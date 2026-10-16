defmodule Expresso.Element.Chart.Chord do
  @moduledoc """
  Draws a chord chart: the flows between the nodes of a graph, with the
  nodes on a ring

  A chord chart takes the flows of a sankey, as `flow` entities, categories
  and one series, or a CSV file. Use it for flows in the two directions
  between the same nodes, such as the trade between countries. A sankey can
  show these flows only with loops.

  The layout has these rules:

  1. Each node is an arc of a ring, from the top and clockwise, in the order
     of the data or the `order` of its node entity. The length of the arc is
     the sum of the flow out of the node and the flow into it.
  2. One scale sets the angles in all the frames. Thus a smaller total in a
     later frame leaves an empty part at the end of the ring.
  3. A flow is a chord between the arcs of its two nodes. It has the width of
     its value at each end. Two quadratic Bézier curves join the two ends,
     with their control point at the center of the ring. At its source, a
     chord is in the part of the arc for the flows out. At its target, it is
     in the part for the flows in.
  4. A chord has the color of its source.

  `render/1` draws each series as a group with its chords. The arcs and their
  labels show with the chart, so `reveal true` adds the chords of one source
  at each step. `Expresso.Element.Chart.Sankey.table/1` writes the table.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Layers, Plot, Sankey}

  # The box of the chart in the units of the SVG, the width of the ring, the
  # gap between two arcs in radians, the room for a label outside the ring,
  # and the least length of an arc with a label.
  @width 800
  @height 450
  @ring 16
  @pad 0.05
  @room 30
  @label 14

  @doc """
  Return the point at an angle and a radius from a center

  The angle 0 is at the top, and the angles go clockwise.

      iex> Expresso.Element.Chart.Chord.point({100, 100}, 0, 50)
      {100.0, 50.0}
      iex> Expresso.Element.Chart.Chord.point({100, 100}, :math.pi() / 2, 50)
      {150.0, 100.0}
  """
  @spec point({number(), number()}, number(), number()) :: {float(), float()}
  def point({cx, cy}, angle, radius),
    do: {cx + radius * :math.sin(angle), cy - radius * :math.cos(angle)}

  @doc """
  Place the arcs and the chords of each frame of a chord chart

  `frames` holds the links of each frame, with the value and the series of
  each link. `top` is the top of the box, and `settings` holds the node
  entities. The frames share the order and the colors of the nodes, and one
  scale.
  """
  @spec layout([[map()]], number(), map()) :: [%{arcs: [map()], chords: [map()]}]
  def layout(frames, top, settings) do
    frames = Enum.map(frames, fn links -> Enum.filter(links, &(&1.value > 0)) end)
    appearance = frames |> List.flatten() |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()
    order = sort(appearance, settings)
    totals = Enum.map(frames, &totals/1)
    largest = totals |> Enum.map(&(&1 |> Map.values() |> Enum.sum())) |> Enum.max()
    scale = (2 * :math.pi() - @pad * length(order)) / largest
    radius = (@height - 8 - top) / 2 - @room

    shared = %{
      order: order,
      appearance: appearance,
      scale: scale,
      center: {@width / 2, top + (@height - 8 - top) / 2},
      outer: radius,
      inner: radius - @ring,
      settings: settings
    }

    for {links, total} <- Enum.zip(frames, totals), do: frame(links, total, shared)
  end

  # The nodes in their order on the ring: the `order` of a node entity, else
  # the place of the node in the data.
  defp sort(appearance, settings) do
    appearance
    |> Enum.with_index(1)
    |> Enum.sort_by(fn {name, place} ->
      case settings do
        %{^name => %{order: order}} when order != nil -> {order, place}
        _other -> {place, place}
      end
    end)
    |> Enum.map(&elem(&1, 0))
  end

  # The flow out of each node and the flow into it together.
  defp totals(links) do
    Enum.reduce(links, %{}, fn link, totals ->
      totals
      |> Map.update(link.from, link.value, &(&1 + link.value))
      |> Map.update(link.to, link.value, &(&1 + link.value))
    end)
  end

  defp frame(links, total, shared) do
    {arcs, _end} =
      shared.order
      |> Enum.filter(&Map.has_key?(total, &1))
      |> Enum.map_reduce(0, fn name, start ->
        size = total[name] * shared.scale
        {{name, start, start + size}, start + size + @pad}
      end)

    starts = Map.new(arcs, fn {name, start, _end} -> {name, start} end)
    place = Map.new(Enum.with_index(shared.order))
    ends = ends(links, starts, place, shared.scale)

    %{
      arcs: Enum.map(arcs, &arc(&1, links, total, shared)),
      chords:
        Enum.map(links, fn link ->
          Map.merge(link, %{
            d: chord(ends[{:out, link}], ends[{:in, link}], shared),
            color: color(link.from, shared)
          })
        end)
    }
  end

  # The span of each end of each chord. In the arc of a node, the flows out
  # come first, then the flows in. Each part has the counterclockwise order
  # of the other nodes, from the nearest one. Thus the chords of an arc do
  # not cross.
  defp ends(links, starts, place, scale) do
    count = map_size(place)
    away = fn name, other -> -rem(place[other] - place[name] + count, count) end

    for {name, start} <- starts, reduce: %{} do
      ends ->
        outs =
          links
          |> Enum.filter(&(&1.from == name))
          |> Enum.sort_by(&away.(name, &1.to))
          |> Enum.map(&{:out, &1})

        ins =
          links
          |> Enum.filter(&(&1.to == name))
          |> Enum.sort_by(&away.(name, &1.from))
          |> Enum.map(&{:in, &1})

        (outs ++ ins)
        |> Enum.reduce({ends, start}, fn {_side, link} = key, {ends, angle} ->
          size = link.value * scale
          {Map.put(ends, key, {angle, angle + size}), angle + size}
        end)
        |> elem(0)
    end
  end

  defp color(name, shared) do
    shared.appearance |> Enum.find_index(&(&1 == name)) |> Layers.color()
  end

  defp arc({name, start, stop}, links, total, shared) do
    setting = Map.get(shared.settings, name, %{label: nil, class: nil})
    middle = (start + stop) / 2
    {x, y} = point(shared.center, middle, shared.outer + 10)

    %{
      name: name,
      label: setting.label || name,
      class: setting.class,
      value: total[name],
      color: color(name, shared),
      series: links |> Enum.filter(&(&1.from == name or &1.to == name)) |> series(),
      d: ring(start, stop, shared),
      labeled: (stop - start) * shared.outer >= @label,
      label_x: x,
      label_y: y + 7 + 8 * -:math.cos(middle),
      anchor: if(:math.sin(middle) >= 0, do: "start", else: "end")
    }
  end

  defp series(links), do: links |> Enum.map(& &1.series) |> Enum.min()

  # The shape of an arc of the ring, from the angle start to the angle stop.
  defp ring(start, stop, shared) do
    f = &Plot.f/1
    large = if stop - start > :math.pi(), do: 1, else: 0
    {x0, y0} = point(shared.center, start, shared.outer)
    {x1, y1} = point(shared.center, stop, shared.outer)
    {x2, y2} = point(shared.center, stop, shared.inner)
    {x3, y3} = point(shared.center, start, shared.inner)
    r = f.(shared.outer)
    q = f.(shared.inner)

    "M#{f.(x0)},#{f.(y0)} A#{r},#{r} 0 #{large} 1 #{f.(x1)},#{f.(y1)} " <>
      "L#{f.(x2)},#{f.(y2)} A#{q},#{q} 0 #{large} 0 #{f.(x3)},#{f.(y3)} Z"
  end

  @doc """
  Return the shape of a chord between two spans of the inner edge of the
  ring

  Each span is a pair of angles. The shape follows the first span, goes to
  the second span on a quadratic Bézier curve with its control point at the
  center, follows the second span, and goes back on a second curve.
  """
  @spec chord({number(), number()}, {number(), number()}, map()) :: String.t()
  def chord({s0, s1}, {t0, t1}, shared) do
    f = &Plot.f/1
    r = f.(shared.inner)
    {cx, cy} = shared.center
    point = fn angle -> point(shared.center, angle, shared.inner) end
    {a, b} = point.(s0)
    {c, d} = point.(s1)
    {e, g} = point.(t0)
    {h, i} = point.(t1)
    large = fn from, to -> if to - from > :math.pi(), do: 1, else: 0 end

    "M#{f.(a)},#{f.(b)} A#{r},#{r} 0 #{large.(s0, s1)} 1 #{f.(c)},#{f.(d)} " <>
      "Q#{f.(cx)},#{f.(cy)} #{f.(e)},#{f.(g)} " <>
      "A#{r},#{r} 0 #{large.(t0, t1)} 1 #{f.(h)},#{f.(i)} " <>
      "Q#{f.(cx)},#{f.(cy)} #{f.(a)},#{f.(b)} Z"
  end

  @doc """
  Draw the arcs, the chords and the labels of a chord chart in its SVG

  The assigns are the assigns of `Expresso.Element.Chart`. A chart with
  frames has one layer for each frame, as a sankey has.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{frames: frames} = assigns) do
    layouts =
      frames
      |> Enum.map(&Layers.links(assigns.categories, &1.values))
      |> layout(assigns.box.top, assigns.node_settings)

    Layers.render(assigns, layouts, &drawing/1)
  end

  defp drawing(assigns) do
    temple do
      for {series, number} <- @numbered do
        g class: Expresso.Element.classes("chart-series", series.class), rest!: series.overlay do
          for chord <- @chords, chord.series == number do
            path class: "chart-link chart-chord chart-c#{chord.color}",
                 d: chord.d,
                 data_keys: Layers.key(assigns, [chord.from, chord.to])
          end
        end
      end

      g class: "chart-nodes" do
        for arc <- @arcs do
          path class: Expresso.Element.classes("chart-node chart-c#{arc.color}", arc.class),
               d: arc.d,
               data_keys: Layers.key(assigns, [arc.name])
        end

        for arc <- @arcs, arc.labeled do
          text class: "chart-node-label",
               data_keys: Layers.key(assigns, [arc.name]),
               x: Plot.f(arc.label_x),
               y: Plot.f(arc.label_y),
               text_anchor: arc.anchor do
            Sankey.label_text(arc, @values)
          end
        end
      end
    end
  end
end
