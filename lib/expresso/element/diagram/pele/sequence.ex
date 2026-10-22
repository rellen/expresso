defmodule Expresso.Element.Diagram.Pele.Sequence do
  @moduledoc """
  The plan of a sequence diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | An actor or a participant | `Web` | `Web` |
  | A message | `i0` | `Customer->Web`, by its two ends |
  | A second message between the same actors in the same direction | `i5` | `Customer->Web:2` |
  | A note | `i6` | `note1`, `note2` and on, in the order of the source |

  Pele draws each actor two times, at the top and at the bottom, and its
  lifeline and its activations have the `data-id` of the actor. Thus each of
  them gets the name of the actor, and a part of the actor shows them at its
  steps. The label of a message gets the name of its message.

  A message is an edge of the graph from one actor to the other, with the arrow
  `<->` for a message with a head at each end and `->` for each other message.
  With `edges :follow`, a message without a part shows from the step where both
  of its actors show. A note is a node with no edges.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  # The types of a message of Mermaid: 2 is a note, 17 and 18 start and end an
  # activation, and 33 and 34 have a head at each end.
  @note 2
  @activation [17, 18]
  @both [33, 34]

  @impl Plan
  def plan(model) do
    messages = model["messages"] || []

    edges =
      for message <- messages,
          message["type"] not in [@note | @activation],
          is_binary(message["to"]) do
        %{
          key: "i" <> message["id"],
          from: message["from"],
          to: message["to"],
          arrow: if(message["type"] in @both, do: "<->", else: "->"),
          label: message["message"],
          name: nil
        }
      end
      |> Plan.edges()

    notes = Plan.numbered(for(%{"type" => @note, "id" => id} <- messages, do: "i" <> id), "note")

    fn data_id, classes -> part(data_id, classes, edges, notes) end
  end

  defp part(data_id, classes, edges, notes) do
    cond do
      Map.has_key?(notes, data_id) -> {notes[data_id], Plan.node()}
      "pele-message" in classes -> edges[data_id] || {data_id, []}
      "pele-actor" in classes -> {data_id, Plan.node()}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end
end
