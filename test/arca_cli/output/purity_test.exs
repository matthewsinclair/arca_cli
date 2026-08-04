defmodule Arca.Cli.Output.PurityTest do
  @moduledoc """
  Covers renderer purity (finding A6).

  A `{:spinner, label, fun}` item used to have its `fun` executed by the ANSI
  renderer and ignored by every other one. That made a command's behaviour depend
  on where its output was going: the work happened on a terminal and was silently
  skipped in a pipe, in JSON, and in every test.

  The work now runs once when the item is added to the context, so all styles
  observe identical side effects and renderers only draw.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Ctx
  alias Arca.Cli.Output

  # Build a context whose spinner records each execution, so the count is observable.
  @spec ctx_with_counting_spinner(pid()) :: Ctx.t()
  defp ctx_with_counting_spinner(collector) do
    Ctx.new(%{}, %{}, command: :purity_probe)
    |> Ctx.add_output({:spinner, "working", fn -> send(collector, :ran) && {:ok, "done"} end})
  end

  @spec run_count() :: non_neg_integer()
  defp run_count do
    receive do
      :ran -> 1 + run_count()
    after
      0 -> 0
    end
  end

  describe "deferred work runs exactly once per command run" do
    for style <- [:ansi, :plain, :json] do
      test "invariant: the spinner function runs exactly once under #{style}" do
        ctx = ctx_with_counting_spinner(self())
        Output.render(%{ctx | meta: Map.put(ctx.meta, :style, unquote(style))})

        assert run_count() == 1
      end
    end

    test "invariant: rendering the same context twice does not re-run the work" do
      ctx = ctx_with_counting_spinner(self())

      Output.render(%{ctx | meta: Map.put(ctx.meta, :style, :plain)})
      Output.render(%{ctx | meta: Map.put(ctx.meta, :style, :ansi)})

      assert run_count() == 1
    end
  end

  describe "every style reports the result" do
    for style <- [:ansi, :plain] do
      test "success: the spinner result appears in #{style} output" do
        ctx =
          Ctx.new(%{}, %{}, command: :purity_probe)
          |> Ctx.add_output({:spinner, "working", fn -> {:ok, "42 rows"} end})

        output = Output.render(%{ctx | meta: Map.put(ctx.meta, :style, unquote(style))})

        assert output =~ "42 rows"
      end
    end

    test "success: the spinner result appears in json output" do
      ctx =
        Ctx.new(%{}, %{}, command: :purity_probe)
        |> Ctx.add_output({:spinner, "working", fn -> {:ok, "42 rows"} end})

      output = Output.render(%{ctx | meta: Map.put(ctx.meta, :style, :json)})

      assert output =~ "42 rows"
    end
  end

  describe "contexts built by hand are resolved too" do
    test "invariant: a struct-literal context never hands a function to a renderer" do
      ctx = %Ctx{output: [{:spinner, "working", fn -> {:ok, "resolved"} end}], meta: %{style: :plain}}

      output = Output.render(ctx)

      assert output =~ "resolved"
      refute output =~ "#Function<"
    end
  end
end
