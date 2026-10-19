defmodule Expresso.Element.Hierarchy.Layout do
  @moduledoc """
  The layout of a tree: the place of each box and the path of each line

  The layout is recursive. Each subtree is a box, and the layout of a node
  places the boxes of the subtrees under it. In the layout `:top_down`, the
  subtrees of a node are side by side in one row, with a gap between two of
  them, and the node is at the center above the row. The layout does not move
  a subtree into the space under a smaller subtree next to it, so the author
  can predict the place of each box. `docs/tree.md` gives the reasons.

  Each level has a size of its own, from the `box` option of the tree. The
  boxes of one level have their tops in one row, so the top of a level is the
  sum of the heights of the levels above it and of the gaps between them.

  A line goes from the bottom of a box down to the middle of the gap under
  it, along to the center of the box of the child, and down to the top of
  that box. The lines of the children of one node thus share the part from
  the box of the node.

  The layout is a function of the tree and the sizes only, so the same tree
  gives the same picture each time.
  """

  alias Expresso.Element.Node

  # The gap between two subtrees of one row, and the gap between two levels,
  # in the units of the drawing.
  @gap 24
  @level_gap 48

  @typedoc "The width and the height of a box"
  @type size :: %{width: pos_integer(), height: pos_integer()}

  @typedoc "One box: its node, its level from 0, its place and its size"
  @type box :: %{
          node: Node.t(),
          depth: non_neg_integer(),
          x: number(),
          y: number(),
          width: pos_integer(),
          height: pos_integer()
        }

  @typedoc "The boxes in the order of the tree, the paths of the lines, and the size of the drawing"
  @type t :: %{boxes: [box()], lines: [String.t()], width: number(), height: number()}

  @doc """
  Return the layout of a tree from its root and the size of each level

  The last size applies to each deeper level.

      iex> alias Expresso.Element.Node
      iex> root = %Node{name: "A", elements: [%Node{name: "B"}, %Node{name: "C"}]}
      iex> layout = Expresso.Element.Hierarchy.Layout.top_down(root, [%{width: 100, height: 40}])
      iex> Enum.map(layout.boxes, &{&1.node.name, &1.x, &1.y})
      [{"A", 62, 0}, {"B", 0, 88}, {"C", 124, 88}]
      iex> {layout.width, layout.height}
      {224, 128}
  """
  @spec top_down(Node.t(), [size()]) :: t()
  def top_down(%Node{} = root, [_ | _] = sizes) do
    tops = tops(sizes, depth(root))
    {boxes, lines, width} = place(root, 0, 0, sizes, tops)
    height = boxes |> Enum.map(&(&1.y + &1.height)) |> Enum.max()
    %{boxes: boxes, lines: lines, width: width, height: height}
  end

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

  # The number of levels of a tree.
  defp depth(%Node{elements: children}) do
    case children || [] do
      [] -> 1
      children -> 1 + (children |> Enum.map(&depth/1) |> Enum.max())
    end
  end

  # The top of each level.
  defp tops(sizes, levels) do
    {tops, _top} =
      Enum.map_reduce(0..(levels - 1)//1, 0, fn depth, top ->
        {top, top + size(sizes, depth).height + @level_gap}
      end)

    List.to_tuple(tops)
  end

  # The width of a subtree: the width of its box, or the width of the row of
  # its children with the gaps, the larger.
  defp width(%Node{elements: children}, depth, sizes) do
    own = size(sizes, depth).width

    case children || [] do
      [] ->
        own

      children ->
        row = children |> Enum.map(&width(&1, depth + 1, sizes)) |> Enum.sum()
        max(own, row + @gap * (length(children) - 1))
    end
  end

  # Place a subtree with its left edge at `left`. The function returns the
  # boxes of the subtree in the order of the tree, the paths of its lines, and
  # its width.
  defp place(%Node{} = node, depth, left, sizes, tops) do
    %{width: own, height: height} = size(sizes, depth)
    total = width(node, depth, sizes)
    top = elem(tops, depth)
    children = node.elements || []

    {child_boxes, child_lines} =
      case children do
        [] ->
          {[], []}

        children ->
          widths = Enum.map(children, &width(&1, depth + 1, sizes))
          row = Enum.sum(widths) + @gap * (length(children) - 1)
          start = left + (total - row) / 2

          {placed, _x} =
            children
            |> Enum.zip(widths)
            |> Enum.map_reduce(start, fn {child, child_width}, x ->
              {place(child, depth + 1, x, sizes, tops), x + child_width + @gap}
            end)

          {Enum.flat_map(placed, &elem(&1, 0)), Enum.flat_map(placed, &elem(&1, 1))}
      end

    x = left + (total - own) / 2
    box = %{node: node, depth: depth, x: number(x), y: top, width: own, height: height}

    lines =
      for child <- Enum.filter(child_boxes, &(&1.depth == depth + 1)),
          do: line(box, child)

    {[box | child_boxes], lines ++ child_lines, total}
  end

  # The path from the bottom of a box to the top of the box of a child.
  defp line(parent, child) do
    from = parent.x + parent.width / 2
    to = child.x + child.width / 2
    bottom = parent.y + parent.height
    middle = bottom + (child.y - bottom) / 2

    "M#{f(from)} #{f(bottom)} V#{f(middle)} H#{f(to)} V#{f(child.y)}"
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
