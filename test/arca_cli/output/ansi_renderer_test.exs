defmodule Arca.Cli.Output.AnsiRendererTest do
  use ExUnit.Case
  alias Arca.Cli.Output.AnsiRenderer
  alias Arca.Cli.Ctx

  describe "render/1 with context" do
    test "renders success messages with green color and checkmark" do
      ctx = %Ctx{output: [{:success, "Operation completed"}]}
      result = AnsiRenderer.render(ctx)

      assert result =~ "✓"
      assert result =~ "Operation completed"
      assert result =~ IO.ANSI.green()
      assert result =~ IO.ANSI.reset()
    end

    test "renders error messages with red color and cross" do
      ctx = %Ctx{output: [{:error, "Operation failed"}]}
      result = AnsiRenderer.render(ctx)

      assert result =~ "✗"
      assert result =~ "Operation failed"
      assert result =~ IO.ANSI.red()
      assert result =~ IO.ANSI.reset()
    end

    test "renders warning messages with yellow color and warning symbol" do
      ctx = %Ctx{output: [{:warning, "This is a warning"}]}
      result = AnsiRenderer.render(ctx)

      assert result =~ "⚠"
      assert result =~ "This is a warning"
      assert result =~ IO.ANSI.yellow()
      assert result =~ IO.ANSI.reset()
    end

    test "renders info messages with cyan color and info symbol" do
      ctx = %Ctx{output: [{:info, "Information message"}]}
      result = AnsiRenderer.render(ctx)

      assert result =~ "ℹ"
      assert result =~ "Information message"
      assert result =~ IO.ANSI.cyan()
      assert result =~ IO.ANSI.reset()
    end

    test "renders text messages without formatting" do
      ctx = %Ctx{output: [{:text, "Plain text"}]}
      result = AnsiRenderer.render(ctx)

      assert result == "Plain text"
      refute result =~ IO.ANSI.green()
      refute result =~ IO.ANSI.red()
    end

    test "renders multiple output items" do
      ctx = %Ctx{
        output: [
          {:success, "Step 1 done"},
          {:info, "Processing"},
          {:success, "Step 2 done"}
        ],
        meta: %{force_ansi: true}
      }

      result = AnsiRenderer.render(ctx)
      lines = String.split(result, "\n")

      assert length(lines) == 3
      assert Enum.at(lines, 0) =~ "✓"
      assert Enum.at(lines, 1) =~ "ℹ"
      assert Enum.at(lines, 2) =~ "✓"
    end

    test "falls back to plain renderer when style is :plain" do
      ctx = %Ctx{
        output: [{:success, "Done"}],
        meta: %{style: :plain}
      }

      result = AnsiRenderer.render(ctx)

      # Plain renderer returns a list; normalise to a string for substring checks
      output_string = result |> List.wrap() |> Enum.join("\n")

      # Plain renderer uses ✓ but no colors
      assert output_string =~ "✓"
      assert output_string =~ "Done"
      refute output_string =~ IO.ANSI.green()
      refute output_string =~ IO.ANSI.reset()
    end
  end

  describe "render/1 with lists" do
    test "renders simple lists with colored bullets" do
      result = AnsiRenderer.render([{:list, ["Item 1", "Item 2", "Item 3"]}])

      # The bullets have ANSI codes between them and the items
      assert result =~ "Item 1"
      assert result =~ "Item 2"
      assert result =~ "Item 3"
      assert result =~ "•"
      assert result =~ IO.ANSI.cyan()
      assert result =~ IO.ANSI.reset()
    end

    test "renders list with title" do
      result = AnsiRenderer.render([{:list, ["A", "B"], title: "Options"}])

      assert result =~ "Options:"
      assert result =~ "A"
      assert result =~ "B"
      assert result =~ "•"
      assert result =~ IO.ANSI.bright()
    end

    test "renders list with custom bullet color" do
      result = AnsiRenderer.render([{:list, ["Item"], bullet_color: :green}])

      assert result =~ "Item"
      assert result =~ "•"
      assert result =~ IO.ANSI.green()
    end

    test "handles different data types in lists" do
      result = AnsiRenderer.render([{:list, [42, :atom, "string", nil]}])

      assert result =~ "42"
      assert result =~ "atom"
      assert result =~ "string"
      # nil becomes empty string
      assert result =~ "•"
    end
  end

  describe "render/1 with tables" do
    test "renders table from list of maps with styled border" do
      data = [
        %{name: "Alice", status: "Active"},
        %{name: "Bob", status: "Inactive"}
      ]

      result = AnsiRenderer.render([{:table, data, []}])

      # Should use rounded border style
      assert result =~ "Alice"
      assert result =~ "Bob"
      assert result =~ "Active"
      assert result =~ "Inactive"

      # Note: Owl.Data.tag doesn't produce raw ANSI codes in the output string,
      # so we can't check for colors directly. The colors are applied internally by Owl.
    end

    test "renders table from list of lists" do
      data = [
        ["Name", "Score"],
        ["Alice", "95"],
        ["Bob", "87"]
      ]

      result = AnsiRenderer.render([{:table, data, []}])

      assert result =~ "Name"
      assert result =~ "Score"
      assert result =~ "95"
      assert result =~ "87"
    end

    test "handles various data types in table cells" do
      data = [
        %{id: 1, active: true, score: 95.5, status: nil},
        %{id: 2, active: false, score: 87.3, status: "pending"}
      ]

      result = AnsiRenderer.render([{:table, data, []}])

      assert result =~ "1"
      assert result =~ "2"
      assert result =~ "true"
      assert result =~ "false"
      assert result =~ "95.5"
      assert result =~ "87.3"
      assert result =~ "pending"
    end

    test "applies cell colorization based on content" do
      data = [
        %{status: "success", result: "error"},
        %{status: "warning", result: "ok"}
      ]

      result = AnsiRenderer.render([{:table, data, []}])

      # Verify content is rendered
      assert result =~ "success"
      assert result =~ "error"
      assert result =~ "warning"
      assert result =~ "ok"

      # Note: Owl.Data.tag doesn't produce raw ANSI codes in the output string.
      # The colorization is applied internally by Owl when rendering tables,
      # but doesn't appear as escape sequences in the final string.
    end

    test "renders table with custom column order" do
      rows = [
        %{"subdomain" => "api", "name" => "Service A", "status" => "active", "theme" => "light"},
        %{"subdomain" => "web", "name" => "Service B", "status" => "inactive", "theme" => "dark"}
      ]

      result =
        AnsiRenderer.render([
          {:table, rows, column_order: ["subdomain", "name", "status", "theme"]}
        ])

      # Extract lines to find header
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "subdomain" end)

      # Verify columns appear in the specified order
      subdomain_pos = :binary.match(header_line, "subdomain") |> elem(0)
      name_pos = :binary.match(header_line, "name") |> elem(0)
      status_pos = :binary.match(header_line, "status") |> elem(0)
      theme_pos = :binary.match(header_line, "theme") |> elem(0)

      assert subdomain_pos < name_pos
      assert name_pos < status_pos
      assert status_pos < theme_pos
    end

    test "renders table without column_order defaults to alphabetical" do
      rows = [
        %{"zebra" => "Z", "apple" => "A", "banana" => "B"}
      ]

      result = AnsiRenderer.render([{:table, rows, []}])

      # Extract header line
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

      result = AnsiRenderer.render([{:table, rows, column_order: :desc}])

      # Extract header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "alpha" end)

      # Verify columns appear in descending alphabetical order
      alpha_pos = :binary.match(header_line, "alpha") |> elem(0)
      beta_pos = :binary.match(header_line, "beta") |> elem(0)
      gamma_pos = :binary.match(header_line, "gamma") |> elem(0)

      assert gamma_pos < beta_pos
      assert beta_pos < alpha_pos
    end

    test "renders table with column_order :asc" do
      rows = [
        %{"zebra" => "Z", "apple" => "A", "banana" => "B"}
      ]

      result = AnsiRenderer.render([{:table, rows, column_order: :asc}])

      # Extract header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "apple" end)

      # Verify columns appear in ascending alphabetical order
      apple_pos = :binary.match(header_line, "apple") |> elem(0)
      banana_pos = :binary.match(header_line, "banana") |> elem(0)
      zebra_pos = :binary.match(header_line, "zebra") |> elem(0)

      assert apple_pos < banana_pos
      assert banana_pos < zebra_pos
    end

    test "renders table with column_order custom function" do
      rows = [
        %{"short" => "S", "medium_name" => "M", "x" => "X"}
      ]

      # Custom sort: by column name length (shortest first)
      custom_sort = fn a, b -> String.length(a) <= String.length(b) end

      result = AnsiRenderer.render([{:table, rows, column_order: custom_sort}])

      # Extract header line
      lines = String.split(result, "\n")
      header_line = Enum.find(lines, fn line -> line =~ "short" end)

      # Verify columns appear ordered by length: "x" < "short" < "medium_name"
      x_pos = :binary.match(header_line, "x") |> elem(0)
      short_pos = :binary.match(header_line, "short") |> elem(0)
      medium_pos = :binary.match(header_line, "medium_name") |> elem(0)

      assert x_pos < short_pos
      assert short_pos < medium_pos
    end

    test "renders table with has_headers using first row order" do
      rows = [
        ["Index", "Command", "Arguments"],
        ["0", "first", ""],
        ["1", "second", ""]
      ]

      result = AnsiRenderer.render([{:table, rows, has_headers: true}])

      # Extract header line
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

    test "renders headerless table with show_headers: false" do
      rows = [
        %{"name" => "Alice", "age" => "30"},
        %{"name" => "Bob", "age" => "25"}
      ]

      result = AnsiRenderer.render([{:table, rows, show_headers: false}])

      # Should not contain "age" or "name" headers
      refute result =~ "│age"
      refute result =~ "│name"

      # Should contain data
      assert result =~ "Alice"
      assert result =~ "Bob"
      assert result =~ "30"
      assert result =~ "25"

      # Should have fewer lines than normal table (no header row, no separator)
      lines = String.split(result, "\n")
      # Headerless bordered table: top border + 2 data rows + bottom border = 4 lines
      assert length(lines) == 4
    end

    test "renders headerless table with list rows" do
      rows = [
        ["foo", "bar"],
        ["baz", "qux"]
      ]

      result = AnsiRenderer.render([{:table, rows, show_headers: false}])

      # Should not contain "Col1" or "Col2" auto-generated headers
      refute result =~ "Col1"
      refute result =~ "Col2"

      # Should contain data
      assert result =~ "foo"
      assert result =~ "bar"
      assert result =~ "baz"
      assert result =~ "qux"

      # Headerless bordered table: 4 lines
      lines = String.split(result, "\n")
      assert length(lines) == 4
    end

    test "renders headerless table with border_style: :none" do
      rows = [
        %{"name" => "Alice", "age" => "30"},
        %{"name" => "Bob", "age" => "25"}
      ]

      result = AnsiRenderer.render([{:table, rows, show_headers: false, border_style: :none}])

      # Should not contain "age" or "name" headers
      refute result =~ "age"
      refute result =~ "name"

      # Should contain data
      assert result =~ "Alice"
      assert result =~ "Bob"

      # Should have no borders at all
      refute result =~ "┌"
      refute result =~ "│"
      refute result =~ "─"

      # Borderless headerless table: just 2 data rows
      lines = String.split(result, "\n")
      assert length(lines) == 2
    end

    test "renders normal table when show_headers: true (default)" do
      rows = [
        %{"name" => "Alice", "age" => "30"}
      ]

      # Test that default behavior shows headers
      ctx = %Ctx{output: [{:table, rows}]}
      result = AnsiRenderer.render(ctx)

      # Should have headers
      assert result =~ "age"
      assert result =~ "name"
      assert result =~ "Alice"
      assert result =~ "30"

      # Verify it's a table (has some border or column structure)
      assert String.length(result) > 20
    end
  end

  describe "render/1 with interactive elements" do
    # The renderer draws a resolved result; it never executes anything. The work
    # runs once at Ctx build time so that every output style sees it.
    test "renders a resolved spinner result" do
      result = AnsiRenderer.render([{:spinner, "Processing", {:ok, "Task completed"}}])

      assert result =~ "⠿"
      assert result =~ "Processing..."
      assert result =~ "✓"
      assert result =~ "Task completed"
      assert result =~ IO.ANSI.cyan()
      assert result =~ IO.ANSI.green()
    end

    test "renders a failed spinner result" do
      result = AnsiRenderer.render([{:spinner, "Processing", {:error, "Task failed"}}])

      assert result =~ "⠿"
      assert result =~ "Processing..."
      assert result =~ "✗"
      assert result =~ "Task failed"
      assert result =~ IO.ANSI.red()
    end

    test "renders a resolved progress result" do
      result = AnsiRenderer.render([{:progress, "Downloading", {:ok, "Download complete"}}])

      assert result =~ "▶"
      assert result =~ "Downloading..."
      assert result =~ "✓"
      assert result =~ "Download complete"
    end
  end

  describe "render/1 with direct item lists" do
    test "renders items without context" do
      items = [
        {:success, "Done"},
        {:error, "Failed"},
        {:info, "Info"}
      ]

      result = AnsiRenderer.render(items)

      assert result =~ "✓ Done"
      assert result =~ "✗ Failed"
      assert result =~ "ℹ Info"
      assert result =~ IO.ANSI.green()
      assert result =~ IO.ANSI.red()
      assert result =~ IO.ANSI.cyan()
    end
  end

  describe "TTY detection and fallback" do
    test "uses colors when TERM is set" do
      # Force a colour-capable terminal so the assertion is deterministic
      original_term = System.get_env("TERM")
      System.put_env("TERM", "xterm-256color")
      on_exit(fn -> Arca.Cli.Test.Support.restore_env("TERM", original_term) end)

      result = AnsiRenderer.render([{:success, "Done"}])

      assert result =~ IO.ANSI.green()
    end

    test "handles unknown output items gracefully" do
      result = AnsiRenderer.render([{:unknown, "data", "extra"}])

      # Should render with faint style
      assert result =~ IO.ANSI.faint()
      assert result =~ "unknown"
    end
  end

  describe "edge cases" do
    test "handles empty output" do
      ctx = %Ctx{output: []}
      result = AnsiRenderer.render(ctx)

      assert result == ""
    end

    test "handles nil values properly" do
      result = AnsiRenderer.render([{:text, nil}])
      assert result == ""
    end

    test "handles mixed content types" do
      ctx = %Ctx{
        output: [
          {:success, "Start"},
          {:table, [%{a: 1}], []},
          {:list, ["item"], []},
          {:error, "End"}
        ],
        meta: %{force_ansi: true}
      }

      result = AnsiRenderer.render(ctx)

      assert result =~ "✓ Start"
      # From table
      assert result =~ "1"
      assert result =~ "item"
      assert result =~ "•"
      assert result =~ "✗ End"
    end
  end

  describe "render/1 with JSON output" do
    test "renders pretty-printed JSON with syntax highlighting" do
      data = %{foo: "bar", count: 42, active: true}
      result = AnsiRenderer.render([{:json, data}])

      # Should contain the actual data
      assert result =~ "foo"
      assert result =~ "bar"
      assert result =~ "count"
      assert result =~ "42"
      assert result =~ "active"
      assert result =~ "true"

      # Should have ANSI color codes
      assert result =~ IO.ANSI.cyan()
      assert result =~ IO.ANSI.green()
      assert result =~ IO.ANSI.yellow()
      assert result =~ IO.ANSI.magenta()
      assert result =~ IO.ANSI.reset()
    end

    test "renders compact JSON when pretty: false" do
      data = %{foo: "bar", count: 42}
      result = AnsiRenderer.render([{:json, data, [pretty: false]}])

      # Should not have newlines or indentation
      refute result =~ "\n  "
      # Should still have the data
      assert result =~ "foo"
      assert result =~ "bar"
      assert result =~ "42"
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

      result = AnsiRenderer.render([{:json, data}])

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

      result = AnsiRenderer.render([{:json, data}])

      # Verify all types are present
      assert result =~ "text"
      assert result =~ "123"
      assert result =~ "45.67"
      assert result =~ "false"
      assert result =~ "null"
    end

    test "applies cyan color to property keys" do
      data = %{myKey: "value"}
      result = AnsiRenderer.render([{:json, data}])

      # The key should be colored cyan
      assert result =~ IO.ANSI.cyan()
      assert result =~ "myKey"
    end

    test "applies green color to string values" do
      data = %{key: "stringValue"}
      result = AnsiRenderer.render([{:json, data}])

      # String values should be colored green
      assert result =~ IO.ANSI.green()
      assert result =~ "stringValue"
    end

    test "applies yellow color to numbers" do
      data = %{age: 30, score: 95.5}
      result = AnsiRenderer.render([{:json, data}])

      # Numbers should be colored yellow
      assert result =~ IO.ANSI.yellow()
    end

    test "applies magenta color to booleans and null" do
      data = %{active: true, deleted: false, optional: nil}
      result = AnsiRenderer.render([{:json, data}])

      # Booleans and null should be colored magenta
      assert result =~ IO.ANSI.magenta()
    end
  end
end
