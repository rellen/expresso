defmodule Expresso.Element.Diagram.Pele.Plan do
  @moduledoc """
  The plan of a diagram type of Pele, and the functions that each plan uses

  A plan takes the model of `parse()` and returns a function. That function
  takes the `data-id` and the classes of an element of the SVG, and it returns
  the name of the element and its marks for `Expresso.Element.Diagram.Outline`.
  `Expresso.Element.Diagram.Pele.name/1` gives the first element of each name
  its marks, and each later element of the name only its `id`.

  Some types give more than one part the same `data-id`, such as two edges
  of an architecture diagram between the same services. The function of such
  a plan takes a third argument: the number of earlier elements with the same
  `data-id` and the same classes.

  A plan with three arguments also gets each node and each edge that has no
  `data-id`, such as a line of a mindmap, with `nil` as its `data-id`. The
  count of such an edge is the number of earlier edges with no `data-id`,
  whatever their other classes, and the same is true for a node. The plan
  returns the name `nil` for an element that keeps no name.

  The functions of this module make the marks:

  | Function | Marks |
  | --- | --- |
  | `node/1` | `data-graph-kind="node"`, and `data-graph-parent` |
  | `container/1` | `data-graph-kind="container"`, and `data-graph-parent` |
  | `edges/1` | `data-graph-kind="edge"`, `data-graph-from`, `data-graph-to`, `data-graph-arrow` and `data-graph-label` |
  """

  @typedoc "The name of an element and its marks"
  @type part :: {String.t() | nil, [{String.t(), String.t()}]}

  @typedoc """
  The function of a plan: the `data-id` and the classes of an element give its
  part. A function with three arguments takes the number of earlier elements
  with the same `data-id` and the same classes too.
  """
  @type t ::
          (String.t(), [String.t()] -> part())
          | (String.t() | nil, [String.t()], non_neg_integer() -> part())

  @typedoc """
  An edge of a model: its key, which is its `data-id` in the SVG, its two ends,
  its arrow, its label, and the name that the source gives it, or `nil`
  """
  @type edge :: %{
          key: String.t(),
          from: String.t(),
          to: String.t(),
          arrow: String.t(),
          label: String.t() | nil,
          name: String.t() | nil
        }

  @doc "Make the function of a plan from the model of a diagram"
  @callback plan(model :: map()) :: t()

  @doc "The marks of a node, with its parent or `nil`"
  @spec node(String.t() | nil) :: [{String.t(), String.t()}]
  def node(parent \\ nil), do: [{"data-graph-kind", "node"} | parent(parent)]

  @doc "The marks of a container, with its parent or `nil`"
  @spec container(String.t() | nil) :: [{String.t(), String.t()}]
  def container(parent \\ nil), do: [{"data-graph-kind", "container"} | parent(parent)]

  defp parent(nil), do: []
  defp parent(parent), do: [{"data-graph-parent", parent}]

  @doc """
  The name and the marks of each edge, by its key

  An edge without a name gets its two ends and its arrow, such as `web->api`.
  A second edge between the same ends gets `:2` after its name, as for
  Graphviz and D2.

      iex> edges = [
      ...>   %{key: "e0", from: "a", to: "b", arrow: "->", label: nil, name: nil},
      ...>   %{key: "e1", from: "a", to: "b", arrow: "->", label: "again", name: nil}
      ...> ]
      iex> Expresso.Element.Diagram.Pele.Plan.edges(edges)["e1"]
      {"a->b:2", [{"data-graph-kind", "edge"}, {"data-graph-from", "a"}, {"data-graph-to", "b"}, {"data-graph-arrow", "->"}, {"data-graph-label", "again"}]}
  """
  @spec edges([edge()]) :: %{String.t() => part()}
  def edges(edges) do
    {named, _counts} =
      Enum.map_reduce(edges, %{}, fn edge, counts ->
        {name, counts} = name(edge, counts)

        marks =
          [
            {"data-graph-kind", "edge"},
            {"data-graph-from", edge.from},
            {"data-graph-to", edge.to},
            {"data-graph-arrow", edge.arrow}
          ] ++ label(edge.label)

        {{edge.key, {name, marks}}, counts}
      end)

    Map.new(named)
  end

  defp name(%{name: name}, counts) when is_binary(name), do: {name, counts}

  defp name(edge, counts) do
    base = edge.from <> edge.arrow <> edge.to
    count = Map.get(counts, base, 0) + 1
    {if(count == 1, do: base, else: "#{base}:#{count}"), Map.put(counts, base, count)}
  end

  defp label(text) when is_binary(text) and text != "", do: [{"data-graph-label", text}]
  defp label(_text), do: []

  @doc """
  The name of each element of a list in order, with a prefix and a number from 1

      iex> Expresso.Element.Diagram.Pele.Plan.numbered(["i6", "i9"], "note")
      %{"i6" => "note1", "i9" => "note2"}
  """
  @spec numbered([String.t()], String.t()) :: %{String.t() => String.t()}
  def numbered(keys, prefix) do
    keys |> Enum.with_index(1) |> Map.new(fn {key, index} -> {key, "#{prefix}#{index}"} end)
  end

  @doc "The plan of a type with no plan: each element keeps its `data-id`, with no marks"
  @spec plain() :: t()
  def plain, do: fn data_id, _classes -> {data_id, []} end
end
