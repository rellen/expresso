defmodule Expresso.Element.Diagram.Pele.TreeView do
  @moduledoc """
  The plan of a tree view of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A directory | `lib` | `lib`, its name without the `/` |
  | A file | `mix.exs` | `mix.exs` |

  A tree view has no edges. A directory is a container, and each directory
  or file in it has it as its parent. Two files with the same name in two
  directories get the same name, so a part shows both. The guides between
  the rows show at each step.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    parents = parents(get_in(model, ["root", "children"]) || [], nil, %{})

    fn data_id, classes ->
      cond do
        "pele-tree-dir" in classes -> {data_id, Plan.container(parents[data_id])}
        "pele-tree-file" in classes -> {data_id, Plan.node(parents[data_id])}
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
