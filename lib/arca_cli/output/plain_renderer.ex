defmodule Arca.Cli.Output.PlainRenderer do
  @moduledoc """
  Plain text renderer for Arca.CLI Context output.

  This module renders Context output items as plain text without any ANSI codes
  or color formatting. It's used in test environments, non-TTY outputs, and
  when users explicitly request plain output.

  Tables are rendered using Owl with simple box-drawing characters (Unicode),
  ensuring clean table output without ANSI color codes.

  ## Usage

      ctx = Arca.Cli.Ctx.new(%{}, %{})
            |> Ctx.add_output({:info, "Processing..."})
            |> Ctx.add_output({:success, "Complete!"})
            |> Ctx.complete(:ok)

      output = Arca.Cli.Output.PlainRenderer.render(ctx)
      IO.puts(output)

  ## Output Examples

      # Messages
      ✓ Success message
      ✗ Error message
      ⚠ Warning message
      Info message

      # Tables (box-drawing borders via Owl)
      ┌──────────┬───────┐
      │ Name     │ Age   │
      ├──────────┼───────┤
      │ Alice    │ 30    │
      │ Bob      │ 25    │
      └──────────┴───────┘

      # Lists
      Items:
      * First item
      * Second item
  """

  alias Arca.Cli.Ctx
  alias Arca.Cli.Utils.OwlHelper

  @doc """
  Renders a Context to plain text output.

  Takes a Context struct and renders all output items as plain text,
  without any ANSI escape codes or color formatting.

  ## Parameters
    - ctx: The Context struct to render

  ## Returns
    - IO list that can be converted to string with IO.iodata_to_binary/1
  """
  @spec render(Ctx.t()) :: iodata()
  def render(%Ctx{} = ctx) do
    # Render any errors first if status is :error
    error_output = render_errors(ctx)

    # Render all output items in order
    main_output =
      case ctx.output do
        output when is_list(output) ->
          output
          |> Enum.map(&render_item/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.intersperse("\n")

        nil ->
          []

        other ->
          # Fallback for non-list output
          [safe_to_string(other)]
      end

    # Combine error output and main output
    case {error_output, main_output} do
      {[], []} -> []
      {[], main} -> main
      {errors, []} -> errors
      {errors, main} -> [errors, "\n\n", main]
    end
  end

  @doc """
  Renders error messages from the context.

  ## Parameters
    - ctx: The Context struct containing errors

  ## Returns
    - IO list of formatted error messages
  """
  @spec render_errors(Ctx.t()) :: iodata()
  def render_errors(%Ctx{errors: []}) do
    []
  end

  def render_errors(%Ctx{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn error -> ["✗ ", error] end)
    |> Enum.intersperse("\n")
  end

  @doc """
  Renders a single output item.

  Pattern matches on the output item type and delegates to the appropriate
  renderer function.

  ## Parameters
    - item: Output item tuple

  ## Returns
    - IO list for the rendered item, or nil if unknown type
  """
  @spec render_item(Ctx.output_item()) :: iodata() | nil

  # Message types
  def render_item({:success, message}) when is_binary(message) do
    ["✓ ", message]
  end

  def render_item({:error, message}) when is_binary(message) do
    ["✗ ", message]
  end

  def render_item({:warning, message}) when is_binary(message) do
    ["⚠ ", message]
  end

  def render_item({:info, message}) when is_binary(message) do
    message
  end

  def render_item({:text, content}) when is_binary(content) do
    content
  end

  # Table rendering using Owl
  def render_item({:table, rows, opts}) when is_list(rows) do
    render_table(rows, opts)
  end

  # List rendering
  def render_item({:list, items, opts}) when is_list(items) do
    render_list(items, opts)
  end

  # Interactive elements - show label only in plain mode
  def render_item({:spinner, label, _func}) when is_binary(label) do
    ["⟳ ", label]
  end

  def render_item({:progress, label, _func}) when is_binary(label) do
    ["◈ ", label]
  end

  # JSON rendering
  def render_item({:json, data}) do
    render_item({:json, data, []})
  end

  def render_item({:json, data, opts}) do
    pretty = Keyword.get(opts, :pretty, true)
    Jason.encode!(data, pretty: pretty)
  end

  # Catch-all for unknown types
  def render_item(_unknown) do
    nil
  end

  @doc """
  Renders a table using Owl with ASCII borders.

  ## Parameters
    - rows: List of rows (list of lists or list of maps)
    - opts: Options including :headers

  ## Returns
    - IO list containing the formatted table
  """
  @spec render_table(list(), keyword()) :: iodata()
  def render_table([], _opts) do
    "(empty table)"
  end

  def render_table(rows, opts) do
    # When show_headers is false, ensure has_headers is also false
    # so that list rows don't treat the first row as headers
    opts =
      if Keyword.get(opts, :show_headers, true) == false do
        Keyword.put_new(opts, :has_headers, false)
      else
        opts
      end

    # Check if we should treat first row as headers
    {headers, data_rows} =
      case {rows, Keyword.get(opts, :has_headers, false)} do
        {[h | t], true} when is_list(h) ->
          # First row is headers
          {h, t}

        {rows, _} ->
          # No headers in data, may be provided separately or generated
          {Keyword.get(opts, :headers), rows}
      end

    # Convert rows to list of maps format for Owl
    data = rows_to_maps(data_rows, headers)

    # Determine column preferences based on data
    column_prefs = build_column_preferences(data)

    # Build Owl table with solid border style (closest to ASCII)
    # Note: Owl doesn't have pure ASCII borders, but :solid uses simple box-drawing chars
    # Merge incoming opts with defaults to support column_order and other OwlHelper options
    default_table_opts = [
      border_style: :solid,
      divide_body_rows: false,
      padding_x: 1
    ]

    # Auto-use headers as column_order if headers provided but column_order is not
    # This handles both explicit :headers option and :has_headers where first row contains headers
    opts =
      case {headers, Keyword.get(opts, :column_order)} do
        {headers_list, nil} when is_list(headers_list) ->
          Keyword.put(opts, :column_order, headers_list)

        _ ->
          opts
      end

    # Check if we should show headers (defaults to true for backwards compatibility)
    show_headers = Keyword.get(opts, :show_headers, true)

    # Extract relevant OwlHelper options from incoming opts
    # OwlHelper supports: column_order, max_width, and all Owl.Table options
    table_opts = Keyword.merge(default_table_opts, opts)

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

    table =
      if map_size(column_prefs) > 0 do
        OwlHelper.table(data, column_prefs, table_opts)
      else
        # Fallback to basic Owl.Table if no column preferences
        Owl.Table.new(data, table_opts)
      end

    # Convert to plain text (no ANSI codes)
    result =
      table
      |> Owl.Data.to_chardata()
      |> strip_ansi_codes()

    # If show_headers is false, remove the header lines from the output
    if not show_headers do
      remove_header_lines(result, Keyword.get(table_opts, :border_style, :solid))
    else
      result
    end
  end

  @doc """
  Renders a list with bullet points.

  ## Parameters
    - items: List of items to render
    - opts: Options including :title

  ## Returns
    - IO list containing the formatted list
  """
  @spec render_list(list(), keyword()) :: iodata()
  def render_list([], _opts) do
    "(empty list)"
  end

  def render_list(items, opts) do
    title = Keyword.get(opts, :title)

    # Build title line if provided
    title_line =
      if title do
        [title, ":\n"]
      else
        []
      end

    # Format items with bullet points
    item_lines =
      items
      |> Enum.map(fn item -> ["* ", item_to_string(item)] end)
      |> Enum.intersperse("\n")

    [title_line, item_lines]
  end

  # Private helper functions

  # Convert list item to string safely
  defp item_to_string(item) when is_binary(item), do: item
  defp item_to_string(item) when is_atom(item), do: Atom.to_string(item)
  defp item_to_string(item) when is_integer(item), do: Integer.to_string(item)
  defp item_to_string(item) when is_float(item), do: Float.to_string(item)
  defp item_to_string(item), do: inspect(item)

  # Convert list of lists to list of maps for Owl.Table
  defp rows_to_maps(rows, nil) when is_list(rows) do
    case rows do
      [] ->
        []

      # Generate column names for list of lists
      [first_row | _] when is_list(first_row) ->
        headers =
          first_row
          |> Enum.with_index(1)
          |> Enum.map(fn {_, idx} -> "Column #{idx}" end)

        rows_to_maps(rows, headers)

      # Already in map format
      [first_row | _] when is_map(first_row) ->
        rows |> Enum.map(&stringify_map_values/1)

      _ ->
        []
    end
  end

  defp rows_to_maps(rows, headers) when is_list(rows) and is_list(headers) do
    Enum.map(rows, fn
      row when is_list(row) ->
        headers
        |> Enum.zip(row)
        |> Map.new(fn {k, v} -> {k, safe_to_string(v)} end)

      row when is_map(row) ->
        stringify_map_values(row)

      _other ->
        %{}
    end)
  end

  # Convert all map values to strings safely, and ensure keys are strings too
  defp stringify_map_values(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {safe_to_string(k), safe_to_string(v)}
    end)
  end

  # Safely convert any value to string
  defp safe_to_string(nil), do: ""
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp safe_to_string(value) when is_float(value), do: Float.to_string(value)
  defp safe_to_string(value), do: inspect(value)

  # Build column width preferences based on data
  defp build_column_preferences([]) do
    %{}
  end

  defp build_column_preferences([first | _] = data) when is_map(first) do
    columns = Map.keys(first)

    # Calculate max width for each column
    Enum.reduce(columns, %{}, fn col, prefs ->
      max_width = calculate_column_width(data, col)
      Map.put(prefs, to_string(col), max_width)
    end)
  end

  defp build_column_preferences(_) do
    %{}
  end

  # Calculate optimal width for a column
  defp calculate_column_width(data, column) do
    # Get all values for this column
    values =
      data
      |> Enum.map(&Map.get(&1, column, ""))
      |> Enum.map(&to_string/1)

    # Include column header in width calculation
    all_values = [to_string(column) | values]

    # Find max length, capped at reasonable limits
    max_length =
      all_values
      |> Enum.map(&String.length/1)
      |> Enum.max()

    # Cap at 50 characters for any single column
    min(max_length + 2, 50)
  end

  # Strip ANSI codes from output (safety measure)
  defp strip_ansi_codes(iodata) when is_list(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> strip_ansi_codes()
  end

  defp strip_ansi_codes(binary) when is_binary(binary) do
    # Remove ANSI escape sequences
    # Pattern matches: ESC [ ... m
    String.replace(binary, ~r/\x1b\[[0-9;]*m/, "")
  end

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
end
