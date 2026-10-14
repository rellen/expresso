defmodule Expresso.Element do
  @moduledoc """
  The behaviour of an element of a slide

  `use Expresso.Element` declares this behaviour, so the compiler gives a
  warning for an element module without `get_assigns/1` or `render/1`. It
  also imports Temple and `Expresso.Component` for the render function of the
  element. The module also holds the functions of the `class` option, which
  each element and each slide takes.
  """

  @doc """
  Make the assigns of the render function from the struct of an element

  The key `overlay` holds the attributes from
  `Expresso.Overlay.Render.attributes/1`. `assigns/1` adds the key `class`.
  """
  @callback get_assigns(element :: struct()) :: map()

  @doc """
  Make the HTML of an element from its assigns

  The root tag gets the attributes of `@overlay` with `rest!: @overlay`, and
  the classes of the element with `classes/2`.
  """
  @callback render(assigns :: map()) :: Phoenix.HTML.safe()

  defmacro __using__(_opts) do
    quote do
      import Temple
      import Expresso.Component

      @behaviour Expresso.Element
    end
  end

  @doc """
  Return the assigns of an element for its render function

  The function calls `get_assigns/1` of the module of the element, and it
  adds the `class` field of the element under the key `class`.
  """
  @spec assigns(struct()) :: map()
  def assigns(%module{} = element),
    do: element |> module.get_assigns() |> Map.put(:class, Map.get(element, :class))

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

  # A percentage of the slide, and not of the container of the element. The pattern
  # takes each form of a CSS number: a sign, a decimal part and an exponent are
  # each optional, and a number such as `.5` has no whole part.
  @percentage ~r/\A\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?)\s*%\s*\z/

  @doc """
  Write a width in percent as a viewport unit

  A value that is one number and a percent sign becomes the same number in
  `vw`, and each other value comes back as it is. A slide takes the full width
  of the screen and of the page, so a percentage of the slide is a viewport
  unit. `Expresso.Element.Image` gives the reasons.

      iex> Expresso.Element.viewport_unit("60%")
      "60vw"
      iex> Expresso.Element.viewport_unit(".5%")
      ".5vw"
      iex> Expresso.Element.viewport_unit("calc(50% + 10px)")
      "calc(50% + 10px)"
  """
  @spec viewport_unit(String.t()) :: String.t()
  def viewport_unit(width) do
    case Regex.run(@percentage, width, capture: :all_but_first) do
      [number] -> number <> "vw"
      nil -> width
    end
  end

  @doc """
  Return the style attribute of the box of an embed or of a video

  The box takes the `width` option and the `aspect` option. An element
  without both gets no attribute.

      iex> Expresso.Element.box_style("60%", "4/3")
      [{"style", "--embed-width: 60vw; --embed-aspect: 4/3"}]
      iex> Expresso.Element.box_style(nil, nil)
      []
  """
  @spec box_style(String.t() | nil, String.t() | nil) :: [{String.t(), String.t()}]
  def box_style(width, aspect) do
    case [
           width && "--embed-width: #{viewport_unit(width)}",
           aspect && "--embed-aspect: #{aspect}"
         ]
         |> Enum.reject(&is_nil/1) do
      [] -> []
      style -> [{"style", Enum.join(style, "; ")}]
    end
  end
end
