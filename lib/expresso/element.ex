defmodule Expresso.Element do
  @moduledoc """
  An element of a slide

  `use Expresso.Element` imports Temple for the render function of the
  element. The module also holds the functions of the `class` option, which
  each element and each slide takes.
  """

  defmacro __using__(_opts) do
    quote do
      import Temple
      use Temple.Component
    end
  end

  # A CSS class name: a letter, an underscore or a hyphen and a letter at the
  # start, then letters, digits, underscores and hyphens.
  @class_name ~r/\A-?[_a-zA-Z][_a-zA-Z0-9-]*\z/

  @class_error "a class option takes CSS class names with a space between them, such as \"dense wide\""

  @doc """
  Make sure that a `class` option holds CSS class names

  This function is the custom type of the option. The value is one name or
  more, with one space or more between two names, such as `"dense wide"`.
  The function returns the names with one space between two names.

      iex> Expresso.Element.class("dense  wide")
      {:ok, "dense wide"}

      iex> {:error, _message} = Expresso.Element.class("2col")
  """
  @spec class(term()) :: {:ok, String.t()} | {:error, String.t()}
  def class(value) when is_binary(value) do
    case String.split(value) do
      [] ->
        {:error, @class_error}

      names ->
        if Enum.all?(names, &Regex.match?(@class_name, &1)),
          do: {:ok, Enum.join(names, " ")},
          else: {:error, @class_error}
    end
  end

  def class(_value), do: {:error, @class_error}

  @doc """
  Join the class of the theme and the classes of the `class` option

      iex> Expresso.Element.classes("code", "dense")
      "code dense"

      iex> Expresso.Element.classes("code", nil)
      "code"
  """
  @spec classes(String.t(), String.t() | nil) :: String.t()
  def classes(base, nil), do: base
  def classes(base, extra), do: base <> " " <> extra
end
