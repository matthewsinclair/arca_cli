defmodule Arca.Cli.Output do
  @moduledoc """
  Main output orchestration module for Arca.CLI.

  This module provides the central rendering pipeline that:
  - Determines the appropriate output style based on context and environment
  - Dispatches to the correct renderer (fancy, plain, or dump)
  - Handles the complete transformation from Context to final output string

  ## Style Precedence

  The output style is determined by the following precedence (highest to lowest):
  1. Explicit style in context metadata
  2. NO_COLOR environment variable (forces plain)
  3. ARCA_STYLE environment variable
  4. MIX_ENV=test (forces plain in test environment)
  5. TTY availability (ansi if TTY, plain otherwise)

  ## Available Styles

  - `:ansi` - Full colors, symbols, and enhanced formatting (TTY only)
  - `:plain` - No ANSI codes, plain text with Unicode symbols
  - `:dump` - Raw data dump for debugging, shows Context structure

  ## Examples

      iex> ctx = %Arca.Cli.Ctx{output: [{:success, "Done"}]}
      iex> Output.render(ctx)
      "✓ Done"

      iex> ctx = %Arca.Cli.Ctx{output: [{:error, "Failed"}], meta: %{style: :dump}}
      iex> Output.render(ctx)
      "%Arca.Cli.Ctx{...}"
  """

  alias Arca.Cli.Ctx
  alias Arca.Cli.Output.{AnsiRenderer, PlainRenderer, JsonRenderer}

  @doc """
  Renders a Context to final output string.

  Takes a Context struct and renders it according to the determined style,
  returning a string ready for output.

  ## Parameters
    - ctx: The Context struct to render

  ## Returns
    - Formatted string output
  """
  @spec render(Ctx.t() | nil) :: String.t()
  def render(nil), do: ""

  def render(%Ctx{} = ctx) do
    ctx
    |> Ctx.resolve_output()
    |> apply_format_callbacks()
    |> process_rendering()
  end

  @doc """
  Applies format_output callbacks to transform the context.

  Supports both legacy string callbacks and new Context transformations.
  """
  @spec apply_format_callbacks(Ctx.t() | String.t()) :: Ctx.t() | String.t()
  def apply_format_callbacks(data) do
    case Arca.Cli.Callbacks.has_callbacks?(:format_output) do
      true -> Arca.Cli.Callbacks.execute(:format_output, data)
      false -> data
    end
  end

  # Process rendering pipeline
  defp process_rendering(%Ctx{} = ctx) do
    ctx
    |> determine_style()
    |> apply_renderer(ctx)
    |> format_for_output()
  end

  # Style determination with precedence chain
  defp determine_style(%Ctx{meta: %{style: style}} = ctx) do
    case Ctx.parse_style(style) do
      {:ok, resolved} -> resolved
      :error -> determine_style_from_environment(ctx)
    end
  end

  defp determine_style(%Ctx{} = ctx), do: determine_style_from_environment(ctx)

  defp determine_style_from_environment(%Ctx{} = ctx) do
    case check_environment() do
      {:style, style} -> style
      :auto -> auto_detect_style(ctx)
    end
  end

  # Check environment variables and settings
  defp check_environment do
    cond do
      no_color?() -> {:style, :plain}
      style = env_style() -> {:style, style}
      test_env?() -> {:style, :plain}
      true -> :auto
    end
  end

  # Auto-detect based on TTY availability
  defp auto_detect_style(_ctx) do
    case tty?() do
      true -> :ansi
      false -> :plain
    end
  end

  # Renderer dispatch
  defp apply_renderer(:ansi, ctx), do: AnsiRenderer.render(ctx)
  defp apply_renderer(:plain, ctx), do: PlainRenderer.render(ctx) |> IO.iodata_to_binary()
  defp apply_renderer(:json, ctx), do: JsonRenderer.render(ctx)
  defp apply_renderer(:dump, ctx), do: dump_context(ctx)

  # Dump renderer for debugging
  defp dump_context(%Ctx{} = ctx) do
    %{
      command: ctx.command,
      args: ctx.args,
      options: ctx.options,
      output: ctx.output,
      errors: ctx.errors,
      status: ctx.status,
      cargo: ctx.cargo,
      meta: ctx.meta
    }
    |> inspect(pretty: true, width: 80, limit: :infinity)
  end

  # Final formatting - ensure we always return a string
  defp format_for_output(result) when is_binary(result), do: result
  defp format_for_output(result) when is_list(result), do: IO.iodata_to_binary(result)
  defp format_for_output(nil), do: ""
  defp format_for_output(result), do: to_string(result)

  # Environment detection helpers

  defp no_color? do
    case System.get_env("NO_COLOR") do
      nil -> false
      "" -> false
      "0" -> false
      "false" -> false
      _ -> true
    end
  end

  defp env_style do
    case Ctx.parse_style(System.get_env("ARCA_STYLE")) do
      {:ok, style} -> style
      :error -> nil
    end
  end

  defp test_env? do
    case System.get_env("MIX_ENV") do
      "test" -> true
      _ -> false
    end
  end

  @doc """
  Whether standard output is an interactive terminal.

  Asks the runtime directly. `TERM` alone is not an answer -- it is inherited by
  piped processes, so it describes the terminal the CLI was launched from rather
  than where output is actually going, which is why forcing colour on from it
  pushed escape codes into pipes and files.

  `:io.columns/1` is not an answer either: escripts run with `-noinput`, where the
  IO device reports `:enotsup` even on a terminal.
  """
  @spec tty?() :: boolean()
  def tty? do
    case System.get_env("TERM") do
      nil -> false
      "dumb" -> false
      _ -> :prim_tty.isatty(:stdout) == true
    end
  end

  @doc """
  Returns the current output style that would be used for rendering.

  Useful for debugging and testing style determination logic.

  ## Parameters
    - ctx: Optional context to check for style metadata

  ## Returns
    - The style atom (:ansi, :plain, or :dump)

  ## Examples

      iex> Output.current_style()
      :ansi

      iex> ctx = %Ctx{meta: %{style: :plain}}
      iex> Output.current_style(ctx)
      :plain
  """
  @spec current_style(Ctx.t() | nil) :: :ansi | :plain | :dump
  def current_style(ctx \\ nil) do
    case ctx do
      nil -> determine_style(%Ctx{})
      %Ctx{} = context -> determine_style(context)
      _ -> determine_style(%Ctx{})
    end
  end
end
