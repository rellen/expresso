defmodule Expresso.Element.TextArea do
  @moduledoc """
  An element that can have text
  """

  use Expresso.Element

  @typedoc "The struct of a text area"
  @type t :: %__MODULE__{}

  defstruct [:text, :at, :steps, :el, :effect, :speed, :easing, on: [], __spark_metadata__: nil]

  @doc """
  Make a text area with text
  """
  @spec new(String.t()) :: t()
  def new(text) do
    %__MODULE__{text: text}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(text_area) do
    %__MODULE__{text: text} = text_area
    %{text: text, overlay: Expresso.Overlay.Render.attributes(text_area)}
  end

  @doc """
  Make the HTML of a text area

  The text goes into one block element inside the root tag. The theme makes
  the root tag a flex container. Each element of the text is then a flex item,
  and the text breaks into more than one line. One block element keeps the
  text in one flex item, and each inline element of the text stays on one line.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "text-area", rest!: @overlay do
        div do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
