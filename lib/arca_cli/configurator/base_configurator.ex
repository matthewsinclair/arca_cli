defmodule Arca.Cli.Configurator.BaseConfigurator do
  @moduledoc """
  Use an `Arca.Cli.Configurator.BaseConfigurator` to quickly and easily build a new Configurator for the CLI.

  ## Command Sorting

  By default, commands are displayed in alphabetical order to make them easier to find.
  You can control this behavior with the `sorted` configuration option:

  ```elixir
  config :my_app,
    commands: [...],
    sorted: true    # Default - commands are displayed in alphabetical order
  ```

  To display commands in the order they are defined:

  ```elixir
  config :my_app,
    commands: [...],
    sorted: false   # Commands are displayed in the order they're defined
  ```
  """

  @doc """
  Implement base functionality for a Configurator.
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [config: 2]

      alias Arca.Cli.Utils
      alias Arca.Cli.Configurator.BaseConfigurator
      require Logger
      @behaviour Arca.Cli.Configurator.ConfiguratorBehaviour

      Module.register_attribute(__MODULE__, :app_name, accumulate: false)
      Module.register_attribute(__MODULE__, :commands, accumulate: false)
      Module.register_attribute(__MODULE__, :author, accumulate: false)
      Module.register_attribute(__MODULE__, :about, accumulate: false)
      Module.register_attribute(__MODULE__, :description, accumulate: false)
      Module.register_attribute(__MODULE__, :version, accumulate: false)
      Module.register_attribute(__MODULE__, :allow_unknown_args, accumulate: false)
      Module.register_attribute(__MODULE__, :parse_double_dash, accumulate: false)
      Module.register_attribute(__MODULE__, :sorted, accumulate: false)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro config(app_name, opts) do
    quote do
      Module.put_attribute(__MODULE__, :app_name, unquote(app_name))
      Module.put_attribute(__MODULE__, :commands, Keyword.get(unquote(opts), :commands, []))

      Module.put_attribute(
        __MODULE__,
        :author,
        Keyword.get(unquote(opts), :author, "Arca CLI AUTHOR")
      )

      Module.put_attribute(
        __MODULE__,
        :about,
        Keyword.get(unquote(opts), :about, "Arca CLI ABOUT")
      )

      Module.put_attribute(
        __MODULE__,
        :description,
        Keyword.get(unquote(opts), :description, "Arca CLI DESCRIPTION")
      )

      Module.put_attribute(
        __MODULE__,
        :version,
        Keyword.get(unquote(opts), :version, "Arca CLI VERSION")
      )

      Module.put_attribute(
        __MODULE__,
        :allow_unknown_args,
        Keyword.get(unquote(opts), :allow_unknown_args, true)
      )

      Module.put_attribute(
        __MODULE__,
        :parse_double_dash,
        Keyword.get(unquote(opts), :parse_double_dash, true)
      )

      Module.put_attribute(
        __MODULE__,
        :sorted,
        Keyword.get(unquote(opts), :sorted, true)
      )
    end
  end

  defmacro __before_compile__(env) do
    app_name = Module.get_attribute(env.module, :app_name) || "arca_cli"
    commands = Module.get_attribute(env.module, :commands) || []
    author = Module.get_attribute(env.module, :author) || "Arca CLI AUTHOR"
    about = Module.get_attribute(env.module, :about) || "Arca CLI ABOUT"
    description = Module.get_attribute(env.module, :description) || "Arca CLI DESCRIPTION"
    version = Module.get_attribute(env.module, :version) || "Arca CLI VERSION"
    allow_unknown_args = Module.get_attribute(env.module, :allow_unknown_args) || true
    parse_double_dash = Module.get_attribute(env.module, :parse_double_dash) || true

    # Default to sorted when the attribute is unset, but honour an explicit `false`
    # (a plain `|| true` would silently coerce `sorted: false` back to `true`).
    sorted =
      case Module.get_attribute(env.module, :sorted) do
        nil -> true
        value -> value
      end

    # Select the sort behaviour at compile time so the generated function carries no
    # dead branch.
    maybe_sort_def =
      if sorted do
        quote do
          defp maybe_sort_commands(commands) do
            Enum.sort_by(commands, fn {cmd_name, _config} ->
              cmd_name |> to_string() |> String.downcase()
            end)
          end
        end
      else
        quote do
          defp maybe_sort_commands(commands), do: commands
        end
      end

    quote do
      def config do
        %{
          app_name: unquote(app_name),
          commands: unquote(commands),
          author: unquote(author),
          about: unquote(about),
          description: unquote(description),
          version: unquote(version),
          allow_unknown_args: unquote(allow_unknown_args),
          parse_double_dash: unquote(parse_double_dash),
          sorted: unquote(sorted)
        }
      end

      @doc """
      Returns the default list of `Command`s for base functionality for `Arca.Cli`.
      """
      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def commands do
        unquote(commands)
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def name do
        unquote(app_name) |> to_string()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def setup do
        create_base_config()
        |> inject_subcommands()
        |> Optimus.new!()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def author do
        unquote(author) |> to_string()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def about do
        unquote(about) |> to_string()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def description do
        unquote(description) |> to_string()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def version do
        unquote(version) |> to_string()
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def allow_unknown_args do
        unquote(allow_unknown_args)
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def parse_double_dash do
        unquote(parse_double_dash)
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def sorted do
        unquote(sorted)
      end

      @impl Arca.Cli.Configurator.ConfiguratorBehaviour
      def create_base_config do
        [
          name: name(),
          description: about() <> "\n" <> description(),
          version: version(),
          author: author(),
          allow_unknown_args: allow_unknown_args(),
          parse_double_dash: parse_double_dash(),
          subcommands: []
        ]
      end

      def inject_subcommands(optimus, commands \\ commands()) do
        # Process commands
        processed_commands =
          commands
          |> Enum.map(&get_command_config/1)
          |> maybe_sort_commands()

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

      # Sort commands alphabetically when the configurator opts in (decided at compile time).
      unquote(maybe_sort_def)

      defp merge_subcommands(existing, new) do
        existing
        |> Keyword.merge(new, fn _key, _val1, val2 -> val2 end)
      end

      defp get_command_config(command_module) do
        [{cmd, config}] = command_module.config()
        {cmd, config}
      end
    end
  end
end
