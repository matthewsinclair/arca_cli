defmodule Arca.Cli.Testing.CliFixturesScriptsTest do
  use ExUnit.Case, async: true

  import Arca.Cli.Testing.CliFixturesTest
  import ExUnit.CaptureIO

  # Helper to create temporary fixture directories
  setup do
    tmp_dir = System.tmp_dir!()
    fixture_path = Path.join(tmp_dir, "test_fixture_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(fixture_path)

    on_exit(fn -> File.rm_rf!(fixture_path) end)

    %{fixture_path: fixture_path}
  end

  describe "run_setup_script/1 - success cases" do
    test "returns empty map when no setup.exs exists", %{fixture_path: path} do
      assert {:ok, %{}} = run_setup_script(path)
    end

    test "evaluates setup.exs and returns map", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "%{user_id: 42, name: \"test\"}")

      {:ok, bindings} = run_setup_script(path)
      assert bindings == %{user_id: 42, name: "test"}
    end

    test "returns map with various types", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")

      File.write!(setup_exs, """
      %{
        integer: 123,
        string: "hello",
        atom: :test_atom,
        boolean: true,
        float: 99.99,
        list: [1, 2, 3]
      }
      """)

      {:ok, bindings} = run_setup_script(path)

      assert bindings.integer == 123
      assert bindings.string == "hello"
      assert bindings.atom == :test_atom
      assert bindings.boolean == true
      assert bindings.float == 99.99
      assert bindings.list == [1, 2, 3]
    end

    test "can execute Elixir code and return computed values", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")

      File.write!(setup_exs, """
      user_id = 10 + 32
      api_key = "laksa_" <> "abc123"
      count = length([1, 2, 3])

      %{
        user_id: user_id,
        api_key: api_key,
        count: count
      }
      """)

      {:ok, bindings} = run_setup_script(path)

      assert bindings.user_id == 42
      assert bindings.api_key == "laksa_abc123"
      assert bindings.count == 3
    end

    test "can use Enum and other standard modules", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")

      File.write!(setup_exs, """
      numbers = Enum.map([1, 2, 3], & &1 * 2)
      sum = Enum.sum(numbers)

      %{numbers: numbers, sum: sum}
      """)

      {:ok, bindings} = run_setup_script(path)

      assert bindings.numbers == [2, 4, 6]
      assert bindings.sum == 12
    end
  end

  describe "run_setup_script/1 - error cases" do
    test "raises when setup.exs returns non-map (string)", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "\"not a map\"")

      assert_raise RuntimeError, ~r/setup.exs must return a map/, fn ->
        run_setup_script(path)
      end
    end

    test "raises when setup.exs returns non-map (tuple)", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "{:ok, %{user_id: 42}}")

      assert_raise RuntimeError, ~r/setup.exs must return a map/, fn ->
        run_setup_script(path)
      end
    end

    test "raises when setup.exs returns non-map (list)", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "[1, 2, 3]")

      assert_raise RuntimeError, ~r/setup.exs must return a map/, fn ->
        run_setup_script(path)
      end
    end

    test "raises when setup.exs has syntax error", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "%{user_id: 42")

      # TokenMissingError is a subtype of SyntaxError
      assert_raise TokenMissingError, fn ->
        run_setup_script(path)
      end
    end

    test "raises when setup.exs has runtime error", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "raise \"intentional error\"")

      assert_raise RuntimeError, "intentional error", fn ->
        run_setup_script(path)
      end
    end

    test "raises when setup.exs references undefined variable", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "%{value: undefined_variable}")

      # Capture stderr to avoid noisy test output
      capture_io(:stderr, fn ->
        assert_raise CompileError, fn ->
          run_setup_script(path)
        end
      end)
    end
  end

  describe "run_setup_script/1 - error messages" do
    test "shows helpful message for non-map return", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "42")

      error =
        try do
          run_setup_script(path)
        rescue
          e -> Exception.message(e)
        end

      assert error =~ "setup.exs must return a map"
      assert error =~ "got: 42"
      assert error =~ "Example:"
      assert error =~ "%{user_id: 123"
    end

    test "includes file path in error for syntax errors", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      File.write!(setup_exs, "%{invalid syntax")

      error =
        try do
          run_setup_script(path)
        rescue
          e -> Exception.message(e)
        end

      assert error =~ "setup.exs"
    end
  end

  describe "run_teardown_script/2 - success cases" do
    test "returns :ok when no teardown.exs exists", %{fixture_path: path} do
      assert :ok = run_teardown_script(path, %{})
    end

    test "evaluates teardown.exs and returns :ok", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      File.write!(teardown_exs, "# Empty teardown")

      assert :ok = run_teardown_script(path, %{})
    end

    test "bindings variable is available in script", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      output_file = Path.join(path, "output.txt")

      File.write!(teardown_exs, """
      user_id = bindings[:user_id]
      name = bindings[:name]
      File.write!("#{output_file}", "\#{user_id},\#{name}")
      """)

      run_teardown_script(path, %{user_id: 42, name: "test"})

      assert File.read!(output_file) == "42,test"
    end

    test "can access and use binding values", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      counter_file = Path.join(path, "counter.txt")

      File.write!(teardown_exs, """
      count = bindings[:count] || 0
      File.write!("#{counter_file}", "\#{count * 2}")
      """)

      run_teardown_script(path, %{count: 21})

      assert File.read!(counter_file) == "42"
    end

    test "handles empty bindings", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")

      File.write!(teardown_exs, """
      # Empty bindings is still a usable map
      Map.get(bindings, :count, 0)
      """)

      assert :ok = run_teardown_script(path, %{})
    end
  end

  describe "run_teardown_script/2 - error handling" do
    test "logs warning but returns :ok on runtime error", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      File.write!(teardown_exs, "raise \"intentional teardown error\"")

      output =
        capture_io(:stderr, fn ->
          result = run_teardown_script(path, %{})
          assert result == :ok
        end)

      assert output =~ "Teardown script failed"
      assert output =~ "intentional teardown error"
      assert output =~ "teardown.exs"
    end

    test "logs warning but returns :ok on syntax error", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      File.write!(teardown_exs, "%{invalid syntax")

      output =
        capture_io(:stderr, fn ->
          result = run_teardown_script(path, %{})
          assert result == :ok
        end)

      assert output =~ "Teardown script failed"
    end

    test "handles KeyError gracefully when accessing missing binding", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      # This will raise KeyError if using bindings.user_id instead of bindings[:user_id]
      File.write!(teardown_exs, "Map.fetch!(bindings, :missing_key)")

      output =
        capture_io(:stderr, fn ->
          result = run_teardown_script(path, %{})
          assert result == :ok
        end)

      assert output =~ "Teardown script failed"
    end

    test "continues even if file operations fail", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      File.write!(teardown_exs, "File.rm!(\"/nonexistent/path/file.txt\")")

      output =
        capture_io(:stderr, fn ->
          result = run_teardown_script(path, %{})
          assert result == :ok
        end)

      assert output =~ "Teardown script failed"
    end
  end

  describe "run_teardown_script/2 - defensive patterns" do
    test "recommended pattern: check binding exists before using", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      output_file = Path.join(path, "result.txt")

      File.write!(teardown_exs, """
      user_id = bindings[:user_id]
      message = (user_id && "cleaned: \#{user_id}") || "nothing to clean"
      File.write!("#{output_file}", message)
      """)

      # With binding
      run_teardown_script(path, %{user_id: 42})
      assert File.read!(output_file) == "cleaned: 42"

      # Without binding
      run_teardown_script(path, %{})
      assert File.read!(output_file) == "nothing to clean"
    end

    test "pattern with Map.get for default values", %{fixture_path: path} do
      teardown_exs = Path.join(path, "teardown.exs")
      output_file = Path.join(path, "result.txt")

      File.write!(teardown_exs, """
      count = Map.get(bindings, :count, 0)
      File.write!("#{output_file}", "\#{count}")
      """)

      # With binding
      run_teardown_script(path, %{count: 5})
      assert File.read!(output_file) == "5"

      # Without binding (uses default)
      run_teardown_script(path, %{})
      assert File.read!(output_file) == "0"
    end
  end

  describe "integration: setup and teardown together" do
    test "teardown receives bindings from setup", %{fixture_path: path} do
      setup_exs = Path.join(path, "setup.exs")
      teardown_exs = Path.join(path, "teardown.exs")
      marker_file = Path.join(path, "marker.txt")

      # Setup creates a marker
      File.write!(setup_exs, """
      File.write!("#{marker_file}", "created by setup")
      %{marker_file: "#{marker_file}"}
      """)

      # Teardown removes it
      File.write!(teardown_exs, """
      file = bindings[:marker_file]
      file && File.exists?(file) && File.rm!(file)
      """)

      # Run setup
      {:ok, bindings} = run_setup_script(path)
      assert bindings.marker_file == marker_file
      assert File.exists?(marker_file)

      # Run teardown with bindings from setup
      :ok = run_teardown_script(path, bindings)
      refute File.exists?(marker_file)
    end
  end
end
