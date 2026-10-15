defmodule Expresso.Element.Row do
  @moduledoc """
  A row of a table

  The `row` entity takes its cells as its first argument, which is a list of
  strings. `Expresso.Element.Table` gives the rules of a table.
  """

  use Expresso.Element

  @typedoc "The struct of a row"
  @type t :: %__MODULE__{}

  defstruct [
              :class,
              cells: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `header` tells whether the
  row is the header of the table, and the key `row_header` tells whether its
  first cell is the header of the row. The table puts both in.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(row) do
    %__MODULE__{cells: cells} = row

    %{
      cells: cells,
      header: false,
      row_header: false,
      overlay: Expresso.Overlay.Render.attributes(row)
    }
  end

  @doc """
  Make the HTML of a row

  Each cell of a header row is a `th` element with `scope="col"`. With
  `row_header`, the first cell of another row is a `th` element with
  `scope="row"`. Each other cell is a `td` element. A cell with no text names
  nothing, so it is a `td` element in each place. Each cell can contain HTML.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      tr class: Expresso.Element.classes("row", assigns[:class]), rest!: @overlay do
        for {text, index} <- Enum.with_index(@cells) do
          c(&cell/1, text: text, scope: scope(text, index, @header, @row_header))
        end
      end
    end
  end

  # The scope of a header cell, or nil for a data cell.
  defp scope(text, index, header, row_header) do
    cond do
      String.trim(text) == "" -> nil
      header -> "col"
      row_header and index == 0 -> "row"
      true -> nil
    end
  end

  # Each cell comes from the deck, as the text of a text area does, and the
  # author of the deck writes the HTML.
  # sobelow_skip ["XSS.Raw"]
  defp cell(%{scope: nil} = assigns) do
    temple do
      td do
        Phoenix.HTML.raw(@text)
      end
    end
  end

  # sobelow_skip ["XSS.Raw"]
  defp cell(assigns) do
    temple do
      th scope: @scope do
        Phoenix.HTML.raw(@text)
      end
    end
  end
end
