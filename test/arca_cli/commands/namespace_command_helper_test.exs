# A namespace declared from a module that is not under Arca.Cli.Commands. The
# generated modules must land beside it, at Arca.Cli.NamespaceProbe.*.
#
# Defined at the top level: a module nested inside the test module would be named
# after it, which is not the shape a real caller has.
defmodule Arca.Cli.NamespaceProbe.Probe do
  use Arca.Cli.Commands.NamespaceCommandHelper

  namespace_command :plain, "Returns a plain string" do
    "a plain string"
  end

  namespace_command :computed, "Returns a computed value" do
    Enum.map_join(1..3, "-", &to_string/1)
  end

  namespace_command :multiline, "Runs a multi-expression block" do
    first = "multi"
    second = "line"
    first <> "-" <> second
  end
end

defmodule Arca.Cli.Commands.NamespaceCommandHelperTest do
  @moduledoc """
  Covers the `namespace_command` macro (finding C4).

  Two defects, and a test that could not see either. The macro took the `do`
  block as an ordinary third argument, so what it received was the keyword list
  `[do: body]` rather than the body -- and the generated `handle/3` returned that
  list. It also generated every module under `Arca.Cli.Commands`, whatever module
  invoked it, so two applications each declaring a `dev` namespace would silently
  redefine each other's command modules.

  The old test hid both. It hand-wrote `Arca.Cli.Commands.TestTest1Command` at the
  top of the file with the same body the macro was supposed to generate, so the
  two definitions collided at exactly the name the macro was hardcoded to use,
  and then asserted with `=~` -- which passes just as happily on
  `[do: "Output from test1"]` as on `"Output from test1"`.

  These tests assert the generated module by its full name, and its return value
  with `==`.
  """
  use ExUnit.Case, async: true

  @generated Arca.Cli.NamespaceProbe.ProbePlainCommand

  describe "generated modules live under the caller's namespace" do
    test "success: the module is named beside the calling module" do
      assert Code.ensure_loaded?(@generated)
    end

    test "invariant: nothing is generated under Arca.Cli.Commands" do
      refute Code.ensure_loaded?(Arca.Cli.Commands.ProbePlainCommand)
    end

    test "success: the command name is namespace-dot-name" do
      assert [{:"probe.plain", _opts}] = @generated.config()
    end

    test "success: the description reaches the command's about text" do
      [{_cmd, opts}] = @generated.config()

      assert opts[:about] == "Returns a plain string"
    end
  end

  describe "the generated handle returns the block's value" do
    test "success: a literal block returns the literal, not a keyword list" do
      assert @generated.handle(%{}, %{}, nil) == "a plain string"
    end

    test "success: a computed block returns the computed value" do
      assert Arca.Cli.NamespaceProbe.ProbeComputedCommand.handle(%{}, %{}, nil) == "1-2-3"
    end

    test "success: a multi-expression block returns its last expression" do
      assert Arca.Cli.NamespaceProbe.ProbeMultilineCommand.handle(%{}, %{}, nil) == "multi-line"
    end

    test "invariant: the return value is not wrapped in a do keyword list" do
      result = @generated.handle(%{}, %{}, nil)

      refute is_list(result)
      assert is_binary(result)
    end
  end
end
