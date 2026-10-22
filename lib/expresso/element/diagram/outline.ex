defmodule Expresso.Element.Diagram.Outline do
  @moduledoc """
  The list of a graph for a screen reader

  A screen reader reads the text of an SVG in the order of the file, and that
  order is not the order of the graph. Therefore the render writes a nested
  list of the graph next to the SVG, and the style sheet hides the list from
  the eye, as it hides the list of a `tree`. The list holds each container
  with its nodes, and each node with the edges that leave it, such as "web,
  to api".

  The tools mark each element of the graph for this module:

  | Attribute | Value |
  | --- | --- |
  | `data-graph-kind` | `node`, `container` or `edge` |
  | `data-graph-parent` | The `id` of the container of a node or of a container |
  | `data-graph-from`, `data-graph-to` | The ends of an edge |
  | `data-graph-arrow` | The arrow of an edge: `->`, `<-`, `<->` or `--` |
  | `data-graph-label` | The label of an edge, when the label is not inside the group of the edge |

  The label of an element is the text that it shows, or its name when it
  shows no text.
  """

  @typedoc "An item of the list: its label, the edges that leave it, and its children"
  @type item :: %{label: String.t(), edges: [String.t()], children: [item()]}

  @doc """
  Return the items of the list of a graph, from its SVG

  The items are in the order of the file. An SVG without a marked element
  returns an empty list.
  """
  @spec items(String.t()) :: [item()]
  def items(svg) do
    tree = Floki.parse_fragment!(svg)

    shapes =
      for {"g", attrs, _} = group <-
            Floki.find(tree, ~s(g[data-graph-kind="node"], g[data-graph-kind="container"])),
          attrs = Map.new(attrs),
          do: %{
            id: attrs["id"],
            parent: attrs["data-graph-parent"],
            label: label(group, attrs["id"])
          }

    labels = Map.new(shapes, &{&1.id, &1.label})

    edges =
      for {"g", attrs, _} = group <- Floki.find(tree, ~s(g[data-graph-kind="edge"])),
          attrs = Map.new(attrs),
          do: edge(attrs, attrs["data-graph-label"] || text(group), labels)

    ids = MapSet.new(shapes, & &1.id)
    tops = Enum.filter(shapes, &(&1.parent == nil or not MapSet.member?(ids, &1.parent)))
    Enum.map(tops, &item(&1, shapes, edges))
  end

  defp item(shape, shapes, edges) do
    %{
      label: shape.label,
      edges: for({source, text} <- edges, source == shape.id, do: text),
      children: for(child <- shapes, child.parent == shape.id, do: item(child, shapes, edges))
    }
  end

  # The text of an edge, under the node that it leaves. An edge with `<-`
  # leaves its second end, and an edge with no direction goes with its first.
  defp edge(attrs, label, labels) do
    {from, to} = {attrs["data-graph-from"], attrs["data-graph-to"]}

    {source, word, target} =
      case attrs["data-graph-arrow"] do
        "->" -> {from, "to", to}
        "<-" -> {to, "to", from}
        _both -> {from, "with", to}
      end

    text = "#{word} #{Map.get(labels, target, target)}"
    {source, if(label == "", do: text, else: "#{text} (#{label})")}
  end

  defp label(group, id) do
    case text(group) do
      "" -> id
      text -> text
    end
  end

  # The text of the `text` elements of a group, with no `title`.
  defp text(group) do
    group
    |> Floki.find("text")
    |> Enum.map_join(" ", &Floki.text/1)
    |> String.split()
    |> Enum.join(" ")
  end
end
