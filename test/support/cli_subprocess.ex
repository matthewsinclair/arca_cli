defmodule Arca.Cli.Test.Subprocess do
  @moduledoc """
  Run this project's CLI as a real OS process from a test.

  Several properties are only observable across a process boundary -- the exit
  status a shell would branch on, the bytes that actually reach a pipe, whether a
  setting written by one invocation is visible to the next -- and every test that
  needs one of them needs the same child environment. This is that environment,
  stated once.

  ## `main/2` runs the escript, not `mix run`

  The child is the built escript: `Arca.Cli.main/1` in a standalone binary. That
  is the artifact this project ships, and it is what a `mix` task would
  ultimately invoke anyway.

  It used to be `mix run --no-compile -e "Arca.Cli.main(...)"`, which works but
  drags Mix's whole machinery into a test of the CLI: project loading, dependency
  checks, and the **global build-directory lock**. Concurrent subprocess tests
  then queued behind one another and Mix printed "Waiting for lock on the build
  directory" into the middle of the run. None of that is under test. The subject
  of these tests is what a user gets when they run the CLI, and `mix run -e` only
  simulates that -- the escript is it.

  ## Environment variables reach the child directly

  Under `mix run` they could not. `config/dotenv.exs` loads `config/.env` in
  `:dev` and `:test` and calls `System.put_env/2` unconditionally, so it
  OVERWROTE `ARCA_CLI_CONFIG_PATH` inherited from the parent -- which is why
  callers used to smuggle `System.put_env` into evaluated code that runs after
  config evaluation. The escript carries compile-time configuration and does not
  evaluate `config/` at all, so `env:` on `System.cmd/3` simply works. That
  simplification is a consequence of the switch, not an incidental detail.

  `ARCA_STYLE` and `NO_COLOR` are scrubbed rather than set. A child inherits the
  whole environment, so a variable exported by the developer's shell -- or leaked
  by an earlier test in the same run -- would otherwise decide what the child
  prints, and the tests that assert what reaches a pipe would be asserting the
  ambient environment instead of the CLI's own behaviour.

  ## `eval/2` and `script/3` still use `mix run`, deliberately

  Two things genuinely are not the CLI and cannot be asked of the escript:

    * `eval/2` evaluates arbitrary code in a child, to ask a library function a
      question whose honest answer needs a real pipe (`Arca.Cli.Output.tty?/0`).
    * `script/3` runs a *downstream* wrapper that defines its own entry point and
      delegates to `Arca.Cli.main/1`. Its whole subject is that a different
      escript inherits our exit codes, so it cannot be ours.

  Their two modules declare `async: false`, because taking a global lock is
  shared global state and that is what an async opt-out is for. Everything that
  runs the escript stays async, because it takes no lock.
  """

  import ExUnit.Assertions

  @escript "_build/escript/arca_cli"
  @mix_run ["run", "--no-compile", "--no-deps-check"]
  @child_env [{"MIX_ENV", "test"}, {"ARCA_STYLE", nil}, {"NO_COLOR", nil}]

  @doc """
  Path to the escript these tests run.
  """
  @spec escript_path() :: String.t()
  def escript_path, do: @escript

  @doc """
  Run `Arca.Cli.main/1` with `argv` in a child process, via the built escript.

  Returns `{output, exit_status}`.

  ## Options

    * `:stderr_to_stdout` -- fold the child's diagnostics into the returned output
    * `:cd` -- working directory for the child
    * `:env` -- extra environment for the child, as `[{name, value}]`
  """
  @spec main([String.t()], keyword()) :: {String.t(), non_neg_integer()}
  def main(argv, opts \\ []) do
    # A missing escript must FAIL, never skip. The predecessor of this check was
    # a `run_when_built/2` helper that printed "(skipped: ... not built)" and
    # passed: with the binary absent, a file of nine tests reported "9 passed"
    # while four of them did nothing. Green over code nothing reached -- the
    # archetype this whole thread exists to remove. test_helper.exs builds the
    # escript before the suite, so reaching this means that step failed.
    assert File.exists?(@escript),
           """
           the escript is not built, so this test cannot run the CLI.

           test_helper.exs builds it before the suite starts, so reaching this
           means that step failed or was removed. Run `mix escript.build`.
           """

    {output, status} =
      System.cmd(
        Path.expand(@escript),
        argv,
        [env: @child_env ++ Keyword.get(opts, :env, [])] ++
          Keyword.take(opts, [:stderr_to_stdout, :cd])
      )

    # Returned verbatim. An earlier draft trimmed the trailing newline here and
    # broke a test that legitimately asserts the CLI emits one -- the helper's
    # job is to run the child, not to edit what it printed.
    {output, status}
  end

  @doc """
  Evaluate `code` in a child process, to ask a question about this library that
  can only be answered honestly outside this VM.

  Uses `mix run`, and so takes the build-directory lock. Prefer `main/2` unless
  the thing under test genuinely is not the CLI.
  """
  @spec eval(String.t(), keyword()) :: {String.t(), non_neg_integer()}
  def eval(code, opts \\ []) do
    run_mix(@mix_run ++ ["-e", code], opts)
  end

  @doc """
  Run a script with `argv` in a child process, as a downstream entry point would.

  Uses `mix run`, and so takes the build-directory lock. The script under test
  defines its own entry point, which is the point.
  """
  @spec script(String.t(), [String.t()], keyword()) :: {String.t(), non_neg_integer()}
  def script(path, argv, opts \\ []) do
    run_mix(@mix_run ++ [path | argv], opts)
  end

  defp run_mix(args, opts) do
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
  # interleaved with whatever the child printed. Only Mix's own line is removed;
  # nothing the CLI produced is touched. The notice arrives with a leading ANSI
  # reset, so the whole line is matched rather than anchoring on the message text.
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
