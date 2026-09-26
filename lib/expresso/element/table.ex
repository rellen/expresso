defmodule Expresso.Element.Table do
  @moduledoc """
  An element that shows a table

  A table holds `row` entities, and a row holds a list of cells. The `header`
  option makes the first row the header of the table, and the renderer then
  puts it into a `thead` element with `th` cells.

  The `reveal` option shows the rows one after the other, one row at each
  step. The transformer gives `at [from: :next]` to each row that has no `at`
  option, as it does for the items of a list. With the `header` option, the
  header row keeps no specification, and it shows with the table.

  The `dim` option gives each row the state `dim` from the first step of a
  later row. The header row does not dim. `docs/overlays.md` gives the rules.
  """

  use Expresso.Element

  @typedoc "The struct of a table"
  @type t :: %__MODULE__{}

  defstruct [
    :at,
    :steps,
    :el,
    header: false,
    reveal: false,
    dim: false,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

  @doc """
  Make a table from rows

  The options are `header`, `reveal` and `dim`, and each takes a boolean.
  """
  @spec new([Expresso.Element.Row.t()], keyword()) :: t()
  def new(rows, opts \\ []) do
    %__MODULE__{
      elements: rows,
      header: Keyword.get(opts, :header, false),
      reveal: Keyword.get(opts, :reveal, false),
      dim: Keyword.get(opts, :dim, false)
    }
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `head` holds the header row,
  or `nil`, and the key `body` holds the other rows.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(table) do
    %__MODULE__{elements: rows, header: header} = table

    {head, body} =
      case {header, rows} do
        {true, [head | body]} -> {head, body}
        _ -> {nil, rows}
      end

    %{head: head, body: body, overlay: Expresso.Overlay.Render.attributes(table)}
  end

  @doc """
  Make the HTML of a table
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      table class: "table", rest!: @overlay do
        if @head do
          thead do
            c(&Expresso.Element.Row.render/1, rest!: header_assigns(@head))
          end
        end

        tbody do
          for row <- @body do
            c(&Expresso.Element.Row.render/1, rest!: Expresso.Element.Row.get_assigns(row))
          end
        end
      end
    end
  end

  defp header_assigns(row) do
    row |> Expresso.Element.Row.get_assigns() |> Map.put(:header, true)
  end
end
