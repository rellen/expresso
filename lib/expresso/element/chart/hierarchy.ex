defmodule Expresso.Element.Chart.Hierarchy do
  @moduledoc """
  The treemap and the sunburst: charts of the parts of a whole in groups

  A category with a slash names a part in a group, such as
  `"Production/Press"`, and the `separator` option of the chart can give a
  different text than the slash. A category can also be a list of its
  levels, such as `["Production", "Press"]`, and the `levels` option reads
  such lists from the columns of a CSV file. The categories therefore give a
  tree, and the one series gives the value of each leaf. A group has the sum
  of its parts.

  A treemap divides its box into rectangles in proportion to the values, with
  the squarified layout of Bruls, Huizing and van Wijk, so the rectangles are
  close to squares. A group holds its parts, with its name in a strip at its
  top. A sunburst draws each level of the tree as a ring around a center, and
  each part as an arc of its ring.

  Each top-level group has a color of the palette, and its parts have lighter
  tints of the same color. The drawing uses the channels of
  `Expresso.Element.Chart.Motion`, so the parts move from frame to frame, and
  the effect `:grow` opens the chart.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Motion, Plot}

  # The most groups at the top level, one for each color of the palette.
  @groups 8

  # The center, the radius of the hole and the outer radius of a sunburst.
  @cx 230
  @cy 230
  @hole 50
  @outer 210

  @typedoc "A part of the tree, or a group of parts"
  @type part :: %{
          name: String.t(),
          id: pos_integer(),
          index: non_neg_integer() | nil,
          depth: pos_integer(),
          color: pos_integer(),
          children: [part()]
        }

  @doc """
  Check the categories of a treemap or a sunburst

  A category is a string with the separator between its levels, such as
  `"A/x"`, or a list of its levels, such as `["A", "x"]`. Each level has a
  name, each category shows one time, a category is not also a group of
  another category, and the top level has at most 8 groups.

      iex> Expresso.Element.Chart.Hierarchy.check(["A/x", "A/y", "B"], "/")
      :ok

      iex> Expresso.Element.Chart.Hierarchy.check([["A", "x"], ["A", "y"], ["B"]], "/")
      :ok

      iex> Expresso.Element.Chart.Hierarchy.check(["A", "A/x"], "/")
      {:error, "the category \\"A\\" is a group of \\"A/x\\", so it takes no value of its own. Give the value to a part, such as \\"A/Other\\"."}
  """
  @spec check([String.t() | [String.t()]], String.t()) :: :ok | {:error, String.t()}
  def check(categories, separator) do
    paths = Enum.map(categories, &path(&1, separator))
    name = &Enum.join(&1, separator)
    roots = paths |> Enum.map(&List.first/1) |> Enum.uniq()

    cond do
      empty = Enum.find(paths, &(&1 == [] or "" in &1)) ->
        {:error, "the category \"#{name.(empty)}\" has a level with no name"}

      path = duplicate(paths) ->
        {:error, "the category \"#{name.(path)}\" shows two times"}

      conflict = conflict(paths) ->
        {group, part} = conflict

        {:error,
         "the category \"#{name.(group)}\" is a group of \"#{name.(part)}\", so it takes no " <>
           "value of its own. Give the value to a part, such as \"#{name.(group ++ ["Other"])}\"."}

      length(roots) > @groups ->
        {:error,
         "a treemap or a sunburst has at most #{@groups} groups at the top level, one for " <>
           "each color. Put the smallest into a group \"Other\"."}

      true ->
        :ok
    end
  end

  @doc """
  Return the levels of a category: the parts of a string between two
  separators, or the names of a list, with no spaces at their ends

      iex> Expresso.Element.Chart.Hierarchy.path("Production > Press", " > ")
      ["Production", "Press"]

      iex> Expresso.Element.Chart.Hierarchy.path(["I/O", " Disks "], "/")
      ["I/O", "Disks"]
  """
  @spec path(String.t() | [String.t()], String.t()) :: [String.t()]
  def path(category, _separator) when is_list(category), do: Enum.map(category, &String.trim/1)

  def path(category, separator),
    do: category |> String.split(separator) |> Enum.map(&String.trim/1)

  defp duplicate(paths) do
    paths |> Enum.frequencies() |> Enum.find_value(fn {path, count} -> count > 1 && path end)
  end

  defp conflict(paths) do
    Enum.find_value(paths, fn group ->
      part =
        Enum.find(paths, &(length(&1) > length(group) and Enum.take(&1, length(group)) == group))

      part && {group, part}
    end)
  end

  @doc """
  Make the tree of the categories

  Each part has an `id` in the order of the tree, a parent before its parts,
  and a leaf has the `index` of its category. The parts of a group keep the
  order of their first category. Call `check/2` first.
  """
  @spec tree([String.t() | [String.t()]], String.t()) :: [part()]
  def tree(categories, separator) do
    categories
    |> Enum.with_index()
    |> Enum.map(fn {category, index} -> {path(category, separator), index} end)
    |> build(1)
    |> Enum.with_index(1)
    |> Enum.map(fn {part, color} -> paint(part, color) end)
    |> number()
  end

  defp build(entries, depth) do
    entries
    |> Enum.group_by(fn {[first | _rest], _index} -> first end)
    |> Enum.sort_by(fn {_name, [{_path, index} | _more]} -> index end)
    |> Enum.map(fn {name, members} -> part(name, members, depth) end)
  end

  # A part with one category of its own name is a leaf. Other members are its
  # parts. `check/1` refuses a name that is both.
  defp part(name, [{[name], index}], depth),
    do: %{name: name, index: index, depth: depth, children: []}

  defp part(name, members, depth) do
    deeper = for {[_name | rest], index} <- members, do: {rest, index}
    %{name: name, index: nil, depth: depth, children: build(deeper, depth + 1)}
  end

  defp paint(part, color) do
    %{part | children: Enum.map(part.children, &paint(&1, color))} |> Map.put(:color, color)
  end

  defp number(parts) do
    {parts, _next} = Enum.map_reduce(parts, 1, &number/2)
    parts
  end

  defp number(part, next) do
    {children, after_children} = Enum.map_reduce(part.children, next + 1, &number/2)
    {Map.merge(part, %{id: next, children: children}), after_children}
  end

  @doc """
  Return each part of the tree, a parent before its parts
  """
  @spec flatten([part()]) :: [part()]
  def flatten(parts), do: Enum.flat_map(parts, &[&1 | flatten(&1.children)])

  # The value of a part in a frame: the value of its category, or the sum of
  # its parts.
  defp value(%{index: nil, children: children}, values),
    do: children |> Enum.map(&value(&1, values)) |> Enum.sum()

  defp value(%{index: index}, values), do: Enum.at(values, index)

  # The parts of each group in order of their values in the first frame, from
  # the largest. The order stays the same in each frame, so a part moves and
  # changes its size, and it does not jump to a different place.
  defp order(parts, first) do
    parts
    |> Enum.map(&%{&1 | children: order(&1.children, first)})
    |> Enum.with_index()
    |> Enum.sort_by(fn {part, index} -> {-value(part, first), index} end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Return the places of the parts of a chart in each frame, and the channels

  `Expresso.Element.Chart.Motion` calls this function for a treemap and for a
  sunburst.
  """
  @spec scene(map()) :: map()
  def scene(%{categories: categories, frames: frames} = assigns) do
    values = Enum.map(frames, fn %{values: [values]} -> values end)
    parts = categories |> tree(assigns.separator) |> order(hd(values))
    scene(assigns.kind, assigns, parts, values)
  end

  defp scene(:treemap, assigns, parts, values) do
    places = Enum.map(values, &treemap(parts, assigns.box, &1, assigns.values))
    all = flatten(parts)

    channels =
      Enum.flat_map(all, fn %{id: id} = part ->
        boxes = Enum.map(places, &Map.fetch!(&1, id))

        [
          {"rx#{id}", Enum.map(boxes, & &1.x)},
          {"ry#{id}", Enum.map(boxes, & &1.y)},
          {"rw#{id}", Enum.map(boxes, & &1.w)},
          {"rh#{id}", Enum.map(boxes, & &1.h)},
          {"ro#{id}", Enum.map(boxes, &if(&1.label, do: 1, else: 0))},
          {"n#{id}", Enum.map(values, &value(part, &1))}
        ]
      end) ++ Motion.flags(assigns.frames)

    %{parts: parts, all: all, places: places, values: values, channels: channels}
  end

  defp scene(:sunburst, assigns, parts, values) do
    depth = parts |> flatten() |> Enum.map(& &1.depth) |> Enum.max()
    ring = (@outer - @hole) / depth
    places = Enum.map(values, &sunburst(parts, 0, 360, &1, ring))
    all = flatten(parts)

    channels =
      Enum.flat_map(all, fn %{id: id} = part ->
        arcs = Enum.map(places, &Map.fetch!(&1, id))

        [
          {"sl#{id}", Enum.map(arcs, & &1.length)},
          {"sa#{id}", Enum.map(arcs, & &1.start)},
          {"su#{id}", Enum.map(arcs, & &1.x)},
          {"sv#{id}", Enum.map(arcs, & &1.y)},
          {"so#{id}", Enum.map(arcs, &if(&1.label, do: 1, else: 0))},
          {"n#{id}", Enum.map(values, &share(part, &1))}
        ]
      end) ++ Motion.flags(assigns.frames)

    %{parts: parts, all: all, places: places, ring: ring, values: values, channels: channels}
  end

  defp share(part, values),
    do: Float.round(value(part, values) / Enum.sum(values) * 100, 1)

  # The rectangles of the parts of a treemap in one frame, as a map from the
  # id of a part to its box and whether its label fits. A part with no value
  # gets a box with no size at the corner of its group.
  defp treemap(parts, box, values, numbers?) do
    rect = %{x: box.left, y: box.top, w: box.right - box.left, h: box.bottom - box.top}
    place_parts(parts, rect, values, numbers?)
  end

  defp place_parts(parts, rect, values, numbers?) do
    total = parts |> Enum.map(&value(&1, values)) |> Enum.sum()
    scale = if total > 0, do: rect.w * rect.h / total, else: 0
    sized = for part <- parts, do: {part, value(part, values) * scale}
    {full, empty} = Enum.split_with(sized, fn {_part, area} -> area > 0 end)

    placed =
      squarify(full, rect) ++
        for {part, _area} <- empty, do: {part, %{x: rect.x, y: rect.y, w: 0, h: 0}}

    Enum.reduce(placed, %{}, fn {part, box}, places ->
      Map.merge(places, place_part(part, box, values, numbers?))
    end)
  end

  # A leaf keeps a gap of one unit on each side. A group has a strip for its
  # name at its top when it has room for it, and its parts go inside.
  defp place_part(%{children: []} = part, box, values, numbers?) do
    box = inset(box, 1, 1)
    lines = if numbers?, do: 46, else: 26
    text = max(String.length(part.name), String.length(Plot.label(value(part, values))))
    label = box.h >= lines and box.w >= 12 + 10.5 * text
    %{part.id => Map.put(box, :label, label)}
  end

  defp place_part(part, box, values, numbers?) do
    box = inset(box, 1, 1)
    strip = if box.h >= 56 and box.w >= 48, do: 22, else: 0
    label = strip > 0 and box.w >= 12 + 9.5 * String.length(part.name)
    inner = %{inset(box, 3, 3) | y: box.y + strip + 3, h: max(box.h - strip - 6, 0)}

    part.children
    |> place_parts(inner, values, numbers?)
    |> Map.put(part.id, Map.put(box, :label, label))
  end

  defp inset(box, dx, dy) do
    %{
      x: box.x + min(dx, box.w / 2),
      y: box.y + min(dy, box.h / 2),
      w: max(box.w - 2 * dx, 0),
      h: max(box.h - 2 * dy, 0)
    }
  end

  @doc """
  Divide a rectangle into rectangles of the given areas, close to squares

  The items are pairs of a key and an area, from the largest, and the sum of
  the areas is the area of the rectangle. This is the squarified layout of
  Bruls, Huizing and van Wijk.

      iex> Expresso.Element.Chart.Hierarchy.squarify([{:a, 6}, {:b, 2}], %{x: 0, y: 0, w: 4, h: 2})
      [{:a, %{x: 0, y: 0, w: 3.0, h: 2.0}}, {:b, %{x: 3.0, y: 0, w: 1.0, h: 2.0}}]
  """
  @spec squarify([{term(), number()}], map()) :: [{term(), map()}]
  def squarify([], _rect), do: []

  def squarify(items, %{w: w, h: h} = rect) when w <= 0 or h <= 0,
    do: for({key, _area} <- items, do: {key, %{x: rect.x, y: rect.y, w: 0, h: 0}})

  def squarify(items, rect) do
    side = min(rect.w, rect.h)
    {row, rest} = row(items, [], side)
    {placed, rest_rect} = lay(Enum.reverse(row), rect)
    placed ++ squarify(rest, rest_rect)
  end

  defp row([], row, _side), do: {row, []}

  defp row([item | rest] = items, row, side) do
    if row == [] or worst([item | row], side) <= worst(row, side),
      do: row(rest, [item | row], side),
      else: {row, items}
  end

  defp worst(row, side) do
    areas = Enum.map(row, &elem(&1, 1))
    sum = Enum.sum(areas)
    max(side * side * Enum.max(areas) / (sum * sum), sum * sum / (side * side * Enum.min(areas)))
  end

  # A row along the short side of the rectangle: a column at the left of a
  # wide rectangle, or a row at the top of a tall rectangle.
  defp lay(row, rect) do
    sum = row |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    if rect.w >= rect.h do
      width = sum / rect.h

      {placed, _y} =
        Enum.map_reduce(row, rect.y, fn {key, area}, y ->
          {{key, %{x: rect.x, y: y, w: width, h: area / width}}, y + area / width}
        end)

      {placed, %{rect | x: rect.x + width, w: rect.w - width}}
    else
      height = sum / rect.w

      {placed, _x} =
        Enum.map_reduce(row, rect.x, fn {key, area}, x ->
          {{key, %{x: x, y: rect.y, w: area / height, h: height}}, x + area / height}
        end)

      {placed, %{rect | y: rect.y + height, h: rect.h - height}}
    end
  end

  # The arcs of the parts of a sunburst in one frame: the start in degrees
  # from the top, the length of the dash on the circle of its ring, the
  # place of its label, and whether its label fits.
  defp sunburst(parts, from, sweep, values, ring) do
    total = parts |> Enum.map(&value(&1, values)) |> Enum.sum()

    {arcs, _start} =
      Enum.reduce(parts, {%{}, from}, fn part, {arcs, start} ->
        angle = if total > 0, do: sweep * value(part, values) / total, else: 0
        arcs = Map.put(arcs, part.id, arc(part, start, angle, ring))
        {Map.merge(arcs, sunburst(part.children, start, angle, values, ring)), start + angle}
      end)

    arcs
  end

  defp arc(part, start, angle, ring) do
    middle = @hole + (part.depth - 0.5) * ring
    turn = (start + angle / 2) * :math.pi() / 180
    length = angle / 360 * 2 * :math.pi() * middle

    %{
      start: start,
      length: length,
      x: @cx + middle * :math.sin(turn),
      y: @cy - middle * :math.cos(turn),
      label: ring >= 24 and length >= 10 + 10 * String.length(part.name)
    }
  end

  @doc """
  Draw a treemap or a sunburst
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{kind: :treemap} = assigns), do: treemap_marks(assigns)
  def render(%{kind: :sunburst} = assigns), do: sunburst_marks(assigns)

  defp treemap_marks(assigns) do
    scene = assigns.scene
    [series] = assigns.series
    assigns = Map.put(assigns, :item, series)

    temple do
      g class: Expresso.Element.classes("chart-series", @item.class), rest!: @item.overlay do
        for root <- scene.parts do
          g class: "chart-c#{root.color}" do
            for part <- flatten([root]) do
              rect class: if(part.children == [], do: "chart-tile", else: "chart-group"),
                   x: 0,
                   y: 0,
                   width: 1,
                   height: 1,
                   style: box_style(part, scene)
            end

            for part <- flatten([root]) do
              c(&treemap_label/1, rest!: Map.merge(assigns, %{part: part}))
            end
          end
        end
      end
    end
  end

  defp box_style(part, scene) do
    channel = fn name, key -> Motion.ref("#{name}#{part.id}", places(scene, part, key)) end

    Motion.style([
      {"--chart-u", channel.("rx", :x)},
      {"--chart-v", channel.("ry", :y)},
      {"--chart-w", Motion.grow(channel.("rw", :w), 0)},
      {"--chart-h", Motion.grow(channel.("rh", :h), 0)}
    ])
  end

  # The value of a key of the place of a part in each frame: of its box in a
  # treemap, or of its arc in a sunburst.
  defp places(scene, part, key),
    do: Enum.map(scene.places, &(&1 |> Map.fetch!(part.id) |> Map.fetch!(key)))

  # 1 in each frame where the label of a part fits its place, else 0.
  defp shown(scene, part) do
    Enum.map(scene.places, &if(Map.fetch!(&1, part.id).label, do: 1, else: 0))
  end

  # The name and the value of a leaf at its top left, or the name of a group
  # in its strip. A label that does not fit its box in a frame does not show
  # in that frame: `--chart-h` holds 1 or 0. With the effect `:grow`, a label
  # shows after its box grows: the theme moves `--chart-w` of the label from 0
  # to 1 after the time of the growth.
  defp treemap_label(assigns) do
    %{part: part, scene: scene} = assigns
    numbers = Enum.map(scene.values, &value(part, &1))

    style =
      Motion.style([
        {"--chart-u", Motion.ref("rx#{part.id}", places(scene, part, :x))},
        {"--chart-v", Motion.ref("ry#{part.id}", places(scene, part, :y))},
        {"--chart-h", Motion.ref("ro#{part.id}", shown(scene, part))}
      ])

    assigns = Map.merge(assigns, %{label_style: style, numbers: numbers})

    temple do
      g class: "chart-mark chart-label", style: @label_style do
        if @part.children == [] do
          text x: 6, y: 20, class: "chart-part" do
            @part.name
          end

          if @values do
            c(&Motion.changing/1,
              rest!:
                Motion.text_assigns(
                  Enum.map(@numbers, &Plot.label/1),
                  @numbers,
                  "n#{@part.id}",
                  x: 6,
                  y: 40,
                  anchor: "start",
                  class: "chart-part-value",
                  count: @count
                )
            )
          end
        else
          text x: 6, y: 16, class: "chart-head" do
            @part.name
          end
        end
      end
    end
  end

  defp sunburst_marks(assigns) do
    scene = assigns.scene
    [series] = assigns.series
    roots = scene.parts
    top = @cy - length(roots) * 36 / 2

    assigns =
      Map.merge(assigns, %{
        item: series,
        roots: roots,
        top: top,
        origin: "transform-origin: #{@cx}px #{@cy}px;",
        cx: @cx,
        cy: @cy,
        legend_x: @cx + @outer + 50
      })

    temple do
      g class: Expresso.Element.classes("chart-series", @item.class), rest!: @item.overlay do
        for part <- scene.all do
          circle class: "chart-ring chart-c#{part.color} chart-depth-#{min(part.depth, 3)}",
                 cx: @cx,
                 cy: @cy,
                 r: Plot.f(middle(part, scene.ring)),
                 stroke_width: Plot.f(scene.ring - 2),
                 style:
                   @origin <>
                     " " <>
                     Motion.style([
                       {"--chart-v",
                        Motion.grow(Motion.ref("sl#{part.id}", places(scene, part, :length)), 0)},
                       {"--chart-w",
                        Motion.grow(Motion.ref("sa#{part.id}", places(scene, part, :start)), 0)}
                     ])
        end

        for part <- scene.all do
          line class: "chart-gap",
               x1: @cx,
               y1: Plot.f(@cy - (middle(part, scene.ring) - scene.ring / 2)),
               x2: @cx,
               y2: Plot.f(@cy - (middle(part, scene.ring) + scene.ring / 2)),
               style:
                 @origin <>
                   " " <>
                   Motion.style([
                     {"--chart-w",
                      Motion.grow(Motion.ref("sa#{part.id}", places(scene, part, :start)), 0)}
                   ])
        end

        for part <- scene.all do
          g class: "chart-mark chart-label",
            style:
              Motion.style([
                {"--chart-u", Motion.ref("su#{part.id}", places(scene, part, :x))},
                {"--chart-v", Motion.ref("sv#{part.id}", places(scene, part, :y))},
                {"--chart-h", Motion.ref("so#{part.id}", shown(scene, part))}
              ]) do
            text x: 0, y: 6, text_anchor: "middle", class: "chart-part" do
              part.name
            end
          end
        end

        for {root, i} <- Enum.with_index(@roots) do
          rect class: "chart-swatch chart-c#{root.color}",
               x: @legend_x,
               y: Plot.f(@top + i * 36 + 4),
               width: 16,
               height: 16,
               rx: 3

          c(&Motion.changing/1,
            rest!:
              Motion.text_assigns(
                Enum.map(@scene.values, &"#{root.name} #{Plot.label(share(root, &1))}%"),
                Enum.map(@scene.values, &share(root, &1)),
                "n#{root.id}",
                x: @legend_x + 28,
                y: Plot.f(@top + i * 36 + 18),
                anchor: "start",
                class: "chart-name",
                prefix: "#{root.name} ",
                suffix: "%",
                count: @count
              )
          )
        end
      end
    end
  end

  defp middle(part, ring), do: @hole + (part.depth - 0.5) * ring
end
