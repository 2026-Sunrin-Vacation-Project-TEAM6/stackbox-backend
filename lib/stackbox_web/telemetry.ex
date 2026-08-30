defmodule StackboxWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("stackbox.repo.query.total_time", unit: {:native, :millisecond})
    ]
  end

  defp periodic_measurements do
    # {:process_info, ...} measurements require a specific process `:name`
    # (they report on one process's info, e.g. message_queue_len) — the
    # previous entry here passed `event: [:vm, :memory]` with no `:name`,
    # which isn't valid for that measurement type and crashed
    # telemetry_poller's supervisor on every application start (including
    # under `mix test`). Left empty until a real periodic measurement is
    # needed; see telemetry_poller's docs for `:vm_memory` if VM-wide memory
    # is wanted instead.
    []
  end
end
