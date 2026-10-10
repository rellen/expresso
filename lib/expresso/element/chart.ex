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

  A `frame` entity holds the series at one point in time, and each frame
  after the first takes one step. A chart with frames, or with the effect
  `:grow`, moves its marks: `Expresso.Element.Chart.Motion` draws them.
  `docs/reference/chart-element.md` gives the rules.
  """

  use Expresso.Element

  alias Expresso.Element.Chart.{Csv, Motion, Plot}
  alias Expresso.Element.{Frame, Series}

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
    :frames,
    values: true,
    reveal: false,
    dim: false,
    frame_label: :top_right,
    sort: false,
    count: false,
    thumbnail: :first,
    elements: [],
    timeline: [],
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
    if chart.categories != nil or chart.elements != [] or chart.timeline != [],
      do:
        {:error, "a chart takes the src option, or categories and series or frames, and not both"},
      else: options(chart)
  end

  def check(%__MODULE__{frames: frames}) when is_binary(frames),
    do: {:error, "the frames option names a column of a CSV file, so it needs the src option"}

  def check(%__MODULE__{timeline: [_ | _], elements: [_ | _]}),
    do: {:error, "a chart with frames holds its series in each frame, and not in the chart"}

  def check(%__MODULE__{} = chart), do: chart |> first_frame() |> validate()

  @doc """
  Read the CSV file of a chart with `src`, and make its categories and series

  The first row holds a heading for the categories, then the name of each
  series. Each other row holds a category, then one number for each series.
  A cell is the text between two commas, with no quotes. The function reads
  the file through `Expresso.DeckFile`, so the watch mode renders the deck
  again after a change to the file.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{src: src, frames: nil} = chart) when is_binary(src) do
    with {:ok, text} <- read(src),
         {:ok, categories, series} <- Csv.table(text, src) do
      validate(%__MODULE__{chart | categories: categories, elements: series})
    end
  end

  def build(%__MODULE__{src: src} = chart) when is_binary(src) do
    with {:ok, text} <- read(src),
         {:ok, categories, timeline} <- Csv.frames(text, chart.frames, src) do
      %__MODULE__{chart | categories: categories, timeline: timeline}
      |> first_frame()
      |> validate()
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

  # The checks of a chart with its categories and its series.
  defp validate(%__MODULE__{} = chart) do
    with {:ok, chart} <- options(chart),
         :ok <- categories(chart),
         :ok <- series(chart),
         {:ok, chart} <- pie(chart),
         do: later_frames(chart)
  end

  # A chart with frames shows the series of its first frame, so `reveal`,
  # `dim` and the overlay options of a series work as for a chart without
  # frames.
  defp first_frame(%__MODULE__{timeline: [%Frame{elements: elements} | _]} = chart),
    do: %__MODULE__{chart | elements: elements}

  defp first_frame(chart), do: chart

  defp options(%__MODULE__{kind: :pie, reveal: true}),
    do: {:error, "a pie has one series, so it takes no reveal option. Give it an at option."}

  defp options(%__MODULE__{kind: kind, sort: true}) when kind != :bar,
    do:
      {:error,
       "the sort option puts the bars of a bar chart in order, so a #{kind} chart takes no sort option"}

  defp options(%__MODULE__{count: true, timeline: [], frames: nil}),
    do: {:error, "the count option counts from one frame to the next, so it needs frames"}

  defp options(%__MODULE__{thumbnail: thumbnail, timeline: [_ | _] = timeline})
       when is_integer(thumbnail) and thumbnail > length(timeline),
       do:
         {:error,
          "the thumbnail option names frame #{thumbnail}, and the chart has #{length(timeline)} frames"}

  defp options(chart), do: {:ok, chart}

  # The checks of each frame after the first. Each one holds the series of the
  # first frame, with the same names in the same order, and only the series
  # of the first frame take the overlay options and the class option.
  defp later_frames(%__MODULE__{timeline: [first | rest]} = chart) do
    names = Enum.map(first.elements, & &1.name)

    Enum.reduce_while(rest, {:ok, chart}, fn %Frame{} = frame, ok ->
      case frame(chart, frame, names) do
        :ok -> {:cont, ok}
        error -> {:halt, error}
      end
    end)
  end

  defp later_frames(chart), do: {:ok, chart}

  defp frame(%__MODULE__{} = chart, %Frame{label: label, elements: elements}, names) do
    cond do
      Enum.map(elements, & &1.name) != names ->
        {:error,
         "the frame \"#{label}\" needs the series #{Enum.map_join(names, ", ", &inspect/1)}, " <>
           "in the order of the first frame"}

      Enum.any?(elements, &(&1.at != nil or &1.on != [] or &1.class != nil)) ->
        {:error,
         "the frame \"#{label}\" gives a series an overlay option or a class. Give them to " <>
           "the series of the first frame."}

      true ->
        with :ok <- series(%__MODULE__{chart | elements: elements}),
             {:ok, _chart} <- pie(%__MODULE__{chart | elements: elements}),
             do: :ok
    end
  end

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
      frames: frame_values(chart),
      moves: moves?(chart),
      el: chart.el,
      count: chart.count,
      sort: chart.sort,
      frame_label: chart.frame_label,
      thumbnail: chart.thumbnail,
      overlay: Expresso.Overlay.Render.attributes(chart) ++ width
    }
  end

  # The values of each frame, as a list of the values of each series. A chart
  # without frames has one frame.
  defp frame_values(%__MODULE__{timeline: [_ | _] = timeline}) do
    for %Frame{label: label, elements: elements} <- timeline,
        do: %{label: label, values: Enum.map(elements, & &1.values)}
  end

  defp frame_values(%__MODULE__{elements: elements}),
    do: [%{label: nil, values: Enum.map(elements, & &1.values)}]

  @doc """
  Tell whether the marks of a chart move

  The marks move in a chart with two or more frames, and in a chart with the
  effect `:grow` on the chart or on a series. `Expresso.Element.Chart.Motion`
  then draws them.
  """
  @spec moves?(t()) :: boolean()
  def moves?(%__MODULE__{timeline: [_, _ | _]}), do: true

  def moves?(%__MODULE__{effect: effect, elements: elements}),
    do: effect == :grow or Enum.any?(elements, &(&1.effect == :grow))

  @doc """
  Return the CSS rules of the frames of a chart

  `Expresso.Overlay.Render.style/1` calls this function for each chart, after
  `Expresso.Overlay.Render.identify/1`. A chart without frames has no rules.
  """
  @spec rules(t()) :: [String.t()]
  def rules(%__MODULE__{timeline: [_, _ | _] = timeline, el: el} = chart) when is_binary(el) do
    assigns = chart |> get_assigns() |> layout()
    Motion.rules(assigns, el, timeline |> tl() |> Enum.map(&(&1.steps || [])))
  end

  def rules(%__MODULE__{}), do: []

  @doc """
  Make the HTML of a chart: a `figure` with the SVG and a table of the values

  The SVG has `role="img"` and the title as its name. The table has the class
  `chart-table`, and the style sheet hides it from the eye and not from a
  screen reader.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = assigns |> Map.put(:view_box, "0 0 #{@width} #{@height}") |> layout()

    temple do
      figure class: Expresso.Element.classes("chart chart-#{@kind}", assigns[:class]),
             rest!: @overlay do
        svg viewBox: @view_box, role: "img", aria_label: @title do
          c(&plot/1, rest!: assigns)
        end

        if length(@frames) > 1 do
          div class: "chart-frames", aria_hidden: "true" do
            for frame <- @frames do
              figure class: "chart-copy" do
                svg viewBox: @view_box do
                  c(&plot/1, rest!: copy(assigns, frame))
                end

                figcaption do
                  frame.label
                end
              end
            end
          end
        end

        c(&table/1, rest!: assigns)
      end
    end
  end

  # A chart of one frame that does not move, for paper and for the handout
  # view. It has the axis of the chart with each frame.
  defp copy(assigns, frame) do
    series =
      for {series, values} <- Enum.zip(assigns.series, frame.values),
          do: %{series | values: values}

    %{assigns | series: series, moves: false}
  end

  # The table holds one column for each series in each frame.
  defp table(assigns) do
    columns =
      for frame <- assigns.frames, {series, s} <- Enum.with_index(assigns.series) do
        name =
          case {frame.label, assigns.series} do
            {nil, _series} -> series.name
            {label, [_one]} -> label
            {label, _series} -> "#{series.name} #{label}"
          end

        {name, Enum.at(frame.values, s)}
      end

    assigns = Map.put(assigns, :columns, columns)

    temple do
      table class: "chart-table" do
        caption do
          @title
        end

        thead do
          tr do
            th do
            end

            for {name, _values} <- @columns do
              th scope: "col" do
                name
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

              for {_name, values} <- @columns do
                td do
                  Plot.label(Enum.at(values, index))
                end
              end
            end
          end
        end
      end
    end
  end

  # The kinds of a chart. Each one writes the content of the SVG.
  defp plot(%{kind: :pie, moves: true} = assigns), do: Motion.render(assigns)
  defp plot(%{kind: :pie} = assigns), do: pie_plot(assigns)
  defp plot(assigns), do: axis_plot(assigns)

  # The axis of a chart with each value of each frame, the box of the plot,
  # the function from a value to its coordinate, and the legend. A pie has no
  # axis.
  defp layout(%{kind: :pie} = assigns), do: Map.put(assigns, :legend_item, &legend_item/1)

  defp layout(assigns) do
    ticks = assigns.frames |> Enum.flat_map(& &1.values) |> List.flatten() |> Plot.ticks()
    box = box(assigns, ticks)
    low = List.first(ticks)
    high = List.last(ticks)
    y = fn value -> box.bottom - (value - low) / (high - low) * (box.bottom - box.top) end

    assigns =
      Map.merge(assigns, %{
        ticks: ticks,
        box: box,
        y: y,
        legend: legend(assigns.series, legend_left(assigns, box)),
        legend_item: &legend_item/1
      })

    Map.put(assigns, :category_x, &category_x(assigns, &1))
  end

  # The box of the plot inside the SVG: the left edge holds the labels of the
  # axis, the top edge holds the legend, and the right edge of a line chart
  # holds the names at the ends of the lines.
  defp box(assigns, ticks) do
    widest = ticks |> Enum.map(&String.length(Plot.label(&1))) |> Enum.max()
    left = 24 + widest * 10
    top = if length(assigns.series) > 1 or label?(assigns), do: 64, else: 28
    right = if assigns.kind == :line, do: @width - 150, else: @width - 16
    bottom = @height - 40
    %{left: left, top: top, right: right, bottom: bottom}
  end

  defp axis_plot(assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @ticks do
          line class: if(tick == 0, do: "chart-base", else: "chart-grid"),
               x1: @box.left,
               x2: @box.right,
               y1: Plot.f(@y.(tick)),
               y2: Plot.f(@y.(tick))

          text x: @box.left - 10,
               y: Plot.f(@y.(tick) + 5),
               text_anchor: "end",
               class: "chart-tick" do
            Plot.label(tick)
          end
        end

        # The bars of a chart that moves draw their own categories, because
        # the `sort` option moves them.
        if not (@moves and @kind == :bar) do
          for {category, index} <- Enum.with_index(@categories) do
            text x: Plot.f(@category_x.(index)),
                 y: @box.bottom + 28,
                 text_anchor: "middle",
                 class: "chart-category" do
              category
            end
          end
        end
      end

      cond do
        @moves -> Motion.render(assigns)
        @kind == :bar -> c(&bars/1, rest!: assigns)
        true -> c(&lines/1, rest!: assigns)
      end
    end
  end

  # The center of a category on the axis. A bar chart gives each category a
  # band of the same width, and a line chart puts the first and the last
  # category on the edges of the plot.
  defp category_x(%{kind: :bar, box: box, categories: categories}, index) do
    band = (box.right - box.left) / length(categories)
    box.left + band * (index + 0.5)
  end

  defp category_x(%{box: box, categories: [_one]}, _index),
    do: (box.left + box.right) / 2

  defp category_x(%{box: box, categories: categories}, index) do
    inset = 24
    box.left + inset + (box.right - box.left - 2 * inset) * index / (length(categories) - 1)
  end

  defp bars(assigns) do
    band = (assigns.box.right - assigns.box.left) / length(assigns.categories)
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

  # The label of the frame goes into the row of the legend, at the right or at
  # the left. At the left, the legend starts after the longest label.
  defp label?(%{frames: [_, _ | _], frame_label: place}), do: place != :none
  defp label?(_assigns), do: false

  defp legend_left(%{frame_label: :top_left} = assigns, box) do
    if label?(assigns) do
      widest = assigns.frames |> Enum.map(&String.length(&1.label)) |> Enum.max()
      box.left + widest * 20 + 24
    else
      box.left
    end
  end

  defp legend_left(_assigns, box), do: box.left

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
