defmodule Expresso.Element.Math.Each do
  @moduledoc """
  The parts of a formula that name each occurrence of a symbol

  A `part` entity with `each: "x"` names each occurrence of `x`. An occurrence
  is a token element of the MathML, `mi`, `mn` or `mo`, with the text `x`. The
  scope is the part of `within`, or the part with the name of the entity in the
  short form, or else the whole formula. With `bare: true`, the base of a
  symbol with an index, such as the `x` of `x_1`, is not an occurrence.
  `docs/each-occurrence.md` gives the design.

  The occurrence `n` of a set also gets the class `set-n`. A copy to a set
  thus becomes one copy for each occurrence, and
  `Expresso.Element.Math.Links` can take one occurrence as the source of a
  link.
  """

  alias Expresso.Element.Part

  @tokens ~w(mi mn mo)

  # The elements of MathML with a base and an index. The base is the first
  # child.
  @scripts ~w(msub msup msubsup)

  @doc """
  Give each occurrence of each part with `each` the class of its part

  A named set keeps its name, and its occurrences get it as a class. In the
  short form, the name of the part is the name of its scope, so the part
  takes the name `each-name`, and its occurrences get that class. The
  occurrence `n` also gets the class `name-n`.

  A copy to a set becomes one copy for each occurrence, with the target
  `set-n` and the name `copy-n`. A copy of a set to a set pairs the
  occurrences in order.

  The function raises for a scope that the formula does not have, for a part
  with no occurrence, for a copy of a set to a set with a different number of
  occurrences, and for a copy of a copy to a set.
  """
  @spec place(Expresso.Element.Math.t()) :: Expresso.Element.Math.t()
  def place(%Expresso.Element.Math{text: text, elements: parts} = math) when is_binary(text) do
    if Enum.any?(parts, & &1.each) do
      names = Expresso.Element.Math.parts(text)

      {parts, {tree, sets}} =
        Enum.map_reduce(parts, {Floki.parse_fragment!(text), %{}}, fn part, {tree, sets} ->
          mark(part, tree, sets, names)
        end)

      parts = Enum.flat_map(parts, &expand(&1, parts, sets))
      %Expresso.Element.Math{math | text: Floki.raw_html(tree), elements: parts}
    else
      math
    end
  end

  def place(math), do: math

  defp mark(%Part{each: nil} = part, tree, sets, _names), do: {part, {tree, sets}}

  defp mark(%Part{id: id, each: symbol, within: within, bare: bare} = part, tree, sets, names) do
    {scope, part} =
      cond do
        within != nil ->
          unless within in names do
            raise ArgumentError,
                  "the part #{inspect(id)} of a math element looks within #{inspect(within)}, " <>
                    "and the formula has no part with that name"
          end

          {within, part}

        id in names ->
          {id, %Part{part | id: "each-#{id}"}}

        true ->
          {nil, part}
      end

    select = %{scope: scope, symbol: symbol, class: part.id, bare: bare == true}
    {tree, count} = add_class(tree, scope == nil, false, select, 0)

    if count == 0 do
      raise ArgumentError,
            "the part #{inspect(id)} of a math element selects each #{inspect(symbol)}, " <>
              "and the formula has none there"
    end

    {part, {tree, Map.put(sets, part.id, count)}}
  end

  # A copy to a set becomes one copy for each occurrence. A copy of a set to a
  # set takes the occurrence with the same number.
  defp expand(%Part{copy_to: target, copy_of: source} = copy, parts, sets)
       when is_map_key(sets, target) do
    count = Map.fetch!(sets, target)

    if Enum.any?(parts, &(&1.copy_of == copy.id)) do
      raise ArgumentError,
            "the copy #{inspect(copy.id)} of a math element goes to the set " <>
              "#{inspect(target)}, so it cannot have a copy. Give the copy of a copy a " <>
              "copy of the source"
    end

    source_of =
      case Map.fetch(sets, source) do
        {:ok, ^count} ->
          &"#{source}-#{&1}"

        {:ok, other} ->
          raise ArgumentError,
                "the part #{inspect(source)} of a math element has #{other} occurrences, and " <>
                  "its copy goes to the set #{inspect(target)} with #{count}. A copy of a set " <>
                  "to a set needs the same number"

        :error ->
          fn _n -> source end
      end

    for n <- 1..count do
      %Part{copy | id: "#{copy.id}-#{n}", copy_of: source_of.(n), copy_to: "#{target}-#{n}"}
    end
  end

  defp expand(part, _parts, _sets), do: [part]

  # Walk the tree. Inside the scope, a token with the text of the symbol gets
  # the class, and the class with its number. With `bare`, a token that is the
  # base of a script does not. The function returns the tree and the number
  # of occurrences.
  defp add_class(nodes, inside, base, select, count) when is_list(nodes),
    do: Enum.map_reduce(nodes, count, &add_class(&1, inside, base, select, &2))

  defp add_class({tag, attrs, children}, inside, base, select, count) when is_binary(tag) do
    inside = inside or named?(attrs, select.scope)

    cond do
      tag in @tokens and String.trim(Floki.text(children)) == select.symbol ->
        occurrence({tag, attrs, children}, inside and not (select.bare and base), select, count)

      tag in @scripts and children != [] ->
        [first | rest] = children
        {first, count} = add_class(first, inside, true, select, count)
        {rest, count} = add_class(rest, inside, false, select, count)
        {{tag, attrs, [first | rest]}, count}

      true ->
        {children, count} = add_class(children, inside, false, select, count)
        {{tag, attrs, children}, count}
    end
  end

  defp add_class(node, _inside, _base, _select, count), do: {node, count}

  defp occurrence({tag, attrs, children}, true, %{class: class}, count),
    do: {{tag, add(attrs, "#{class} #{class}-#{count + 1}"), children}, count + 1}

  defp occurrence(token, false, _select, count), do: {token, count}

  defp named?(_attrs, nil), do: false

  defp named?(attrs, name) do
    attrs = Map.new(attrs)

    attrs["data-part"] == name or attrs["data-line"] == name or
      name in String.split(attrs["class"] || "")
  end

  defp add(attrs, class) do
    case List.keytake(attrs, "class", 0) do
      {{"class", own}, attrs} -> [{"class", "#{own} #{class}"} | attrs]
      nil -> [{"class", class} | attrs]
    end
  end
end
