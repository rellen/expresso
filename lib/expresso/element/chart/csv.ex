defmodule Expresso.Element.Chart.Csv do
  @moduledoc """
  The reader of the CSV file of a chart

  A delimiter, a comma by default, divides the cells of a row. A cell in
  double quotes can hold the delimiter, a line break and a quote, which two
  quotes give. The first row holds the headings, and each other row holds a
  category and one number for each series. `table/3` reads a file without
  frames. `frames/4` reads a file with a column that names the frame of each
  row. Each function returns the text of an error for a file that it cannot
  read, and `Expresso.Element.Chart` gives that error to the author.

  For a treemap or a sunburst, the `levels` option can name the columns that
  hold the levels of a category, from the top level down. The category of a
  row is then the list of its levels, and an empty cell at the end of the
  list ends the category at a higher level.
  """

  alias Expresso.Element.{Frame, Series}

  # A number with a comma between each group of three digits, such as
  # 1,250 or 12,500.5. A spreadsheet writes it in quotes.
  @grouped ~r/\A[+-]?\d{1,3}(,\d{3})+(\.\d+)?\z/

  @typedoc """
  The options of a reader: `levels`, the headings of the columns that hold
  the levels of a category, and `delimiter`, the character between two cells.
  """
  @type opts :: [levels: [String.t()] | nil, delimiter: String.t()]

  @doc """
  Read a CSV file of categories and series

  The first row holds a heading for the categories, then the name of each
  series. Each other row holds a category, then one number for each series.

      iex> Expresso.Element.Chart.Csv.table("year,Orders\\n2024,180\\n2025,240\\n", "a.csv")
      {:ok, ["2024", "2025"], [%Expresso.Element.Series{name: "Orders", values: [180, 240]}]}

  A cell in quotes can hold the delimiter, and a number in quotes can have a
  comma between each group of three digits:

      iex> text = ~s(Plant,Orders\\n"Leeds, Line 4","1,250"\\n)
      iex> Expresso.Element.Chart.Csv.table(text, "a.csv")
      {:ok, ["Leeds, Line 4"], [%Expresso.Element.Series{name: "Orders", values: [1250]}]}
  """
  @spec table(String.t(), String.t(), opts()) ::
          {:ok, [String.t() | [String.t()]], [Series.t()]} | {:error, String.t()}
  def table(text, src, opts \\ []) do
    with {:ok, rows} <- rows(text, src, opts),
         {:ok, rows} <- levels(rows, opts[:levels], src),
         [{_number, [_heading | names]} | data] when names != [] and data != [] <- rows,
         {:ok, columns} <- columns(data, length(names), src) do
      categories = Enum.map(data, fn {_number, [category | _values]} -> category end)
      {:ok, categories, series(names, columns)}
    else
      {:error, message} -> {:error, message}
      _rows -> {:error, "the chart file \"#{src}\" needs a row of names and a row of values"}
    end
  end

  @doc """
  Return the heading of the column of the categories, or `nil`

  The heading is the first cell of the first row. In a file with a column of
  frames, it is the first cell of the other columns. A file with levels joins
  the headings of its levels. An empty heading, or a file that the other
  functions refuse, returns `nil`.

      iex> Expresso.Element.Chart.Csv.heading("Year,Orders\\n2024,1\\n", "a.csv")
      "Year"
      iex> Expresso.Element.Chart.Csv.heading("year,region,Orders\\n2024,North,1\\n", "a.csv", [], "year")
      "region"
      iex> Expresso.Element.Chart.Csv.heading(",Orders\\n2024,1\\n", "a.csv")
      nil
  """
  @spec heading(String.t(), String.t(), opts(), String.t() | nil) :: String.t() | nil
  def heading(text, src, opts \\ [], frames \\ nil) do
    with {:ok, rows} <- rows(text, src, opts),
         {:ok, [{_number, cells} | _data]} <- levels(rows, opts[:levels], src),
         [first | _rest] <- if(frames, do: List.delete(cells, frames), else: cells),
         true <- is_binary(first) and String.trim(first) != "" do
      String.trim(first)
    else
      _no_heading -> nil
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
  @spec frames(String.t(), String.t(), String.t(), opts()) ::
          {:ok, [String.t() | [String.t()]], [Frame.t()]} | {:error, String.t()}
  def frames(text, column, src, opts \\ []) do
    with {:ok, rows} <- rows(text, src, opts),
         {:ok, rows} <- levels(rows, opts[:levels], src),
         [{_number, heading} | data] when data != [] <- rows,
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

  @doc """
  Join the columns of the levels of each row into one category

  The category is the first cell of the row, and the other cells keep their
  order. Without levels, the function returns the rows as they are.

      iex> rows = [{1, ["Division", "Team", "Hours"]}, {2, ["Production", "Press", "62"]}, {3, ["Office", "", "20"]}]
      iex> Expresso.Element.Chart.Csv.levels(rows, ["Division", "Team"], "a.csv")
      {:ok, [{1, ["Division/Team", "Hours"]}, {2, [["Production", "Press"], "62"]}, {3, [["Office"], "20"]}]}
  """
  @spec levels([{pos_integer(), [String.t()]}], [String.t()] | nil, String.t()) ::
          {:ok, [{pos_integer(), [term()]}]} | {:error, String.t()}
  def levels(rows, nil, _src), do: {:ok, rows}
  def levels([], _levels, _src), do: {:ok, []}

  def levels([{number, heading} | data], levels, src) do
    case Enum.find(levels, &(&1 not in heading)) do
      nil ->
        indices = Enum.map(levels, &index(heading, &1))
        rest = &others(&1, indices)

        with {:ok, rows} <- join_levels(data, indices, rest, src),
             do: {:ok, [{number, [Enum.join(levels, "/") | rest.(heading)]} | rows]}

      level ->
        {:error, "the chart file \"#{src}\" has no column \"#{level}\" for the levels"}
    end
  end

  defp index(heading, level), do: Enum.find_index(heading, &(&1 == level))

  # The cells of a row that are not levels, in their order.
  defp others(cells, indices),
    do: for({cell, i} <- Enum.with_index(cells), i not in indices, do: cell)

  defp join_levels(data, indices, rest, src) do
    data
    |> Enum.reduce_while({:ok, []}, fn {line, cells}, {:ok, rows} ->
      case path(Enum.map(indices, &(Enum.at(cells, &1) || ""))) do
        {:ok, path} ->
          {:cont, {:ok, [{line, [path | rest.(cells)]} | rows]}}

        :error ->
          {:halt,
           {:error,
            "line #{line} of the chart file \"#{src}\" has an empty level before a level with a name"}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  # The names of the levels of a row, with no empty name at the end. An empty
  # name before a name, or no name at all, is an error.
  defp path(cells) do
    path = cells |> Enum.reverse() |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()
    if path == [] or "" in path, do: :error, else: {:ok, path}
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

  @doc """
  Divide the text of a chart file into rows of cells

  Each row has the number of its first line. The function trims the spaces
  around a cell without quotes, and it keeps the text in quotes as it is. It
  skips a line with only white space. It removes a byte order mark at the
  start of the text, as the format "CSV UTF-8" of a spreadsheet writes it, so
  the first cell keeps its name.

      iex> Expresso.Element.Chart.Csv.rows("\\uFEFFyear,Orders\\n2024,3\\n", "a.csv")
      {:ok, [{1, ["year", "Orders"]}, {2, ["2024", "3"]}]}

      iex> Expresso.Element.Chart.Csv.rows("a; b\\n\\n\\"x\\"\\"y\\";\\"1\\n2\\"\\n", "a.csv", delimiter: ";")
      {:ok, [{1, ["a", "b"]}, {3, [~s(x"y), "1\\n2"]}]}
  """
  @spec rows(String.t(), String.t(), opts()) ::
          {:ok, [{pos_integer(), [String.t()]}]} | {:error, String.t()}
  def rows(text, src, opts \\ []) do
    delimiter = Keyword.get(opts, :delimiter, ",")

    case read_rows(without_mark(text), delimiter, 1, []) do
      {:ok, rows} -> {:ok, rows}
      {:error, line, problem} -> {:error, "line #{line} of the chart file \"#{src}\" #{problem}"}
    end
  end

  # U+FEFF at the start of a file is a byte order mark, and not a character
  # of the first cell. `String.trim/1` does not remove it.
  defp without_mark("\uFEFF" <> text), do: text
  defp without_mark(text), do: text

  defp read_rows("", _delimiter, _line, rows), do: {:ok, Enum.reverse(rows)}

  defp read_rows(text, delimiter, line, rows) do
    case blank(text) do
      {:blank, rest} ->
        read_rows(rest, delimiter, line + 1, rows)

      :row ->
        case read_cells(text, delimiter, line, line, []) do
          {:ok, cells, rest, next} -> read_rows(rest, delimiter, next, [{line, cells} | rows])
          error -> error
        end
    end
  end

  # A line with only spaces and tabs, and the text after it.
  defp blank(text) do
    case Regex.run(~r/\A[ \t]*(?:\r?\n|\z)/, text) do
      [match] -> {:blank, binary_part(text, byte_size(match), byte_size(text) - byte_size(match))}
      nil -> :row
    end
  end

  # The cells of one row, the text after the row and the number of the next
  # line. `line` is the line of the current cell, which a cell in quotes with
  # a line break moves on.
  defp read_cells(text, delimiter, start, line, cells) do
    case read_cell(skip_spaces(text, delimiter), delimiter, line) do
      {:ok, cell, rest, line} ->
        cells = [cell | cells]

        case next(rest, delimiter) do
          {:cell, rest} -> read_cells(rest, delimiter, start, line, cells)
          {:end, rest} -> {:ok, Enum.reverse(cells), rest, line + 1}
          :other -> {:error, line, "has text after the closing quote of a cell"}
        end

      {:error, :quote} ->
        {:error, start, "has a quote with no closing quote"}
    end
  end

  defp read_cell(<<?", rest::binary>>, delimiter, line), do: quoted(rest, delimiter, line, [])

  defp read_cell(text, delimiter, line) do
    {cell, rest} = plain(text, delimiter, [])
    {:ok, String.trim(cell), rest, line}
  end

  # The text of a cell in quotes. Two quotes give one quote.
  defp quoted(<<?", ?", rest::binary>>, delimiter, line, acc),
    do: quoted(rest, delimiter, line, [?" | acc])

  defp quoted(<<?", rest::binary>>, delimiter, line, acc),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary(), skip_spaces(rest, delimiter), line}

  defp quoted(<<?\r, ?\n, rest::binary>>, delimiter, line, acc),
    do: quoted(rest, delimiter, line + 1, [?\n | acc])

  defp quoted(<<?\n, rest::binary>>, delimiter, line, acc),
    do: quoted(rest, delimiter, line + 1, [?\n | acc])

  defp quoted(<<char::utf8, rest::binary>>, delimiter, line, acc),
    do: quoted(rest, delimiter, line, [<<char::utf8>> | acc])

  defp quoted(_text, _delimiter, _line, _acc), do: {:error, :quote}

  # The text of a cell without quotes, to the delimiter or the end of the line.
  defp plain("", _delimiter, acc), do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

  defp plain(<<char::utf8, rest::binary>> = text, delimiter, acc) do
    if String.starts_with?(text, delimiter) or char in [?\r, ?\n],
      do: {acc |> Enum.reverse() |> IO.iodata_to_binary(), text},
      else: plain(rest, delimiter, [<<char::utf8>> | acc])
  end

  defp next("", _delimiter), do: {:end, ""}
  defp next(<<?\r, ?\n, rest::binary>>, _delimiter), do: {:end, rest}
  defp next(<<?\n, rest::binary>>, _delimiter), do: {:end, rest}
  defp next(<<?\r, rest::binary>>, _delimiter), do: {:end, rest}

  defp next(text, delimiter) do
    if String.starts_with?(text, delimiter),
      do:
        {:cell, binary_part(text, byte_size(delimiter), byte_size(text) - byte_size(delimiter))},
      else: :other
  end

  # The spaces before a cell or after a closing quote. A space or a tab that
  # is the delimiter is not one of them.
  defp skip_spaces(<<?\s, rest::binary>>, delimiter) when delimiter != " ",
    do: skip_spaces(rest, delimiter)

  defp skip_spaces(<<?\t, rest::binary>>, delimiter) when delimiter != "\t",
    do: skip_spaces(rest, delimiter)

  defp skip_spaces(text, _delimiter), do: text

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
    text = String.trim(text)
    text = if text =~ @grouped, do: String.replace(text, ",", ""), else: text

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
