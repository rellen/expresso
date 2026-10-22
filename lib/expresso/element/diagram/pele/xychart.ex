defmodule Expresso.Element.Diagram.Pele.Xychart do
  @moduledoc """
  The plan of an XY chart of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A series with a title | `Shop` | Its title, such as `Shop` for `bar "Shop" [30, 60, 80]` |
  | A series without a title | none | Its type and its number among the series of that type, from 1, such as `line1` |

  An XY chart has no edges. Each series is a node. Pele gives a series with a
  title its title as its `data-id`, and a series without a title no
  `data-id`. Pele draws each bar series, then each line series, each in the
  order of the source. The plan names the series without a title at the index
  `n` from 0 by the series without a title at that index in the same order.
  The bars and the points of a series show with their series.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    {names, _counts} =
      Enum.map_reduce(model["plots"] || [], %{}, fn plot, counts ->
        number = Map.get(counts, plot["type"], 0) + 1
        name = if plot["title"] in [nil, ""], do: "#{plot["type"]}#{number}"
        {name, Map.put(counts, plot["type"], number)}
      end)

    # Only the series without a title have no `data-id`. Pele draws each bar
    # series before each line series.
    untitled =
      (model["plots"] || [])
      |> Enum.zip(names)
      |> Enum.reject(fn {_plot, name} -> is_nil(name) end)
      |> Enum.sort_by(fn {plot, _name} -> plot["type"] != "bar" end)
      |> Enum.map(&elem(&1, 1))

    fn
      nil, classes, count -> series(classes, Enum.at(untitled, count))
      data_id, classes, _count -> series(classes, data_id)
    end
  end

  defp series(classes, name) when is_binary(name) do
    if "pele-series" in classes, do: {name, Plan.node()}, else: {name, []}
  end

  defp series(_classes, nil), do: {nil, []}
end
