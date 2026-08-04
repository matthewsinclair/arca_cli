defmodule Arca.Cli.Commands.SettingsAllCommand do
  @moduledoc """
  Displays all current configuration settings.

  This command provides a formatted view of all application settings,
  showing the complete configuration state.
  """
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :"settings.all",
    name: "settings.all",
    about: "Display current configuration settings."

  @typedoc """
  Possible error types for settings display operations
  """
  @type error_type ::
          :formatting_error
          | :empty_settings
          | :internal_error

  @typedoc """
  Result type for settings operations
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Format and display all settings using the Context pattern.

  Returns a Context with structured output showing all settings in a table format.
  """
  @impl Arca.Cli.Command.CommandBehaviour
  @spec handle(map(), map(), Optimus.t()) :: Ctx.t() | String.t()
  def handle(args, settings, _optimus) do
    ctx = Ctx.for_command(:"settings.all", args, settings)

    case Arca.Cli.load_settings() do
      {:ok, loaded_settings} ->
        render_settings(ctx, loaded_settings)

      {:error, reason} ->
        ctx
        |> Ctx.add_error(reason)
        |> Ctx.complete(:error)
    end
  end

  # Render whatever configuration is actually in force.
  #
  # This used to answer with a fabricated two-row table reading "test/true"
  # whenever it ran under test, so the command's own test could not tell the
  # difference between reading the configuration correctly and not reading it at
  # all. The settings a test wants to see are the settings it seeded.
  @spec render_settings(Ctx.t(), map()) :: Ctx.t()
  defp render_settings(ctx, settings) when is_map(settings) and map_size(settings) > 0 do
    ctx
    |> Ctx.add_output({:info, "Current Configuration Settings"})
    |> Ctx.add_output({:table, settings_to_table_rows(settings), [has_headers: true]})
    |> Ctx.with_cargo(%{settings_count: map_size(settings)})
    |> Ctx.complete(:ok)
  end

  defp render_settings(ctx, _settings) do
    ctx
    |> Ctx.add_output({:warning, "No settings available"})
    |> Ctx.complete(:ok)
  end

  # Convert settings map to table rows
  defp settings_to_table_rows(settings) do
    # First row is headers
    headers = ["Setting", "Value", "Type"]

    # Convert each setting to a row
    data_rows =
      settings
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, value} ->
        [
          to_string(key),
          format_value(value),
          type_of_value(value)
        ]
      end)

    [headers | data_rows]
  end

  # Format value for display
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_atom(value), do: to_string(value)
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value) when is_list(value), do: inspect(value, pretty: true)
  defp format_value(value) when is_map(value), do: inspect(value, pretty: true)
  defp format_value(value), do: inspect(value)

  # Get type of value as string
  defp type_of_value(value) when is_binary(value), do: "string"
  defp type_of_value(value) when is_boolean(value), do: "boolean"
  defp type_of_value(value) when is_atom(value), do: "atom"
  defp type_of_value(value) when is_integer(value), do: "integer"
  defp type_of_value(value) when is_float(value), do: "float"
  defp type_of_value(value) when is_list(value), do: "list"
  defp type_of_value(value) when is_map(value), do: "map"
  defp type_of_value(_value), do: "other"
end
