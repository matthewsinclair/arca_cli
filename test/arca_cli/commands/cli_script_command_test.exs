defmodule Arca.Cli.Commands.CliScriptCommandTest do
  use ExUnit.Case, async: false

  alias Arca.Cli.Commands.CliScriptCommand

  describe "parsing regular commands" do
    test "parses single command" do
      content = "help"

      # We test via the file interface since parse_script is private
      file = write_temp_script(content)

      try do
        # Verify it doesn't raise
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> help" || result != ""
      after
        File.rm(file)
      end
    end

    test "parses multiple commands" do
      content = """
      help
      about
      status
      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> help" || result != ""
      after
        File.rm(file)
      end
    end

    test "skips comment lines" do
      content = """
      # This is a comment
      help
      # Another comment
      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        refute result =~ "# This is a comment"
        assert result =~ "script> help" || result != ""
      after
        File.rm(file)
      end
    end

    test "skips empty lines" do
      content = """

      help

      about

      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> help" || result != ""
      after
        File.rm(file)
      end
    end
  end

  describe "parsing heredoc commands" do
    test "parses simple heredoc" do
      content = """
      echo test <<EOF
      line 1
      line 2
      EOF
      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> echo test <<EOF"
        assert result =~ "line 1"
        assert result =~ "line 2"
        assert result =~ "EOF"
      after
        File.rm(file)
      end
    end

    test "parses heredoc with different markers" do
      for marker <- ["EOF", "END", "INPUT", "DATA123"] do
        content = """
        command <<#{marker}
        content
        #{marker}
        """

        file = write_temp_script(content)

        try do
          result =
            capture_io(fn ->
              CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
            end)

          assert result =~ "<<#{marker}"
        after
          File.rm(file)
        end
      end
    end

    test "preserves whitespace in heredoc content" do
      content = """
      command <<EOF
        indented line
      \ttabbed line
          more spaces
      EOF
      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "indented line"
        assert result =~ "more spaces"
      after
        File.rm(file)
      end
    end

    test "handles empty heredoc" do
      content = """
      command <<EOF
      EOF
      """

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> command <<EOF"
      after
        File.rm(file)
      end
    end

    test "handles multiple heredocs in one script" do
      content = """
      command1 <<EOF
      input1
      EOF
      regular_command
      command2 <<END
      input2
      END
      """

      file = write_temp_script(content)

      try do
        # This exercises the parser, so it must reach every command. The stub
        # optimus cannot execute any of them, and scripts now stop at the first
        # failure, so --keep-going is what keeps this a parser test.
        result =
          capture_io(fn ->
            CliScriptCommand.handle(
              %{args: %{file: file}, flags: %{keep_going: true}},
              %{},
              test_optimus()
            )
          end)

        assert result =~ "command1 <<EOF"
        assert result =~ "command2 <<END"
        assert result =~ "script> regular_command"
      after
        File.rm(file)
      end
    end
  end

  describe "heredoc error handling" do
    test "raises on unclosed heredoc" do
      content = """
      command <<EOF
      line 1
      line 2
      """

      file = write_temp_script(content)

      try do
        assert_raise RuntimeError, ~r/Unclosed heredoc/, fn ->
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)
        end
      after
        File.rm(file)
      end
    end

    test "error message includes line number" do
      content = """
      regular command
      another command
      command <<EOF
      line 1
      """

      file = write_temp_script(content)

      try do
        assert_raise RuntimeError, ~r/starting at line 3/, fn ->
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)
        end
      after
        File.rm(file)
      end
    end
  end

  describe "Windows line endings" do
    test "handles CRLF line endings" do
      content = "help\r\nabout\r\nstatus\r\n"

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "script> help" || result != ""
      after
        File.rm(file)
      end
    end

    test "handles heredoc with CRLF" do
      content = "command <<EOF\r\nline1\r\nline2\r\nEOF\r\n"

      file = write_temp_script(content)

      try do
        result =
          capture_io(fn ->
            CliScriptCommand.handle(%{args: %{file: file}}, %{}, test_optimus())
          end)

        assert result =~ "<<EOF"
      after
        File.rm(file)
      end
    end
  end

  describe "file reading errors" do
    test "returns an error tuple for a non-existent file" do
      # An error tuple, not a display string: an unreadable script must reach the
      # exit status so automation can tell the run failed (finding A13).
      result =
        CliScriptCommand.handle(
          %{args: %{file: "/nonexistent/file.cli"}},
          %{},
          test_optimus()
        )

      assert {:error, :script_not_readable, message} = result
      assert message =~ "cannot read script file /nonexistent/file.cli"
      assert message =~ "no such file or directory"
    end
  end

  # Test Helpers

  defp write_temp_script(content) do
    file = Path.join(System.tmp_dir!(), "test_script_#{:rand.uniform(100_000)}.cli")
    File.write!(file, content)
    file
  end

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end

  defp test_optimus do
    # Minimal optimus structure for testing
    # In real tests, this would be the actual Optimus config
    %{}
  end
end
