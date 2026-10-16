defmodule Expresso.Element.Chart.Sankey do
  @moduledoc """
  Draws a sankey chart: the flows between the nodes of a graph

  A category of a sankey is a path of two nodes or more, such as
  `["Coal", "Electricity"]` or `"Gas/Electricity/Homes"`. Its value goes
  along each link of the path. `links/4` adds the values of the same link.
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

  An alluvial chart has one node for each name in each column. The column of
  a node is its place in the path, so the same name in two columns becomes
  two nodes. Its node is the tuple `{column, name}`, as `links/4` returns it. The
  nodes of one name have one color and one place in each column.

  A graph with a loop has no first column. `back_links/1` finds the links
  that close a loop. The layout finds the columns from the other links, and
  a back link goes in a lane under the nodes. The frames of a chart share the
  columns, the order and the scale of the nodes, as `layout_frames/3`
  returns them. Each frame is a layer, and the opacity of the layers changes
  from one frame to the next.

  `render/1` draws each series of the chart as a group. The group holds the
  links of the series and the nodes that show first with it. The node labels
  of each series are in a group after the links, with the same steps.
  `table/1` writes a row for each link for a screen reader.
  """

  import Temple
  use Temple.Component

  import Expresso.Element.Chart.Kinds

  alias Expresso.Element.Chart.{Layers, Plot, Table}

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

  # The gap between two lanes of the back links, and the least distance from
  # a node to the turn of a back link.
  @lane 6
  @turn 8

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
  Make sure that the categories and the values make a graph

  Each category names two nodes or more, each node has a name, and no link
  goes from a node to the same node. Each value is zero or more, and their
  sum is more than zero. A loop of two nodes or more is correct:
  `back_links/1` finds the links that close it. With `alluvial` true, each
  column has its own nodes, so a name can follow the same name.

      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], "B/C"], [1, 2], "/")
      :ok
      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], ["B", "A"]], [1, 2], "/")
      :ok
      iex> Expresso.Element.Chart.Sankey.check([["A", "A"]], [1], "/")
      {:error, "a flow of a sankey goes from \\"A\\" to \\"A\\". A flow goes to another node."}
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

      same = not alluvial and Enum.find_value(paths, &same_node/1) ->
        {:error,
         "a flow of a sankey goes from \"#{same}\" to \"#{same}\". A flow goes to another node."}

      Enum.any?(values, &(&1 < 0)) or Enum.sum(values) <= 0 ->
        {:error, "the values of a sankey are zero or more, and their sum is more than zero"}

      true ->
        :ok
    end
  end

  defp same_node(path) do
    path |> Enum.chunk_every(2, 1, :discard) |> Enum.find_value(fn [a, b] -> a == b and a end)
  end

  @doc """
  Return the links that close a loop, as pairs of a source and a target

  A depth-first search from each node, in the order of the data, follows
  the links in their order. A link to a node on the path of the search
  closes a loop. The graph without these links has no loop, so `columns/2`
  uses it to find the columns.

      iex> links = [%{from: "A", to: "B"}, %{from: "B", to: "C"}, %{from: "C", to: "A"}]
      iex> Expresso.Element.Chart.Sankey.back_links(links)
      MapSet.new([{"C", "A"}])
  """
  @spec back_links([%{from: key(), to: key()}]) :: MapSet.t({key(), key()})
  def back_links(links) do
    next = Enum.group_by(links, & &1.from, & &1.to)
    nodes = links |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()

    nodes
    |> Enum.reduce({%{}, []}, &search(&1, next, %{}, &2))
    |> elem(1)
    |> MapSet.new()
  end

  # The search keeps the nodes that it finished and the nodes on its path as
  # the keys of maps, and the back links as a list.
  defp search(node, next, path, {done, back}) do
    if Map.has_key?(done, node) do
      {done, back}
    else
      path = Map.put(path, node, true)

      {done, back} =
        next
        |> Map.get(node, [])
        |> Enum.reduce({done, back}, &follow(node, &1, next, path, &2))

      {Map.put(done, node, true), back}
    end
  end

  defp follow(node, child, next, path, {done, back}) do
    if Map.has_key?(path, child),
      do: {done, [{node, child} | back]},
      else: search(child, next, path, {done, back})
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

  A node with no link into it is in column 0. Each other node is one column
  after its last source. A link that closes a loop, as `back_links/1` finds
  it, does not count. `pinned` holds the columns of some nodes, from 0, and
  the nodes after them move to follow them. A node of an alluvial chart
  holds its column.

      iex> links = [%{from: "A", to: "B"}, %{from: "B", to: "C"}, %{from: "A", to: "C"}]
      iex> Expresso.Element.Chart.Sankey.columns(links)
      %{"A" => 0, "B" => 1, "C" => 2}
      iex> Expresso.Element.Chart.Sankey.columns(links, %{"C" => 4})
      %{"A" => 0, "B" => 1, "C" => 4}
      iex> Expresso.Element.Chart.Sankey.columns([%{from: "A", to: "B"}, %{from: "B", to: "A"}])
      %{"A" => 0, "B" => 1}
      iex> Expresso.Element.Chart.Sankey.columns([%{from: {0, "A"}, to: {1, "A"}}])
      %{{0, "A"} => 0, {1, "A"} => 1}
  """
  @spec columns([%{from: key(), to: key()}], %{String.t() => non_neg_integer()}) ::
          %{key() => non_neg_integer()}
  def columns(links, pinned \\ %{}) do
    loops = back_links(links)
    forward = Enum.reject(links, &MapSet.member?(loops, {&1.from, &1.to}))
    sources = Enum.group_by(forward, & &1.to, & &1.from)
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
      last: Enum.max(Map.values(columns)),
      lanes: lanes(union, columns)
    }

    shared = Map.merge(shared, room(frames, sizes, shared))
    shared = Map.put(shared, :right, right(sizes, shared))

    for {links, size} <- Enum.zip(frames, sizes), do: frame(links, size, shared)
  end

  # The lane of each back link, from 0 next to the nodes. A back link goes
  # from a column to the same column or to an earlier column. A shorter back
  # link has a lane nearer to the nodes. Thus its turns are inside the turns
  # of a longer back link.
  defp lanes(links, columns) do
    links
    |> Enum.filter(&(columns[&1.to] <= columns[&1.from]))
    |> Enum.with_index()
    |> Enum.sort_by(fn {link, index} -> {columns[link.from] - columns[link.to], index} end)
    |> Enum.with_index(fn {link, _index}, lane -> {{link.from, link.to}, lane} end)
    |> Map.new()
  end

  defp back?(link, shared), do: Map.has_key?(shared.lanes, {link.from, link.to})

  # The scale, the bottom of the nodes and the margin at the two sides. The
  # lanes of the back links take a row under the nodes, and the turns of the
  # back links take a margin at the left and at the right.
  defp room(frames, sizes, shared) do
    backs = Enum.map(frames, fn links -> Enum.filter(links, &back?(&1, shared)) end)
    lanes = map_size(shared.lanes)
    reserve = if lanes == 0, do: 0, else: @gap + @lane * (lanes - 1)
    extra = backs |> Enum.map(fn links -> links |> Enum.map(& &1.value) |> Enum.sum() end)
    extra = Enum.max(extra)

    scale =
      for size <- sizes,
          {_column, names} <- stacks(size, shared) do
        (@height - 8 - shared.top - reserve - @gap * (length(names) - 1)) /
          (Enum.sum(Enum.map(names, &size[&1])) + extra)
      end
      |> Enum.min()

    sides =
      for links <- backs,
          side <- [:from, :to],
          {_node, values} <- Enum.group_by(links, &Map.get(&1, side), & &1.value),
          do: Enum.sum(values)

    margin = if sides == [], do: 0, else: @turn + Enum.max(sides) * scale
    bottom = @height - 8 - if(lanes == 0, do: 0, else: reserve + extra * scale)

    %{scale: scale, bottom: bottom, margin: margin}
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
    %{scale: scale, top: top, last: last, bottom: bottom, margin: margin, right: right} = shared
    width = @width - 8 - 2 * margin - right - @node
    x = fn column -> 4 + margin + column * width / max(last, 1) end

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
    color = fn node -> names |> Enum.find_index(&(&1 == name(node))) |> Layers.color() end
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
      links:
        links
        |> place(boxes, shared)
        |> Enum.map(&Map.put(&1, :color, color.(&1.from)))
        |> Enum.sort_by(&is_nil(&1.stroke)),
      node_width: @node
    }
  end

  # The place of each link at its two nodes. The links out of a node have
  # the order of their targets from the top, and the links into a node have
  # the order of their sources. The back links are at the bottom of a node.
  # Among them, the back link in the lane farthest from the nodes is at the
  # top.
  defp place(links, nodes, shared) do
    scale = shared.scale
    center = fn name -> nodes[name].y + nodes[name].height / 2 end

    key = fn link, other ->
      if back?(link, shared), do: {1, -lane(link, shared)}, else: {0, other}
    end

    outs =
      links
      |> Enum.group_by(& &1.from)
      |> Map.new(fn {node, out} -> {node, Enum.sort_by(out, &key.(&1, center.(&1.to)))} end)

    ins =
      links
      |> Enum.group_by(& &1.to)
      |> Map.new(fn {node, into} -> {node, Enum.sort_by(into, &key.(&1, center.(&1.from)))} end)

    out_offsets = Map.new(outs, fn {node, out} -> {node, offsets(out, scale)} end)
    in_offsets = Map.new(ins, fn {node, into} -> {node, offsets(into, scale)} end)
    turns = Map.merge(turns(outs, :out, shared), turns(ins, :in, shared))
    lane_y = lane_centers(links, shared)

    Enum.map(links, fn link ->
      source = nodes[link.from]
      target = nodes[link.to]
      thickness = link.value * scale
      y0 = source.y + out_offsets[link.from][link]
      y1 = target.y + in_offsets[link.to][link]

      if back?(link, shared) do
        ends = {source.x + @node, y0 + thickness / 2, target.x, y1 + thickness / 2}
        turn = {turns[{:out, link}], turns[{:in, link}]}

        Map.merge(link, %{
          path: back_path(ends, lane_y[{link.from, link.to}], turn, thickness),
          stroke: Plot.f(thickness)
        })
      else
        Map.merge(link, %{
          path: ribbon(source.x + @node, y0, target.x, y1, thickness),
          stroke: nil
        })
      end
    end)
  end

  defp lane(link, shared), do: shared.lanes[{link.from, link.to}]

  # The distance from a node to the turn of each back link at that node. A
  # lower back link at the node has its turn nearer to the node, so the
  # turns do not cross.
  defp turns(stacks, side, shared) do
    for {_node, stack} <- stacks, reduce: %{} do
      turns ->
        stack
        |> Enum.filter(&back?(&1, shared))
        |> Enum.reverse()
        |> Enum.reduce({turns, 0}, fn link, {turns, below} ->
          width = link.value * shared.scale
          {Map.put(turns, {side, link}, @turn + below + width / 2), below + width}
        end)
        |> elem(0)
    end
  end

  # The center of the lane of each back link of a frame, under the nodes.
  defp lane_centers(links, shared) do
    links
    |> Enum.filter(&back?(&1, shared))
    |> Enum.sort_by(&lane(&1, shared))
    |> Enum.map_reduce(shared.bottom + @gap, fn link, y ->
      height = link.value * shared.scale
      {{{link.from, link.to}, y + height / 2}, y + height + @lane}
    end)
    |> elem(0)
    |> Map.new()
  end

  # The center line of a back link: from the right side of its source to a
  # turn, down to its lane, to the left along the lane, up at a turn before
  # its target, and into the left side of the target. The corners are round,
  # and the stroke of the line has the height of the link.
  defp back_path({x0, y0, x1, y1}, lane, {out, into}, height) do
    f = &Plot.f/1
    r = height / 2 + 2
    xr = x0 + out
    xl = x1 - into

    "M#{f.(x0)},#{f.(y0)} H#{f.(xr - r)} Q#{f.(xr)},#{f.(y0)} #{f.(xr)},#{f.(y0 + r)} " <>
      "V#{f.(lane - r)} Q#{f.(xr)},#{f.(lane)} #{f.(xr - r)},#{f.(lane)} " <>
      "H#{f.(xl + r)} Q#{f.(xl)},#{f.(lane)} #{f.(xl)},#{f.(lane - r)} " <>
      "V#{f.(y1 + r)} Q#{f.(xl)},#{f.(y1)} #{f.(xl + r)},#{f.(y1)} H#{f.(x1)}"
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
      |> Enum.map(&Layers.links(assigns.categories, &1.values))
      |> layout_frames(assigns.box.top, assigns.node_settings)

    Layers.render(assigns, layouts, &drawing/1)
  end

  def render(assigns) do
    layout =
      assigns.categories
      |> Layers.links(Enum.map(assigns.series, & &1.values))
      |> layout(assigns.box.top, assigns.node_settings)

    Layers.render(assigns, [layout], &drawing/1)
  end

  @doc """
  Tell whether a chart shows a title over each column: an alluvial chart or
  a parallel sets chart with the `levels` option

      iex> Expresso.Element.Chart.Sankey.titles?(%{kind: :alluvial, levels: ["2020", "2026"]})
      true
      iex> Expresso.Element.Chart.Sankey.titles?(%{kind: :sankey, levels: ["from", "to"]})
      false
  """
  @spec titles?(map()) :: boolean()
  def titles?(%{kind: kind, levels: [_ | _]}) when is_titled(kind), do: true

  def titles?(_assigns), do: false

  @doc """
  Draw the title of each column of an alluvial chart or a parallel sets
  chart, in the row above the nodes

  The first title is at the left edge of its column, and the last title is
  at the right edge of its column. Each other title is at the middle of its
  column. The key `xs` holds the x of each column, as the layout returns it.
  """
  @spec titles(map()) :: Phoenix.HTML.safe()
  def titles(assigns) do
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

  defp drawing(assigns) do
    temple do
      for {series, number} <- @numbered do
        g class: Expresso.Element.classes("chart-series", series.class), rest!: series.overlay do
          for link <- @links, link.series == number do
            path class: link_class(link),
                 d: link.path,
                 stroke_width: link.stroke,
                 data_keys: Layers.key(assigns, [link.from, link.to])
          end

          for node <- @nodes, node.series == number do
            rect class: Expresso.Element.classes("chart-node chart-c#{node.color}", node.class),
                 x: Plot.f(node.x),
                 y: Plot.f(node.y),
                 width: @node_width,
                 height: Plot.f(max(node.height, 1)),
                 data_keys: Layers.key(assigns, [node.name])
          end
        end
      end

      for {series, number} <- @numbered do
        g class: "chart-labels", rest!: Layers.no_morph(series.overlay) do
          for node <- @nodes, node.series == number, node.labeled do
            text [class: "chart-node-label", data_keys: Layers.key(assigns, [node.name])] ++
                   label_place(node) do
              label_text(node, @values)
            end
          end
        end
      end
    end
  end

  defp link_class(%{stroke: nil, color: color}), do: "chart-link chart-c#{color}"
  defp link_class(%{color: color}), do: "chart-link chart-back chart-c#{color}"

  @doc """
  Return the attributes that place the label of a node: at the right of the
  node, and in the middle of its height

      iex> Expresso.Element.Chart.Sankey.label_place(%{x: 4, y: 10, height: 20})
      [x: "28", y: "27", text_anchor: "start"]
  """
  @spec label_place(map()) :: keyword()
  def label_place(node) do
    [x: Plot.f(node.x + @node + 8), y: Plot.f(node.y + node.height / 2 + 7), text_anchor: "start"]
  end

  @doc """
  Return the text of the label of a node: its label, and its value when the
  chart shows the values

      iex> Expresso.Element.Chart.Sankey.label_text(%{label: "Gas", value: 95}, true)
      "Gas 95"
  """
  @spec label_text(map(), boolean()) :: String.t()
  def label_text(node, true), do: "#{node.label} #{Plot.label(node.value)}"
  def label_text(node, false), do: node.label

  @doc """
  Return the headers and the rows of the table of a sankey: one row for each
  link, with its source, its target and its value in each frame
  """
  @spec table(map()) :: %{headers: [String.t()], rows: [[String.t()]]}
  def table(assigns) do
    rows =
      for {[from, to], index} <- Enum.with_index(assigns.categories),
          do: [cell(assigns, from), cell(assigns, to) | Table.values(assigns.frames, index)]

    %{
      headers: ["From", "To" | Table.value_headers(assigns.frames, assigns.value_label)],
      rows: rows
    }
  end

  @doc """
  Return the text of a node in the table

  A node of an alluvial chart names its column, because one name can be in
  each column.
  """
  @spec cell(map(), key()) :: String.t()
  def cell(assigns, {column, name}) do
    title =
      if titles?(assigns),
        do: Enum.at(assigns.levels, column),
        else: "Column #{column + 1}"

    "#{label(assigns, name)} (#{title})"
  end

  def cell(assigns, name), do: label(assigns, name)

  defp label(%{node_settings: settings}, name) do
    case settings do
      %{^name => %{label: label}} when label != nil -> label
      _other -> name
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
