defmodule Arca.Cli.Commands.FlagTestCommand do
  use Arca.Cli.Command.BaseCommand

  config :flagtest,
    name: "flag_test",
    about: "A test command for flag parsing",
    options: [
      short: [
        value_name: "SHORT",
        short: "-s",
        long: "--short",
        help: "A test short flag",
        parser: :string
      ],
      long: [
        value_name: "LONG",
        long: "--long",
        help: "A test long-only flag",
        parser: :string
      ]
    ],
    flags: [
      boolean: [
        short: "-b",
        long: "--boolean",
        help: "A boolean flag"
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    {:ok, args}
  end
end

defmodule Arca.Cli.Commands.FlagCommandTest do
  use ExUnit.Case
  alias Arca.Cli.Commands.FlagTestCommand

  describe "flag parsing tests" do
    setup do
      # Get the command configuration and create an Optimus instance for testing
      [{cmd_name, cmd_config}] = FlagTestCommand.config()

      optimus_config = [
        name: "test_app",
        description: "Test application",
        version: "1.0.0",
        allow_unknown_args: false,
        parse_double_dash: true,
        subcommands: [
          {cmd_name, cmd_config}
        ]
      ]

      optimus = Optimus.new!(optimus_config)

      %{optimus: optimus, cmd_name: cmd_name}
    end

    test "short flag with value parsing", %{optimus: optimus} do
      args = ["flag_test", "-s", "value"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flag was correctly parsed
      assert parse_result.options.short == "value"
    end

    test "long flag with value parsing", %{optimus: optimus} do
      args = ["flag_test", "--short", "value"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flag was correctly parsed
      assert parse_result.options.short == "value"
    end

    test "long-only flag with value parsing", %{optimus: optimus} do
      args = ["flag_test", "--long", "value"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flag was correctly parsed
      assert parse_result.options.long == "value"
    end

    test "boolean flag parsing (true)", %{optimus: optimus} do
      args = ["flag_test", "--boolean"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flag was correctly parsed as true
      assert parse_result.flags.boolean == true
    end

    test "boolean flag parsing (short form)", %{optimus: optimus} do
      args = ["flag_test", "-b"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flag was correctly parsed as true
      assert parse_result.flags.boolean == true
    end

    test "multiple flags combined", %{optimus: optimus} do
      args = ["flag_test", "-b", "--short", "value", "--long", "another"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert all flags were correctly parsed
      assert parse_result.flags.boolean == true
      assert parse_result.options.short == "value"
      assert parse_result.options.long == "another"
    end

    test "flags with equals syntax", %{optimus: optimus} do
      args = ["flag_test", "--short=value", "--long=another"]

      # Parse the arguments directly with Optimus
      parsed = Optimus.parse!(optimus, args)

      # Get the subcommand and the parsed arguments
      {subcommand, parse_result} = parsed
      assert subcommand == [:flagtest]

      # Assert the flags were correctly parsed
      assert parse_result.options.short == "value"
      assert parse_result.options.long == "another"
    end
  end
end
