defmodule Arca.Cli.AtomSafetyTest do
  @moduledoc """
  Covers atoms created from user-supplied strings (finding C11).

  Four sites called `String.to_atom/1` on text the user typed: the two help
  entry points, the help name converter, and the style read out of settings.
  Atoms are never garbage collected and the VM dies when the table fills, so any
  path from user input to `String.to_atom/1` is a denial-of-service waiting for a
  long-lived REPL session or a script that loops over generated names.

  The tests assert the precise thing rather than a statistic: after asking for the
  name, `String.to_existing_atom/1` must still raise for it. A count-based check
  backs that up, because a leak elsewhere in the same call would show as growth
  even while each named probe looked clean.
  """
  use ExUnit.Case, async: false

  alias Arca.Cli.Ctx
  alias Arca.Cli.Help

  # Distinct on every run so a previous run cannot make a leaked atom look absent.
  defp unique_name(prefix) do
    "#{prefix}_#{System.unique_integer([:positive])}"
  end

  defp atom_created?(name) do
    _ = String.to_existing_atom(name)
    true
  rescue
    ArgumentError -> false
  end

  describe "help entry points do not mint atoms" do
    test "failure: asking for help on an unknown command creates no atom for it" do
      name = unique_name("nosuchcmd")

      {outcome, _output} = Arca.Cli.dispatch_command_help(name, nil)

      assert outcome == :error
      refute atom_created?(name)
    end

    test "failure: should_show_help? on an unknown command creates no atom for it" do
      name = unique_name("nosuchcmd")

      refute Help.should_show_help?(name, %{})
      refute atom_created?(name)
    end

    test "failure: to_command_atom rejects an unknown name without minting it" do
      name = unique_name("nosuchcmd")

      assert Help.to_command_atom(name) == {:error, :unknown_command}
      refute atom_created?(name)
    end

    test "success: to_command_atom resolves a registered command to its atom" do
      assert Help.to_command_atom("about") == {:ok, :about}
      assert Help.to_command_atom("sys.info") == {:ok, :"sys.info"}
      assert Help.to_command_atom(:about) == {:ok, :about}
    end
  end

  describe "settings do not mint atoms" do
    test "failure: an unrecognised style in settings creates no atom for it" do
      name = unique_name("bogusstyle")

      ctx = Ctx.new(%{}, %{"style" => name})

      assert ctx.meta == %{}
      refute atom_created?(name)
    end

    test "success: a recognised style still resolves" do
      ctx = Ctx.new(%{}, %{"style" => "json"})

      assert ctx.meta.style == :json
    end
  end

  describe "the atom table stays flat under a stream of unknown commands" do
    test "invariant: 200 distinct unknown commands add no atoms for their names" do
      names = Enum.map(1..200, fn n -> unique_name("phantom#{n}") end)

      before_count = :erlang.system_info(:atom_count)

      Enum.each(names, fn name ->
        Arca.Cli.dispatch_command_help(name, nil)
        Help.should_show_help?(name, %{})
        Ctx.new(%{}, %{"style" => name})
      end)

      growth = :erlang.system_info(:atom_count) - before_count

      assert Enum.all?(names, &(not atom_created?(&1)))

      # Each name touched three former `String.to_atom/1` sites, so the leak this
      # test exists to catch would show as growth of at least 200.
      assert growth < 50,
             "atom table grew by #{growth} across 200 unknown command names"
    end
  end
end
