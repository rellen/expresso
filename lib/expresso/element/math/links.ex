defmodule Expresso.Element.Math.Links do
  @moduledoc """
  The links between the lines of a derivation

  `\\from{name}{…}` in the LaTeX of a line marks a sub-term that comes from the
  part `name` of an earlier line. Temml writes the attribute `data-from` on
  the MathML of the sub-term. `place/1` gives each link a copy of its source,
  with the copies of `Expresso.Element.Copy`. The copy has the steps of the
  line of the link, and it moves from its source to the linked sub-term.

  The source of a link is each element with the name in the nearest earlier
  line that has the name. An element belongs to the line of its nearest
  ancestor with the name of a line. `docs/line-links.md` gives the design.
  """

  alias Expresso.Element.Part

  @doc """
  Give each link of a math element a copy of its source

  The function gives the linked sub-term number `n` the class `link-n`, and
  each element of a source in the line `j` the class `from-j-name`. It then
  adds one copy part for each link: from `from-j-name` to `link-n`, with the
  steps of the part of the line of the link. It raises for a name that no
  earlier line has, and for a line with links and with no steps.
  """
  @spec place(Expresso.Element.Math.t()) :: Expresso.Element.Math.t()
  def place(%Expresso.Element.Math{text: text, line_names: lines, elements: parts} = math)
      when is_binary(text) and lines != [] do
    tree = Floki.parse_fragment!(text)

    case links(tree, lines) do
      [] ->
        math

      links ->
        links = Enum.map(links, &source(&1, tree, lines))
        tree = mark(tree, lines, links)
        copies = Enum.map(links, &copy(&1, parts, lines))
        %Expresso.Element.Math{math | text: Floki.raw_html(tree), elements: parts ++ copies}
    end
  end

  def place(math), do: math

  # Each linked sub-term in the order of the MathML: its number, its line and
  # the name of its source.
  defp links(tree, lines) do
    tree
    |> walk(lines, nil, [])
    |> Enum.filter(fn {attrs, _line} -> Map.has_key?(attrs, "data-from") end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{attrs, line}, n} -> %{n: n, line: line, name: attrs["data-from"]} end)
  end

  # Each element of the tree with its attributes and the index of its line.
  defp walk(nodes, lines, line, acc) when is_list(nodes),
    do: Enum.reduce(nodes, acc, &walk(&1, lines, line, &2))

  defp walk({tag, attrs, children}, lines, line, acc) when is_binary(tag) do
    attrs = Map.new(attrs)
    line = line_of(attrs, lines) || line
    acc = acc ++ [{attrs, line}]
    walk(children, lines, line, acc)
  end

  defp walk(_node, _lines, _line, acc), do: acc

  defp line_of(attrs, lines), do: Enum.find_index(lines, &(&1 == attrs["data-part"]))

  # The nearest earlier line with an element with the name of the link.
  defp source(%{line: line, name: name} = link, tree, lines) do
    present =
      tree
      |> walk(lines, nil, [])
      |> Enum.filter(fn {attrs, at} -> at != nil and at < (line || 0) and named?(attrs, name) end)
      |> Enum.map(&elem(&1, 1))

    case Enum.max(present, fn -> nil end) do
      nil ->
        raise ArgumentError,
              "the link \\from{#{name}} of a math element names no part of an earlier line"

      source ->
        Map.put(link, :source, source)
    end
  end

  defp named?(attrs, name),
    do: attrs["data-part"] == name or name in String.split(attrs["class"] || "")

  # Give each linked sub-term and each element of a source its class.
  defp mark(tree, lines, links) do
    sources = MapSet.new(links, &{&1.source, &1.name})
    {tree, _n} = mark(tree, lines, nil, sources, 1)
    tree
  end

  defp mark(nodes, lines, line, sources, n) when is_list(nodes) do
    Enum.map_reduce(nodes, n, &mark(&1, lines, line, sources, &2))
  end

  defp mark({tag, attrs, children}, lines, line, sources, n) when is_binary(tag) do
    map = Map.new(attrs)
    line = line_of(map, lines) || line

    {classes, n} =
      case map do
        %{"data-from" => _name} -> {["link-#{n}"], n + 1}
        _map -> {[], n}
      end

    classes =
      classes ++
        for {source, name} <- sources,
            source == line,
            named?(map, name),
            do: "from-#{source}-#{name}"

    {children, n} = mark(children, lines, line, sources, n)
    {{tag, add_classes(attrs, classes), children}, n}
  end

  defp mark(node, _lines, _line, _sources, n), do: {node, n}

  defp add_classes(attrs, []), do: attrs

  defp add_classes(attrs, classes) do
    case List.keytake(attrs, "class", 0) do
      {{"class", own}, attrs} -> [{"class", Enum.join([own | classes], " ")} | attrs]
      nil -> [{"class", Enum.join(classes, " ")} | attrs]
    end
  end

  # The copy of a link: from the source to the linked sub-term, at the steps
  # of the line of the link.
  defp copy(%{n: n, line: line, name: name, source: source}, parts, lines) do
    line_name = Enum.at(lines, line)

    steps =
      case Enum.find(parts, &(&1.id == line_name)) do
        %Part{steps: [_ | _] = steps} ->
          steps

        _part ->
          raise ArgumentError,
                "the line #{inspect(line_name)} of a math element has \\from, so it needs " <>
                  "steps. Give the math element reveal true, or give the line an at option"
      end

    %Part{
      id: "#{name}@link-#{n}",
      copy_of: "from-#{source}-#{name}",
      copy_to: "link-#{n}",
      covers: true,
      steps: steps
    }
  end
end
