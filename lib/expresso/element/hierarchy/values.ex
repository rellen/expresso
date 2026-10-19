defmodule Expresso.Element.Hierarchy.Values do
  @moduledoc """
  The values of a tree: the sums, the order, the limit, the depth and the text

  `prepare/2` changes the tree before the layout, in this order:

  1. `depth` cuts the tree at a level. A node at the last level gets the
     total of its subtree as its value.
  2. `sum` gives a node with no value the sum of the values of its nodes.
  3. `sort` puts the nodes under each node in the order of their values.
  4. `limit` keeps a number of nodes under each node, and one more node holds
     the sum of the rest.

  `text/3` writes a value in the format of the `value_format` option. The
  layout and the renderer then read the prepared tree only, so each part of
  the drawing shows the same values.
  """

  alias Expresso.Element.Node
  alias Expresso.Element.Stat

  @typedoc "The options of the tree that change the values"
  @type options :: [
          depth: pos_integer() | nil,
          sum: boolean(),
          sort: :value | :none,
          limit: pos_integer() | nil
        ]

  @doc """
  Return the tree with the values, the order and the levels of the options

      iex> alias Expresso.Element.Node
      iex> root = %Node{name: "/", elements: [%Node{name: "a", value: 1}, %Node{name: "b", value: 5}, %Node{name: "c", value: 2}]}
      iex> root = Expresso.Element.Hierarchy.Values.prepare(root, sum: true, sort: :value, limit: 2)
      iex> root.value
      8
      iex> Enum.map(root.elements, &{&1.label || &1.name, &1.value})
      [{"b", 5}, {"c", 2}, {"1 more", 1}]
  """
  @spec prepare(Node.t(), options()) :: Node.t()
  def prepare(%Node{} = root, options) do
    root
    |> cut(options[:depth], 1)
    |> fill(Keyword.get(options, :sum, true))
    |> order(options[:sort] || :none, options[:limit])
  end

  @doc """
  Return the value of a node, or the total of the values under it

      iex> alias Expresso.Element.Node
      iex> Expresso.Element.Hierarchy.Values.total(%Node{name: "a", elements: [%Node{name: "b", value: 2}, %Node{name: "c", value: 3.5}]})
      5.5
      iex> Expresso.Element.Hierarchy.Values.total(%Node{name: "a"})
      nil
  """
  @spec total(Node.t()) :: number() | nil
  def total(%Node{value: value}) when value != nil, do: value
  def total(%Node{elements: children}), do: children |> List.wrap() |> Enum.map(&total/1) |> sum()

  defp cut(%Node{} = node, nil, _level), do: node

  defp cut(%Node{} = node, depth, level) when level >= depth,
    do: %Node{node | value: total(node), elements: []}

  defp cut(%Node{} = node, depth, level),
    do: %Node{node | elements: Enum.map(node.elements || [], &cut(&1, depth, level + 1))}

  defp fill(%Node{} = node, sum?) do
    children = Enum.map(node.elements || [], &fill(&1, sum?))

    value =
      if node.value == nil and sum?,
        do: children |> Enum.map(& &1.value) |> sum(),
        else: node.value

    %Node{node | value: value, elements: children}
  end

  defp order(%Node{} = node, sort, limit) do
    children =
      (node.elements || [])
      |> Enum.map(&order(&1, sort, limit))
      |> sort(sort)
      |> limit(limit, node)

    %Node{node | elements: children}
  end

  # A node with no value goes after the nodes with a value. The sort is
  # stable, so two nodes with the same value keep the order of the data.
  defp sort(children, :value),
    do: Enum.sort_by(children, &{&1.value != nil, &1.value || 0}, :desc)

  defp sort(children, :none), do: children

  defp limit(children, limit, parent) when is_integer(limit) and length(children) > limit do
    {kept, rest} = Enum.split(children, limit)

    # The node of the rest shows with the last node that the limit keeps.
    last = List.last(kept)

    more = %Node{
      name: more_name(parent),
      label: "#{length(rest)} more",
      class: "tree-more",
      value: rest |> Enum.map(&total/1) |> sum(),
      elements: [],
      steps: last.steps,
      effect: last.effect,
      speed: last.speed,
      easing: last.easing
    }

    kept ++ [more]
  end

  defp limit(children, _limit, _parent), do: children

  @doc """
  Return the name of the node that holds the rest of the nodes under a node

  The name starts with a character that no name of the data holds, so it
  cannot be the name of a different node.
  """
  @spec more_name(Node.t()) :: String.t()
  def more_name(%Node{name: name}), do: "\u0000more:" <> name

  defp sum([]), do: nil

  defp sum(values) do
    case Enum.reject(values, &is_nil/1) do
      [] -> nil
      values -> Enum.sum(values)
    end
  end

  @doc """
  Write a value in a format

  `total` is the value of the root, for the format `:percent`.

      iex> alias Expresso.Element.Hierarchy.Values
      iex> Values.text(1250, :number, nil)
      "1,250"
      iex> Values.text(2.0 / 3, :number, nil)
      "0.67"
      iex> Values.text(412_000_000_000, :bytes, nil)
      "412 GB"
      iex> Values.text(4_150_000, :bytes, nil)
      "4.2 MB"
      iex> Values.text(512, :bytes, nil)
      "512 B"
      iex> Values.text(25, :percent, 200)
      "12.5%"
      iex> Values.text(200, :percent, 200)
      "100%"
  """
  @spec text(number(), :number | :bytes | :percent, number() | nil) :: String.t()
  def text(value, :number, _total), do: number(value, 2)

  def text(value, :bytes, _total) do
    {scaled, unit} = bytes(value, ~w(B KB MB GB TB PB EB))

    cond do
      unit == "B" -> number(value, 0) <> " B"
      scaled < 10 -> number(scaled, 1) <> " " <> unit
      true -> number(round(scaled), 0) <> " " <> unit
    end
  end

  def text(value, :percent, total), do: number(value / total * 100, 1) <> "%"

  # The largest unit in which the value is 1 or more.
  defp bytes(value, [unit]), do: {value, unit}
  defp bytes(value, [unit | _rest]) when value < 1000, do: {value, unit}
  defp bytes(value, [_unit | rest]), do: bytes(value / 1000, rest)

  # A number with at most `decimals` decimals, no zero at the end of the
  # fraction, and a comma between each group of three digits.
  defp number(value, _decimals) when is_integer(value), do: Stat.format(value, 0, true)

  defp number(value, decimals) do
    rounded = Float.round(value * 1.0, decimals)

    if rounded == trunc(rounded),
      do: Stat.format(trunc(rounded), 0, true),
      else: Stat.format(rounded, min(Stat.decimals(rounded), decimals), true)
  end
end
