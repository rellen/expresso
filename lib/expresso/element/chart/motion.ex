defmodule Expresso.Element.Chart.Motion do
  @moduledoc """
  The marks of a chart that move: the frames and the effect `:grow`

  `Expresso.Element.Chart` calls this module for a chart with two or more
  frames, and for a chart with the effect `:grow`. The module draws each mark
  one time, at the origin of the SVG, and a CSS transform moves the mark to its
  place. The place comes from a custom property of the chart, a **channel**,
  such as `--b1-3` for the top of the bar of series 1 in category 3. The style
  attribute of the mark reads the channel, with the value of the first frame
  as the fallback.

  The generated style block of the deck sets the channels of each later frame
  at the steps of that frame. `rules/3` writes these rules. A mark copies the
  channel into a registered property of the theme, such as `--chart-v`, and the
  theme gives that property a transition. Therefore the mark moves from one
  frame to the next with the time and the easing of the element.

  A text that changes, such as the value of a bar, has one copy for each
  frame, and the channel `--k<n>` of frame `n` is 1 for the copy of the frame
  that shows. The copies fade. With the `count` option, the text has one copy
  instead, and the presenter script writes the number from the registered
  property `--chart-n` at each frame of the animation.

  The effect `:grow` multiplies each place by `--chart-shown`, which the theme
  sets from `--shown` on a chart or a series with that effect. A bar then
  grows from the base line, and a pie opens from the top. The line of a line
  chart opens from the left with a clip.

  `docs/reference/chart-element.md` gives the rules for the author, and
  `docs/architecture.md` gives the design.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.Plot

  # The length of the shape of a bar, in the units of the SVG. A clip at the
  # base line cuts it, so the shape is longer than the highest bar.
  @shape 470

  # The radius of a pie. The arcs of a pie are circles with a wide stroke, so
  # a dash of the stroke is a slice.
  @radius 180

  @doc """
  Return the channels of a chart: the name and the value for each frame

  The function leaves out a channel that has the same value in each frame,
  because the mark then holds the value itself.
  """
  @spec channels(map()) :: [{String.t(), [number()]}]
  def channels(assigns) do
    assigns
    |> scene()
    |> Map.fetch!(:channels)
    |> Enum.reject(fn {_name, values} -> values |> Enum.uniq() |> length() == 1 end)
  end

  @doc """
  Return the CSS rules of the frames of one chart

  `el` is the value of the `data-el` attribute of the chart, and `steps` holds
  the steps of each frame after the first. Each rule sets the channels of one
  frame at its steps. The last rule sets the channels of the frame of the
  `thumbnail` option on the overview and on the menu of the slides, because
  they show the last step of the slide.
  """
  @spec rules(map(), String.t(), [[pos_integer()]]) :: [String.t()]
  def rules(assigns, el, steps) do
    channels = channels(assigns)

    frames =
      for {steps, index} <- Enum.with_index(steps, 1), steps != [] do
        selectors =
          Enum.map_join(steps, ", ", &"section[data-step=\"#{&1}\"] [data-el=\"#{el}\"]")

        "#{selectors} { #{declarations(channels, index)} }"
      end

    thumbnail =
      ":is(.menu-thumb, body[data-overview=\"true\"] .handout-page[data-thumbnail]) " <>
        "[data-el=\"#{el}\"] { #{declarations(channels, thumbnail(assigns))} }"

    if channels == [], do: [], else: frames ++ [thumbnail]
  end

  defp declarations(channels, index) do
    Enum.map_join(channels, " ", fn {name, values} ->
      "--#{name}: #{Plot.f(Enum.at(values, index))};"
    end)
  end

  defp thumbnail(%{thumbnail: :first}), do: 0
  defp thumbnail(%{thumbnail: :last, frames: frames}), do: length(frames) - 1
  defp thumbnail(%{thumbnail: number}), do: number - 1

  @doc """
  Draw the marks of a chart

  The assigns hold the keys of `Expresso.Element.Chart` and the box of the
  plot, the function `y` from a value to a coordinate, and the function
  `category_x` from the index of a category to its center.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    assigns = Map.put(assigns, :scene, scene(assigns))

    temple do
      c(&frame_label/1, rest!: assigns)

      case @kind do
        :bar -> c(&bars/1, rest!: assigns)
        :line -> c(&lines/1, rest!: assigns)
        :pie -> c(&pie/1, rest!: assigns)
      end
    end
  end

  # The places of the marks of each frame, and the channels that hold them.

  defp scene(%{kind: :pie} = assigns), do: pie_scene(assigns)
  defp scene(%{kind: :line} = assigns), do: line_scene(assigns)
  defp scene(assigns), do: bar_scene(assigns)

  # The value of series `s` in category `i` in each frame.
  defp values(frames, s, i), do: Enum.map(frames, &(&1.values |> Enum.at(s) |> Enum.at(i)))

  defp flags(frames) do
    count = length(frames)
    for k <- 1..count, do: {"k#{k}", for(j <- 1..count, do: if(j == k, do: 1, else: 0))}
  end

  defp bar_scene(assigns) do
    %{box: box, categories: categories, series: series, frames: frames, y: y} = assigns
    band = (box.right - box.left) / length(categories)
    group = band * 0.7
    slot = group / length(series)
    base = y.(0)

    xs = bar_positions(assigns)

    marks =
      for {item, s} <- Enum.with_index(series), i <- 0..(length(categories) - 1) do
        values = values(frames, s, i)

        %{
          series: item,
          category: i,
          dx: -group / 2 + (item.color - 1) * slot + 1,
          width: max(slot - 2, 1),
          tops: Enum.map(values, y),
          labels: Enum.map(values, &if(&1 >= 0, do: y.(&1) - 8, else: y.(&1) + 20)),
          values: values
        }
      end

    channels =
      Enum.map(xs, fn {i, x} -> {"x#{i}", x} end) ++
        Enum.flat_map(marks, fn mark ->
          id = "#{mark.series.color}-#{mark.category}"
          [{"b#{id}", mark.tops}, {"t#{id}", mark.labels}, {"n#{id}", mark.values}]
        end) ++ flags(frames)

    %{
      base: base,
      xs: Map.new(xs),
      marks: marks,
      negative: Enum.any?(marks, fn mark -> Enum.any?(mark.values, &(&1 < 0)) end),
      channels: channels
    }
  end

  # The center of each category in each frame. With `sort`, the category with
  # the largest total of a frame goes first.
  defp bar_positions(%{categories: categories, frames: frames} = assigns) do
    for i <- 0..(length(categories) - 1) do
      {i, Enum.map(frames, &assigns.category_x.(rank(&1, i, assigns.sort)))}
    end
  end

  defp rank(_frame, i, false), do: i

  defp rank(frame, i, true) do
    frame.values
    |> Enum.zip_with(&Enum.sum/1)
    |> Enum.with_index()
    |> Enum.sort_by(fn {total, index} -> {-total, index} end)
    |> Enum.find_index(fn {_total, index} -> index == i end)
  end

  defp line_scene(assigns) do
    %{categories: categories, series: series, frames: frames, y: y} = assigns
    last = length(categories) - 1

    marks =
      for {item, s} <- Enum.with_index(series) do
        points =
          for i <- 0..last,
              do: %{x: assigns.category_x.(i), ys: Enum.map(values(frames, s, i), y)}

        %{series: item, points: points, values: values(frames, s, last)}
      end

    # The labels at the ends of the lines move apart in each frame.
    ends =
      frames
      |> Enum.map(fn frame ->
        frame.values |> Enum.map(&y.(List.last(&1))) |> Plot.spread(22)
      end)
      |> Enum.zip_with(& &1)

    marks = for {mark, end_ys} <- Enum.zip(marks, ends), do: Map.put(mark, :ends, end_ys)

    channels =
      Enum.flat_map(marks, fn mark ->
        color = mark.series.color

        points =
          for {point, i} <- Enum.with_index(mark.points), do: {"p#{color}-#{i}", point.ys}

        points ++ [{"e#{color}", mark.ends}, {"n#{color}", mark.values}]
      end) ++ flags(frames)

    %{marks: marks, end_x: assigns.category_x.(last) + 14, channels: channels}
  end

  defp pie_scene(%{categories: categories, frames: frames}) do
    circumference = 2 * :math.pi() * @radius / 2

    shares =
      Enum.map(frames, fn %{values: [values]} ->
        total = Enum.sum(values)
        Enum.map(values, &(&1 / total))
      end)

    starts =
      Enum.map(shares, fn shares ->
        shares |> Enum.scan(0, &(&1 + &2)) |> Enum.zip_with(shares, &(&1 - &2))
      end)

    marks =
      for i <- 0..(length(categories) - 1) do
        parts = Enum.map(shares, &Enum.at(&1, i))

        %{
          category: i,
          lengths: Enum.map(parts, &(&1 * circumference)),
          starts: Enum.map(starts, &(Enum.at(&1, i) * 360)),
          percents: Enum.map(parts, &Float.round(&1 * 100, 1))
        }
      end

    channels =
      Enum.flat_map(marks, fn mark ->
        i = mark.category
        [{"l#{i}", mark.lengths}, {"a#{i}", mark.starts}, {"n#{i}", mark.percents}]
      end) ++ flags(frames)

    %{marks: marks, channels: channels}
  end

  # The value of a channel in a style attribute: the custom property with the
  # value of the first frame as its fallback, or the value alone when no frame
  # changes it.
  defp ref(name, [first | _rest] = values) do
    if values |> Enum.uniq() |> length() == 1,
      do: Plot.f(first),
      else: "var(--#{name}, #{Plot.f(first)})"
  end

  # A place that the effect `:grow` moves from `from`.
  defp grow(value, from),
    do: "calc(#{Plot.f(from)} + (#{value} - #{Plot.f(from)}) * var(--chart-shown, 1))"

  defp style(pairs), do: Enum.map_join(pairs, " ", fn {key, value} -> "#{key}: #{value};" end)

  # A text that changes from frame to frame. It has one copy for each frame
  # that fades, or one copy with a number that the script counts.
  defp changing(assigns) do
    temple do
      cond do
        Enum.uniq(@texts) |> length() == 1 ->
          text x: @x, y: @y, text_anchor: @anchor, class: @class do
            List.first(@texts)
          end

        @count ->
          text x: @x, y: @y, text_anchor: @anchor, class: @class do
            @prefix

            tspan class: "chart-count",
                  data_decimals: decimals(@numbers),
                  style: style([{"--chart-n", @number}]) do
              Plot.label(List.first(@numbers))
            end

            @suffix
          end

        true ->
          for {copy, k} <- Enum.with_index(@texts, 1) do
            text x: @x,
                 y: @y,
                 text_anchor: @anchor,
                 class: "#{@class} chart-fade",
                 style: "opacity: var(--k#{k}, #{if k == 1, do: 1, else: 0});" do
              copy
            end
          end
      end
    end
  end

  defp decimals(numbers) do
    numbers
    |> Enum.map(fn number ->
      case Plot.label(number) |> String.split(".") do
        [_integer, fraction] -> String.length(fraction)
        [_integer] -> 0
      end
    end)
    |> Enum.max()
  end

  defp text_assigns(texts, numbers, name, opts) do
    Map.merge(
      %{
        texts: texts,
        numbers: numbers,
        number: if(numbers == [], do: nil, else: grow(ref(name, numbers), 0)),
        x: 0,
        y: 0,
        anchor: "middle",
        prefix: "",
        suffix: "",
        count: false
      },
      Map.new(opts)
    )
  end

  # The label of the frame, in the row of the legend. Each frame has a copy,
  # and the copies fade.
  defp frame_label(%{frame_label: :none} = assigns), do: empty(assigns)
  defp frame_label(%{frames: [_one]} = assigns), do: empty(assigns)

  defp frame_label(assigns) do
    {x, anchor} =
      case {assigns.kind, assigns.frame_label} do
        {:pie, _place} -> {784, "end"}
        {_kind, :top_left} -> {assigns.box.left, "start"}
        {_kind, :top_right} -> {assigns.box.right, "end"}
      end

    y = 34
    labels = Enum.map(assigns.frames, & &1.label)

    temple do
      c(&changing/1,
        rest!: text_assigns(labels, [], "", x: x, y: y, anchor: anchor, class: "chart-frame")
      )
    end
  end

  defp empty(_assigns), do: Phoenix.HTML.raw("")

  defp bars(assigns) do
    scene = assigns.scene

    temple do
      for item <- @series do
        g class: Expresso.Element.classes("chart-series chart-c#{item.color}", item.class),
          rest!: item.overlay do
          c(@legend_item, legend: @legend, series: item)
          c(&bar_shapes/1, rest!: Map.put(assigns, :item, item))

          if @values do
            c(&bar_values/1, rest!: Map.put(assigns, :item, item))
          end
        end
      end

      g class: "chart-axis" do
        for {category, i} <- Enum.with_index(@categories) do
          text x: 0,
               y: @box.bottom + 28,
               text_anchor: "middle",
               class: "chart-category chart-mark",
               style: style([{"--chart-u", ref("x#{i}", scene.xs[i])}, {"--chart-v", 0}]) do
            category
          end
        end
      end
    end
  end

  # The bars of one series. The bars up and the bars down each have a group
  # with the clip of their side of the base line.
  defp bar_shapes(assigns) do
    scene = assigns.scene
    marks = Enum.filter(scene.marks, &(&1.series.color == assigns.item.color))
    assigns = Map.put(assigns, :marks, marks)

    temple do
      for direction <- [1, -1], direction == 1 or scene.negative do
        g class: "chart-clip", style: clip(direction, scene.base) do
          for mark <- @marks do
            path class: "chart-bar chart-mark",
                 d: shape(mark.dx, mark.width, direction),
                 style: bar_style(scene, mark, "b", mark.tops, scene.base)
          end
        end
      end
    end
  end

  # The values of the bars of one series. A value moves with the end of its
  # bar.
  defp bar_values(assigns) do
    scene = assigns.scene
    marks = Enum.filter(scene.marks, &(&1.series.color == assigns.item.color))
    assigns = Map.put(assigns, :marks, marks)

    temple do
      for mark <- @marks do
        g class: "chart-mark", style: bar_style(scene, mark, "t", mark.labels, scene.base - 8) do
          c(&changing/1,
            rest!:
              text_assigns(
                Enum.map(mark.values, &Plot.label/1),
                mark.values,
                "n#{mark.series.color}-#{mark.category}",
                x: Plot.f(mark.dx + mark.width / 2),
                class: "chart-value",
                count: @count
              )
          )
        end
      end
    end
  end

  # The place of a bar or of its value: the center of its category, and the
  # channel of its end, which the effect `:grow` moves from the base line.
  defp bar_style(scene, mark, channel, values, from) do
    style([
      {"--chart-u", ref("x#{mark.category}", scene.xs[mark.category])},
      {"--chart-v", grow(ref("#{channel}#{mark.series.color}-#{mark.category}", values), from)}
    ])
  end

  # The clip of the bars up or of the bars down: the side of the base line
  # of their direction, in the units of the SVG. A clip with an `id` does not
  # work here, because the overview and the menu show copies of the slide.
  defp clip(1, base), do: "--chart-clip: inset(-100px -100px #{Plot.f(450 - base)}px -100px);"
  defp clip(-1, base), do: "--chart-clip: inset(#{Plot.f(base)}px -100px -100px -100px);"

  # The shape of a bar at the origin: a long rectangle with round corners at
  # its end. A bar up has its end at the top, and a bar down at the bottom.
  defp shape(x, width, direction) do
    radius = Enum.min([4, width / 2])
    right = x + width
    far = direction * @shape
    corner = direction * radius

    "M#{Plot.f(x)} #{far}V#{Plot.f(corner)}Q#{Plot.f(x)} 0 #{Plot.f(x + radius)} 0" <>
      "H#{Plot.f(right - radius)}Q#{Plot.f(right)} 0 #{Plot.f(right)} #{Plot.f(corner)}" <>
      "V#{far}Z"
  end

  defp lines(assigns) do
    scene = assigns.scene

    temple do
      for mark <- scene.marks do
        g class:
            Expresso.Element.classes(
              "chart-series chart-c#{mark.series.color}",
              mark.series.class
            ),
          rest!: mark.series.overlay do
          c(@legend_item, legend: @legend, series: mark.series)

          g class: "chart-trace" do
            for {{from, to}, i} <- Enum.with_index(Enum.zip(mark.points, tl(mark.points))) do
              line class: "chart-line chart-segment",
                   x1: 0,
                   y1: 0,
                   x2: 1,
                   y2: 0,
                   style:
                     style([
                       {"--chart-v", ref("p#{mark.series.color}-#{i}", from.ys)},
                       {"--chart-w", ref("p#{mark.series.color}-#{i + 1}", to.ys)},
                       {"--chart-x", Plot.f(from.x)},
                       {"--chart-dx", Plot.f(to.x - from.x)}
                     ])
            end

            for {point, i} <- Enum.with_index(mark.points) do
              circle class: "chart-dot chart-mark",
                     cx: 0,
                     cy: 0,
                     r: 5,
                     style:
                       style([
                         {"--chart-u", Plot.f(point.x)},
                         {"--chart-v", ref("p#{mark.series.color}-#{i}", point.ys)}
                       ])
            end

            g class: "chart-mark",
              style:
                style([
                  {"--chart-u", Plot.f(scene.end_x)},
                  {"--chart-v", ref("e#{mark.series.color}", mark.ends)}
                ]) do
              c(&changing/1,
                rest!:
                  text_assigns(
                    Enum.map(mark.values, &"#{mark.series.name} #{Plot.label(&1)}"),
                    mark.values,
                    "n#{mark.series.color}",
                    y: 5,
                    anchor: "start",
                    class: "chart-end",
                    prefix: "#{mark.series.name} ",
                    count: @count
                  )
              )
            end
          end
        end
      end
    end
  end

  # A pie of arcs. Each arc is a circle with a stroke as wide as the radius,
  # and its dash is the slice. A line of the color of the background parts
  # two slices, as the edge of a slice does in a pie without motion.
  defp pie(assigns) do
    scene = assigns.scene
    [series] = assigns.series
    cx = 40 + @radius
    cy = 450 / 2
    top = cy - length(assigns.categories) * 36 / 2

    assigns =
      Map.merge(assigns, %{
        item: series,
        cx: cx,
        cy: cy,
        top: top,
        radius_value: @radius,
        origin: "transform-origin: #{cx}px #{cy}px;"
      })

    temple do
      g class: Expresso.Element.classes("chart-series", @item.class), rest!: @item.overlay do
        for mark <- scene.marks do
          circle class: "chart-arc chart-c#{mark.category + 1}",
                 cx: @cx,
                 cy: @cy,
                 r: div(@radius_value, 2),
                 stroke_width: @radius_value,
                 style:
                   @origin <>
                     " " <>
                     style([
                       {"--chart-v", grow(ref("l#{mark.category}", mark.lengths), 0)},
                       {"--chart-w", grow(ref("a#{mark.category}", mark.starts), 0)}
                     ])
        end

        for mark <- scene.marks do
          line class: "chart-gap",
               x1: @cx,
               y1: @cy,
               x2: @cx,
               y2: @cy - @radius_value,
               style:
                 @origin <>
                   " " <>
                   style([{"--chart-w", grow(ref("a#{mark.category}", mark.starts), 0)}])
        end

        for {category, i} <- Enum.with_index(@categories) do
          rect class: "chart-swatch chart-c#{i + 1}",
               x: @cx + @radius_value + 60,
               y: Plot.f(@top + i * 36 + 4),
               width: 16,
               height: 16,
               rx: 3

          c(&changing/1,
            rest!:
              text_assigns(
                Enum.map(Enum.at(scene.marks, i).percents, &"#{category} #{Plot.label(&1)}%"),
                Enum.at(scene.marks, i).percents,
                "n#{i}",
                x: @cx + @radius_value + 88,
                y: Plot.f(@top + i * 36 + 18),
                anchor: "start",
                class: "chart-name",
                prefix: "#{category} ",
                suffix: "%",
                count: @count
              )
          )
        end
      end
    end
  end

  @doc false
  @spec radius() :: pos_integer()
  def radius, do: @radius
end
