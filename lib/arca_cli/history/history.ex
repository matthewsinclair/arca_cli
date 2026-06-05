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
    defstruct history: []

    @typedoc """
    History state structure with a list of command history entries.
    """
    @type t :: %__MODULE__{history: list()}
  end

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
    try do
      state = GenServer.call(__MODULE__, :state)
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to get history state: #{inspect(error)}")
        {:error, :history_not_available, "History service not available"}
    end
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
    try do
      history = GenServer.call(__MODULE__, {:push_cmd, cmd})
      {:ok, history}
    rescue
      error ->
        Logger.error("Failed to push command to history: #{inspect(error)}")
        {:error, :history_operation_failed, "Failed to add command to history"}
    end
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
    try do
      length = GenServer.call(__MODULE__, :hlen)
      {:ok, length}
    rescue
      error ->
        Logger.error("Failed to get history length: #{inspect(error)}")
        {:error, :history_operation_failed, "Failed to retrieve history length"}
    end
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
    try do
      history = GenServer.call(__MODULE__, :history)
      {:ok, history}
    rescue
      error ->
        Logger.error("Failed to get history: #{inspect(error)}")
        {:error, :history_not_available, "History not available"}
    end
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
    try do
      empty_history = GenServer.call(__MODULE__, :flush_history)
      {:ok, empty_history}
    rescue
      error ->
        Logger.error("Failed to flush history: #{inspect(error)}")
        {:error, :history_operation_failed, "Failed to flush history"}
    end
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
    with {:ok, new_history} <- add_command_to_history(state.history, cmd),
         {:ok, new_state} <- update_history_state(new_history) do
      {:reply, new_history, new_state}
    end
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

  # Adds a command to the history list
  @spec add_command_to_history(history_list(), String.t()) :: result(history_list())
  defp add_command_to_history(history, cmd) when is_binary(cmd) do
    new_history = [{length(history), String.trim(cmd)} | history]
    {:ok, new_history}
  end

  # Updates the history state with a new history list
  @spec update_history_state(history_list()) :: result(state())
  defp update_history_state(new_history) do
    new_state = %CliHistory{history: new_history}
    {:ok, new_state}
  end
end
