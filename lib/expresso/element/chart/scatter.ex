defmodule Expresso.Element.Chart.Scatter do
  @moduledoc """
  A scatter plot: one mark for each point, at the place of its x value and its
  y value

  `Expresso.Element.Chart` sends each function of a chart of the family
  `:points` to this module: the check, the assigns, the layout, the marks and
  the table. `docs/scatter-plots.md` gives the design.

  The check puts the points into groups. Each group is an
  `Expresso.Element.Series` with its points in `elements`, and it is a child
  of the chart, so a group takes the steps of the overlay contract.

  Each mark has its place in the channels of `Expresso.Element.Chart.Motion`:
  `--x<n>` and `--y<n>` for point `n`, and `--r<n>` for its radius. The style
  attribute of the mark reads the channels with the value of the first frame
  as the fallback, so a chart of one frame needs no rule.

  `Expresso.Element.Chart.Encoding` gives the symbol, the color and the size
  of each mark, and `Expresso.Element.Chart.Scatter.Legend` draws the legends
  at the right of the plot.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.{Encoding, Motion, Plot, Scale}
  alias Expresso.Element.Chart.Scatter.Legend
  alias Expresso.Element.{Point, Series}

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  # The radius of a mark without a size, and the radius of the largest mark
  # of a scatter plot and of a bubble chart, in the units of the SVG.
  @radius 7
  @largest [scatter: 24, bubble: 40]

  # The color of a mark without a color, in a chart without categories of
  # color and in a chart with them.
  @plain "var(--chart-1)"
  @other "var(--muted)"

  # The options of the other kinds, and the reason that a scatter plot takes
  # none of them.
  @others [
    categories: "each point gives its own x and y",
    category_label: "the x_label option names the x axis",
    value_label: "the y_label option names the y axis",
    levels: "a scatter plot has no groups of categories",
    shape: "only a voronoi chart takes it",
    sort: "a scatter plot has no bars",
    count: "a scatter plot shows no numbers that count",
    src: "the points come from point entities",
    frames: "the points come from point entities",
    highlight: "the marks show no focus",
    whole_first: "the marks show no focus"
  ]

  @doc """
  Check the options and the points of a scatter plot, and put the points into
  groups

  `Expresso.Element.Chart.check/1` calls this function. Each category of the
  color is one group, in the order of its first point. A point without a
  category of the color goes into a group of such points.
  """
  @spec check(Chart.t()) :: {:ok, Chart.t()} | {:error, String.t()}
  def check(%Chart{} = chart) do
    with :ok <- options(chart),
         {:ok, points} <- points(chart),
         :ok <- names(points),
         :ok <- axis(points, :x, chart.x_range, chart.x_scale),
         :ok <- axis(points, :y, chart.y_range, chart.y_scale),
         :ok <- encodings(chart, points),
         do: {:ok, %Chart{chart | elements: groups(chart, points)}}
  end

  defp options(%Chart{kind: kind} = chart) do
    given =
      Enum.find(@others, fn {option, _reason} ->
        Map.fetch!(chart, option) not in [nil, false]
      end)

    cond do
      given != nil ->
        {option, reason} = given
        {:error, "a #{kind} chart takes no #{option} option, because #{reason}"}

      chart.timeline != [] ->
        {:error, "a #{kind} chart takes no frames"}

      chart.reveal or chart.dim or chart.effect == :grow ->
        {:error, "a #{kind} chart takes no reveal option, no dim option and no effect :grow"}

      true ->
        :ok
    end
  end

  defp points(%Chart{elements: [], kind: kind}),
    do: {:error, "a #{kind} chart needs a point"}

  defp points(%Chart{elements: elements, kind: kind}) do
    cond do
      Enum.all?(elements, &is_struct(&1, Point)) ->
        {:ok, elements}

      not Enum.all?(elements, &is_struct(&1, Series)) ->
        {:error, "a #{kind} chart holds point entities or series of points, and not both"}

      true ->
        series_points(elements, kind)
    end
  end

  # The checks of the series of a scatter plot: each holds points and no
  # values, and a point of a series names its symbol and its color, because
  # the series is its category.
  defp series_points(series, kind) do
    names = Enum.map(series, & &1.name)
    points = Enum.flat_map(series, & &1.elements)

    cond do
      length(series) > 8 ->
        {:error,
         "a #{kind} chart has at most 8 series, one for each color. Put the smallest into a series \"Other\"."}

      (twice = names -- Enum.uniq(names)) != [] ->
        {:error, "two series have the name \"#{hd(twice)}\". Give each series its own name."}

      one = Enum.find(series, &(&1.values != nil)) ->
        {:error,
         "the series \"#{one.name}\" of a #{kind} chart holds point entities, and no values"}

      empty = Enum.find(series, &(&1.elements == [])) ->
        {:error, "the series \"#{empty.name}\" of a #{kind} chart needs a point"}

      point = Enum.find(points, &(is_binary(&1.symbol) or is_binary(&1.color))) ->
        {:error,
         "the point \"#{point.name}\" is in a series, and the series is its category. Give " <>
           "the point a symbol such as :square and a color such as :accent, and no category."}

      true ->
        {:ok, points}
    end
  end

  defp names(points) do
    names = Enum.map(points, & &1.name)

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [name | _rest] ->
        {:error, "two points have the name \"#{name}\". Give each point its own name."}
    end
  end

  # The checks of one axis: its range, the values of a logarithmic axis, and
  # the values outside the range.
  defp axis(points, axis, range, scale) do
    log = scale == :log
    values = Enum.map(points, &{&1.name, Map.fetch!(&1, axis)})

    with :ok <- range_check(range, log, axis),
         :ok <- log_check(values, log, axis),
         do: inside(values, range, axis)
  end

  defp range_check({low, high}, _log, axis) when low >= high,
    do:
      {:error,
       "the #{axis}_range option goes from the low value to the high value, such as {0, 100}"}

  defp range_check({low, _high}, true, axis) when low <= 0,
    do: {:error, "a logarithmic #{axis} axis needs a #{axis}_range with values more than zero"}

  defp range_check(_range, _log, _axis), do: :ok

  defp log_check(values, true, axis) do
    case Enum.find(values, fn {_name, value} -> value <= 0 end) do
      nil ->
        :ok

      {name, value} ->
        {:error,
         "a logarithmic #{axis} axis needs values more than zero, and the point \"#{name}\" " <>
           "has #{axis} #{Plot.label(value)}"}
    end
  end

  defp log_check(_values, false, _axis), do: :ok

  defp inside(_values, nil, _axis), do: :ok

  defp inside(values, {low, high}, axis) do
    case Enum.find(values, fn {_name, value} -> value < low or value > high end) do
      nil ->
        :ok

      {name, value} ->
        {:error,
         "the point \"#{name}\" has #{axis} #{Plot.label(value)}, outside the " <>
           "#{axis}_range {#{Plot.label(low)}, #{Plot.label(high)}}"}
    end
  end

  # The checks of the symbol, the color and the size.
  defp encodings(%Chart{kind: kind}, points) do
    sized = Enum.filter(points, &(&1.size != nil))
    symbols = points |> Enum.map(& &1.symbol) |> Encoding.categories()
    colors = points |> Enum.map(& &1.color) |> Encoding.categories()
    count = length(Encoding.symbols())

    cond do
      bad = Enum.find(sized, &(&1.size <= 0)) ->
        {:error,
         "the size of a point is a number more than zero, and the point \"#{bad.name}\" " <>
           "has the size #{Plot.label(bad.size)}"}

      kind == :bubble and length(sized) < length(points) ->
        bare = Enum.find(points, &(&1.size == nil))

        {:error,
         "a bubble chart needs a size for each point, and the point \"#{bare.name}\" has none"}

      sized != [] and length(sized) < length(points) ->
        bare = Enum.find(points, &(&1.size == nil))

        {:error,
         "the point \"#{bare.name}\" has no size, and other points have one. " <>
           "Give a size to each point or to none."}

      length(symbols) > count ->
        {:error,
         "the symbol takes at most #{count} categories, one for each symbol, and the points " <>
           "have #{length(symbols)}: #{Enum.map_join(symbols, ", ", &inspect/1)}"}

      length(colors) > 8 ->
        {:error,
         "the color takes at most 8 categories, one for each color of the theme, and the " <>
           "points have #{length(colors)}. Put the smallest into a category \"Other\"."}

      true ->
        :ok
    end
  end

  # The groups of the points. Each series is a group, and it gives its symbol
  # and its color to each point without one. Without series, each category of
  # the color is a group, in the order of its first point, and the points
  # without a category are one group.
  defp groups(%Chart{elements: [%Series{} | _] = series}, _points) do
    for {%Series{} = one, place} <- Enum.with_index(series, 1) do
      symbol = one.symbol || :circle
      color = one.color || Enum.at(Encoding.roles(), place - 1)

      points =
        for %Point{} = point <- one.elements,
            do: %Point{point | symbol: point.symbol || symbol, color: point.color || color}

      %Series{one | symbol: symbol, color: color, elements: points}
    end
  end

  defp groups(%Chart{title: title}, points) do
    points
    |> Enum.group_by(&if(is_binary(&1.color), do: &1.color))
    |> then(fn groups ->
      for key <- points |> Enum.map(&if(is_binary(&1.color), do: &1.color)) |> Enum.uniq(),
          do: %Series{name: key || title, elements: groups[key]}
    end)
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `groups` holds each group with its overlay attributes and its
  points. Each point has its number `index`, from 1 in the order of the data.
  The key `frames` holds the values of each point in each frame.
  """
  @spec assigns(Chart.t()) :: map()
  def assigns(%Chart{} = chart) do
    all = Enum.flat_map(chart.elements, & &1.elements)
    symbols = all |> Enum.map(& &1.symbol) |> Encoding.categories()
    colors = all |> Enum.map(& &1.color) |> Encoding.categories()
    default = if colors == [], do: @plain, else: @other

    {groups, _next} =
      Enum.map_reduce(chart.elements, 1, fn %Series{} = group, next ->
        points =
          group.elements
          |> Enum.with_index(next)
          |> Enum.map(fn {%Point{} = point, index} ->
            %{
              name: point.name,
              index: index,
              class: point.class,
              symbol: Encoding.symbol(point.symbol, symbols),
              color: Encoding.color(point.color, colors, default),
              symbol_value: point.symbol,
              color_value: point.color,
              overlay: Expresso.Overlay.Render.attributes(point)
            }
          end)

        {%{
           name: group.name,
           category: category(group),
           class: group.class,
           overlay: Expresso.Overlay.Render.attributes(group),
           points: points
         }, next + length(points)}
      end)

    %{
      kind: chart.kind,
      title: chart.title,
      x_label: chart.x_label,
      y_label: chart.y_label,
      x_range: chart.x_range,
      y_range: chart.y_range,
      x_scale: chart.x_scale,
      y_scale: chart.y_scale,
      groups: groups,
      symbols: symbols,
      colors: colors,
      series:
        for(
          %Series{color: color} = one when color != nil <- chart.elements,
          do: %{name: one.name, symbol: one.symbol, color: Encoding.role(color)}
        ),
      symbol_label: chart.symbol_label,
      color_label: chart.color_label,
      size_label: chart.size_label,
      opacity: chart.opacity,
      largest: @largest[chart.kind],
      frames: [%{label: nil, points: values(chart.elements)}],
      frame_label: chart.frame_label,
      thumbnail: chart.thumbnail,
      el: chart.el,
      overlay: Expresso.Overlay.Render.attributes(chart) ++ Chart.width(chart)
    }
  end

  # The key of the item of the legend in a group: the name of a series, or
  # the category of the color. A group without either has no item.
  defp category(%Series{color: color, name: name}) when color != nil, do: name

  defp category(%Series{elements: points}) do
    case Enum.find(points, &is_binary(&1.color)) do
      nil -> nil
      point -> point.color
    end
  end

  # The values of each point of a frame, in the order of their numbers.
  defp values(groups) do
    for %Series{elements: points} <- groups,
        %Point{} = point <- points,
        do: %{x: point.x, y: point.y, size: point.size}
  end

  @doc """
  Add the layout of a scatter plot to its assigns: the axes, the box of the
  plot, and the functions `x` and `y` from a value to a coordinate

  The axes hold the values of each frame, so a mark keeps its scale from one
  frame to the next.
  """
  @spec layout(map()) :: map()
  def layout(assigns) do
    points = Enum.flat_map(assigns.frames, & &1.points)
    x_axis = Scale.new(Enum.map(points, & &1.x), assigns.x_range, assigns.x_scale)
    y_axis = Scale.new(Enum.map(points, & &1.y), assigns.y_range, assigns.y_scale)
    sizes = points |> Enum.map(& &1.size) |> Enum.reject(&is_nil/1)
    assigns = Map.put(assigns, :most, Enum.max(sizes, fn -> nil end))
    legend = Legend.layout(assigns)
    box = box(assigns, x_axis, y_axis, legend)

    Map.merge(assigns, %{
      legend: Legend.place(legend, box),
      x_axis: x_axis,
      y_axis: y_axis,
      box: box,
      x: &(box.left + Scale.fraction(x_axis, &1) * (box.right - box.left)),
      y: &(box.bottom - Scale.fraction(y_axis, &1) * (box.bottom - box.top))
    })
  end

  # The box of the plot inside the SVG: the left edge holds the ticks of the
  # y axis and its title, and the bottom edge holds the ticks of the x axis
  # and its title. Half of the widest tick of the x axis can go past the
  # right edge of the box. The legends take the right part of the SVG.
  defp box(assigns, x_axis, y_axis, legend) do
    widest = &(&1.ticks |> Enum.map(fn tick -> String.length(Plot.label(tick)) end) |> Enum.max())
    left = 24 + widest.(y_axis) * 10 + if(assigns.y_label, do: 32, else: 0)
    right = @width - 16 - max(widest.(x_axis) * 5, Legend.width(legend))
    top = if label?(assigns), do: 64, else: 28
    bottom = @height - 40 - if(assigns.x_label, do: 30, else: 0)
    %{left: left, top: top, right: right, bottom: bottom}
  end

  defp label?(%{frames: [_, _ | _], frame_label: place}), do: place != :none
  defp label?(_assigns), do: false

  @doc """
  Return the places of the marks of each frame, and the channels that hold them
  """
  @spec scene(map()) :: %{marks: %{pos_integer() => map()}, channels: [{String.t(), [number()]}]}
  def scene(assigns) do
    count = assigns.frames |> hd() |> Map.fetch!(:points) |> length()

    marks =
      Map.new(1..count//1, fn index ->
        points = Enum.map(assigns.frames, &Enum.at(&1.points, index - 1))

        {index,
         %{
           xs: Enum.map(points, &assigns.x.(&1.x)),
           ys: Enum.map(points, &assigns.y.(&1.y)),
           rs: Enum.map(points, &radius(assigns, &1.size))
         }}
      end)

    channels =
      Enum.flat_map(marks, fn {index, mark} ->
        [{"x#{index}", mark.xs}, {"y#{index}", mark.ys}, {"r#{index}", mark.rs}]
      end)

    %{marks: marks, channels: channels}
  end

  # The radius of a mark from its size. A chart without sizes has marks of
  # one radius.
  defp radius(_assigns, nil), do: @radius
  defp radius(assigns, size), do: Encoding.radius(size, assigns.most, assigns.largest)

  @doc """
  Draw the content of the SVG of a scatter plot: the axes, the legends and
  the marks

  Inside a group, the larger marks come first, so a large mark does not hide
  a small mark. The item of the legend of a category of the color goes into
  the group of that category, so it shows and dims with its marks.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.put(assigns, :scene, scene(assigns))

    temple do
      c(&Motion.frame_label/1, rest!: assigns)
      c(&axes/1, rest!: assigns)
      c(&titles/1, rest!: assigns)

      c(&Legend.render/1, rest!: Map.put(assigns, :category, nil))

      for group <- @groups do
        g class: Expresso.Element.classes("chart-series", group.class), rest!: group.overlay do
          if group.category do
            c(&Legend.render/1, rest!: Map.put(assigns, :category, group.category))
          end

          for point <- Enum.sort_by(group.points, &(-hd(@scene.marks[&1.index].rs))) do
            c(&mark/1, point: point, mark: @scene.marks[point.index], opacity: @opacity)
          end
        end
      end
    end
  end

  # One mark: a circle of radius 1 that the style moves to its place and
  # scales to its radius.
  defp mark(assigns) do
    %{point: point, mark: mark} = assigns

    style =
      Motion.style(
        [
          {"--chart-u", Motion.ref("x#{point.index}", mark.xs)},
          {"--chart-v", Motion.ref("y#{point.index}", mark.ys)},
          {"--chart-w", Motion.ref("r#{point.index}", mark.rs)},
          {"--series", point.color}
        ] ++ if(assigns.opacity, do: [{"opacity", assigns.opacity}], else: [])
      )

    assigns = Map.put(assigns, :style, style)

    temple do
      if @point.overlay == [] do
        c(&shape/1, point: @point, style: @style)
      else
        g rest!: @point.overlay do
          c(&shape/1, point: @point, style: @style)
        end
      end
    end
  end

  # The path of a mark. A point with an overlay has a group around its path
  # for the overlay, because the transitions of an element with `data-on`
  # replace the transitions of the channels.
  defp shape(assigns) do
    temple do
      path class: Expresso.Element.classes("chart-point chart-mark", @point.class),
           d: Encoding.path(@point.symbol),
           style: @style
    end
  end

  # The grid, the base lines and the ticks of the two axes.
  defp axes(assigns) do
    temple do
      g class: "chart-axis" do
        for tick <- @x_axis.ticks do
          line class: "chart-grid",
               x1: Plot.f(@x.(tick)),
               x2: Plot.f(@x.(tick)),
               y1: @box.top,
               y2: @box.bottom

          text x: Plot.f(@x.(tick)),
               y: @box.bottom + 28,
               text_anchor: "middle",
               class: "chart-tick" do
            Plot.label(tick)
          end
        end

        for tick <- @y_axis.ticks do
          line class: "chart-grid",
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

        line class: "chart-base", x1: @box.left, x2: @box.right, y1: @box.bottom, y2: @box.bottom
        line class: "chart-base", x1: @box.left, x2: @box.left, y1: @box.top, y2: @box.bottom
      end
    end
  end

  # The title of the x axis under its ticks, and the title of the y axis
  # beside its ticks, turned to read from the bottom up.
  defp titles(assigns) do
    temple do
      if @x_label do
        text x: Plot.f((@box.left + @box.right) / 2),
             y: @box.bottom + 62,
             text_anchor: "middle",
             class: "chart-axis-title" do
          @x_label
        end
      end

      if @y_label do
        text x: 0,
             y: 0,
             transform: "translate(22 #{Plot.f((@box.top + @box.bottom) / 2)}) rotate(-90)",
             text_anchor: "middle",
             class: "chart-axis-title" do
          @y_label
        end
      end
    end
  end

  @doc """
  Return the headers and the rows of the table of a scatter plot

  The table has one row for each point, with its name, its x value and its y
  value. A chart with series, with a category of the symbol or of the color,
  or with sizes, has a column for each of them. A symbol or a color that is not a
  category has no text.
  """
  @spec table(map()) :: %{headers: [String.t() | nil], rows: [[String.t()]]}
  def table(assigns) do
    points =
      for group <- assigns.groups, point <- group.points, do: Map.put(point, :group, group.name)

    [frame] = assigns.frames
    columns = columns(assigns, frame)

    rows =
      for {point, values} <- Enum.zip(points, frame.points) do
        cells =
          Enum.map(columns, fn {_shown, _header, cell} ->
            cell.(%{point: point, values: values})
          end)

        [point.name, Plot.label(values.x), Plot.label(values.y) | cells]
      end

    headers =
      [nil, assigns.x_label || "x", assigns.y_label || "y"] ++ Enum.map(columns, &elem(&1, 1))

    %{headers: headers, rows: rows}
  end

  # The columns of the table after the x and the y: a header and a function
  # that writes the cell of a point.
  defp columns(assigns, frame) do
    same = same?(assigns)

    [
      {assigns.series != [], assigns.color_label || "Series", & &1.point.group},
      {assigns.symbols != [] and not same, assigns.symbol_label || "Symbol",
       &text(&1.point.symbol_value)},
      {assigns.colors != [], assigns.color_label || assigns.symbol_label || "Color",
       &text(&1.point.color_value)},
      {Enum.any?(frame.points, &(&1.size != nil)), assigns.size_label || "Size",
       &Plot.label(&1.values.size)}
    ]
    |> Enum.filter(&elem(&1, 0))
  end

  defp text(value) when is_binary(value), do: value
  defp text(_value), do: ""

  @doc """
  Tell whether the symbol and the color of each point take the same category

  Such a chart has one legend, with the symbol and the color of each
  category.
  """
  @spec same?(map()) :: boolean()
  def same?(%{colors: [], symbols: []}), do: false

  def same?(assigns) do
    for group <- assigns.groups,
        point <- group.points,
        reduce: true,
        do: (same -> same and point.symbol_value == point.color_value)
  end
end
