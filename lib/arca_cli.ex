defmodule Arca.Cli do
  @moduledoc """
  Arca.Cli is a flexible command-line interface utility for Elixir projects.

  This module serves as the main entry point for the CLI application and provides:

  1. Command dispatcher and routing functionality
  2. Configuration and settings management
  3. Error handling and formatting
  4. Application lifecycle management

  The CLI follows a modular design with pluggable commands and configurators.
  Commands are registered through configurators, which are responsible for
  setting up the CLI environment and registering available commands.

  ## Architecture

  - Commands: Individual command implementations in `Arca.Cli.Command.*`
  - Configurators: Setup modules in `Arca.Cli.Configurator.*`
  - History: Command history tracking in `Arca.Cli.History`
  - Utils: Utility functions in `Arca.Cli.Utils`
  - Testing: Test utilities in `Arca.Cli.Testing.*`

  ## Testing Utilities

  Arca.Cli provides powerful testing utilities for CLI commands:

  - `Arca.Cli.Testing.CliFixturesTest` - Declarative, file-based testing framework
  - `Arca.Cli.Testing.CliCommandHelper` - Helper functions for running commands in tests

  See `Arca.Cli.Testing.CliFixturesTest` for detailed documentation on creating
  CLI fixture tests.

  ## Configuration

  Arca.Cli uses Arca.Config to manage configuration files. Configuration is automatically
  derived based on the application name:

  - Default config directory: `~/.arca/`
  - Default config filename: `arca_cli.json` (derived from the application name)

  These paths can be overridden with environment variables:
  - `ARCA_CONFIG_PATH`: Override the configuration directory
  - `ARCA_CONFIG_FILE`: Override the configuration filename

  ## Error Handling

  The application uses consistent error tuples in the format:

  - `{:ok, result}` for successful operations
  - `{:error, error_type, reason}` for error conditions where:
    - `error_type` is an atom indicating the category of error
    - `reason` is a string or term providing detailed information about the error

  Standard error types are defined in this module's @type definitions.
  """

  @typedoc """
  Types of errors that can occur in the CLI application.
  """
  @type error_type ::
          :command_not_found
          | :command_failed
          | :invalid_argument
          | :config_error
          | :file_not_found
          | :file_not_readable
          | :file_not_writable
          | :decode_error
          | :encode_error
          | :unknown_error

  @typedoc """
  Standard result tuple for operations that might fail.
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), term()}

  @typedoc """
  Detailed error tuple with context information.
  """
  @type error_tuple :: {:error, error_type(), term()}

  @typedoc """
  The outcome of running a command: success, success carrying warnings, or failure.

  This is what `run/1` returns and what `main/1` translates into an OS exit status.
  """
  @type outcome :: :ok | :error | :warning

  @typedoc """
  A command outcome paired with the text to display for it.

  Every function named `dispatch*` returns this shape. The `handle_*` and
  `parse_command_line` functions are adapters over them that keep the historical
  display-only contract for the REPL and for downstream callers.
  """
  @type dispatch_result :: {outcome(), String.t() | [String.t()] | {:nooutput, term()}}

  use Application
  require Logger
  use OK.Pipe
  import Arca.Cli.Utils
  alias Arca.Cli.Configurator.Coordinator
  alias Arca.Cli.{Ctx, Output, Callbacks}

  @doc """
  Handle Application functionality to start the Arca.Cli subsystem.

  Starts the core components first, then schedules delayed initialization
  for configuration-related tasks to prevent circular dependencies.
  """
  @impl true
  def start(_type, _args) do
    # Logger.info("#{__MODULE__}.start: #{inspect(args)}")

    # Configure logger backends for REPL mode
    configure_logger_backends()

    children = build_child_specs()
    opts = [strategy: :one_for_one, name: Arca.Cli]
    Supervisor.start_link(children, opts)
  end

  # Configure logger backends when in REPL mode
  defp configure_logger_backends do
    env = Application.get_env(:arca_cli, :env)

    if System.get_env("REPL_MODE") == "true" && env != :prod do
      LoggerBackends.add(LoggerFileBackend)
    end
  end

  # Builds the appropriate child specifications based on the environment and runtime state.
  # In test mode, we avoid starting the History GenServer through the supervisor
  # if it's already running (started by the test helper).
  defp build_child_specs do
    history_maybe_child_spec()
  end

  # For test environment where History is already running, don't start the HistorySupervisor
  defp history_maybe_child_spec do
    cond do
      # Check if we're in a release where Mix is not available
      Code.ensure_loaded?(Mix) == false ->
        [{Arca.Cli.HistorySupervisor, []}]

      # In test environment with History already running
      Mix.env() == :test && is_pid(Process.whereis(Arca.Cli.History)) ->
        []

      # Default case - start the HistorySupervisor
      true ->
        [{Arca.Cli.HistorySupervisor, []}]
    end
  end

  @doc """
  Register callbacks for configuration changes.

  Sets up handlers that respond to configuration changes,
  allowing the CLI to adapt to updates in real-time.

  This function includes guards against circular dependencies and
  is designed to be safely called during the delayed initialization phase.
  """
  def register_config_callbacks do
    # Check if Arca.Config is available before proceeding
    if config_available?() do
      # Use a clean, declarative approach to register our callback
      :arca_cli
      |> register_main_config_callback()
      |> register_specific_callbacks()
    else
      Logger.debug("Skipping config callback registration - Arca.Config not available")
      :ok
    end
  end

  # Check if Arca.Config is available for callback registration
  defp config_available? do
    cond do
      # In a release where Mix is not available
      Code.ensure_loaded?(Mix) == false ->
        # Just check if Arca.Config is available
        Code.ensure_loaded?(Arca.Config) &&
          function_exported?(Arca.Config, :register_change_callback, 2) &&
          Process.whereis(Arca.Config.Server) != nil

      # In test environment, we don't need Arca.Config
      Mix.env() == :test ->
        true

      # Normal development environment
      true ->
        # Check if the Arca.Config module is loaded and the Server process is running
        Code.ensure_loaded?(Arca.Config) &&
          function_exported?(Arca.Config, :register_change_callback, 2) &&
          Process.whereis(Arca.Config.Server) != nil
    end
  end

  defp register_main_config_callback(_app_name) do
    # Register a main callback for any configuration change
    # Use try/rescue to handle potential errors gracefully
    try do
      Arca.Config.register_change_callback(:arca_cli, &handle_config_change/1)
      :ok
    rescue
      e ->
        Logger.error("Failed to register main config callback: #{inspect(e)}")
        :ok
    end
  end

  defp register_specific_callbacks(:ok) do
    # Additional specific settings we want to watch
    try do
      ["callbacks", "repl_settings", "display_options"]
      |> Enum.each(fn key ->
        try do
          Arca.Config.subscribe(key)
        rescue
          e ->
            Logger.error("Failed to subscribe to #{key}: #{inspect(e)}")
        end
      end)

      :ok
    rescue
      e ->
        Logger.error("Failed to register specific callbacks: #{inspect(e)}")
        :ok
    end
  end

  defp handle_config_change(config) do
    # Handle the configuration change in a focused, functional way
    Logger.debug("Configuration changed")

    # Extract any important settings that require special handling
    config
    |> Map.get("display_options", %{})
    |> apply_display_settings()
  end

  defp apply_display_settings(display_options) do
    # Apply any display settings that were changed
    # This is just a placeholder for actual implementation
    Logger.debug("Applied display settings: #{inspect(display_options)}")
    :ok
  end

  @doc """
  Entry point for command line parsing.

  This function is the main entry point for the CLI and is called when
  the application is run as an escript or via the mix task.

  It runs the command via `run/1` and translates the outcome into an OS exit
  status, so that a failing command exits non-zero. Success (and warnings,
  which are successes carrying notes) returns normally, letting the escript
  exit 0 through normal shutdown.

  Embedders and tests should call `run/1` instead: it is the same code path
  but never halts the VM.
  """
  @spec main([String.t()]) :: :ok | no_return()
  def main(argv) do
    argv
    |> run()
    |> halt_for()
  end

  # Translate a command outcome into an OS exit status. Only failure halts;
  # System.halt/1 flushes pending IO, so piped output is not truncated.
  @spec halt_for(outcome()) :: :ok | no_return()
  defp halt_for(:error), do: System.halt(1)
  defp halt_for(outcome) when outcome in [:ok, :warning], do: :ok

  @doc """
  Run the CLI for the given arguments and report the command outcome.

  This is the pure entry point. It parses, dispatches and displays exactly as
  `main/1` does, but returns the outcome instead of halting the VM. Use it when
  embedding Arca.Cli in another application, and in tests.

  ## Parameters
    - argv: Command line arguments

  ## Returns
    - `:ok` if the command succeeded
    - `:warning` if the command succeeded with warnings
    - `:error` if the command failed
  """
  @spec run([String.t()]) :: outcome()
  def run(argv) do
    configure_io()
    unless length(argv) != 0, do: intro() |> put_lines

    # Load settings with proper error handling
    # If initialization is still in progress, this will return defaults
    settings =
      case load_settings() do
        {:ok, loaded_settings} ->
          loaded_settings

        _ ->
          # For any other result (which should be an error tuple),
          # log a warning and return empty settings
          Logger.warning("Error loading settings")
          %{}
      end

    optimus = optimus_config()
    {outcome, response} = dispatch(argv, settings, optimus)

    display_response(response)
    outcome
  end

  # Prepare standard output before anything is written to it.
  #
  # Two axes, and both used to be wrong in opposite directions: content that must
  # survive a pipe was being destroyed, while decoration that must not survive one
  # was being forced on.
  #
  #   - Encoding: an escript's stdio defaults to latin1, which turns any codepoint
  #     above 255 into literal `\x{...}` text. Emoji and accented characters have
  #     to be declared as unicode to arrive as their real UTF-8 bytes.
  #   - Colour: nothing to do. The runtime already worked out at boot whether
  #     stdout is a terminal, and `:elixir, :ansi_enabled` reflects it correctly.
  #     The bug was overriding that flag with an unconditional `true`, which
  #     pushed escape codes into pipes and files. Removing the override is the fix.
  @spec configure_io() :: :ok
  defp configure_io do
    :io.setopts(:standard_io, encoding: :unicode)
    :ok
  end

  # Display a dispatch response, preserving the historical display behaviour:
  # under test everything renders, elsewhere empty and :nooutput responses are
  # skipped so errors are not printed twice.
  @spec display_response(term()) :: :ok
  defp display_response(response) do
    if Code.ensure_loaded?(Mix) && Mix.env() == :test do
      response
      |> filter_blank_lines
      |> put_lines
    else
      case response do
        "" ->
          :ok

        {:nooutput, _} ->
          :ok

        _ ->
          response
          |> filter_blank_lines
          |> put_lines
      end
    end

    :ok
  end

  # # Check initialization status and log appropriately
  # defp check_initialization_status do
  #   # Skip checking in test mode
  #   unless Mix.env() == :test do
  #     if Process.whereis(Arca.Cli.Configurator.Initializer) != nil do
  #       status = Arca.Cli.Configurator.Initializer.status()

  #       # # Only log a warning if initialization isn't complete
  #       # unless Map.get(status, :initialized, false) do
  #       #   Logger.debug("CLI initialization not yet complete - using default settings")
  #       # end
  #     else
  #       # Initializer not started - this shouldn't happen in normal operation
  #       Logger.debug("CLI initializer not started - using default settings")
  #     end
  #   end
  # end

  @doc """
  Parse the command line arguments and dispatch to the appropriate handler,
  reporting both the command outcome and what to display for it.

  ## Parameters
    - argv: Command line arguments
    - settings: Application settings
    - optimus: Optimus configuration

  ## Returns
    - `{outcome, output}` where outcome is `:ok`, `:warning` or `:error`
  """
  @spec dispatch([String.t()], map(), term()) :: dispatch_result()
  def dispatch(argv, settings, optimus) do
    case command_line_type(argv) do
      :help ->
        # Top-level help
        {:ok, generate_filtered_help(optimus)}

      {:help_command, command} ->
        # Help for a specific command
        dispatch_command_help(command, optimus)

      :normal ->
        # Normal command execution
        Optimus.parse(optimus, argv)
        |> dispatch_args(settings, optimus)
    end
  end

  @doc """
  Parse the command line arguments and dispatch to the appropriate handler.

  Display-only adapter over `dispatch/3`, kept for callers that only need the
  output. Use `dispatch/3` when the command outcome matters.

  ## Parameters
    - argv: Command line arguments
    - settings: Application settings
    - optimus: Optimus configuration

  ## Returns
    - Command result or error message
  """
  @spec parse_command_line([String.t()], map(), term()) :: String.t() | [String.t()]
  def parse_command_line(argv, settings, optimus) do
    dispatch(argv, settings, optimus) |> elem(1)
  end

  @doc """
  Determine the type of command line request.

  ## Parameters
    - argv: Command line arguments

  ## Returns
    - :help for top-level help
    - {:help_command, command} for command-specific help
    - :normal for normal command execution
  """
  @spec command_line_type([String.t()]) :: :help | {:help_command, String.t()} | :normal
  def command_line_type(argv) do
    cond do
      # Case 1: Top-level help with --help flag
      argv == ["--help"] ->
        :help

      # Case 2: Command-specific help with --help flag
      length(argv) >= 2 && Enum.at(argv, 1) == "--help" ->
        {:help_command, List.first(argv)}

      # Case 3: Command-specific help with --help flag anywhere after command
      length(argv) >= 2 && "--help" in argv ->
        {:help_command, List.first(argv)}

      # Case 4: Help prefix command
      length(argv) >= 2 && List.first(argv) == "help" ->
        {:help_command, Enum.at(argv, 1)}

      # Case 5: Normal command parsing
      true ->
        :normal
    end
  end

  @doc """
  Check if the command line arguments contain a help flag

  Delegates to the Help module for consistent behavior.
  """
  def has_help_flag?(argv) do
    Arca.Cli.Help.has_help_flag?(argv)
  end

  @doc """
  Handle help for a specific command, reporting the outcome alongside the text.

  Asking for help on an unknown command is a failure, so it reports `:error`.
  """
  @spec dispatch_command_help(atom() | String.t(), term()) :: dispatch_result()
  def dispatch_command_help(cmd, optimus) do
    # Convert cmd to atom if it's a string
    cmd_atom = if is_binary(cmd), do: String.to_atom(cmd), else: cmd

    case handler_for_command(cmd_atom) do
      {:ok, _cmd_atom, handler} ->
        # First try to get help text directly from the command's config
        case extract_help_from_config(handler) do
          {:ok, help_text} when is_binary(help_text) ->
            # Format the help text to match the style of Optimus.Help.help
            {:ok, format_command_help(cmd, help_text)}

          _ ->
            # Fall back to the centralized help system
            {:ok, Arca.Cli.Help.show(cmd_atom, [], optimus)}
        end

      nil ->
        # Command not found
        {:error, ["error: unknown command: #{cmd}"]}
    end
  end

  @doc """
  Handle help for a specific command

  First tries to get help text from the command's config;
  falls back to the Help module for centralized help handling.

  Display-only adapter over `dispatch_command_help/2`.
  """
  def handle_command_help(cmd, optimus) do
    dispatch_command_help(cmd, optimus) |> elem(1)
  end

  @doc """
  Extract help text from a command's config.

  ## Parameters
    - handler: Command handler module

  ## Returns
    - {:ok, help_text} if help text is found in config
    - {:error, reason} if help text is not found
  """
  def extract_help_from_config(handler) do
    try do
      # Get the command's config
      config = handler.config() |> List.first()

      # Extract the help text from the config
      help_text = config |> elem(1) |> Keyword.get(:help)

      if is_binary(help_text) do
        {:ok, help_text}
      else
        {:error, :help_not_found, "Help text not found in command config"}
      end
    rescue
      e ->
        Logger.debug("Error extracting help from config: #{inspect(e)}")
        {:error, :config_error, "Error extracting help from config"}
    end
  end

  @doc """
  Format help text to match the style of Optimus.Help.help output.

  ## Parameters
    - cmd: Command name (atom or string)
    - help_text: Raw help text from command config

  ## Returns
    - Formatted help text in a list of strings with proper formatting
  """
  def format_command_help(cmd, help_text) do
    cmd_str = if is_atom(cmd), do: Atom.to_string(cmd), else: cmd

    # Create a header similar to Optimus.Help.help
    header = [
      "USAGE:",
      "    cli #{cmd_str} [OPTIONS]",
      "",
      "DESCRIPTION:"
    ]

    # Split the help text into lines and indent appropriately
    help_lines =
      help_text
      |> String.split("\n")
      |> Enum.map(fn line ->
        if String.trim(line) == "", do: "", else: "    #{line}"
      end)

    # Combine the parts
    header ++ help_lines
  end

  @doc """
  Provide an Optimus config to drive the CLI.
  """
  def optimus_config do
    # We need to include hidden commands in the config for execution
    # but help display will use commands(false) to filter them
    configurators()
    |> Coordinator.setup()
  end

  @doc """
  Grab the list of Configurators specified in config to :arca_cli.
  """
  def configurators() do
    Application.fetch_env!(:arca_cli, :configurators)
  end

  @doc """
  Grab the list of Commands that have been specified in config to :arca_cli.

  ## Parameters
    - include_hidden: Whether to include commands marked with hidden: true (default: true)
  """
  def commands(include_hidden \\ true) do
    cmds =
      configurators()
      |> Enum.flat_map(& &1.commands())

    if include_hidden do
      cmds
    else
      # Filter out hidden commands for display in help
      cmds
      |> Enum.reject(fn module ->
        {_cmd_atom, opts} = apply(module, :config, []) |> List.first()
        Keyword.get(opts, :hidden, false)
      end)
    end
  end

  @doc """
  Return the command handler for the specfied command. Look in commands if provided, and if not, default to the list of commands provided by the commands() function.

  Supports both standard commands (e.g., `:about`) and dot notation commands (e.g., `:"sys.info"`).
  """
  def handler_for_command(cmd, commands \\ commands()) do
    command_string = Atom.to_string(cmd)

    # For dot notation, convert sys.info -> SysInfoCommand
    # For standard notation, convert sys -> SysCommand
    command_module_name =
      command_string
      |> String.split(".")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")
      |> Kernel.<>("Command")

    # Find the command handler module. Search from the end: when two configurators
    # register the same command name, Optimus merges last-registered-wins, so
    # dispatch has to resolve the same way or parse and dispatch disagree about
    # which module a command means.
    handler =
      commands
      |> Enum.reverse()
      |> Enum.find(fn module ->
        module_name_parts = Module.split(module)
        List.last(module_name_parts) == command_module_name
      end)

    case handler do
      nil -> nil
      module -> {:ok, cmd, module}
    end
  end

  @doc """
  Handle the command line arguments, reporting the outcome alongside the output.

  Parse failures and unknown commands are failures and report `:error`; help
  and successful dispatch report the command's own outcome.
  """
  @spec dispatch_args(term(), map(), term()) :: dispatch_result()
  def dispatch_args(args, settings, optimus) do
    case args do
      {:ok, [subcmd], cmd_args} ->
        dispatch_subcommand(subcmd, cmd_args, settings, optimus)

      {:ok, msg} when is_binary(msg) ->
        {:ok, msg}

      {:ok, %Optimus.ParseResult{unknown: []}} ->
        # Use helper function to generate filtered help text
        {:ok, generate_filtered_help(optimus)}

      {:ok, %Optimus.ParseResult{unknown: errors}} ->
        # When called with an unknown param(s), show an error
        {:error, handle_error(["Unknown command:"] ++ errors)}

      {:error, cmd, reason} ->
        {:error, handle_error(cmd, reason)}

      {:error, reason} ->
        {:error, handle_error(reason)}

      {:help, subcmd} ->
        # Optimus.Help.help puts intro() and contact() on the front of this, so drop it
        {:ok,
         Optimus.Help.help(optimus, subcmd, 80)
         |> Enum.drop(2)
         |> Enum.map(&rewrite_usage_app_name(&1, optimus.name))}

      :help ->
        # Use helper function to generate filtered help text
        {:ok, generate_filtered_help(optimus)}

      :version ->
        # Optimus reports --version as a bare atom; without this clause it fell
        # through to the catch-all and printed the help screen instead.
        {:ok, "#{name()} #{version()}"}

      _other ->
        # Use helper function to generate filtered help text
        {:ok, generate_filtered_help(optimus)}
    end
  end

  # Always replace the app name with "cli" in USAGE lines for consistency
  @spec rewrite_usage_app_name(String.t(), String.t()) :: String.t()
  defp rewrite_usage_app_name(line, app_name) do
    if String.starts_with?(line, "    #{app_name}") do
      # Extract the part after the app name (command and args)
      app_name_len = String.length(app_name)
      line_len = String.length(line)

      remaining =
        if line_len > app_name_len + 4 do
          String.slice(line, (app_name_len + 4)..(line_len - 1))
        else
          ""
        end

      "    cli#{remaining}"
    else
      line
    end
  end

  @doc """
  Handle the command line arguments.

  Display-only adapter over `dispatch_args/3`, used by the REPL and by callers
  that do not need the command outcome.
  """
  def handle_args(args, settings, optimus) do
    dispatch_args(args, settings, optimus) |> elem(1)
  end

  @doc """
  Dispatch to the appropriate subcommand, if we can find one, reporting the
  outcome alongside the output.

  ## Parameters
    - cmd: Command name (atom)
    - args: Command arguments
    - settings: Application settings
    - optimus: Optimus configuration

  ## Returns
    - `{outcome, output}` where outcome is `:ok`, `:warning` or `:error`
  """
  @spec dispatch_subcommand(atom(), map(), map(), term()) :: dispatch_result()
  def dispatch_subcommand(cmd, args, settings, optimus) do
    with {:ok, handler} <- find_command_handler(cmd),
         {:ok, outcome, result} <- execute_command(cmd, args, settings, optimus, handler) do
      {outcome, result}
    else
      # Handle enhanced error format
      {:error, error_type, reason, debug_info} ->
        {:error, handle_error({:error, error_type, reason, debug_info})}

      # Handle standard error format for backward compatibility
      {:error, error_type, reason} ->
        {:error, handle_error({:error, error_type, reason})}
    end
  end

  @doc """
  Dispatch to the appropriate subcommand, if we can find one.

  Display-only adapter over `dispatch_subcommand/4`.

  ## Parameters
    - cmd: Command name (atom)
    - args: Command arguments
    - settings: Application settings
    - optimus: Optimus configuration

  ## Returns
    - Command result or error message
  """
  @spec handle_subcommand(atom(), map(), map(), term()) :: String.t() | [String.t()]
  def handle_subcommand(cmd, args, settings, optimus) do
    dispatch_subcommand(cmd, args, settings, optimus) |> elem(1)
  end

  @doc """
  Find a command handler for the given command.

  ## Parameters
    - cmd: Command name (atom)

  ## Returns
    - {:ok, handler} with the command handler module on success
    - {:error, :command_not_found, reason} if command not found
  """
  @spec find_command_handler(atom()) :: result(module())
  def find_command_handler(cmd) do
    case handler_for_command(cmd) do
      nil ->
        create_error(:command_not_found, "unknown command: #{cmd}")

      {:ok, _cmd_atom, handler} ->
        {:ok, handler}
    end
  end

  @doc """
  Execute a command with proper error handling.

  ## Parameters
    - cmd: Command name (atom)
    - args: Command arguments
    - settings: Application settings
    - optimus: Optimus configuration
    - handler: Command handler module

  ## Returns
    - {:ok, outcome, result} with the command outcome and result on success
    - {:error, error_type, reason} on execution failure
  """
  @spec execute_command(atom(), map(), map(), term(), module()) ::
          {:ok, outcome(), String.t() | [String.t()]}
          | error_tuple()
          | Arca.Cli.ErrorHandler.enhanced_error()
  def execute_command(cmd, args, settings, optimus, handler) do
    try do
      # Use the centralized help system to check if help should be shown
      if Arca.Cli.Help.should_show_help?(cmd, args, handler) do
        # Show help for this command using the centralized help system
        {:ok, :ok, Arca.Cli.Help.show(cmd, args, optimus)}
      else
        # Normal command execution with proper error handling
        handler.handle(args, settings, optimus)
        |> process_command_result(handler, settings)
      end
    rescue
      e ->
        stacktrace = __STACKTRACE__

        # Log the detailed error with stack trace for server logs
        Logger.error(
          "Error executing command #{cmd}: #{inspect(e)}\n#{Exception.format_stacktrace(stacktrace)}"
        )

        # Create an enhanced error with both error message and debug info
        Arca.Cli.ErrorHandler.create_error(
          :command_failed,
          "Error executing command #{cmd}: #{Exception.message(e)}",
          stack_trace: stacktrace,
          original_error: e,
          error_location: "#{__MODULE__}.execute_command/5"
        )
    end
  end

  # Process command results with pattern matching
  # New: Handle Context returns, carrying the context's own status through
  defp process_command_result(%Ctx{} = ctx, _handler, _settings) do
    {:ok, ctx_outcome(ctx), Output.render(ctx)}
  end

  # Legacy: Handle string returns
  defp process_command_result(result, _handler, settings) when is_binary(result) do
    {:ok, :ok, apply_legacy_formatting(result, settings)}
  end

  # Legacy: Handle list returns
  defp process_command_result(result, _handler, _settings) when is_list(result) do
    {:ok, :ok, result}
  end

  # Existing: Handle nooutput tuples
  defp process_command_result({:nooutput, _value} = result, _handler, _settings) do
    {:ok, :ok, result}
  end

  # Existing: Handle error with binary reason
  defp process_command_result({:error, reason}, handler, _settings) when is_binary(reason) do
    Arca.Cli.ErrorHandler.create_error(
      :command_failed,
      reason,
      error_location: "#{handler}.handle/3"
    )
  end

  # Existing: Handle error with type and reason
  defp process_command_result({:error, error_type, reason}, handler, _settings) do
    Arca.Cli.ErrorHandler.create_error(
      error_type,
      reason,
      error_location: "#{handler}.handle/3"
    )
  end

  # Existing: Handle enhanced error format
  defp process_command_result({:error, _type, _reason, _debug} = error, _handler, _settings) do
    error
  end

  # Fallback: Convert other returns to string
  defp process_command_result(other, _handler, _settings) do
    {:ok, :ok, inspect(other)}
  end

  # Derive a command outcome from a context. An explicit Ctx.complete/2 status
  # wins; failing that, a context carrying errors is a failure, not a success.
  @spec ctx_outcome(Ctx.t()) :: outcome()
  defp ctx_outcome(%Ctx{status: status}) when status in [:ok, :error, :warning], do: status
  defp ctx_outcome(%Ctx{errors: [_ | _]}), do: :error
  defp ctx_outcome(%Ctx{}), do: :ok

  # Apply legacy formatting for string outputs
  defp apply_legacy_formatting(output, _settings) when is_binary(output) do
    # Apply callbacks if they exist
    if Callbacks.has_callbacks?(:format_output) do
      Callbacks.execute(:format_output, output)
    else
      output
    end
  end

  @doc """
  Determines if help should be shown for a command with the given arguments.

  Delegates to the centralized Help module for consistent behavior.

  ## Parameters
    - handler: Command handler module
    - args: Command arguments from Optimus.parse

  ## Returns
    - true if help should be displayed, false otherwise
  """
  def should_show_help_for_command?(handler, args) do
    # Use the centralized help system
    Arca.Cli.Help.should_show_help?(nil, args, handler)
  end

  @doc """
  Checks if command arguments are empty.

  Delegates to the centralized Help module for consistent behavior.

  ## Parameters
    - args: Command arguments from Optimus.parse

  ## Returns
    - true if arguments are empty, false otherwise
  """
  def is_empty_command_args?(args) do
    Arca.Cli.Help.is_empty_command_args?(args)
  end

  @doc """
  Creates a standardized error tuple with the given error type and reason.

  ## Parameters
    - error_type: The type of error (atom)
    - reason: Description or data about the error

  ## Returns
    - An error tuple of the form {:error, error_type, reason}
  """
  @spec create_error(error_type(), term()) :: error_tuple()
  def create_error(error_type, reason) do
    {:error, error_type, reason}
  end

  @doc """
  Handle an error nicely and return a formatted error message.

  ## Parameters
    - cmd: Command name that caused the error (atom, string, or list)
    - reason: Error reason (any type)
    - error_type: Optional error type (defaults to :unknown_error)

  ## Returns
    - String containing formatted error message
  """
  # Handle error tuples directly
  @spec format_error(error_tuple()) :: String.t()
  def format_error({:error, error_type, reason}) do
    format_error_with_type(reason, error_type)
  end

  # Define function head with default parameter
  @spec handle_error(atom() | [String.t()] | String.t(), term(), error_type()) :: String.t()
  def handle_error(cmd, reason, error_type \\ :unknown_error)

  # Handle atom command with error type
  def handle_error(cmd, reason, error_type) when is_atom(cmd) do
    handle_error([Atom.to_string(cmd)], reason, error_type)
  end

  # Handle command with list of reasons or single reason
  def handle_error(cmd, reason, _error_type) when is_list(cmd) do
    ("error: " <> Enum.join(cmd, " ") <> ": " <> format_reason(reason))
    |> String.trim()
  end

  # Handle string command with any reason
  def handle_error(cmd, reason, error_type) when is_binary(cmd) do
    # Special case for command not found errors
    message =
      if error_type == :command_not_found || (is_binary(reason) && reason =~ "unknown command") do
        similar_commands = find_similar_commands(cmd)
        format_command_not_found_error(cmd, reason, similar_commands)
      else
        "error: #{cmd}: #{format_reason(reason)}"
      end

    message |> String.trim()
  end

  # Handle error with just error type and reason
  @spec format_error_with_type(term(), error_type()) :: String.t()
  defp format_error_with_type(reason, error_type) do
    prefix = error_type_to_prefix(error_type)
    "#{prefix}: #{format_reason(reason)}" |> String.trim()
  end

  # Convert error type to human-readable prefix
  @spec error_type_to_prefix(error_type()) :: String.t()
  defp error_type_to_prefix(:command_not_found), do: "error: command not found"
  defp error_type_to_prefix(:command_failed), do: "error: command failed"
  defp error_type_to_prefix(:invalid_argument), do: "error: invalid argument"
  defp error_type_to_prefix(:config_error), do: "error: configuration error"
  defp error_type_to_prefix(:file_not_found), do: "error: file not found"
  defp error_type_to_prefix(:file_not_readable), do: "error: file not readable"
  defp error_type_to_prefix(:file_not_writable), do: "error: file not writable"
  defp error_type_to_prefix(:decode_error), do: "error: decode error"
  defp error_type_to_prefix(:encode_error), do: "error: encode error"
  defp error_type_to_prefix(_), do: "error"

  # Format command not found errors with suggestions and namespace handling
  @spec format_command_not_found_error(String.t(), term(), [String.t()]) :: String.t()
  defp format_command_not_found_error(cmd, reason, similar_commands) do
    # Handle namespaces more elegantly
    cond do
      !String.contains?(cmd, ".") &&
          Enum.any?(similar_commands, &String.starts_with?(&1, "#{cmd}.")) ->
        namespace_commands =
          similar_commands
          |> Enum.filter(&String.starts_with?(&1, "#{cmd}."))
          |> Enum.sort()

        # This is a namespace prefix, show available commands in this namespace
        "#{cmd} is a command namespace. Available commands:\n#{Enum.join(namespace_commands, ", ")}\n" <>
          "Try '#{cmd}.<command>' to run a specific command in this namespace."

      true ->
        # Standard error with suggestions
        if Enum.empty?(similar_commands) do
          "error: #{cmd}: #{format_reason(reason)}"
        else
          namespaced_hint =
            if Enum.any?(similar_commands, &String.contains?(&1, ".")) do
              "\nHint: Commands can use dot notation for namespaces (e.g., 'sys.info', 'dev.deps')"
            else
              ""
            end

          "error: #{cmd}: #{format_reason(reason)}\nDid you mean one of these? #{Enum.join(similar_commands, ", ")}#{namespaced_hint}"
        end
    end
  end

  # Helper to find similar commands for better error messages
  @spec find_similar_commands(String.t()) :: [String.t()]
  defp find_similar_commands(cmd) do
    all_command_names =
      commands()
      |> Enum.map(fn module ->
        {cmd_atom, _opts} = apply(module, :config, []) |> List.first()
        Atom.to_string(cmd_atom)
      end)

    # First check if this might be a namespace reference
    namespace_matches =
      all_command_names
      |> Enum.filter(&String.starts_with?(&1, cmd <> "."))

    # Also look for commands that are similar
    similarity_matches =
      all_command_names
      |> Enum.filter(fn candidate ->
        String.jaro_distance(cmd, candidate) > 0.7 ||
          (String.contains?(candidate, ".") &&
             String.jaro_distance(cmd, String.split(candidate, ".") |> List.last()) > 0.7)
      end)

    (namespace_matches ++ similarity_matches)
    |> Enum.uniq()
    |> Enum.sort()
    # Limit to reasonable number of suggestions
    |> Enum.take(5)
  end

  # Handle RuntimeError exception
  @spec handle_error(RuntimeError.t()) :: String.t()
  def handle_error(%RuntimeError{message: message}), do: handle_error(message)

  # Handle list of reasons without command
  @spec handle_error([String.t()]) :: String.t()
  def handle_error(reasons) when is_list(reasons) do
    ("error: " <> Enum.join(reasons, " "))
    |> String.trim()
  end

  # Handle string reason without command
  @spec handle_error(String.t()) :: String.t()
  def handle_error(reason) when is_binary(reason) do
    "error: #{reason}"
    |> String.trim()
  end

  # Handle enhanced error tuple with debug information
  @spec handle_error(Arca.Cli.ErrorHandler.enhanced_error()) :: String.t()
  def handle_error({:error, error_type, reason, debug_info}) do
    # Check if debug mode is enabled
    debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)

    # Use the ErrorHandler to format the error with debug information when enabled
    Arca.Cli.ErrorHandler.format_error({:error, error_type, reason, debug_info},
      debug: debug_enabled
    )
  end

  # Handle standard error tuple (Railway-Oriented Programming)
  @spec handle_error(error_tuple()) :: String.t()
  def handle_error({:error, error_type, reason}) do
    # For backward compatibility, use the existing format_error_with_type function
    format_error_with_type(reason, error_type)
  end

  # Handle any other error type
  @spec handle_error(term()) :: String.t()
  def handle_error(reason) do
    "error: #{inspect(reason)}"
    |> String.trim()
  end

  # Private helper to format error reasons consistently
  @spec format_reason(term()) :: String.t()
  defp format_reason(reason) when is_list(reason), do: Enum.join(reason, " ")
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  @doc """
  Load settings from configuration.

  Uses the Arca.Config server to retrieve the entire configuration.
  Assumes all configuration dependencies are properly initialized.

  ## Returns
    - {:ok, settings} with settings map on success
    - {:error, reason} on error to maintain compatibility
  """
  @spec load_settings() :: {:ok, map()} | {:error, String.t()}
  def load_settings() do
    if Code.ensure_loaded?(Mix) && Mix.env() == :test do
      test_settings = Application.get_env(:arca_cli, :test_settings, %{})
      {:ok, test_settings}
    else
      case Arca.Config.Server.reload() do
        {:ok, config} -> {:ok, config}
        {:error, reason} -> {:error, "Failed to load configuration: #{inspect(reason)}"}
      end
    end
  rescue
    e ->
      Logger.error("Error loading settings: #{inspect(e)}")
      {:error, "Configuration loading failed: #{inspect(e)}"}
  end

  # Helper function to safely return empty settings
  @doc """
  Load configuration phase for OTP start phases.

  This function should be called during the :load_config start phase to:
  - Load settings from Arca.Config
  - Load settings from Multiplyer.Config
  - Register config callbacks
  - Initialize CLI configuration state

  ## Returns
    - :ok on success
    - {:error, reason} on failure
  """
  @spec load_config_phase() :: :ok | {:error, term()}
  def load_config_phase do
    with :ok <- ensure_dependency_phases_loaded(),
         {:ok, _settings} <- load_settings(),
         :ok <- register_config_callbacks() do
      :ok
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  rescue
    e -> {:error, {"Configuration phase failed", e}}
  end

  # Ensure dependency configuration phases are loaded
  defp ensure_dependency_phases_loaded do
    with :ok <- call_if_available(Arca.Config, :load_config_phase, []),
         :ok <- call_if_available(Multiplyer.Config.Server, :load_config_phase, []) do
      :ok
    end
  end

  # Safely call a function if the module is available
  defp call_if_available(module, function, args) do
    if Code.ensure_loaded?(module) && function_exported?(module, function, length(args)) do
      try do
        apply(module, function, args)
      rescue
        e -> {:error, e}
      end
    else
      :ok
    end
  end

  @doc """
  Get a setting by its id.

  Includes checks to prevent circular dependencies during initialization.
  If called during startup, it will return appropriate defaults.

  ## Parameters
    - id: The setting identifier

  ## Returns
    - {:ok, value} with the setting value on success
    - {:error, reason} if setting couldn't be retrieved (for backward compatibility)
  """
  @spec get_setting(atom() | String.t()) :: {:ok, term()} | {:error, String.t()}
  def get_setting(id) do
    id_str = to_string(id)

    # In test environment, get from application env
    if Code.ensure_loaded?(Mix) && Mix.env() == :test do
      test_settings = Application.get_env(:arca_cli, :test_settings, %{})

      case Map.fetch(test_settings, id_str) do
        {:ok, value} ->
          {:ok, value}

        :error ->
          {:error, "Setting not found: #{id_str}"}
      end
    else
      try do
        if config_available?() do
          id_str
          |> Arca.Config.get()
          |> case do
            {:ok, value} -> {:ok, value}
            {:error, :not_found} -> {:error, "Setting not found: #{id_str}"}
            {:error, reason} -> {:error, "Failed to get setting #{id_str}: #{inspect(reason)}"}
          end
        else
          get_default_setting(id_str)
        end
      rescue
        e ->
          Logger.error("Error getting setting #{id_str}: #{inspect(e)}")
          get_default_setting(id_str)
      end
    end
  end

  # Return appropriate defaults for known settings
  defp get_default_setting(id_str) do
    case id_str do
      # Define defaults for common settings
      "repl_settings" -> {:ok, %{"prompt" => "cli> ", "history_size" => 100}}
      "display_options" -> {:ok, %{"color" => true, "format" => "default"}}
      "callbacks" -> {:ok, %{}}
      # For any other setting, return a not-found error
      _ -> {:error, "Setting not found during initialization: #{id_str}"}
    end
  end

  @doc """
  Save settings to configuration.

  Uses Arca.Config to save settings with proper error handling.
  Includes guards against circular dependencies during initialization.

  ## Parameters
    - new_settings: Map containing settings to be saved

  ## Returns
    - {:ok, updated_settings} on success
    - {:error, reason} on failure (for backward compatibility)
  """
  @spec save_settings(map()) :: {:ok, map()} | {:error, String.t()}
  def save_settings(new_settings) do
    if Code.ensure_loaded?(Mix) && Mix.env() == :test do
      current_settings = Application.get_env(:arca_cli, :test_settings, %{})
      updated_settings = Map.merge(current_settings, new_settings)
      Application.put_env(:arca_cli, :test_settings, updated_settings)
      {:ok, updated_settings}
    else
      if config_available?() do
        new_settings
        |> save_settings_individually()
        |> case do
          :ok -> {:ok, new_settings}
          {:error, reason} -> {:error, "Failed to save settings: #{inspect(reason)}"}
        end
      else
        {:error, "Arca.Config not available - settings not saved"}
      end
    end
  end

  # Save settings one by one with robust error handling
  defp save_settings_individually(settings) do
    settings
    |> Enum.reduce_while(:ok, fn {key, value}, _acc ->
      try do
        case Arca.Config.put(key, value) do
          {:ok, _} -> {:cont, :ok}
          error -> {:halt, error}
        end
      rescue
        e ->
          Logger.error("Error saving setting #{key}: #{inspect(e)}")
          {:halt, {:error, "Failed to save setting #{key}: #{inspect(e)}"}}
      end
    end)
  end

  @doc """
  Print an about message
  """
  def intro(args \\ [], settings \\ nil)

  def intro(_args, _settings) do
    about() <> "\n" <> description() <> "\n" <> url() <> "\n" <> name() <> " " <> version()
  end

  # Accessors for string constants set via config
  def about do
    Application.fetch_env!(:arca_cli, :about)
  end

  def url do
    Application.fetch_env!(:arca_cli, :url)
  end

  def name do
    Application.fetch_env!(:arca_cli, :name)
  end

  def description do
    Application.fetch_env!(:arca_cli, :description)
  end

  @doc """
  The CLI's version.

  Resolves from `config :arca_cli, :version` when an app sets one, and otherwise
  from the application spec -- which mix generates from the VERSION file. There is
  no hardcoded fallback: a version string that can drift from the real version is
  worse than no version at all.
  """
  @spec version() :: String.t()
  def version do
    case Application.fetch_env(:arca_cli, :version) do
      {:ok, configured} -> to_string(configured)
      :error -> Arca.Cli.Configurator.BaseConfigurator.app_version(:arca_cli)
    end
  end

  @doc """
  Generate filtered help text that excludes commands with hidden: true
  """
  def generate_filtered_help(_optimus) do
    # Get commands and filter out hidden ones
    # Only non-hidden commands
    visible_commands = commands(false)

    # Format the header like Optimus.Help.help does, but use "cli" for the name
    # This provides consistency in the USAGE section
    header = [
      "USAGE:",
      "    cli ...",
      "    cli --version",
      "    cli --help",
      "    cli help subcommand",
      "",
      "SUBCOMMANDS:",
      ""
    ]

    # Check if sorting is enabled (default: true)
    # Get this from the first configurator in the list for simplicity
    should_sort =
      case configurators() do
        [first_configurator | _] -> first_configurator.sorted()
        # Default to true if no configurators
        _ -> true
      end

    # Get command names and descriptions
    commands_with_descriptions =
      visible_commands
      |> Enum.map(fn module ->
        {cmd_atom, opts} = apply(module, :config, []) |> List.first()
        name = Atom.to_string(cmd_atom)
        about = Keyword.get(opts, :about, "")
        {name, about}
      end)
      # Sort by name (alphabetically) if sorting is enabled
      |> maybe_sort_commands(should_sort)

    # Calculate the maximum command name length to ensure proper alignment
    max_name_length =
      commands_with_descriptions
      |> Enum.map(fn {name, _} -> String.length(name) end)
      |> Enum.max(fn -> 0 end)

    # Add 2 spaces of padding after the longest command name
    padding_width = max_name_length + 2

    # Format the command list with dynamic padding
    command_list =
      commands_with_descriptions
      |> Enum.map(fn {name, about} ->
        padding = String.duplicate(" ", max(0, padding_width - String.length(name)))
        "    #{name}#{padding}#{about}"
      end)

    # Combine header and command list
    header ++ command_list
  end

  def author do
    Application.fetch_env!(:arca_cli, :author)
  end

  def prompt_symbol do
    # Check if a prompt_fun is configured
    case Application.get_env(:arca_cli, :prompt_fun) do
      nil ->
        # Fall back to static prompt_symbol
        Application.fetch_env!(:arca_cli, :prompt_symbol)

      fun when is_function(fun, 0) ->
        # Call the function to get dynamic prompt
        fun.()

      _ ->
        # Invalid prompt_fun, fall back to static
        Application.fetch_env!(:arca_cli, :prompt_symbol)
    end
  end

  @doc """
  Generate the REPL prompt string with optional custom text.

  This function supports three configuration modes:
  1. Not configured (nil) - Returns default prompt format for backward compatibility
  2. Static string - Prepends the string to the default prompt
  3. Dynamic function - Delegates full prompt generation to the function

  ## Parameters
    - context: Map containing:
      - config_domain: The configured domain (atom or nil)
      - history_count: Current history count (integer)
      - history_cmds: List of all history commands (list of strings)
      - prompt_symbol: The configured prompt symbol (string)

  ## Returns
    - Complete prompt string ready for display

  ## Examples
      # No configuration - default behavior
      iex> Arca.Cli.prompt_text(%{prompt_symbol: "🔥", history_count: 0})
      "\\n🔥 0 > "

      # Static string configuration would return:
      # "\\nmyapp 🔥 0 > "

      # Dynamic function configuration would delegate to the function:
      # config :arca_cli, prompt_text: &MyApp.get_prompt/1
      # Function receives full context and returns complete prompt string
  """
  @spec prompt_text(map()) :: String.t()
  def prompt_text(context \\ %{}) do
    # Extract values from context with defaults
    prompt_symbol = Map.get(context, :prompt_symbol, ">")
    history_count = Map.get(context, :history_count, 0)

    case Application.get_env(:arca_cli, :prompt_text) do
      nil ->
        # Not configured - return default prompt format
        "\n#{prompt_symbol} #{history_count} > "

      text when is_binary(text) ->
        # Static text configuration - prepend to default format
        "\n#{text} #{prompt_symbol} #{history_count} > "

      fun when is_function(fun, 1) ->
        # Dynamic function configuration - function handles entire prompt
        try do
          result = fun.(context)

          if is_binary(result) do
            result
          else
            # Fallback to default if function returns non-string
            "\n#{prompt_symbol} #{history_count} > "
          end
        rescue
          error ->
            Logger.warning("Error calling prompt_text function: #{inspect(error)}")
            # Fallback to default prompt on error
            "\n#{prompt_symbol} #{history_count} > "
        end

      _ ->
        # Invalid configuration - fall back to default
        Logger.warning("Invalid prompt_text configuration - must be nil, string, or function/1")
        "\n#{prompt_symbol} #{history_count} > "
    end
  end

  # Helper function to conditionally sort commands
  defp maybe_sort_commands(commands, true) do
    # Sort alphabetically when sorting is enabled
    Enum.sort_by(commands, fn {name, _} -> String.downcase(name) end)
  end

  defp maybe_sort_commands(commands, false) do
    # Keep original order when sorting is disabled
    commands
  end
end
