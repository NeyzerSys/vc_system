defmodule VcSystem.Access.Agents do
  @moduledoc """
  Agent identity and credentials.
  """
  alias VcSystem.Repo
  alias VcSystem.Access.Schemas.Agent

  @doc """
  Returns the active agent with that email and password, or `nil`.

  A missing email, a wrong password and an inactive agent all return `nil`,
  so callers cannot tell which one happened.
  """
  def get_agent_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    agent = Repo.get_by(Agent, email: Agent.normalize_email(email))

    if Agent.valid_password?(agent, password) and agent.active, do: agent
  end

  @doc """
  Creates an agent. Pass `super_admin: true` to create a systems agent.
  """
  def create_agent(attrs, opts \\ []) do
    %Agent{is_super_admin: Keyword.get(opts, :super_admin, false)}
    |> Agent.create_changeset(attrs)
    |> Repo.insert()
  end

  def get_agent_by_email(email) when is_binary(email) do
    Repo.get_by(Agent, email: Agent.normalize_email(email))
  end
end
