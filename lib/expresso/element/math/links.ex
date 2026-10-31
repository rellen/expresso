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

  A link with the name of a set of `Expresso.Element.Math.Each` takes one
  occurrence of the set: the link number `k` with that name and that source
  line takes the occurrence `k` of the set in that line.
  `docs/each-occurrence.md` gives the design.
  """

  alias Expresso.Element.{On, Part}

  @doc """
  Give each link of a math element a copy of its source

  The function gives the linked sub-term number `n` the class `link-n`, and
  each element of a source in the line `j` the class `from-j-name`. It then
  adds one copy part for each link: from `from-j-name` to `link-n`, with the
  steps of the part of the line of the link. It raises for a name that no
  earlier line has, and for a line with links and with no steps.

  A line with `steps: 2` shows from its second step, and its copies move from
  its first step.

  A line of a rewrite takes a step for each group of its phases. The
  `rewrite` of the line gives the step when each part gets its color, such as
  the occurrences of the rewrite in the old line and the source of `by`, the
  step when the copies of the kept runs, `keep-k-n`, move, and the step when
  the other copies move. The line shows at its last step.
  """
  @spec place(Expresso.Element.Math.t()) :: Expresso.Element.Math.t()
  def place(%Expresso.Element.Math{text: text, line_names: lines} = math)
      when is_binary(text) and lines != [] do
    # The steps of each line before a line with `steps: 2` loses its first step.
    steps = Map.new(math.elements, &{&1.id, &1.steps})
    {%Expresso.Element.Math{elements: parts} = math, phases} = second_steps(math)
    tree = Floki.parse_fragment!(text)

    case links(tree, lines) do
      [] ->
        math

      links ->
        sets = for %Part{id: id, each: symbol} <- parts, symbol != nil, do: id
        links = links |> Enum.map(&source(&1, tree, lines)) |> occurrences(sets, tree, lines)
        tree = mark(tree, lines, links)
        copies = Enum.map(links, &copy(&1, steps, lines, {math.rewrite_lines, phases}))
        parts = colors(parts, math.rewrite_lines, steps, phases)
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

  defp line_of(attrs, lines), do: Enum.find_index(lines, &(&1 == attrs["data-line"]))

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

  # A link to a set takes the next occurrence of the set in its source line,
  # with the class `set-n` of that occurrence.
  defp occurrences(links, sets, tree, lines) do
    nodes = walk(tree, lines, nil, [])

    {links, _taken} =
      Enum.map_reduce(links, %{}, fn %{name: name, source: line} = link, taken ->
        if name in sets do
          k = Map.get(taken, {name, line}, 0) + 1
          {%{link | name: occurrence(nodes, name, line, k)}, Map.put(taken, {name, line}, k)}
        else
          {link, taken}
        end
      end)

    links
  end

  defp occurrence(nodes, name, line, k) do
    classes =
      for {attrs, ^line} <- nodes,
          class <- String.split(attrs["class"] || ""),
          numbered?(class, name),
          do: class

    case Enum.at(classes, k - 1) do
      nil ->
        raise ArgumentError,
              "the math element has #{k} links \\from{#{name}} to the line #{line + 1}, " <>
                "and the set #{inspect(name)} has #{length(classes)} occurrences there"

      class ->
        class
    end
  end

  defp numbered?(class, name) do
    case String.split_at(class, String.length(name) + 1) do
      {prefix, number} when prefix == name <> "-" -> number =~ ~r/^[0-9]+$/
      _split -> false
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

  # A line with `steps: 2` has an `on` entity last in its part, from
  # `Expresso.Element.Math.check/1`, and a line of a rewrite has one for each
  # step after its first. The line shows from the step of the last entity, and
  # the entities go away. The function also returns each step of each line of
  # a rewrite, by name: its first step, then the steps of the entities.
  defp second_steps(%Expresso.Element.Math{} = math) do
    %Expresso.Element.Math{two_step_lines: twos, rewrite_lines: rewrites, elements: parts} = math

    {parts, phases} =
      Enum.map_reduce(parts, %{}, fn part, phases ->
        count = added(part.id, twos, rewrites)
        split(part, count, phases)
      end)

    {%Expresso.Element.Math{math | elements: parts}, phases}
  end

  # The number of `on` entities that the check added to the part of a line,
  # or nil for a line with one step that is not a line of a rewrite.
  defp added(id, twos, rewrites) do
    case rewrites do
      %{^id => %{steps: steps}} -> steps - 1
      _rewrites -> if id in twos, do: 1
    end
  end

  defp split(%Part{id: id, on: on, steps: [first | _] = steps} = part, count, phases)
       when is_integer(count) do
    {on, added} = Enum.split(on || [], length(on || []) - count)
    all = [first | Enum.map(added, fn %On{steps: [step | _]} -> step end)]
    last = List.last(all)
    part = %Part{part | on: on, steps: Enum.filter(steps, &(&1 >= last))}
    {part, Map.put(phases, id, all)}
  end

  defp split(part, _count, phases), do: {part, phases}

  # Each part of a line of a rewrite gets its color at the step of its phase,
  # such as the accent color for the occurrences of the rewrite and the color
  # of success for the source of `by`. A part of the deck with the name of the
  # part keeps its own entities.
  defp colors(parts, rewrites, steps, phases) do
    Enum.reduce(rewrites, parts, fn {line, rewrite}, parts ->
      color(parts, rewrite, Map.get(steps, line), Map.get(phases, line))
    end)
  end

  defp color(parts, %{colors: colors}, [_ | _] = steps, [_ | _] = all) do
    Enum.reduce(colors, parts, fn {id, color, i}, parts ->
      from = Enum.at(all, i - 1)
      add_on(parts, id, %On{steps: Enum.filter(steps, &(&1 >= from)), set: [color: color]})
    end)
  end

  defp color(parts, _rewrite, _steps, _all), do: parts

  defp add_on(parts, id, on) do
    case Enum.find_index(parts, &(&1.id == id and &1.copy_of == nil)) do
      nil ->
        parts ++ [%Part{id: id, on: [on]}]

      index ->
        List.update_at(parts, index, fn %Part{} = part ->
          %Part{part | on: (part.on || []) ++ [on]}
        end)
    end
  end

  # The copy of a link: from the source to the linked sub-term, at the steps
  # of the line of the link. In a line of a rewrite, the copy of a kept run
  # moves at the step of `keep`, and each other copy at the step of `rest`.
  defp copy(%{n: n, line: line, name: name, source: source}, steps, lines, {rewrites, phases}) do
    line_name = Enum.at(lines, line)

    steps =
      case Map.get(steps, line_name) do
        [_ | _] = steps ->
          steps

        _steps ->
          raise ArgumentError,
                "the line #{inspect(line_name)} of a math element has \\from, so it needs " <>
                  "steps. Give the math element reveal true, or give the line an at option"
      end

    steps =
      case {Map.get(rewrites, line_name), Map.get(phases, line_name)} do
        {%{keep: keep, rest: rest}, [_ | _] = all} ->
          i = if String.starts_with?(name, "keep-"), do: keep, else: rest
          from = Enum.at(all, i - 1)
          Enum.filter(steps, &(&1 >= from))

        _phases ->
          steps
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
