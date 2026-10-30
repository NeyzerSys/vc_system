defmodule VcSystem.Access.Agents.Sessions do
  @moduledoc """
  API sessions: access token + refresh token.

  - The access token lasts `access_ttl_minutes` (60 by default).
  - The client renews it with the refresh token **before** it expires. Once
    the access token expires without being renewed (no activity), the session
    is over and the agent has to log in again.
  - Renewing never goes past `refresh_ttl_hours` (12 by default) from login:
    that is the longest an agent stays logged in without typing the password.

  Tokens are random, sent to the client once, and stored as SHA-256 hashes.
  """
  import Ecto.Query

  alias VcSystem.Repo
  alias VcSystem.Access.{Agents, Audit}
  alias VcSystem.Access.Schemas.UserToken

  @access_ttl_minutes Application.compile_env(:vc_system, [__MODULE__, :access_ttl_minutes], 60)
  @refresh_ttl_hours Application.compile_env(:vc_system, [__MODULE__, :refresh_ttl_hours], 12)
  @token_bytes 32
  @token_type "Bearer"

  @doc """
  Checks the credentials and opens a session.

  Returns `{:ok, session}` or `{:error, :invalid_credentials}`. Failed
  attempts are not logged.
  """
  def login(email, password) when is_binary(email) and is_binary(password) do
    case Agents.get_agent_by_email_and_password(email, password) do
      nil -> {:error, :invalid_credentials}
      agent -> create_session(agent)
    end
  end

  defp create_session(agent) do
    now = now()
    {access_token, access_hash} = build_token()
    {refresh_token, refresh_hash} = build_token()
    refresh_expires_at = DateTime.add(now, @refresh_ttl_hours, :hour)

    user_token = %UserToken{
      agent_id: agent.id,
      access_token: access_hash,
      refresh_token: refresh_hash,
      token_type: @token_type,
      expires_at: access_expires_at(now, refresh_expires_at),
      refresh_expires_at: refresh_expires_at
    }

    Repo.transaction(fn ->
      user_token = Repo.insert!(user_token)
      Audit.log_access!(agent, "LOGIN")
      session(agent, user_token, access_token, refresh_token)
    end)
  end

  @doc """
  Finds the session for an access token.

  Returns `{:ok, agent, user_token}`, `{:error, :session_expired}` or
  `{:error, :invalid_token}`. An expired session is deleted and logged as
  `SESSION_EXPIRED`.
  """
  def verify_access_token(token) when is_binary(token) do
    with {:ok, hash} <- hash_token(token),
         %UserToken{} = user_token <- get_token_by(access_token: hash) do
      check_usable(user_token)
    else
      _ -> {:error, :invalid_token}
    end
  end

  @doc """
  Renews a session with its refresh token. Both tokens are replaced, so a
  refresh token works only once.

  Returns `{:ok, session}`, `{:error, :session_expired}` or
  `{:error, :invalid_token}`.
  """
  def refresh_session(refresh_token) when is_binary(refresh_token) do
    with {:ok, hash} <- hash_token(refresh_token),
         %UserToken{} = user_token <- get_token_by(refresh_token: hash),
         {:ok, agent, user_token} <- check_usable(user_token) do
      rotate(agent, user_token)
    else
      {:error, :session_expired} -> {:error, :session_expired}
      _ -> {:error, :invalid_token}
    end
  end

  defp rotate(agent, user_token) do
    now = now()
    {access_token, access_hash} = build_token()
    {refresh_token, refresh_hash} = build_token()

    user_token
    |> Ecto.Changeset.change(
      access_token: access_hash,
      refresh_token: refresh_hash,
      expires_at: access_expires_at(now, user_token.refresh_expires_at)
    )
    |> Repo.update!()
    |> then(&{:ok, session(agent, &1, access_token, refresh_token)})
  end

  @doc """
  Closes the session and logs the `LOGOUT`.
  """
  def logout(%UserToken{} = user_token) do
    end_session(user_token, "LOGOUT")
  end

  @doc """
  Deletes every expired session and logs `SESSION_EXPIRED` for each one that
  was still active. Revoked sessions are deleted without a new log entry:
  their `SESSION_REVOKED` was already written.

  Returns how many sessions were deleted.
  """
  def delete_expired_sessions do
    now = now()
    expired = from t in UserToken, where: t.expires_at <= ^now

    Repo.transaction(fn ->
      {revoked, _} = Repo.delete_all(where(expired, [t], t.revoked))

      {active, agents} =
        expired
        |> where([t], not t.revoked)
        |> join(:inner, [t], a in assoc(t, :agent))
        |> select([_t, a], %{id: a.id, email: a.email})
        |> Repo.delete_all()

      Audit.log_access_all!(agents, "SESSION_EXPIRED")
      revoked + active
    end)
    |> then(fn {:ok, count} -> count end)
  end

  defp check_usable(%UserToken{revoked: true}), do: {:error, :invalid_token}
  defp check_usable(%UserToken{agent: %{active: false}}), do: {:error, :invalid_token}

  defp check_usable(%UserToken{agent: agent} = user_token) do
    if UserToken.expired?(user_token, now()) do
      end_session(user_token, "SESSION_EXPIRED")
      {:error, :session_expired}
    else
      {:ok, agent, user_token}
    end
  end

  # Deletes by id so two requests ending the same session log it only once.
  defp end_session(user_token, event) do
    Repo.transaction(fn ->
      {deleted, _} = Repo.delete_all(from t in UserToken, where: t.id == ^user_token.id)
      if deleted == 1, do: Audit.log_access!(user_token.agent, event)
    end)

    :ok
  end

  defp get_token_by(clauses) do
    UserToken
    |> where(^Keyword.put(clauses, :token_type, @token_type))
    |> preload(:agent)
    |> Repo.one()
  end

  defp session(agent, user_token, access_token, refresh_token) do
    %{
      agent: agent,
      token_type: @token_type,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: user_token.expires_at,
      refresh_expires_at: user_token.refresh_expires_at
    }
  end

  defp build_token do
    raw = :crypto.strong_rand_bytes(@token_bytes)
    {Base.url_encode64(raw, padding: false), :crypto.hash(:sha256, raw)}
  end

  defp hash_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, raw} -> {:ok, :crypto.hash(:sha256, raw)}
      :error -> :error
    end
  end

  defp access_expires_at(now, refresh_expires_at) do
    Enum.min([DateTime.add(now, @access_ttl_minutes, :minute), refresh_expires_at], DateTime)
  end

  defp now, do: DateTime.utc_now(:second)
end
