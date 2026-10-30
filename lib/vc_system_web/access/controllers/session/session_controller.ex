defmodule VcSystemWeb.Access.Session.SessionController do
  use VcSystemWeb, :controller

  alias VcSystem.Access.Agents.Sessions

  action_fallback VcSystemWeb.FallbackController

  def create(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    with {:ok, session} <- Sessions.login(email, password) do
      render(conn, :show, session: session)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def refresh(conn, %{"refresh_token" => refresh_token}) when is_binary(refresh_token) do
    with {:ok, session} <- Sessions.refresh_session(refresh_token) do
      render(conn, :show, session: session)
    end
  end

  def refresh(_conn, _params), do: {:error, :bad_request}

  def delete(conn, _params) do
    :ok = Sessions.logout(conn.assigns.current_token)
    send_resp(conn, :no_content, "")
  end
end
