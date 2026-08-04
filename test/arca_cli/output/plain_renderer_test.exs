defmodule Arca.Cli.Output.PlainRendererTest do
  use ExUnit.Case
  alias Arca.Cli.Ctx
  alias Arca.Cli.Output.PlainRenderer

  # Tests that assert on column ORDER read positions out of the rendered header
  # line, so they need every column to fit on that line. Unpinned, the table
  # sizes against Owl.IO.columns() -- the terminal the test VM happens to be
  # attached to -- and at 40 columns a column wraps to one character per row,
  # which removes its name from the header line and fails the assertion. The
  # width is a fixture, so it is pinned rather than inherited.
  @layout_width 120

  describe "render/1 - main rendering" do
    test "renders empty context" do
      ctx = Ctx.new(%{}, %{})
      result = PlainRenderer.render(ctx)
      assert result == []
    end

    test "renders context with multiple output items" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:info, "Starting process"})
        |> Ctx.add_output({:success, "Process completed"})

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result == "Starting process\n✓ Process completed"
    end

    test "renders errors from context errors field" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_error("Something went wrong")
        |> Ctx.add_error("Another error occurred")

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result ==
               "error: Something went wrong\n✗ Something went wrong\n" <>
                 "error: Another error occurred\n✗ Another error occurred"
    end

    test "renders both errors and output" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:info, "Processing"})
        |> Ctx.add_error("Failed to complete")
        |> Ctx.complete(:error)

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result == "error: Failed to complete\n✗ Failed to complete\n\nProcessing"
    end

    test "success: the dialect line names the command when the context has one" do
      result =
        Ctx.for_command(:"cfg.get", %{}, %{})
        |> Ctx.add_error("setting not found: nope")
        |> Ctx.complete(:error)
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result == "error: cfg.get: setting not found: nope\n✗ setting not found: nope"
    end

    test "invariant: the dialect line starts a line, so `grep '^error:'` finds it" do
      lines =
        Ctx.for_command(:"cfg.get", %{}, %{})
        |> Ctx.add_error("setting not found: nope")
        |> Ctx.complete(:error)
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()
        |> String.split("\n")

      assert Enum.any?(lines, &String.starts_with?(&1, "error: "))
    end
  end

  describe "render_item/1 - table width" do
    # vc's N2: these tests used to size against Owl.IO.columns(), so the suite
    # passed or failed on the width of the terminal that happened to launch it.
    # A narrow terminal is a legitimate place to run a CLI, so the renderer has
    # to cope with one -- what it must not do is make the TEST depend on it.
    test "invariant: a table narrower than its content still carries every value" do
      rows = [
        %{"subdomain" => "api", "name" => "Service A", "status" => "active", "theme" => "light"}
      ]

      result =
        {:table, rows, headers: ["subdomain", "name", "status", "theme"], max_width: 40}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # At 40 columns the last column wraps to one character per row, so assert
      # on the characters being present rather than on a contiguous word.
      assert result =~ "subdomain"
      assert result =~ "Service A"
      assert result =~ "active"
      refute result == ""
    end

    test "success: the same table at a wide width keeps every column on one line" do
      rows = [
        %{"subdomain" => "api", "name" => "Service A", "status" => "active", "theme" => "light"}
      ]

      result =
        {:table, rows, headers: ["subdomain", "name", "status", "theme"], max_width: 120}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      header_line = result |> String.split("\n") |> Enum.find(&(&1 =~ "subdomain"))

      assert header_line =~ "name"
      assert header_line =~ "status"
      assert header_line =~ "theme"
    end
  end

  describe "render_item/1 - message types" do
    test "renders success message" do
      result =
        {:success, "Operation successful"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "✓ Operation successful"
    end

    test "renders error message" do
      result =
        {:error, "Operation failed"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "✗ Operation failed"
    end

    test "renders warning message" do
      result =
        {:warning, "This is a warning"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "⚠ This is a warning"
    end

    test "renders info message" do
      result =
        {:info, "Information message"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "Information message"
    end

    test "renders text content" do
      result =
        {:text, "Plain text content"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "Plain text content"
    end
  end

  describe "render_item/1 - tables" do
    test "renders table with headers" do
      rows = [
        ["Alice", "30"],
        ["Bob", "25"]
      ]

      result =
        {:table, rows, headers: ["Name", "Age"]}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Verify it contains box-drawing table elements
      # Top-left corner
      assert result =~ "┌"
      # Vertical line
      assert result =~ "│"
      # Horizontal line
      assert result =~ "─"
      assert result =~ "Name"
      assert result =~ "Age"
      assert result =~ "Alice"
      assert result =~ "30"
      assert result =~ "Bob"
      assert result =~ "25"

      # Verify no ANSI codes
      refute result =~ "\x1b["
    end

    test "renders table without headers" do
      rows = [
        ["Alice", "30"],
        ["Bob", "25"]
      ]

      result =
        {:table, rows, []}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Should generate generic column headers
      assert result =~ "Column 1"
      assert result =~ "Column 2"
      assert result =~ "Alice"
      assert result =~ "Bob"
    end

    test "renders table with map rows" do
      rows = [
        %{"Name" => "Alice", "Age" => 30},
        %{"Name" => "Bob", "Age" => 25}
      ]

      result =
        {:table, rows, []}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result =~ "Name"
      assert result =~ "Age"
      assert result =~ "Alice"
      assert result =~ "30"
      assert result =~ "Bob"
      assert result =~ "25"
    end

    test "renders empty table" do
      result =
        {:table, [], headers: ["Name", "Age"]}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "(empty table)"
    end

    test "renders table with headers automatically used as column order" do
      rows = [
        %{"subdomain" => "api", "name" => "Service A", "status" => "active", "theme" => "light"},
        %{"subdomain" => "web", "name" => "Service B", "status" => "inactive", "theme" => "dark"}
      ]

      result =
        {:table, rows,
         headers: ["subdomain", "name", "status", "theme"], max_width: @layout_width}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Extract the header line (first line with column names)
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "subdomain" end)

      # Verify columns appear in the specified order from headers
      # subdomain should appear before name, name before status, etc.
      subdomain_pos = :binary.match(header_line, "subdomain") |> elem(0)
      name_pos = :binary.match(header_line, "name") |> elem(0)
      status_pos = :binary.match(header_line, "status") |> elem(0)
      theme_pos = :binary.match(header_line, "theme") |> elem(0)

      assert subdomain_pos < name_pos
      assert name_pos < status_pos
      assert status_pos < theme_pos
    end

    test "renders table with explicit column_order overriding headers" do
      rows = [
        %{"subdomain" => "api", "name" => "Service A", "status" => "active"}
      ]

      result =
        {:table, rows,
         headers: ["subdomain", "name", "status"],
         column_order: ["status", "name", "subdomain"],
         max_width: @layout_width}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Extract the header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "subdomain" end)

      # Verify columns appear in the column_order, not headers order
      status_pos = :binary.match(header_line, "status") |> elem(0)
      name_pos = :binary.match(header_line, "name") |> elem(0)
      subdomain_pos = :binary.match(header_line, "subdomain") |> elem(0)

      assert status_pos < name_pos
      assert name_pos < subdomain_pos
    end

    test "renders table without column_order defaults to alphabetical" do
      rows = [
        %{"zebra" => "Z", "apple" => "A", "banana" => "B"}
      ]

      result =
        {:table, rows, max_width: @layout_width}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Extract the header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "apple" end)

      # Verify columns appear in alphabetical order
      apple_pos = :binary.match(header_line, "apple") |> elem(0)
      banana_pos = :binary.match(header_line, "banana") |> elem(0)
      zebra_pos = :binary.match(header_line, "zebra") |> elem(0)

      assert apple_pos < banana_pos
      assert banana_pos < zebra_pos
    end

    test "renders table with column_order :desc" do
      rows = [
        %{"alpha" => "A", "beta" => "B", "gamma" => "G"}
      ]

      result =
        {:table, rows, column_order: :desc, max_width: @layout_width}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Extract the header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "alpha" end)

      # Verify columns appear in descending alphabetical order
      alpha_pos = :binary.match(header_line, "alpha") |> elem(0)
      beta_pos = :binary.match(header_line, "beta") |> elem(0)
      gamma_pos = :binary.match(header_line, "gamma") |> elem(0)

      assert gamma_pos < beta_pos
      assert beta_pos < alpha_pos
    end

    test "renders table with has_headers using first row order" do
      rows = [
        ["Index", "Command", "Arguments"],
        ["0", "first", ""],
        ["1", "second", ""]
      ]

      result =
        {:table, rows, has_headers: true, max_width: @layout_width}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Extract the header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "Index" end)

      # Verify columns appear in the order from first row (Index, Command, Arguments)
      # NOT alphabetically (Arguments, Command, Index)
      index_pos = :binary.match(header_line, "Index") |> elem(0)
      command_pos = :binary.match(header_line, "Command") |> elem(0)
      arguments_pos = :binary.match(header_line, "Arguments") |> elem(0)

      assert index_pos < command_pos
      assert command_pos < arguments_pos
    end
  end

  describe "render_item/1 - lists" do
    test "renders list with title" do
      items = ["First item", "Second item", "Third item"]

      result =
        {:list, items, title: "My Items"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "My Items:\n* First item\n* Second item\n* Third item"
    end

    test "renders list without title" do
      items = ["Apple", "Banana", "Cherry"]

      result =
        {:list, items, []}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "* Apple\n* Banana\n* Cherry"
    end

    test "renders empty list" do
      result =
        {:list, [], title: "Empty"}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "(empty list)"
    end

    test "renders list with non-string items" do
      items = [1, :atom, "string", %{key: "value"}]

      result =
        {:list, items, []}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result =~ "* 1"
      assert result =~ "* atom"
      assert result =~ "* string"
      assert result =~ "* %{key: \"value\"}"
    end
  end

  describe "render_item/1 - interactive elements" do
    # Renderers receive resolved items: the work runs at Ctx build time, so plain
    # output carries the same information as ANSI, just without the decoration.
    test "renders spinner label and its resolved result" do
      result =
        {:spinner, "Loading data", {:ok, "42 rows"}}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "⟳ Loading data...\n  ✓ 42 rows"
    end

    test "renders a failed spinner result with a failure marker" do
      result =
        {:spinner, "Loading data", {:error, "connection refused"}}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "⟳ Loading data...\n  ✗ connection refused"
    end

    test "renders progress label and its resolved result" do
      result =
        {:progress, "Processing files", {:ok, "done"}}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result == "◈ Processing files...\n  ✓ done"
    end
  end

  describe "render_item/1 - edge cases" do
    test "returns nil for unknown item types" do
      assert PlainRenderer.render_item({:unknown, "data"}) == nil
      assert PlainRenderer.render_item("not a tuple") == nil
      assert PlainRenderer.render_item(42) == nil
    end

    test "handles nil values gracefully" do
      assert PlainRenderer.render_item(nil) == nil
    end
  end

  describe "complete context workflows" do
    test "renders a successful command execution" do
      ctx =
        Ctx.new(%{file: "data.csv"}, %{})
        |> Ctx.add_output({:info, "Processing file: data.csv"})
        |> Ctx.add_output({:info, "Reading 1000 rows"})
        |> Ctx.add_output(
          {:table, [["Count", "1000"], ["Status", "OK"]], headers: ["Metric", "Value"]}
        )
        |> Ctx.add_output({:success, "Processing complete"})
        |> Ctx.complete(:ok)

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result =~ "Processing file: data.csv"
      assert result =~ "Reading 1000 rows"
      assert result =~ "Metric"
      assert result =~ "Value"
      assert result =~ "Count"
      assert result =~ "1000"
      assert result =~ "✓ Processing complete"
    end

    test "renders a failed command execution" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:info, "Starting operation"})
        |> Ctx.add_error("File not found: config.yml")
        |> Ctx.add_output({:error, "Operation aborted"})
        |> Ctx.complete(:error)

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result =~ "✗ File not found: config.yml"
      assert result =~ "Starting operation"
      assert result =~ "✗ Operation aborted"
    end

    test "renders mixed output types" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:warning, "Deprecated function used"})
        |> Ctx.add_output({:list, ["Task 1", "Task 2"], title: "Tasks"})
        |> Ctx.add_output({:info, "Continuing with execution"})
        |> Ctx.complete(:warning)

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result =~ "⚠ Deprecated function used"
      assert result =~ "Tasks:"
      assert result =~ "* Task 1"
      assert result =~ "* Task 2"
      assert result =~ "Continuing with execution"
    end
  end

  describe "ANSI code verification" do
    test "output contains no ANSI escape codes" do
      # Create a context with various output types
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:success, "Success with color"})
        |> Ctx.add_output({:error, "Error with color"})
        |> Ctx.add_output({:warning, "Warning with color"})
        |> Ctx.add_output({:table, [["Data", "Value"]], headers: ["Col1", "Col2"]})
        |> Ctx.add_output({:list, ["Item 1", "Item 2"], title: "List"})

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      # Check for common ANSI escape sequences
      # ESC[
      refute result =~ ~r/\x1b\[/
      # Color codes
      refute result =~ ~r/\x1b\[[0-9;]*m/
      # Clear line
      refute result =~ ~r/\x1b\[K/
      # Home cursor
      refute result =~ ~r/\x1b\[H/
    end

    test "strips any ANSI codes from Owl output" do
      # Even if Owl somehow outputs ANSI codes, they should be stripped
      rows = [["Test", "Data"]]

      result =
        {:table, rows, headers: ["Header1", "Header2"]}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Verify no ANSI codes remain
      refute result =~ ~r/\x1b\[/
    end
  end

  describe "helper functions" do
    test "rows_to_maps converts list of lists with headers" do
      rows = [["Alice", 30], ["Bob", 25]]
      headers = ["Name", "Age"]

      # This is a private function, so we test it indirectly through table rendering
      result =
        {:table, rows, headers: headers}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      assert result =~ "Name"
      assert result =~ "Age"
      assert result =~ "Alice"
    end

    test "handles various data types in tables" do
      rows = [
        [nil, "value"],
        ["string", 123],
        [:atom, true]
      ]

      result =
        {:table, rows, headers: ["Type", "Example"]}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # All values should be converted to strings
      assert result =~ "Type"
      assert result =~ "Example"
      assert result =~ "string"
      assert result =~ "123"
      assert result =~ "atom"
      assert result =~ "true"
    end
  end

  describe "render_item/1 - JSON output" do
    test "renders pretty-printed JSON without ANSI codes" do
      data = %{foo: "bar", count: 42, active: true}

      result =
        {:json, data}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Should contain the actual data
      assert result =~ "foo"
      assert result =~ "bar"
      assert result =~ "count"
      assert result =~ "42"
      assert result =~ "active"
      assert result =~ "true"

      # Should have proper JSON formatting (newlines and indentation)
      assert result =~ "\n"

      # Should NOT have any ANSI escape codes
      refute result =~ ~r/\x1b\[/
    end

    test "renders compact JSON when pretty: false" do
      data = %{foo: "bar", count: 42}

      result =
        {:json, data, [pretty: false]}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Should not have newlines or indentation
      refute result =~ "\n  "

      # Should still have the data
      assert result =~ "foo"
      assert result =~ "bar"
      assert result =~ "42"

      # Should be compact - verify it's valid JSON and compact
      assert {:ok, decoded} = Jason.decode(result)
      assert decoded["foo"] == "bar"
      assert decoded["count"] == 42
    end

    test "handles nested JSON structures" do
      data = %{
        user: %{
          name: "Alice",
          settings: %{
            theme: "dark"
          }
        },
        tags: ["admin", "editor"]
      }

      result =
        {:json, data}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Should contain nested data
      assert result =~ "user"
      assert result =~ "name"
      assert result =~ "Alice"
      assert result =~ "settings"
      assert result =~ "theme"
      assert result =~ "dark"
      assert result =~ "tags"
      assert result =~ "admin"
      assert result =~ "editor"
    end

    test "handles various data types in JSON" do
      data = %{
        string: "text",
        number: 123,
        float: 45.67,
        boolean: false,
        null: nil,
        array: [1, 2, 3]
      }

      result =
        {:json, data}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Verify all types are present
      assert result =~ "text"
      assert result =~ "123"
      assert result =~ "45.67"
      assert result =~ "false"
      assert result =~ "null"

      # Verify array is present - format varies (compact vs pretty)
      assert result =~ "1"
      assert result =~ "2"
      assert result =~ "3"
      assert {:ok, decoded} = Jason.decode(result)
      assert decoded["array"] == [1, 2, 3]
    end

    test "JSON output contains no ANSI escape codes" do
      data = %{
        success: "completed",
        error: "failed",
        warning: "caution",
        info: "notice"
      }

      result =
        {:json, data}
        |> PlainRenderer.render_item()
        |> IO.iodata_to_binary()

      # Verify data is present
      assert result =~ "success"
      assert result =~ "completed"

      # Verify no ANSI codes
      refute result =~ ~r/\x1b\[/
      refute result =~ ~r/\x1b\[[0-9;]*m/
    end

    test "renders JSON in context output" do
      ctx =
        Ctx.new(%{}, %{})
        |> Ctx.add_output({:info, "Response data:"})
        |> Ctx.add_output({:json, %{status: "ok", count: 5}})

      result =
        ctx
        |> PlainRenderer.render()
        |> IO.iodata_to_binary()

      assert result =~ "Response data:"
      assert result =~ "status"
      assert result =~ "ok"
      assert result =~ "count"
      assert result =~ "5"
    end
  end
end
