defmodule Arca.Cli.NoTestEnvGateTest do
  @moduledoc """
  Guards AC-09.1 and AC-09.3: production code must not know it is being tested.

  Every environment branch that was removed had gone wrong in the same way. The
  suite exercised one path and users got another, so a defect on the user's path
  could not be caught by any test, and a branch could stop firing altogether
  without anything going red. `history_maybe_child_spec` had a test-only branch
  that never once executed; `Output.test_env?` consulted a variable `mix test`
  does not set; `settings.all` answered a fabricated table under test, so its own
  test could not distinguish reading the configuration from not reading it.

  This is a grep expressed as a test because the property is textual: it is about
  what the source is allowed to mention, and no runtime assertion can state it.
  """
  use ExUnit.Case, async: true

  # Scan the compiled library only. This file necessarily contains the very
  # strings it forbids, and test support code is allowed to know it is a test.
  defp lib_sources, do: Path.wildcard("lib/**/*.ex")

  @spec sites(String.t()) :: [String.t()]
  defp sites(needle) do
    for path <- lib_sources(),
        {line, number} <- Enum.with_index(File.read!(path) |> String.split("\n"), 1),
        String.contains?(line, needle) do
      "#{path}:#{number}"
    end
  end

  describe "environment branching" do
    test "invariant: lib branches on capability, never on the Mix environment" do
      assert sites("Mix.env()") == []
    end

    test "invariant: settings come from configuration, not from application env" do
      assert sites(":test_settings") == []
    end

    test "invariant: style is not chosen by reading MIX_ENV" do
      assert sites(~s|get_env("MIX_ENV")|) == []
    end
  end

  describe "the gate itself" do
    # Without this, a scanner that silently matched nothing -- a wrong root, a
    # changed extension, a wildcard that stopped expanding -- would report every
    # invariant above as satisfied. The gate has to be able to fail.
    test "invariant: the scanner finds strings that are genuinely present" do
      found = sites("defmodule")

      assert length(found) > 40
      assert Enum.any?(found, &String.starts_with?(&1, "lib/arca_cli.ex:"))
    end
  end
end
