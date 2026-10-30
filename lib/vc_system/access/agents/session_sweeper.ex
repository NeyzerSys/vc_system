defmodule VcSystem.Access.Agents.SessionSweeper do
  @moduledoc """
  Deletes expired sessions every `interval_minutes`, so sessions abandoned
  without a logout do not stay in `user_tokens` forever and still get their
  `SESSION_EXPIRED` entry.

  Safe to run on several nodes at once: each deleted row is returned, and
  logged, by only one of them.
  """
  use GenServer
  require Logger

  alias VcSystem.Access.Agents.Sessions

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = opts |> Keyword.fetch!(:interval_minutes) |> :timer.minutes()
    schedule(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:sweep, state) do
    count = Sessions.delete_expired_sessions()
    if count > 0, do: Logger.info("Deleted #{count} expired sessions")

    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(interval), do: Process.send_after(self(), :sweep, interval)
end
