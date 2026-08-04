defmodule Arca.Cli.RunEntryTest do
  @moduledoc """
  Covers `Arca.Cli.run/1`, the pure entry point.

  `run/1` is what embedders and tests call: it does everything `main/1` does
  except translate the outcome into an OS exit status, so it never halts the
  host VM.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # Run the CLI in-process, discarding its display output and keeping the outcome.
  @spec outcome_of([String.t()]) :: Arca.Cli.outcome()
  defp outcome_of(argv) do
    {outcome, _io} = with_io(fn -> Arca.Cli.run(argv) end)
    outcome
  end

  describe "run/1 outcome" do
    test "success: a command returning output reports :ok" do
      assert outcome_of(["cli.error", "success"]) == :ok
    end

    test "failure: a command returning a standard error tuple reports :error" do
      assert outcome_of(["cli.error", "standard"]) == :error
    end

    test "failure: a command returning a legacy error tuple reports :error" do
      assert outcome_of(["cli.error", "legacy"]) == :error
    end

    test "failure: a command raising an exception reports :error" do
      assert outcome_of(["cli.error", "raise"]) == :error
    end

    test "failure: an unknown command reports :error" do
      assert outcome_of(["nosuchcommand"]) == :error
    end

    test "failure: a context completed with :error reports :error" do
      assert outcome_of(["cli.error", "ctx"]) == :error
    end

    test "success: a context completed with :warning reports :warning" do
      assert outcome_of(["cli.error", "warning"]) == :warning
    end
  end

  describe "run/1 does not halt" do
    test "invariant: a failing run leaves the VM able to run the next command" do
      # Were run/1 to halt on failure, the second call would never happen and
      # this whole suite would die mid-run rather than fail.
      assert outcome_of(["cli.error", "standard"]) == :error
      assert outcome_of(["cli.error", "success"]) == :ok
    end
  end
end
