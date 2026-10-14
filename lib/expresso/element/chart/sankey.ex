defmodule Expresso.Element.Chart.Sankey do
  @moduledoc """
  Draws a sankey chart: the flows between the nodes of a graph

  A category of a sankey is a path of two nodes or more, such as
  `["Coal", "Electricity"]` or `"Gas/Electricity/Homes"`. Its value goes
  along each link of the path. `links/3` adds the values of the same link.
  Thus a CSV file can hold one row for each flow, or one row for each record
  of a path with the `levels` option.

  The layout has these rules:

  1. A node with no flow into it is in the first column. Each other node is
     one column after its last source. Thus a link can go across a column.
     The `column` of a node entity sets the column of its node.
  2. The height of a node is the larger of the flow into it and the flow out
     of it. One scale sets the height of each node, and the fullest column
     fills the height of the chart. The nodes of each column are in the
     vertical middle of the chart.
  3. The nodes of a column keep the order of the data, or the `order` of
     their node entity. At each node, the links have the order of their
     other ends, from the top, so few links cross.
  4. A link is a ribbon between two cubic Bézier curves. The control points
     are at the middle between the two columns, so a link leaves and enters
     each node horizontally. The ribbon is a filled shape, and not a thick
     stroke, so its height is its value at each point.

  An alluvial chart has one node for each name in each column: the column of
  a node is its place in the path, so the same name in two columns gives two
  nodes. Its node is the tuple `{column, name}`, as `links/4` returns it. The
  nodes of one name have one color and one place in each column.

  A graph with a loop has no first column, so `check/4` refuses it. The
  frames of a chart share the columns, the order and the scale of the nodes,
  as `layout_frames/2` returns them. Each frame is a layer, and the opacity
  of the layers changes from one frame to the next.

  `render/1` draws each series of the chart as a group. The group holds the
  links of the series and the nodes that show first with it. The node labels
  of each series are in a group after the links, with the same steps.
  `table/1` writes a row for each link for a screen reader.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Motion, Plot}

  @typedoc "A node: its name, or its column from 0 and its name in an alluvial chart"
  @type key :: String.t() | {non_neg_integer(), String.t()}

  @typedoc "A link: two nodes and a value"
  @type link :: %{from: key(), to: key(), value: number()}

  # The box of the chart in the units of the SVG, the width of a node, the
  # gap between two nodes of a column, and the least height of a node with a
  # label.
  @width 800
  @height 450
  @node 16
  @gap 14
  @label 16

  # The least distance between the middles of two labels in a column: the
  # height of one line of a label.
  @line 22

  # The width of one character of a label, a little more than the mean
  # width of the font.
  @character 10

  @doc """
  Return the nodes of a category of a sankey, as a list of names

  A category is a list of names, or a string with the separator between two
  names. The spaces next to a name do not count. A path of an alluvial chart
  after the check holds its nodes, and the function returns them.

      iex> Expresso.Element.Chart.Sankey.path("Gas / Electricity", "/")
      ["Gas", "Electricity"]
      iex> Expresso.Element.Chart.Sankey.path(["I/O", "Disks"], "/")
      ["I/O", "Disks"]
  """
  @spec path(String.t() | [String.t()] | [key()], String.t()) :: [key()]
  def path([{_column, _name} | _] = nodes, _separator), do: nodes
  def path(category, _separator) when is_list(category), do: Enum.map(category, &String.trim/1)

  def path(category, separator),
    do: category |> String.split(separator) |> Enum.map(&String.trim/1)

  @doc """
  Make sure that the categories and the values make a graph with no loop

  Each category names two nodes or more, each node has a name, and no link
  goes from a node to the same node. Each value is zero or more, and their
  sum is more than zero. With `alluvial` true, each column has its own
  nodes, so a name can follow the same name and no loop can occur.

      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], "B/C"], [1, 2], "/")
      :ok
      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], ["B", "A"]], [1, 2], "/")
      {:error, "the flows of a sankey make a loop: A → B → A. A sankey goes in one direction, so give a node in the loop a different name, such as \\"A (again)\\"."}
      iex> Expresso.Element.Chart.Sankey.check([["A", "A"], ["A", "B"]], [1, 2], "/", true)
      :ok
  """
  @spec check([String.t() | [String.t()]], [number()], String.t(), boolean()) ::
          :ok | {:error, String.t()}
  def check(categories, values, separator, alluvial \\ false) do
    paths = Enum.map(categories, &path(&1, separator))

    cond do
      short = Enum.find(paths, &(length(&1) < 2)) ->
        {:error,
         "the category #{inspect(Enum.join(short, separator))} of a sankey names one node. " <>
           "A category is a path of two nodes or more, such as [\"Coal\", \"Electricity\"]."}

      Enum.any?(paths, &Enum.member?(&1, "")) ->
        {:error, "a node of a sankey has no name"}

      alluvial ->
        values_check(values)

      same = Enum.find_value(paths, &same_node/1) ->
        {:error,
         "a flow of a sankey goes from \"#{same}\" to \"#{same}\". A flow goes to another node."}

      values_check(values) != :ok ->
        values_check(values)

      true ->
        loop(paths)
    end
  end

  defp values_check(values) do
    if Enum.any?(values, &(&1 < 0)) or Enum.sum(values) <= 0,
      do: {:error, "the values of a sankey are zero or more, and their sum is more than zero"},
      else: :ok
  end

  defp same_node(path) do
    path |> Enum.chunk_every(2, 1, :discard) |> Enum.find_value(fn [a, b] -> a == b and a end)
  end

  defp loop(paths) do
    edges = paths |> Enum.flat_map(&Enum.chunk_every(&1, 2, 1, :discard)) |> Enum.uniq()

    case cycle(edges) do
      nil ->
        :ok

      [first | _] = nodes ->
        {:error,
         "the flows of a sankey make a loop: #{Enum.join(nodes ++ [first], " → ")}. " <>
           "A sankey goes in one direction, so give a node in the loop a different name, " <>
           "such as #{inspect(first <> " (again)")}."}
    end
  end

  # A loop of the graph as a list of its nodes, or nil. A depth-first search
  # finds a link back to a node on the path of the search.
  defp cycle(edges) do
    next = Enum.group_by(edges, &hd/1, &List.last/1)
    nodes = edges |> List.flatten() |> Enum.uniq()

    Enum.reduce_while(nodes, MapSet.new(), fn node, done ->
      case visit(node, next, [], done) do
        {:loop, loop} -> {:halt, {:loop, loop}}
        {:ok, done} -> {:cont, done}
      end
    end)
    |> case do
      {:loop, loop} -> loop
      _done -> nil
    end
  end

  defp visit(node, next, path, done) do
    cond do
      node in path ->
        {:loop, path |> Enum.reverse() |> Enum.drop_while(&(&1 != node))}

      MapSet.member?(done, node) ->
        {:ok, done}

      true ->
        case children(node, next, path, done) do
          {:ok, done} -> {:ok, MapSet.put(done, node)}
          loop -> loop
        end
    end
  end

  defp children(node, next, path, done) do
    next
    |> Map.get(node, [])
    |> Enum.reduce_while({:ok, done}, fn child, {:ok, done} ->
      case visit(child, next, [node | path], done) do
        {:ok, done} -> {:cont, {:ok, done}}
        loop -> {:halt, loop}
      end
    end)
  end

  @doc """
  Return the links of the paths, with the sum of the values of each link

  The links keep the order of their first path, and each pair of neighbors
  in a path is a link. With `alluvial` true, each node is the tuple of its
  place in the path and its name.

      iex> Expresso.Element.Chart.Sankey.links([["A", "B", "C"], ["A", "B"]], [2, 3], "/")
      [%{from: "A", to: "B", value: 5}, %{from: "B", to: "C", value: 2}]
      iex> Expresso.Element.Chart.Sankey.links([["A", "A"]], [2], "/", true)
      [%{from: {0, "A"}, to: {1, "A"}, value: 2}]
  """
  @spec links([String.t() | [String.t()]], [number()], String.t(), boolean()) :: [link()]
  def links(categories, values, separator, alluvial \\ false) do
    categories
    |> Enum.zip(values)
    |> Enum.flat_map(fn {category, value} ->
      category
      |> path(separator)
      |> nodes(alluvial)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [from, to] -> {{from, to}, value} end)
    end)
    |> Enum.reduce({[], %{}}, fn {key, value}, {order, sums} ->
      order = if Map.has_key?(sums, key), do: order, else: [key | order]
      {order, Map.update(sums, key, value, &(&1 + value))}
    end)
    |> then(fn {order, sums} ->
      order
      |> Enum.reverse()
      |> Enum.map(fn {from, to} = key -> %{from: from, to: to, value: sums[key]} end)
    end)
  end

  defp nodes([{_column, _name} | _] = path, true), do: path
  defp nodes(path, true), do: Enum.with_index(path, fn name, column -> {column, name} end)
  defp nodes(path, false), do: path

  @doc """
  Return the name of a node

      iex> Expresso.Element.Chart.Sankey.name("Gas")
      "Gas"
      iex> Expresso.Element.Chart.Sankey.name({2, "Gas"})
      "Gas"
  """
  @spec name(key()) :: String.t()
  def name({_column, name}), do: name
  def name(name), do: name

  @doc """
  Return the column of each node, from 0

  A node with no link into it is in column 0, and each other node is one
  column after its furthest source. `pinned` gives the column of some nodes,
  from 0, and the columns after them follow from them. A node of an alluvial
  chart holds its column.

      iex> links = [%{from: "A", to: "B"}, %{from: "B", to: "C"}, %{from: "A", to: "C"}]
      iex> Expresso.Element.Chart.Sankey.columns(links)
      %{"A" => 0, "B" => 1, "C" => 2}
      iex> Expresso.Element.Chart.Sankey.columns(links, %{"C" => 4})
      %{"A" => 0, "B" => 1, "C" => 4}
      iex> Expresso.Element.Chart.Sankey.columns([%{from: {0, "A"}, to: {1, "A"}}])
      %{{0, "A"} => 0, {1, "A"} => 1}
  """
  @spec columns([%{from: key(), to: key()}], %{String.t() => non_neg_integer()}) ::
          %{key() => non_neg_integer()}
  def columns(links, pinned \\ %{}) do
    sources = Enum.group_by(links, & &1.to, & &1.from)
    nodes = links |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()

    pinned =
      Map.merge(pinned, for({column, _name} = node <- nodes, into: %{}, do: {node, column}))

    Enum.reduce(nodes, pinned, fn node, known -> elem(column(node, sources, known), 1) end)
  end

  defp column(node, sources, known) do
    case known do
      %{^node => column} ->
        {column, known}

      _unknown ->
        {column, known} =
          sources
          |> Map.get(node, [])
          |> Enum.reduce({0, known}, fn source, {column, known} ->
            {above, known} = column(source, sources, known)
            {max(column, above + 1), known}
          end)

        {column, Map.put(known, node, column)}
    end
  end

  @doc """
  Place the nodes and the links of a sankey in the box of the SVG

  `links` holds each link with its value and the number of its series, from
  1. The function returns the nodes, with their boxes, colors and the number
  of their first series, and the links, with their paths. `top` is the top of
  the box, and `settings` holds the `Expresso.Element.Node` of each node with
  a `node` entity.
  """
  @spec layout(
          [%{from: String.t(), to: String.t(), value: number(), series: pos_integer()}],
          number(),
          %{String.t() => Expresso.Element.Node.t()}
        ) :: %{nodes: [map()], links: [map()], node_width: pos_integer(), xs: [number()]}
  def layout(links, top \\ 8, settings \\ %{}), do: hd(layout_frames([links], top, settings))

  @doc """
  Place the nodes and the links of each frame of a sankey

  `frames` holds the links of each frame, as `layout/2` takes them. The
  frames share the columns, the order and the colors of the nodes, from the
  links of each frame together, and one scale, so a height means the same
  value in each frame. A node or a link with no value in a frame does not
  show in that frame.
  """
  @spec layout_frames([[map()]], number(), %{String.t() => Expresso.Element.Node.t()}) :: [
          %{nodes: [map()], links: [map()], node_width: pos_integer(), xs: [number()]}
        ]
  def layout_frames(frames, top, settings \\ %{}) do
    frames = Enum.map(frames, fn links -> Enum.filter(links, &(&1.value > 0)) end)
    union = frames |> List.flatten() |> Enum.uniq_by(&{&1.from, &1.to})
    columns = columns(union, pinned(settings))
    appearance = union |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()
    order = sort(appearance, columns, settings)
    sizes = Enum.map(frames, &sizes/1)

    shared = %{
      columns: columns,
      order: order,
      appearance: appearance,
      top: top,
      settings: settings,
      last: Enum.max(Map.values(columns))
    }

    shared = Map.merge(shared, %{scale: scale(sizes, shared), right: right(sizes, shared)})

    for {links, size} <- Enum.zip(frames, sizes), do: frame(links, size, shared)
  end

  @doc """
  Return the columns that the `node` entities give, from 0

      iex> Expresso.Element.Chart.Sankey.pinned(%{"A" => %Expresso.Element.Node{name: "A", column: 3}})
      %{"A" => 2}
  """
  @spec pinned(%{String.t() => Expresso.Element.Node.t()}) :: %{String.t() => non_neg_integer()}
  def pinned(settings) do
    for {name, %{column: column}} <- settings, column != nil, into: %{}, do: {name, column - 1}
  end

  # The nodes in their order in each column: the `order` of a node entity,
  # else the place of the node in its column in the data. The nodes of an
  # alluvial chart take the place of their name in the data, so one name has
  # one place in each column.
  defp sort(order, columns, settings) do
    ranks = order |> Enum.map(&name/1) |> Enum.uniq() |> Enum.with_index(1) |> Map.new()

    order
    |> Enum.group_by(&columns[&1])
    |> Enum.flat_map(fn {_column, names} ->
      names
      |> Enum.with_index(1)
      |> Enum.map(fn
        {{_column, name} = node, _place} -> {node, ranks[name]}
        other -> other
      end)
      |> Enum.sort_by(fn {node, place} -> {order_of(settings, name(node), place), place} end)
      |> Enum.map(&elem(&1, 0))
    end)
  end

  defp order_of(settings, name, place) do
    case settings do
      %{^name => %{order: order}} when order != nil -> order
      _other -> place
    end
  end

  # The size of each node of a frame: the larger of the flow into it and the
  # flow out of it.
  defp sizes(links) do
    into = Enum.reduce(links, %{}, &Map.update(&2, &1.to, &1.value, fn v -> v + &1.value end))
    out = Enum.reduce(links, %{}, &Map.update(&2, &1.from, &1.value, fn v -> v + &1.value end))
    Map.merge(into, out, fn _node, a, b -> max(a, b) end)
  end

  # The scale that fits the fullest column of each frame into the height.
  defp scale(sizes, shared) do
    for size <- sizes,
        {_column, names} <- stacks(size, shared) do
      (@height - 8 - shared.top - @gap * (length(names) - 1)) /
        Enum.sum(Enum.map(names, &size[&1]))
    end
    |> Enum.min()
  end

  # The space at the right of the last column for its labels: the width of
  # the widest label in the frames, and a maximum of one third of the width.
  defp right(sizes, shared) do
    widest =
      for size <- sizes,
          {name, value} <- size,
          shared.columns[name] == shared.last do
        label = Map.get(shared.settings, name(name), %{label: nil}).label || name(name)
        String.length("#{label} #{Plot.label(value)}") * @character
      end
      |> Enum.max()

    min(widest + 8, @width / 3)
  end

  # The nodes of a frame in each column, in the order of the nodes.
  defp stacks(size, shared) do
    shared.order |> Enum.filter(&Map.has_key?(size, &1)) |> Enum.group_by(&shared.columns[&1])
  end

  defp frame(links, size, shared) do
    %{scale: scale, top: top, last: last, right: right} = shared
    bottom = @height - 8
    x = fn column -> 4 + column * (@width - 8 - right - @node) / max(last, 1) end

    boxes =
      size
      |> stacks(shared)
      |> Enum.flat_map(fn {column, names} ->
        heights = Enum.map(names, &(size[&1] * scale))
        used = Enum.sum(heights) + @gap * (length(names) - 1)

        names
        |> Enum.zip(heights)
        |> Enum.map_reduce(top + (bottom - top - used) / 2, fn {name, height}, y ->
          {{name, %{x: x.(column), y: y, height: height, column: column}}, y + height + @gap}
        end)
        |> elem(0)
      end)
      |> Map.new()

    names = shared.appearance |> Enum.map(&name/1) |> Enum.uniq()
    color = fn node -> rem(Enum.find_index(names, &(&1 == name(node))), 8) + 1 end
    setting = fn node -> Map.get(shared.settings, name(node), %{label: nil, class: nil}) end

    nodes =
      for node <- shared.appearance, box = boxes[node], box != nil do
        touching = Enum.filter(links, &(&1.from == node or &1.to == node))

        Map.merge(box, %{
          name: node,
          label: setting.(node).label || name(node),
          class: setting.(node).class,
          value: size[node],
          color: color.(node),
          series: touching |> Enum.map(& &1.series) |> Enum.min()
        })
      end

    %{
      nodes: labeled(nodes),
      xs: Enum.map(0..last, x),
      links: links |> place(boxes, scale) |> Enum.map(&Map.put(&1, :color, color.(&1.from))),
      node_width: @node
    }
  end

  # The place of each link at its two nodes. The links out of a node have
  # the order of their targets from the top, and the links into a node have
  # the order of their sources.
  defp place(links, nodes, scale) do
    center = fn name -> nodes[name].y + nodes[name].height / 2 end

    outs =
      links
      |> Enum.group_by(& &1.from)
      |> Map.new(fn {node, out} -> {node, offsets(Enum.sort_by(out, &center.(&1.to)), scale)} end)

    ins =
      links
      |> Enum.group_by(& &1.to)
      |> Map.new(fn {node, into} ->
        {node, offsets(Enum.sort_by(into, &center.(&1.from)), scale)}
      end)

    Enum.map(links, fn link ->
      source = nodes[link.from]
      target = nodes[link.to]
      thickness = link.value * scale
      y0 = source.y + outs[link.from][link]
      y1 = target.y + ins[link.to][link]

      Map.put(
        link,
        :path,
        ribbon(source.x + @node, y0, target.x, y1, thickness)
      )
    end)
  end

  # The distance of each link from the top of its node.
  defp offsets(links, scale) do
    links
    |> Enum.map_reduce(0, fn link, y -> {{link, y}, y + link.value * scale} end)
    |> elem(0)
    |> Map.new()
  end

  @doc """
  Return the path of a ribbon from `(x0, y0)` to `(x1, y1)`, with a height

  The top edge and the bottom edge are cubic Bézier curves. Their control
  points are at the middle, so the ribbon leaves and enters horizontally.

      iex> Expresso.Element.Chart.Sankey.ribbon(0, 0, 100, 50, 10)
      "M0,0 C50,0 50,50 100,50 L100,60 C50,60 50,10 0,10 Z"
  """
  @spec ribbon(number(), number(), number(), number(), number()) :: String.t()
  def ribbon(x0, y0, x1, y1, height) do
    m = (x0 + x1) / 2
    f = &Plot.f/1

    "M#{f.(x0)},#{f.(y0)} C#{f.(m)},#{f.(y0)} #{f.(m)},#{f.(y1)} #{f.(x1)},#{f.(y1)} " <>
      "L#{f.(x1)},#{f.(y1 + height)} C#{f.(m)},#{f.(y1 + height)} #{f.(m)},#{f.(y0 + height)} " <>
      "#{f.(x0)},#{f.(y0 + height)} Z"
  end

  @doc """
  Draw the links, the nodes and the labels of a sankey in its SVG

  The assigns are the assigns of `Expresso.Element.Chart`. Each category is a
  link, and the value of a link is in one series. A chart with frames has one
  layer for each frame. The layer of the frame that shows has the opacity 1.
  The channel `--k<n>` of `Expresso.Element.Chart.Motion` sets the opacity,
  so the opacity of the layers changes from one frame to the next.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{frames: [_, _ | _] = frames} = assigns) do
    layouts =
      frames
      |> Enum.map(&links(assigns.categories, &1.values))
      |> layout_frames(assigns.box.top, assigns.node_settings)

    layers =
      for {layout, k} <- Enum.with_index(layouts, 1),
          do: {k, Map.merge(layout, %{numbered: numbered(assigns, k), values: assigns.values})}

    assigns = Map.merge(assigns, %{layers: layers, xs: hd(layouts).xs})

    temple do
      Motion.frame_label(assigns)
      titles(assigns)

      for {k, layer} <- @layers do
        g class: "chart-layer chart-fade",
          style: "opacity: var(--k#{k}, #{if k == 1, do: 1, else: 0});" do
          c(&drawing/1, rest!: layer)
        end
      end
    end
  end

  def render(assigns) do
    layout =
      assigns.categories
      |> links(Enum.map(assigns.series, & &1.values))
      |> layout(assigns.box.top, assigns.node_settings)

    drawing =
      drawing(Map.merge(layout, %{numbered: numbered(assigns, 1), values: assigns.values}))

    assigns = Map.merge(assigns, %{drawing: drawing, xs: layout.xs})

    temple do
      titles(assigns)
      @drawing
    end
  end

  @doc """
  Tell whether a chart shows a title over each column: an alluvial chart
  with the `levels` option

      iex> Expresso.Element.Chart.Sankey.titles?(%{kind: :alluvial, levels: ["2020", "2026"]})
      true
      iex> Expresso.Element.Chart.Sankey.titles?(%{kind: :sankey, levels: ["from", "to"]})
      false
  """
  @spec titles?(map()) :: boolean()
  def titles?(%{kind: :alluvial, levels: [_ | _]}), do: true
  def titles?(_assigns), do: false

  # The title of each column of an alluvial chart, in the row above the
  # nodes. A title is at the left edge of its first column, in the middle of
  # a column between, and at the right edge of the last column. The key `xs`
  # holds the x of each column, as the layout returns it.
  defp titles(assigns) do
    if titles?(assigns) do
      last = length(assigns.levels) - 1

      places =
        for {words, column} <- Enum.with_index(assigns.levels),
            do: Tuple.insert_at(title_place(column, last, Enum.at(assigns.xs, column)), 0, words)

      assigns = Map.merge(assigns, %{places: places, y: assigns.box.top - 16})

      temple do
        for {words, x, anchor} <- @places do
          text class: "chart-column", x: Plot.f(x), y: Plot.f(@y), text_anchor: anchor do
            words
          end
        end
      end
    else
      Phoenix.HTML.raw("")
    end
  end

  defp title_place(column, last, x) do
    cond do
      column == 0 -> {x, "start"}
      column == last -> {x + @node, "end"}
      true -> {x + @node / 2, "middle"}
    end
  end

  # Each series with its number from 1. A layer after the first has no morph
  # key, so the morph between two slides finds one copy of each mark.
  defp numbered(assigns, 1), do: Enum.with_index(assigns.series, 1)

  defp numbered(assigns, _layer) do
    for {series, number} <- Enum.with_index(assigns.series, 1),
        do: {%{series | overlay: no_morph(series.overlay)}, number}
  end

  defp no_morph(overlay), do: Enum.reject(overlay, &(elem(&1, 0) == "data-morph-key"))

  defp drawing(assigns) do
    temple do
      for {series, number} <- @numbered do
        g class: Expresso.Element.classes("chart-series", series.class), rest!: series.overlay do
          for link <- @links, link.series == number do
            path class: "chart-link chart-c#{link.color}", d: link.path
          end

          for node <- @nodes, node.series == number do
            rect class: Expresso.Element.classes("chart-node chart-c#{node.color}", node.class),
                 x: Plot.f(node.x),
                 y: Plot.f(node.y),
                 width: @node_width,
                 height: Plot.f(max(node.height, 1))
          end
        end
      end

      for {series, number} <- @numbered do
        g class: "chart-labels", rest!: no_morph(series.overlay) do
          for node <- @nodes, node.series == number, node.labeled do
            text [class: "chart-node-label"] ++ label_place(node) do
              label_text(node, @values)
            end
          end
        end
      end
    end
  end

  # The link of each category in the series that holds its value. `values`
  # holds the values of each series.
  defp links(categories, values) do
    for {[from, to], index} <- Enum.with_index(categories),
        {series, number} <- Enum.with_index(values, 1),
        value = Enum.at(series, index),
        value > 0,
        do: %{from: from, to: to, value: value, series: number}
  end

  # A label is at the right of its node, and in the middle of its height.
  defp label_place(node) do
    [x: Plot.f(node.x + @node + 8), y: Plot.f(node.y + node.height / 2 + 7), text_anchor: "start"]
  end

  defp label_text(node, true), do: "#{node.label} #{Plot.label(node.value)}"
  defp label_text(node, false), do: node.label

  @doc """
  Write the table of a sankey: one row for each link, with its source, its
  target and its value
  """
  @spec table(map()) :: Phoenix.HTML.safe()
  def table(assigns) do
    columns =
      case assigns.frames do
        [_one] -> [assigns.value_label || "Value"]
        frames -> Enum.map(frames, & &1.label)
      end

    rows =
      for {[from, to], index} <- Enum.with_index(assigns.categories) do
        values =
          for frame <- assigns.frames,
              do: frame.values |> Enum.map(&Enum.at(&1, index)) |> Enum.sum()

        {cell(assigns, from), cell(assigns, to), values}
      end

    assigns = Map.merge(assigns, %{rows: rows, columns: columns})

    temple do
      table class: "chart-table" do
        caption do
          if @value_label, do: "#{@title} (#{@value_label})", else: @title
        end

        thead do
          tr do
            for column <- ["From", "To" | @columns] do
              th scope: "col" do
                column
              end
            end
          end
        end

        tbody do
          for row <- @rows do
            c(&row/1, row: row)
          end
        end
      end
    end
  end

  # The text of a node in the table. A node of an alluvial chart names its
  # column, because one name can be in each column.
  defp cell(assigns, {column, name}) do
    title =
      if titles?(assigns),
        do: Enum.at(assigns.levels, column),
        else: "Column #{column + 1}"

    "#{label(assigns, name)} (#{title})"
  end

  defp cell(assigns, name), do: label(assigns, name)

  defp label(%{node_settings: settings}, name) do
    case settings do
      %{^name => %{label: label}} when label != nil -> label
      _other -> name
    end
  end

  defp row(%{row: {from, to, values}} = assigns) do
    assigns = Map.merge(assigns, %{from: from, to: to, values: values})

    temple do
      tr do
        th scope: "row" do
          @from
        end

        td do
          @to
        end

        for value <- @values do
          td do
            Plot.label(value)
          end
        end
      end
    end
  end

  @doc """
  Return the width of a node in the units of the SVG

      iex> Expresso.Element.Chart.Sankey.node_width()
      16
  """
  @spec node_width() :: pos_integer()
  def node_width, do: @node

  @doc """
  Mark each node that shows its label with the key `labeled`

  A node as high as a label shows its label. A shorter node shows its label
  when the middle of the label is one line or more from the middle of each
  other label in its column, from the top down, so two labels do not cover
  each other.

      iex> nodes = [
      ...>   %{name: "A", column: 0, y: 0, height: 40},
      ...>   %{name: "B", column: 0, y: 54, height: 6},
      ...>   %{name: "C", column: 0, y: 64, height: 4}
      ...> ]
      iex> nodes |> Expresso.Element.Chart.Sankey.labeled() |> Enum.map(& &1.labeled)
      [true, true, false]
  """
  @spec labeled([map()]) :: [map()]
  def labeled(nodes) do
    middle = fn node -> node.y + node.height / 2 end
    {tall, short} = Enum.split_with(nodes, &(&1.height >= @label))
    taken = Enum.map(tall, &{&1.column, middle.(&1)})

    shown =
      short
      |> Enum.sort_by(middle)
      |> Enum.reduce({MapSet.new(Enum.map(tall, & &1.name)), taken}, fn node, {shown, taken} ->
        place = {node.column, middle.(node)}

        if Enum.all?(taken, &apart?(&1, place)),
          do: {MapSet.put(shown, node.name), [place | taken]},
          else: {shown, taken}
      end)
      |> elem(0)

    Enum.map(nodes, &Map.put(&1, :labeled, MapSet.member?(shown, &1.name)))
  end

  defp apart?({column, y}, {other, middle}), do: column != other or abs(y - middle) >= @line
end
