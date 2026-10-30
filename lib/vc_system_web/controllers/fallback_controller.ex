defmodule VcSystemWeb.FallbackController do
  @moduledoc """
  Turns `{:error, reason}` returned by API actions into JSON responses.
  """
  use VcSystemWeb, :controller

  def call(conn, {:error, :invalid_credentials}),
    do: error(conn, :unauthorized, "Invalid email or password")

  def call(conn, {:error, :invalid_token}),
    do: error(conn, :unauthorized, "Invalid or missing token")

  def call(conn, {:error, :session_expired}), do: error(conn, :unauthorized, "Session expired")
  def call(conn, {:error, :bad_request}), do: error(conn, :bad_request, "Bad request")

  defp error(conn, status, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: %{detail: detail}})
  end
end
