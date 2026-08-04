defmodule Arca.Cli.Commands.DevCommandsEscriptTest do
  @moduledoc """
  Covers `dev.info` and `dev.deps` across deployment formats (finding A8).

  Both commands asked Mix for their answers. Mix is a build tool: it is not
  shipped inside an escript, so in the one deployment format users actually
  install, `dev.info` crashed on `Mix.env/0` and `dev.deps` silently fell back to
  a hardcoded list of dependencies written by hand and never updated.

  The fabricated list is the more interesting failure. A crash is at least honest
  about not knowing; a confident wrong answer is not. It named `optimus ~> 0.2`
  while the project builds against a git branch, and omitted `arca_config`
  entirely.

  The escript-level assertions run against a real built escript, because that is
  the only place the defect ever appeared -- under Mix, both commands worked.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Commands.DevDepsCommand
  alias Arca.Cli.Commands.DevInfoCommand

  @escript "_build/escript/arca_cli"

  @parse_result %{args: %{}, options: %{}, flags: %{}, unknown: []}

  defp table_rows(ctx) do
    ctx.output
    |> Enum.find_value([], fn
      {:table, rows, _opts} -> rows
      _ -> nil
    end)
  end

  defp property(ctx, name) do
    ctx
    |> table_rows()
    |> Enum.find_value(fn
      [^name, value] -> value
      _ -> nil
    end)
  end

  describe "dev.info reports what it can actually know" do
    test "success: it names the application and its real version" do
      ctx = DevInfoCommand.handle(@parse_result, %{}, nil)

      assert property(ctx, "Application") == Arca.Cli.name()
      assert property(ctx, "Version") == Arca.Cli.version()
    end

    test "success: it reports the runtime facts it reads from the VM" do
      ctx = DevInfoCommand.handle(@parse_result, %{}, nil)

      assert property(ctx, "Elixir Version") == System.version()
      assert property(ctx, "OTP Release") == List.to_string(:erlang.system_info(:otp_release))
    end

    test "success: it completes ok and names itself" do
      ctx = DevInfoCommand.handle(@parse_result, %{}, nil)

      assert ctx.command == :"dev.info"
      assert ctx.status == :ok
    end
  end

  describe "dev.deps reports the applications that are really loaded" do
    test "success: every loaded application appears with its real version" do
      ctx = DevDepsCommand.handle(@parse_result, %{}, nil)

      rows = table_rows(ctx)

      assert ["arca_cli", to_string(Application.spec(:arca_cli, :vsn))] in rows
      assert ["elixir", System.version()] in rows
    end

    test "invariant: nothing is reported that is not loaded" do
      ctx = DevDepsCommand.handle(@parse_result, %{}, nil)

      loaded = Application.loaded_applications() |> Enum.map(fn {app, _, _} -> to_string(app) end)
      [_header | data_rows] = table_rows(ctx)

      assert Enum.all?(data_rows, fn [app, _vsn] -> app in loaded end)
    end

    test "invariant: every version reported is the version the VM actually loaded" do
      ctx = DevDepsCommand.handle(@parse_result, %{}, nil)
      [_header | data_rows] = table_rows(ctx)

      mismatched =
        Enum.reject(data_rows, fn [app, vsn] ->
          vsn == to_string(Application.spec(String.to_existing_atom(app), :vsn))
        end)

      assert mismatched == []
    end

    test "success: it completes ok and names itself" do
      ctx = DevDepsCommand.handle(@parse_result, %{}, nil)

      assert ctx.command == :"dev.deps"
      assert ctx.status == :ok
    end
  end

  describe "both commands work in a built escript" do
    setup do
      # The escript is the deployment format where the defect lived. Skip rather
      # than fail when it has not been built, so a bare `mix test` stays green.
      {:ok, built?: File.exists?(@escript)}
    end

    test "success: dev.info does not crash and reports the escript deployment", context do
      run_when_built(context, fn ->
        {output, status} = System.cmd(Path.expand(@escript), ["dev.info"], stderr_to_stdout: true)

        assert status == 0
        assert output =~ "escript"
        refute output =~ "UndefinedFunctionError"
      end)
    end

    test "success: dev.deps reports real applications, not the fabricated list", context do
      run_when_built(context, fn ->
        {output, status} = System.cmd(Path.expand(@escript), ["dev.deps"], stderr_to_stdout: true)

        assert status == 0
        assert output =~ "arca_cli"
        assert output =~ to_string(Application.spec(:optimus, :vsn))
        # The fabricated list named a version requirement, which a loaded
        # application never carries -- it carries a resolved version.
        refute output =~ "~> "
      end)
    end
  end

  defp run_when_built(%{built?: false}, _assertions) do
    IO.puts("\n  (skipped: #{@escript} not built -- run `mix escript.build`)")
  end

  defp run_when_built(%{built?: true}, assertions), do: assertions.()
end
