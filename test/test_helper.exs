# Support functions for CLI test cases
defmodule Arca.Cli.Test.Support do
  # Example config file
  @example_config_json_as_map %{
    "id" => "DOT_SLASH_DOT_LL_SLASH_CONFIG_DOT_JSON"
  }

  # Write a known config file to a known location
  def write_default_config_file(config_file, config_path) do
    config_file
    |> Path.expand(config_path)
    |> File.write(Jason.encode!(@example_config_json_as_map, pretty: true))
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Point Arca.Config at a private directory for the duration of the run.

  Seeded with the settings the suite expects to find already present, so that
  reads of a known-good setting have something to read. Removed after the suite.
  """
  def isolate_config! do
    config_path =
      Path.join(System.tmp_dir!(), "arca_cli_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(config_path)

    File.write!(
      Path.join(config_path, "config.json"),
      Jason.encode!(@example_config_json_as_map, pretty: true)
    )

    {:ok, _previous} =
      Arca.Config.switch_config_location(path: config_path, file: "config.json")

    ExUnit.after_suite(fn _results -> File.rm_rf!(config_path) end)

    {:ok, config_path}
  end

  @doc """
  Ensures that the History GenServer is properly started for tests.
  This function can be called to guarantee History is available.
  """
  def ensure_history_started do
    if Process.whereis(Arca.Cli.History) == nil do
      # Logger.debug("Starting Arca.Cli.History for tests")
      case Arca.Cli.History.start_link() do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        error -> error
      end
    else
      {:ok, Process.whereis(Arca.Cli.History)}
    end
  end

  @doc """
  Restore an application env key to a prior value, deleting it when the prior value was nil.
  """
  def restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  def restore_app_env(app, key, value), do: Application.put_env(app, key, value)

  @doc """
  Restore a system env var to a prior value, deleting it when the prior value was nil.
  """
  def restore_env(var, nil), do: System.delete_env(var)
  def restore_env(var, value), do: System.put_env(var, value)

  @doc """
  Restore an Arca setting to a prior value, removing it when it had none.
  """
  # A setting that was absent must be removed again, not left at whatever a test
  # wrote. Returning :ok without removing it leaked state between test modules,
  # which stayed invisible only for as long as nothing read the setting back.
  #
  # `delete/1` lives on the server rather than the `Arca.Config` facade, which is
  # why this reaches one level further down than the read and write paths do.
  def restore_setting(key, nil) do
    Arca.Config.Server.delete(key)
    :ok
  end

  def restore_setting(key, value), do: Arca.Cli.save_settings(%{key => value})

  @doc """
  Fetch an Arca setting's value, returning `default` when it is unset or unavailable.
  """
  def setting_value(key, default \\ nil) do
    case Arca.Cli.get_setting(key) do
      {:ok, value} -> value
      _ -> default
    end
  end
end

# Ensure history is available for all tests
Arca.Cli.Test.Support.ensure_history_started()

# Point Arca.Config at a throwaway directory for the whole run.
#
# The suite reads and writes settings through the real configuration path, and
# this repo's own config file is git-tracked -- without this, a test that saves a
# setting dirties the working tree.
#
# There was already code that looked like it did this job. It did not: it set
# `ARCA_CONFIG_PATH`, but `Arca.Config.Cfg.config_pathname/0` resolves the
# app-specific `ARCA_CLI_CONFIG_PATH` first, and `config/.env` sets that. The
# generic variable never won, so the isolation was inert.
#
# `switch_config_location/1` is the mechanism rather than a bare `System.put_env`
# because the config server has already booted and cached its location by the
# time this file runs. It re-points the running server AND sets the app-specific
# environment variables, so subprocesses spawned by tests inherit the same
# location instead of reaching for the repo's config.
Arca.Cli.Test.Support.isolate_config!()

# Logger writes to stderr, which ExUnit's stdout capture does not intercept, so a
# command that logs before it fails would print its diagnostics through the test
# run. capture_log holds them per test and shows them only when one fails.
ExUnit.start(capture_log: true)
