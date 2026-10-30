defmodule VcSystem.Access.Audit do
  @moduledoc """
  The access module's logs. For now only `access_log`: logins and logouts.
  """
  alias VcSystem.Repo
  alias VcSystem.Access.Schemas.{AccessLog, Agent}

  @events AccessLog.events()

  @doc """
  Records an access event for `agent`. Meant to run inside the same
  transaction as the change it describes.
  """
  def log_access!(%Agent{} = agent, event) do
    agent
    |> AccessLog.changeset(event)
    |> Repo.insert!()
  end

  @doc """
  Records the same access event for many agents in one insert. Each agent is
  a map with `:id` and `:email`.
  """
  def log_access_all!(agents, event) when event in @events do
    now = DateTime.utc_now(:second)

    entries =
      Enum.map(agents, fn agent ->
        %{agent_id: agent.id, email: agent.email, event: event, created_at: now, updated_at: now}
      end)

    Repo.insert_all(AccessLog, entries)
  end
end
