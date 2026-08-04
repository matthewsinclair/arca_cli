defmodule Arca.Cli.Commands.SysFlushCommand do
  @moduledoc """
  Flushes the history of previous commands.

  This command clears the command history, removing all previously executed
  commands from the history storage.
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.History

  config :"sys.flush",
    name: "sys.flush",
    about: "Flush the command history."

  @typedoc """
  Possible error types for history flush operations
  """
  @type error_type ::
          :history_unavailable
          | :flush_failed

  @typedoc """
  Result type for flush operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Flush the history of previous commands with proper error handling.

  Uses Railway-Oriented Programming to handle the flush operation.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: String.t() | {:error, error_type(), String.t()}
  def handle(_args, _settings, _optimus) do
    case flush_command_history() do
      {:ok, _} ->
        "Command history cleared successfully"

      # The failure returns its error tuple. As a display string it read as
      # success to dispatch, so a history flush that did not happen still
      # reported success and exited 0 (finding A24).
      {:error, error_type, reason} ->
        {:error, error_type, "failed to clear command history: #{reason}"}
    end
  end

  @doc """
  Flush command history with error handling.

  ## Returns
    - {:ok, :flushed} on successful history flush
    - {:error, error_type, reason} if flush operation failed
  """
  @spec flush_command_history() :: result(:flushed)
  def flush_command_history() do
    try do
      History.flush_history()
      {:ok, :flushed}
    rescue
      e in RuntimeError ->
        {:error, :flush_failed, Exception.message(e)}

      _ ->
        {:error, :history_unavailable, "Could not access command history"}
    end
  end
end
