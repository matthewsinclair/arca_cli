defmodule Arca.Cli.Commands.ParamTestCommand do
  use Arca.Cli.Command.BaseCommand

  config :paramtest,
    name: "param_test",
    about: "A test command for parameter parsing",
    allow_unknown_args: true,
    args: [
      text: [
        value_name: "TEXT",
        help: "Text argument that may contain spaces or quotes",
        required: true
      ],
      optional: [
        value_name: "OPTIONAL",
        help: "Optional second argument",
        required: false
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    # Return the raw args for inspection in tests
    {:ok, args}
  end
end

defmodule Arca.Cli.Commands.ParamParsingTest do
  use ExUnit.Case
  alias Arca.Cli.Commands.ParamTestCommand

  describe "parameter parsing tests" do
    setup do
      # Get the command configuration and create an Optimus instance for testing
      [{cmd_name, cmd_config}] = ParamTestCommand.config()

      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: [
          {cmd_name, cmd_config}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      %{optimus: optimus, cmd_name: cmd_name}
    end

    test "simple parameter parsing", %{optimus: optimus} do
      args = ["param_test", "simple"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:paramtest]

      # Assert the parameter was correctly parsed
      assert parse_result.args.text == "simple"
    end

    test "parameter with spaces using multiple args", %{optimus: optimus} do
      # In CLI, quotes would be preserved by the shell
      args = ["param_test", "text", "with", "spaces"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:paramtest]

      # Verify how Optimus handles multiple words without quotes
      assert parse_result.args.text == "text"
      assert parse_result.args.optional == "with"
      # Extra words become unknown args
      assert parse_result.unknown == ["spaces"]
    end

    test "parameter with spaces as a single argument", %{optimus: optimus} do
      # This simulates a properly shell-quoted string passed to the CLI
      args = ["param_test", "text with spaces"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Shell would preserve this as a single argument
      {_subcommand, parse_result} = parsed
      assert parse_result.args.text == "text with spaces"
      assert parse_result.args.optional == nil
      assert parse_result.unknown == []
    end

    # Simulating how it would be handled in REPL mode
    test "simulated REPL handling of parameters with spaces" do
      # In the REPL, the input would be a single string like:
      repl_input = "param_test text with spaces"

      # Then it gets split into args
      args = repl_input |> String.trim() |> String.split()

      # Add the settings and optimus from setup
      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: [
          {:paramtest, ParamTestCommand.config() |> List.first() |> elem(1)}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      # Parse the arguments using Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the parsed arguments
      {_subcommand, parse_result} = parsed

      # This should reflect how the REPL actually handles it - words are split
      assert parse_result.args.text == "text"
      assert parse_result.args.optional == "with"
      assert parse_result.unknown == ["spaces"]
    end

    test "simulated REPL handling with quoted parameters (current behavior)" do
      # Simulating the string direct from stdin in REPL mode
      repl_input = "param_test \"text with spaces\""

      # The current implementation splits by whitespace, ignoring quotes
      args = repl_input |> String.trim() |> String.split()

      # Setup the optimus object
      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: [
          {:paramtest, ParamTestCommand.config() |> List.first() |> elem(1)}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      # Parse the arguments using Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the parsed arguments
      {_subcommand, parse_result} = parsed

      # Demonstrate how quotes are currently not being respected
      assert parse_result.args.text == "\"text"
      assert parse_result.args.optional == "with"
      assert parse_result.unknown == ["spaces\""]
    end

    test "simulated REPL handling with improved quote-respecting splitting" do
      # Simulating the string direct from stdin in REPL mode
      repl_input = "param_test \"text with spaces\""

      # Split preserving quoted strings
      args = split_preserving_quotes(repl_input)

      # Setup the optimus object
      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: [
          {:paramtest, ParamTestCommand.config() |> List.first() |> elem(1)}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      # Parse the arguments using Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the parsed arguments
      {_subcommand, parse_result} = parsed

      # With proper quote-respecting splitting, we'd get the right result
      assert parse_result.args.text == "text with spaces"
      assert parse_result.args.optional == nil
      assert parse_result.unknown == []
    end

    test "simulated REPL with multiple quoted parameters" do
      # Simulating command with multiple quoted parameters
      repl_input = "param_test \"first quoted param\" \"second quoted param\""

      # Use our quote-preserving splitter
      args = split_preserving_quotes(repl_input)

      # Setup the optimus object
      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: [
          {:paramtest, ParamTestCommand.config() |> List.first() |> elem(1)}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      # Parse the arguments using Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the parsed arguments
      {_subcommand, parse_result} = parsed

      # Verify our quoted parameters work as expected
      assert parse_result.args.text == "first quoted param"
      assert parse_result.args.optional == "second quoted param"
      assert parse_result.unknown == []
    end
  end

  # Delegates to the real REPL quote-preserving splitter so the test exercises the
  # production tokenizer instead of a divergent copy.
  defp split_preserving_quotes(input) do
    {:ok, args} = Arca.Cli.Repl.split_args(input)
    args
  end
end
