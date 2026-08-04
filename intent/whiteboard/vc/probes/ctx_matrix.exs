# ctx_matrix.exs -- the channel x completion x style matrix, driven not read.
#
# Run: MIX_ENV=test mix run --no-start intent/whiteboard/vc/probes/ctx_matrix.exs
#
# WHY: this dialect's completeness claim has been wrong three times (A25, A27,
# A28), and every time the untested COMBINATION was the broken one. WP-12 made
# Ctx.outcome/1 the single authority; this table is the external check that the
# authority still holds after arca_config's R1 error-shape change lands on
# arca_cli.ex:1083-1098, which sits upstream of the dialect.
#
# The invariant is a BICONDITIONAL, not presence: an `^error:` line appears if
# and only if Ctx.outcome/1 says the command failed. Asserting mere presence is
# what let A28 through -- the broken row printed its line and passed.

alias Arca.Cli.Ctx
alias Arca.Cli.Output

strip = fn s -> String.replace(s, ~r/\e\[[0-9;]*m/, "") end

render = fn ctx, style ->
  %{ctx | meta: Map.put(ctx.meta, :style, style)} |> Output.render() |> strip.()
end

count = fn out, prefix ->
  out |> String.split("\n") |> Enum.count(&String.starts_with?(&1, prefix))
end

channel = fn
  ctx, :add_error -> Ctx.add_error(ctx, "marker")
  ctx, :error_item -> Ctx.add_output(ctx, {:error, "marker"})
end

finish = fn
  ctx, :none -> ctx
  ctx, status -> Ctx.complete(ctx, status)
end

json_status = fn json ->
  case Regex.run(~r/"status":\s*"([a-z]+)"/, json) do
    [_, s] -> s
    _ -> "ABSENT"
  end
end

IO.puts("# ctx matrix -- channel x completion x style")
IO.puts("")

IO.puts("channel     | completion | outcome | plain | ansi  | cross | json status | biconditional")
IO.puts("------------|------------|---------|-------|-------|-------|-------------|--------------")

violations =
  for ch <- [:add_error, :error_item], fin <- [:error, :ok, :warning, :none], reduce: [] do
    acc ->
      ctx = Ctx.new(%{}, %{}, command: :"probe.cmd") |> channel.(ch) |> finish.(fin)
      outcome = Ctx.outcome(ctx)
      plain = render.(ctx, :plain)
      ansi = render.(ctx, :ansi)
      p = count.(plain, "error:")
      a = count.(ansi, "error:")
      x = count.(plain, "✗")
      js = json_status.(render.(ctx, :json))
      failed? = outcome == :error

      # The biconditional: a dialect line appears iff the context failed, in
      # BOTH text styles, and the two styles agree with each other.
      bicond = (p > 0) == failed? and (a > 0) == failed? and p == a

      # The safety property WP-12 added: the cross marker is NEVER gated, so
      # gating the dialect line can never swallow a recorded error.
      cross_ok = x > 0

      # JSON must always carry a status. It reported ABSENT before WP-12 for
      # never-completed contexts, because nil fields are dropped from the doc.
      json_ok = js != "ABSENT"

      status = if bicond and cross_ok and json_ok, do: "OK", else: "*** VIOLATION ***"

      IO.puts(
        "#{String.pad_trailing(to_string(ch), 11)} | " <>
          "#{String.pad_trailing(to_string(fin), 10)} | " <>
          "#{String.pad_trailing(to_string(outcome), 7)} | " <>
          "  #{p}    |   #{a}   |   #{x}   | " <>
          "#{String.pad_trailing(js, 11)} | #{status}"
      )

      if status == "OK", do: acc, else: [{ch, fin} | acc]
  end

IO.puts("")
IO.puts("## both channels together (documented bound: at least one, not exactly one)")

both =
  Ctx.new(%{}, %{}, command: :"probe.cmd")
  |> Ctx.add_error("marker")
  |> Ctx.add_output({:error, "marker"})
  |> Ctx.complete(:error)

IO.puts("  ^error: lines = #{count.(render.(both, :plain), "error:")} (expected >= 1)")
IO.puts("  outcome       = #{Ctx.outcome(both)}")

IO.puts("")

case violations do
  [] ->
    IO.puts("RESULT: PASS -- biconditional holds, cross never gated, json always carries a status")

  vs ->
    IO.puts("RESULT: *** FAIL *** -- #{length(vs)} violating cell(s): #{inspect(vs)}")
    System.at_exit(fn _ -> exit({:shutdown, 1}) end)
end
