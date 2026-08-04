defmodule Arca.Cli.Utils.Test do
  use ExUnit.Case, async: false
  import Arca.Cli.Utils

  doctest Arca.Cli.Utils

  @a_atom :atom123
  @a_boolean true
  @a_list [1, 2, 3]
  @a_map %{a: 1, b: 2, c: 3}
  @a_nil nil
  @a_tuple {:one, :two, :three}
  @a_binary <<1, 2, 3>>
  @a_bitstring <<1::size(2), 6::size(4)>>
  @a_integer 123
  @a_float 123.123
  @a_number 102_030
  @a_string "a string"

  describe "Arca.Cli.Utils" do
    test "know all of the types" do
      assert type_of(@a_atom) == :atom
      assert type_of(@a_boolean) == :boolean
      assert type_of(@a_list) == :list
      assert type_of(@a_map) == :map
      assert type_of(@a_nil) == nil
      assert type_of(@a_tuple) == :tuple
      assert type_of(@a_binary) == :binary
      assert type_of(@a_bitstring) == :bitstring
      assert type_of(@a_integer) == :integer
      assert type_of(@a_float) == :float
      assert type_of(@a_number) == :integer
      assert type_of(@a_string) == :binary
    end

    test "pretty_print all of the types" do
      assert to_str(@a_atom) == inspect(@a_atom)
      assert to_str(@a_boolean) == inspect(@a_boolean)
      assert to_str(@a_list) == inspect(@a_list)
      assert to_str(@a_map) == inspect(@a_map)
      assert to_str(@a_nil) == inspect(@a_nil)
      assert to_str(@a_tuple) == inspect(@a_tuple)
      assert to_str(@a_binary) == inspect(@a_binary)
      assert to_str(@a_bitstring) == inspect(@a_bitstring)
      assert to_str(@a_integer) == inspect(@a_integer)
      assert to_str(@a_float) == inspect(@a_float)
      assert to_str(@a_number) == inspect(@a_number)
      assert to_str(@a_string) == inspect(@a_string)
    end

    test "filter blank lines from list" do
      assert filter_blank_lines(["ABC", "DEF", "GHI"]) == ["ABC", "DEF", "GHI"]
      assert filter_blank_lines(["ABC", "DEF", "GHI", ""]) == ["ABC", "DEF", "GHI"]
      assert filter_blank_lines(["ABC", "DEF", "GHI", "", ""]) == ["ABC", "DEF", "GHI"]
      assert filter_blank_lines(["", "ABC", "", "DEF", "GHI"]) == ["", "ABC", "", "DEF", "GHI"]

      assert filter_blank_lines(["", "ABC", "", "DEF", "GHI", "", ""]) == [
               "",
               "ABC",
               "",
               "DEF",
               "GHI"
             ]
    end

    test "filter blank lines from tuple" do
      assert filter_blank_lines({"ABC", "DEF", "GHI"}) == {"ABC", "DEF", "GHI"}
      assert filter_blank_lines({"ABC", "DEF", "GHI", ""}) == {"ABC", "DEF", "GHI"}
      assert filter_blank_lines({"ABC", "DEF", "GHI", "", ""}) == {"ABC", "DEF", "GHI"}
      assert filter_blank_lines({"", "ABC", "", "DEF", "GHI"}) == {"", "ABC", "", "DEF", "GHI"}

      assert filter_blank_lines({"", "ABC", "", "DEF", "GHI", "", ""}) ==
               {"", "ABC", "", "DEF", "GHI"}
    end

    test "filter blank lines from string" do
      assert filter_blank_lines("ABC DEF GHI") == "ABC DEF GHI"
      assert filter_blank_lines("ABC DEF GHI\n") == "ABC DEF GHI\n"
      assert filter_blank_lines("ABC DEF GHI\n\n") == "ABC DEF GHI\n"
      assert filter_blank_lines("\nABC\nDEF GHI") == "\nABC\nDEF GHI"
      assert filter_blank_lines("\nABC\nDEF\n\nGHI\n\n") == "\nABC\nDEF\n\nGHI\n"
      assert filter_blank_lines("\nABC\nDEF\n\nGHI\n\n\n\n\n\n") == "\nABC\nDEF\n\nGHI\n"
    end

    test "with_default function" do
      assert with_default({:ok, 123}, 0) == 123
      assert with_default({:error, :something_wrong}, 0) == 0
      assert with_default(:unexpected, 0) == :unexpected
    end

    test "is_blank?/1 returns true for blank values" do
      assert is_blank?(nil)
      assert is_blank?("")
      assert is_blank?("   ")
      assert is_blank?([])
      assert is_blank?({})
      assert is_blank?(%{})
    end

    test "is_blank?/1 returns false for non-blank values" do
      refute is_blank?("not blank")
      refute is_blank?("  some text  ")
      refute is_blank?([1])
      refute is_blank?({:ok})
      refute is_blank?(%{key: :value})
      refute is_blank?(42)
      refute is_blank?(0)
      refute is_blank?(false)
      refute is_blank?(true)
    end

    test "to_url_link function" do
      url = "https://example.com"

      expected =
        "#{IO.ANSI.light_cyan()}#{IO.ANSI.underline()}\e]8;;#{url}\a#{url}\e]8;;\a#{IO.ANSI.reset()}"

      assert to_url_link(url) == expected
    end
  end

  describe "timer/1" do
    test "measures the execution time of a given function" do
      {duration, result} =
        timer(fn ->
          :timer.sleep(1000)
          :ok
        end)

      assert result == :ok
      # duration is in seconds, so 100 ms should be at least 0.1 seconds
      assert duration > 0
    end

    test "returns the result of the given function" do
      {_duration, result} = timer(fn -> 42 end)

      assert result == 42
    end

    test "returns a duration of zero for an instant function" do
      {duration, result} = timer(fn -> :ok end)

      assert result == :ok
      assert duration == 0
    end

    test "handles functions that raise exceptions" do
      assert_raise RuntimeError, "something went wrong", fn ->
        timer(fn -> raise "something went wrong" end)
      end
    end
  end
end
