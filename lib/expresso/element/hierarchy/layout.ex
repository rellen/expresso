defmodule Expresso.Element.Hierarchy.Layout do
  @moduledoc """
  The layout of a tree: the place of each box and the path of each line

  The layout is recursive. Each subtree is a box, and the layout of a node
  places the boxes of the subtrees under it with one of three layouts:

  | Layout | The nodes under a node |
  | --- | --- |
  | `:top_down` | Side by side in one row under the node. The node is at the center above the row. |
  | `:left_right` | One under the other in a column at the right of the node. The node is at the middle at the left. |
  | `:stacked` | One under the other below the node, with an indent. |

  The layout does not move a subtree into the space next to a smaller
  subtree, so the author can predict the place of each box. `docs/tree.md`
  gives the reasons.

  Each level has a size of its own, from the `box` option of the tree. In a
  tree with one layout, the boxes of one level thus have their tops in one
  row for `:top_down`, and their left edges in one column for `:left_right`.

  A line goes from the edge of a box to the edge of the box of a child, with
  horizontal and vertical parts only. The lines of the children of one node
  share the part from the box of the node.

  The layout is a function of the tree and the options only, so the same tree
  gives the same picture each time.
  """

  alias Expresso.Element.Node

  # The gap between two subtrees, and the gap between a node and the nodes
  # under it, in the units of the drawing. A stacked node has an indent.
  @gap 24
  @level_gap 48
  @indent 32

  @layouts [:top_down, :left_right, :stacked]

  @typedoc "The width and the height of a box"
  @type size :: %{width: pos_integer(), height: pos_integer()}

  @typedoc "A layout of the nodes under a node"
  @type layout :: :top_down | :left_right | :stacked

  @typedoc "One box: its node, its level from 0, its place and its size"
  @type box :: %{
          node: Node.t(),
          depth: non_neg_integer(),
          x: number(),
          y: number(),
          width: pos_integer(),
          height: pos_integer()
        }

  @typedoc """
  The boxes in the order of the tree, the paths of the lines, the name of the
  node at the end of each line, and the size of the drawing
  """
  @type t :: %{
          boxes: [box()],
          lines: [String.t()],
          targets: [String.t()],
          width: number(),
          height: number()
        }

  @typedoc """
  The options of the layout: the layout of the tree, the first stacked level,
  and an offset that moves each box and each line
  """
  @type options :: [
          layout: layout(),
          stack_from: pos_integer() | nil,
          offset: {number(), number()}
        ]

  @doc "Return the three layouts"
  @spec layouts() :: [layout()]
  def layouts, do: @layouts

  @doc """
  Return the layout of a tree from its root and the size of each level

  The last size applies to each deeper level. The layout of the nodes under a
  node comes from the first of these:

  1. The `layout` option of the node.
  2. The option `stack_from`: the nodes of that level and below are stacked.
     The root is level 1.
  3. The `layout` option of the nearest node above it with the option.
  4. The `layout` option of the tree, which is `:top_down` by default.

  ```
  iex> alias Expresso.Element.Node
  iex> root = %Node{name: "A", elements: [%Node{name: "B"}, %Node{name: "C"}]}
  iex> layout = Expresso.Element.Hierarchy.Layout.layout(root, [%{width: 100, height: 40}], [])
  iex> Enum.map(layout.boxes, &{&1.node.name, &1.x, &1.y})
  [{"A", 62, 0}, {"B", 0, 88}, {"C", 124, 88}]
  iex> {layout.width, layout.height}
  {224, 128}
  iex> layout = Expresso.Element.Hierarchy.Layout.layout(root, [%{width: 100, height: 40}], layout: :left_right)
  iex> Enum.map(layout.boxes, &{&1.node.name, &1.x, &1.y})
  [{"A", 0, 32}, {"B", 148, 0}, {"C", 148, 64}]
  ```
  """
  @spec layout(Node.t(), [size()], options()) :: t()
  def layout(%Node{} = root, [_ | _] = sizes, options) do
    context = %{
      sizes: sizes,
      stack_from: options[:stack_from],
      inherited: Keyword.get(options, :layout) || :top_down
    }

    {dx, dy} = Keyword.get(options, :offset) || {0, 0}
    placed = root |> place(0, context) |> shift(dx, dy)

    %{
      boxes: Enum.map(placed.boxes, &round_box/1),
      lines: Enum.map(placed.lines, fn {points, _to} -> path(points) end),
      targets: Enum.map(placed.lines, fn {_points, to} -> to end),
      width: number(placed.width),
      height: number(placed.height)
    }
  end

  @doc """
  Return the layout of a tree in which each node has the layout `:top_down`
  """
  @spec top_down(Node.t(), [size()]) :: t()
  def top_down(root, sizes), do: layout(root, sizes, layout: :top_down)

  @doc """
  Return the size of the boxes of a level, from 0 for the root

      iex> sizes = [%{width: 280, height: 120}, %{width: 220, height: 96}]
      iex> Expresso.Element.Hierarchy.Layout.size(sizes, 0)
      %{width: 280, height: 120}
      iex> Expresso.Element.Hierarchy.Layout.size(sizes, 5)
      %{width: 220, height: 96}
  """
  @spec size([size()], non_neg_integer()) :: size()
  def size(sizes, depth), do: Enum.at(sizes, depth) || List.last(sizes)

  # The layout of the nodes under a node at a depth from 0.
  defp own_layout(%Node{layout: layout}, _depth, _context) when layout != nil, do: layout

  defp own_layout(_node, depth, %{stack_from: from}) when is_integer(from) and depth + 2 >= from,
    do: :stacked

  defp own_layout(_node, _depth, %{inherited: inherited}), do: inherited

  # Place a subtree with its top left corner at 0, 0. The result holds the
  # boxes in the order of the tree, the lines as lists of points, and the
  # size of the subtree.
  defp place(%Node{} = node, depth, context) do
    %{width: width, height: height} = size(context.sizes, depth)
    box = %{node: node, depth: depth, x: 0, y: 0, width: width, height: height}
    layout = own_layout(node, depth, context)
    context = if node.layout, do: %{context | inherited: node.layout}, else: context

    case node.elements || [] do
      [] -> %{boxes: [box], lines: [], width: width, height: height}
      children -> arrange(layout, box, Enum.map(children, &place(&1, depth + 1, context)))
    end
  end

  defp arrange(:top_down, box, children) do
    row = row_size(children, :width)
    total = max(box.width, row)
    box = %{box | x: (total - box.width) / 2}
    top = box.height + @level_gap

    {children, _x} =
      Enum.map_reduce(children, (total - row) / 2, fn child, x ->
        {shift(child, x, top), x + child.width + @gap}
      end)

    from = {box.x + box.width / 2, box.height}
    middle = box.height + @level_gap / 2

    lines =
      for %{boxes: [child | _rest]} <- children,
          do: [
            from,
            {elem(from, 0), middle},
            {child.x + child.width / 2, middle},
            {child.x + child.width / 2, child.y}
          ]

    join(box, children, lines, total, top + Enum.max(Enum.map(children, & &1.height)))
  end

  defp arrange(:left_right, box, children) do
    column = row_size(children, :height)
    total = max(box.height, column)
    box = %{box | y: (total - box.height) / 2}
    left = box.width + @level_gap

    {children, _y} =
      Enum.map_reduce(children, (total - column) / 2, fn child, y ->
        {shift(child, left, y), y + child.height + @gap}
      end)

    from = {box.width, box.y + box.height / 2}
    middle = box.width + @level_gap / 2

    lines =
      for %{boxes: [child | _rest]} <- children,
          do: [
            from,
            {middle, elem(from, 1)},
            {middle, child.y + child.height / 2},
            {child.x, child.y + child.height / 2}
          ]

    join(box, children, lines, left + Enum.max(Enum.map(children, & &1.width)), total)
  end

  defp arrange(:stacked, box, children) do
    {children, bottom} =
      Enum.map_reduce(children, box.height + @gap, fn child, y ->
        {shift(child, @indent, y), y + child.height + @gap}
      end)

    rail = @indent / 2

    lines =
      for %{boxes: [child | _rest]} <- children,
          do: [
            {rail, box.height},
            {rail, child.y + child.height / 2},
            {child.x, child.y + child.height / 2}
          ]

    width = max(box.width, @indent + Enum.max(Enum.map(children, & &1.width)))
    join(box, children, lines, width, bottom - @gap)
  end

  # The width of a row or the height of a column of subtrees, with the gaps.
  defp row_size(children, key),
    do: Enum.sum(Enum.map(children, &Map.fetch!(&1, key))) + @gap * (length(children) - 1)

  # Each line of a node goes to the box of one child, the first box of the
  # child, and it carries the name of that child.
  defp join(box, children, lines, width, height) do
    targets = Enum.map(children, fn %{boxes: [child | _rest]} -> child.node.name end)

    %{
      boxes: [box | Enum.flat_map(children, & &1.boxes)],
      lines: Enum.zip(lines, targets) ++ Enum.flat_map(children, & &1.lines),
      width: width,
      height: height
    }
  end

  # Move a placed subtree by dx and dy. The subtree keeps its size.
  defp shift(placed, dx, dy) do
    boxes = Enum.map(placed.boxes, &%{&1 | x: &1.x + dx, y: &1.y + dy})

    lines =
      Enum.map(placed.lines, fn {points, to} ->
        {Enum.map(points, fn {x, y} -> {x + dx, y + dy} end), to}
      end)

    %{placed | boxes: boxes, lines: lines}
  end

  defp round_box(box), do: %{box | x: number(box.x), y: number(box.y)}

  # The SVG path of a line with horizontal and vertical parts only.
  defp path([{x, y} | rest]) do
    {parts, _point} =
      Enum.map_reduce(rest, {x, y}, fn {nx, ny}, {px, _py} ->
        part = if nx == px, do: "V#{f(ny)}", else: "H#{f(nx)}"
        {part, {nx, ny}}
      end)

    Enum.join(["M#{f(x)} #{f(y)}" | parts], " ")
  end

  @doc """
  Return a float with no fraction as an integer, so its text has no ".0"

      iex> Expresso.Element.Hierarchy.Layout.number(62.0)
      62
      iex> Expresso.Element.Hierarchy.Layout.number(61.5)
      61.5
  """
  @spec number(number()) :: number()
  def number(value) when is_float(value) and value == trunc(value), do: trunc(value)
  def number(value), do: value

  defp f(value), do: value |> number() |> to_string()
end
