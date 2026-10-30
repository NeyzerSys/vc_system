defmodule VcSystemWeb.Access.Profile.MeController do
  use VcSystemWeb, :controller

  def show(conn, _params) do
    render(conn, :show, agent: conn.assigns.current_agent)
  end
end
