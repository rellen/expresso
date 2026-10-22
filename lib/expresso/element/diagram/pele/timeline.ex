defmodule Expresso.Element.Diagram.Pele.Timeline do
  @moduledoc """
  The plan of a timeline of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A section | `Early` | `Early` |
  | A period, with its line and its dot | `2025` | `2025` |
  | An event of a period | none | `2025/1`, `2025/2` and on, in the order of the source |

  A timeline draws no line between two periods, so it has no edges. A period
  is a container: it holds its events, and it has its section as its parent.
  Pele draws each event with no `data-id`, in the order of the periods and of
  their events.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    periods = model["periods"] || []
    sections = for period <- periods, into: %{}, do: {name(period), period["section"]}

    events =
      for period <- periods,
          {_event, index} <- Enum.with_index(period["events"] || [], 1),
          do: {"#{name(period)}/#{index}", name(period)}

    fn
      nil, classes, count -> event(classes, Enum.at(events, count))
      data_id, classes, _count -> part(data_id, classes, sections)
    end
  end

  # Pele gives a period the text of the source with no space at its ends.
  defp name(period), do: String.trim(period["text"] || "")

  defp event(classes, {name, period}) do
    if "pele-event" in classes, do: {name, Plan.node(period)}, else: {nil, []}
  end

  defp event(_classes, nil), do: {nil, []}

  defp part(data_id, classes, sections) do
    cond do
      "pele-period" in classes -> {data_id, Plan.container(sections[data_id])}
      "pele-section" in classes -> {data_id, Plan.container()}
      true -> {data_id, []}
    end
  end
end
