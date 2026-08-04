defmodule Arca.Cli.Test.Subprocess do
  @moduledoc """
  Run this project's CLI as a real OS process from a test.

  Several properties are only observable across a process boundary -- the exit
  status a shell would branch on, the bytes that actually reach a pipe, whether a
  setting written by one invocation is visible to the next -- and every test that
  needs one of them needs the same child environment. This is that environment,
  stated once.

  ## Why the environment is set explicitly

  `mix test` does not export `MIX_ENV`. A child launched without it therefore
  runs in `:dev` and loads `_build/dev`, a build the parent never compiled: with
  `--no-compile` it fails outright on a fresh checkout, and without it the child
  compiles a second environment while holding the global build-directory lock,
  which is what makes concurrent subprocess tests queue behind one another.
  Pinning the child to the parent's environment means `--no-compile` is safe,
  because the build is the one `mix test` just produced.

  `ARCA_STYLE` and `NO_COLOR` are scrubbed rather than set. A child inherits the
  whole environment, so a variable exported by the developer's shell -- or leaked
  by an earlier test in the same run -- would otherwise decide what the child
  prints, and the tests that assert what reaches a pipe would be asserting the
  ambient environment instead of the CLI's own behaviour.
  """

  import ExUnit.Assertions

  @mix_run ["run", "--no-compile", "--no-deps-check"]
  @child_env [{"MIX_ENV", "test"}, {"ARCA_STYLE", nil}, {"NO_COLOR", nil}]

  @doc """
  Run `Arca.Cli.main/1` with `argv` in a child process.

  Returns `{output, exit_status}`. Pass `stderr_to_stdout: true` to fold the
  child's diagnostics into the returned output.
  """
  @spec main([String.t()], keyword()) :: {String.t(), non_neg_integer()}
  def main(argv, opts \\ []) do
    eval("Arca.Cli.main(#{inspect(argv)})", opts)
  end

  @doc """
  Evaluate `code` in a child process, for asking the CLI a question about itself
  that can only be answered honestly outside this VM.
  """
  @spec eval(String.t(), keyword()) :: {String.t(), non_neg_integer()}
  def eval(code, opts \\ []) do
    run(@mix_run ++ ["-e", code], opts)
  end

  @doc """
  Run a script with `argv` in a child process, as a downstream entry point would.
  """
  @spec script(String.t(), [String.t()], keyword()) :: {String.t(), non_neg_integer()}
  def script(path, argv, opts \\ []) do
    run(@mix_run ++ [path | argv], opts)
  end

  defp run(args, opts) do
    {output, status} =
      System.cmd(
        "mix",
        args,
        [env: @child_env] ++ Keyword.take(opts, [:stderr_to_stdout, :cd])
      )

    refute_harness_failure(output)

    {strip_mix_noise(output), status}
  end

  # Mix writes its build-directory lock notice to stdout, so it arrives
  # interleaved with whatever the CLI printed. Children contend for that lock
  # with the parent `mix test`, which means any test asserting on exact output
  # would fail intermittently, and on a machine fast enough to avoid contention
  # it would never fail at all -- a flake that looks like a CLI defect.
  #
  # Only Mix's own line is removed. Nothing the CLI produced is touched.
  # The notice arrives with a leading ANSI reset, so the whole line is matched
  # rather than anchoring on the message text.
  @mix_noise ~r/^.*Waiting for lock on the build directory.*\n?/m
  defp strip_mix_noise(output), do: String.replace(output, @mix_noise, "")

  # A child that never reached the CLI also exits non-zero, so without this every
  # "exits 1" assertion would pass whether or not the CLI ran. Name that case so
  # it reads as a broken harness rather than as the behaviour under test.
  defp refute_harness_failure(output) do
    refute output =~ "Could not find a Mix.Project",
           "harness failure: the child never started the CLI.\n#{output}"

    refute output =~ ~r/could not (compile|find) (dependency|application)/,
           "harness failure: the child could not load the application.\n#{output}"

    :ok
  end
end
