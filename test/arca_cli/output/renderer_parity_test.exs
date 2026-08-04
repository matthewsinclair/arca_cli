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
  # error dialect has now been wrong three times: `:ansi` rendered ctx.errors not
  # at all (A25); the `{:error, _}` OUTPUT item channel carried no dialect line
  # while `add_error/2` did (A27); and then the guard that fixed A27 was applied
  # to that one channel, so `add_error/2 |> complete(:ok)` printed `error:` while
  # exiting 0 (A28, found by vc).
  #
  # Each time the claim was reasoned rather than probed, and each time the
  # untested COMBINATION was the broken one. The cross-product that stood here
  # after A27 covered channel x style with the completion pinned to :error on
  # every row -- so the axis that actually discriminated was held constant, and
  # A28 walked straight through it.
  #
  # It is now channel x completion x style, and it asserts the BICONDITIONAL
  # rather than mere presence: an `^error:` line appears if and only if the
  # context failed. Presence-only was what let A28 hide, because row B printed the
  # line and passed. A new channel or completion state needs a row here and fails
  # until it has one.
  @failure_channels [
    {"add_error/2", :add_error},
    {"{:error, _} output item", :error_output_item}
  ]

  @completions [
    {"complete(:error)", :error},
    {"complete(:ok)", :ok},
    {"complete(:warning)", :warning},
    {"never completed", :none}
  ]

  # JSON is excluded from the TEXT cross-product by design, not by omission: it
  # reports failure structurally, and a dialect line inside a JSON document would
  # corrupt it. hv's ruling was text styles only. JSON's own agreement with
  # Ctx.outcome/1 is asserted separately below.
  @text_styles [:ansi, :plain]

  @spec report_failure(Ctx.t(), atom()) :: Ctx.t()
  defp report_failure(ctx, :add_error), do: Ctx.add_error(ctx, "marker-failure")

  defp report_failure(ctx, :error_output_item),
    do: Ctx.add_output(ctx, {:error, "marker-failure"})

  @spec finish(Ctx.t(), atom()) :: Ctx.t()
  defp finish(ctx, :none), do: ctx
  defp finish(ctx, status), do: Ctx.complete(ctx, status)

  @spec failing_ctx(atom(), atom()) :: Ctx.t()
  defp failing_ctx(channel, completion) do
    Ctx.new(%{}, %{}, command: :"parity.probe")
    |> report_failure(channel)
    |> finish(completion)
  end

  @spec render_ctx_as(Ctx.t(), atom()) :: String.t()
  defp render_ctx_as(ctx, style) do
    ctx
    |> then(&%{&1 | meta: Map.put(&1.meta, :style, style)})
    |> Output.render()
    |> String.replace(~r/\e\[[0-9;]*m/, "")
  end

  # The biconditional below compares rendered output against Ctx.outcome/1. That
  # proves the renderers AGREE with the authority that sets the exit status; it
  # cannot prove the authority is itself right, since both sides would move
  # together. This table is the anchor: expected outcomes as literals, so a change
  # to Ctx.outcome/1 has to be argued for here rather than silently ratified.
  #
  # The last row is the one worth reading twice: an `{:error, _}` output item with
  # no complete/2 is :ok, because an error-STYLED line is a display element and
  # says nothing about whether the command failed. `add_error/2` with no complete
  # is :error, because recording a reason for failure does.
  @outcome_table [
    {:add_error, :error, :error},
    {:add_error, :ok, :ok},
    {:add_error, :warning, :warning},
    {:add_error, :none, :error},
    {:error_output_item, :error, :error},
    {:error_output_item, :ok, :ok},
    {:error_output_item, :warning, :warning},
    {:error_output_item, :none, :ok}
  ]

  for {channel, completion, expected} <- @outcome_table do
    test "invariant: Ctx.outcome is #{expected} for #{channel} + #{completion}" do
      ctx = failing_ctx(unquote(channel), unquote(completion))

      assert Ctx.outcome(ctx) == unquote(expected),
             "the exit-status authority changed for #{unquote(channel)} + #{unquote(completion)}"
    end
  end

  for style <- @text_styles,
      {channel_label, channel} <- @failure_channels,
      {completion_label, completion} <- @completions do
    test "invariant: ^error: iff failed -- #{channel_label} + #{completion_label} + #{style}" do
      ctx = failing_ctx(unquote(channel), unquote(completion))
      output = render_ctx_as(ctx, unquote(style))
      greppable? = output =~ ~r/^error: parity\.probe: /m

      assert greppable? == Ctx.failed?(ctx),
             "#{unquote(channel_label)} + #{unquote(completion_label)} under #{unquote(style)}: " <>
               "outcome is #{Ctx.outcome(ctx)} but `^error:` present = #{greppable?}. " <>
               "The grep and the exit status must never disagree."

      assert output =~ "marker-failure",
             "the recorded failure text was swallowed under #{unquote(style)}: " <>
               "gating the dialect line must never gate the ✗ marker"
    end
  end

  describe "the JSON status is the same authority as the exit status" do
    for {channel_label, channel} <- @failure_channels,
        {completion_label, completion} <- @completions do
      test "invariant: JSON status is the outcome -- #{channel_label} + #{completion_label}" do
        ctx = failing_ctx(unquote(channel), unquote(completion))
        decoded = ctx |> render_ctx_as(:json) |> Jason.decode!()

        assert decoded["status"] == to_string(Ctx.outcome(ctx)),
               "JSON reported #{inspect(decoded["status"])} for a context whose outcome is " <>
                 "#{Ctx.outcome(ctx)}. A never-completed failing context used to drop the key " <>
                 "entirely, so a machine consumer saw no status at all (A28)."
      end
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
