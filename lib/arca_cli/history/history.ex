defmodule Arca.Cli.History do
  @moduledoc """
  Command history management for the CLI.

  This module provides functionality to track and manage command history through a GenServer.
  It implements operations like:
  - Adding commands to history
  - Retrieving command history
  - Flushing the history
  - Getting history length

  The history is maintained as a list of {index, command} tuples, where newer commands
  are at the beginning of the list.
  """

  use GenServer
  require Logger

  # Type definitions
  @typedoc """
  Error types that may be returned by History operations.
  """
  @type error_type ::
          :history_not_available
          | :invalid_command_format
          | :history_operation_failed

  @typedoc """
  Standard result tuple for operations that might fail.
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), term()}

  @typedoc """
  A history entry consists of an index and a command string.
  """
  @type history_entry :: {non_neg_integer(), String.t()}

  @typedoc """
  A history list is a list of history entries.
  """
  @type history_list :: [history_entry()]

  defmodule CliHistory do
    @moduledoc """
    Structure to hold the command history state.
    """
    # next_index is tracked rather than derived from the list length: history is
    # bounded, so once it is full the length stops growing and derived indices
    # would start colliding with entries already recorded.
    defstruct history: [], next_index: 0

    @typedoc """
    History state structure with a list of command history entries.
    """
    @type t :: %__MODULE__{history: list(), next_index: non_neg_integer()}
  end

  @default_history_size 100

  @type state :: %CliHistory{history: history_list()}

  # Client API

  @doc """
  Start the History GenServer.

  ## Parameters
    - `initial_state` (optional): The initial state of the GenServer. Defaults to `%CliHistory{}`.

  ## Returns
    - `{:ok, pid}` on successful start
    - `{:error, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> is_pid(Process.whereis(Arca.Cli.History))
      true
  """
  @spec start_link(state()) :: {:ok, pid()} | {:error, term()}
  def start_link(initial_state \\ %CliHistory{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Get the current History state.

  ## Returns
    - `{:ok, state}` with the current state on success
    - `{:error, error_type, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> {:ok, %Arca.Cli.History.CliHistory{}} = Arca.Cli.History.get_state()
  """
  @spec get_state() :: result(state())
  def get_state() do
    call(:state, :history_not_available, "History service not available")
  end

  # Every client function below goes through here.
  #
  # `GenServer.call/2` to a dead or absent process EXITS the caller -- it does
  # not raise. Each of these functions used to wrap the call in `try/rescue`,
  # which cannot catch an exit, so the graceful degradation they documented never
  # happened: if History was down, the caller died with it. The REPL prompt calls
  # `hlen` on every keystroke, so a History crash took the whole session down.
  @spec call(term(), error_type(), String.t()) :: result(term())
  defp call(request, error_type, message) do
    {:ok, GenServer.call(__MODULE__, request)}
  catch
    :exit, reason ->
      Logger.error("History #{inspect(request)} unavailable: #{inspect(reason)}")
      {:error, error_type, message}
  end

  @doc """
  Push a new command onto the front of the command history.

  ## Parameters
    - `cmd`: The command to push onto the history. It should be a binary string.

  ## Returns
    - `{:ok, history_list}` with the updated history list on success
    - `{:error, error_type, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> Arca.Cli.History.flush_history()
      iex> {:ok, [{0, "echo 'Hello World'"}]} = Arca.Cli.History.push_cmd("echo 'Hello World'")
  """
  @spec push_cmd(String.t()) :: result(history_list())
  def push_cmd(cmd) when is_binary(cmd) do
    call({:push_cmd, cmd}, :history_operation_failed, "Failed to add command to history")
  end

  @spec push_cmd([String.t()]) :: result(history_list())
  def push_cmd(cmd) when is_list(cmd) do
    # Convert list of arguments back to command string
    # This handles CLI mode where args come in as a list
    cmd_string =
      cmd
      |> Enum.map(fn arg ->
        # Quote arguments that contain spaces
        if String.contains?(arg, " ") do
          "\"#{arg}\""
        else
          arg
        end
      end)
      |> Enum.join(" ")

    push_cmd(cmd_string)
  end

  @spec push_cmd(term()) :: result(history_list())
  def push_cmd(cmd) do
    push_cmd(inspect(cmd))
  end

  @doc """
  Get the current history length.

  ## Returns
    - `{:ok, length}` with the history length on success
    - `{:error, error_type, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> Arca.Cli.History.flush_history()
      iex> Arca.Cli.History.push_cmd("echo 'Hello World'")
      iex> {:ok, 1} = Arca.Cli.History.get_history_length()
  """
  @spec get_history_length() :: result(non_neg_integer())
  def get_history_length() do
    call(:hlen, :history_operation_failed, "Failed to retrieve history length")
  end

  @doc """
  Get the list of recent commands in chronological order (oldest first).

  ## Returns
    - `{:ok, history_list}` with the history list on success
    - `{:error, error_type, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> Arca.Cli.History.flush_history()
      iex> Arca.Cli.History.push_cmd("echo 'Hello World'")
      iex> Arca.Cli.History.push_cmd("ls -l")
      iex> {:ok, history} = Arca.Cli.History.get_history()
      iex> history
      [{0, "echo 'Hello World'"}, {1, "ls -l"}]
  """
  @spec get_history() :: result(history_list())
  def get_history() do
    call(:history, :history_not_available, "History not available")
  end

  @doc """
  Get all commands from history as a list of strings (without indices).

  ## Returns
    - List of command strings in chronological order (oldest first)

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> Arca.Cli.History.flush_history()
      iex> Arca.Cli.History.push_cmd("echo 'Hello World'")
      iex> Arca.Cli.History.push_cmd("ls -l")
      iex> Arca.Cli.History.get_all()
      ["echo 'Hello World'", "ls -l"]
  """
  @spec get_all() :: [String.t()]
  def get_all() do
    case get_history() do
      {:ok, history} ->
        Enum.map(history, fn {_index, cmd} -> cmd end)

      {:error, _, _} ->
        []
    end
  end

  @doc """
  Flush the history completely.

  ## Returns
    - `{:ok, []}` with empty list on success
    - `{:error, error_type, reason}` on failure

  ## Examples
      iex> # Ensure the GenServer is started
      iex> case Process.whereis(Arca.Cli.History) do
      ...>   nil -> {:ok, _} = Arca.Cli.History.start_link()
      ...>   pid -> {:ok, pid}
      ...> end
      iex> Arca.Cli.History.push_cmd("echo 'Hello World'")
      iex> {:ok, []} = Arca.Cli.History.flush_history()
  """
  @spec flush_history() :: result(history_list())
  def flush_history() do
    call(:flush_history, :history_operation_failed, "Failed to flush history")
  end

  # For backward compatibility with existing code
  # These functions maintain the previous API while delegating to the new functions

  @doc false
  def state do
    case get_state() do
      {:ok, state} -> state
      _ -> %CliHistory{}
    end
  end

  @doc false
  def hlen do
    case get_history_length() do
      {:ok, length} -> length
      _ -> 0
    end
  end

  @doc false
  def history do
    case get_history() do
      {:ok, history} -> history
      _ -> []
    end
  end

  # Server Callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:push_cmd, cmd}, _from, state) do
    new_history =
      [{state.next_index, String.trim(cmd)} | state.history]
      |> Enum.take(history_size())

    {:reply, new_history, %CliHistory{history: new_history, next_index: state.next_index + 1}}
  end

  @impl true
  def handle_call(:hlen, _from, state) do
    {:reply, length(state.history), state}
  end

  @impl true
  def handle_call(:history, _from, state) do
    {:reply, Enum.reverse(state.history), state}
  end

  @impl true
  def handle_call(:flush_history, _from, _state) do
    new_state = %CliHistory{history: []}
    {:reply, [], new_state}
  end

  # Private functions

  @doc """
  The maximum number of commands history retains.

  Configurable as `config :arca_cli, history_size: n`; defaults to
  #{@default_history_size}. Without a bound, a long-running REPL session grew
  its history without limit.
  """
  @spec history_size() :: pos_integer()
  def history_size do
    case Application.get_env(:arca_cli, :history_size, @default_history_size) do
      size when is_integer(size) and size > 0 -> size
      _ -> @default_history_size
    end
  end
end
