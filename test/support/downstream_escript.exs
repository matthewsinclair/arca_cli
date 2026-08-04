# Models a downstream project's escript entry point: a main_module that does
# nothing but delegate to Arca.Cli.main/1. Run as a script (`mix run <this>
# <args>`) so the delegation happens in a real OS process with a real exit
# status, which is what a downstream escript actually gets.
#
# Used by test/arca_cli/eg/eg_exit_code_test.exs. A .exs under test/support is
# not auto-compiled (elixirc_paths only picks up .ex), so it stays a script.

defmodule Arca.Cli.Test.DownstreamEscript do
  @moduledoc """
  The canonical downstream wrapper: `escript: [main_module: __MODULE__]` plus
  a one-line delegation, and nothing else.
  """

  def main(argv) do
    Arca.Cli.main(argv)
  end
end

Arca.Cli.Test.DownstreamEscript.main(System.argv())
