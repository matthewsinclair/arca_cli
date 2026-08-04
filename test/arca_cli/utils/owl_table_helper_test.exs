defmodule Arca.Cli.Utils.OwlTableHelperTest do
  use ExUnit.Case, async: true

  alias Arca.Cli.Utils.OwlHelper

  describe "adjust_column_widths/2" do
    test "returns a function that maps columns to widths" do
      preferences = %{
        "ID" => 10,
        "Name" => 15,
        "Description" => {0.6, :percent},
        "Source" => {0.4, :percent}
      }

      max_width_fn = OwlHelper.adjust_column_widths(preferences, 80)

      assert is_function(max_width_fn, 1)
      assert max_width_fn.("ID") == 10
      assert max_width_fn.("Name") == 15
      assert max_width_fn.("Description") > 0
      assert max_width_fn.("Source") > 0
      # Default
      assert max_width_fn.("Unknown") == 10
    end

    test "adjusts percentage columns based on remaining width" do
      preferences = %{
        "ID" => 10,
        "Name" => 10,
        "Description" => {0.7, :percent},
        "Source" => {0.3, :percent}
      }

      # 80 - 1 (borders) - (4 * 3) (borders + padding) = 67
      # 67 - 20 (fixed width) = 47 remaining for percentage columns
      # Description should get ~33 (0.7 * 47), Source ~14 (0.3 * 47)

      max_width_fn = OwlHelper.adjust_column_widths(preferences, 80)

      description_width = max_width_fn.("Description")
      source_width = max_width_fn.("Source")

      assert description_width > source_width
      assert_in_delta description_width, 32, 2
      assert_in_delta source_width, 14, 2
    end
  end

  describe "table/3" do
    test "creates a table with ANSI colored cells" do
      data = [
        %{
          "ID" => Owl.Data.tag("task/demo/echo", :cyan),
          "Name" => Owl.Data.tag("Echo Task", [:bright, :white]),
          "Description" => Owl.Data.tag("Simple echo task", [:bright, :green]),
          "Source" => Owl.Data.tag("internal", :yellow)
        },
        %{
          "ID" => Owl.Data.tag("task/test/hello", :cyan),
          "Name" => Owl.Data.tag("Hello World Task", [:bright, :white]),
          "Description" => Owl.Data.tag("A demo task", [:bright, :green]),
          "Source" => Owl.Data.tag("custom_path", :yellow)
        }
      ]

      # Color the headers too
      opts = [render_cell: [header: &header_tag/1]]

      preferences = %{
        "ID" => 15,
        "Name" => 15,
        "Description" => {0.5, :percent},
        "Source" => {0.5, :percent}
      }

      # Use solid border style for this test to match expected assertions
      opts = Keyword.merge([max_width: 80, border_style: :solid], opts)
      table = OwlHelper.table(data, preferences, opts)

      # For ANSI tests, instead of comparing to a fixture, we'll just verify the output
      # contains the expected components, as the exact rendering can vary
      result = table |> Owl.Data.to_chardata() |> to_string()

      # Test contains our input data, but with ANSI codes the patterns are different
      # We need to check for the parts of the string that won't be interrupted by ANSI codes
      assert String.contains?(result, "Simple")
      assert String.contains?(result, "echo")
      assert String.contains?(result, "task")
      assert String.contains?(result, "task/demo/echo")
      assert String.contains?(result, "Echo")
      assert String.contains?(result, "Task")
      assert String.contains?(result, "internal")

      # Verify the structure - with solid border style for this test
      assert String.contains?(result, "┌")
      assert String.contains?(result, "┐")
      assert String.contains?(result, "└")
      assert String.contains?(result, "┘")
      assert String.contains?(result, "├")
      assert String.contains?(result, "┤")
    end

    test "creates a table with correct widths at 40 chars" do
      data = [
        %{
          "ID" => "task/demo",
          "Name" => "Echo Task",
          "Description" => "Simple echo task",
          "Source" => "internal"
        },
        %{
          "ID" => "task/test",
          "Name" => "Hello Wrld",
          "Description" => "A demo task",
          "Source" => "custom"
        }
      ]

      preferences = %{
        "ID" => 10,
        "Name" => 10,
        "Description" => {0.5, :percent},
        "Source" => {0.5, :percent}
      }

      # Use divide_body_rows: true for this test to match expected output
      table =
        OwlHelper.table(data, preferences,
          max_width: 40,
          divide_body_rows: true,
          border_style: :solid
        )

      result = table |> Owl.Data.to_chardata() |> to_string()
      expected = File.read!("test/fixtures/utils/owl_helper/owl_helper_40.out")

      assert_tables_similar(result, expected)
    end

    test "creates a table with correct widths at 80 chars" do
      data = [
        %{
          "ID" => "task/demo/echo",
          "Name" => "Echo Task",
          "Description" => "Simple echo task",
          "Source" => "internal"
        },
        %{
          "ID" => "task/test/hello",
          "Name" => "Hello World Task",
          "Description" => "A demo task",
          "Source" => "custom_path"
        }
      ]

      preferences = %{
        "ID" => 15,
        "Name" => 15,
        "Description" => {0.5, :percent},
        "Source" => {0.5, :percent}
      }

      # Use divide_body_rows: true for this test to match expected output
      table =
        OwlHelper.table(data, preferences,
          max_width: 80,
          divide_body_rows: true,
          border_style: :solid
        )

      result = table |> Owl.Data.to_chardata() |> to_string()
      expected = File.read!("test/fixtures/utils/owl_helper/owl_helper_80.out")

      assert_tables_similar(result, expected)
    end

    test "creates a table with correct widths at 120 chars" do
      data = [
        %{
          "ID" => "task/demo/echo",
          "Name" => "Echo Task",
          "Description" => "Simple echo task",
          "Source" => "internal"
        },
        %{
          "ID" => "task/test/hello",
          "Name" => "Hello World Task",
          "Description" => "A demo task with more details",
          "Source" => "custom_path"
        },
        %{
          "ID" => "task/sample/process",
          "Name" => "Sample Processing Task",
          "Description" => "Complex task with many options",
          "Source" => "filesystem"
        }
      ]

      preferences = %{
        "ID" => 20,
        "Name" => 20,
        "Description" => {0.6, :percent},
        "Source" => {0.4, :percent}
      }

      # Use divide_body_rows: true for this test to match expected output
      table =
        OwlHelper.table(data, preferences,
          max_width: 120,
          divide_body_rows: true,
          border_style: :solid
        )

      result = table |> Owl.Data.to_chardata() |> to_string()
      expected = File.read!("test/fixtures/utils/owl_helper/owl_helper_120.out")

      assert_tables_similar(result, expected)
    end
  end

  # Helper to compare tables by stripping whitespace variations
  defp assert_tables_similar(actual, expected) do
    # Normalize both strings by trimming each line and joining
    normalize = fn string ->
      string
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.join("\n")
    end

    normalized_actual = normalize.(actual)
    normalized_expected = normalize.(expected)

    assert normalized_actual == normalized_expected, """
    Tables do not match

    ACTUAL:
    #{actual}

    EXPECTED:
    #{expected}
    """
  end

  # The header colouring is a mapping from column name to style, so it is stated
  # as clauses rather than as a case inside the test body. Same behaviour, and it
  # keeps the test straight-line (IN-EX-TEST-005).
  defp header_tag("ID"), do: Owl.Data.tag("ID", :cyan)
  defp header_tag("Name"), do: Owl.Data.tag("Name", [:bright, :white])
  defp header_tag("Description"), do: Owl.Data.tag("Description", [:bright, :green])
  defp header_tag("Source"), do: Owl.Data.tag("Source", :yellow)
  defp header_tag(column), do: column
end
