defmodule Arca.Cli.Commands.DevDepsCommand do
  @moduledoc """
  Command to display project dependencies.
  This is a namespaced command using dot notation (dev.deps).
  """
  use Arca.Cli.Command.BaseCommand

  config :"dev.deps",
    name: "dev.deps",
    about: "Display project dependencies."

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(_args, _settings, _optimus) do
    deps = get_deps()
    header = "Project Dependencies:\n"

    deps_list =
      deps
      |> Enum.map(fn {app, version} -> "  #{app}: #{version}" end)
      |> Enum.join("\n")

    header <> deps_list
  end

  defp get_deps do
    try do
      deps = Mix.Project.config()[:deps]

      deps
      |> Enum.map(fn
        {app, requirement} when is_binary(requirement) ->
          {app, requirement}

        {app, opts} when is_list(opts) ->
          version =
            Keyword.get(opts, :tag) || Keyword.get(opts, :branch) || Keyword.get(opts, :ref) ||
              "latest"

          {app, version}

        {app, _version, opts} when is_list(opts) ->
          version =
            Keyword.get(opts, :tag) || Keyword.get(opts, :branch) || Keyword.get(opts, :ref) ||
              "latest"

          {app, version}

        {app, _version} ->
          {app, "latest"}

        app when is_atom(app) ->
          {app, "latest"}
      end)
      |> Enum.sort_by(fn {app, _} -> app end)
    rescue
      _ ->
        # Fallback when Mix.Project.config() isn't available (in escript)
        [
          {:ok, "~> 2.3"},
          {:optimus, "~> 0.2"},
          {:castore, "~> 1.0"},
          {:jason, "~> 1.4"},
          {:ex_doc, "dev"},
          {:owl, "~> 0.12"},
          {:ucwidth, "~> 0.2"},
          {:pathex, "~> 2.5"},
          {:table_rex, "~> 4.0"},
          {:elixir_uuid, "~> 1.2"},
          {:ex_prompt, "~> 0.1.3"}
        ]
    end
  end
end
