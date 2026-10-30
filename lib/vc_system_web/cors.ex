defmodule VcSystemWeb.CORS do
  @moduledoc """
  Origins allowed to call the API from a browser. Read at runtime from the
  `:cors_origins` config, which `config/runtime.exs` fills from `CORS_ORIGINS`.
  """

  def origins, do: Application.get_env(:vc_system, :cors_origins, [])
end
