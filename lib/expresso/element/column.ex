defmodule Expresso.Element.Column do
  @moduledoc """
  One column of a `columns` element

  A column holds the same elements as a text box. The `width` option gives the
  width of the column as a CSS length or percentage, and a column without the
  option takes an equal part of the free space. `Expresso.Element.Columns`
  gives the rules.
  """

  use Expresso.Element

  @typedoc "The struct of a column"
  @type t :: %__MODULE__{}

  defstruct [:width, :at, :steps, :el, :effect, on: [], elements: [], __spark_metadata__: nil]

  @doc """
  Make a column from elements, with an optional width
  """
  @spec new(list(), String.t() | nil) :: t()
  def new(elements, width \\ nil) do
    %__MODULE__{elements: elements, width: width}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`, and the `style` attribute of the
  `width` option. The style sets the custom properties `--column-width` and
  `--column-grow`, and the theme reads them.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(column) do
    %__MODULE__{elements: elements, width: width} = column

    %{
      elements: elements,
      overlay: Expresso.Overlay.Render.attributes(column) ++ width(width)
    }
  end

  defp width(nil), do: []
  defp width(width), do: [{"style", "--column-width: #{width}; --column-grow: 0"}]

  @doc """
  Make the HTML of a column
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "column", rest!: @overlay do
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
