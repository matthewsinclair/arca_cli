defmodule Arca.Cli.Help do
  @moduledoc """
  Centralized help system for Arca.Cli.

  This module provides a unified interface for handling help requests across
  all command scenarios. It's designed to be used at the pre-execution stage
  to determine if help should be shown instead of executing a command.

  ## Help Scenarios

  This module handles three main help scenarios:

  1. Command invoked without parameters: `cli cmd`
     - This shows help if the command has `show_help_on_empty: true`
     - Commands requiring arguments should set this to true
     - Commands that work without args should set this to false

  2. Command invoked with `--help` flag: `cli cmd --help`
     - Always shows help regardless of command configuration

  3. Command invoked with help prefix: `cli help cmd`
     - Always shows help regardless of command configuration

  ## Integration with BaseCommand

  Commands that use `Arca.Cli.Command.BaseCommand` can simply set the
  `show_help_on_empty` configuration parameter to control when help is shown:

  ```elixir
  defmodule MyApp.Commands.QueryCommand do
    use Arca.Cli.Command.BaseCommand

    config :query,
      name: "query",
      about: "Query data from the system",
      show_help_on_empty: true  # Show help when invoked without args

    @impl true
    def handle(args, settings, optimus) do
      # Just implement the command logic - help is handled automatically
      # ...
    end
  end
  ```
  """

  require Logger
  alias Arca.Cli.Callbacks

  @typedoc """
  Types of errors that can occur in the Help module.
  """
  @type error_type ::
          :handler_not_found
          | :config_not_available
          | :command_error

  @typedoc """
  Standard result tuple for operations that might fail.
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), term()}

  @doc """
  Determines if help should be shown for a command with the given arguments.

  Checks three conditions:
  1. If the command is invoked with --help flag
  2. If the command is configured to show help on empty arguments
  3. If the command requires arguments but none were provided

  ## Parameters
    - cmd: Command name or atom
    - args: Command arguments from Optimus.parse
    - handler: (Optional) Command handler module

  ## Returns
    - true if help should be displayed, false otherwise
  """
  @spec should_show_help?(atom() | String.t(), map() | list(), module() | nil) :: boolean()
  def should_show_help?(cmd, args, handler \\ nil) do
    handler = handler || handler_for_name(cmd)

    has_help_flag?(args) ||
      (handler && is_empty_command_args?(args) && show_help_on_empty?(handler)) || false
  end

  # Resolve a command name to its handler without minting an atom for a name that
  # is not a registered command.
  @spec handler_for_name(atom() | String.t()) :: module() | nil
  defp handler_for_name(cmd) do
    case to_command_atom(cmd) do
      {:ok, cmd_atom} -> get_handler_for_command(cmd_atom)
      {:error, :unknown_command} -> nil
    end
  end

  @doc """
  Generates and displays help for a command.

  ## Parameters
    - cmd: Command name or atom
    - args: Command arguments
    - optimus: Optimus configuration

  ## Returns
    - Formatted help text
  """
  @spec show(atom() | String.t(), map(), term()) :: [String.t()]
  def show(cmd, _args, optimus) do
    case to_command_atom(cmd) do
      {:ok, cmd_atom} ->
        cmd_atom
        |> generate_help(optimus)
        |> format_help()

      {:error, :unknown_command} ->
        ["error: unknown command: #{cmd}"]
    end
  end

  @doc """
  Checks if a command is configured to show help when invoked with empty arguments.

  ## Parameters
    - handler: Command handler module

  ## Returns
    - true if the command should show help on empty, false otherwise
  """
  @spec show_help_on_empty?(module()) :: boolean()
  def show_help_on_empty?(handler) do
    with {:ok, config} <- fetch_handler_config(handler),
         {:ok, show_help} <- extract_show_help_setting(config) do
      show_help
    else
      _ -> false
    end
  end

  @doc """
  Fetches the configuration from a command handler module.

  ## Parameters
    - handler: Command handler module

  ## Returns
    - {:ok, config} with the configuration on success
    - {:error, error_type, reason} on failure
  """
  @spec fetch_handler_config(module()) :: result(term())
  def fetch_handler_config(handler) do
    try do
      {:ok, handler.config()}
    rescue
      error ->
        Logger.debug("Error fetching config from handler: #{inspect(error)}")
        {:error, :config_not_available, "Command configuration not available"}
    end
  end

  @doc """
  Extracts the show_help_on_empty setting from a command configuration.

  ## Parameters
    - config: Command configuration from handler.config()

  ## Returns
    - {:ok, boolean} with the setting value on success
    - {:error, error_type, reason} on failure
  """
  @spec extract_show_help_setting(term()) :: result(boolean())
  def extract_show_help_setting(config) do
    try do
      setting =
        config
        |> List.first()
        |> elem(1)
        |> Keyword.get(:show_help_on_empty, false)

      {:ok, setting}
    rescue
      _ -> {:error, :command_error, "Could not extract show_help_on_empty setting"}
    end
  end

  @doc """
  Checks if arguments contain the --help flag.

  ## Parameters
    - args: Command arguments

  ## Returns
    - true if --help is present, false otherwise
  """
  @spec has_help_flag?(map() | list()) :: boolean()
  def has_help_flag?(args) when is_list(args), do: "--help" in args
  def has_help_flag?(%{flags: flags}) when is_map(flags), do: Map.get(flags, :help, false)
  def has_help_flag?(_), do: false

  @doc """
  Checks if command arguments are empty.

  ## Parameters
    - args: Command arguments from Optimus.parse

  ## Returns
    - true if arguments are empty, false otherwise
  """
  @spec is_empty_command_args?(map() | list()) :: boolean()
  def is_empty_command_args?(%{} = map) when map_size(map) == 0, do: true
  def is_empty_command_args?(%{metadata: _} = map) when map_size(map) == 1, do: true

  def is_empty_command_args?(%Optimus.ParseResult{args: args, flags: flags, options: options})
      when args == %{} and flags == %{} and options == %{},
      do: true

  def is_empty_command_args?(["--help"]), do: true
  def is_empty_command_args?(_), do: false

  @doc """
  Resolve a command name to the atom that identifies a registered command.

  The single place a command name becomes an atom. It resolves against the
  commands actually registered by the configurators, so an unrecognised name is
  reported rather than turned into a new atom. That matters because atoms are
  never reclaimed and the VM halts when the table fills: a REPL session or a
  script looping over generated names would otherwise be able to exhaust it.

  Resolving against the registry rather than `String.to_existing_atom/1` also
  keeps the answer honest -- an atom that happens to exist for some unrelated
  reason is still not a command.

  ## Parameters
    - cmd: Command name (binary or atom)

  ## Returns
    - `{:ok, atom}` when the name names a registered command
    - `{:error, :unknown_command}` otherwise

  ## Examples

      iex> Arca.Cli.Help.to_command_atom("about")
      {:ok, :about}

      iex> Arca.Cli.Help.to_command_atom("no.such.command")
      {:error, :unknown_command}
  """
  @spec to_command_atom(atom() | String.t()) :: {:ok, atom()} | {:error, :unknown_command}
  def to_command_atom(cmd) when is_atom(cmd) and not is_nil(cmd), do: {:ok, cmd}

  def to_command_atom(cmd) when is_binary(cmd) do
    Arca.Cli.command_atoms()
    |> Enum.find(fn registered -> Atom.to_string(registered) == cmd end)
    |> case do
      nil -> {:error, :unknown_command}
      registered -> {:ok, registered}
    end
  end

  def to_command_atom(_cmd), do: {:error, :unknown_command}

  @doc """
  Finds the handler module for a command.

  ## Parameters
    - cmd: Command name as atom

  ## Returns
    - Command handler module or nil if not found
  """
  @spec get_handler_for_command(atom()) :: module() | nil
  def get_handler_for_command(cmd) do
    case Arca.Cli.handler_for_command(cmd) do
      {:ok, _cmd_atom, handler} -> handler
      _ -> nil
    end
  end

  @doc """
  Generates help text for a command.

  ## Parameters
    - cmd: Command name as atom
    - optimus: Optimus configuration

  ## Returns
    - List of help text lines
  """
  @spec generate_help(atom(), term()) :: [String.t()]
  def generate_help(cmd, optimus) do
    help_lines =
      optimus
      |> Optimus.Help.help([cmd], 80)
      |> Enum.drop(2)

    normalize_app_name(help_lines, optimus.name)
  end

  @doc """
  Normalizes the application name in help text for consistency.
  Always replaces the application name with "cli" in USAGE lines.

  ## Parameters
    - help_lines: List of help text lines
    - app_name: Application name to replace

  ## Returns
    - Updated help text lines
  """
  @spec normalize_app_name([String.t()], String.t()) :: [String.t()]
  def normalize_app_name(help_lines, app_name) do
    help_lines
    |> Enum.map(fn line ->
      if String.starts_with?(line, "    #{app_name}") do
        with {:ok, remaining} <- extract_remaining_text(line, app_name) do
          "    cli#{remaining}"
        end
      else
        line
      end
    end)
  end

  @doc """
  Extracts the remaining text after the application name in a help line.

  ## Parameters
    - line: Help text line
    - app_name: Application name to extract after

  ## Returns
    - {:ok, remaining} with the extracted text on success
    - {:error, reason} if extraction fails
  """
  @spec extract_remaining_text(String.t(), String.t()) :: result(String.t())
  def extract_remaining_text(line, app_name) do
    app_name_len = String.length(app_name)
    line_len = String.length(line)

    if line_len > app_name_len + 4 do
      remaining = String.slice(line, (app_name_len + 4)..(line_len - 1))
      {:ok, remaining}
    else
      {:ok, ""}
    end
  end

  @doc """
  Formats help text using callbacks if available.

  ## Parameters
    - help_text: List of help text lines

  ## Returns
    - Formatted help text (possibly processed by callbacks)
  """
  @spec format_help([String.t()]) :: [String.t()]
  def format_help(help_text) do
    if Callbacks.has_callbacks?(:format_help) do
      Callbacks.execute(:format_help, help_text)
    else
      help_text
    end
  end
end
