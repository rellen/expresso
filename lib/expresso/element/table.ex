defmodule Expresso.Element.Table do
  @moduledoc """
  An element that shows a table

  A table holds `row` entities, and a row holds a list of cells. The `header`
  option makes the first row the header of the table, and the renderer then
  puts it into a `thead` element with `th` cells. The `row_header` option
  makes the first cell of each other row the header of its row. The `caption`
  option gives the table a name, and `caption_hidden` hides the caption from
  the eye and not from a screen reader.

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
              :class,
              :caption,
              caption_hidden: false,
              header: false,
              row_header: false,
              reveal: false,
              dim: false,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Make sure that the options of a table agree

  This function is the transformer of the `table` entity. A hidden caption
  needs a caption.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{caption: nil, caption_hidden: true}),
    do: {:error, "the caption_hidden option of a table needs the caption option"}

  def check(%__MODULE__{} = table), do: {:ok, table}

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `head` holds the header row,
  or `nil`, and the key `body` holds the other rows.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(table) do
    %__MODULE__{elements: rows, header: header} = table

    {head, body} =
      case {header, rows} do
        {true, [head | body]} -> {head, body}
        _ -> {nil, rows}
      end

    %{
      head: head,
      body: body,
      caption: table.caption,
      caption_class:
        if(table.caption_hidden, do: "table-caption table-caption-hidden", else: "table-caption"),
      row_header: table.row_header,
      overlay: Expresso.Overlay.Render.attributes(table)
    }
  end

  @doc """
  Make the HTML of a table

  The caption is the first child of the table, as HTML asks.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      table class: Expresso.Element.classes("table", assigns[:class]), rest!: @overlay do
        if @caption do
          caption class: @caption_class do
            @caption
          end
        end

        if @head do
          thead do
            c(&Expresso.Element.Row.render/1, rest!: header_assigns(@head))
          end
        end

        tbody do
          for row <- @body do
            c(&Expresso.Element.Row.render/1, rest!: row_assigns(row, @row_header))
          end
        end
      end
    end
  end

  defp header_assigns(row), do: row |> row_assigns(false) |> Map.put(:header, true)

  defp row_assigns(row, row_header),
    do: row |> Expresso.Element.assigns() |> Map.put(:row_header, row_header)
end
