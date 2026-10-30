defmodule VcSystemWeb.PageController do
  use VcSystemWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
