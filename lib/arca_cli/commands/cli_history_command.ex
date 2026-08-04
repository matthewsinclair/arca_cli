defmodule Arca.Cli.Commands.CliHistoryCommand do
  @moduledoc """
  Arca CLI command to list command history with structured output.
  """
  alias Arca.Cli.{History, Ctx}
  use Arca.Cli.Command.BaseCommand

  config :"cli.history",
    name: "cli.history",
    about: "Show a history of recent commands."

  @doc """
  List the history of commands using Context pattern for structured output.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, settings, _optimus) do
    ctx = Ctx.for_command(:"cli.history", args, settings)

    case History.history() do
      [] ->
        ctx
        |> Ctx.add_output({:info, "No command history available"})
        |> Ctx.complete(:ok)

      history ->
        build_history_context(ctx, history)
    end
  end

  defp build_history_context(ctx, history) do
    # Convert history to table format
    table_rows = history_to_table_rows(history)

    ctx
    |> Ctx.add_output({:info, "Command History"})
    |> Ctx.add_output({:table, table_rows, [has_headers: true]})
    |> Ctx.with_cargo(%{
      total_commands: length(history),
      latest_index: history |> List.last() |> elem(0)
    })
    |> Ctx.complete(:ok)
  end

  defp history_to_table_rows(history) do
    # Headers
    headers = ["Index", "Command", "Arguments"]

    # Convert each history entry to a row
    data_rows =
      history
      |> Enum.map(fn {idx, cmd_string} ->
        # Parse command string to extract command and arguments
        {command, args} = parse_command_string(cmd_string)

        [
          to_string(idx),
          command,
          args
        ]
      end)

    [headers | data_rows]
  end

  defp parse_command_string(cmd_string) do
    case String.split(cmd_string, " ", parts: 2) do
      [command] ->
        {command, ""}

      [command, args] ->
        {command, args}

      _ ->
        {cmd_string, ""}
    end
  end
end
