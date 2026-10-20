defmodule Expresso.Element.Hierarchy.Steps do
  @moduledoc """
  The steps of a tree: the groups of `reveal`, the dim, the steps of each
  box, and the moves of `reflow`

  A box of a tree is not inside the box of its parent in the HTML, so the
  overlay contract cannot hide the boxes under a node with the node. This
  module gives each box the steps of its node, or of the nearest node above
  it with steps. The line to a node takes the steps of the node.

  `Expresso.Overlay.Expand` calls `groups/2` before the counter walk and
  `dim/1` after the expansion, as it does for the `reveal` and the `dim`
  options of a list. The renderer calls `effective/1` and `rules/2`.
  """

  alias Expresso.Element.Hierarchy
  alias Expresso.Element.Hierarchy.Layout
  alias Expresso.Element.Node
  alias Expresso.Element.On
  alias Expresso.Overlay

  @doc """
  Give each group of the `reveal` option one step from the counter

  The groups come from the tree after the options of the values, so `sort`
  gives the order of `:nodes`. Each node of a group shows from the step of
  its group. A node with its own `at` option keeps it, and a `:next` in it
  takes a step after the groups. The nodes under it take its steps. The function returns the tree and the
  counter after the groups.
  """
  @spec groups(Hierarchy.t(), pos_integer()) :: {Hierarchy.t(), pos_integer()}
  def groups(%Hierarchy{reveal: nil} = tree, counter), do: {tree, counter}
  def groups(%Hierarchy{elements: []} = tree, counter), do: {tree, counter}

  def groups(%Hierarchy{reveal: kind, elements: [root]} = tree, counter) do
    %Hierarchy{elements: [prepared]} = Hierarchy.prepared(tree)
    own = root |> owned() |> MapSet.new(& &1.name)

    groups =
      prepared
      |> by(kind)
      |> Enum.map(fn group -> Enum.reject(group, &MapSet.member?(own, &1)) end)
      |> Enum.reject(&(&1 == []))

    steps =
      groups
      |> Enum.with_index(counter)
      |> Enum.flat_map(fn {group, step} -> Enum.map(group, &{&1, step}) end)
      |> Map.new()

    {root, counter} = root |> put_steps(steps) |> resolve(counter + length(groups))
    {%Hierarchy{tree | elements: [root]}, counter}
  end

  # A node in a group has an absolute specification, so the counter walk would
  # give the nodes under it a counter from its own step. Therefore each node
  # with a relative `at` option takes its step here, after the groups, in the
  # order of the tree.
  defp resolve(%Node{} = node, counter) do
    {at, counter} =
      if node.at && Overlay.relative?(node.at),
        do: Overlay.resolve_next(node.at, counter),
        else: {node.at, counter}

    {children, counter} = Enum.map_reduce(node.elements || [], counter, &resolve/2)
    {%Node{node | at: at, elements: children}, counter}
  end

  # The nodes with their own at option, and each node under them. They keep
  # the steps of that node, so no node shows before the node above it.
  defp owned(%Node{at: nil} = node), do: Enum.flat_map(node.elements || [], &owned/1)
  defp owned(%Node{} = node), do: nodes(node)

  # The names of the nodes of each group, in the order of the steps.
  defp by(root, :levels),
    do:
      root
      |> levels(0)
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> Enum.sort()
      |> Enum.map(&elem(&1, 1))

  defp by(root, :branches),
    do: [
      [root.name]
      | Enum.map(root.elements, fn child -> Enum.map(nodes(child), & &1.name) end)
    ]

  defp by(root, :nodes), do: root |> nodes() |> Enum.map(&[&1.name])

  defp levels(%Node{} = node, depth),
    do: [{node.name, depth} | Enum.flat_map(node.elements || [], &levels(&1, depth + 1))]

  defp put_steps(%Node{} = node, steps) do
    at =
      case Map.fetch(steps, node.name) do
        {:ok, step} -> %Overlay{pairs: [{step, :max}]}
        :error -> node.at
      end

    %Node{node | at: at, elements: Enum.map(node.elements || [], &put_steps(&1, steps))}
  end

  @doc """
  Dim each box from the first step of a later box

  A box takes the steps of its node, or of the nearest node above it with
  steps. The function adds an `on` entity with the state `dim` to each node,
  as the `dim` option of a list does to each item. A box without steps does
  not dim.
  """
  @spec dim([Node.t()]) :: [Node.t()]
  def dim(roots) do
    firsts =
      roots
      |> Enum.flat_map(&effective_list(&1, nil))
      |> Enum.flat_map(fn {_name, steps} -> Enum.take(steps || [], 1) end)
      |> Enum.uniq()

    Enum.map(roots, &dim_node(&1, nil, firsts))
  end

  defp dim_node(%Node{} = node, inherited, firsts) do
    steps = node.steps || inherited

    node =
      with [first | _rest] <- steps,
           [_ | _] = later <- Enum.filter(firsts, &(&1 > first)),
           from = Enum.min(later),
           [_ | _] = dimmed <- Enum.filter(steps, &(&1 >= from)) do
        {:ok, at} = Overlay.new(dimmed)
        %Node{node | on: (node.on || []) ++ [%On{at: at, state: :dim, steps: dimmed}]}
      else
        _none -> node
      end

    %Node{node | elements: Enum.map(node.elements || [], &dim_node(&1, steps, firsts))}
  end

  @doc """
  Return the steps of the box of each node, by its name

  A node without steps takes the steps of the nearest node above it with
  steps. A box with `nil` shows at each step of the tree.

      iex> alias Expresso.Element.Node
      iex> root = %Node{name: "a", elements: [%Node{name: "b", steps: [2, 3], elements: [%Node{name: "c"}]}]}
      iex> Expresso.Element.Hierarchy.Steps.effective(root)
      %{"a" => nil, "b" => [2, 3], "c" => [2, 3]}
  """
  @spec effective(Node.t()) :: %{String.t() => [pos_integer()] | nil}
  def effective(%Node{} = root), do: root |> effective_list(nil) |> Map.new()

  defp effective_list(%Node{} = node, inherited) do
    steps = node.steps || inherited
    [{node.name, steps} | Enum.flat_map(node.elements || [], &effective_list(&1, steps))]
  end

  @doc """
  Return the boxes of each step of a tree with `reflow`

  The function calculates one layout for each step from the boxes that show
  at that step. A node that does not show keeps its place when a node under
  it shows. The result maps each step to the layout of that step, moved to
  the center of the full layout: across for `:top_down`, and down for
  `:left_right`.
  """
  @spec layouts(Node.t(), [Layout.size()], keyword(), Layout.t()) :: [{pos_integer(), Layout.t()}]
  def layouts(%Node{} = root, sizes, options, %{width: width, height: height}) do
    steps = effective(root)
    last = steps |> Map.values() |> Enum.flat_map(&(&1 || [])) |> Enum.max(fn -> 0 end)

    for step <- 1..last//1, shown = shown(root, steps, step), shown != nil do
      layout = Layout.layout(shown, sizes, options)
      offset = center(options[:layout], layout, width, height)
      {step, Layout.layout(shown, sizes, Keyword.put(options, :offset, offset))}
    end
  end

  defp shown(%Node{} = node, steps, step) do
    children =
      node.elements |> List.wrap() |> Enum.map(&shown(&1, steps, step)) |> Enum.reject(&is_nil/1)

    visible = steps[node.name] == nil or step in steps[node.name]
    if visible or children != [], do: %Node{node | elements: children}
  end

  def center(:left_right, layout, _width, height), do: {0, (height - layout.height) / 2}
  def center(:stacked, _layout, _width, _height), do: {0, 0}
  def center(_top_down, layout, width, _height), do: {(width - layout.width) / 2, 0}

  @doc """
  Return the offset of each box at each step of a tree with `reflow`

  An offset is the place of the box at the step, less its place in the full
  layout. A box that does not show at a step takes the offset of the next
  step at which it shows, so it fades in at its place and does not move.
  After its last step, it keeps the offset of its last step.
  """
  @spec offsets([{pos_integer(), Layout.t()}], Layout.t()) :: [
          {pos_integer(), String.t(), number(), number()}
        ]
  def offsets(layouts, full) do
    home = Map.new(full.boxes, &{&1.node.name, {&1.x, &1.y}})

    places =
      for {step, layout} <- layouts, box <- layout.boxes, into: %{} do
        {{step, box.node.name}, {box.x, box.y}}
      end

    steps = Enum.map(layouts, &elem(&1, 0))

    for {name, {hx, hy}} <- home,
        step <- steps,
        {x, y} = place(places, name, step, steps),
        x != nil and (x != hx or y != hy) do
      {step, name, Layout.number(x - hx), Layout.number(y - hy)}
    end
  end

  defp place(places, name, step, steps) do
    Map.get(places, {step, name}) ||
      Enum.find_value(Enum.filter(steps, &(&1 > step)), &Map.get(places, {&1, name})) ||
      Enum.find_value(
        steps |> Enum.filter(&(&1 < step)) |> Enum.reverse(),
        &Map.get(places, {&1, name})
      ) ||
      {nil, nil}
  end

  defp nodes(%Node{} = node), do: [node | Enum.flat_map(node.elements || [], &nodes/1)]
end
