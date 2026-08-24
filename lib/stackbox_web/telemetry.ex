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
    [
      {:process_info, event: [:vm, :memory], measurement: :total}
    ]
  end
end
