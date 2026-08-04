defmodule Arca.Cli.Testing.CliFixturesPatternTest do
  @moduledoc """
  Covers the fixture framework's documented `expected.out` patterns.

  Two of them never worked: the replacement keys were written as ordinary
  double-quoted strings, where `"\\d"` is Elixir's DEL escape and `"\\w"`
  silently drops the backslash. Neither key could match what a fixture file
  actually contains, so `{{\\d+}}` and `{{\\w+}}` fell through to a literal
  comparison and the fixture failed however correct the output was.

  Finding A14. Every documented pattern gets a case here, so a silently
  non-functioning pattern cannot recur.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Testing.CliFixturesTest

  # compare_output/4 flunks on mismatch, so a match is simply a return.
  @spec matches?(String.t(), String.t()) :: boolean()
  defp matches?(actual, expected) do
    CliFixturesTest.compare_output(actual, expected, "pattern-test")
    true
  rescue
    ExUnit.AssertionError -> false
  end

  describe "documented patterns match" do
    test "success: {{??}} matches digits" do
      assert matches?("count: 42", "count: {{??}}")
    end

    test "success: {{\\d+}} matches digits" do
      assert matches?("count: 42", ~S"count: {{\d+}}")
    end

    test "success: {{\\w+}} matches word characters" do
      assert matches?("id: abc_123", ~S"id: {{\w+}}")
    end

    test "success: {{*}} matches arbitrary text" do
      assert matches?("provider: anything at all", "provider: {{*}}")
    end

    test "success: {{.*}} matches arbitrary text greedily" do
      assert matches?("response: a: b: c", "response: {{.*}}")
    end

    test "success: a semver built from three digit patterns matches" do
      assert matches?("arca_cli 0.4.3", ~S"arca_cli {{\d+}}.{{\d+}}.{{\d+}}")
    end
  end

  describe "documented patterns still discriminate" do
    test "failure: {{\\d+}} does not match non-digits" do
      refute matches?("count: many", ~S"count: {{\d+}}")
    end

    test "failure: {{\\w+}} does not match punctuation-only text" do
      refute matches?("id: ---", ~S"id: {{\w+}}")
    end

    test "failure: surrounding literal text must still match exactly" do
      refute matches?("total: 42", ~S"count: {{\d+}}")
    end
  end
end
