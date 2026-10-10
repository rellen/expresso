defmodule Expresso.Element.Chart.Csv do
  @moduledoc """
  The reader of the CSV file of a chart

  A cell is the text between two commas, with no quotes. The first row holds
  the headings, and each other row holds a category and one number for each
  series. `table/2` reads a file without frames. `frames/3` reads a file with
  a column that names the frame of each row. Each function returns the text
  of an error for a file that it cannot read, and `Expresso.Element.Chart`
  gives that error to the author.
  """

  alias Expresso.Element.{Frame, Series}

  @doc """
  Read a CSV file of categories and series

  The first row holds a heading for the categories, then the name of each
  series. Each other row holds a category, then one number for each series.

      iex> Expresso.Element.Chart.Csv.table("year,Orders\\n2024,180\\n2025,240\\n", "a.csv")
      {:ok, ["2024", "2025"], [%Expresso.Element.Series{name: "Orders", values: [180, 240]}]}
  """
  @spec table(String.t(), String.t()) ::
          {:ok, [String.t()], [Series.t()]} | {:error, String.t()}
  def table(text, src) do
    with [{_number, [_heading | names]} | data] when names != [] and data != [] <- rows(text),
         {:ok, columns} <- columns(data, length(names), src) do
      categories = Enum.map(data, fn {_number, [category | _values]} -> category end)
      {:ok, categories, series(names, columns)}
    else
      {:error, message} -> {:error, message}
      _rows -> {:error, "the chart file \"#{src}\" needs a row of names and a row of values"}
    end
  end

  @doc """
  Read a CSV file with a column that names the frame of each row

  The column with the heading `column` names the frame. Of the other columns,
  the first holds the category, and each other column holds a series. The
  frames have the order of their first row, and each frame holds each
  category of the first frame one time, in any order. The function puts the
  categories of each frame into the order of the first frame.

      iex> text = "year,region,Orders\\n2024,North,1\\n2024,South,2\\n2025,South,4\\n2025,North,3\\n"
      iex> {:ok, categories, [_first, second]} = Expresso.Element.Chart.Csv.frames(text, "year", "a.csv")
      iex> {categories, second.label, hd(second.elements).values}
      {["North", "South"], "2025", [3, 4]}
  """
  @spec frames(String.t(), String.t(), String.t()) ::
          {:ok, [String.t()], [Frame.t()]} | {:error, String.t()}
  def frames(text, column, src) do
    with [{_number, heading} | data] when data != [] <- rows(text),
         {:ok, index} <- column(heading, column, src),
         [_category | names] when names != [] <- List.delete_at(heading, index),
         data = Enum.map(data, fn {number, cells} -> {number, cells, index} end),
         {:ok, groups} <- groups(data, src),
         {:ok, categories} <- categories(groups, src),
         {:ok, timeline} <- timeline(groups, categories, names, src) do
      {:ok, categories, timeline}
    else
      {:error, message} ->
        {:error, message}

      _rows ->
        {:error,
         "the chart file \"#{src}\" needs a row of names and a row of values, with a column " <>
           "for the frame, a column for the category and a column for each series"}
    end
  end

  defp column(heading, column, src) do
    case Enum.find_index(heading, &(&1 == column)) do
      nil -> {:error, "the chart file \"#{src}\" has no column \"#{column}\" for the frames"}
      index -> {:ok, index}
    end
  end

  # The rows of each frame, in the order of the first row of each frame. A
  # row with too few cells has no frame, and `columns/3` reports it later.
  defp groups(data, src) do
    groups =
      Enum.reduce(data, [], fn {number, cells, index}, groups ->
        label = Enum.at(cells, index)
        row = {number, List.delete_at(cells, index)}

        case List.keyfind(groups, label, 0) do
          nil -> groups ++ [{label, [row]}]
          {^label, rows} -> List.keyreplace(groups, label, 0, {label, rows ++ [row]})
        end
      end)

    cond do
      Enum.any?(groups, fn {label, _rows} -> label in [nil, ""] end) ->
        {:error, "a row of the chart file \"#{src}\" has no frame"}

      number = empty(groups) ->
        {:error, "line #{number} of the chart file \"#{src}\" has no category"}

      true ->
        {:ok, groups}
    end
  end

  defp empty(groups) do
    Enum.find_value(groups, fn {_label, rows} ->
      Enum.find_value(rows, fn {number, cells} -> cells == [] && number end)
    end)
  end

  # The categories of the first frame. Each other frame holds the same
  # categories, each one time.
  defp categories([{_label, rows} | _rest] = groups, src) do
    categories = names(rows)
    sorted = Enum.sort(categories)
    other = Enum.find(groups, fn {_label, rows} -> Enum.sort(names(rows)) != sorted end)

    cond do
      other != nil ->
        {label, _rows} = other

        {:error,
         "the frame \"#{label}\" of the chart file \"#{src}\" needs the categories of the " <>
           "first frame, each one time"}

      length(Enum.uniq(categories)) != length(categories) ->
        {:error, "a frame of the chart file \"#{src}\" holds a category two times"}

      true ->
        {:ok, categories}
    end
  end

  defp names(rows), do: Enum.map(rows, fn {_number, [category | _values]} -> category end)

  defp timeline(groups, categories, names, src) do
    groups
    |> Enum.reduce_while({:ok, []}, fn {label, rows}, {:ok, frames} ->
      ordered =
        Enum.sort_by(rows, fn {_number, [category | _values]} ->
          Enum.find_index(categories, &(&1 == category))
        end)

      case columns(ordered, length(names), src) do
        {:ok, columns} ->
          {:cont, {:ok, [%Frame{label: label, elements: series(names, columns)} | frames]}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, frames} -> {:ok, Enum.reverse(frames)}
      error -> error
    end
  end

  defp series(names, columns) do
    for {name, values} <- Enum.zip(names, columns), do: %Series{name: name, values: values}
  end

  defp rows(text) do
    text
    |> String.split(["\r\n", "\n"])
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _number} -> String.trim(line) == "" end)
    |> Enum.map(fn {line, number} ->
      {number, line |> String.split(",") |> Enum.map(&String.trim/1)}
    end)
  end

  defp columns(data, count, src) do
    data
    |> Enum.reduce_while({:ok, []}, fn {number, [_category | cells]}, {:ok, rows} ->
      case numbers(cells, count) do
        {:ok, values} ->
          {:cont, {:ok, [values | rows]}}

        :error ->
          {:halt, {:error, "line #{number} of the chart file \"#{src}\" needs #{count} numbers"}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, rows |> Enum.reverse() |> Enum.zip_with(& &1)}
      error -> error
    end
  end

  defp numbers(cells, count) when length(cells) == count do
    values = Enum.map(cells, &number/1)
    if Enum.all?(values, &is_number/1), do: {:ok, values}, else: :error
  end

  defp numbers(_cells, _count), do: :error

  defp number(text) do
    case Integer.parse(text) do
      {integer, ""} ->
        integer

      _other ->
        case Float.parse(text) do
          {float, ""} -> float
          _error -> nil
        end
    end
  end
end
