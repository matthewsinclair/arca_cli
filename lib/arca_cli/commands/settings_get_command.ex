defmodule Arca.Cli.Commands.SettingsGetCommand do
  @moduledoc """
  Retrieves a specific setting value from the configuration.

  This command allows users to query individual settings by their ID,
  supporting dot notation for accessing nested configuration values.
  """
  alias Arca.Cli
  use Arca.Cli.Command.BaseCommand

  config :"settings.get",
    name: "settings.get",
    about: "Get the value of a specific setting",
    args: [
      id: [
        value_name: "SETTING_ID",
        help: "Setting ID (supports dot notation for nested settings)",
        required: true,
        parser: :string
      ]
    ]

  @typedoc """
  Possible error types for settings retrieval operations
  """
  @type error_type ::
          :setting_not_found
          | :invalid_setting_id
          | :load_failed
          | :internal_error

  @typedoc """
  Result type for settings operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Retrieve a setting value by its ID.

  This implementation handles both the new error tuple format and legacy formats,
  providing backward compatibility while leveraging Railway-Oriented Programming.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: any() | String.t()
  def handle(args, _settings, _optimus) do
    retrieve_setting(args.args.id)
  rescue
    error in RuntimeError ->
      # Maintain compatibility with legacy error handling
      error.message
  end

  # Retrieve a setting by ID and handle all potential error cases
  @spec retrieve_setting(String.t()) :: any() | String.t()
  defp retrieve_setting(setting_id) do
    # Delegate to Cli.get_setting and handle the return types
    case Cli.get_setting(setting_id) do
      # Success case
      {:ok, value} ->
        value

      # Error case
      {:error, message} ->
        message
    end
  end
end
