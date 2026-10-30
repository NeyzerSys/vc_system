defmodule VcSystem.Access.Audit do
  @moduledoc """
  The access module's logs. For now only `access_log`: logins and logouts.
  """
  alias VcSystem.Repo
  alias VcSystem.Access.Schemas.{AccessLog, Agent}

  @doc """
  Records an access event for `agent`. Meant to run inside the same
  transaction as the change it describes.
  """
  def log_access!(%Agent{} = agent, event) do
    agent
    |> AccessLog.changeset(event)
    |> Repo.insert!()
  end
end
