defmodule Arca.Cli.DeadCodeGateTest do
  @moduledoc """
  Guards AC-07.1 and AC-07.2: the machinery deleted in WP-07 stays deleted.

  Every symbol named here was reachable only from its own tests. That is the
  shape worth guarding against, because it is invisible to a green suite: the
  tests exercised the function directly, so they answered "does this work" while
  the live question was "does anything call it". A deletion like that reverts
  easily and silently -- a merge, a revert, a well-meant restoration -- and
  nothing else in the suite would notice.
  """
  use ExUnit.Case, async: true

  defp lib_sources, do: Path.wildcard("lib/**/*.ex")

  @spec sites(String.t()) :: [String.t()]
  defp sites(needle) do
    for path <- lib_sources(),
        {line, number} <- Enum.with_index(File.read!(path) |> String.split("\n"), 1),
        String.contains?(line, needle) do
      "#{path}:#{number}"
    end
  end

  describe "purged symbols (AC-07.1)" do
    # The config-callback subsystem: a closed loop. `load_config_phase/0` called
    # the rest and nothing called it, because mix.exs declares no start_phases.
    test "invariant: the dead config-callback subsystem is gone" do
      assert sites("load_config_phase") == []
      assert sites("register_config_callbacks") == []
      assert sites("handle_config_change") == []
      assert sites("apply_display_settings") == []
    end

    # A module that has never existed in this project, called through a
    # function_exported? guard that made its absence look deliberate.
    test "invariant: the Multiplyer reference is gone" do
      assert sites("Multiplyer") == []
    end

    # Reachable only by exporting REPL_MODE=true before boot, which the `repl`
    # command itself did not do.
    test "invariant: REPL_MODE branching is gone" do
      assert sites("REPL_MODE") == []
      assert sites("is_repl_mode") == []
    end

    test "invariant: the unused error-location macros are gone" do
      assert sites("err_cloc") == []
      assert sites("err_cfloc") == []
      assert sites("create_error_with_location") == []
    end

    test "invariant: OK.Pipe is not imported by anything" do
      assert sites("OK.Pipe") == []
    end

    test "invariant: the unregistered duplicate commands are gone" do
      assert Path.wildcard(
               "lib/arca_cli/commands/{flush,get,history,redo,status,settings,sub}_command.ex"
             ) ==
               []
    end

    # `decode_json` built atoms from arbitrary JSON keys, which is the C11
    # exhaustion vector by another route, and `form_encoded_body` joined pairs
    # with "=" and "&" without encoding either side.
    test "invariant: the HTTP residue in Utils is gone" do
      assert sites("form_encoded_body") == []
      assert sites("parse_json_body") == []
      assert sites("decode_json") == []
    end
  end

  describe "dependency prune (AC-07.2)" do
    @pruned ~w[castore certifi elixir_uuid pathex table_rex ucwidth ok
               dotenv logger_file_backend logger_backends]

    # Declared directly and used by nothing here.
    test "invariant: pruned dependencies are not declared in mix.exs" do
      declared =
        File.read!("mix.exs")
        |> String.split("\n")
        |> Enum.filter(&String.match?(&1, ~r/^\s*\{:[a-z_]+,/))
        |> Enum.map(&Regex.run(~r/\{:([a-z_]+),/, &1, capture: :all_but_first))
        |> List.flatten()

      assert Enum.filter(@pruned, &(&1 in declared)) == []
    end

    # Only three of the ten can leave the lock. The other seven are dependencies
    # of arca_config, so they stay resolved transitively no matter what this
    # project declares -- removing them here makes them arca_config's business,
    # which is the most this repository can do about them.
    test "invariant: dependencies with no other dependant left the lock" do
      lock = File.read!("mix.lock")

      for dep <- ~w[dotenv logger_file_backend logger_backends] do
        refute lock =~ ~s|"#{dep}":|, "#{dep} is still locked"
      end
    end
  end

  describe "the gate itself" do
    test "invariant: the scanner finds strings that are genuinely present" do
      found = sites("defmodule")

      assert length(found) > 40
      assert Enum.any?(found, &String.starts_with?(&1, "lib/arca_cli.ex:"))
    end
  end
end
