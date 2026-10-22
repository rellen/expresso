defmodule Expresso.Element.Diagram.Pele.State do
  @moduledoc """
  The plan of a state diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A state | `Draft` | `Draft` |
  | A composite state | `Review` | `Review` |
  | The start or the end of the diagram | `root_start`, `root_end` | `root_start`, `root_end` |
  | The start or the end in a composite state | `Review_start` | `Review_start` |
  | A transition | `edge1` | `Draft->Submitted`, by its two states |
  | A second transition between the same states in the same direction | `edge9` | `Draft->Submitted:2` |
  | A note | `Draft----note-8` | `note1`, `note2` and on, in the order of the source |
  | The line from a note to its state | `Draft-Draft----note-8` | `note1--Draft` |

  Pele numbers the transitions in the order of the source, and it counts the
  transitions in a composite state where the source declares that state. A
  composite state is a container, and each state in it has the composite state
  as its parent. A concurrent region has no group, so a state of a region has
  the composite state as its parent too.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    %{relations: relations, parents: parents, notes: notes} =
      walk(model["rootDoc"] || [], nil, %{relations: [], parents: %{}, notes: []})

    transitions =
      relations
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map(fn {relation, index} ->
        %{
          key: "edge#{index}",
          from: relation["state1"]["id"],
          to: relation["state2"]["id"],
          arrow: "->",
          label: relation["description"],
          name: nil
        }
      end)

    notes = notes |> Enum.reverse() |> Plan.numbered("note")

    note_edges =
      for {state, note} <- notes,
          do: %{key: state, from: note, to: state, arrow: "--", label: nil, name: nil}

    edges = Plan.edges(transitions ++ note_edges)

    fn data_id, classes -> part(data_id, classes, parents, edges, notes) end
  end

  # The statements of a document, in the order of the source. A state with a
  # document is a composite state, and its statements come at its place.
  defp walk(statements, parent, acc) do
    Enum.reduce(statements, acc, fn statement, acc -> statement(statement, parent, acc) end)
  end

  defp statement(%{"stmt" => "relation"} = relation, parent, acc) do
    parents =
      acc.parents
      |> Map.put_new(relation["state1"]["id"], parent)
      |> Map.put_new(relation["state2"]["id"], parent)

    %{acc | relations: [relation | acc.relations], parents: parents}
  end

  # Pele draws no group for a concurrent region of a composite state, so each
  # state of a region has the composite state as its parent.
  defp statement(%{"stmt" => "state", "type" => "divider"} = state, parent, acc),
    do: walk(state["doc"] || [], parent, acc)

  defp statement(%{"stmt" => "state", "id" => id} = state, parent, acc) do
    acc = %{acc | parents: Map.put_new(acc.parents, id, parent)}

    acc =
      if state["note"] && id not in acc.notes, do: %{acc | notes: [id | acc.notes]}, else: acc

    walk(state["doc"] || [], id, acc)
  end

  defp statement(_statement, _parent, acc), do: acc

  defp part(data_id, classes, parents, edges, notes) do
    if "pele-note-edge" in classes or "pele-note" in classes,
      do: note(data_id, classes, edges, notes),
      else: state(data_id, classes, parents, edges)
  end

  defp note(data_id, classes, edges, notes) do
    if "pele-note-edge" in classes,
      do: edges[line_state(data_id)] || {data_id, []},
      else: {notes[note_state(data_id)] || data_id, Plan.node()}
  end

  defp state(data_id, classes, parents, edges) do
    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, Plan.container(parents[data_id])}
      "pele-node" in classes -> {data_id, Plan.node(parents[data_id])}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end

  # Pele names a note `<state>----note-<n>`, and the line of the note
  # `<state>-<state>----note-<n>`.
  defp note_state(data_id), do: data_id |> String.split("----note-") |> hd()

  defp line_state(data_id) do
    double = note_state(data_id)
    size = div(byte_size(double) - 1, 2)
    binary_part(double, 0, size)
  end
end
