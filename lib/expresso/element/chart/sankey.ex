defmodule Expresso.Element.Chart.Sankey do
  @moduledoc """
  Draws a sankey chart: the flows between the nodes of a graph

  A category of a sankey is a path of two nodes or more, such as
  `["Coal", "Electricity"]` or `"Gas/Electricity/Homes"`, and its value flows
  along each link of the path. `links/3` adds the values of the same link
  together, so a CSV file can hold one row for each flow, or one row for each
  record of an alluvial chart with the `levels` option.

  The layout has these rules:

  1. A node with no flow into it is in the first column. Each other node is
     one column after its furthest source, so a link can skip a column.
  2. The height of a node is the larger of the flow into it and the flow out
     of it. One scale gives the heights of each column, and the fullest
     column fills the height of the chart. Each column is in the middle.
  3. The nodes of a column keep the order of the data. At each node, the
     links have the order of the other ends, from the top, so few links
     cross.
  4. A link is a ribbon between two cubic Bézier curves. The control points
     are at the middle of the two columns, so a link leaves and enters each
     node level. The ribbon is a filled shape, and not a thick stroke, so its
     height is the value at each point.

  A graph with a loop has no first column, so `check/3` refuses it. The
  frames of a chart share the columns, the order and the scale of the nodes,
  as `layout_frames/2` gives them, and each frame is a layer that fades.

  `render/1` draws each series of the chart as a group with its links and the
  nodes that show first with it. The labels of the nodes are in groups of
  their own above each link, with the same steps. `table/1` writes a row for
  each link for a screen reader.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Motion, Plot}

  @typedoc "A link: two nodes and a value"
  @type link :: %{from: String.t(), to: String.t(), value: number()}

  # The box of the chart in the units of the SVG, the width of a node, the
  # gap between two nodes of a column, and the least height of a node with a
  # label.
  @width 800
  @height 450
  @node 16
  @gap 14
  @label 16

  @doc """
  Return the nodes of a category of a sankey, as a list of names

  A category is a list of names, or a string with the separator between two
  names. The spaces next to a name do not count.

      iex> Expresso.Element.Chart.Sankey.path("Gas / Electricity", "/")
      ["Gas", "Electricity"]
      iex> Expresso.Element.Chart.Sankey.path(["I/O", "Disks"], "/")
      ["I/O", "Disks"]
  """
  @spec path(String.t() | [String.t()], String.t()) :: [String.t()]
  def path(category, _separator) when is_list(category), do: Enum.map(category, &String.trim/1)

  def path(category, separator),
    do: category |> String.split(separator) |> Enum.map(&String.trim/1)

  @doc """
  Make sure that the categories and the values make a graph with no loop

  Each category names two nodes or more, each node has a name, and no link
  goes from a node to the same node. Each value is zero or more, and their
  sum is more than zero.

      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], "B/C"], [1, 2], "/")
      :ok
      iex> Expresso.Element.Chart.Sankey.check([["A", "B"], ["B", "A"]], [1, 2], "/")
      {:error, "the flows of a sankey make a loop: A → B → A. A sankey goes in one direction, so give a node in the loop a different name, such as \\"A (again)\\"."}
  """
  @spec check([String.t() | [String.t()]], [number()], String.t()) :: :ok | {:error, String.t()}
  def check(categories, values, separator) do
    paths = Enum.map(categories, &path(&1, separator))

    cond do
      short = Enum.find(paths, &(length(&1) < 2)) ->
        {:error,
         "the category #{inspect(Enum.join(short, separator))} of a sankey names one node. " <>
           "A category is a path of two nodes or more, such as [\"Coal\", \"Electricity\"]."}

      Enum.any?(paths, &Enum.member?(&1, "")) ->
        {:error, "a node of a sankey has no name"}

      same = Enum.find_value(paths, &same_node/1) ->
        {:error,
         "a flow of a sankey goes from \"#{same}\" to \"#{same}\". A flow goes to another node."}

      Enum.any?(values, &(&1 < 0)) or Enum.sum(values) <= 0 ->
        {:error, "the values of a sankey are zero or more, and their sum is more than zero"}

      true ->
        loop(paths)
    end
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
  in a path is a link.

      iex> Expresso.Element.Chart.Sankey.links([["A", "B", "C"], ["A", "B"]], [2, 3], "/")
      [%{from: "A", to: "B", value: 5}, %{from: "B", to: "C", value: 2}]
  """
  @spec links([String.t() | [String.t()]], [number()], String.t()) :: [link()]
  def links(categories, values, separator) do
    categories
    |> Enum.zip(values)
    |> Enum.flat_map(fn {category, value} ->
      category
      |> path(separator)
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

  @doc """
  Return the column of each node, from 0

  A node with no link into it is in column 0, and each other node is one
  column after its furthest source.

      iex> links = [%{from: "A", to: "B"}, %{from: "B", to: "C"}, %{from: "A", to: "C"}]
      iex> Expresso.Element.Chart.Sankey.columns(links)
      %{"A" => 0, "B" => 1, "C" => 2}
  """
  @spec columns([%{from: String.t(), to: String.t()}]) :: %{String.t() => non_neg_integer()}
  def columns(links) do
    sources = Enum.group_by(links, & &1.to, & &1.from)
    nodes = links |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()
    Enum.reduce(nodes, %{}, fn node, known -> elem(column(node, sources, known), 1) end)
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
  the box.
  """
  @spec layout(
          [%{from: String.t(), to: String.t(), value: number(), series: pos_integer()}],
          number()
        ) :: %{nodes: [map()], links: [map()], node_width: pos_integer()}
  def layout(links, top \\ 8), do: hd(layout_frames([links], top))

  @doc """
  Place the nodes and the links of each frame of a sankey

  `frames` holds the links of each frame, as `layout/2` takes them. The
  frames share the columns, the order and the colors of the nodes, from the
  links of each frame together, and one scale, so a height means the same
  value in each frame. A node or a link with no value in a frame does not
  show in that frame.
  """
  @spec layout_frames([[map()]], number()) :: [
          %{nodes: [map()], links: [map()], node_width: pos_integer()}
        ]
  def layout_frames(frames, top) do
    frames = Enum.map(frames, fn links -> Enum.filter(links, &(&1.value > 0)) end)
    union = frames |> List.flatten() |> Enum.uniq_by(&{&1.from, &1.to})
    columns = columns(union)
    order = union |> Enum.flat_map(&[&1.from, &1.to]) |> Enum.uniq()
    sizes = Enum.map(frames, &sizes/1)
    shared = %{columns: columns, order: order, top: top, last: Enum.max(Map.values(columns))}
    shared = Map.put(shared, :scale, scale(sizes, shared))

    for {links, size} <- Enum.zip(frames, sizes), do: frame(links, size, shared)
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

  # The nodes of a frame in each column, in the order of the nodes.
  defp stacks(size, shared) do
    shared.order |> Enum.filter(&Map.has_key?(size, &1)) |> Enum.group_by(&shared.columns[&1])
  end

  defp frame(links, size, shared) do
    %{scale: scale, top: top, last: last} = shared
    bottom = @height - 8
    x = fn column -> 4 + column * (@width - 8 - @node) / max(last, 1) end

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

    color = fn name -> rem(Enum.find_index(shared.order, &(&1 == name)), 8) + 1 end

    nodes =
      for name <- shared.order, box = boxes[name], box != nil do
        touching = Enum.filter(links, &(&1.from == name or &1.to == name))

        Map.merge(box, %{
          name: name,
          value: size[name],
          color: color.(name),
          series: touching |> Enum.map(& &1.series) |> Enum.min(),
          last: box.column == last
        })
      end

    %{
      nodes: nodes,
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

  The top edge and the bottom edge are cubic Bézier curves with their
  control points at the middle, so the ribbon leaves and enters level.

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
  layer for each frame, and the layer of the frame that shows has the
  opacity 1: the channel `--k<n>` of `Expresso.Element.Chart.Motion` gives it,
  and the layers fade from one frame to the next.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{frames: [_, _ | _] = frames} = assigns) do
    layouts =
      frames
      |> Enum.map(&links(assigns.categories, &1.values))
      |> layout_frames(assigns.box.top)

    layers =
      for {layout, k} <- Enum.with_index(layouts, 1),
          do: {k, Map.merge(layout, %{numbered: numbered(assigns, k), values: assigns.values})}

    assigns = Map.put(assigns, :layers, layers)

    temple do
      Motion.frame_label(assigns)

      for {k, layer} <- @layers do
        g class: "chart-layer chart-fade",
          style: "opacity: var(--k#{k}, #{if k == 1, do: 1, else: 0});" do
          c(&drawing/1, rest!: layer)
        end
      end
    end
  end

  def render(assigns) do
    layout = links(assigns.categories, Enum.map(assigns.series, & &1.values)) |> layout()
    drawing(Map.merge(layout, %{numbered: numbered(assigns, 1), values: assigns.values}))
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
            rect class: "chart-node chart-c#{node.color}",
                 x: Plot.f(node.x),
                 y: Plot.f(node.y),
                 width: @node_width,
                 height: Plot.f(max(node.height, 1))
          end
        end
      end

      for {series, number} <- @numbered do
        g class: "chart-labels", rest!: no_morph(series.overlay) do
          for node <- @nodes, node.series == number, label?(node) do
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

  # A label is at the right of its node, or at the left of a node of the last
  # column, and in the middle of the height of the node.
  defp label_place(node) do
    {x, anchor} =
      if node.last, do: {node.x - 8, "end"}, else: {node.x + @node + 8, "start"}

    [x: Plot.f(x), y: Plot.f(node.y + node.height / 2 + 7), text_anchor: anchor]
  end

  defp label_text(node, true), do: "#{node.name} #{Plot.label(node.value)}"
  defp label_text(node, false), do: node.name

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

        {from, to, values}
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
  Tell whether a node is high enough for its label

      iex> Expresso.Element.Chart.Sankey.label?(%{height: 20})
      true
      iex> Expresso.Element.Chart.Sankey.label?(%{height: 4})
      false
  """
  @spec label?(%{height: number()}) :: boolean()
  def label?(%{height: height}), do: height >= @label
end
