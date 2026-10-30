defmodule VcSystemWeb.Router do
  use VcSystemWeb, :router

  import VcSystemWeb.Access.Auth, only: [require_api_agent: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VcSystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :require_api_agent
  end

  scope "/", VcSystemWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/v1", VcSystemWeb.Access do
    pipe_through :api

    post "/login", Session.SessionController, :create
    post "/login/refresh", Session.SessionController, :refresh
  end

  scope "/api/v1", VcSystemWeb.Access do
    pipe_through [:api, :api_auth]

    delete "/logout", Session.SessionController, :delete
    get "/me", Profile.MeController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vc_system, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VcSystemWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
