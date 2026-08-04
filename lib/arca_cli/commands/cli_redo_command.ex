defmodule Arca.Cli.Commands.CliRedoCommand do
  @moduledoc """
  Redo a previous command from the command history.
  """
  alias Arca.Cli.{Repl, History}
  use Arca.Cli.Command.BaseCommand

  config :"cli.redo",
    name: "cli.redo",
    about: "Redo a previous command from the history.",
    args: [
      idx: [
        value_name: "IDX",
        help: "Command index",
        required: true,
        parser: :integer
      ]
    ]

  @doc """
  Redo a specific command by index from History.

  An index outside the history is returned as an error tuple, not as its own
  message. Returning the message as a plain string left the CLI exiting 0 on a
  redo that never ran anything (finding A13).
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, settings, optimus) do
    history = History.history()

    case Enum.at(history, valid_index(args.args.idx, length(history))) do
      nil -> {:error, :invalid_argument, "no command at history index #{args.args.idx}"}
      entry -> Repl.eval_for_redo(entry, settings, optimus)
    end
  end

  # Enum.at/2 treats a negative index as counting from the end, which would make
  # `cli.redo -1` silently replay the most recent command.
  @spec valid_index(integer(), non_neg_integer()) :: integer()
  defp valid_index(idx, length) when idx >= 0 and idx < length, do: idx
  defp valid_index(_idx, length), do: length
end
