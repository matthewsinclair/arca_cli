defmodule Arca.Cli.Ctx do
  @moduledoc """
  Context structure for carrying command output through the Arca.CLI pipeline.

  This module provides a clean separation between data processing and presentation logic,
  enabling commands to return structured data that can be rendered in different formats
  based on environment and user preferences.

  ## Overview

  The `Ctx` struct carries all information about a command's execution:
  - Command identification and arguments
  - Structured output items with semantic meaning
  - Error messages and status
  - Command-specific data (cargo)
  - Metadata for controlling rendering

  ## Output Item Types

  Output items use tagged tuples to convey semantic meaning:

      # Messages with semantic meaning
      {:success, message}
      {:error, message}
      {:warning, message}
      {:info, message}

      # Structured data
      {:table, rows, headers: headers}
      {:list, items, title: title}
      {:text, content}

      # Interactive elements (ansi mode only)
      {:spinner, label, func}
      {:progress, label, func}

  ## Usage Examples

      # Basic usage
      ctx = Arca.Cli.Ctx.new(%{}, %{})
            |> Ctx.add_output({:info, "Processing started"})
            |> Ctx.add_output({:success, "Operation completed"})
            |> Ctx.complete(:ok)

      # With structured data
      ctx = Arca.Cli.Ctx.new(args, settings)
            |> process_data()
            |> Ctx.add_output({:table, rows, headers: ["Name", "Value"]})
            |> Ctx.complete(:ok)

      # Error handling
      ctx = Arca.Cli.Ctx.new(args, settings)
            |> Ctx.add_error("Configuration invalid")
            |> Ctx.complete(:error)

      # Command-specific data
      ctx = Arca.Cli.Ctx.new(args, settings)
            |> Ctx.with_cargo(%{processed_count: 42})
            |> Ctx.complete(:ok)
  """

  @typedoc """
  Output item types with semantic meaning.
  """
  @type output_item ::
          {:success, String.t()}
          | {:error, String.t()}
          | {:warning, String.t()}
          | {:info, String.t()}
          | {:table, list(list()), keyword()}
          | {:list, list()}
          | {:list, list(), keyword()}
          | {:text, String.t()}
          | {:json, term()}
          | {:json, term(), keyword()}
          | {:spinner, String.t(), term()}
          | {:progress, String.t(), term()}

  @typedoc """
  Command execution status.
  """
  @type status :: :ok | :error | :warning

  @typedoc """
  A rendering style a context can request.
  """
  @type style :: :ansi | :plain | :json | :dump

  @styles [:ansi, :plain, :json, :dump]

  @typedoc """
  The context structure carrying command output and metadata.
  """
  @type t :: %__MODULE__{
          command: atom() | nil,
          args: map(),
          options: map(),
          output: list(output_item()),
          errors: list(String.t()),
          status: status() | nil,
          cargo: map(),
          meta: map()
        }

  defstruct command: nil,
            args: %{},
            options: %{},
            output: [],
            errors: [],
            status: nil,
            cargo: %{},
            meta: %{}

  @doc """
  Creates a new context from command arguments and settings.

  ## Parameters
    - args: Command arguments map from Optimus parsing
    - settings: Application settings map (optional)
    - opts: Additional options (optional)
      - :command - The command atom being executed
      - :options - Command-specific options

  ## Examples

      iex> Ctx.new(%{name: "test"}, %{})
      %Ctx{args: %{name: "test"}, ...}

      iex> Ctx.new(%{}, %{}, command: :about, options: %{verbose: true})
      %Ctx{command: :about, options: %{verbose: true}, ...}
  """
  @spec new(map() | nil, map(), keyword()) :: t()
  def new(args, settings, opts \\ [])

  def new(command, _settings, _opts) when is_atom(command) and not is_nil(command) do
    raise ArgumentError, """
    Arca.Cli.Ctx.new/3 takes the command arguments as its first parameter, but was \
    given the command atom #{inspect(command)}.

    The command belongs on the :command option. Use for_command/4, which puts it there:

        Ctx.for_command(#{inspect(command)}, args, settings)
    """
  end

  def new(args, settings, opts) do
    %__MODULE__{
      command: Keyword.get(opts, :command),
      args: args || %{},
      options: Keyword.get(opts, :options, %{}),
      meta: extract_meta_from_settings(settings)
    }
  end

  @doc """
  Creates a new context for a named command.

  The convenience form of `new/3` that makes the correct call the easy one: the
  command is the first parameter, where it reads naturally, rather than an option
  buried behind the arguments.

  ## Parameters
    - command: The command atom being executed
    - args: Command arguments map from Optimus parsing
    - settings: Application settings map
    - opts: Additional options (optional), as for `new/3`

  ## Examples

      iex> ctx = Arca.Cli.Ctx.for_command(:"sys.info", %{}, %{})
      iex> {ctx.command, ctx.args}
      {:"sys.info", %{}}
  """
  @spec for_command(atom(), map() | nil, map(), keyword()) :: t()
  def for_command(command, args, settings, opts \\ []) when is_atom(command) do
    new(args, settings, Keyword.put(opts, :command, command))
  end

  @doc """
  Resolves a rendering style name to its atom.

  The one place a style name becomes a style. Settings and the `ARCA_STYLE`
  environment variable both carry the style as text, and both resolve through
  here, so the vocabulary is stated once. An unrecognised name is reported rather
  than turned into an atom -- settings are user-editable, and `String.to_atom/1`
  on user input grows a table the VM never reclaims.

  ## Examples

      iex> Arca.Cli.Ctx.parse_style("json")
      {:ok, :json}

      iex> Arca.Cli.Ctx.parse_style(:plain)
      {:ok, :plain}

      iex> Arca.Cli.Ctx.parse_style("technicolor")
      :error
  """
  @spec parse_style(String.t() | atom() | nil) :: {:ok, style()} | :error
  def parse_style(style) when style in @styles, do: {:ok, style}
  def parse_style("ansi"), do: {:ok, :ansi}
  def parse_style("plain"), do: {:ok, :plain}
  def parse_style("json"), do: {:ok, :json}
  def parse_style("dump"), do: {:ok, :dump}
  def parse_style(_style), do: :error

  @doc """
  Appends an output item to the context.

  Output items are accumulated in order and will be rendered sequentially.

  ## Parameters
    - ctx: The context to update
    - item: The output item to add

  ## Examples

      iex> ctx |> Ctx.add_output({:success, "File saved"})
      %Ctx{output: [{:success, "File saved"}], ...}

      iex> ctx |> Ctx.add_output({:table, rows, headers: ["Name", "Value"]})
      %Ctx{output: [{:table, rows, headers: ["Name", "Value"]}], ...}
  """
  @spec add_output(t(), output_item()) :: t()
  def add_output(%__MODULE__{output: output} = ctx, item) do
    %{ctx | output: output ++ [resolve_deferred(item)]}
  end

  @doc """
  Resolves any deferred work still carried in a context's output items.

  `add_output/2` already does this as items are added, so this is the safety net
  for a context built as a struct literal: it guarantees no renderer is ever
  handed a function to execute. Resolving twice is harmless -- an item whose work
  has already run no longer holds a function.
  """
  @spec resolve_output(t()) :: t()
  def resolve_output(%__MODULE__{output: output} = ctx) when is_list(output) do
    %{ctx | output: Enum.map(output, &resolve_deferred/1)}
  end

  def resolve_output(%__MODULE__{} = ctx), do: ctx

  # Work carried inside an output item runs here, at context build time, so it
  # happens exactly once and identically under every output style. The ANSI
  # renderer used to execute it, which meant a spinner's function ran on a TTY
  # and was silently skipped in plain output, in JSON, in pipes and in tests.
  @spec resolve_deferred(output_item()) :: output_item()
  defp resolve_deferred({:spinner, label, func}) when is_function(func, 0) do
    {:spinner, label, func.()}
  end

  defp resolve_deferred({:progress, label, func}) when is_function(func, 0) do
    {:progress, label, func.()}
  end

  defp resolve_deferred(item), do: item

  @doc """
  Appends multiple output items to the context.

  ## Parameters
    - ctx: The context to update
    - items: List of output items to add

  ## Examples

      iex> ctx |> Ctx.add_outputs([{:info, "Step 1"}, {:info, "Step 2"}])
      %Ctx{output: [{:info, "Step 1"}, {:info, "Step 2"}], ...}
  """
  @spec add_outputs(t(), list(output_item())) :: t()
  def add_outputs(%__MODULE__{} = ctx, items) when is_list(items) do
    Enum.reduce(items, ctx, &add_output(&2, &1))
  end

  @doc """
  Appends an error message to the context.

  Errors are tracked separately from output for special handling during rendering.

  ## Parameters
    - ctx: The context to update
    - error_msg: Error message string

  ## Examples

      iex> ctx |> Ctx.add_error("Invalid configuration")
      %Ctx{errors: ["Invalid configuration"], ...}
  """
  @spec add_error(t(), String.t()) :: t()
  def add_error(%__MODULE__{errors: errors} = ctx, error_msg) when is_binary(error_msg) do
    %{ctx | errors: errors ++ [error_msg]}
  end

  @doc """
  Appends multiple error messages to the context.

  ## Parameters
    - ctx: The context to update
    - error_msgs: List of error message strings

  ## Examples

      iex> ctx |> Ctx.add_errors(["Error 1", "Error 2"])
      %Ctx{errors: ["Error 1", "Error 2"], ...}
  """
  @spec add_errors(t(), list(String.t())) :: t()
  def add_errors(%__MODULE__{} = ctx, error_msgs) when is_list(error_msgs) do
    Enum.reduce(error_msgs, ctx, &add_error(&2, &1))
  end

  @doc """
  The context string for this command's `error:` dialect lines.

  Text renderers pair this with `Arca.Cli.ErrorHandler.error_line/2` to report a
  Ctx failure as `error: <command>: <message>`, the same dialect the
  string-returning command paths use. Defined here rather than in each renderer
  so both agree on what the context is.

  ## Examples

      iex> Arca.Cli.Ctx.error_context(%Arca.Cli.Ctx{command: :"cfg.get"})
      "cfg.get"

      iex> Arca.Cli.Ctx.error_context(%Arca.Cli.Ctx{command: nil})
      nil
  """
  @spec error_context(t()) :: String.t() | nil
  def error_context(%__MODULE__{command: nil}), do: nil
  def error_context(%__MODULE__{command: command}), do: Atom.to_string(command)

  @doc """
  Sets command-specific data in the cargo field.

  The cargo field allows commands to store arbitrary data that might be needed
  by renderers or for debugging purposes.

  ## Parameters
    - ctx: The context to update
    - data: Map of command-specific data

  ## Examples

      iex> ctx |> Ctx.with_cargo(%{processed: 42, skipped: 3})
      %Ctx{cargo: %{processed: 42, skipped: 3}, ...}
  """
  @spec with_cargo(t(), map()) :: t()
  def with_cargo(%__MODULE__{} = ctx, data) when is_map(data) do
    %{ctx | cargo: data}
  end

  @doc """
  Updates the cargo field by merging with existing data.

  ## Parameters
    - ctx: The context to update
    - data: Map of command-specific data to merge

  ## Examples

      iex> ctx |> Ctx.update_cargo(%{new_field: "value"})
      %Ctx{cargo: %{existing: "data", new_field: "value"}, ...}
  """
  @spec update_cargo(t(), map()) :: t()
  def update_cargo(%__MODULE__{cargo: cargo} = ctx, data) when is_map(data) do
    %{ctx | cargo: Map.merge(cargo, data)}
  end

  @doc """
  Sets the final status of the command execution.

  This should be called once at the end of command processing to indicate
  the overall result.

  ## Parameters
    - ctx: The context to update
    - status: Final status (:ok, :error, or :warning)

  ## Examples

      iex> ctx |> Ctx.complete(:ok)
      %Ctx{status: :ok, ...}

      iex> ctx |> Ctx.complete(:error)
      %Ctx{status: :error, ...}
  """
  @spec complete(t(), status()) :: t()
  def complete(%__MODULE__{} = ctx, status) when status in [:ok, :error, :warning] do
    %{ctx | status: status}
  end

  @doc """
  The outcome of this context: whether the command succeeded, warned, or failed.

  This is the single authority on the question. An explicit `complete/2` status
  wins; failing that, a context carrying errors is a failure rather than a
  success, because a command that called `add_error/2` and never completed has
  still failed.

  Dispatch turns this into the OS exit status, both text renderers use it to
  decide whether to emit the `error:` dialect line, and the JSON renderer reports
  it as the status field. They all call this one function so those answers cannot
  disagree. Before this existed they each decided independently, and the answers
  did diverge: a context built by `add_error/2 |> complete(:ok)` printed `error:`
  while exiting 0, and one built by `add_error/2` alone exited 1 while its JSON
  carried no status field at all (finding A28).

  ## Examples

      iex> ctx |> Ctx.complete(:ok) |> Ctx.outcome()
      :ok

      iex> ctx |> Ctx.add_error("boom") |> Ctx.outcome()
      :error
  """
  @spec outcome(t()) :: status()
  def outcome(%__MODULE__{status: status}) when status in [:ok, :error, :warning], do: status
  def outcome(%__MODULE__{errors: [_ | _]}), do: :error
  def outcome(%__MODULE__{}), do: :ok

  @doc """
  Whether this context represents a failed command.

  `outcome/1` reduced to the question the renderers ask. Tied to `outcome/1` so
  that a red `error:` line and a non-zero exit status always travel together.

  ## Examples

      iex> ctx |> Ctx.add_error("boom") |> Ctx.failed?()
      true

      iex> ctx |> Ctx.add_error("noted") |> Ctx.complete(:ok) |> Ctx.failed?()
      false
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{} = ctx), do: outcome(ctx) == :error

  @doc """
  Sets a metadata value for controlling rendering behavior.

  Metadata can influence how the output is rendered, such as forcing a specific
  style or disabling certain features.

  ## Parameters
    - ctx: The context to update
    - key: Metadata key (atom)
    - value: Metadata value

  ## Common metadata keys:
    - :style - Force a specific rendering style (:ansi, :plain, :json, :dump)
    - :no_color - Disable color output
    - :format - Output format (:text, :json, :yaml)

  ## Examples

      iex> ctx |> Ctx.set_meta(:style, :plain)
      %Ctx{meta: %{style: :plain}, ...}
  """
  @spec set_meta(t(), atom(), any()) :: t()
  def set_meta(%__MODULE__{meta: meta} = ctx, key, value) when is_atom(key) do
    %{ctx | meta: Map.put(meta, key, value)}
  end

  @doc """
  Updates metadata by merging with existing values.

  ## Parameters
    - ctx: The context to update
    - metadata: Map of metadata to merge

  ## Examples

      iex> ctx |> Ctx.update_meta(%{style: :plain, no_color: true})
      %Ctx{meta: %{style: :plain, no_color: true}, ...}
  """
  @spec update_meta(t(), map()) :: t()
  def update_meta(%__MODULE__{meta: meta} = ctx, metadata) when is_map(metadata) do
    %{ctx | meta: Map.merge(meta, metadata)}
  end

  @doc """
  Converts the context to a simple string representation for testing.

  This is a basic renderer that shows the structure of the context without
  any formatting. Primarily useful for testing and debugging.

  ## Parameters
    - ctx: The context to render

  ## Examples

      iex> ctx |> Ctx.to_string()
      "Status: ok\\nOutput: 2 items\\nErrors: 0"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = ctx) do
    status_line = "Status: #{ctx.status || "pending"}"
    output_line = "Output: #{length(ctx.output)} items"
    error_line = "Errors: #{length(ctx.errors)}"

    lines = [status_line, output_line, error_line]

    # Add cargo info if present
    lines =
      if map_size(ctx.cargo) > 0 do
        lines ++ ["Cargo: #{inspect(ctx.cargo)}"]
      else
        lines
      end

    # Add actual output items for debugging
    lines =
      if length(ctx.output) > 0 do
        output_items =
          ctx.output
          |> Enum.map(&format_output_item/1)
          |> Enum.join("\n")

        lines ++ ["", "Items:", output_items]
      else
        lines
      end

    # Add errors if present
    lines =
      if length(ctx.errors) > 0 do
        error_items = ctx.errors |> Enum.map(&"  - #{&1}") |> Enum.join("\n")
        lines ++ ["", "Error messages:", error_items]
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  # Private helper to extract metadata from settings
  defp extract_meta_from_settings(settings) when is_map(settings) do
    %{}
    |> maybe_add_style(settings)
    |> maybe_add_no_color(settings)
  end

  defp extract_meta_from_settings(_), do: %{}

  defp maybe_add_style(meta, settings) do
    case parse_style(Map.get(settings, "style")) do
      {:ok, style} -> Map.put(meta, :style, style)
      :error -> meta
    end
  end

  defp maybe_add_no_color(meta, settings) do
    case Map.get(settings, "no_color") do
      true -> Map.put(meta, :no_color, true)
      _ -> meta
    end
  end

  # Private helper to format output items for debugging
  defp format_output_item({:success, msg}), do: "  [success] #{msg}"
  defp format_output_item({:error, msg}), do: "  [error] #{msg}"
  defp format_output_item({:warning, msg}), do: "  [warning] #{msg}"
  defp format_output_item({:info, msg}), do: "  [info] #{msg}"
  defp format_output_item({:text, content}), do: "  [text] #{String.slice(content, 0, 50)}..."

  defp format_output_item({:table, rows, opts}) do
    "  [table] #{length(rows)} rows, opts: #{inspect(opts)}"
  end

  defp format_output_item({:list, items, opts}) do
    "  [list] #{length(items)} items, opts: #{inspect(opts)}"
  end

  defp format_output_item({:spinner, label, _func}), do: "  [spinner] #{label}"
  defp format_output_item({:progress, label, _func}), do: "  [progress] #{label}"
  defp format_output_item(other), do: "  [unknown] #{inspect(other)}"
end
