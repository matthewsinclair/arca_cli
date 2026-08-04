defmodule Arca.Cli.Output.AnsiRenderer do
  @moduledoc """
  ANSI renderer for Arca.Cli output with colors, symbols, and enhanced formatting.

  This renderer produces visually rich terminal output with:
  - Colored text for different message types
  - Enhanced symbols (✓, ✗, ⚠, ℹ)
  - Styled tables using Owl with borders and colors
  - Formatted lists with colored bullet points
  - Interactive elements like spinners and progress bars

  Falls back to PlainRenderer when TTY is not available.
  """

  alias Arca.Cli.ErrorHandler
  alias Arca.Cli.Output.PlainRenderer

  @doc """
  Renders a context or output items with ANSI formatting.

  ## Parameters

    - ctx_or_items: Either a %Arca.Cli.Ctx{} struct or a list of output items

  ## Returns

    - Formatted string with ANSI escape codes for colors and styling

  ## Examples

      iex> ctx = %Arca.Cli.Ctx{output: [{:success, "Done!"}]}
      iex> render(ctx)
      "✓ Done!"

      iex> render([{:error, "Failed"}])
      "✗ Failed"
  """
  @spec render(Arca.Cli.Ctx.t() | [Arca.Cli.Ctx.output_item()]) :: String.t()
  def render(%Arca.Cli.Ctx{meta: %{style: :plain}} = ctx) do
    ctx
    |> PlainRenderer.render()
    |> IO.iodata_to_binary()
  end

  # No style detection here. Arca.Cli.Output.determine_style/1 is the single
  # authority and only dispatches to this renderer once it has decided on :ansi;
  # a second, differently-written TTY check here could disagree with it.
  def render(%Arca.Cli.Ctx{} = ctx) do
    do_render({:ansi, ctx})
  end

  def render(items) when is_list(items) do
    do_render({:ansi, %Arca.Cli.Ctx{output: items}})
  end

  # Private functions

  defp do_render({:ansi, ctx}) do
    # ctx.errors used to be dropped here entirely: this function read ctx.output
    # and nothing else, so a Ctx command that failed with errors and no output
    # rendered to the empty string. :ansi is the style chosen for an interactive
    # terminal, so the one audience that saw nothing at all was the human the
    # command was written for (finding A25).
    join_sections(render_errors(ctx), render_main(ctx))
  end

  # Errors carry the project dialect line (matching `^error:`, as the plain
  # renderer and the string-returning command paths do) plus the ✗ block.
  @spec render_errors(Arca.Cli.Ctx.t()) :: String.t()
  defp render_errors(%Arca.Cli.Ctx{errors: []}), do: ""

  defp render_errors(%Arca.Cli.Ctx{errors: errors} = ctx) when is_list(errors) do
    errors
    |> Enum.map(&render_failure(ctx, &1))
    |> Enum.join("\n")
  end

  defp render_errors(_ctx), do: ""

  @spec render_main(Arca.Cli.Ctx.t()) :: String.t()
  defp render_main(%Arca.Cli.Ctx{output: output} = ctx) when is_list(output) do
    output
    |> Enum.map(&render_output_item(&1, ctx))
    |> Enum.join("\n")
  end

  defp render_main(%Arca.Cli.Ctx{output: nil}), do: ""

  # Fallback for non-list output
  defp render_main(%Arca.Cli.Ctx{output: other}), do: safe_to_string(other)

  # Both failure channels render through here. See the note in
  # PlainRenderer.render_failure/2 for why the dialect line is tied to
  # `Ctx.failed?/1` -- the same predicate that decides the exit status -- and why
  # the ✗ marker is not.
  @spec render_failure(Arca.Cli.Ctx.t(), String.t()) :: String.t()
  defp render_failure(%Arca.Cli.Ctx{} = ctx, message) do
    failure_lines(Arca.Cli.Ctx.failed?(ctx), Arca.Cli.Ctx.error_context(ctx), message)
  end

  @spec failure_lines(boolean(), String.t() | nil, String.t()) :: String.t()
  defp failure_lines(true, context, message) do
    red(ErrorHandler.error_line(context, message)) <> "\n" <> render_item({:error, message})
  end

  defp failure_lines(false, _context, message), do: render_item({:error, message})

  @spec render_output_item(Arca.Cli.Ctx.output_item(), Arca.Cli.Ctx.t()) :: String.t()
  defp render_output_item({:error, message}, %Arca.Cli.Ctx{} = ctx) when is_binary(message) do
    render_failure(ctx, message)
  end

  defp render_output_item(item, _ctx), do: render_item(item)

  @spec red(String.t()) :: String.t()
  defp red(text), do: IO.ANSI.red() <> text <> IO.ANSI.reset()

  # Same rule the plain renderer uses, so the two styles agree on layout.
  @spec join_sections(String.t(), String.t()) :: String.t()
  defp join_sections("", main), do: main
  defp join_sections(errors, ""), do: errors
  defp join_sections(errors, main), do: errors <> "\n\n" <> main

  # Message renderers with colors and symbols

  defp render_item({:success, message}) do
    IO.ANSI.green() <> "✓ " <> message <> IO.ANSI.reset()
  end

  defp render_item({:error, message}) do
    IO.ANSI.red() <> "✗ " <> message <> IO.ANSI.reset()
  end

  defp render_item({:warning, message}) do
    IO.ANSI.yellow() <> "⚠ " <> message <> IO.ANSI.reset()
  end

  defp render_item({:info, message}) do
    IO.ANSI.cyan() <> "ℹ " <> message <> IO.ANSI.reset()
  end

  defp render_item({:text, message}) do
    message
  end

  # Table renderer with enhanced styling

  defp render_item({:table, rows, opts}) do
    # Handle empty tables gracefully
    case rows do
      [] ->
        ""

      [_ | _] ->
        # Auto-use headers as column_order if headers provided but column_order is not
        # This handles both explicit :headers option and :has_headers where first row contains headers
        opts =
          case {Keyword.get(opts, :headers), Keyword.get(opts, :has_headers), rows,
                Keyword.get(opts, :column_order)} do
            # Explicit headers provided, no column_order
            {headers_list, _, _, nil} when is_list(headers_list) ->
              Keyword.put(opts, :column_order, headers_list)

            # has_headers: true and first row is a list (contains headers), no column_order
            {nil, true, [first_row | _], nil} when is_list(first_row) ->
              Keyword.put(opts, :column_order, Enum.map(first_row, &to_string/1))

            # Otherwise, keep opts as-is
            _ ->
              opts
          end

        # Check if we should show headers (defaults to true for backwards compatibility)
        show_headers = Keyword.get(opts, :show_headers, true)

        # When show_headers is false, ensure has_headers is also false
        # so that list rows don't treat the first row as headers
        opts =
          if not show_headers do
            Keyword.put_new(opts, :has_headers, false)
          else
            opts
          end

        table_opts =
          Keyword.merge(
            [
              border_style: :solid_rounded,
              divide_body_rows: false,
              padding_x: 1,
              render_cell: &colorize_cell/1
            ],
            opts
          )

        # If show_headers is false, modify render_cell to make headers invisible
        table_opts =
          if not show_headers do
            current_render_cell = Keyword.get(table_opts, :render_cell, &Function.identity/1)

            # If render_cell is already a keyword list, preserve body renderer
            # Otherwise, use it for both header (empty) and body
            new_render_cell =
              case current_render_cell do
                opts when is_list(opts) ->
                  Keyword.merge([header: fn _ -> "" end], opts)

                func when is_function(func) ->
                  [header: fn _ -> "" end, body: func]
              end

            Keyword.put(table_opts, :render_cell, new_render_cell)
          else
            table_opts
          end

        # Add column_order support by converting to sort_columns
        table_opts =
          case Keyword.get(table_opts, :column_order) do
            nil ->
              table_opts

            columns when is_list(columns) ->
              # Create a sort function that orders columns based on their position in the list
              sort_fn = fn a, b ->
                a_index = Enum.find_index(columns, &(&1 == a)) || length(columns)
                b_index = Enum.find_index(columns, &(&1 == b)) || length(columns)
                a_index <= b_index
              end

              table_opts
              |> Keyword.delete(:column_order)
              |> Keyword.put(:sort_columns, sort_fn)

            other ->
              # If it's not a list (e.g., :asc, :desc, or a function), pass it through as sort_columns
              table_opts
              |> Keyword.delete(:column_order)
              |> Keyword.put(:sort_columns, other)
          end

        # Render the table
        result =
          rows
          |> prepare_table_data(opts)
          |> Owl.Table.new(table_opts)
          |> Owl.Data.to_chardata()
          |> IO.iodata_to_binary()

        # If show_headers is false, remove the header lines from the output
        if not show_headers do
          remove_header_lines(result, Keyword.get(table_opts, :border_style, :solid_rounded))
        else
          result
        end
    end
  end

  # List renderer with colored bullets

  defp render_item({:list, items}) when is_list(items) do
    render_item({:list, items, []})
  end

  defp render_item({:list, items, opts}) when is_list(items) do
    title = Keyword.get(opts, :title)
    bullet_color = Keyword.get(opts, :bullet_color, :cyan)

    formatted_items =
      items
      |> Enum.map(fn item ->
        bullet = apply(IO.ANSI, bullet_color, []) <> "• " <> IO.ANSI.reset()
        bullet <> safe_to_string(item)
      end)

    if title do
      IO.ANSI.bright() <>
        title <> ":" <> IO.ANSI.reset() <> "\n" <> Enum.join(formatted_items, "\n")
    else
      Enum.join(formatted_items, "\n")
    end
  end

  # Interactive elements

  # The result is already computed: Ctx.add_output/2 runs the work when the item
  # is built, so every style sees the same side effects. Renderers only draw.
  defp render_item({:spinner, label, result}) do
    format_execution_result({label_header(label, "⠿"), result})
  end

  defp render_item({:progress, label, result}) do
    format_execution_result({label_header(label, "▶"), result})
  end

  # JSON renderer with syntax highlighting

  defp render_item({:json, data}) do
    render_item({:json, data, []})
  end

  defp render_item({:json, data, opts}) do
    pretty = Keyword.get(opts, :pretty, true)

    data
    |> Jason.encode!(pretty: pretty)
    |> colorize_json()
  end

  # Fallback for unknown items
  defp render_item(item) do
    IO.ANSI.faint() <> safe_to_string(item) <> IO.ANSI.reset()
  end

  defp label_header(label, symbol) do
    IO.ANSI.cyan() <> symbol <> " " <> label <> "..." <> IO.ANSI.reset()
  end

  defp format_execution_result({header, {:ok, result}}) do
    header <> "\n" <> IO.ANSI.green() <> "  ✓ " <> safe_to_string(result) <> IO.ANSI.reset()
  end

  defp format_execution_result({header, {:error, reason}}) do
    header <> "\n" <> IO.ANSI.red() <> "  ✗ " <> safe_to_string(reason) <> IO.ANSI.reset()
  end

  defp format_execution_result({header, result}) do
    header <> "\n  " <> safe_to_string(result)
  end

  # Helper functions

  defp prepare_table_data(rows, opts) when is_list(rows) do
    rows
    |> classify_rows()
    |> process_rows(opts)
  end

  defp classify_rows(rows) do
    {rows, determine_row_type(rows)}
  end

  defp determine_row_type(rows) do
    case rows do
      [h | _] when is_map(h) -> :maps
      [h | _] when is_list(h) -> :lists
      _ -> :mixed
    end
  end

  defp process_rows({rows, :maps}, _opts) do
    Enum.map(rows, &stringify_map_values/1)
  end

  defp process_rows({rows, :lists}, opts) do
    # Check if first row should be treated as headers
    # Default to true for fancy renderer
    has_headers = Keyword.get(opts, :has_headers, true)

    case {rows, has_headers} do
      {[headers | data], true} when data != [] ->
        # First row is headers
        headers_list = Enum.map(headers, &safe_to_string/1)

        # Auto-set column_order from headers if not explicitly provided
        # This is handled in render_item, but we return headers_list for that function to use
        Enum.map(data, fn row ->
          row
          |> Enum.map(&safe_to_string/1)
          |> Enum.zip(headers_list)
          |> Enum.map(fn {value, key} -> {key, value} end)
          |> Map.new()
        end)

      {rows, _} ->
        # No headers in first row, generate column names
        Enum.map(rows, fn row ->
          row
          |> Enum.with_index()
          |> Enum.map(fn {value, idx} -> {"Col#{idx + 1}", safe_to_string(value)} end)
          |> Map.new()
        end)
    end
  end

  defp process_rows({rows, :mixed}, _opts) do
    Enum.map(rows, &process_mixed_row/1)
  end

  defp process_mixed_row(row) when is_list(row) do
    Enum.map(row, &safe_to_string/1)
  end

  defp process_mixed_row(row) when is_map(row) do
    stringify_map_values(row)
  end

  defp process_mixed_row(row) do
    [safe_to_string(row)]
  end

  defp stringify_map_values(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {k, safe_to_string(v)} end)
  end

  defp safe_to_string(nil), do: ""
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_atom(value), do: to_string(value)
  defp safe_to_string(value) when is_number(value), do: to_string(value)
  defp safe_to_string(value), do: inspect(value)

  # Cell colorization for tables
  defp colorize_cell(cell) when is_binary(cell) do
    cell
    |> classify_cell()
    |> apply_cell_color(cell)
  end

  defp colorize_cell(cell), do: safe_to_string(cell)

  defp classify_cell(cell) do
    normalized = String.downcase(cell)

    cond do
      # Headers pattern - all uppercase
      cell =~ ~r/^[A-Z][A-Z\s]+$/ and cell == String.upcase(cell) -> :header
      # Numbers
      cell =~ ~r/^\d+(\.\d+)?$/ -> :number
      # Success keywords
      normalized in ["success", "ok", "true", "yes", "active"] -> :success
      # Error keywords
      normalized in ["error", "failed", "false", "no", "inactive"] -> :error
      # Warning keywords
      normalized in ["warning", "pending", "maybe"] -> :warning
      # Default
      true -> :default
    end
  end

  defp apply_cell_color(:header, cell), do: Owl.Data.tag(cell, :bright)
  defp apply_cell_color(:number, cell), do: Owl.Data.tag(cell, :cyan)
  defp apply_cell_color(:success, cell), do: Owl.Data.tag(cell, :green)
  defp apply_cell_color(:error, cell), do: Owl.Data.tag(cell, :red)
  defp apply_cell_color(:warning, cell), do: Owl.Data.tag(cell, :yellow)
  defp apply_cell_color(:default, cell), do: cell

  # Remove header lines from table output for headerless tables
  @spec remove_header_lines(String.t(), atom()) :: String.t()
  defp remove_header_lines(table_string, border_style) do
    lines = String.split(table_string, "\n")

    case border_style do
      :none ->
        # For borderless tables, just remove the first line (header row)
        case lines do
          [_header_row | data_rows] -> Enum.join(data_rows, "\n")
          _ -> table_string
        end

      _ ->
        # For bordered tables, remove top border, header row, and separator
        # Then add back the top border
        case lines do
          [top_border, _header_row, _separator | body_and_bottom] ->
            [top_border | body_and_bottom]
            |> Enum.join("\n")

          _ ->
            table_string
        end
    end
  end

  # JSON syntax highlighting
  defp colorize_json(json_string) when is_binary(json_string) do
    json_string
    # Colorize property keys (e.g., "key":)
    |> String.replace(~r/"([^"]+)"\s*:/, fn match ->
      [_, key] = Regex.run(~r/"([^"]+)"\s*:/, match)
      IO.ANSI.cyan() <> "\"#{key}\"" <> IO.ANSI.reset() <> ":"
    end)
    # Colorize string values (e.g., : "value")
    |> String.replace(~r/:\s*"([^"]*)"/, fn match ->
      [_, value] = Regex.run(~r/:\s*"([^"]*)"/, match)
      ": " <> IO.ANSI.green() <> "\"#{value}\"" <> IO.ANSI.reset()
    end)
    # Colorize numbers
    |> String.replace(~r/:\s*(-?\d+\.?\d*)([,\s\n\}])/, fn match ->
      [_, number, trailing] = Regex.run(~r/:\s*(-?\d+\.?\d*)([,\s\n\}])/, match)
      ": " <> IO.ANSI.yellow() <> number <> IO.ANSI.reset() <> trailing
    end)
    # Colorize booleans and null
    |> String.replace(~r/:\s*(true|false|null)([,\s\n\}])/, fn match ->
      [_, value, trailing] = Regex.run(~r/:\s*(true|false|null)([,\s\n\}])/, match)
      ": " <> IO.ANSI.magenta() <> value <> IO.ANSI.reset() <> trailing
    end)
  end
end
