defmodule Expresso.Element.Quotation do
  @moduledoc """
  An element that shows a quotation

  The `quotation` entity takes its text as its first argument, and the `by`
  option gives the name of the source. The entity is not named `quote`,
  because `Kernel.quote/2` has that name, and a call of the DSL would be
  ambiguous.
  """

  use Expresso.Element

  @typedoc "The struct of a quotation"
  @type t :: %__MODULE__{}

  defstruct [:text, :by, :at, :steps, :el, on: [], __spark_metadata__: nil]

  @doc """
  Make a quotation with text, and with the name of the source
  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(text, by \\ nil) do
    %__MODULE__{text: text, by: by}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(quotation) do
    %__MODULE__{text: text, by: by} = quotation
    %{text: text, by: by, overlay: Expresso.Overlay.Render.attributes(quotation)}
  end

  @doc """
  Make the HTML of a quotation

  The text goes into one block element inside a `blockquote` element, and the
  text can contain HTML. The name of the source goes into a `figcaption`
  element, and a quotation without a `by` option has no such element.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      figure class: "quotation", rest!: @overlay do
        blockquote do
          div do
            Phoenix.HTML.raw(@text)
          end
        end

        if @by do
          figcaption do
            @by
          end
        end
      end
    end
  end
end
