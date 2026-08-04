defmodule Arca.Cli.Repl.ShouldPushTest do
  @moduledoc """
  Which commands get recorded in REPL history.

  The exclusion list (`history`, `redo`, `flush`, `help`) was matched with `=~`,
  so any command merely *containing* one of those words was silently dropped.
  `settings.get help_url` was never recorded, and neither was anything with
  "history" or "redo" anywhere in its arguments. The match is on the command
  name now, exactly.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Repl

  describe "commands excluded from history" do
    test "invariant: the four history-management commands are excluded" do
      refute Repl.should_push?("history")
      refute Repl.should_push?("redo")
      refute Repl.should_push?("flush")
      refute Repl.should_push?("help")
    end

    test "invariant: exclusion survives surrounding whitespace" do
      refute Repl.should_push?("  history  ")
    end

    test "invariant: an excluded command with arguments is still excluded" do
      refute Repl.should_push?("help settings.all")
      refute Repl.should_push?("redo 3")
    end
  end

  describe "commands recorded in history" do
    test "success: a command whose argument merely contains an excluded word is recorded" do
      assert Repl.should_push?("settings.get help_url")
    end

    test "success: a command whose name merely contains an excluded word is recorded" do
      assert Repl.should_push?("cli.history")
      assert Repl.should_push?("cli.redo 1")
    end

    test "success: an ordinary command is recorded" do
      assert Repl.should_push?("about")
      assert Repl.should_push?("settings.all")
    end
  end

  describe "list form" do
    test "success: argument lists are joined on whitespace, not concatenated" do
      # Joining with "" turned ["settings.get", "help_url"] into
      # "settings.gethelp_url", which then matched the "help" exclusion.
      assert Repl.should_push?(["settings.get", "help_url"])
    end

    test "invariant: an excluded command in list form is still excluded" do
      refute Repl.should_push?(["help", "settings.all"])
    end
  end
end
