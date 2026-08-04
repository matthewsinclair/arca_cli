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

  @known_options [
    :commands,
    :author,
    :about,
    :description,
    :version,
    :allow_unknown_args,
    :parse_double_dash,
    :sorted
  ]

  defmacro config(app_name, opts) do
    quote do
      Module.put_attribute(__MODULE__, :app_name, unquote(app_name))

      # Record only what the configurator actually declared. Defaults live in
      # exactly one place -- __before_compile__ -- so an undeclared option stays
      # distinguishable from one explicitly set to `false`, and an unrecognised
      # option is reported instead of silently doing nothing.
      for {key, value} <- unquote(opts) do
        if key in unquote(@known_options) do
          Module.put_attribute(__MODULE__, key, value)
        else
          IO.warn(
            "unknown configurator option #{inspect(key)}; known options are " <>
              inspect(unquote(@known_options))
          )
        end
      end
    end
  end

  # Read a configurator attribute, falling back to `default` only when it was never
  # set. `||` is wrong here: it also swallows an explicit `false`, which silently
  # coerced `allow_unknown_args: false` and `parse_double_dash: false` back to true.
  @spec attribute_or_default(module(), atom(), term()) :: term()
  defp attribute_or_default(module, name, default) do
    case Module.get_attribute(module, name) do
      nil -> default
      value -> value
    end
  end

  @doc """
  Resolve an application's version from its loaded application spec.

  This is the default a configurator uses when it does not declare a `:version`,
  so a CLI reports the real version of the app it belongs to rather than a
  hardcoded string that drifts.
  """
  @spec app_version(atom()) :: String.t()
  def app_version(app) when is_atom(app) do
    case Application.spec(app, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  defmacro __before_compile__(env) do
    app_name = attribute_or_default(env.module, :app_name, "arca_cli")
    commands = attribute_or_default(env.module, :commands, [])
    author = attribute_or_default(env.module, :author, "")
    about = attribute_or_default(env.module, :about, "")
    description = attribute_or_default(env.module, :description, "")
    allow_unknown_args = attribute_or_default(env.module, :allow_unknown_args, true)
    parse_double_dash = attribute_or_default(env.module, :parse_double_dash, true)
    sorted = attribute_or_default(env.module, :sorted, true)

    # An undeclared version resolves from the app spec at runtime, so it cannot drift
    # from the app's real version the way a baked-in placeholder did.
    version = Module.get_attribute(env.module, :version)
    app_atom = if is_atom(app_name), do: app_name, else: String.to_atom(app_name)

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
          version: version(),
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
        case unquote(version) do
          nil -> Arca.Cli.Configurator.BaseConfigurator.app_version(unquote(app_atom))
          declared -> to_string(declared)
        end
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
