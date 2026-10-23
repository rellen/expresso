defmodule Expresso.Element.Chart.Scatter.Data do
  @moduledoc """
  The points of a scatter plot from the rows of a CSV file

  The first row holds the headings, and each other row is one point. The
  options `label`, `x`, `y`, `symbol`, `color` and `size` of the chart name
  the column of each value, so a deck can show different columns of one
  file:

  | Option | The column | The default |
  | --- | --- | --- |
  | `label` | The name of the point | The first column |
  | `x` | The x value, a number | `"x"` |
  | `y` | The y value, a number | `"y"` |
  | `symbol` | A category of the symbol | No symbol |
  | `color` | A category of the color | No color |
  | `size` | The size, a number more than zero | No size |
  | `frames` | The label of the frame of the row | No frames |

  An empty cell of the symbol or of the color gives the point no category. A
  column of the color with a number in each cell that is not empty gives
  each point a color from a number, on the scale of the `color_scale`
  option.
  With `frames`, each row is a point in one frame, and the function returns
  each point with the label of its frame.
  """

  alias Expresso.Element.Chart.Csv
  alias Expresso.Element.Point

  @doc """
  Return the points of the rows of a CSV file

  `rows` are the rows of `Expresso.Element.Chart.Csv.rows/3`, with the
  headings first. `columns` holds the options of the chart that name the
  columns.

      iex> rows = [{1, ["service", "cost", "load"]}, {2, ["api", "1200", "840"]}]
      iex> {:ok, [point]} = Expresso.Element.Chart.Scatter.Data.points(rows, "a.csv", x: "cost", y: "load")
      iex> {point.name, point.x, point.y}
      {"api", 1200, 840}
  """
  @spec points([{pos_integer(), [String.t()]}], String.t(), keyword()) ::
          {:ok, [Point.t() | {String.t(), Point.t()}]} | {:error, String.t()}
  def points([{_line, headings} | data], src, columns) do
    headings = Enum.map(headings, &String.trim/1)

    named = [
      label: columns[:label] || List.first(headings),
      x: columns[:x] || "x",
      y: columns[:y] || "y",
      symbol: columns[:symbol],
      color: columns[:color],
      size: columns[:size],
      frames: columns[:frames]
    ]

    with {:ok, places} <- places(named, headings, src),
         {:ok, points} <- data |> Enum.map(&point(&1, places, src)) |> Shoddy.Result.collect() do
      {:ok, shades(points)}
    end
  end

  def points([], src, _columns), do: {:error, "the chart file \"#{src}\" has no rows"}

  # The index of the column of each value that the chart reads.
  defp places(named, headings, src) do
    Enum.reduce_while(named, {:ok, %{}}, fn
      {_key, nil}, ok ->
        {:cont, ok}

      {key, heading}, {:ok, places} ->
        case Enum.find_index(headings, &(&1 == heading)) do
          nil ->
            {:halt,
             {:error,
              "the chart file \"#{src}\" has no column \"#{heading}\" for the #{key} option. " <>
                "The columns are #{Enum.map_join(headings, ", ", &inspect/1)}."}}

          index ->
            {:cont, {:ok, Map.put(places, key, index)}}
        end
    end)
  end

  defp point({line, cells}, places, src) do
    cell = fn key -> places[key] && cells |> Enum.at(places[key], "") |> String.trim() end

    with {:ok, x} <- number(cell.(:x), :x, line, src),
         {:ok, y} <- number(cell.(:y), :y, line, src),
         {:ok, size} <- size(cell.(:size), line, src) do
      point = %Point{
        name: cell.(:label),
        x: x,
        y: y,
        symbol: category(cell.(:symbol)),
        color: category(cell.(:color)),
        size: size
      }

      {:ok, if(places[:frames], do: {cell.(:frames), point}, else: point)}
    end
  end

  # A column of the color with a number in each cell that is not empty gives
  # each point a color from a number.
  defp shades(points) do
    colors = points |> Enum.map(&color_of/1) |> Enum.reject(&is_nil/1)

    if colors != [] and Enum.all?(colors, &(Csv.number(&1) != nil)),
      do: Enum.map(points, &shade/1),
      else: points
  end

  defp color_of({_frame, %Point{color: color}}), do: color
  defp color_of(%Point{color: color}), do: color

  defp shade({frame, point}), do: {frame, shade(point)}
  defp shade(%Point{color: nil} = point), do: point
  defp shade(%Point{color: color} = point), do: %Point{point | color: Csv.number(color)}

  defp number(text, key, line, src) do
    case Csv.number(text) do
      nil ->
        {:error,
         "line #{line} of the chart file \"#{src}\" has #{inspect(text)} as its #{key}, " <>
           "and the #{key} is a number"}

      number ->
        {:ok, number}
    end
  end

  defp size(nil, _line, _src), do: {:ok, nil}
  defp size(text, line, src), do: number(text, :size, line, src)

  defp category(nil), do: nil
  defp category(""), do: nil
  defp category(text), do: text
end
