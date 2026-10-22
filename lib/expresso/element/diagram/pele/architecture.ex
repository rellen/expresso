defmodule Expresso.Element.Diagram.Pele.Architecture do
  @moduledoc """
  The plan of an architecture diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A service or a junction | `api` | `api` |
  | A group | `cloud` | `cloud` |
  | An edge | `web-api` | `web->api`, by its two ends |
  | A second edge between the same ends | `web-api` | `web->api:2` |

  Pele gives each edge between the same two ends the same `data-id`, and the
  label of an edge that same `data-id` too. Therefore the function of this
  plan takes the number of earlier elements with the same `data-id` and the
  same classes. The edges come in the order of the model, and the labels in
  the order of the edges with a title.

  The arrow of an edge is `->` for a head at its second end, such as
  `web:R --> L:api`, `<-` for a head at its first end, `<->` for a head at
  each end, and `--` for no head. A service, a junction or a group in a group
  has that group as its parent.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents =
      for {id, item} <- Map.merge(model["groups"] || %{}, model["nodes"] || %{}),
          into: %{},
          do: {id, item["in"]}

    {edges, keys} = edges(model["edges"] || [])
    named = Plan.edges(edges)

    labels =
      edges
      |> Enum.filter(& &1.label)
      |> Enum.group_by(&data_id/1, & &1.key)

    fn data_id, classes, count ->
      part(data_id, classes, count, %{parents: parents, keys: keys, named: named, labels: labels})
    end
  end

  defp part(data_id, classes, count, plan) do
    cond do
      "pele-edge" in classes -> plan.named[plan.keys[{data_id, count}]] || {data_id, []}
      "pele-edge-label" in classes -> {label(data_id, count, plan), []}
      "pele-cluster" in classes -> {data_id, Plan.container(plan.parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(plan.parents[data_id])}
      true -> {data_id, []}
    end
  end

  # The label at the index `count` of a `data-id` belongs to the edge at that
  # index among the edges of the `data-id` with a title.
  defp label(data_id, count, plan) do
    case plan.labels |> Map.get(data_id, []) |> Enum.at(count) do
      nil -> data_id
      key -> plan.named[key] |> elem(0)
    end
  end

  # Each edge gets the key `<data-id>#<count>`, with the number of the edges
  # before it that have the same `data-id`.
  defp edges(edges) do
    {edges, {keys, _counts}} =
      Enum.map_reduce(edges, {%{}, %{}}, fn edge, {keys, counts} ->
        data_id = "#{edge["lhsId"]}-#{edge["rhsId"]}"
        count = Map.get(counts, data_id, 0)
        key = "#{data_id}##{count}"

        edge = %{
          key: key,
          from: edge["lhsId"],
          to: edge["rhsId"],
          arrow: arrow(edge["lhsInto"], edge["rhsInto"]),
          label: edge["title"],
          name: nil
        }

        {edge, {Map.put(keys, {data_id, count}, key), Map.put(counts, data_id, count + 1)}}
      end)

    {edges, keys}
  end

  defp data_id(%{key: key}), do: key |> String.split("#") |> hd()

  defp arrow(true, true), do: "<->"
  defp arrow(true, _second), do: "<-"
  defp arrow(_first, true), do: "->"
  defp arrow(_first, _second), do: "--"
end
