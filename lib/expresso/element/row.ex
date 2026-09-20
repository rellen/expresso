defmodule Expresso.Element.Row do
  @moduledoc """
  A row of a table

  The `row` entity takes its cells as its first argument, which is a list of
  strings. `Expresso.Element.Table` gives the rules of a table.
  """

  use Expresso.Element

  @typedoc "The struct of a row"
  @type t :: %__MODULE__{}

  defstruct [:at, :steps, :el, cells: [], on: [], __spark_metadata__: nil]

  @doc """
  Make a row from cells
  """
  @spec new([String.t()]) :: t()
  def new(cells) do
    %__MODULE__{cells: cells}
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `header` tells whether the
  row is the header of the table, and the table puts it in.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(row) do
    %__MODULE__{cells: cells} = row
    %{cells: cells, header: false, overlay: Expresso.Overlay.Render.attributes(row)}
  end

  @doc """
  Make the HTML of a row

  A header row holds `th` elements, and another row holds `td` elements. Each
  cell can contain HTML.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  # Each cell comes from the deck, as the text of a text area does, and the
  # author of the deck writes the HTML.
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    temple do
      tr class: "row", rest!: @overlay do
        for cell <- @cells do
          if @header do
            th do
              Phoenix.HTML.raw(cell)
            end
          else
            td do
              Phoenix.HTML.raw(cell)
            end
          end
        end
      end
    end
  end
end
