defmodule Arca.Cli.Commands.AboutCommand do
  @moduledoc """
  Displays basic information about the CLI application.

  This command shows version, description, and other core information
  about the CLI application to users.
  """
  use Arca.Cli.Command.BaseCommand

  @cli_command """
  Arca.Cli is a simple example implementation to show the main use cases. It displays basic information about the CLI application.

  This command shows version, description, and other core information about the CLI application to users.
  """

  config :about,
    name: "about",
    about: "Info about the command line interface.",
    help: @cli_command

  @typedoc """
  Possible error types for the about command
  """
  @type error_type ::
          :app_info_unavailable
          | :formatting_error

  @typedoc """
  Result type for about command operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Display about info for the core CLI.

  Uses Railway-Oriented Programming to handle potential failures
  when retrieving application information.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: String.t()
  def handle(args, settings, _optimus) do
    with {:ok, about_text} <- get_about_text(args, settings) do
      about_text
    else
      {:error, _error_type, message} ->
        "Error: #{message}"
    end
  end

  @doc """
  Retrieve the application about text with error handling.

  ## Returns
    - {:ok, about_text} with formatted about info
    - {:error, error_type, reason} on failure
  """
  @spec get_about_text(map(), map()) :: result(String.t())
  def get_about_text(args, settings) do
    try do
      about_text = Arca.Cli.intro(args, settings)
      {:ok, about_text}
    rescue
      e in ArgumentError ->
        {:error, :app_info_unavailable,
         "Failed to retrieve application info: #{Exception.message(e)}"}

      _ ->
        {:error, :formatting_error, "An error occurred while retrieving application information"}
    end
  end
end
