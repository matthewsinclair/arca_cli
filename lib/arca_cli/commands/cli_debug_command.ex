defmodule Arca.Cli.Commands.CliDebugCommand do
  @moduledoc """
  Command to show or toggle debug mode for detailed error information.

  This command allows users to:
  - View the current debug mode status: `cli cli.debug`
  - Enable debug mode: `cli cli.debug on`
  - Disable debug mode: `cli cli.debug off`

  When debug mode is enabled, error messages will include detailed information
  such as stack traces and error context, which is helpful for troubleshooting.

  The setting is read back at the start of every invocation (see
  `Arca.Cli.apply_persisted_settings/1`), so turning it on stays on until it is
  turned off. What this command reports is the value actually in force, not the
  value on disk: those used to be able to disagree, and the one that mattered to
  error formatting was the one nobody was reading.

  ## Examples

      $ cli cli.debug
      Debug mode is currently OFF

      $ cli cli.debug on
      Debug mode is now ON

      $ cli cli.debug off
      Debug mode is now OFF
  """
  use Arca.Cli.Command.BaseCommand

  config :"cli.debug",
    name: "cli.debug",
    about: "Show or toggle debug mode for detailed error information",
    args: [
      toggle: [
        value_name: "on|off",
        help: "Turn debug mode on or off",
        required: false
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    case args.args.toggle do
      nil -> "Debug mode is currently #{label(debug_mode?())}"
      "on" -> set_debug_mode(true)
      "off" -> set_debug_mode(false)
      other -> {:error, :invalid_argument, "Invalid value '#{other}'. Use 'on' or 'off'."}
    end
  end

  # The value actually in force. Every consumer of debug mode reads the
  # application environment, so that is what this command reports.
  @spec debug_mode?() :: boolean()
  defp debug_mode? do
    Application.get_env(:arca_cli, :debug_mode, false) == true
  end

  @spec set_debug_mode(boolean()) :: String.t() | Arca.Cli.error_tuple()
  defp set_debug_mode(value) do
    Application.put_env(:arca_cli, :debug_mode, value)

    case Arca.Cli.save_settings(%{"debug_mode" => value}) do
      {:ok, _settings} ->
        "Debug mode is now #{label(value)}"

      {:error, reason} ->
        {:error, :settings_not_saved,
         "debug mode is #{label(value)} for this session only: #{reason}"}
    end
  end

  @spec label(boolean()) :: String.t()
  defp label(true), do: "ON"
  defp label(false), do: "OFF"
end
