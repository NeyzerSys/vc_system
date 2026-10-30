defmodule VcSystemWeb.Access.Profile.MeJSON do
  alias VcSystem.Access.Schemas.Agent

  def show(%{agent: agent}), do: %{data: agent(agent)}

  def agent(%Agent{} = agent) do
    %{
      id: agent.id,
      first_name: agent.first_name,
      last_name: agent.last_name,
      username: agent.username,
      email: agent.email,
      is_super_admin: agent.is_super_admin
    }
  end
end
