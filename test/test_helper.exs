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
  Restore an Arca setting to a prior value; a nil prior value is a no-op.
  """
  # A setting that was absent must be removed again, not left at whatever a test
  # wrote. Returning :ok without removing it leaked state between test modules,
  # which stayed invisible only for as long as nothing read the setting back.
  def restore_setting(key, nil) do
    current = Application.get_env(:arca_cli, :test_settings, %{})
    Application.put_env(:arca_cli, :test_settings, Map.delete(current, key))
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

# Logger writes to stderr, which ExUnit's stdout capture does not intercept, so a
# command that logs before it fails would print its diagnostics through the test
# run. capture_log holds them per test and shows them only when one fails.
ExUnit.start(capture_log: true)
