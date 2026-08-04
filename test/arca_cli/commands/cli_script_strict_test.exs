defmodule Arca.Cli.Commands.CliScriptStrictTest do
  @moduledoc """
  Scripts run strictly (findings A7 and the `cli.script` leg of A13).

  Two defects met here. Scripts were evaluated through the REPL's fuzzy matcher,
  so a typo'd command silently ran whichever command it most resembled -- `abut`
  ran `about`. And the executor ignored every result, so a script reported
  success no matter how many of its commands failed.

  Fuzzy matching remains a convenience of the interactive prompt, where a human
  sees the substitution and can undo it. A script is not a human typing.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @spec write_script(String.t()) :: String.t()
  defp write_script(content) do
    path = Path.join(System.tmp_dir!(), "arca_strict_#{System.unique_integer([:positive])}.cli")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  # Run a script through the real CLI, returning outcome and captured output.
  @spec run_script(String.t(), [String.t()]) :: {Arca.Cli.outcome(), String.t()}
  defp run_script(content, flags \\ []) do
    path = write_script(content)
    {outcome, io} = with_io(fn -> Arca.Cli.run(["cli.script" | flags] ++ [path]) end)
    {outcome, io}
  end

  describe "typos are not rewritten" do
    test "failure: a misspelled command fails instead of running a similar one" do
      {outcome, output} = run_script("abut\n")

      assert outcome == :error
      refute output =~ "A declarative CLI for Elixir apps"
    end

    test "success: a correctly spelled command still runs" do
      {outcome, output} = run_script("about\n")

      assert outcome == :ok
      assert output =~ "A declarative CLI for Elixir apps"
    end
  end

  describe "stop on first failure" do
    test "failure: a script stops at the first failing command" do
      {outcome, output} = run_script("nosuchcommand\nabout\n")

      assert outcome == :error
      assert output =~ "stopped at the first failing command"
      refute output =~ "A declarative CLI for Elixir apps"
    end

    test "success: --keep-going runs the remaining commands" do
      {outcome, output} = run_script("nosuchcommand\nabout\n", ["--keep-going"])

      assert outcome == :error
      assert output =~ "A declarative CLI for Elixir apps"
      refute output =~ "stopped at the first failing command"
    end

    test "success: a script of good commands succeeds" do
      {outcome, _output} = run_script("about\nabout\n")

      assert outcome == :ok
    end
  end

  describe "unreadable script" do
    test "failure: a missing script file is an error, not a printed note" do
      {outcome, output} = with_io(fn -> Arca.Cli.run(["cli.script", "/nonexistent/file.cli"]) end)

      assert outcome == :error
      assert output =~ "cannot read script file"
    end
  end
end
