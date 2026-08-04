defmodule Arca.Cli.Commands.CliErrorCommand do
  @moduledoc """
  Command used for testing error handling scenarios.

  This command deliberately produces different types of errors
  to test the error handling pipeline.

  It doubles as the way to verify that a failing command exits non-zero:
  every error type below makes the CLI exit 1, while `success` exits 0.
  """
  use Arca.Cli.Command.BaseCommand

  alias Arca.Cli.Ctx

  config :"cli.error",
    name: "cli.error",
    about: "Test command for error handling",
    args: [
      error_type: [
        value_name: "TYPE",
        help: "Type of error to generate (raise, standard, legacy, ctx, warning, success)",
        required: true
      ]
    ]

  @impl true
  def handle(args, settings, _optimus) do
    case args.args.error_type do
      "raise" ->
        # Deliberately raise an exception
        raise "This is a test exception from CliErrorCommand"

      "standard" ->
        # Return a standard error tuple
        {:error, :invalid_argument, "This is a standard error tuple test"}

      "legacy" ->
        # Return a legacy error tuple
        {:error, "This is a legacy error tuple test"}

      "ctx" ->
        # Report failure through the context's own status channel
        Ctx.new(%{}, settings, command: :"cli.error")
        |> Ctx.add_output({:error, "This is a context error test"})
        |> Ctx.complete(:error)

      "warning" ->
        # A warning is a success carrying notes, so this still exits 0
        Ctx.new(%{}, settings, command: :"cli.error")
        |> Ctx.add_output({:warning, "This is a context warning test"})
        |> Ctx.complete(:warning)

      "success" ->
        # Return success
        "Success: No error occurred"

      _ ->
        {:error, :invalid_argument,
         "Unknown error type. Use 'raise', 'standard', 'legacy', 'ctx', 'warning', or 'success'."}
    end
  end
end
