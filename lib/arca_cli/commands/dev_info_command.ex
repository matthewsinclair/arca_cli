defmodule Arca.Cli.Commands.DevInfoCommand do
  @moduledoc """
  Command to display development environment information.
  This is a namespaced command using dot notation (dev.info).

  Everything reported here is read from the running system or captured at compile
  time, so the command works the same whether the CLI runs under Mix or as an
  escript. Mix is a build tool and is not present in a released escript; asking it
  anything at runtime is what used to make this command crash.
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :"dev.info",
    name: "dev.info",
    about: "Display development environment information."

  # Captured at compile time, where the build environment is actually known.
  @build_env Application.compile_env(:arca_cli, :env, :prod)

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, settings, _optimus) do
    Ctx.for_command(:"dev.info", args, settings)
    |> Ctx.add_output({:info, "Development Environment Information"})
    |> Ctx.add_output({:table, info_rows(), has_headers: true})
    |> Ctx.complete(:ok)
  end

  @spec info_rows() :: [[String.t()]]
  defp info_rows do
    [
      ["Property", "Value"],
      ["Application", Arca.Cli.name()],
      ["Version", Arca.Cli.version()],
      ["Build Environment", to_string(@build_env)],
      ["Deployment", deployment()],
      ["Elixir Version", System.version()],
      ["OTP Release", List.to_string(:erlang.system_info(:otp_release))],
      ["Compilation Target", List.to_string(:erlang.system_info(:system_architecture))]
    ]
  end

  # A capability check, not an environment check: Mix is present when the CLI runs
  # from a checkout and absent from a built escript.
  @spec deployment() :: String.t()
  defp deployment do
    case Code.ensure_loaded?(Mix) do
      true -> "mix"
      false -> "escript"
    end
  end
end
