defmodule Arca.Cli.ConfigContractTest do
  @moduledoc """
  The arca_config surface this CLI depends on, stated once and checked.

  arca_cli tracks arca_config by git branch, so a change over there arrives here
  on a `mix deps.update` with no compiler error to warn anyone: every call below
  is resolved at runtime. The consequence is that a retired or renamed function
  becomes a crash in someone's terminal rather than a red build.

  This turns that into a test failure at the dep bump. It asserts existence and
  arity only -- behaviour is the bump's own verification job, and asserting
  behaviour here would just re-test arca_config.

  ## Why some of these reach past the facade

  `Arca.Config` is the public module and everything should go through it. Two
  calls cannot, and are listed separately so the exception stays visible rather
  than becoming precedent:

  - `Server.start_link/1` has no facade equivalent in either version.
  - `Server.delete/1` gained a facade `Arca.Config.delete/1` only in the
    unreleased arca_config, so the switch happens at the bump, not before it.

  vc's cross-repo read found that arca_config's own consumer-contract test pins
  its facade `delete/1` and does not pin either of these, so nothing on that side
  would notice their removal. That is exactly the gap this file covers.
  """
  use ExUnit.Case, async: true

  # Called from lib/. Each entry is a real call site, not a wish list.
  @facade [
    {:get, 1},
    {:put, 2},
    {:reload, 0},
    {:switch_config_location, 1}
  ]

  # Reaching past the facade. Keep this list short and justified; every addition
  # is new coupling to another repository's internals.
  @server_internals [
    {:start_link, 1},
    {:delete, 1}
  ]

  # `Arca.Cli.config_available?/0` probes for this by `function_exported?/3` as
  # its "is arca_config alive" check. NOTHING in this repository calls it -- WP-07
  # deleted the callback subsystem -- so a call-graph search from the arca_config
  # side will not find this consumer, and retiring it there silently flips
  # `config_available?` to false and degrades every `save_settings` here.
  #
  # A probe with no caller is invisible to everyone. This is the one place that
  # says out loud that it must keep existing.
  @liveness_probe {:register_change_callback, 2}

  setup_all do
    Code.ensure_loaded!(Arca.Config)
    Code.ensure_loaded!(Arca.Config.Server)
    :ok
  end

  describe "the facade surface arca_cli calls" do
    for {fun, arity} <- @facade do
      test "invariant: Arca.Config.#{fun}/#{arity} exists" do
        assert function_exported?(Arca.Config, unquote(fun), unquote(arity)),
               "arca_config no longer exports Arca.Config.#{unquote(fun)}/#{unquote(arity)}, " <>
                 "which this CLI calls. The dep bump broke a call site."
      end
    end
  end

  describe "the Server internals arca_cli reaches for" do
    for {fun, arity} <- @server_internals do
      test "invariant: Arca.Config.Server.#{fun}/#{arity} exists" do
        assert function_exported?(Arca.Config.Server, unquote(fun), unquote(arity)),
               "arca_config no longer exports Arca.Config.Server.#{unquote(fun)}/" <>
                 "#{unquote(arity)}. This is internals-level coupling and arca_config's own " <>
                 "contract test does not pin it, so nothing on that side would have caught this."
      end
    end
  end

  describe "the liveness probe" do
    test "invariant: the function config_available?/0 probes for still exists" do
      {fun, arity} = @liveness_probe

      assert function_exported?(Arca.Config, fun, arity),
             "Arca.Config.#{fun}/#{arity} is gone. Nothing here CALLS it -- it is the " <>
               "target of a function_exported?/3 liveness probe in Arca.Cli.config_available?/0 " <>
               "-- so its removal does not break a call site. It silently makes " <>
               "config_available?/0 return false and degrades every save_settings."
    end

    # Without this, the test above would pass for the wrong reason if the probe
    # were changed to name some other function: the assertion would still be
    # true of arca_config while no longer describing what this CLI actually does.
    test "invariant: config_available?/0 still probes the function pinned here" do
      {fun, _arity} = @liveness_probe
      source = File.read!("lib/arca_cli.ex")

      assert source =~ "function_exported?(Arca.Config, :#{fun},",
             "Arca.Cli.config_available?/0 no longer probes #{fun}, so the pin above is " <>
               "describing a contract this CLI has stopped relying on. Update @liveness_probe."
    end
  end
end
