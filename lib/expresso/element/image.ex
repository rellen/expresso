defmodule Expresso.Element.Image do
  @moduledoc """
  An element that shows an image

  The `src` option gives the path of the image file, and the path is relative
  to the working directory of the command. `Expresso.Image` reads the file at
  render time and makes a data URI, so the document of the deck stays one file.

  The `alt` option gives the text of the image for a screen reader. An image
  with no `alt` option is decorative, and the render function then writes an
  empty `alt` attribute.

  The `width` option gives the width of the image as a CSS width. The render
  function writes the value into the custom property `--image-width` on the
  root tag, and the theme reads that property. An image with no `width` option
  takes its natural size, and the theme makes it smaller for a slide that is
  too small.

  Use a length, such as `"900px"`, or a percentage, such as `"60%"`. A
  percentage is a part of the width of the slide.

  The render function writes a percentage as a viewport unit, so `"60%"`
  becomes `60vw`. CSS resolves a percentage against the container of the
  image, and that container takes the natural width of the image. Therefore a
  percentage in CSS makes an image smaller only, and `100%` changes nothing. A
  slide takes the full width of the screen and of the page, so a viewport unit
  gives the meaning that an author expects.

  The function changes a value that is one number and a percent sign only. The
  number takes each form that CSS permits, so `"60%"`, `"33.5%"`, `".5%"`,
  `"+60%"` and `"6e1%"` each become a viewport unit. A value such as
  `"calc(50% + 10px)"` holds a percentage inside a function, and it goes into
  the document as it is.
  """

  use Expresso.Element

  @typedoc "The struct of an image"
  @type t :: %__MODULE__{}

  defstruct [:src, :alt, :width, :at, :steps, :el, on: [], __spark_metadata__: nil]

  @doc """
  Make an image with a path, with text for a screen reader and with a width
  """
  @spec new(Path.t(), String.t() | nil, String.t() | nil) :: t()
  def new(src, alt \\ nil, width \\ nil) do
    %__MODULE__{src: src, alt: alt, width: width}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`, and the `style` attribute of the
  `width` option. The key `src` holds the data URI of the file, and
  `Expresso.Image.data_uri!/1` raises for a file that it cannot read.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(image) do
    %__MODULE__{src: src, alt: alt, width: width} = image

    %{
      src: Expresso.Image.data_uri!(src),
      alt: alt || "",
      overlay: Expresso.Overlay.Render.attributes(image) ++ width(width)
    }
  end

  # A custom property inherits, so the property goes on the root tag and the
  # `img` element reads it. An `on` entity can then also set the property.
  defp width(nil), do: []
  defp width(width), do: [{"style", "--image-width: #{viewport_unit(width)}"}]

  # A percentage of the slide, and not of the container of the image. The pattern
  # takes each form of a CSS number: a sign, a decimal part and an exponent are
  # each optional, and a number such as `.5` has no whole part.
  @percentage ~r/\A\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?)\s*%\s*\z/

  defp viewport_unit(width) do
    case Regex.run(@percentage, width, capture: :all_but_first) do
      [number] -> number <> "vw"
      nil -> width
    end
  end

  @doc """
  Make the HTML of an image
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "image", rest!: @overlay do
        img src: @src, alt: @alt
      end
    end
  end
end
