defmodule Expresso.Element.Diagram.Pele.Class do
  @moduledoc """
  The plan of a class diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A class | `Turtle` | `Turtle` |
  | A namespace | `Reef` | `Reef` |
  | A relation | `id_Animal_Turtle_1` | `Animal<-Turtle`, by its two classes and its arrow |
  | A second relation between the same classes in the same direction | `id_Animal_Turtle_5` | `Animal<-Turtle:2` |
  | A note | `note0` | `note0` |
  | The line from a note to its class | `edgeNote0` | `note0--Turtle` |

  The model gives the relations in the order of the source, with no id. Pele
  names the relation at the index `n` from 1 `id_<class>_<class>_<n>`. The arrow
  of a relation is `->` for a marker at its second class, such as `-->` or
  `--|>`, `<-` for a marker at its first class, such as `<|--`, `<->` for a
  marker at each end, and `--` for no marker. A class in a namespace has the
  namespace as its parent.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for {namespace, %{"classes" => classes}} <- model["namespaces"] || %{},
          {class, _} <- classes,
          into: %{},
          do: {class, namespace}

    relations =
      (model["relations"] || [])
      |> Enum.with_index(1)
      |> Enum.map(fn {relation, index} ->
        {from, to} = {relation["id1"], relation["id2"]}

        %{
          key: "id_#{from}_#{to}_#{index}",
          from: from,
          to: to,
          arrow: arrow(relation["relation"] || %{}),
          label: relation["title"],
          name: nil
        }
      end)

    notes =
      for {id, note} <- model["notes"] || %{} do
        %{
          key: "edgeNote#{note["index"]}",
          from: id,
          to: note["class"],
          arrow: "--",
          label: nil,
          name: nil
        }
      end

    edges = Plan.edges(relations ++ Enum.sort_by(notes, & &1.key))

    fn data_id, classes -> part(data_id, classes, parents, edges) end
  end

  defp part(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end

  # A marker of the type "none" is no marker at its end.
  defp arrow(%{"type1" => first, "type2" => second}) do
    case {first != "none", second != "none"} do
      {true, true} -> "<->"
      {true, false} -> "<-"
      {false, true} -> "->"
      {false, false} -> "--"
    end
  end

  defp arrow(_relation), do: "--"
end
