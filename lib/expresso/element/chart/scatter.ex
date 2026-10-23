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
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.{Motion, Plot, Scale}
  alias Expresso.Element.{Point, Series}

  # The box of the chart in the units of the SVG.
  @width 800
  @height 450

  # The radius of a mark, in the units of the SVG.
  @radius 7

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

  `Expresso.Element.Chart.check/1` calls this function. A chart of one group
  holds each point in that group.
  """
  @spec check(Chart.t()) :: {:ok, Chart.t()} | {:error, String.t()}
  def check(%Chart{} = chart) do
    with :ok <- options(chart),
         {:ok, points} <- points(chart),
         :ok <- names(points),
         :ok <- axis(points, :x, chart.x_range, chart.x_scale),
         :ok <- axis(points, :y, chart.y_range, chart.y_scale),
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
    if Enum.all?(elements, &is_struct(&1, Point)),
      do: {:ok, elements},
      else: {:error, "a #{kind} chart holds point entities, and no series"}
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

  # The groups of the points: one group with each point.
  defp groups(%Chart{title: title}, points), do: [%Series{name: title, elements: points}]

  @doc """
  Make the assigns of the render function from the struct

  The key `groups` holds each group with its overlay attributes and its
  points. Each point has its number `index`, from 1 in the order of the data.
  The key `frames` holds the values of each point in each frame.
  """
  @spec assigns(Chart.t()) :: map()
  def assigns(%Chart{} = chart) do
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
              overlay: Expresso.Overlay.Render.attributes(point)
            }
          end)

        {%{
           name: group.name,
           color: 1,
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
      frames: [%{label: nil, points: values(chart.elements)}],
      frame_label: chart.frame_label,
      thumbnail: chart.thumbnail,
      el: chart.el,
      overlay: Expresso.Overlay.Render.attributes(chart) ++ Chart.width(chart)
    }
  end

  # The values of each point of a frame, in the order of their numbers.
  defp values(groups) do
    for %Series{elements: points} <- groups,
        %Point{} = point <- points,
        do: %{x: point.x, y: point.y}
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
    box = box(assigns, x_axis, y_axis)

    Map.merge(assigns, %{
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
  # right edge of the box.
  defp box(assigns, x_axis, y_axis) do
    widest = &(&1.ticks |> Enum.map(fn tick -> String.length(Plot.label(tick)) end) |> Enum.max())
    left = 24 + widest.(y_axis) * 10 + if(assigns.y_label, do: 32, else: 0)
    right = @width - 16 - widest.(x_axis) * 5
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
           rs: Enum.map(points, fn _point -> @radius end)
         }}
      end)

    channels =
      Enum.flat_map(marks, fn {index, mark} ->
        [{"x#{index}", mark.xs}, {"y#{index}", mark.ys}, {"r#{index}", mark.rs}]
      end)

    %{marks: marks, channels: channels}
  end

  @doc """
  Draw the content of the SVG of a scatter plot: the axes and the marks
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.put(assigns, :scene, scene(assigns))

    temple do
      c(&Motion.frame_label/1, rest!: assigns)
      c(&axes/1, rest!: assigns)
      c(&titles/1, rest!: assigns)

      for group <- @groups do
        g class: Expresso.Element.classes("chart-series chart-c#{group.color}", group.class),
          rest!: group.overlay do
          for point <- group.points do
            c(&mark/1, point: point, mark: @scene.marks[point.index])
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
      Motion.style([
        {"--chart-u", Motion.ref("x#{point.index}", mark.xs)},
        {"--chart-v", Motion.ref("y#{point.index}", mark.ys)},
        {"--chart-w", Motion.ref("r#{point.index}", mark.rs)}
      ])

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
           d: "M1 0A1 1 0 1 1 -1 0A1 1 0 1 1 1 0Z",
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

  The table has one row for each point, in the order of the data, with its
  name, its x value and its y value.
  """
  @spec table(map()) :: %{headers: [String.t() | nil], rows: [[String.t()]]}
  def table(assigns) do
    names = for group <- assigns.groups, point <- group.points, do: point.name
    [frame] = assigns.frames

    rows =
      for {name, values} <- Enum.zip(names, frame.points),
          do: [name, Plot.label(values.x), Plot.label(values.y)]

    %{headers: [nil, assigns.x_label || "x", assigns.y_label || "y"], rows: rows}
  end
end
