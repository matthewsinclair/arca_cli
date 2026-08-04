defmodule Arca.Cli.Commands.SysCmdCommand do
  @moduledoc """
  Arca CLI command to run an OS command and report its result.

  Arguments after the command name are passed through as separate arguments, so
  `sys.cmd ls -l -a` runs `ls` with two flags rather than one flag named `-l -a`.

  The OS exit status is the command's outcome: a non-zero status makes `sys.cmd`
  fail, which the CLI reports as a non-zero exit of its own.
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :"sys.cmd",
    name: "sys.cmd",
    about: "Run an OS command from within the CLI and return the results.",
    allow_unknown_args: true,
    args: [
      args: [
        value_name: "ARGS",
        help: "Arguments to OS command",
        required: false,
        parser: :string
      ]
    ]

  @typedoc """
  The result of running an OS command.
  """
  @type run_result ::
          {:ok, String.t()}
          | {:exit, String.t(), non_neg_integer()}
          | {:error, String.t()}

  @doc """
  Run an OS command and return a context describing what happened.

  Output is carried on the context rather than printed here, so it is rendered
  once by whichever renderer the caller's environment selects.

  ## Returns

    - A `Ctx` completed `:ok` when the command exits 0
    - A `Ctx` completed `:error`, naming the exit status, when it does not
    - A `Ctx` completed `:error` when the command cannot be run at all
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(%{args: %{args: oscmd}} = args, settings, _optimus) when is_binary(oscmd) do
    ctx = Ctx.for_command(:"sys.cmd", args, settings)

    case run(oscmd, Map.get(args, :unknown, [])) do
      {:ok, output} ->
        ctx |> add_command_output(output) |> Ctx.complete(:ok)

      {:exit, output, status} ->
        ctx
        |> add_command_output(output)
        |> Ctx.add_error("#{oscmd} exited with status #{status}")
        |> Ctx.complete(:error)

      {:error, message} ->
        ctx |> Ctx.add_error(message) |> Ctx.complete(:error)
    end
  end

  def handle(%{args: %{args: nil}} = args, settings, _optimus) do
    Ctx.for_command(:"sys.cmd", args, settings)
    |> Ctx.add_error("no OS command given")
    |> Ctx.complete(:error)
  end

  # Fallback for non-matching args (eg :help, nil): delegate to the BaseCommand default.
  @doc false
  def handle(args, settings, optimus), do: super(args, settings, optimus)

  # Run the command with its arguments kept separate.
  #
  # stderr is deliberately not captured: it stays on the CLI's own stderr, so a
  # caller redirecting the two streams separately still gets what it asked for.
  @spec run(String.t(), [String.t()]) :: run_result()
  defp run(oscmd, oscmd_args) do
    case System.cmd(oscmd, oscmd_args) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:exit, output, status}
    end
  rescue
    e in ErlangError ->
      case e.original do
        :enoent -> {:error, "command not found: #{oscmd}"}
        reason -> {:error, "could not run #{oscmd}: #{inspect(reason)}"}
      end
  end

  # A command that produced nothing contributes no output item, so a silent
  # command stays silent rather than rendering a blank line.
  @spec add_command_output(Ctx.t(), String.t()) :: Ctx.t()
  defp add_command_output(ctx, output) do
    case String.trim_trailing(output) do
      "" -> ctx
      trimmed -> Ctx.add_output(ctx, {:text, trimmed})
    end
  end
end
