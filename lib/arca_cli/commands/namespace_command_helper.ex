defmodule Arca.Cli.Commands.NamespaceCommandHelper do
  @moduledoc ~S"""
  Provides helper macros to simplify creating namespaced (dot notation) commands.

  ## Usage Example

  ```elixir
  defmodule MyApp.Cli.Commands.Dev do
    use Arca.Cli.Commands.NamespaceCommandHelper

    namespace_command :info, "Display development environment information" do
      "Elixir #{System.version()} on OTP #{:erlang.system_info(:otp_release)}"
    end

    namespace_command :deps, "List loaded applications" do
      Application.loaded_applications()
      |> Enum.map_join("\n", fn {app, _description, vsn} -> "#{app} #{vsn}" end)
    end
  end
  ```

  This generates, alongside the calling module:

  - `MyApp.Cli.Commands.DevInfoCommand`, with command name `dev.info`
  - `MyApp.Cli.Commands.DevDepsCommand`, with command name `dev.deps`

  The generated modules live beside the caller rather than in
  `Arca.Cli.Commands`, so two applications can each define a `dev` namespace
  without one silently redefining the other's modules.
  """

  @doc """
  Main macro for use statements that sets up the namespace from the module name.

  Extracts the namespace from the last part of the module name:
  - `MyApp.CLI.Commands.Dev` becomes namespace `dev`
  - `MyApp.CLI.Commands.System` becomes namespace `system`
  """
  defmacro __using__(_opts) do
    quote do
      import Arca.Cli.Commands.NamespaceCommandHelper, only: [namespace_command: 3]

      @namespace __MODULE__ |> Module.split() |> List.last() |> String.downcase()

      # Where generated command modules are placed: beside the calling module, so
      # they carry the caller's namespace rather than Arca's.
      @namespace_parent __MODULE__ |> Module.split() |> Enum.drop(-1)
    end
  end

  @doc """
  Generates a new command module in the current namespace.

  ## Parameters

  - `name`: The name of the command (without namespace)
  - `description`: The command description for help text
  - `do` block: The body evaluated when the command runs. The generated `handle/3`
    returns the block's value.

  ## Example

  ```elixir
  namespace_command :info, "Display info" do
    "Some information: " <> System.version()
  end
  ```
  """
  defmacro namespace_command(name, description, do: block) do
    quote do
      command_name = :"#{@namespace}.#{unquote(name)}"

      module_name =
        Module.concat(
          @namespace_parent ++
            [
              "#{String.capitalize(@namespace)}" <>
                "#{String.capitalize(to_string(unquote(name)))}Command"
            ]
        )

      defmodule module_name do
        @moduledoc """
        Namespaced command: #{command_name}

        #{unquote(description)}
        """
        use Arca.Cli.Command.BaseCommand

        config command_name,
          name: to_string(command_name),
          about: unquote(description)

        @impl Arca.Cli.Command.CommandBehaviour
        def handle(_args, _settings, _optimus) do
          unquote(block)
        end
      end
    end
  end
end
