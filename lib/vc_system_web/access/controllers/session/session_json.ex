defmodule VcSystemWeb.Access.Session.SessionJSON do
  alias VcSystemWeb.Access.Profile.MeJSON

  def show(%{session: session}) do
    %{
      data: %{
        token_type: session.token_type,
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_at: session.expires_at,
        refresh_expires_at: session.refresh_expires_at,
        agent: MeJSON.agent(session.agent)
      }
    }
  end
end
