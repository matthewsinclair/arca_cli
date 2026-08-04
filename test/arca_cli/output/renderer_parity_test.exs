defmodule Arca.Cli.Output.RendererParityTest do
  @moduledoc """
  Every `Ctx.output_item` type must render under every style.

  The renderers drifted: `{:list, items}` as a 2-tuple was handled by the ANSI
  renderer but fell through the plain renderer's catch-all to `nil`, and
  `{:json, ...}` was implemented in both renderers while missing from the
  `output_item` type entirely. Drift like that is invisible until a command
  happens to emit the one shape a given renderer forgot.

  This walks the full item list against every style, so a newly added item type
  that only one renderer knows about fails here.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Ctx
  alias Arca.Cli.Output

  @styles [:ansi, :plain, :json]

  # One representative value per output_item shape, each carrying a distinctive
  # marker string so the assertion can prove it actually reached the output.
  @items [
    {"success", {:success, "marker-success"}},
    {"error", {:error, "marker-error"}},
    {"warning", {:warning, "marker-warning"}},
    {"info", {:info, "marker-info"}},
    {"text", {:text, "marker-text"}},
    {"table", {:table, [["marker-table", "b"]], headers: ["h1", "h2"]}},
    {"list/2", {:list, ["marker-list2"]}},
    {"list/3", {:list, ["marker-list3"], title: "t"}},
    {"json/2", {:json, %{"k" => "marker-json2"}}},
    {"json/3", {:json, %{"k" => "marker-json3"}, pretty: false}},
    {"spinner", {:spinner, "spin", {:ok, "marker-spinner"}}},
    {"progress", {:progress, "prog", {:ok, "marker-progress"}}}
  ]

  @spec render_item_as(Ctx.output_item(), atom()) :: String.t()
  defp render_item_as(item, style) do
    Ctx.new(%{}, %{}, command: :parity_probe)
    |> Ctx.add_output(item)
    |> then(&%{&1 | meta: Map.put(&1.meta, :style, style)})
    |> Output.render()
  end

  for style <- @styles, {label, item} <- @items do
    test "invariant: #{label} renders under #{style}" do
      output = render_item_as(unquote(Macro.escape(item)), unquote(style))

      refute output == "", "#{unquote(label)} rendered nothing under #{unquote(style)}"
      assert output =~ "marker-", "#{unquote(label)} lost its content under #{unquote(style)}"
    end
  end

  describe "list arity parity" do
    test "invariant: the 2-tuple and 3-tuple list forms both render in every style" do
      for style <- @styles do
        two = render_item_as({:list, ["alpha"]}, style)
        three = render_item_as({:list, ["alpha"], []}, style)

        assert two =~ "alpha", "{:list, items} lost content under #{style}"
        assert three =~ "alpha", "{:list, items, opts} lost content under #{style}"
      end
    end
  end
end
