defmodule Expresso.Element.TextArea do
  @moduledoc """
  An element that can have text
  """

  use Expresso.Element

  @typedoc "The struct of a text area"
  @type t :: %__MODULE__{}

  defstruct [
              :class,
              :text,
              :goto,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `goto` holds the link of the
  `goto` option, or `nil`. The key `text` holds the text with the ids and the
  style rules of this copy in each inline SVG, from
  `Expresso.SvgCopy.copy_each/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(text_area) do
    %__MODULE__{text: text, goto: goto} = text_area

    %{
      text: Expresso.SvgCopy.copy_each(text),
      goto: goto,
      overlay: Expresso.Overlay.Render.attributes(text_area)
    }
  end

  @doc """
  Make the HTML of a text area

  The text goes into one block element inside the root tag. The theme makes
  the root tag a flex container. Each element of the text is then a flex item,
  and the text breaks into more than one line. One block element keeps the
  text in one flex item, and each inline element of the text stays on one line.

  With the `goto` option, the block element goes into a link. The text must
  then hold no link, because HTML does not permit a link inside a link.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("text-area", assigns[:class]), rest!: @overlay do
        if @goto do
          a class: "goto", href: Expresso.Goto.href(@goto), data_link: @goto.index do
            div do
              Phoenix.HTML.raw(@text)
            end
          end
        else
          div do
            Phoenix.HTML.raw(@text)
          end
        end
      end
    end
  end
end
