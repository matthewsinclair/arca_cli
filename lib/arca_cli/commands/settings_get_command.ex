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

  A setting that cannot be read is returned as an error tuple, not as its own
  message. Returning the message as a plain string made this command indis-
  tinguishable from one that succeeded and happened to print an explanation, so
  the CLI exited 0 on a failed lookup (finding A13).
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: any() | Cli.error_tuple()
  def handle(args, _settings, _optimus) do
    retrieve_setting(args.args.id)
  rescue
    error in RuntimeError ->
      {:error, :internal_error, error.message}
  end

  # Retrieve a setting by ID and handle all potential error cases
  @spec retrieve_setting(String.t()) :: any() | Cli.error_tuple()
  defp retrieve_setting(setting_id) do
    case Cli.get_setting(setting_id) do
      {:ok, value} -> value
      {:error, message} -> {:error, :setting_not_found, message}
    end
  end
end
