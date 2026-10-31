defmodule Expresso.Element.Math.Each do
  @moduledoc """
  The parts of a formula that name each occurrence of a symbol

  A `part` entity with `each: "x"` names each occurrence of `x`. An occurrence
  is a token element of the MathML, `mi`, `mn` or `mo`, with the text `x`. The
  scope is the part of `within`, or the part with the name of the entity in the
  short form, or else the whole formula. `docs/each-occurrence.md` gives the
  design.
  """

  alias Expresso.Element.Part

  @tokens ~w(mi mn mo)

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

  defp mark(%Part{id: id, each: symbol, within: within} = part, tree, names) do
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

    {tree, count} = add_class(tree, scope == nil, scope, symbol, part.id)

    if count == 0 do
      raise ArgumentError,
            "the part #{inspect(id)} of a math element selects each #{inspect(symbol)}, " <>
              "and the formula has none there"
    end

    {part, tree}
  end

  # Walk the tree. Inside the scope, a token with the text of the symbol gets
  # the class. The function returns the tree and the number of occurrences.
  defp add_class(nodes, inside, scope, symbol, class) when is_list(nodes) do
    Enum.map_reduce(nodes, 0, fn node, count ->
      {node, n} = add_class(node, inside, scope, symbol, class)
      {node, count + n}
    end)
  end

  defp add_class({tag, attrs, children}, inside, scope, symbol, class) when is_binary(tag) do
    inside = inside or named?(attrs, scope)

    if inside and tag in @tokens and String.trim(Floki.text(children)) == symbol do
      {{tag, add(attrs, class), children}, 1}
    else
      {children, count} = add_class(children, inside, scope, symbol, class)
      {{tag, attrs, children}, count}
    end
  end

  defp add_class(node, _inside, _scope, _symbol, _class), do: {node, 0}

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
