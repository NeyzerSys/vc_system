defmodule VcSystem.AccessFixtures do
  @moduledoc """
  Test helpers for the access module.
  """
  import Ecto.Query

  alias VcSystem.Repo
  alias VcSystem.Access.Agents
  alias VcSystem.Access.Schemas.UserToken

  def valid_agent_password, do: "contrasena-de-prueba"

  def unique_agent_email, do: "agente#{System.unique_integer([:positive])}@example.com"

  def agent_fixture(attrs \\ %{}) do
    {:ok, agent} =
      attrs
      |> Enum.into(%{
        first_name: "Sara",
        last_name: "Lopez",
        email: unique_agent_email(),
        password: valid_agent_password()
      })
      |> Agents.create_agent()

    agent
  end

  @doc """
  Moves every session of the agent into the past, so it reads as expired.
  """
  def expire_sessions(agent) do
    past = DateTime.add(DateTime.utc_now(:second), -1, :minute)

    Repo.update_all(from(t in UserToken, where: t.agent_id == ^agent.id),
      set: [expires_at: past]
    )
  end
end
