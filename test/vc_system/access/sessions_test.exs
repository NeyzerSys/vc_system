defmodule VcSystem.Access.SessionsTest do
  use VcSystem.DataCase, async: true

  import VcSystem.AccessFixtures

  alias VcSystem.Access.Agents
  alias VcSystem.Access.Agents.Sessions
  alias VcSystem.Access.Schemas.{AccessLog, Agent, UserToken}

  defp events(agent) do
    Repo.all(from l in AccessLog, where: l.agent_id == ^agent.id, order_by: l.id, select: l.event)
  end

  describe "create_agent/2" do
    test "hashes the password, builds the username and lowercases the email" do
      agent = agent_fixture(%{email: "  Sara@Example.COM "})

      assert agent.email == "sara@example.com"
      assert agent.username == "Sara Lopez"
      refute agent.password == valid_agent_password()
      assert Agent.valid_password?(agent, valid_agent_password())
      refute agent.is_super_admin
    end

    test "rejects a repeated email" do
      agent = agent_fixture()

      assert {:error, changeset} =
               Agents.create_agent(%{
                 first_name: "Otro",
                 last_name: "Agente",
                 email: String.upcase(agent.email),
                 password: valid_agent_password()
               })

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects short passwords" do
      assert {:error, changeset} =
               Agents.create_agent(%{
                 first_name: "Sara",
                 last_name: "Lopez",
                 email: unique_agent_email(),
                 password: "corta"
               })

      assert errors_on(changeset).password != []
    end
  end

  describe "login/2" do
    test "opens a session and logs it" do
      agent = agent_fixture()

      assert {:ok, session} = Sessions.login(agent.email, valid_agent_password())
      assert session.token_type == "Bearer"
      assert session.agent.id == agent.id
      assert DateTime.diff(session.expires_at, DateTime.utc_now(), :minute) in 59..60
      assert DateTime.diff(session.refresh_expires_at, DateTime.utc_now(), :hour) in 11..12
      assert events(agent) == ["login"]
    end

    test "stores only the hash of the tokens" do
      agent = agent_fixture()
      {:ok, session} = Sessions.login(agent.email, valid_agent_password())

      user_token = Repo.get_by!(UserToken, agent_id: agent.id)
      refute user_token.access_token == session.access_token
      assert byte_size(user_token.access_token) == 32
    end

    test "fails with a wrong password, an unknown email or an inactive agent, without logging" do
      agent = agent_fixture()
      inactive = agent_fixture()
      Repo.update_all(from(a in Agent, where: a.id == ^inactive.id), set: [active: false])

      assert {:error, :invalid_credentials} = Sessions.login(agent.email, "contrasena-mala")

      assert {:error, :invalid_credentials} =
               Sessions.login("nadie@example.com", valid_agent_password())

      assert {:error, :invalid_credentials} =
               Sessions.login(inactive.email, valid_agent_password())

      assert Repo.aggregate(AccessLog, :count) == 0
    end
  end

  describe "verify_access_token/1" do
    setup do
      agent = agent_fixture()
      {:ok, session} = Sessions.login(agent.email, valid_agent_password())
      %{agent: agent, session: session}
    end

    test "returns the agent for a valid token", %{agent: agent, session: session} do
      assert {:ok, %Agent{id: id}, %UserToken{}} =
               Sessions.verify_access_token(session.access_token)

      assert id == agent.id
    end

    test "rejects unknown or malformed tokens" do
      assert {:error, :invalid_token} = Sessions.verify_access_token("no-es-un-token")
      assert {:error, :invalid_token} = Sessions.verify_access_token("")
    end

    test "ends an expired session and logs session_expired", %{agent: agent, session: session} do
      expire_sessions(agent)

      assert {:error, :session_expired} = Sessions.verify_access_token(session.access_token)
      assert Repo.aggregate(UserToken, :count) == 0
      assert events(agent) == ["login", "session_expired"]
    end

    test "rejects revoked sessions and inactive agents", %{agent: agent, session: session} do
      Repo.update_all(UserToken, set: [revoked: true])
      assert {:error, :invalid_token} = Sessions.verify_access_token(session.access_token)

      Repo.update_all(UserToken, set: [revoked: false])
      Repo.update_all(from(a in Agent, where: a.id == ^agent.id), set: [active: false])
      assert {:error, :invalid_token} = Sessions.verify_access_token(session.access_token)
    end
  end

  describe "refresh_session/1" do
    setup do
      agent = agent_fixture()
      {:ok, session} = Sessions.login(agent.email, valid_agent_password())
      %{agent: agent, session: session}
    end

    test "replaces both tokens and keeps the 12 hour limit", %{session: session} do
      assert {:ok, new_session} = Sessions.refresh_session(session.refresh_token)

      assert new_session.access_token != session.access_token
      assert new_session.refresh_token != session.refresh_token
      assert new_session.refresh_expires_at == session.refresh_expires_at
      assert {:error, :invalid_token} = Sessions.verify_access_token(session.access_token)
      assert {:ok, _agent, _token} = Sessions.verify_access_token(new_session.access_token)
    end

    test "a refresh token works only once", %{session: session} do
      assert {:ok, _} = Sessions.refresh_session(session.refresh_token)
      assert {:error, :invalid_token} = Sessions.refresh_session(session.refresh_token)
    end

    test "cannot renew once the access token expired", %{agent: agent, session: session} do
      expire_sessions(agent)

      assert {:error, :session_expired} = Sessions.refresh_session(session.refresh_token)
      assert events(agent) == ["login", "session_expired"]
    end
  end

  describe "logout/1" do
    test "deletes the session and logs it" do
      agent = agent_fixture()
      {:ok, session} = Sessions.login(agent.email, valid_agent_password())
      {:ok, _agent, user_token} = Sessions.verify_access_token(session.access_token)

      assert :ok = Sessions.logout(user_token)
      assert {:error, :invalid_token} = Sessions.verify_access_token(session.access_token)
      assert events(agent) == ["login", "logout"]
    end
  end

  describe "delete_expired_sessions/0" do
    test "deletes expired sessions, logs active ones and keeps live ones" do
      expired = agent_fixture()
      revoked = agent_fixture()
      live = agent_fixture()

      for agent <- [expired, revoked, live] do
        {:ok, _} = Sessions.login(agent.email, valid_agent_password())
      end

      expire_sessions(expired)
      expire_sessions(revoked)

      Repo.update_all(from(t in UserToken, where: t.agent_id == ^revoked.id),
        set: [revoked: true]
      )

      assert Sessions.delete_expired_sessions() == 2

      assert [%UserToken{agent_id: agent_id}] = Repo.all(UserToken)
      assert agent_id == live.id
      assert events(expired) == ["login", "session_expired"]
      assert events(revoked) == ["login"]
      assert events(live) == ["login"]
    end

    test "returns 0 when nothing expired" do
      assert Sessions.delete_expired_sessions() == 0
    end
  end
end
