defmodule Expresso.Element.List do
  @moduledoc """
  An element that shows a list of items

  A list holds `item` entities, and an item holds text and one optional nested
  `list`. The DSL accepts three levels of lists. The `ordered` option gives a
  numbered list, and the default is a bulleted list.

  The `reveal` option shows the items one after the other, one item at each
  step. The transformer gives `at [from: :next]` to each item that has no `at`
  option, as the `auto_reveal` option of a slide does for its elements. A list
  with an absolute `at` option starts its items at its own first step, so no
  item gets a step at which the list does not show.

  The `dim` option gives each item the state `dim` from the first step of a
  later item, so the newest item has the attention. `docs/overlays.md` gives
  the rules.
  """

  use Expresso.Element

  @typedoc "The struct of a list"
  @type t :: %__MODULE__{}

  defstruct [
    :at,
    :steps,
    :el,
    :effect,
    ordered: false,
    reveal: false,
    dim: false,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Make a list from items

  The options are `ordered`, `reveal` and `dim`, and each takes a boolean.
  """
  @spec new([Expresso.Element.Item.t()], keyword()) :: t()
  def new(items, opts \\ []) do
    %__MODULE__{
      elements: items,
      ordered: Keyword.get(opts, :ordered, false),
      reveal: Keyword.get(opts, :reveal, false),
      dim: Keyword.get(opts, :dim, false)
    }
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(list) do
    %__MODULE__{elements: elements, ordered: ordered} = list
    %{elements: elements, ordered: ordered, overlay: Expresso.Overlay.Render.attributes(list)}
  end

  @doc """
  Make the HTML of a list

  An ordered list is an `ol` element, and the other list is a `ul` element.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      if @ordered do
        ol class: "list", rest!: @overlay do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      else
        ul class: "list", rest!: @overlay do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end
