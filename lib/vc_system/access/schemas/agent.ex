defmodule VcSystem.Access.Schemas.Agent do
  @moduledoc """
  A system agent (`cat_agents`): identity and login credentials.

  Agents log in with `email` and `password`. The `password` column always
  holds a Bcrypt hash, never the plain text.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "cat_agents" do
    field :first_name, :string
    field :last_name, :string
    field :username, :string
    field :email, :string
    field :password, :string, redact: true
    field :is_super_admin, :boolean, default: false
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime, inserted_at: :created_at)
  end

  @doc """
  Changeset for creating an agent.

  `password` arrives in plain text and is replaced by its hash. `username` is
  built from `first_name` and `last_name`. `is_super_admin` and `active` are
  not cast: whoever creates the agent sets them on the struct.
  """
  def create_changeset(agent, attrs) do
    agent
    |> cast(attrs, [:first_name, :last_name, :email, :password])
    |> validate_required([:first_name, :last_name, :email, :password])
    |> update_change(:first_name, &String.trim/1)
    |> update_change(:last_name, &String.trim/1)
    |> validate_email()
    |> validate_password()
    |> put_username()
    |> hash_password()
  end

  defp validate_email(changeset) do
    changeset
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 255)
    |> unique_constraint(:email)
  end

  # Bcrypt only uses the first 72 bytes of the password.
  defp validate_password(changeset) do
    validate_length(changeset, :password, min: 12, max: 72, count: :bytes)
  end

  defp put_username(changeset) do
    first_name = get_field(changeset, :first_name)
    last_name = get_field(changeset, :last_name)

    if first_name && last_name do
      put_change(changeset, :username, "#{first_name} #{last_name}")
    else
      changeset
    end
  end

  defp hash_password(%Ecto.Changeset{valid?: true} = changeset) do
    password = get_change(changeset, :password)
    put_change(changeset, :password, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset

  @doc """
  Lowercases and trims an email, so lookups and the unique index agree.
  """
  def normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  @doc """
  Checks a plain-text password against the agent's hash.

  When there is no agent it still runs a fake check, so a missing email
  takes as long to answer as a wrong password.
  """
  def valid_password?(%__MODULE__{password: hash}, password)
      when is_binary(hash) and is_binary(password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_agent, _password) do
    Bcrypt.no_user_verify()
    false
  end
end
