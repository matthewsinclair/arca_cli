defmodule Arca.Cli.Configurator.TruthfulnessTest do
  @moduledoc """
  Covers the configurator contract: configuration that is set must take effect,
  configuration that is broken must fail loudly, and parse and dispatch must
  never disagree about what a command name means.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Configurator.Coordinator

  # A configurator that turns every boolean option off. The bug was that `false`
  # was indistinguishable from unset, so all three were coerced back to true.
  defmodule StrictConfigurator do
    use Arca.Cli.Configurator.BaseConfigurator

    config :strict_cli,
      commands: [],
      about: "strict",
      allow_unknown_args: false,
      parse_double_dash: false,
      sorted: false
  end

  # A configurator that declares nothing beyond its commands, to pin the defaults.
  defmodule DefaultsConfigurator do
    use Arca.Cli.Configurator.BaseConfigurator

    config :defaults_cli, commands: []
  end

  defmodule BrokenConfigurator do
    @behaviour Arca.Cli.Configurator.ConfiguratorBehaviour

    @impl true
    def commands, do: []

    @impl true
    def create_base_config, do: raise("this configurator is deliberately broken")

    @impl true
    def setup, do: create_base_config()

    @impl true
    def name, do: "broken"

    @impl true
    def author, do: ""

    @impl true
    def about, do: ""

    @impl true
    def description, do: ""

    @impl true
    def version, do: "0.0.0"

    @impl true
    def allow_unknown_args, do: true

    @impl true
    def parse_double_dash, do: true

    @impl true
    def sorted, do: true
  end

  describe "explicit false is honoured" do
    test "success: config/0 reports every explicitly disabled option as false" do
      config = StrictConfigurator.config()

      assert config.allow_unknown_args == false
      assert config.parse_double_dash == false
      assert config.sorted == false
    end

    test "success: the accessor functions report false too" do
      assert StrictConfigurator.allow_unknown_args() == false
      assert StrictConfigurator.parse_double_dash() == false
      assert StrictConfigurator.sorted() == false
    end

    test "success: Optimus receives the disabled options" do
      base_config = StrictConfigurator.create_base_config()

      assert base_config[:allow_unknown_args] == false
      assert base_config[:parse_double_dash] == false
    end

    test "invariant: undeclared options still default to true" do
      config = DefaultsConfigurator.config()

      assert config.allow_unknown_args == true
      assert config.parse_double_dash == true
      assert config.sorted == true
    end
  end

  describe "broken configurator fails loudly" do
    test "failure: setup raises, naming the failure, rather than substituting a fallback" do
      assert_raise ArgumentError, ~r/configurator setup failed/, fn ->
        Coordinator.setup([BrokenConfigurator])
      end
    end

    test "invariant: the app's command set is never silently replaced by the default one" do
      # The old behaviour returned DftConfigurator's Optimus config here, so a
      # broken configurator produced a CLI that ran with the wrong commands.
      result =
        try do
          Coordinator.setup([BrokenConfigurator])
        rescue
          _ -> :raised
        end

      assert result == :raised
    end
  end

  describe "duplicate command names resolve consistently" do
    defmodule First.DupCommand do
      use Arca.Cli.Command.BaseCommand

      config :dup, name: "dup", about: "first registration"

      @impl true
      def handle(_args, _settings, _optimus), do: "first"
    end

    defmodule Second.DupCommand do
      use Arca.Cli.Command.BaseCommand

      config :dup, name: "dup", about: "second registration"

      @impl true
      def handle(_args, _settings, _optimus), do: "second"
    end

    test "success: dispatch resolves a duplicate command to the last registered module" do
      commands = [First.DupCommand, Second.DupCommand]

      assert Arca.Cli.handler_for_command(:dup, commands) ==
               {:ok, :dup, Second.DupCommand}
    end

    test "invariant: reversing registration order reverses the winner" do
      commands = [Second.DupCommand, First.DupCommand]

      assert Arca.Cli.handler_for_command(:dup, commands) ==
               {:ok, :dup, First.DupCommand}
    end

    test "invariant: parse and dispatch pick the same registration" do
      # Optimus merges subcommands last-wins; dispatch must agree, or a command
      # parses against one module's spec and runs another module's code.
      merged =
        Coordinator.merge_subcommands(
          [dup: [name: "dup", about: "first registration"]],
          dup: [name: "dup", about: "second registration"]
        )

      {:ok, :dup, dispatch_winner} =
        Arca.Cli.handler_for_command(:dup, [First.DupCommand, Second.DupCommand])

      assert merged[:dup][:about] == "second registration"
      assert dispatch_winner == Second.DupCommand
    end
  end
end
