defmodule VcSystem.Access.Schemas.UserToken do
  @moduledoc """
  A live agent session (`user_tokens`).

  `access_token` and `refresh_token` hold the SHA-256 hash of each token.
  The plain tokens only exist on the client.
  """
  use Ecto.Schema

  alias VcSystem.Access.Schemas.Agent

  schema "user_tokens" do
    field :access_token, :binary, redact: true
    field :refresh_token, :binary, redact: true
    field :token_type, :string, default: "session"
    field :expires_at, :utc_datetime
    field :refresh_expires_at, :utc_datetime
    field :revoked, :boolean, default: false

    belongs_to :agent, Agent

    timestamps(type: :utc_datetime, inserted_at: :created_at)
  end

  @doc """
  Returns true when the session can no longer be used or renewed.
  """
  def expired?(%__MODULE__{expires_at: expires_at}, now) do
    DateTime.compare(expires_at, now) != :gt
  end
end
