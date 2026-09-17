defmodule Expresso.Element.Image do
  @moduledoc """
  An element that shows an image

  The `src` option gives the path of the image file, and the path is relative
  to the working directory of the command. `Expresso.Image` reads the file at
  render time and makes a data URI, so the document of the deck stays one file.

  The `alt` option gives the text of the image for a screen reader. An image
  with no `alt` option is decorative, and the render function then writes an
  empty `alt` attribute.
  """

  use Expresso.Element

  @typedoc "The struct of an image"
  @type t :: %__MODULE__{}

  defstruct [:src, :alt, :at, :steps, :el, on: [], __spark_metadata__: nil]

  @doc """
  Make an image with a path and with text for a screen reader
  """
  @spec new(Path.t(), String.t() | nil) :: t()
  def new(src, alt \\ nil) do
    %__MODULE__{src: src, alt: alt}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `src` holds the data URI of
  the file, and `Expresso.Image.data_uri!/1` raises for a file that it cannot
  read.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(image) do
    %__MODULE__{src: src, alt: alt} = image

    %{
      src: Expresso.Image.data_uri!(src),
      alt: alt || "",
      overlay: Expresso.Overlay.Render.attributes(image)
    }
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
