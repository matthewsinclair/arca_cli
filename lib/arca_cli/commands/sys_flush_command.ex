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
  Possible error types for history flush operations.

  These are History's own error types, passed through rather than remapped: this
  command adds nothing to the diagnosis, and inventing a second vocabulary for
  the same failures is how two names for one thing start.
  """
  @type error_type :: History.error_type()

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

  This used to call `History.flush_history/0`, **discard what it returned**, and
  answer `{:ok, :flushed}` unless something raised. Nothing raises: `History.call/3`
  catches the `:exit` and returns a tagged tuple (the WP-05 fix for A5), so the
  `try/rescue` here was dead and the only failure signal was thrown away. That
  made `handle/3`'s error branch unreachable, so the A24 fix looked right and
  could not execute -- the archetype this whole thread is about, one layer out.

  Caught by vc on WP-11 re-verification.

  ## Returns
    - {:ok, :flushed} on successful history flush
    - {:error, error_type, reason} if flush operation failed
  """
  @spec flush_command_history() :: result(:flushed)
  def flush_command_history() do
    case History.flush_history() do
      {:ok, _} -> {:ok, :flushed}
      {:error, error_type, reason} -> {:error, error_type, reason}
    end
  end
end
