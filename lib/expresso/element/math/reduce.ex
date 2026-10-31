defmodule Expresso.Element.Math.Reduce do
  @moduledoc """
  The lines of a derivation that one β-reduction makes

  A `reduce` entity names a redex of the line before it, or of the line that
  `from` names. `prepare/3` reads the old line with
  `Expresso.Element.Math.Lambda`, finds the redex and its parts, and gives the
  old line these parts, where `k` is the number of the new line:

    * `lam-k`, the λ with its variable, its dot and the parenthesis before it,
    * `close-k`, the parenthesis after the body,
    * `body-k` and `arg-k`, the body and the argument,
    * `bound-k`, each bound variable.

  It returns a `rewrite` of `Expresso.Element.Math.Rewrite` that replaces each
  bound variable with a copy of the argument and drops the λ, the
  parenthesis and the argument. A redex with no bound variable becomes its
  body. `docs/beta-reductions.md` gives the design.
  """

  alias Expresso.Element.{MathLine, MathReduce, MathRewrite}
  alias Expresso.Element.Math.{Lambda, Latex}

  @doc """
  Give the old line of a reduction its parts, and return the rewrite

  The function returns the lines with the new old line, and the rewrite. It
  returns an error for a line that is not a λ-term, for a part with no redex,
  for a capture, and for a redex that crosses a part or a link of the line.
  """
  @spec prepare(MathReduce.t(), pos_integer(), [MathLine.t()]) ::
          {:ok, [MathLine.t()], MathRewrite.t()} | {:error, String.t()}
  def prepare(%MathReduce{} = reduce, k, done) do
    with {:ok, index} <- source(reduce, done),
         %MathLine{} = old <- Enum.at(done, index),
         {:ok, atoms} <- Latex.parse(old.tex),
         {:ok, term} <- Lambda.parse(atoms),
         {:ok, redex_term} <- find(term, reduce.redex, Lambda.tokens(atoms)),
         {:ok, redex} <- Lambda.redex(redex_term),
         paren = paren_body?(term, redex_term),
         redex = keep_parens(redex, paren),
         {atoms, done} = split(atoms, done, index, ranges(redex, redex_term)),
         {:ok, atoms} <- mark(atoms, redex, redex_term, k) do
      %MathLine{} = line = Enum.at(done, index)
      line = %{line | tex: Latex.write(atoms)}

      rewrite = %MathRewrite{
        rewrite(reduce, redex, redex_term, k, line, index, paren)
        | why_tex: reason(reduce, redex, atoms, k)
      }

      {:ok, List.replace_at(done, index, line), rewrite}
    else
      {:error, message} -> {:error, "the reduce of the line #{k} of a math element: " <> message}
    end
  end

  defp source(%MathReduce{from: nil}, done), do: {:ok, length(done) - 1}

  defp source(%MathReduce{from: from}, done) do
    done
    |> Enum.with_index()
    |> Enum.find_value({:error, "no line before it has the name #{inspect(from)}"}, fn {line, i} ->
      if (line.name || "line#{i + 1}") == from, do: {:ok, i}
    end)
  end

  # The leftmost outermost redex, or the redex of a part: the outermost redex
  # whose tokens are the tokens of the part.
  defp find(term, :leftmost, _tokens) do
    case Lambda.leftmost(term) do
      nil -> {:error, "the line has no redex"}
      redex -> {:ok, redex}
    end
  end

  defp find(term, name, tokens) when is_binary(name) do
    span =
      tokens
      |> Enum.with_index()
      |> Enum.filter(fn {token, _i} -> name in token.names end)
      |> Enum.map(&elem(&1, 1))

    case span do
      [] ->
        {:error, "the line has no part #{inspect(name)}"}

      span ->
        {first, last} = Enum.min_max(span)

        case outermost(term, &(Lambda.redex?(&1) and &1.first == first and &1.last == last)) do
          nil -> {:error, "the part #{inspect(name)} holds no redex"}
          redex -> {:ok, redex}
        end
    end
  end

  # The outermost term for which the function is true, from the left.
  defp outermost(term, fun) do
    if fun.(term), do: term, else: term |> children() |> Enum.find_value(&outermost(&1, fun))
  end

  defp children(%{kind: :abs, body: body}), do: [body]
  defp children(%{kind: :app, fun: fun, arg: arg}), do: [fun, arg]
  defp children(%{kind: :paren, term: term}), do: [term]
  defp children(_term), do: []

  # A body that is a λ needs parentheses when a term comes after the redex,
  # so the redex is the function of an application: in `(\\lambda f.\\,\\lambda
  # x.\\,f)\\,g\\,y`, the λ of `x` must not take `y`.
  defp paren_body?(term, redex) do
    match?(%{kind: :abs}, unwrap(unwrap(redex.fun).body)) and function?(term, redex)
  end

  defp unwrap(%{kind: :paren, term: term}), do: unwrap(term)
  defp unwrap(term), do: term

  defp function?(%{kind: :app, fun: fun} = term, redex) do
    same?(fun, redex) or Enum.any?(children(term), &function?(&1, redex))
  end

  defp function?(term, redex), do: Enum.any?(children(term), &function?(&1, redex))

  defp same?(a, b), do: {a.first, a.last} == {b.first, b.last}

  # A body in parentheses keeps the parentheses of the λ: the part of the λ
  # starts after its `(`, and its `)` stays.
  defp keep_parens(%{close: close, head: {first, last}} = redex, true) when close != nil,
    do: %{redex | head: {first + 1, last}, close: nil}

  defp keep_parens(redex, _paren), do: redex

  # The ranges of tokens that get a part.
  defp ranges(%{bound: []} = redex, term), do: [redex.arg, redex.body, {term.first, term.last}]

  defp ranges(redex, _term) do
    Enum.map(redex.bound, &{&1, &1}) ++
      [redex.arg, redex.head] ++ if(redex.close, do: [{redex.close, redex.close}], else: [])
  end

  # A kept run of a rewrite follows the atoms of a line, and not its terms,
  # so a link `\from{keep-…}{…}` can hold the end of one term and the start
  # of the next. A link of a body can hold a λ without its parenthesis. Where
  # a range of tokens starts or ends inside a link that occurs once in the
  # line, the function splits the link, and the part of its source in an
  # earlier line, in two. The copies then move as one copy did before.
  defp split(atoms, done, index, ranges) do
    edges = ranges |> Enum.flat_map(fn {first, last} -> [first, last + 1] end) |> Enum.uniq()

    Enum.reduce(edges, {atoms, done}, fn edge, {atoms, done} ->
      tokens = Lambda.tokens(atoms)

      with %{path: path} <- Enum.at(tokens, edge),
           {:ok, prefix, i, j, name} <- inside_link(atoms, path),
           1 <- links(atoms, name),
           {:ok, source} <- source_line(done, index, name) do
        new = fresh(name, done)
        atoms = update(atoms, prefix, &cut(&1, i, j, "\\from", new))
        %MathLine{} = source_line = Enum.at(done, source)
        {:ok, source_atoms} = Latex.parse(source_line.tex)
        n = count_before(atoms_of(Enum.at(atoms_at(atoms, prefix), i)), j)
        source_atoms = cut_part(source_atoms, name, n, new)
        {atoms, List.replace_at(done, source, %{source_line | tex: Latex.write(source_atoms)})}
      else
        _none -> {atoms, done}
      end
    end)
  end

  # The list of the link, the index of the link in it, the index of the token
  # in the body of the link, and the name of the link, for a token at the top
  # of the body of a link, after its first atom.
  defp inside_link(atoms, path) do
    case Enum.split(path, -2) do
      {prefix, [{:body, i}, j]} -> link_at(Enum.at(atoms_at(atoms, prefix), i), prefix, i, j)
      _short -> :none
    end
  end

  defp link_at({:command, "\\from", [{:group, label}, {:group, body}]}, prefix, i, j) do
    if Enum.any?(Enum.take(body, j), &(not space?(&1))),
      do: {:ok, prefix, i, j, Latex.write(label)},
      else: :none
  end

  defp link_at(_atom, _prefix, _i, _j), do: :none

  # The number of links with a name in a list of atoms, at each depth.
  defp links(atoms, name) do
    Enum.reduce(atoms, 0, fn
      {:command, "\\from", [{:group, label}, {:group, body}]}, n ->
        n + if(Latex.write(label) == name, do: 1, else: 0) + links(body, name)

      {:command, _command, groups}, n ->
        n + Enum.sum_by(groups, fn {:group, inner} -> links(inner, name) end)

      {:group, inner}, n ->
        n + links(inner, name)

      _atom, n ->
        n
    end)
  end

  defp space?({:space, _text}), do: true
  defp space?(_atom), do: false

  # The list of atoms at a path.
  defp atoms_at(atoms, []), do: atoms

  defp atoms_at(atoms, [{:group, i} | rest]) do
    {:group, inner} = Enum.at(atoms, i)
    atoms_at(inner, rest)
  end

  defp atoms_at(atoms, [{:body, i} | rest]) do
    {:command, _name, [_label, {:group, body}]} = Enum.at(atoms, i)
    atoms_at(body, rest)
  end

  defp atoms_of({:command, _name, [_label, {:group, body}]}), do: body

  # Split the naming command `i` of a list before the atom `j` of its body.
  # The second half takes the new name.
  defp cut(atoms, i, j, command, new) do
    {:command, ^command, [label, {:group, body}]} = Enum.at(atoms, i)
    {left, right} = Enum.split(body, j)

    pieces = [
      {:command, command, [label, {:group, left}]},
      {:command, command, [{:group, [{:symbol, new}]}, {:group, right}]}
    ]

    Enum.take(atoms, i) ++ pieces ++ Enum.drop(atoms, i + 1)
  end

  # The number of atoms that are not a space before the atom `j` of a body.
  defp count_before(body, j), do: body |> Enum.take(j) |> Enum.count(&(not space?(&1)))

  # Split the part `name` of a line after its atom number `n` that is not a
  # space.
  defp cut_part(atoms, name, n, new) do
    atoms
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{:command, "\\part", [{:group, label}, {:group, body}]} = atom, i} ->
        if Latex.write(label) == name do
          j = after_count(body, n)
          cut(atoms, i, j, "\\part", new) |> Enum.slice(i, 2)
        else
          [put_body(atom, cut_part(body, name, n, new))]
        end

      {{:command, command, groups}, _i} ->
        [
          {:command, command,
           Enum.map(groups, fn {:group, g} -> {:group, cut_part(g, name, n, new)} end)}
        ]

      {{:group, inner}, _i} ->
        [{:group, cut_part(inner, name, n, new)}]

      {atom, _i} ->
        [atom]
    end)
  end

  defp put_body({:command, name, [label, {:group, _body}]}, body),
    do: {:command, name, [label, {:group, body}]}

  # The index of the atom after `n` atoms that are not a space.
  defp after_count(body, n) do
    body
    |> Enum.with_index()
    |> Enum.reject(fn {atom, _i} -> space?(atom) end)
    |> Enum.at(n)
    |> elem(1)
  end

  # The nearest line before the old line with the part `name`.
  defp source_line(done, index, name) do
    done
    |> Enum.take(index)
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(:none, fn {line, i} ->
      with {:ok, atoms} <- Latex.parse(line.tex),
           body when body != nil <- Latex.part(atoms, name),
           do: {:ok, i},
           else: (_none -> nil)
    end)
  end

  # A name for the second half: the name of the link, or of its kept run
  # `keep-k-n`, with `-2`, `-3` and so on, that no line holds.
  defp fresh(name, done) do
    texts = Enum.map(done, & &1.tex)

    base =
      case Regex.run(~r/^keep-\d+-\d+/, name) do
        [base] -> base
        nil -> name
      end

    2
    |> Stream.iterate(&(&1 + 1))
    |> Stream.map(&"#{base}-#{&1}")
    |> Enum.find(fn candidate ->
      not Enum.any?(texts, &String.contains?(&1, "{#{candidate}}"))
    end)
  end

  # Give the old line the parts of the redex. The bound variables first, and
  # then the other parts from the right, so the tokens keep their order.
  defp mark(atoms, %{bound: []} = redex, term, k) do
    with {:ok, atoms} <- wrap(atoms, redex.arg, "arg-#{k}"),
         {:ok, atoms} <- wrap(atoms, redex.body, "body-#{k}"),
         do: wrap(atoms, {term.first, term.last}, "redex-#{k}")
  end

  defp mark(atoms, redex, _term, k) do
    ranges =
      Enum.map(redex.bound, &{{&1, &1}, "bound-#{k}"}) ++
        [{redex.arg, "arg-#{k}"}] ++
        if(redex.close, do: [{{redex.close, redex.close}, "close-#{k}"}], else: []) ++
        [{redex.head, "lam-#{k}"}]

    Enum.reduce_while(ranges, {:ok, atoms}, fn {range, name}, {:ok, atoms} ->
      case wrap(atoms, range, name) do
        {:ok, atoms} -> {:cont, {:ok, atoms}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  # Put a `\part{name}{…}` around the atoms of the tokens `first` to `last`.
  # The atoms must be in one list, and no other token may be in them.
  defp wrap(atoms, {first, last}, name) do
    tokens = Lambda.tokens(atoms)
    a = Enum.at(tokens, first)
    b = Enum.at(tokens, last)
    level = prefix(a.path, b.path)
    depth = length(level)
    i = step(Enum.at(a.path, depth))
    j = step(Enum.at(b.path, depth))
    j = if length(b.path) == depth + 1, do: j + length(b.atoms) - 1, else: j

    inside =
      tokens
      |> Enum.with_index()
      |> Enum.filter(fn {token, _n} ->
        List.starts_with?(token.path, level) and step(Enum.at(token.path, depth)) in i..j//1
      end)
      |> Enum.map(&elem(&1, 1))

    if inside == Enum.to_list(first..last) do
      {:ok, update(atoms, level, &part(&1, i, j, name))}
    else
      {:error, "the redex crosses a part or a link of the line at the part #{name}"}
    end
  end

  defp prefix([step | a], [step | b]) when a != [] and b != [], do: [step | prefix(a, b)]
  defp prefix(_a, _b), do: []

  defp step({_kind, i}), do: i
  defp step(i), do: i

  # Temml puts the attributes of a `\part` that is the whole body of a
  # `\part` on one element, so one name goes away. An empty group after the
  # inner part keeps the two names on two elements.
  defp part(atoms, i, j, name) do
    inner = atoms |> Enum.slice(i..j//1) |> guard()
    command = {:command, "\\part", [{:group, [{:symbol, name}]}, {:group, inner}]}
    Enum.take(atoms, i) ++ [command] ++ Enum.drop(atoms, j + 1)
  end

  defp guard(atoms) do
    case Enum.reject(atoms, &space?/1) do
      [{:command, name, [_label, _body]}] when name in ["\\part", "\\id"] ->
        atoms ++ [{:group, []}]

      _atoms ->
        atoms
    end
  end

  # Change the list of atoms at a path.
  defp update(atoms, [], fun), do: fun.(atoms)

  defp update(atoms, [{:group, i} | rest], fun) do
    List.update_at(atoms, i, fn {:group, inner} -> {:group, update(inner, rest, fun)} end)
  end

  defp update(atoms, [{:body, i} | rest], fun) do
    List.update_at(atoms, i, fn {:command, name, [label, {:group, body}]} ->
      body = update(body, rest, fun)
      body = if rest == [] and name in ["\\part", "\\id"], do: guard(body), else: body
      {:command, name, [label, {:group, body}]}
    end)
  end

  # The rewrite of the reduction. An argument of more than one variable gets
  # parentheses in each place, unless it has its own.
  defp rewrite(reduce, %{bound: []}, _term, k, line, index, paren) do
    %MathRewrite{
      relation: reduce.relation || "\\to_\\beta",
      replace: "redex-#{k}",
      to: if(paren, do: "(\\use{body-#{k}})", else: "\\use{body-#{k}}"),
      from: line.name || "line#{index + 1}",
      why: reduce.why,
      name: reduce.name,
      steps: reduce.steps,
      kind: :body
    }
  end

  defp rewrite(reduce, redex, term, k, line, index, _paren) do
    %MathRewrite{
      relation: reduce.relation || "\\to_\\beta",
      replace: "bound-#{k}",
      by: "arg-#{k}",
      paren: paren?(term.arg),
      drop: ["lam-#{k}", "arg-#{k}"] ++ if(redex.close, do: ["close-#{k}"], else: []),
      from: line.name || "line#{index + 1}",
      why: reduce.why,
      name: reduce.name,
      steps: reduce.steps,
      kind: :reduce
    }
  end

  defp paren?(%{kind: kind}), do: kind not in [:var, :paren]

  # The default reason: the variable, `:=` and the argument, with no names.
  defp reason(%MathReduce{why: why}, _redex, _atoms, _k) when why != nil, do: nil

  defp reason(_reduce, %{var: var}, atoms, k) do
    arg = atoms |> Latex.part("arg-#{k}") |> Lambda.plain() |> Latex.write()
    "#{var} := #{arg}"
  end
end
