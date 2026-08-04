defmodule Arca.Cli.Utils.PutLinesTest do
  @moduledoc """
  Covers `put_lines/1` for maps and tuples (finding C1).

  Both clauses were `IO.inspect/1`. That is a debugging call: it writes its own
  representation straight to stdout, bypassing `print_ansi/1` and therefore every
  style decision the CLI had just made, and it returns the term rather than `:ok`
  -- so the `@spec put_lines(term()) :: :ok | [:ok]` above it was never true.

  Both now go through `to_str/1`, which is the one term-to-string path in this
  module, and then out through the same printer as everything else.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Arca.Cli.Utils

  describe "maps and tuples render through the normal printer" do
    test "success: a map is rendered as a string, not inspected at the user" do
      output = capture_io(fn -> Utils.put_lines(%{key: "value"}) end)

      assert String.trim(output) == ~s(%{key: "value"})
    end

    test "success: a tuple is rendered as a string" do
      output = capture_io(fn -> Utils.put_lines({:ok, "done"}) end)

      assert String.trim(output) == ~s({:ok, "done"})
    end

    test "invariant: the rendering matches the module's one term-to-string path" do
      term = %{b: 2, a: 1}

      output = capture_io(fn -> Utils.put_lines(term) end)

      assert String.trim(output) == String.trim(Utils.to_str(term))
    end
  end

  describe "the other clauses are unchanged" do
    test "success: a binary is trimmed and printed" do
      assert capture_io(fn -> Utils.put_lines("  hello  ") end) == "hello\n"
    end

    test "success: a list prints one line per element" do
      assert capture_io(fn -> Utils.put_lines(["one", "two"]) end) == "one\ntwo\n"
    end

    test "success: nil prints as nil" do
      assert capture_io(fn -> Utils.put_lines(nil) end) == "nil\n"
    end

    test "invariant: :ok prints nothing" do
      assert capture_io(fn -> Utils.put_lines(:ok) end) == ""
    end
  end
end
