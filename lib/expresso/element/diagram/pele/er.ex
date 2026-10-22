defmodule Expresso.Element.Diagram.Pele.Er do
  @moduledoc """
  The plan of an entity relationship diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | An entity | `CUSTOMER` | `CUSTOMER` |
  | A relationship | `id_entity-CUSTOMER-0_entity-ORDER-1_0` | `CUSTOMER--ORDER`, by its two entities |
  | A second relationship between the same entities | `id_entity-CUSTOMER-0_entity-ORDER-1_3` | `CUSTOMER--ORDER:2` |

  The model gives each entity an id, such as `entity-CUSTOMER-0`, and the
  relationships in the order of the source. Pele names the relationship at the
  index `n` from 0 `id_<entity id>_<entity id>_<n>`. A relationship has no
  direction, so its arrow is `--`, and its label is the role of the source,
  such as `places`.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    names = for {name, %{"id" => id}} <- model["entities"] || %{}, into: %{}, do: {id, name}

    edges =
      (model["relationships"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {relationship, index} ->
        {from, to} = {relationship["entityA"], relationship["entityB"]}

        %{
          key: "id_#{from}_#{to}_#{index}",
          from: names[from] || from,
          to: names[to] || to,
          arrow: "--",
          label: relationship["roleA"],
          name: nil
        }
      end)
      |> Plan.edges()

    fn data_id, classes -> part(data_id, classes, edges) end
  end

  defp part(data_id, classes, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-node" in classes -> {data_id, Plan.node()}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
