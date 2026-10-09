defmodule Expresso.Element.Chart do
  @moduledoc """
  An element that draws a bar chart, a line chart or a pie chart

  The `chart` entity takes the kind as its first argument: `:bar`, `:line` or
  `:pie`. The `categories` option gives the names of the categories, and each
  `series` entity gives a name and one value for each category. The `src`
  option gives a CSV file in place of the two: the first row holds the names
  of the series, and each other row holds a category and its values.

  The render function draws the chart as SVG in the document, so the chart
  needs no script and no file, and it prints. The colors of the series are
  `--chart-1` to `--chart-8` of the theme, in a fixed order. A chart with two
  or more series has a legend, a bar shows its value, the end of a line shows
  its name and its last value, and the legend of a pie shows each part in
  percent. A table with the values goes into the document for a screen
  reader.

  A series is a child of the chart, so `reveal true` shows each series at its
  own step, and `dim true` dims each series when a later series shows.
  `docs/reference/chart-element.md` gives the rules.
  """

  use Expresso.Element

  alias Expresso.Element.Chart.Plot
  alias Expresso.Element.Series

  @typedoc "The struct of a chart"
  @type t :: %__MODULE__{}

  @kinds [:bar, :line, :pie]

  # The colors of a palette for the series, so the most series of a chart.
  @colors 8

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  defstruct [
    :class,
    :kind,
    :title,
    :categories,
    :src,
    :width,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    values: true,
    reveal: false,
    dim: false,
    elements: [],
    on: [],
    __spark_metadata__: nil
  ]

  @doc """
  Return the kinds of a chart

      iex> Expresso.Element.Chart.kinds()
      [:bar, :line, :pie]
  """
  @spec kinds() :: [atom()]
  def kinds, do: @kinds

  @doc """
  Check the options of a chart

  The transform of the `chart` entity calls this function. A chart with `src`
  keeps its file until `Expresso.PathTransformer` runs, because the `root`
  option of the deck can change the path, and `build/1` then reads it.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{src: src} = chart) when is_binary(src) do
    if chart.categories != nil or chart.elements != [],
      do: {:error, "a chart takes the src option, or categories and series, and not both"},
      else: options(chart)
  end

  def check(%__MODULE__{} = chart), do: validate(chart)

  @doc """
  Read the CSV file of a chart with `src`, and make its categories and series

  The first row holds a heading for the categories, then the name of each
  series. Each other row holds a category, then one number for each series.
  A cell is the text between two commas, with no quotes. The function reads
  the file through `Expresso.DeckFile`, so the watch mode renders the deck
  again after a change to the file.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{src: src} = chart) when is_binary(src) do
    with {:ok, text} <- read(src),
         {:ok, categories, series} <- parse(text, src) do
      validate(%__MODULE__{chart | categories: categories, elements: series})
    end
  end

  def build(%__MODULE__{} = chart), do: {:ok, chart}

  defp read(src) do
    case Expresso.DeckFile.read(src) do
      {:ok, text} ->
        {:ok, text}

      {:error, reason} ->
        {:error,
         "cannot read the chart file \"#{src}\": #{:file.format_error(reason)}. A path is " <>
           "relative to the working directory of the command, or to the root option of the deck."}
    end
  end

  defp parse(text, src) do
    rows =
      text
      |> String.split(["\r\n", "\n"])
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _number} -> String.trim(line) == "" end)
      |> Enum.map(fn {line, number} ->
        {number, line |> String.split(",") |> Enum.map(&String.trim/1)}
      end)

    with [{_number, [_heading | names]} | data] when names != [] and data != [] <- rows,
         {:ok, columns} <- columns(data, length(names), src) do
      categories = Enum.map(data, fn {_number, [category | _values]} -> category end)

      series =
        for {name, values} <- Enum.zip(names, columns), do: %Series{name: name, values: values}

      {:ok, categories, series}
    else
      {:error, message} -> {:error, message}
      _rows -> {:error, "the chart file \"#{src}\" needs a row of names and a row of values"}
    end
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
    values = Enum.map(cells, &parse_number/1)
    if Enum.all?(values, &is_number/1), do: {:ok, values}, else: :error
  end

  defp numbers(_cells, _count), do: :error

  defp parse_number(text) do
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

  # The checks of a chart with its categories and its series.
  defp validate(%__MODULE__{} = chart) do
    with {:ok, chart} <- options(chart),
         :ok <- categories(chart),
         :ok <- series(chart),
         do: pie(chart)
  end

  defp options(%__MODULE__{kind: :pie, reveal: true}),
    do: {:error, "a pie has one series, so it takes no reveal option. Give it an at option."}

  defp options(chart), do: {:ok, chart}

  defp categories(%__MODULE__{categories: [_ | _] = categories}) do
    if Enum.all?(categories, &is_binary/1),
      do: :ok,
      else: {:error, "the categories of a chart are strings"}
  end

  defp categories(_chart), do: {:error, "a chart needs the categories option or the src option"}

  defp series(%__MODULE__{elements: [], kind: kind}),
    do: {:error, "a chart #{inspect(kind)} needs a series"}

  defp series(%__MODULE__{elements: elements}) when length(elements) > @colors,
    do:
      {:error,
       "a chart has at most #{@colors} series, one for each color. Put the smallest into a series \"Other\"."}

  defp series(%__MODULE__{elements: elements, categories: categories}) do
    count = length(categories)

    case Enum.find(elements, &(not values?(&1.values, count))) do
      nil ->
        :ok

      %Series{name: name} ->
        {:error, "the series \"#{name}\" needs #{count} numbers, one for each category"}
    end
  end

  defp values?(values, count),
    do: is_list(values) and length(values) == count and Enum.all?(values, &is_number/1)

  defp pie(
         %__MODULE__{kind: :pie, elements: [%Series{values: values}], categories: categories} =
           chart
       ) do
    cond do
      length(categories) > @colors ->
        {:error,
         "a pie has at most #{@colors} parts, one for each color. Put the smallest into a part \"Other\"."}

      Enum.any?(values, &(&1 < 0)) or Enum.sum(values) <= 0 ->
        {:error, "the values of a pie are zero or more, and their sum is more than zero"}

      true ->
        {:ok, chart}
    end
  end

  defp pie(%__MODULE__{kind: :pie}), do: {:error, "a pie has one series"}
  defp pie(chart), do: {:ok, chart}

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, and the
  `style` attribute of the `width` option. The key `series` holds each series
  with its color number and its overlay attributes.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(%__MODULE__{} = chart) do
    series =
      chart.elements
      |> Enum.with_index(1)
      |> Enum.map(fn {series, color} ->
        %{
          name: series.name,
          values: series.values,
          color: color,
          class: series.class,
          overlay: Expresso.Overlay.Render.attributes(series)
        }
      end)

    width =
      if chart.width,
        do: [{"style", "--chart-width: #{Expresso.Element.Image.viewport_unit(chart.width)}"}],
        else: []

    %{
      kind: chart.kind,
      title: chart.title,
      categories: chart.categories,
      series: series,
      values: chart.values,
      overlay: Expresso.Overlay.Render.attributes(chart) ++ width
    }
  end

  @doc """
  Make the HTML of a chart: a `figure` with the SVG and a table of the values

  The SVG has `role="img"` and the title as its name. The table has the class
  `chart-table`, and the style sheet hides it from the eye and not from a
  screen reader.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.put(assigns, :view_box, "0 0 #{@width} #{@height}")

    temple do
      figure class: Expresso.Element.classes("chart chart-#{@kind}", assigns[:class]),
             rest!: @overlay do
        svg viewBox: @view_box, role: "img", aria_label: @title do
          c(&plot/1, rest!: assigns)
        end

        c(&table/1, rest!: assigns)
      end
    end
  end

  defp table(assigns) do
    temple do
      table class: "chart-table" do
        caption do
          @title
        end

        thead do
          tr do
            th do
            end

            for series <- @series do
              th scope: "col" do
                series.name
              end
            end
          end
        end

        tbody do
          for {category, index} <- Enum.with_index(@categories) do
            tr do
              th scope: "row" do
                category
              end

              for series <- @series do
                td do
                  Plot.label(Enum.at(series.values, index))
                end
              end
            end
          end
        end
      end
    end
  end

  # The kinds of a chart. Each one writes the content of the SVG.
  defp plot(%{kind: :pie} = assigns), do: pie_plot(assigns)
  defp plot(assigns), do: axis_plot(assigns)

  # The box of the plot inside the SVG: the left edge holds the labels of the
  # axis, the top edge holds the legend, and the right edge of a line chart
  # holds the names at the ends of the lines.
  defp frame(assigns, ticks) do
    widest = ticks |> Enum.map(&String.length(Plot.label(&1))) |> Enum.max()
    left = 24 + widest * 10
    top = if length(assigns.series) > 1, do: 64, else: 28
    right = if assigns.kind == :line, do: @width - 150, else: @width - 16
    bottom = @height - 40
    %{left: left, top: top, right: right, bottom: bottom}
  end

  defp axis_plot(assigns) do
    values = Enum.flat_map(assigns.series, & &1.values)
    ticks = Plot.ticks(values)
    frame = frame(assigns, ticks)
    low = List.first(ticks)
    high = List.last(ticks)
    y = fn value -> frame.bottom - (value - low) / (high - low) * (frame.bottom - frame.top) end

    assigns =
      assigns
      |> Map.put(:ticks, ticks)
      |> Map.put(:frame, frame)
      |> Map.put(:y, y)
      |> Map.put(:legend, legend(assigns.series, frame.left))

    temple do
      g class: "chart-axis" do
        for tick <- @ticks do
          line class: if(tick == 0, do: "chart-base", else: "chart-grid"),
               x1: @frame.left,
               x2: @frame.right,
               y1: Plot.f(@y.(tick)),
               y2: Plot.f(@y.(tick))

          text x: @frame.left - 10,
               y: Plot.f(@y.(tick) + 5),
               text_anchor: "end",
               class: "chart-tick" do
            Plot.label(tick)
          end
        end

        for {category, index} <- Enum.with_index(@categories) do
          text x: Plot.f(category_x(assigns, index)),
               y: @frame.bottom + 28,
               text_anchor: "middle",
               class: "chart-category" do
            category
          end
        end
      end

      if @kind == :bar do
        c(&bars/1, rest!: assigns)
      else
        c(&lines/1, rest!: assigns)
      end
    end
  end

  # The center of a category on the axis. A bar chart gives each category a
  # band of the same width, and a line chart puts the first and the last
  # category on the edges of the plot.
  defp category_x(%{kind: :bar, frame: frame, categories: categories}, index) do
    band = (frame.right - frame.left) / length(categories)
    frame.left + band * (index + 0.5)
  end

  defp category_x(%{frame: frame, categories: [_one]}, _index),
    do: (frame.left + frame.right) / 2

  defp category_x(%{frame: frame, categories: categories}, index) do
    inset = 24
    frame.left + inset + (frame.right - frame.left - 2 * inset) * index / (length(categories) - 1)
  end

  defp bars(assigns) do
    band = (assigns.frame.right - assigns.frame.left) / length(assigns.categories)
    group = band * 0.7
    slot = group / length(assigns.series)
    assigns = Map.merge(assigns, %{band: band, slot: slot, group: group})

    temple do
      for series <- @series do
        g class: Expresso.Element.classes("chart-series chart-c#{series.color}", series.class),
          rest!: series.overlay do
          c(&legend_item/1, legend: @legend, series: series)

          for {value, index} <- Enum.with_index(series.values) do
            c(&bar/1, rest!: Map.merge(assigns, %{series: series, value: value, index: index}))
          end
        end
      end
    end
  end

  # One bar and its value. The bars of a category stand side by side, with a
  # gap of 2 units, in the order of the series.
  defp bar(assigns) do
    x =
      category_x(assigns, assigns.index) - assigns.group / 2 +
        (assigns.series.color - 1) * assigns.slot + 1

    width = max(assigns.slot - 2, 1)

    label_y =
      if assigns.value >= 0,
        do: assigns.y.(assigns.value) - 8,
        else: assigns.y.(assigns.value) + 20

    assigns = Map.merge(assigns, %{x: x, bar_width: width, label_y: label_y})

    temple do
      path class: "chart-bar", d: Plot.bar(@x, @bar_width, @y.(0), @y.(@value))

      if @values do
        text x: Plot.f(@x + @bar_width / 2),
             y: Plot.f(@label_y),
             text_anchor: "middle",
             class: "chart-value" do
          Plot.label(@value)
        end
      end
    end
  end

  defp lines(assigns) do
    ends =
      assigns.series
      |> Enum.map(&assigns.y.(List.last(&1.values)))
      |> Plot.spread(22)

    assigns = Map.put(assigns, :ends, ends)

    temple do
      for {series, end_y} <- Enum.zip(@series, @ends) do
        g class: Expresso.Element.classes("chart-series chart-c#{series.color}", series.class),
          rest!: series.overlay do
          c(&legend_item/1, legend: @legend, series: series)

          polyline class: "chart-line",
                   points:
                     series.values
                     |> Enum.with_index()
                     |> Enum.map_join(" ", fn {value, index} ->
                       "#{Plot.f(category_x(assigns, index))},#{Plot.f(@y.(value))}"
                     end)

          for {value, index} <- Enum.with_index(series.values) do
            circle class: "chart-dot",
                   cx: Plot.f(category_x(assigns, index)),
                   cy: Plot.f(@y.(value)),
                   r: 5
          end

          text x: Plot.f(category_x(assigns, length(@categories) - 1) + 14),
               y: Plot.f(end_y + 5),
               class: "chart-end" do
            "#{series.name} #{Plot.label(List.last(series.values))}"
          end
        end
      end
    end
  end

  # The legend of two or more series: a row of colors and names above the
  # plot, with the left edge of each item. A chart of one series has no
  # legend, because the title names it. Each item goes into the group of its
  # series, so it shows and dims with the series.
  defp legend([_one], _left), do: %{}

  defp legend(series, left) do
    series
    |> Enum.map_reduce(left, fn series, x ->
      {{series.color, x}, x + 44 + String.length(series.name) * 11}
    end)
    |> elem(0)
    |> Map.new()
  end

  defp legend_item(assigns) do
    temple do
      if x = @legend[@series.color] do
        rect class: "chart-swatch", x: x, y: 14, width: 16, height: 16, rx: 3

        text x: x + 24, y: 28, class: "chart-name" do
          @series.name
        end
      end
    end
  end

  # A pie: one slice for each category, from the top and clockwise, and a
  # legend at the right with the name and the part in percent of each one.
  defp pie_plot(assigns) do
    [series] = assigns.series
    total = Enum.sum(series.values)

    turns =
      series.values
      |> Enum.map_reduce(0, fn value, from ->
        {{from, from + value / total}, from + value / total}
      end)
      |> elem(0)

    radius = 180
    cx = 40 + radius
    cy = @height / 2
    top = cy - length(assigns.categories) * 36 / 2

    assigns =
      Map.merge(assigns, %{
        series: series,
        total: total,
        turns: turns,
        radius: radius,
        cx: cx,
        cy: cy,
        top: top
      })

    temple do
      g class: Expresso.Element.classes("chart-series", @series.class), rest!: @series.overlay do
        for {{from, to}, index} <- Enum.with_index(@turns), to > from do
          path class: "chart-slice chart-c#{index + 1}",
               d: Plot.slice(@cx, @cy, @radius, from, to)
        end

        for {{category, value}, index} <-
              Enum.with_index(Enum.zip(@categories, @series.values)) do
          rect class: "chart-swatch chart-c#{index + 1}",
               x: @cx + @radius + 60,
               y: Plot.f(@top + index * 36 + 4),
               width: 16,
               height: 16,
               rx: 3

          text x: @cx + @radius + 88, y: Plot.f(@top + index * 36 + 18), class: "chart-name" do
            "#{category} #{Plot.label(Float.round(value / @total * 100, 1))}%"
          end
        end
      end
    end
  end
end
