defmodule Expresso.Element.Chart.Scatter.Legend do
  @moduledoc """
  The legends of a scatter plot, in a column at the right of the plot

  A scatter plot has up to three legends, from the top:

  - The series, with the symbol and the color of each one.
  - The colors: each category of the color, with its color. When the symbol
    and the color of each point take the same category, the item also shows
    the symbol, and the chart has no legend of the symbols.
  - The symbols: each category of the symbol, with its symbol.
  - The sizes: three marks of round sizes, with their values.

  The options `color_label`, `symbol_label` and `size_label` give a title
  to each legend. `layout/1` makes the rows, `place/2` puts them at the
  right of the box of the plot, and `render/1` draws them.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Encoding, Plot, Scatter}

  # The height of a row of text, and the radius of a symbol of an item.
  @row 28
  @symbol 7

  # The width of the SVG, and the most width of the legends.
  @width 800
  @most 280

  @doc """
  Make the rows of the legends from the assigns of a scatter plot

  Each row has a `dy` from the top of the legends. An item of a category of
  the color has the key `category`, so it goes into the group of its
  category.
  """
  @spec layout(map()) :: %{rows: [map()], width: number()}
  def layout(assigns) do
    same = Scatter.same?(assigns)

    rows =
      [colors(assigns, same), symbols(assigns, same), sizes(assigns)]
      |> Enum.reject(&(&1 == []))
      |> Enum.intersperse([%{type: :gap, height: 12}])
      |> List.flatten()

    {rows, _dy} =
      Enum.map_reduce(rows, 0, fn row, dy -> {Map.put(row, :dy, dy), dy + row.height} end)

    %{rows: Enum.reject(rows, &(&1.type == :gap)), width: rows_width(rows)}
  end

  defp colors(%{series: [_ | _] = series} = assigns, _same) do
    items =
      for one <- series do
        %{
          type: :item,
          category: one.name,
          symbol: one.symbol,
          color: one.color,
          name: one.name,
          height: @row
        }
      end

    title(assigns.color_label) ++ items
  end

  defp colors(%{colors: []}, _same), do: []

  defp colors(assigns, same) do
    title = if same, do: assigns.color_label || assigns.symbol_label, else: assigns.color_label

    items =
      for category <- assigns.colors do
        symbol = if same, do: Encoding.symbol(category, assigns.symbols), else: :circle

        %{
          type: :item,
          category: category,
          symbol: symbol,
          color: Encoding.color(category, assigns.colors, nil),
          name: category,
          height: @row
        }
      end

    title(title) ++ items
  end

  defp symbols(%{symbols: []}, _same), do: []
  defp symbols(_assigns, true), do: []

  defp symbols(assigns, false) do
    items =
      for category <- assigns.symbols do
        %{
          type: :item,
          category: nil,
          symbol: Encoding.symbol(category, assigns.symbols),
          color: "var(--muted)",
          name: category,
          height: @row
        }
      end

    title(assigns.symbol_label) ++ items
  end

  defp sizes(%{most: nil}), do: []

  defp sizes(assigns) do
    items =
      for size <- Encoding.legend_sizes(assigns.most) do
        radius = Encoding.radius(size, assigns.most, assigns.largest)

        %{
          type: :size,
          category: nil,
          radius: radius,
          name: Plot.label(size),
          height: max(2 * radius + 8, @row)
        }
      end

    title(assigns.size_label) ++ items
  end

  defp title(nil), do: []
  defp title(text), do: [%{type: :title, category: nil, name: text, height: @row}]

  # The width of the widest row: a mark and its text, at approximately 11
  # units for each character. The largest mark of the sizes sets the place of
  # the text of each size.
  defp rows_width([]), do: 0

  defp rows_width(rows) do
    mark = rows |> Enum.map(&mark_width/1) |> Enum.max()

    rows
    |> Enum.reject(&(&1.type == :gap))
    |> Enum.map(fn
      %{type: :title, name: name} -> String.length(name) * 11
      %{name: name} -> mark + 10 + String.length(name) * 11
    end)
    |> Enum.max(fn -> 0 end)
    |> min(@most)
  end

  defp mark_width(%{type: :size, radius: radius}), do: 2 * radius
  defp mark_width(_row), do: 2 * @symbol + 2

  @doc """
  Return the width that the legends take at the right of the SVG, with a gap
  before them

      iex> Expresso.Element.Chart.Scatter.Legend.width(%{rows: [], width: 0})
      0
  """
  @spec width(%{rows: [map()], width: number()}) :: number()
  def width(%{rows: []}), do: 0
  def width(%{width: width}), do: width + 32

  @doc """
  Put the rows of the legends at the right of the SVG, from the top of the box
  of the plot
  """
  @spec place(%{rows: [map()], width: number()}, map()) :: map()
  def place(%{rows: rows, width: width} = legend, box) do
    x = @width - 16 - width
    mark = rows |> Enum.map(&mark_width/1) |> Enum.max(fn -> 0 end)
    Map.merge(legend, %{x: x, top: box.top, text_x: x + mark + 10})
  end

  @doc """
  Draw the rows of the legends with the category of the assigns

  The key `category` is `nil` for the rows outside the groups, or the name of
  a category of the color for its item.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    rows = Enum.filter(assigns.legend.rows, &(&1.category == assigns.category))
    assigns = Map.put(assigns, :rows, rows)

    temple do
      for row <- @rows do
        c(&row/1, row: row, legend: @legend)
      end
    end
  end

  defp row(%{row: %{type: :title}} = assigns) do
    temple do
      text x: @legend.x,
           y: Plot.f(@legend.top + @row.dy + 18),
           class: "chart-axis-title" do
        @row.name
      end
    end
  end

  defp row(%{row: %{type: :item}} = assigns) do
    assigns = Map.put(assigns, :size, @symbol)

    temple do
      path class: "chart-key",
           d: Encoding.path(@row.symbol),
           style: "--series: #{@row.color};",
           transform:
             "translate(#{Plot.f(@legend.text_x - 10 - @size)} " <>
               "#{Plot.f(@legend.top + @row.dy + 12)}) scale(#{@size})"

      text x: Plot.f(@legend.text_x),
           y: Plot.f(@legend.top + @row.dy + 18),
           class: "chart-name" do
        @row.name
      end
    end
  end

  defp row(%{row: %{type: :size}} = assigns) do
    temple do
      circle class: "chart-size",
             cx: Plot.f(@legend.text_x - 10 - @row.radius),
             cy: Plot.f(@legend.top + @row.dy + @row.height / 2),
             r: Plot.f(@row.radius)

      text x: Plot.f(@legend.text_x),
           y: Plot.f(@legend.top + @row.dy + @row.height / 2 + 6),
           class: "chart-name" do
        @row.name
      end
    end
  end
end
