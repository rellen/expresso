defmodule Expresso.Element.Math do
  @moduledoc """
  An element that shows a formula in MathML

  The `math` entity takes the MathML as its first argument, from the `<math>`
  tag to the `</math>` tag. A browser renders MathML Core without a script and
  without a font file, and each browser of the floor of this project supports
  it. Give the `math` tag the attribute `display="block"` for a formula on its
  own line, which is the usual form on a slide.

  The text goes into the document as it is, as the text of a text area does.
  """

  use Expresso.Element

  @typedoc "The struct of a math element"
  @type t :: %__MODULE__{}

  defstruct [:text, :at, :steps, :el, on: [], __spark_metadata__: nil]

  @doc """
  Make a math element with MathML
  """
  @spec new(String.t()) :: t()
  def new(text), do: %__MODULE__{text: text}

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(math) do
    %__MODULE__{text: text} = math
    %{text: text, overlay: Expresso.Overlay.Render.attributes(math)}
  end

  @doc """
  Make the HTML of a math element

  The MathML goes into one block element inside the root tag.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "math", rest!: @overlay do
        div do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
