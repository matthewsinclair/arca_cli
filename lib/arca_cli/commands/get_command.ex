defmodule Arca.Cli.Commands.GetCommand do
  @moduledoc """
  Arca CLI command to get a property from settings.
  """
  alias Arca.Cli
  use Arca.Cli.Command.BaseCommand

  config :get,
    name: "get",
    about: "Get the value of a setting.",
    args: [
      id: [
        value_name: "SETTING_ID",
        help: "Setting id",
        required: true,
        parser: :string
      ]
    ]

  @doc """
  Get a settings value from settings by its id (with dot notation)
  """
  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, _settings, _optimus) do
    case Cli.get_setting(args.args.id) do
      # Error message is returned directly
      {:error, message} -> message
      # Extract value from success tuple
      {:ok, value} -> value
    end
  rescue
    error in RuntimeError -> error.message
  end
end
