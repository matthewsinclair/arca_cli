defmodule Arca.Cli.Commands.DevDepsCommand do
  @moduledoc """
  Command to display the applications loaded in this deployment.
  This is a namespaced command using dot notation (dev.deps).

  The list comes from `Application.loaded_applications/0`, which is what the VM is
  actually running. The previous implementation read the dependency list out of
  `Mix.Project.config/0` and, when Mix was absent -- which is to say, in every
  built escript -- fell back to a list of names and versions written by hand. That
  fallback answered confidently and wrongly, which is worse than not answering.
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :"dev.deps",
    name: "dev.deps",
    about: "Display the applications loaded in this deployment."

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, settings, _optimus) do
    Ctx.for_command(:"dev.deps", args, settings)
    |> Ctx.add_output({:info, "Loaded Applications"})
    |> Ctx.add_output({:table, loaded_rows(), has_headers: true})
    |> Ctx.with_cargo(%{application_count: length(Application.loaded_applications())})
    |> Ctx.complete(:ok)
  end

  @spec loaded_rows() :: [[String.t()]]
  defp loaded_rows do
    data_rows =
      Application.loaded_applications()
      |> Enum.map(fn {app, _description, vsn} -> [to_string(app), to_string(vsn)] end)
      |> Enum.sort()

    [["Application", "Version"] | data_rows]
  end
end
