defmodule Arca.Cli.Commands.CfgListCommand do
  @moduledoc """
  Displays all current configuration settings.

  This command provides a formatted view of all application settings,
  showing the complete configuration state using Railway-Oriented Programming patterns.
  """
  require Logger
  use Arca.Cli.Command.BaseCommand

  config :"cfg.list",
    name: "cfg.list",
    about: "List all configuration settings"

  @typedoc """
  Possible error types for configuration operations
  """
  @type error_type ::
          :settings_not_found
          | :empty_settings
          | :formatting_error
          | :load_failed

  @typedoc """
  Result type for configuration operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Create a standardized error tuple for config operations
  """
  @spec create_error(error_type(), String.t()) :: {:error, error_type(), String.t()}
  def create_error(error_type, reason) do
    {:error, error_type, reason}
  end

  @doc """
  Handle the command execution with proper error handling.

  Implements Railway-Oriented Programming to provide clear error flow.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: String.t() | {:error, error_type(), String.t()}
  def handle(_args, _settings, _optimus) do
    with {:ok, settings} <- load_settings(),
         {:ok, formatted} <- format_settings(settings) do
      formatted
    else
      # An empty configuration is a legitimate state, not a failure. This is the
      # same call settings.all makes, and it exits 0.
      {:error, :empty_settings, message} ->
        message

      # Every other failure returns its error tuple. Returning the message as a
      # plain string made a failed listing indistinguishable from a successful
      # one, so the CLI exited 0 either way (finding A19).
      {:error, _error_type, _message} = error ->
        error
    end
  end

  @doc """
  Load settings from the configuration file with proper error handling

  ## Returns
    - {:ok, settings} with settings map on success
    - {:error, error_type, reason} on error with details
  """
  # `Arca.Cli.load_settings/0` answers `{:ok, settings}` or `{:error, reason}`,
  # and the reason is the whole diagnosis -- "Failed to load config file: enoent",
  # or a parse error naming the position. This used to strict-match the `:ok`
  # tuple, so a legitimate error tuple raised a MatchError into a bare rescue that
  # logged the raw struct at the user and returned the constant string "Unknown
  # error loading settings" (finding A29). The user was told nothing, and a
  # `%MatchError{}` was printed above the dialect line.
  #
  # Its sibling `settings.all` reads the same function and reports the reason
  # correctly, so the two commands gave the same failure two different qualities
  # of answer. The reason now survives here too.
  #
  # There is no rescue. An unexpected exception is reported by `execute_command/5`
  # with its actual message, which is strictly more than a constant string, and
  # one handler for unexpected exceptions is the right number.
  @spec load_settings() :: result(map())
  def load_settings do
    case Arca.Cli.load_settings() do
      {:ok, settings} -> reject_empty(settings)
      {:error, reason} -> create_error(:load_failed, reason)
    end
  end

  # An empty configuration is a legitimate state rather than a failure: handle/3
  # returns this message as ordinary output and the command exits 0. It is tagged
  # as an error only so the `with` above can branch on it, which is why the text
  # reads as a sentence to the user rather than as a lowercase dialect fragment.
  @spec reject_empty(map()) :: result(map())
  defp reject_empty(settings) when map_size(settings) == 0 do
    create_error(:empty_settings, "No configuration settings found.")
  end

  defp reject_empty(settings), do: {:ok, settings}

  @doc """
  Format settings for display with proper error handling

  ## Parameters
    - settings: The configuration settings map to format
    
  ## Returns
    - {:ok, formatted_string} with formatted settings on success
    - {:error, error_type, reason} on formatting failure
  """
  @spec format_settings(map()) :: result(String.t())
  def format_settings(settings) do
    try do
      header = "Configuration Settings:\n"

      settings_list =
        settings
        |> Enum.map(fn {key, value} -> "  #{key}: #{inspect(value)}" end)
        |> Enum.join("\n")

      {:ok, header <> settings_list}
    rescue
      e ->
        create_error(:formatting_error, "failed to format settings: #{inspect(e)}")
    end
  end
end

defmodule Arca.Cli.Commands.CfgGetCommand do
  @moduledoc """
  Retrieves a specific setting value from the configuration.

  This command allows users to query individual settings by their ID,
  supporting string keys in the configuration. Uses Railway-Oriented Programming
  for proper error handling.
  """
  require Logger
  use Arca.Cli.Command.BaseCommand

  config :"cfg.get",
    name: "cfg.get",
    about: "Get a specific configuration setting",
    allow_unknown_args: true,
    args: [
      setting_key: [
        value_name: "SETTING_KEY",
        help: "The key of the setting to retrieve",
        required: true,
        parser: :string
      ]
    ]

  @typedoc """
  Possible error types for configuration operations
  """
  @type error_type ::
          :invalid_setting_key
          | :setting_not_found
          | :load_failed

  @typedoc """
  Result type for configuration operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Create a standardized error tuple for config operations
  """
  @spec create_error(error_type(), String.t()) :: {:error, error_type(), String.t()}
  def create_error(error_type, reason) do
    {:error, error_type, reason}
  end

  @doc """
  Handle the command execution with proper error handling.

  Implements Railway-Oriented Programming and properly processes command arguments.

  Every failure is returned as an error tuple rather than as its own message.
  Returning the message as a plain string made a failed lookup indistinguishable
  from a successful one, so the CLI exited 0 either way (finding A13).
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: String.t() | {:error, error_type(), String.t()}
  def handle(args, _settings, _optimus) do
    args
    |> extract_setting_key()
    |> get_setting()
  end

  @spec get_setting(String.t() | nil) :: String.t() | {:error, error_type(), String.t()}
  defp get_setting(setting_key) when setting_key in [nil, ""] do
    create_error(:invalid_setting_key, "no setting key given -- try 'cfg.get <setting_name>'")
  end

  defp get_setting(setting_key) do
    with {:ok, key} <- validate_setting_key(setting_key),
         {:ok, value} <- fetch_setting_value(key) do
      inspect(value, pretty: true)
    else
      {:error, error_type, message}
      when error_type in [:invalid_setting_key, :setting_not_found] ->
        {:error, error_type, message}

      {:error, error_type, message} ->
        Logger.debug("Cfg.get error: #{error_type} - #{message}")
        create_error(:load_failed, "cannot read setting #{setting_key}: #{message}")
    end
  end

  @doc """
  Extract the setting key from command arguments.

  Handles both regular args and unknown args formats to support flexibility.

  ## Parameters
    - args: The command arguments map
    
  ## Returns
    - The setting key as a string or nil if not found
  """
  @spec extract_setting_key(map()) :: String.t() | nil
  def extract_setting_key(args) do
    cond do
      # Case 1: Direct args access with setting_key
      is_map(args) && is_map(args.args) && Map.has_key?(args.args, :setting_key) ->
        args.args.setting_key

      # Case 2: Unknown args field with values
      is_map(args) && Map.has_key?(args, :unknown) && length(args.unknown) > 0 ->
        Enum.join(args.unknown, " ")

      # Case 3: No valid arguments found
      true ->
        nil
    end
  end

  @doc """
  Validate that a setting key is in a valid format

  ## Parameters
    - key: The setting key to validate
    
  ## Returns
    - {:ok, key} with the validated key on success
    - {:error, error_type, reason} if the key format is invalid
  """
  @spec validate_setting_key(String.t()) :: result(String.t())
  def validate_setting_key(key) when is_binary(key) and byte_size(key) > 0 do
    # Simple validation for now - just ensure it's not empty
    # Could be extended for more specific validation rules
    {:ok, key}
  end

  def validate_setting_key(nil) do
    create_error(:invalid_setting_key, "Setting key cannot be nil")
  end

  def validate_setting_key("") do
    create_error(:invalid_setting_key, "Setting key cannot be empty")
  end

  def validate_setting_key(_) do
    create_error(:invalid_setting_key, "Invalid setting key format")
  end

  @doc """
  Fetch a specific setting value using Railway-Oriented Programming

  ## Parameters
    - key: The setting key to fetch
    
  ## Returns
    - {:ok, value} with the setting value on success
    - {:error, error_type, reason} if the setting couldn't be found
  """
  @spec fetch_setting_value(String.t()) :: result(term())
  def fetch_setting_value(key) do
    case Arca.Cli.get_setting(key) do
      # Success with tuple
      {:ok, value} ->
        {:ok, value}

      # Error with message
      {:error, reason} ->
        create_error(:setting_not_found, reason)
    end
  end
end

defmodule Arca.Cli.Commands.CfgHelpCommand do
  @moduledoc """
  Displays help information for cfg namespace commands.

  This command provides an overview of all available commands in the
  cfg namespace and their purposes.
  """
  use Arca.Cli.Command.BaseCommand

  config :"cfg.help",
    name: "cfg.help",
    about: "Display help for cfg commands"

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(_args, _settings, _optimus) do
    # Return as a simple string instead of a heredoc to avoid formatting issues
    "Cfg Namespace Commands:\n\n" <>
      "cfg.list - List all configuration settings\n" <>
      "cfg.get  - Get a specific configuration setting\n" <>
      "cfg.help - Display this help message\n\n" <>
      "These commands help manage the application configuration."
  end
end
