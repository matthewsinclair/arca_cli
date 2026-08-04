# ----
# Everything required for a mimimal  example app.
# ----

defmodule Eg.Cli do
  @moduledoc """
  A simple example CLI that uses .
  """

  @doc """
  Entry point for command line parsing (just pass up to ).

  This is the canonical downstream escript pattern: a project points its
  `escript: [main_module: Eg.Cli]` at this, and inherits Arca.Cli's exit-code
  behaviour without any code of its own.
  """
  def main(argv) do
    Arca.Cli.main(argv)
  end

  @doc """
  Non-halting entry point, for running the CLI inside a host VM (eg tests).
  """
  def run(argv) do
    Arca.Cli.run(argv)
  end
end

defmodule Eg.Cli.EgCommand do
  @moduledoc """
  A simple example command to test  commands.
  """
  import Arca.Cli.Utils
  use Arca.Cli.Command.BaseCommand

  config :eg,
    name: "eg",
    about: "An example command"

  @doc """
  Ech the name of the command.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(_args, _settings, _optimus) do
    Arca.Cli.Utils.this_fn_as_string()
  end
end

defmodule Eg.Cli.EgwithparamCommand do
  @moduledoc """
  A simple example command to test  commands with params.
  """
  use Arca.Cli.Command.BaseCommand

  config :egwithparam,
    name: "egwithparam",
    about: "An example command with a paramater",
    args: [
      p1: [
        value_name: "P1",
        help: "A paramater to pass to the example command",
        required: true,
        parser: :string
      ]
    ]

  @doc """
  Return the paramater passed into the example command
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, _settings, _optimus) do
    Arca.Cli.Utils.this_fn_as_string(args.args.p1)
  end
end

defmodule Eg.Cli.EgsubCommand do
  @moduledoc """
  A simple example command to test  nested sub-commands.
  """
  import Arca.Cli.Utils
  use Arca.Cli.Command.BaseCommand
  use Arca.Cli.Command.BaseSubCommand

  config :egsub,
    name: "egsub",
    about: "An example nested sub command",
    args: [
      cmd: [
        value_name: "CMD",
        help: "one | two | ...",
        required: true,
        parser: :string
      ],
      args: [
        value_name: "ARGS",
        help: "*",
        required: false,
        parser: :string
      ]
    ],
    sub_commands: [
      Eg.Cli.EgsuboneCommand
    ]
end

defmodule Eg.Cli.EgsuboneCommand do
  @moduledoc """
  A simple example command to test  sub commands.
  """
  use Arca.Cli.Command.BaseCommand
  import Arca.Cli.Utils

  config :egsubone,
    name: "egsubone",
    about: "Sub one.",
    args: [
      p1: [
        value_name: "p1",
        help: "Parameter One",
        required: false,
        parser: :string
      ]
    ]

  @doc """
  SuboneCommand
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, _settings, _optimus) do
    this_fn_as_string(args.p1)
  end
end

defmodule Eg.Cli.EgConfigurator do
  @moduledoc """
  `Eg.Cli.Commands.Configurator` sets up the Eg.Cli commands in a Configurator.
  """
  use Arca.Cli.Configurator.BaseConfigurator

  config :eg_cli,
    commands: [
      Eg.Cli.EgCommand,
      Eg.Cli.EgwithparamCommand,
      Eg.Cli.EgsubCommand
    ],
    author: "hello@eg.cli",
    about: "The simplest Arca CLI Example",
    description: "eg_cli is the simplest, fully worked Arca CLI example",
    version: "0.0.1"
end

# ----
# Test the mimimal  example app.
# ----

defmodule Eg.Cli.Test do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @cli_commands [
    ["eg"],
    ["egwithparam", "p1"],
    ["egsub", "egsubone", "p1"]
  ]

  describe "Eg.Cli" do
    setup do
      # Get previous env var for config path and file names
      previous_configurators = Application.get_env(:arca_cli, :configurators)

      Application.put_env(:arca_cli, :configurators, [
        Eg.Cli.EgConfigurator
      ])

      # Put things back how we found them
      on_exit(fn -> Application.put_env(:arca_cli, :configurators, previous_configurators) end)

      :ok
    end

    test "eg_cli commands smoke test" do
      # Expected results for each command
      expected_output = %{
        "eg" => "Eg.Cli.EgCommand.handle/3",
        "egwithparam" => "Eg.Cli.EgwithparamCommand.handle/3: p1",
        "egsub" => "Eg.Cli.EgsuboneCommand.handle/3: p1"
      }

      # Run through each command and smoke test each one
      Enum.each(@cli_commands, fn cmd ->
        [cmd_string | _] = cmd
        # Smoke testing example command: #{Enum.join(cmd, " ")}

        res =
          capture_io(fn ->
            try do
              Eg.Cli.run(cmd)
            rescue
              e in RuntimeError ->
                IO.puts("error: " <> e.message)
                assert false
            end
          end)
          |> String.trim()

        assert Map.get(expected_output, cmd_string) =~ res
      end)
    end
  end
end
