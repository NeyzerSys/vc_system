defmodule VcSystem.Access do
  @moduledoc """
  The access module: agents, sessions and logs.

  This is the only entry point from outside the module. If something is
  missing, add a `defdelegate` here instead of calling the inner modules.
  """
  alias VcSystem.Access.Agents
  alias VcSystem.Access.Agents.Sessions

  defdelegate create_agent(attrs, opts \\ []), to: Agents
  defdelegate get_agent_by_email(email), to: Agents

  defdelegate login(email, password), to: Sessions
  defdelegate verify_access_token(token), to: Sessions
  defdelegate refresh_session(refresh_token), to: Sessions
  defdelegate logout(user_token), to: Sessions
end
