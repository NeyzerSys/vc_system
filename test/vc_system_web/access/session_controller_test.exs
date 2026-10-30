defmodule VcSystemWeb.Access.SessionControllerTest do
  use VcSystemWeb.ConnCase, async: true

  import VcSystem.AccessFixtures

  setup %{conn: conn} do
    %{conn: put_req_header(conn, "accept", "application/json"), agent: agent_fixture()}
  end

  defp login(conn, agent) do
    conn
    |> post(~p"/api/v1/login", %{email: agent.email, password: valid_agent_password()})
    |> json_response(200)
    |> Map.fetch!("data")
  end

  defp authed(conn, access_token) do
    put_req_header(conn, "authorization", "Bearer " <> access_token)
  end

  describe "POST /api/v1/login" do
    test "returns the tokens and the agent", %{conn: conn, agent: agent} do
      data = login(conn, agent)

      assert data["token_type"] == "Bearer"
      assert is_binary(data["access_token"])
      assert is_binary(data["refresh_token"])
      assert data["agent"]["email"] == agent.email
      refute Map.has_key?(data["agent"], "password")
    end

    test "returns 401 with wrong credentials", %{conn: conn, agent: agent} do
      conn = post(conn, ~p"/api/v1/login", %{email: agent.email, password: "contrasena-mala"})
      assert json_response(conn, 401)["errors"]["detail"] == "Invalid email or password"
    end

    test "returns 400 without credentials", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/login", %{})
      assert json_response(conn, 400)
    end
  end

  describe "GET /api/v1/me" do
    test "returns the logged agent", %{conn: conn, agent: agent} do
      data = login(conn, agent)

      conn = conn |> authed(data["access_token"]) |> get(~p"/api/v1/me")
      assert json_response(conn, 200)["data"]["id"] == agent.id
    end

    test "returns 401 without a token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/me")
      assert json_response(conn, 401)["errors"]["detail"] == "Invalid or missing token"
    end

    test "returns 401 when the session expired", %{conn: conn, agent: agent} do
      data = login(conn, agent)
      expire_sessions(agent)

      conn = conn |> authed(data["access_token"]) |> get(~p"/api/v1/me")
      assert json_response(conn, 401)["errors"]["detail"] == "Session expired"
    end
  end

  describe "POST /api/v1/login/refresh" do
    test "returns a new pair of tokens", %{conn: conn, agent: agent} do
      data = login(conn, agent)

      conn = post(conn, ~p"/api/v1/login/refresh", %{refresh_token: data["refresh_token"]})
      new_data = json_response(conn, 200)["data"]

      assert new_data["access_token"] != data["access_token"]
      assert new_data["refresh_token"] != data["refresh_token"]
    end

    test "returns 401 with an unknown refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/login/refresh", %{refresh_token: "no-existe"})
      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/logout" do
    test "closes the session", %{conn: conn, agent: agent} do
      data = login(conn, agent)

      conn = conn |> authed(data["access_token"]) |> delete(~p"/api/v1/logout")
      assert response(conn, 204)

      conn = build_conn() |> authed(data["access_token"]) |> get(~p"/api/v1/me")
      assert json_response(conn, 401)
    end
  end

  describe "CORS" do
    test "answers the preflight of an allowed origin" do
      conn =
        build_conn()
        |> put_req_header("origin", "http://localhost:5173")
        |> put_req_header("access-control-request-method", "POST")
        |> options("/api/v1/login")

      assert conn.status == 204
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
    end

    test "does not allow other origins", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "https://otro-sitio.com")
        |> get(~p"/api/v1/me")

      refute get_resp_header(conn, "access-control-allow-origin") == ["https://otro-sitio.com"]
    end
  end
end
