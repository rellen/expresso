defmodule Expresso.Element.Math.Each do
  @moduledoc """
  The parts of a formula that name each occurrence of a symbol

  A `part` entity with `each: "x"` names each occurrence of `x`. An occurrence
  is a token element of the MathML, `mi`, `mn` or `mo`, with the text `x`. The
  scope is the part of `within`, or the part with the name of the entity in the
  short form, or else the whole formula. With `bare: true`, the base of a
  symbol with an index, such as the `x` of `x_1`, is not an occurrence.
  `docs/each-occurrence.md` gives the design.
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
  function raises for a scope that the formula does not have, and for a part
  with no occurrence.
  """
  @spec place(Expresso.Element.Math.t()) :: Expresso.Element.Math.t()
  def place(%Expresso.Element.Math{text: text, elements: parts} = math) when is_binary(text) do
    if Enum.any?(parts, & &1.each) do
      tree = Floki.parse_fragment!(text)
      names = Expresso.Element.Math.parts(text)

      {tree, parts} =
        Enum.map_reduce(parts, tree, fn part, tree -> mark(part, tree, names) end)
        |> then(fn {parts, tree} -> {tree, parts} end)

      %Expresso.Element.Math{math | text: Floki.raw_html(tree), elements: parts}
    else
      math
    end
  end

  def place(math), do: math

  defp mark(%Part{each: nil} = part, tree, _names), do: {part, tree}

  defp mark(%Part{id: id, each: symbol, within: within, bare: bare} = part, tree, names) do
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
    {tree, count} = add_class(tree, scope == nil, false, select)

    if count == 0 do
      raise ArgumentError,
            "the part #{inspect(id)} of a math element selects each #{inspect(symbol)}, " <>
              "and the formula has none there"
    end

    {part, tree}
  end

  # Walk the tree. Inside the scope, a token with the text of the symbol gets
  # the class. With `bare`, a token that is the base of a script does not.
  # The function returns the tree and the number of occurrences.
  defp add_class(nodes, inside, base, select) when is_list(nodes) do
    Enum.map_reduce(nodes, 0, fn node, count ->
      {node, n} = add_class(node, inside, base, select)
      {node, count + n}
    end)
  end

  defp add_class({tag, attrs, children}, inside, base, select) when is_binary(tag) do
    inside = inside or named?(attrs, select.scope)

    cond do
      tag in @tokens and String.trim(Floki.text(children)) == select.symbol ->
        occurrence({tag, attrs, children}, inside and not (select.bare and base), select)

      tag in @scripts and children != [] ->
        [first | rest] = children
        {first, n} = add_class(first, inside, true, select)
        {rest, count} = add_class(rest, inside, false, select)
        {{tag, attrs, [first | rest]}, n + count}

      true ->
        {children, count} = add_class(children, inside, false, select)
        {{tag, attrs, children}, count}
    end
  end

  defp add_class(node, _inside, _base, _select), do: {node, 0}

  defp occurrence({tag, attrs, children}, true, select),
    do: {{tag, add(attrs, select.class), children}, 1}

  defp occurrence(token, false, _select), do: {token, 0}

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
