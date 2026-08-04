defmodule Arca.Cli.ErrorFormatTest do
  @moduledoc """
  Covers the error dialect (findings C5 and C15).

  Four formatters were producing four shapes for the same thing:

      error: Unknown command: nosuchcommand      # context and message inverted
      error: settings.get: missing required ...  # the ratified shape
      Error (invalid_argument): ...              # ErrorHandler
      Input error: ...                           # the REPL's deprecated one

  Nothing decided between them; which one a user saw depended on which layer
  noticed the failure first. The ratified dialect is `error: <context>: <message>`
  and `Arca.Cli.ErrorHandler.format_error/2` is now the only place it is produced.

  Reasons are rendered as text rather than inspected. `inspect/1` on a binary
  showed users `"Key not found"`, quotes and all -- an implementation detail of
  how the message travelled, presented as though it were part of the message.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Arca.Cli.ErrorHandler
  alias Arca.Cli.Test.Support

  # Every failure path's first line, as the user sees it.
  @spec first_line([String.t()]) :: String.t()
  defp first_line(argv) do
    {_outcome, io} = with_io(fn -> Arca.Cli.run(argv) end)

    io |> String.split("\n") |> List.first() |> String.trim()
  end

  setup do
    original_app = Application.get_env(:arca_cli, :debug_mode)
    original_setting = Support.setting_value("debug_mode")
    Application.put_env(:arca_cli, :debug_mode, false)

    on_exit(fn ->
      Support.restore_app_env(:arca_cli, :debug_mode, original_app)
      Support.restore_setting("debug_mode", original_setting)
    end)

    :ok
  end

  describe "the formatter states the dialect once" do
    test "success: a context and a message become error: context: message" do
      assert ErrorHandler.error_line("cli.thing", "it broke") == "error: cli.thing: it broke"
    end

    test "success: no context yields a bare error: message" do
      assert ErrorHandler.error_line(nil, "it broke") == "error: it broke"
    end

    test "success: the command supplied by the caller wins over the error type" do
      formatted =
        ErrorHandler.format_error({:error, :command_failed, "it broke", nil}, command: "cli.thing")

      assert formatted == "error: cli.thing: it broke"
    end

    test "success: with no command, the error type supplies the context" do
      formatted = ErrorHandler.format_error({:error, :command_failed, "it broke", nil}, [])

      assert formatted == "error: command failed: it broke"
    end

    test "success: an unknown error type has nothing useful to say, so says nothing" do
      formatted = ErrorHandler.format_error({:error, :unknown_error, "it broke", nil}, [])

      assert formatted == "error: it broke"
    end

    test "success: an unlisted error type is spelled out rather than inspected" do
      formatted = ErrorHandler.format_error({:error, :script_not_readable, "nope", nil}, [])

      assert formatted == "error: script not readable: nope"
    end
  end

  describe "every failure path emits the dialect on its first line" do
    test "failure: an unknown command" do
      assert first_line(["nosuchcommand"]) == "error: nosuchcommand: unknown command"
    end

    test "failure: help for an unknown command" do
      assert first_line(["help", "nosuchcommand"]) == "error: nosuchcommand: unknown command"
    end

    test "failure: a parse error on a known command" do
      assert first_line(["settings.get"]) ==
               "error: settings.get: missing required arguments: SETTING_ID"
    end

    test "failure: a standard error tuple" do
      assert first_line(["cli.error", "standard"]) ==
               "error: cli.error: This is a standard error tuple test"
    end

    test "failure: a legacy error tuple" do
      assert first_line(["cli.error", "legacy"]) ==
               "error: cli.error: This is a legacy error tuple test"
    end

    test "failure: a raised exception" do
      assert first_line(["cli.error", "raise"]) ==
               "error: cli.error: This is a test exception from CliErrorCommand"
    end

    test "failure: a setting that does not exist" do
      assert first_line(["settings.get", "nosuchkey"]) ==
               "error: settings.get: setting not found: nosuchkey"
    end

    test "invariant: no failure path emits a second dialect" do
      lines =
        [
          ["nosuchcommand"],
          ["help", "nosuchcommand"],
          ["settings.get"],
          ["cli.error", "standard"],
          ["cli.error", "legacy"],
          ["cli.error", "raise"],
          ["settings.get", "nosuchkey"],
          ["cli.redo", "999"]
        ]
        |> Enum.map(&first_line/1)

      assert Enum.all?(lines, &String.starts_with?(&1, "error: ")),
             "not in the dialect: #{inspect(Enum.reject(lines, &String.starts_with?(&1, "error: ")))}"
    end

    test "invariant: the retired shapes are gone" do
      lines =
        [
          ["nosuchcommand"],
          ["cli.error", "standard"],
          ["cli.error", "raise"],
          ["settings.get", "nosuchkey"]
        ]
        |> Enum.map(&first_line/1)

      refute Enum.any?(lines, &(&1 =~ ~r/^Error \(/))
      refute Enum.any?(lines, &(&1 =~ ~r/^(Input|Evaluation|Prompt|Output|History) error:/))
    end
  end

  describe "reasons are text, not inspected terms" do
    test "success: a binary reason passes through unquoted" do
      assert ErrorHandler.format_reason("Key not found") == "Key not found"
    end

    test "success: an atom reason is spelled, not inspected" do
      assert ErrorHandler.format_reason(:not_found) == "not_found"
    end

    test "success: a list of reasons is joined" do
      assert ErrorHandler.format_reason(["one", "two"]) == "one two"
    end

    test "invariant: a term with no text form still renders" do
      assert ErrorHandler.format_reason(%{a: 1}) == "%{a: 1}"
    end

    test "invariant: no failure path shows a quoted reason" do
      lines =
        [
          ["settings.get", "nosuchkey"],
          ["cfg.get", "nosuchkey"],
          ["cli.error", "standard"],
          ["nosuchcommand"]
        ]
        |> Enum.map(&first_line/1)

      quoted = Enum.filter(lines, &(&1 =~ ~s(: ")))

      assert quoted == []
    end
  end

  describe "debug mode still appends the structured block" do
    test "success: the dialect line comes first, then the debug block" do
      Application.put_env(:arca_cli, :debug_mode, true)

      {_outcome, io} = with_io(fn -> Arca.Cli.run(["cli.error", "raise"]) end)

      assert String.starts_with?(io, "error: cli.error: This is a test exception")
      assert io =~ "Debug Information:"
      assert io =~ "Stack trace:"
    end

    test "invariant: with debug off, no debug block appears" do
      {_outcome, io} = with_io(fn -> Arca.Cli.run(["cli.error", "raise"]) end)

      refute io =~ "Debug Information:"
    end
  end

  describe "the command-not-found suggestion block keeps its extra lines" do
    test "success: a namespace prefix lists the namespace's commands" do
      {_outcome, io} = with_io(fn -> Arca.Cli.run(["sys"]) end)

      assert String.starts_with?(io, "error: sys: unknown command")
      assert io =~ "sys is a command namespace"
      assert io =~ "sys.info"
    end

    test "success: a near miss suggests the commands it is near" do
      {_outcome, io} = with_io(fn -> Arca.Cli.run(["sys.inf"]) end)

      assert String.starts_with?(io, "error: sys.inf: unknown command")
      assert io =~ "Did you mean one of these?"
      assert io =~ "sys.info"
    end
  end
end
