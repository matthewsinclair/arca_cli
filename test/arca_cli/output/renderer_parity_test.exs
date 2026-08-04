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

  # A context reports failure two ways, and the completeness claim about the
  # error dialect has now been wrong twice: once because `:ansi` rendered
  # ctx.errors not at all (A25), and once because the `{:error, _}` OUTPUT item
  # channel carried no dialect line while `add_error/2` did (found by vc). Both
  # times the claim was reasoned rather than probed, and both times the untested
  # combination was the broken one.
  #
  # So this is written as a cross-product over (channel x text style) rather than
  # as assertions about the channels one at a time. A third channel added later
  # needs a row here, and will fail until it has one.
  @failure_channels [
    {"add_error/2", :add_error},
    {"{:error, _} output item", :error_output_item}
  ]

  # JSON is excluded by design, not by omission: it reports failure structurally
  # (`"status": "error"` plus `errors`), and a dialect line inside a JSON
  # document would corrupt it. hv's ruling was text styles only.
  @text_styles [:ansi, :plain]

  @spec report_failure(Ctx.t(), atom()) :: Ctx.t()
  defp report_failure(ctx, :add_error), do: Ctx.add_error(ctx, "marker-failure")

  defp report_failure(ctx, :error_output_item),
    do: Ctx.add_output(ctx, {:error, "marker-failure"})

  @spec failing_ctx_as(atom(), atom()) :: String.t()
  defp failing_ctx_as(channel, style) do
    Ctx.new(%{}, %{}, command: :"parity.probe")
    |> report_failure(channel)
    |> Ctx.complete(:error)
    |> then(&%{&1 | meta: Map.put(&1.meta, :style, style)})
    |> Output.render()
    |> String.replace(~r/\e\[[0-9;]*m/, "")
  end

  for style <- @text_styles, {label, channel} <- @failure_channels do
    test "invariant: a failure reported via #{label} is greppable under #{style}" do
      lines =
        unquote(channel)
        |> failing_ctx_as(unquote(style))
        |> String.split("\n")

      assert Enum.any?(lines, &String.starts_with?(&1, "error: parity.probe: ")),
             "#{unquote(label)} produced no `^error:` line under #{unquote(style)}"
    end
  end

  describe "the dialect line means failure, not decoration" do
    test "invariant: an error-styled item in a SUCCEEDING context emits no error line" do
      for style <- @text_styles do
        output =
          Ctx.new(%{}, %{}, command: :"parity.probe")
          |> Ctx.add_output({:error, "3 of 40 rows rejected"})
          |> Ctx.complete(:ok)
          |> then(&%{&1 | meta: Map.put(&1.meta, :style, style)})
          |> Output.render()
          |> String.replace(~r/\e\[[0-9;]*m/, "")

        refute output =~ ~r/^error:/m,
               "a succeeding command emitted `^error:` under #{style}, so the grep over-reports"

        assert output =~ "3 of 40 rows rejected",
               "the error-styled line itself was lost under #{style}"
      end
    end
  end
end
