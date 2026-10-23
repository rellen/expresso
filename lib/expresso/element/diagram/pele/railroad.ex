defmodule Expresso.Element.Diagram.Pele.Railroad do
  @moduledoc """
  The plan of a railroad diagram of Pele

  | Part | `data-id` | Name |
  | --- | --- | --- |
  | A rule, with its track | `heading` | `heading` |
  | A reference to a rule | `heading` | `heading/1`, `heading/2` and on, in the order of the rules and of their definitions |

  A railroad diagram has no edges. A rule is a container, and each reference
  in its track has it as its parent. Pele gives a reference the name of the
  rule as its `data-id`, so the plan counts the references to each rule, and
  the function of the plan takes the number of earlier references with the
  same `data-id`. A terminal, such as `"#"`, has no part of its own.
  """

  @behaviour Expresso.Element.Diagram.Pele.Plan

  alias Expresso.Element.Diagram.Pele.Plan

  @impl Plan
  def plan(model) do
    references =
      for rule <- model["rules"] || [],
          name <- references(rule["definition"]),
          do: {name, rule["name"]}

    by_name = Enum.group_by(references, &elem(&1, 0), &elem(&1, 1))

    fn
      data_id, classes, count when is_binary(data_id) ->
        cond do
          "pele-rule" in classes ->
            {data_id, Plan.container()}

          "pele-nonterminal" in classes ->
            {"#{data_id}/#{count + 1}",
             Plan.node(by_name |> Map.get(data_id, []) |> Enum.at(count))}

          true ->
            {data_id, []}
        end

      nil, _classes, _count ->
        {nil, []}
    end
  end

  # The names of the rules that a definition refers to, in the order of the
  # definition.
  defp references(%{"type" => "nonterminal", "name" => name}), do: [name]
  defp references(%{"elements" => elements}), do: Enum.flat_map(elements, &references/1)

  defp references(%{"alternatives" => alternatives}),
    do: Enum.flat_map(alternatives, &references/1)

  defp references(%{"element" => element}), do: references(element)
  defp references(_definition), do: []
end
