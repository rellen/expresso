defmodule Expresso.Element.Diagram.Pele.Treemap do
  @moduledoc """
  The plan of a treemap of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A section | `Code` | `Code` |
  | A leaf | `Elixir` | `Elixir` |

  A treemap has no edges. A section is a container, and each section or leaf
  in it has it as its parent. Two leaves with the same name in two sections
  get the same name, so a part shows both.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents = parents(model["roots"] || [], nil, %{})

    fn data_id, classes ->
      cond do
        "pele-section" in classes -> {data_id, Plan.container(parents[data_id])}
        "pele-leaf" in classes -> {data_id, Plan.node(parents[data_id])}
        true -> {data_id, []}
      end
    end
  end

  defp parents(items, parent, acc) do
    Enum.reduce(items, acc, fn item, acc ->
      parents(item["children"] || [], item["name"], Map.put_new(acc, item["name"], parent))
    end)
  end
end
