defmodule Arca.Cli.Output.IoCorrectnessTest do
  @moduledoc """
  Covers what actually reaches a pipe (finding A12).

  Both axes used to be inverted. Content that must survive a pipe was destroyed:
  the escript's stdio defaulted to latin1, so an emoji arrived as the literal
  text `\\x{1F4E6}` rather than its UTF-8 bytes. Decoration that must not survive
  a pipe was forced on: `ansi_enabled` was set to `true` unconditionally, pushing
  escape codes into files and downstream processes.

  These assert bytes from a real piped subprocess, because that is the only place
  the defect was observable -- in-process rendering looked fine throughout.
  """
  use ExUnit.Case, async: true

  # `mix test` has already compiled this build, and every child here inherits
  # MIX_ENV=test from it. Without these flags each child re-verifies that build
  # while holding the global build-directory lock, so concurrent subprocess tests
  # queue behind one another and the run prints "Waiting for lock on the build
  # directory". The work being skipped is work the parent just did.
  @mix_run ["run", "--no-compile", "--no-deps-check"]

  # Run the CLI in a subprocess whose stdout is a pipe, returning the raw bytes.
  @spec piped_output([String.t()]) :: binary()
  defp piped_output(argv) do
    {output, _status} = System.cmd("mix", @mix_run ++ ["-e", "Arca.Cli.main(#{inspect(argv)})"])
    output
  end

  describe "piped output preserves content" do
    test "success: an emoji arrives as its UTF-8 bytes, not as escaped text" do
      output = piped_output(["about"])

      # U+1F4E6 PACKAGE is <<0xF0, 0x9F, 0x93, 0xA6>> in UTF-8.
      assert output =~ "📦"
      refute output =~ "\\x{1F4E6}"
    end

    test "invariant: piped output is valid UTF-8" do
      output = piped_output(["about"])

      assert String.valid?(output)
    end
  end

  describe "piped output carries no decoration" do
    test "invariant: no ANSI escape bytes reach a pipe" do
      output = piped_output(["about"])

      refute output =~ "\e["
    end

    test "invariant: no ANSI escape bytes reach a pipe on the failure path either" do
      output = piped_output(["cli.error", "standard"])

      refute output =~ "\e["
    end
  end

  describe "TTY detection" do
    test "invariant: output going to a pipe is not reported as a terminal" do
      # Asked in a subprocess, whose stdout is a pipe by construction. Asserting
      # on this VM's stdout would pass or fail depending on whether `mix test`
      # was run in a terminal or piped into something -- the exact class of
      # environment-dependent behaviour this work package exists to remove.
      {output, 0} = System.cmd("mix", @mix_run ++ ["-e", "IO.puts(Arca.Cli.Output.tty?())"])

      assert last_line(output) == "false"
    end
  end

  # mix may emit compilation notices ahead of the value being probed.
  @spec last_line(binary()) :: binary()
  defp last_line(output) do
    output |> String.trim() |> String.split("\n") |> List.last()
  end
end
