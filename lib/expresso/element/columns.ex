defmodule Expresso.Element.Columns do
  @moduledoc """
  An element that puts its columns side by side

  A `columns` element holds `column` entities, and a column holds the same
  elements as a text box. The theme makes the element a flex row. A column
  without a `width` option takes an equal part of the free space, and a column
  with the option takes that width. Each column takes the `at` option and the
  `on` entity, so a column can show at a step.

  A column cannot hold a `columns` element, because Spark cannot nest two
  entities inside each other without a limit.
  """

  use Expresso.Element

  @typedoc "The struct of a columns element"
  @type t :: %__MODULE__{}

  defstruct [
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
  Make a columns element from columns
  """
  @spec new([Expresso.Element.Column.t()]) :: t()
  def new(columns), do: %__MODULE__{elements: columns}

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(columns) do
    %__MODULE__{elements: elements} = columns
    %{elements: elements, overlay: Expresso.Overlay.Render.attributes(columns)}
  end

  @doc """
  Make the HTML of a columns element
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "columns", rest!: @overlay do
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
