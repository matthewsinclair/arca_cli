defmodule Arca.Cli.Command.BaseSubCommand do
  @moduledoc """
  Base module for implementing subcommand functionality.

  This module provides a reusable implementation for commands that need
  to dispatch to subcommands based on arguments.

  ## Example

  ```elixir
  defmodule MyApp.Commands.SettingsCommand do
    use Arca.Cli.Command.BaseCommand
    use Arca.Cli.Command.BaseSubCommand

    config :settings,
      name: "settings",
      about: "Manage application settings",
      args: [
        cmd: [value_name: "CMD", help: "get | set", required: true, parser: :string],
        args: [value_name: "ARGS", help: "*", required: false, parser: :string]
      ],
      sub_commands: [
        MyApp.Commands.SettingsGetCommand,
        MyApp.Commands.SettingsSetCommand
      ]
  end
  ```

  Subcommands are registered through the `:sub_commands` config key, which is what
  `sub_commands/0` reads. A `@sub_commands` module attribute is not consulted.

  Arguments are passed to the subcommand parser in the order they are declared in
  `:args`, so declaration order is the order the user types them.
  """

  @typedoc """
  Possible error types that can occur during subcommand operations
  """
  @type error_type ::
          :subcommand_not_found
          | :parsing_failed
          | :invalid_arguments
          | :dispatch_error
          | :optimus_error

  @typedoc """
  Result type for subcommand operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Create a standardized error tuple
  """
  @spec create_error(error_type(), String.t()) :: {:error, error_type(), String.t()}
  def create_error(error_type, reason) do
    {:error, error_type, reason}
  end

  defmacro __using__(_) do
    quote do
      import Arca.Cli.Utils
      alias Arca.Cli.Command.BaseSubCommand
      @behaviour Arca.Cli.Command.SubCommandBehaviour

      @before_compile Arca.Cli.Command.BaseSubCommand

      @doc """
      Command handler for the subcommand. Routes to the respective handler for the subcommands.

      This implementation extracts arguments, sets up the Optimus parser for subcommands,
      parses the arguments, and dispatches to the appropriate subcommand handler.
      """
      @impl Arca.Cli.Command.CommandBehaviour
      @spec handle(map(), map(), Optimus.t()) ::
              String.t() | [String.t()] | {:ok, any()} | {:error, any()}
      def handle(args, settings, _outer_optimus) do
        with {:ok, argv} <- extract_arguments(args),
             {:ok, inner_optimus} <- create_subcommand_optimus(),
             {:ok, parse_result} <- parse_arguments(inner_optimus, argv),
             {:ok, output} <- dispatch_to_subcommand(parse_result, settings, inner_optimus) do
          filter_blank_lines(output)
        else
          # Handle error cases from any step in the with pipeline
          {:error, :invalid_arguments, reason} ->
            "Error: #{reason}"

          {:error, :parsing_failed, reason} ->
            "Parsing error: #{reason}"

          {:error, :subcommand_not_found, reason} ->
            "Command not found: #{reason}"

          {:error, error_type, reason} ->
            "Error (#{error_type}): #{reason}"
        end
      end

      @doc """
      Extract and prepare arguments from the command input.

      Converts the raw argument map to a list of argument values.
      """
      @spec extract_arguments(map()) ::
              {:ok, [String.t()]} | {:error, BaseSubCommand.error_type(), String.t()}
      def extract_arguments(args) do
        try do
          argv =
            declared_argument_order()
            |> Enum.map(&Map.get(args.args, &1))
            |> Enum.reject(&is_nil/1)

          {:ok, argv}
        rescue
          e ->
            BaseSubCommand.create_error(
              :invalid_arguments,
              "Failed to extract arguments: #{inspect(e)}"
            )
        end
      end

      # The order the command declared its arguments in.
      #
      # Rebuilding argv from `Map.values/1` used the map's own key order, which is
      # term order over the argument names -- nothing to do with the order the
      # user typed them. A reverse afterwards made the two-argument case come out
      # right often enough to look correct, and there was no third argument in
      # the repo to prove otherwise.
      @spec declared_argument_order() :: [atom()]
      defp declared_argument_order do
        [{_cmd, opts}] = __MODULE__.config()

        opts
        |> Keyword.get(:args, [])
        |> Keyword.keys()
      end

      @doc """
      Create an Optimus instance for parsing subcommands.
      """
      @spec create_subcommand_optimus() ::
              {:ok, Optimus.t()} | {:error, BaseSubCommand.error_type(), String.t()}
      def create_subcommand_optimus() do
        try do
          optimus =
            config()
            |> inject_subcommands()
            |> Optimus.new!()

          {:ok, optimus}
        rescue
          e ->
            BaseSubCommand.create_error(
              :optimus_error,
              "Failed to create Optimus parser: #{inspect(e)}"
            )
        end
      end

      @doc """
      Parse arguments using the Optimus parser.
      """
      @spec parse_arguments(Optimus.t(), [String.t()]) ::
              {:ok, {:ok, [atom()], Optimus.ParseResult.t()} | {:error, atom(), term()}}
              | {:error, BaseSubCommand.error_type(), String.t()}
      def parse_arguments(optimus, argv) do
        case Optimus.parse(optimus, argv) do
          {:ok, _commands, _parse_result} = result ->
            {:ok, result}

          {:error, reason} ->
            {:ok, {:error, :parsing_error, reason}}

          {:error, commands, reasons} ->
            {:ok, {:error, commands, reasons}}

          other ->
            BaseSubCommand.create_error(
              :parsing_failed,
              "Unexpected parse result: #{inspect(other)}"
            )
        end
      end

      @doc """
      Dispatch the command to the appropriate subcommand handler.
      """
      @spec dispatch_to_subcommand(
              {:ok, [atom()], Optimus.ParseResult.t()}
              | {:error, atom() | [atom()], term() | [term()]},
              map(),
              Optimus.t()
            ) :: {:ok, any()} | {:error, BaseSubCommand.error_type(), String.t()}
      def dispatch_to_subcommand(parse_result, settings, optimus) do
        case parse_result do
          {:ok, [subcmd], result} ->
            {:ok, handle_subcommand(subcmd, result.args, settings, optimus)}

          {:error, reason} ->
            {:ok, handle_subcommand(:error, reason, settings, optimus)}

          {:error, [cmd], [reason]} ->
            {:ok, handle_subcommand(:error, reason, settings, optimus)}

          other ->
            BaseSubCommand.create_error(
              :dispatch_error,
              "Unexpected dispatch result: #{inspect(other)}"
            )
        end
      end

      @doc """
      Dispatch to the appropriate subcommand handler, if it can be found.
      """
      @spec handle_subcommand(atom(), any(), map(), Optimus.t()) :: any()
      def handle_subcommand(cmd, args, settings, optimus) do
        case Arca.Cli.handler_for_command(cmd, sub_commands()) do
          nil ->
            Arca.Cli.handle_error([args])

          {:ok, _cmd_atom, handler} ->
            handler.handle(args, settings, optimus)
        end
      end

      @doc """
      Inject any subcommands into the provided Optimus config.
      """
      @spec inject_subcommands(keyword(), [module()]) :: keyword()
      def inject_subcommands(optimus, commands \\ sub_commands()) do
        processed_commands = Enum.map(commands, &get_command_config/1)

        {top_level_keys, subcommands} =
          Keyword.split(optimus, [
            :name,
            :description,
            :version,
            :author,
            :allow_unknown_args,
            :parse_double_dash
          ])

        merged_subcommands = merge_subcommands(subcommands[:subcommands], processed_commands)

        top_level_keys ++ [subcommands: merged_subcommands]
      end

      @doc false
      @spec merge_subcommands(keyword() | nil, keyword()) :: keyword()
      defp merge_subcommands(existing, new) do
        existing = existing || []
        Keyword.merge(existing, new, fn _key, _val1, val2 -> val2 end)
      end

      @doc false
      @spec get_command_config(module()) :: {atom(), keyword()}
      defp get_command_config(command_module) do
        [{cmd, config}] = command_module.config()
        {cmd, config}
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Return the list of subcommands that have been registered for this command.

      This implementation extracts the list from the command's configuration.
      """
      @impl Arca.Cli.Command.SubCommandBehaviour
      @spec sub_commands() :: [module()]
      def sub_commands() do
        [{cmd, config}] = __MODULE__.config()
        Keyword.get(config, :sub_commands, [])
      end
    end
  end
end
