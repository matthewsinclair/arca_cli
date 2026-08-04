defmodule Arca.Cli.Output.JsonRenderer do
  @moduledoc """
  JSON renderer for Arca.Cli output.

  This renderer produces JSON output for structured data, suitable for:
  - Machine-readable output
  - API integration
  - Automation and scripting

  The JSON output is pretty-printed for readability.
  """

  alias Arca.Cli.Ctx

  @doc """
  Renders a context as pretty-printed JSON.

  ## Parameters
    - ctx: The Context struct to render

  ## Returns
    - JSON string representation of the context

  ## Examples

      iex> ctx = %Ctx{output: [{:success, "Done"}], status: :ok}
      iex> JsonRenderer.render(ctx)
      ~s({"status": "ok", "output": [{"type": "success", "message": "Done"}]})
  """
  @spec render(Ctx.t()) :: String.t()
  def render(%Ctx{} = ctx) do
    ctx
    |> to_json_map()
    |> Jason.encode!(pretty: true)
  end

  # Convert Context to JSON-serializable map.
  #
  # The status reported is `Ctx.outcome/1`, not the raw `ctx.status` field: they
  # differ when a command records errors and never calls `complete/2`, and the
  # raw field loses that. Such a context exits 1, but its raw status is nil, which
  # the nil-rejection below then dropped from the document entirely -- so a
  # machine consumer saw a failing command as a result with no status at all
  # (finding A28). `outcome/1` is the same authority dispatch uses for the exit
  # code, so the JSON and the exit status now always agree.
  defp to_json_map(%Ctx{} = ctx) do
    %{
      command: ctx.command,
      status: Ctx.outcome(ctx),
      output: format_output(ctx.output),
      errors: ctx.errors,
      cargo: ctx.cargo,
      meta: ctx.meta
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) || v == [] || v == %{} end)
    |> Map.new()
  end

  # Format output items for JSON
  defp format_output(output) when is_list(output) do
    Enum.map(output, &format_output_item/1)
  end

  defp format_output(_), do: []

  # Convert output items to JSON-friendly format
  defp format_output_item({:success, message}) do
    %{type: "success", message: message}
  end

  defp format_output_item({:error, message}) do
    %{type: "error", message: message}
  end

  defp format_output_item({:warning, message}) do
    %{type: "warning", message: message}
  end

  defp format_output_item({:info, message}) do
    %{type: "info", message: message}
  end

  defp format_output_item({:text, content}) do
    %{type: "text", content: content}
  end

  defp format_output_item({:table, rows, opts}) do
    %{
      type: "table",
      rows: rows,
      options: Enum.into(opts, %{})
    }
  end

  defp format_output_item({:list, items}) do
    format_output_item({:list, items, []})
  end

  defp format_output_item({:list, items, opts}) do
    %{
      type: "list",
      items: items,
      options: Enum.into(opts, %{})
    }
  end

  # The result is included: it was computed at Ctx build time, so JSON consumers
  # get the same information a TTY user sees rather than a bare label.
  defp format_output_item({:spinner, label, result}) do
    %{type: "spinner", label: label, result: jsonable(result)}
  end

  defp format_output_item({:progress, label, result}) do
    %{type: "progress", label: label, result: jsonable(result)}
  end

  defp format_output_item({:json, data}) do
    %{type: "json", data: data}
  end

  defp format_output_item({:json, data, _opts}) do
    %{type: "json", data: data}
  end

  defp format_output_item(other) do
    %{type: "unknown", data: inspect(other)}
  end

  # A resolved spinner result is whatever the command's function returned, so it
  # may well be a tuple or another term Jason cannot encode. Pass through what is
  # natively encodable and inspect the rest, rather than raising at render time.
  defp jsonable(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp jsonable(value) when is_atom(value), do: to_string(value)
  defp jsonable(value) when is_list(value), do: Enum.map(value, &jsonable/1)
  defp jsonable(%{__struct__: _} = value), do: inspect(value)

  defp jsonable(value) when is_map(value),
    do: Map.new(value, fn {k, v} -> {jsonable(k), jsonable(v)} end)

  defp jsonable(value), do: inspect(value)
end
