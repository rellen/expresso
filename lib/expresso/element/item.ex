defmodule Expresso.Element.Item do
  @moduledoc """
  An item of a list

  The `item` entity takes its text as its first argument, and it can hold one
  nested `list`. `Expresso.Element.List` gives the rules of a list.
  """

  use Expresso.Element

  @typedoc "The struct of an item"
  @type t :: %__MODULE__{}

  defstruct [
    :text,
    :goto,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Make an item with text, and with nested lists
  """
  @spec new(String.t(), list()) :: t()
  def new(text, elements \\ []) do
    %__MODULE__{text: text, elements: elements}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `goto` holds the link of the
  `goto` option, or `nil`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(item) do
    %__MODULE__{text: text, elements: elements, goto: goto} = item

    %{
      text: text,
      goto: goto,
      elements: elements,
      overlay: Expresso.Overlay.Render.attributes(item)
    }
  end

  @doc """
  Make the HTML of an item

  The text goes into one block element, as in `Expresso.Element.TextArea`, and
  each nested list comes after it. With the `goto` option, the text goes into
  a link, and a nested list stays outside the link.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      li class: "item", rest!: @overlay do
        if @goto do
          a class: "goto", href: Expresso.Goto.href(@goto), data_commands: @goto.commands do
            div do
              Phoenix.HTML.raw(@text)
            end
          end
        else
          div do
            Phoenix.HTML.raw(@text)
          end
        end

        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
