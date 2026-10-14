defmodule Expresso.Element.Columns do
  @moduledoc """
  An element that puts its columns side by side

  A `columns` element holds `column` entities, and a column holds the same
  elements as a text box. The theme makes the element a flex row. A column
  without a `width` option takes an equal part of the free space, and a column
  with the option takes that width. Each column takes the `at` option and the
  `on` entity, so a column can show at a step.

  A column holds the elements of a text box, a callout and a toc, and not a
  `columns` element or a text box. `docs/reference/placement.md` gives the
  rules.
  """

  use Expresso.Element

  @typedoc "The struct of a columns element"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :morph,
    :easing,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(columns) do
    %__MODULE__{elements: elements} = columns
    %{elements: elements, overlay: Expresso.Overlay.Render.attributes(columns)}
  end

  @doc """
  Make the HTML of a columns element
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("columns", assigns[:class]), rest!: @overlay do
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
