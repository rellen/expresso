defmodule Expresso.Element.Chart.Table do
  @moduledoc """
  The table of the values of a chart, for a screen reader

  The SVG of a chart has `role="img"` and the title, so a screen reader reads
  its name and not its values. Each chart therefore writes a table with the
  class `chart-table`, and the style sheet hides it from the eye and not from
  a screen reader.

  Each kind of chart returns its headers and its rows as data, and `render/1`
  writes the table. The first cell of each row is the header of the row.
  """

  import Temple
  import Expresso.Component

  alias Expresso.Element.Chart.Plot

  @doc """
  Return the caption of a table: the title of the chart, and the name of the
  values in parentheses

      iex> Expresso.Element.Chart.Table.caption("Orders", nil)
      "Orders"
      iex> Expresso.Element.Chart.Table.caption("Orders", "units")
      "Orders (units)"
  """
  @spec caption(String.t(), String.t() | nil) :: String.t()
  def caption(title, nil), do: title
  def caption(title, value_label), do: "#{title} (#{value_label})"

  @doc """
  Return the headers of the columns of values in a table of flows: the name
  of the values for a chart with one frame, else the label of each frame

      iex> Expresso.Element.Chart.Table.value_headers([%{label: nil}], nil)
      ["Value"]
      iex> Expresso.Element.Chart.Table.value_headers([%{label: "2015"}, %{label: "2025"}], "TWh")
      ["2015", "2025"]
  """
  @spec value_headers([%{label: String.t() | nil}], String.t() | nil) :: [String.t()]
  def value_headers([_one], value_label), do: [value_label || "Value"]
  def value_headers(frames, _value_label), do: Enum.map(frames, & &1.label)

  @doc """
  Return the value of a category in each frame, as text: the sum of its
  values in each series

      iex> frames = [%{values: [[2, 0], [1, 4]]}, %{values: [[5, 0], [0, 1]]}]
      iex> Expresso.Element.Chart.Table.values(frames, 0)
      ["3", "5"]
  """
  @spec values([%{values: [[number()]]}], non_neg_integer()) :: [String.t()]
  def values(frames, index) do
    for frame <- frames,
        do: frame.values |> Enum.map(&Enum.at(&1, index)) |> Enum.sum() |> Plot.label()
  end

  @doc """
  Write a table from its caption, its headers and its rows

  The assigns hold these keys:

  - `caption`: the text of the caption, from `caption/2`.
  - `headers`: the text of each header of a column. The first header can be
    `nil`. The corner then names nothing, so it is a cell: a header with no
    text has no name for a screen reader.
  - `rows`: the cells of each row, as text. The first cell is the header of
    the row.
  """
  @spec render(%{caption: String.t(), headers: [String.t() | nil], rows: [[String.t()]]}) ::
          Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      table class: "chart-table" do
        caption do
          @caption
        end

        thead do
          tr do
            for header <- @headers do
              c(&header/1, text: header)
            end
          end
        end

        tbody do
          for [first | cells] <- @rows do
            tr do
              th scope: "row" do
                first
              end

              for cell <- cells do
                td do
                  cell
                end
              end
            end
          end
        end
      end
    end
  end

  defp header(%{text: nil} = _assigns) do
    temple do
      td do
      end
    end
  end

  defp header(assigns) do
    temple do
      th scope: "col" do
        @text
      end
    end
  end
end
