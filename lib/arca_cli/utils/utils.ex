defmodule Arca.Cli.Utils do
  @moduledoc """
  Utility functions for the Arca CLI.

  This module provides a collection of utility functions for common operations such as:
  - Converting between data types
  - Pretty printing
  - ANSI formatting
  - Data validation
  - Error handling
  - Time measurement
  - String manipulation

  These functions are designed to follow functional programming principles with
  consistent return types, explicit error handling, and pipeline-friendly interfaces.
  """

  @typedoc """
  Types of errors that can occur in the Utils module.
  """
  @type error_type ::
          :decode_error
          | :encode_error
          | :parsing_error
          | :conversion_error
          | :validation_error
          | :execution_error

  @typedoc """
  Standard result tuple for operations that might fail.
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), term()}

  @doc """
  Wraps the given value in an `{:ok, value}` tuple.

  ## Parameters
  - `x`: The value to be wrapped.

  ## Returns
  - `{:ok, x}`.

  ## Examples
      iex> Arca.Cli.Utils.return("value")
      {:ok, "value"}
  """
  @spec return(term()) :: {:ok, term()}
  def return(x) do
    {:ok, x}
  end

  @doc """
  Returns the value if it's an `{:ok, value}` tuple, or a default value if it's an error tuple.

  ## Parameters
  - `x`: The result tuple (`{:ok, value}` or `{:error, reason}`).
  - `default`: The default value to return in case of an error.

  ## Returns
  - The value from the `{:ok, value}` tuple.
  - The default value if `x` is an `{:error, reason}` tuple.
  - The original value if `x` is neither.

  ## Examples
      iex> Arca.Cli.Utils.with_default({:ok, "value"}, "default")
      "value"

      iex> Arca.Cli.Utils.with_default({:error, "error"}, "default")
      "default"
  """
  @spec with_default({:ok, term()} | {:error, term()} | term(), term()) :: term()
  def with_default({:ok, value}, _default), do: value
  def with_default({:error, _reason}, default), do: default
  def with_default({:error, _type, _reason}, default), do: default
  def with_default(value, _default), do: value

  @doc """
  Converts the given URL into an ANSI-formatted clickable link.

  ## Parameters
  - `url`: The URL to be converted.

  ## Returns
  - A string containing the ANSI-formatted clickable link.

  ## Examples
      iex> Arca.Cli.Utils.to_url_link("http://example.com")
      "\e[96m\e[4m\e]8;;http://example.com\ahttp://example.com\e]8;;\a\e[0m"
  """
  @spec to_url_link(String.t()) :: String.t()
  def to_url_link(url) do
    "#{IO.ANSI.light_cyan()}#{IO.ANSI.underline()}\e]8;;#{url}\a#{url}\e]8;;\a#{IO.ANSI.reset()}"
  end

  @doc """
  Prints the given output, filtering out blank lines before printing.

  ## Parameters
  - `out`: The output to be printed.

  ## Returns
  - :ok or list of :ok values

  ## Examples
      iex> # The print function filters blank lines and prints the rest
      iex> # For testing purposes, see filter_blank_lines/1 doctest
  """
  @spec print(term()) :: :ok | [:ok]
  def print(out) do
    out |> filter_blank_lines() |> put_lines()
  end

  @doc """
  Prints an ANSI-formatted version of the given value.

  Using pattern matching to handle different data types appropriately.

  ## Parameters
  - `to_print`: The value to be printed.

  ## Returns
  - :ok

  ## Examples
      iex> # The print_ansi function prints ANSI-formatted output
      iex> # Returns :ok on success
  """
  @spec print_ansi(term()) :: :ok
  def print_ansi(to_print) when is_map(to_print), do: to_print |> to_str() |> print_ansi()
  def print_ansi(nil), do: "nil" |> print_ansi()
  def print_ansi(to_print) when is_atom(to_print), do: to_print |> to_str() |> print_ansi()
  def print_ansi(to_print) when is_tuple(to_print), do: to_print |> to_str() |> print_ansi()
  def print_ansi(to_print), do: to_print |> IO.ANSI.format() |> IO.puts()

  @doc """
  Prints a pretty-printed version of the given term.

  ## Parameters
  - `term`: The term to be printed.

  ## Returns
  - :ok

  ## Examples
      iex> # The pretty_print function outputs a string representation
      iex> # Returns :ok on success
  """
  @spec pretty_print(term()) :: :ok
  def pretty_print(term) do
    IO.puts(to_str(term))
  end

  @doc """
  Prints each line from the given value, using pattern matching
  to handle different data types appropriately.

  ## Parameters
  - `lines`: Value to be printed, supported types:
    - list of strings
    - map
    - tuple
    - binary string
    - nil
    - atom

  ## Returns
  - :ok or list of :ok values

  ## Examples
      iex> # The put_lines function prints each line
      iex> # Returns :ok or a list of :ok values
  """
  @spec put_lines(term()) :: :ok | [:ok]
  def put_lines(lines) when is_list(lines), do: Enum.map(lines, &print_ansi/1)
  # Rendered through the one term-to-string path rather than IO.inspect/1, which
  # writes its own debug representation straight to stdout behind the caller's
  # back -- and returns the term, not :ok, so even the spec was wrong.
  def put_lines(map) when is_map(map), do: map |> to_str() |> print_ansi()
  def put_lines(tpl) when is_tuple(tpl), do: tpl |> to_str() |> print_ansi()
  def put_lines(string) when is_binary(string), do: string |> String.trim() |> print_ansi()
  def put_lines(nil), do: "nil" |> print_ansi()

  def put_lines(atom) when is_atom(atom) do
    unless atom == :ok, do: to_string(atom) |> print_ansi()
  end

  @doc """
  Converts the given term to a string with pretty printing enabled.

  Uses pattern matching for clean, specialized handling of different types.

  ## Parameters
  - `term`: The term to be converted.

  ## Returns
  - A string representation of the term.

  ## Examples
      iex> Arca.Cli.Utils.to_str(%{key: "value"})
      "%{key: \\"value\\"}"
  """
  @spec to_str(term()) :: String.t()
  def to_str(term), do: inspect(term, pretty: true, limit: :infinity)

  @doc """
  Determines the type of the given term using pattern matching
  for a clean, functional implementation.

  ## Parameters
  - `term`: The term whose type is to be determined.

  ## Returns
  - The type of the term as an atom.

  ## Examples
      iex> Arca.Cli.Utils.type_of(:atom)
      :atom

      iex> Arca.Cli.Utils.type_of(true)
      :boolean

      iex> Arca.Cli.Utils.type_of(42)
      :integer
  """
  @spec type_of(term()) :: atom()
  def type_of(term) when is_boolean(term), do: :boolean
  def type_of(nil), do: nil
  def type_of(term) when is_atom(term), do: :atom
  def type_of(term) when is_function(term), do: :function
  def type_of(term) when is_list(term), do: :list
  def type_of(term) when is_map(term), do: :map
  def type_of(term) when is_pid(term), do: :pid
  def type_of(term) when is_port(term), do: :port
  def type_of(term) when is_reference(term), do: :reference
  def type_of(term) when is_tuple(term), do: :tuple
  def type_of(term) when is_binary(term), do: :binary
  def type_of(term) when is_bitstring(term), do: :bitstring
  def type_of(term) when is_integer(term), do: :integer
  def type_of(term) when is_float(term), do: :float

  @doc """
  Checks if the given data is blank using pattern matching
  for clean handling of different data types.

  A blank value is:
  - `nil`
  - An empty string (only spaces are considered empty)
  - An empty list
  - An empty tuple
  - An empty map

  ## Parameters
  - `data`: The data to be checked.

  ## Returns
  - `true` if the data is blank.
  - `false` otherwise.

  ## Examples
      iex> Arca.Cli.Utils.is_blank?(nil)
      true

      iex> Arca.Cli.Utils.is_blank?("")
      true

      iex> Arca.Cli.Utils.is_blank?(["not blank"])
      false
  """
  @spec is_blank?(term()) :: boolean()
  def is_blank?(data) when is_binary(data), do: String.trim(data) == ""
  def is_blank?(list) when is_list(list), do: list == []
  def is_blank?(tuple) when is_tuple(tuple), do: tuple == {}
  def is_blank?(map) when is_map(map), do: map == %{}
  def is_blank?(nil), do: true
  def is_blank?(_), do: false

  @doc """
  Removes blank lines from the end of a list or string.

  Uses pattern matching for specialized handling of different data types,
  with clear function heads for each type.

  ## Parameters
  - `lines`: The list, tuple, string, map, atom, or other data type to be filtered.

  ## Returns
  - The filtered list, tuple, or string.
  - For other data types, returns the original value.

  ## Examples
      iex> Arca.Cli.Utils.filter_blank_lines(["Line 1", "Line 2", "", ""])
      ["Line 1", "Line 2"]

      iex> Arca.Cli.Utils.filter_blank_lines("Line 1\\nLine 2\\n\\n")
      "Line 1\\nLine 2\\n"

      iex> Arca.Cli.Utils.filter_blank_lines(123)
      123
  """
  @spec filter_blank_lines(term()) :: term()
  def filter_blank_lines(lines) when is_list(lines) do
    lines |> Enum.reverse() |> Enum.drop_while(&is_blank?/1) |> Enum.reverse()
  end

  def filter_blank_lines(lines) when is_tuple(lines) do
    lines |> Tuple.to_list() |> filter_blank_lines() |> List.to_tuple()
  end

  def filter_blank_lines(string) when is_binary(string) do
    filter_trailing_newlines(string)
  end

  # Pass-through for simple types
  def filter_blank_lines(map) when is_map(map), do: map
  def filter_blank_lines(atom) when is_atom(atom), do: atom
  def filter_blank_lines(number) when is_number(number), do: number
  def filter_blank_lines(other), do: other

  @doc """
  Helper function to recursively filter trailing newlines from a string.

  ## Parameters
  - `string`: The string to process

  ## Returns
  - String with trailing newlines removed
  """
  @spec filter_trailing_newlines(String.t()) :: String.t()
  def filter_trailing_newlines(string) do
    newstr = String.replace(string, ~r/\n\n$/, "\n")

    if newstr == string do
      newstr
    else
      filter_trailing_newlines(newstr)
    end
  end

  @doc """
  Measures the execution time of a given function and returns 
  a tuple with the duration in seconds and the function's result.

  Uses Railway-Oriented Programming with try/rescue for proper error handling.

  ## Parameters
  - `func`: Function to execute and time

  ## Returns
  - `{duration, result}` with execution time and function result
  - For errors, returns `{0, :error}` or re-raises appropriate exceptions

  ## Examples
      iex> {duration, result} = timer(fn -> :timer.sleep(1000); "Done" end)
      iex> is_integer(duration) and duration >= 1
      true
      iex> result
      "Done"
  """
  @spec timer(function()) :: {non_neg_integer(), term()}
  def timer(func) do
    start_time = DateTime.utc_now()

    # Use try/rescue to ensure we properly handle any interruptions
    try do
      result = func.()
      end_time = DateTime.utc_now()
      duration = DateTime.diff(end_time, start_time)
      {duration, result}
    rescue
      e in [ErlangError] ->
        handle_erlang_error(e)

      e ->
        # For all other errors, re-raise them
        reraise e, __STACKTRACE__
    after
      # Ensure we clean up any resources, like file handles
      :ok
    end
  end

  @doc """
  Handles specific Erlang errors gracefully.

  ## Parameters
  - `error`: The ErlangError to handle

  ## Returns
  - `{0, :error}` for known error types that should be handled gracefully
  - Re-raises the error for unknown error types
  """
  @spec handle_erlang_error(ErlangError.t()) :: {0, :error}
  def handle_erlang_error(%ErlangError{original: reason}) do
    case reason do
      # Invalid argument
      :einval ->
        {0, :error}

      # Bad file descriptor
      :ebadf ->
        {0, :error}

      # Broken pipe
      :epipe ->
        {0, :error}

      _ ->
        # Since __STACKTRACE__ is only available in rescue/catch blocks,
        # we need to re-throw and then re-raise to get the proper stacktrace
        try do
          # Raise the error again
          raise %ErlangError{original: reason}
        rescue
          e ->
            reraise e, __STACKTRACE__
        end
    end
  end

  @doc """
  Returns the current function's fully-qualified name as a string with 
  an optional parameter appended to the end.

  ## Parameters
  - `optional_param`: Optional parameter to append to the function name

  ## Returns
  - String with function name and optional parameter

  ## Examples
      iex> defmodule MyModule1 do
      ...>   def my_function do
      ...>     this_fn_as_string()
      ...>   end
      ...> end
      iex> MyModule1.my_function()
      "Arca.Cli.Utils.Test.MyModule1.my_function/0"

      iex> defmodule MyModule2 do
      ...>   def my_function_with_param do
      ...>     this_fn_as_string("additional_info")
      ...>   end
      ...> end
      iex> MyModule2.my_function_with_param()
      "Arca.Cli.Utils.Test.MyModule2.my_function_with_param/0: additional_info"
  """
  defmacro this_fn_as_string(optional_param \\ nil) do
    quote do
      function_info = __ENV__.function
      function_name = elem(function_info, 0)
      function_arity = elem(function_info, 1)
      module_name = __MODULE__ |> Atom.to_string() |> String.replace("Elixir.", "")
      base_info = "#{module_name}.#{function_name}/#{function_arity}"

      case unquote(optional_param) do
        nil -> base_info
        param -> "#{base_info}: #{param}"
      end
    end
  end

  @doc """
  Logs a warning that the current function is not implemented.

  ## Parameters
  - `optional_msg`: Optional message to include in the warning

  ## Returns
  - `:ok`
  """
  defmacro this_function_is_not_implemented(optional_msg \\ nil) do
    quote do
      function_info = __ENV__.function
      function_name = elem(function_info, 0)
      function_arity = elem(function_info, 1)
      opt_msg = if unquote(optional_msg), do: ": #{unquote(optional_msg)}", else: ""

      Logger.warning(
        "#{__MODULE__} has not implemented #{function_name}/#{function_arity}#{opt_msg}"
      )
    end
  end
end
