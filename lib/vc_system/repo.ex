defmodule VcSystem.Repo do
  use Ecto.Repo,
    otp_app: :vc_system,
    adapter: Ecto.Adapters.Postgres
end
