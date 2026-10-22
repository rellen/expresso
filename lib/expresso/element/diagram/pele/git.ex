defmodule Expresso.Element.Diagram.Pele.Git do
  @moduledoc """
  The plan of a git graph of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A branch, with its lane and its label | `feature` | `feature` |
  | A commit | `deck` | `deck`, its id |
  | The line from a parent to a commit | none | `deck--chart`, by the parent and the commit |

  A commit has its branch as its parent, so the list for a screen reader
  holds the commits of each branch under the branch. A commit without an id in
  the source gets the id of Mermaid, such as `0-a1b2c3d`.

  Pele draws the lines with no `data-id`. It takes the commits in the order of
  the source, and for each commit the line from each of its parents: first
  each line between two branches, then each line on one branch. The plan
  names the line at the index `n` from 0 by the line at that index in the same
  order. A line has no head, so its arrow is `--`.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    commits = model["commits"] || %{}
    ordered = commits |> Map.values() |> Enum.sort_by(& &1["seq"])

    lines =
      for commit <- ordered,
          parent <- commit["parents"] || [],
          Map.has_key?(commits, parent) and parent != commit["id"],
          do: {commits[parent]["branch"] != commit["branch"], parent, commit["id"]}

    {across, along} = Enum.split_with(lines, &elem(&1, 0))

    edges =
      (across ++ along)
      |> Enum.with_index()
      |> Enum.map(fn {{_across, from, to}, index} ->
        %{key: "#{index}", from: from, to: to, arrow: "--", label: nil, name: nil}
      end)
      |> Plan.edges()

    fn
      nil, _classes, count -> edges["#{count}"] || {nil, []}
      data_id, classes, _count -> part(data_id, classes, commits)
    end
  end

  defp part(data_id, classes, commits) do
    cond do
      "pele-branch" in classes -> {data_id, Plan.container()}
      "pele-commit" in classes -> {data_id, Plan.node(commits[data_id]["branch"])}
      true -> {data_id, []}
    end
  end
end
