defmodule Arca.Cli.Commands.SysInfoCommand do
  @moduledoc """
  Command to display system information.
  This is a test command for dot notation (sys.info).
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :"sys.info",
    name: "sys.info",
    about: "Display system information."

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, settings, _optimus) do
    # Gather system information
    elixir_version = System.version()
    otp_version = :erlang.system_info(:otp_release) |> List.to_string()
    system_arch = :erlang.system_info(:system_architecture) |> List.to_string()

    # Additional system info
    num_schedulers = :erlang.system_info(:schedulers)
    process_count = :erlang.system_info(:process_count)

    # Build Context with structured output
    Ctx.for_command(:"sys.info", args, settings)
    |> Ctx.add_output({:info, "System Information"})
    |> Ctx.add_output(
      {:table,
       [
         ["Property", "Value"],
         ["Elixir Version", elixir_version],
         ["OTP Version", otp_version],
         ["System Architecture", system_arch],
         ["Schedulers", to_string(num_schedulers)],
         ["Process Count", to_string(process_count)]
       ], [has_headers: true]}
    )
    |> Ctx.complete(:ok)
  end
end
