defmodule Arca.Cli.HistorySupervisor do
  use Supervisor
  alias Arca.Cli.History

  def start_link(init_arg) do
    # Logger.info("#{__MODULE__}.start_link: #{inspect(init_arg)}")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    # Logger.info("#{__MODULE__}.init: #{inspect(init_arg)}")

    children = [
      {Arca.Cli.History, %History.CliHistory{}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
