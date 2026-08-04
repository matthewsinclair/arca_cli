defmodule Arca.Cli.Commands.SysCmdTest do
  @moduledoc """
  Covers `sys.cmd` (finding A10, and the `sys.cmd` leg of finding A13).

  Three defects lived in one handler. It joined every argument after the command
  name into a single string, so `sys.cmd ls -l -a` asked `ls` for a flag called
  `-l -a`. It printed the output itself and *also* returned it, so the dispatch
  layer printed it again -- as an inspected `{output, status}` tuple. And it
  reported the OS exit status only inside that tuple, which nothing read, so a
  failed OS command left the CLI exiting 0.

  The three are one defect really: the handler was doing the renderer's job, and
  a value that had already been printed had nowhere honest left to go.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Commands.SysCmdCommand

  defp args_for(oscmd, unknown \\ []) do
    %{args: %{args: oscmd}, options: %{}, flags: %{}, unknown: unknown}
  end

  defp text_output(ctx) do
    ctx.output
    |> Enum.filter(&match?({:text, _}, &1))
    |> Enum.map_join("\n", fn {:text, content} -> content end)
  end

  describe "arguments are passed separately" do
    test "success: each argument reaches the OS command as its own argument" do
      # Joined, `expr` would receive the single operand "1 + 1" and echo it back.
      # Separate, it evaluates the expression.
      ctx = SysCmdCommand.handle(args_for("expr", ["1", "+", "1"]), %{}, nil)

      assert text_output(ctx) == "2"
      assert ctx.status == :ok
    end

    test "success: a flag stays a flag rather than merging with the next one" do
      ctx = SysCmdCommand.handle(args_for("printf", ["%s-%s", "a", "b"]), %{}, nil)

      assert text_output(ctx) == "a-b"
      assert ctx.status == :ok
    end

    test "success: a command with no arguments runs" do
      ctx = SysCmdCommand.handle(args_for("true"), %{}, nil)

      assert ctx.status == :ok
    end
  end

  describe "output is carried, not printed" do
    test "invariant: the handler prints nothing itself" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          SysCmdCommand.handle(args_for("echo", ["hello"]), %{}, nil)
        end)

      assert output == ""
    end

    test "success: output is carried as a text item, with no status tuple" do
      ctx = SysCmdCommand.handle(args_for("echo", ["hello"]), %{}, nil)

      assert ctx.output == [{:text, "hello"}]
    end

    test "success: a command that produces nothing adds no output item" do
      ctx = SysCmdCommand.handle(args_for("true"), %{}, nil)

      assert ctx.output == []
    end

    test "invariant: rendering the context shows the output exactly once" do
      ctx = SysCmdCommand.handle(args_for("echo", ["marker-token"]), %{}, nil)

      rendered = Arca.Cli.Output.render(ctx)

      assert length(String.split(rendered, "marker-token")) == 2
    end
  end

  describe "the OS exit status is the command's outcome" do
    test "failure: a non-zero exit status completes the context as an error" do
      ctx = SysCmdCommand.handle(args_for("false"), %{}, nil)

      assert ctx.status == :error
    end

    test "failure: the error message names the exit status" do
      ctx = SysCmdCommand.handle(args_for("false"), %{}, nil)

      assert ctx.errors == ["false exited with status 1"]
    end

    test "success: a zero exit status completes the context as ok" do
      ctx = SysCmdCommand.handle(args_for("true"), %{}, nil)

      assert ctx.status == :ok
      assert ctx.errors == []
    end

    test "failure: a command that cannot be found is an error, not a crash" do
      ctx = SysCmdCommand.handle(args_for("no_such_binary_anywhere"), %{}, nil)

      assert ctx.status == :error
      assert ctx.errors == ["command not found: no_such_binary_anywhere"]
    end

    test "failure: no OS command at all is an error" do
      ctx = SysCmdCommand.handle(args_for(nil), %{}, nil)

      assert ctx.status == :error
      assert ctx.errors == ["no OS command given"]
    end
  end

  describe "the outcome reaches the dispatch layer" do
    test "failure: a failed OS command makes the CLI run report :error" do
      assert ExUnit.CaptureIO.capture_io(fn ->
               assert Arca.Cli.run(["sys.cmd", "false"]) == :error
             end)
    end

    test "success: a successful OS command makes the CLI run report :ok" do
      assert ExUnit.CaptureIO.capture_io(fn ->
               assert Arca.Cli.run(["sys.cmd", "true"]) == :ok
             end)
    end
  end
end
