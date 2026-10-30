defmodule VcSystem.Access.Schemas.AccessLog do
  @moduledoc """
  Agent logins and logouts (`access_log`). Immutable: written once, never edited.

  Failed login attempts are not recorded here.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VcSystem.Access.Schemas.Agent

  @events ~w(login logout session_revoked session_expired)

  schema "access_log" do
    field :email, :string
    field :event, :string

    belongs_to :agent, Agent

    timestamps(type: :utc_datetime, inserted_at: :created_at)
  end

  def events, do: @events

  @doc """
  Builds the entry for `agent`, keeping the email it had at that moment.
  """
  def changeset(%Agent{} = agent, event) when event in @events do
    %__MODULE__{agent_id: agent.id, email: agent.email, event: event}
    |> change()
    |> check_constraint(:event, name: :event_must_be_valid)
  end
end
