defmodule Expresso.Element.Shape do
  @moduledoc """
  An element that draws a rectangle, an ellipse, a line or an arrow over a slide

  The `shape` entity takes the kind as its first argument: `:rect`,
  `:ellipse`, `:line` or `:arrow`. A rectangle and an ellipse take `x`, `y`,
  `width` and `height`, and they can hold a short text. A line and an arrow
  take the points `from` and `to`. Each length is a CSS length, and a
  percentage is a part of the width or of the height of the slide. The point
  `["0%", "0%"]` is the top left corner of the slide.

  A shape shows nothing in the place where the deck writes it. The renderer
  puts the shapes of a slide into one layer over the whole slide, in the
  order of the deck, so a shape can point at each part of the slide.
  `of_slide/1` returns them. A shape takes the overlay options, so it can show
  at a step, move or get the state `alert`.

  The shape draws with `currentColor`, and the theme gives it the color
  `--shape-color`, which is `--accent` by default. `set: [color: ...]` of an
  `on` entity changes it, and the state `dim` dims it, as for text.
  """

  use Expresso.Element

  @typedoc "The struct of a shape"
  @type t :: %__MODULE__{}

  @kinds [:rect, :ellipse, :line, :arrow]

  defstruct [
    :class,
    :kind,
    :x,
    :y,
    :width,
    :height,
    :from,
    :to,
    :text,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    fill: false,
    on: [],
    __spark_metadata__: nil
  ]

  @doc """
  Return the kinds of a shape

      iex> Expresso.Element.Shape.kinds()
      [:rect, :ellipse, :line, :arrow]
  """
  @spec kinds() :: [atom()]
  def kinds, do: @kinds

  @doc """
  Make sure that a point is a list of two CSS lengths, such as `["10%", "40%"]`

  This function is the custom type of `from` and `to`.

      iex> Expresso.Element.Shape.point(["10%", "40%"])
      {:ok, ["10%", "40%"]}

      iex> {:error, _message} = Expresso.Element.Shape.point(["10%"])
  """
  @spec point(term()) :: {:ok, [String.t()]} | {:error, String.t()}
  def point([x, y]) when is_binary(x) and is_binary(y), do: {:ok, [x, y]}

  def point(_value),
    do: {:error, "a point is a list of two CSS lengths, such as [\"10%\", \"40%\"]"}

  @doc """
  Make sure that a shape has the options of its kind

  Spark calls this function after it builds the entity. A rectangle and an
  ellipse need `x`, `y`, `width` and `height`, and take no point. A line and
  an arrow need `from` and `to`, and take no box, no text and no fill.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{kind: kind} = shape) when kind in [:rect, :ellipse] do
    cond do
      missing = Enum.find([:x, :y, :width, :height], &is_nil(Map.get(shape, &1))) ->
        {:error, "a shape #{inspect(kind)} needs the option #{missing}"}

      shape.from || shape.to ->
        {:error, "a shape #{inspect(kind)} takes x, y, width and height, and not from and to"}

      true ->
        {:ok, shape}
    end
  end

  def check(%__MODULE__{kind: kind} = shape) do
    cond do
      is_nil(shape.from) or is_nil(shape.to) ->
        {:error, "a shape #{inspect(kind)} needs the options from and to"}

      Enum.any?([:x, :y, :width, :height, :text], &Map.get(shape, &1)) or shape.fill ->
        {:error,
         "a shape #{inspect(kind)} takes from and to, and not x, y, width, height, text or fill"}

      true ->
        {:ok, shape}
    end
  end

  @doc """
  Return the shapes of a slide, in the order of the deck

  A shape can be at the level of the slide or inside an element that holds
  elements, such as a text box.
  """
  @spec of_slide(map()) :: [t()]
  def of_slide(slide), do: collect(slide.elements || [])

  defp collect(elements) do
    Enum.flat_map(elements, fn
      %__MODULE__{} = shape -> [shape]
      %{elements: [_ | _] = children} -> collect(children)
      _element -> []
    end)
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, and, for a
  rectangle and an ellipse, the `style` attribute of the box. The key `marker`
  holds a new id for the head of an arrow. Each copy of a slide renders the
  shape again, so each copy gets its own id, as the copies of a diagram do.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(%__MODULE__{} = shape) do
    box =
      if shape.kind in [:rect, :ellipse],
        do: [
          {"style",
           "left: #{shape.x}; top: #{shape.y}; width: #{shape.width}; height: #{shape.height}"}
        ],
        else: []

    %{
      kind: shape.kind,
      from: shape.from,
      to: shape.to,
      text: shape.text,
      fill: shape.fill,
      marker: "shape-arrow-#{System.unique_integer([:positive])}",
      overlay: Expresso.Overlay.Render.attributes(shape) ++ box
    }
  end

  @doc """
  Make the HTML of a shape

  A rectangle and an ellipse are a `div` with a border, and their text goes
  into it. A line and an arrow are an `svg` over the whole slide, with a
  `line` from point to point, so a percentage keeps its meaning in each
  direction. `Expresso.Renderer` calls this function for each shape of the
  slide, in the layer of the shapes.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{kind: kind} = assigns) when kind in [:rect, :ellipse] do
    temple do
      div class: Expresso.Element.classes("shape shape-#{@kind}", assigns[:class]),
          data_fill: @fill,
          rest!: @overlay do
        if @text do
          div do
            @text
          end
        end
      end
    end
  end

  def render(assigns) do
    temple do
      svg class: Expresso.Element.classes("shape shape-line", assigns[:class]),
          aria_hidden: "true",
          rest!: @overlay do
        if @kind == :arrow do
          defs do
            marker id: @marker,
                   viewBox: "0 0 10 10",
                   refX: "8",
                   refY: "5",
                   markerWidth: "4",
                   markerHeight: "4",
                   orient: "auto-start-reverse" do
              path d: "M0 0L10 5L0 10z"
            end
          end
        end

        line x1: Enum.at(@from, 0),
             y1: Enum.at(@from, 1),
             x2: Enum.at(@to, 0),
             y2: Enum.at(@to, 1),
             marker_end: if(@kind == :arrow, do: "url(##{@marker})")
      end
    end
  end
end
