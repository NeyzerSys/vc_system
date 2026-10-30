defmodule VcSystemWeb.Access.Auth do
  @moduledoc """
  Plugs for authenticating API requests with `Authorization: Bearer <token>`.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias VcSystem.Access.Agents.Sessions

  @doc """
  Requires a valid access token. On success assigns `:current_agent` and
  `:current_token`; otherwise answers 401 and halts.
  """
  def require_api_agent(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, agent, user_token} <- Sessions.verify_access_token(token) do
      conn
      |> assign(:current_agent, agent)
      |> assign(:current_token, user_token)
    else
      {:error, :session_expired} -> unauthorized(conn, "Session expired")
      _ -> unauthorized(conn, "Invalid or missing token")
    end
  end

  defp unauthorized(conn, detail) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: detail}})
    |> halt()
  end
end
