defmodule Expresso.Element.Math.Rewrite do
  @moduledoc """
  The lines of a derivation that a substitution makes

  A `rewrite` entity makes the LaTeX of a new line from the LaTeX of an old
  line. `expand/1` reads the old line with `Expresso.Element.Math.Latex` and
  walks its atoms:

    * An occurrence of `replace` becomes the new content: `\\from{name}{…}`
      with the LaTeX of the part `by`, or the LaTeX of `by_tex`.
    * A part of `drop` goes away.
    * A run of other atoms in one group becomes `\\part{keep-k-n}{…}` in the
      old line and `\\from{keep-k-n}{…}` in the new line, so it moves down at
      the step of the new line. `k` is the number of the new line.
    * A group or a command that holds an occurrence or a part of `drop` stays,
      and the walk goes into it. In the new line, it fades in.

  Each occurrence also gets `\\class{hit-k}{…}` in the old line. The new line
  has 3 steps by default, one for each phase: at `:occurrences`, the
  occurrences and the source of `by` get a color; at `:kept`, the kept runs
  move; at `:copies`, the copies of `by` move. The `steps` option puts phases
  together in one step. Without `why`, the reason is `replace := by` in LaTeX.

  The links of `Expresso.Element.Math.Links` and the copies of
  `Expresso.Element.Copy` then move the symbols. `docs/line-rewrites.md` gives
  the design.
  """

  alias Expresso.Element.{MathLine, MathReduce, MathRewrite}
  alias Expresso.Element.Math.{Latex, Rule}

  # The commands that give a name to their second group. The walk does not go
  # into the first group, which holds the name.
  @names ["\\part", "\\id", "\\class", "\\from", "\\data"]

  # The commands that hold text and not symbols of the formula. A rewrite
  # does not look into them.
  @texts ["\\text", "\\textrm", "\\textit", "\\textbf", "\\mathrm", "\\operatorname"]

  @doc """
  Turn each rewrite of a list of lines into a line

  The function returns the lines in order. A rewrite also changes its old
  line, because each kept run of the old line gets a `\\part`. It returns an
  error for a rewrite with no line before it, for a name that the old line or
  an earlier line does not have, and for a rewrite with no occurrence.
  """
  @spec expand([MathLine.t() | MathRewrite.t()]) :: {:ok, [MathLine.t()]} | {:error, String.t()}
  def expand(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn
      {%MathLine{} = line, _k}, {:ok, done} ->
        {:cont, {:ok, done ++ [line]}}

      {%MathRewrite{} = rewrite, k}, {:ok, done} ->
        case rewrite(rewrite, k, done) do
          {:ok, done} -> {:cont, {:ok, done}}
          {:error, message} -> {:halt, {:error, message}}
        end

      {%MathReduce{} = reduce, k}, {:ok, done} ->
        case reduce(reduce, k, done) do
          {:ok, done} -> {:cont, {:ok, done}}
          {:error, message} -> {:halt, {:error, message}}
        end
    end)
  end

  defp rewrite(_rewrite, _k, []),
    do: {:error, "a rewrite of a math element needs a line before it"}

  # A rule gives the old line the parts of its match, and the rewrite then
  # replaces the part of the match with the right side as a template.
  defp rewrite(%MathRewrite{rule: {left, right}} = rewrite, k, done) do
    with :ok <- one_content(rewrite),
         {:ok, index} <- source(rewrite, done),
         %MathLine{} = old <- Enum.at(done, index),
         {:ok, atoms} <- parse(old.tex),
         :ok <- present(%MathRewrite{rewrite | within: rewrite.replace}, atoms),
         {:ok, atoms, template} <-
           Rule.match(atoms, left, right, rewrite.vars || [], rewrite.replace, k) do
      old = %MathLine{old | tex: Latex.write(atoms)}

      rewrite = %MathRewrite{
        rewrite
        | rule: nil,
          replace: "rule-#{k}",
          to: template,
          from: name(old, index + 1)
      }

      rewrite(rewrite, k, List.replace_at(done, index, old))
    end
  end

  defp rewrite(%MathRewrite{} = rewrite, k, done) do
    with :ok <- one_content(rewrite),
         {:ok, index} <- source(rewrite, done),
         %MathLine{} = old <- Enum.at(done, index),
         {:ok, atoms} <- parse(old.tex),
         {:ok, content} <- content(rewrite, done),
         :ok <- present(rewrite, atoms) do
      kind =
        cond do
          rewrite.replace == nil -> :line
          Latex.part(atoms, rewrite.replace) -> :part
          true -> :symbol
        end

      state = %{
        replace: rewrite.replace,
        kind: kind,
        drop: rewrite.drop || [],
        within: rewrite.within,
        content: content,
        prefix: "keep-#{k}",
        hit: "hit-#{k}",
        n: 0,
        count: 0
      }

      {old_atoms, new_atoms, state} = whole(atoms, rewrite.within == nil, state)

      with :ok <- found(state, rewrite, k),
           {:ok, plan} <- plan(rewrite, k) do
        line = %MathLine{
          relation: rewrite.relation || "=",
          tex: new_atoms |> trim_all() |> Latex.write(),
          why: rewrite.why,
          why_tex: why_tex(rewrite, kind, atoms, content),
          name: rewrite.name,
          steps: plan.steps,
          rewrite: plan
        }

        {:ok,
         List.replace_at(done, index, %MathLine{
           old
           | tex: old_atoms |> guard(state.hit) |> Latex.write()
         }) ++ [line]}
      end
    end
  end

  defp found(%{count: 0}, rewrite, k) do
    {:error,
     "the rewrite of the line #{k} of a math element finds no #{inspect(rewrite.replace)} " <>
       "to replace"}
  end

  defp found(_state, _rewrite, _k), do: :ok

  # The phases of each kind of rewrite in order, the color of each part at its
  # phase, and the phases when the copies of the kept runs and the other
  # copies move.
  defp phases(:rewrite, k, by) do
    colors = [{"hit-#{k}", "var(--accent)", :occurrences}]
    colors = if by, do: colors ++ [{by, "var(--success)", :occurrences}], else: colors
    {[:occurrences, :kept, :copies], colors, :kept, :copies}
  end

  defp phases(:reduce, k, _by) do
    colors = [
      {"lam-#{k}", "var(--binder)", :redex},
      {"arg-#{k}", "var(--argument)", :redex},
      {"hit-#{k}", "var(--binder)", :bound}
    ]

    {[:redex, :bound, :body, :argument], colors, :body, :argument}
  end

  defp phases(:body, k, _by),
    do:
      {[:redex, :bound, :body, :argument], [{"arg-#{k}", "var(--argument)", :redex}], :body,
       :body}

  # The steps of the new line: a step for each group of `steps`. The plan
  # gives the number of steps, the step of each color, and the steps when
  # the copies move, each from 1.
  defp plan(%MathRewrite{kind: kind, by: by, steps: groups}, k) do
    {order, colors, keep, rest} = phases(kind, k, by)
    groups = groups || order

    if Enum.flat_map(groups, &List.wrap/1) == order do
      at =
        groups
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {group, i} -> Enum.map(List.wrap(group), &{&1, i}) end)
        |> Map.new()

      {:ok,
       %{
         steps: length(groups),
         colors: Enum.map(colors, fn {id, color, phase} -> {id, color, at[phase]} end),
         keep: at[keep],
         rest: at[rest]
       }}
    else
      {:error,
       "the steps of the line #{k} of a math element must hold " <>
         Enum.map_join(order, ", ", &inspect/1) <> " once each, in this order"}
    end
  end

  # A β-reduction gives its old line the parts of its redex, and a rewrite
  # makes the new line.
  defp reduce(_reduce, _k, []),
    do: {:error, "a reduce of a math element needs a line before it"}

  defp reduce(reduce, k, done) do
    with {:ok, done, rewrite} <- Expresso.Element.Math.Reduce.prepare(reduce, k, done),
         do: rewrite(rewrite, k, done)
  end

  # The index of the old line: the line before the rewrite, or the line with
  # the name of `from`.
  defp source(%MathRewrite{from: nil}, done), do: {:ok, length(done) - 1}

  defp source(%MathRewrite{from: from}, done) do
    case Enum.find_index(Enum.with_index(done, 1), fn {line, n} -> name(line, n) == from end) do
      nil ->
        {:error,
         "a rewrite of a math element reads the line #{inspect(from)}, and no line before it has that name"}

      index ->
        {:ok, index}
    end
  end

  defp name(%MathLine{name: nil}, n), do: "line#{n}"
  defp name(%MathLine{name: name}, _n), do: name

  defp parse(tex) do
    case Latex.parse(tex) do
      {:ok, atoms} ->
        {:ok, atoms}

      {:error, message} ->
        {:error, "a rewrite of a math element cannot read its old line: " <> message}
    end
  end

  # A rewrite takes one of the options of the new content, and `replace`
  # unless it takes `to` or `rule`.
  defp one_content(%MathRewrite{} = rewrite) do
    given =
      for {key, value} <- [
            by: rewrite.by,
            by_tex: rewrite.by_tex,
            to: rewrite.to,
            rule: rewrite.rule
          ],
          value != nil,
          do: key

    cond do
      length(given) != 1 ->
        {:error, "a rewrite of a math element takes one of the options by, by_tex, to and rule"}

      rewrite.replace == nil and given in [[:by], [:by_tex]] ->
        {:error, "a rewrite of a math element with by or by_tex needs the replace option"}

      true ->
        :ok
    end
  end

  # The atoms that go into the place of each occurrence. In a template, each
  # `\\use{name}` becomes a link to the part `name` of the nearest line.
  defp content(%MathRewrite{to: to}, done) when is_binary(to) do
    with {:ok, atoms} <- parse(to), do: uses(atoms, done)
  end

  defp content(%MathRewrite{by_tex: tex}, _done) when is_binary(tex), do: parse(tex)

  defp content(%MathRewrite{by: by, paren: paren}, done) do
    with {:ok, link} <- link(by, done) do
      if paren, do: {:ok, [{:symbol, "("}, link, {:symbol, ")"}]}, else: {:ok, [link]}
    end
  end

  # A link to the part `name` of the nearest line that has it.
  defp link(name, done) do
    done
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      with {:ok, atoms} <- Latex.parse(line.tex), do: Latex.part(atoms, name)
    end)
    |> case do
      nil ->
        {:error,
         "a rewrite of a math element takes the part #{inspect(name)}, and no line before it has that part"}

      body ->
        {:ok, {:command, "\\from", [{:group, [{:symbol, name}]}, {:group, unlink(body)}]}}
    end
  end

  defp uses(atoms, done) do
    Enum.reduce_while(atoms, {:ok, []}, fn atom, {:ok, acc} ->
      case use_atom(atom, done) do
        {:ok, atom} -> {:cont, {:ok, acc ++ [atom]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp use_atom({:command, "\\use", [{:group, label}]}, done), do: link(Latex.write(label), done)

  defp use_atom({:group, atoms}, done) do
    with {:ok, atoms} <- uses(atoms, done), do: {:ok, {:group, atoms}}
  end

  defp use_atom({:command, name, groups}, done) do
    with {:ok, groups} <- uses(groups, done), do: {:ok, {:command, name, groups}}
  end

  defp use_atom(atom, _done), do: {:ok, atom}

  defp why_tex(%MathRewrite{why: why}, _kind, _atoms, _content) when why != nil, do: nil
  defp why_tex(%MathRewrite{why_tex: tex}, _kind, _atoms, _content) when tex != nil, do: tex
  defp why_tex(_rewrite, :line, _atoms, _content), do: nil
  defp why_tex(rewrite, _kind, atoms, content), do: reason(rewrite, atoms, content)

  # The default reason: the symbol or the part of `replace`, `:=`, and the new
  # content, in LaTeX.
  defp reason(%MathRewrite{replace: replace}, atoms, content) do
    old =
      case Latex.part(atoms, replace) do
        nil -> replace
        body -> body |> plain() |> Latex.write()
      end

    old <> " := " <> (content |> plain() |> Latex.write())
  end

  # The reason holds no names, because a later link must not find a part in
  # it. Each naming command gives its body.
  defp plain(atoms) do
    Enum.flat_map(atoms, fn
      {:command, name, [_label, {:group, body}]} when name in @names -> plain(body)
      {:command, name, groups} -> [{:command, name, Enum.map(groups, &plain_group/1)}]
      {:group, inner} -> [{:group, plain(inner)}]
      atom -> [atom]
    end)
  end

  defp plain_group({:group, atoms}), do: {:group, plain(atoms)}

  # Each name of `within` and `drop` must be a part of the old line.
  defp present(%MathRewrite{within: within, drop: drop}, atoms) do
    case Enum.find(List.wrap(within) ++ (drop || []), &(Latex.part(atoms, &1) == nil)) do
      nil ->
        :ok

      name ->
        {:error,
         "a rewrite of a math element names the part #{inspect(name)}, and its old line has no part with that name"}
    end
  end

  # Temml drops a `\\class` that is the whole body of a `\\data`, such as
  # the cell of a line or a part. A list whose only atom is an occurrence thus
  # gets an empty group after it, and the class stays.
  defp guard(atoms, hit) do
    atoms = Enum.map(atoms, &guard_atom(&1, hit))

    case Enum.reject(atoms, &space?/1) do
      [{:command, "\\class", [{:group, [{:symbol, ^hit}]}, _body]}] -> atoms ++ [{:group, []}]
      _atoms -> atoms
    end
  end

  defp guard_atom({:group, atoms}, hit), do: {:group, guard(atoms, hit)}

  defp guard_atom({:command, name, groups}, hit),
    do: {:command, name, Enum.map(groups, fn {:group, atoms} -> {:group, guard(atoms, hit)} end)}

  defp guard_atom(atom, _hit), do: atom

  # A template without `replace` is the whole new line, and the whole old
  # line is its occurrence.
  defp whole(atoms, _inside, %{kind: :line} = state) do
    hit = {:command, "\\class", [{:group, [{:symbol, state.hit}]}, {:group, atoms}]}
    {[hit], state.content, %{state | count: 1}}
  end

  defp whole(atoms, inside, state), do: walk(atoms, inside, state)

  # Walk a list of atoms. The function returns the atoms of the old line, the
  # atoms of the new line and the state. `inside` is true inside the part of
  # `within`, or everywhere without `within`.
  defp walk(atoms, inside, state) do
    {old, new, run, state} =
      atoms
      |> units()
      |> Enum.reduce({[], [], [], state}, fn unit, {old, new, run, state} ->
        case kind(unit, inside, state) do
          :plain ->
            {old, new, run ++ unit, state}

          kind ->
            {old_run, new_run, state} = keep(run, old != [], state)
            {old_unit, new_unit, state} = change(kind, unit, inside, state)
            {old ++ old_run ++ old_unit, new ++ new_run ++ new_unit, [], state}
        end
      end)

    {old_run, new_run, state} = keep(run, old != [], state)
    {old ++ old_run, new ++ new_run, state}
  end

  # A unit is an atom, with the script marks and the scripts after it, so a
  # base and its index stay together.
  defp units(atoms) do
    atoms
    |> Enum.reduce([], fn
      {:script, _mark} = mark, [unit | units] ->
        [unit ++ [mark] | units]

      atom, [[_ | _] = unit | units] = all ->
        if match?({:script, _mark}, List.last(unit)),
          do: [unit ++ [atom] | units],
          else: [[atom] | all]

      atom, units ->
        [[atom] | units]
    end)
    |> Enum.reverse()
  end

  defp kind([atom], inside, state) do
    cond do
      hit?(atom, inside, state) -> :hit
      dropped?(atom, state) -> :drop
      holds?(atom, inside, state) -> :deep
      true -> :plain
    end
  end

  defp kind(unit, inside, state),
    do: if(Enum.any?(unit, &holds_or_is?(&1, inside, state)), do: :deep, else: :plain)

  defp holds_or_is?(atom, inside, state),
    do: hit?(atom, inside, state) or dropped?(atom, state) or holds?(atom, inside, state)

  defp hit?(atom, _inside, %{kind: :part, replace: name}),
    do: Latex.name_of(atom) == name and part?(atom)

  defp hit?({:symbol, text}, inside, %{replace: text}), do: inside
  defp hit?({:command, name, []}, inside, %{replace: name}), do: inside
  defp hit?(_atom, _inside, _state), do: false

  defp dropped?(atom, %{drop: drop}), do: part?(atom) and Latex.name_of(atom) in drop

  defp part?({:command, name, [_, _]}), do: name in ["\\part", "\\id"]
  defp part?(_atom), do: false

  # True for an atom that holds an occurrence or a part of `drop` inside it.
  defp holds?({:group, atoms}, inside, state),
    do: Enum.any?(atoms, &holds_or_is?(&1, inside, state))

  defp holds?({:command, name, _groups}, _inside, _state) when name in @texts, do: false

  defp holds?({:command, _name, _groups} = atom, inside, state) do
    atom
    |> bodies(inside, state)
    |> Enum.any?(fn {atoms, inside} -> Enum.any?(atoms, &holds_or_is?(&1, inside, state)) end)
  end

  defp holds?(_atom, _inside, _state), do: false

  # The groups of a command that the walk reads, each with the value of
  # `inside` for it. The name of a naming command is not a body.
  defp bodies({:command, name, [_label, {:group, body}]} = atom, inside, state)
       when name in @names do
    [{body, inside or (state.within != nil and Latex.name_of(atom) == state.within)}]
  end

  defp bodies({:command, _name, groups}, inside, _state),
    do: for({:group, atoms} <- groups, do: {atoms, inside})

  # The old atoms and the new atoms of a unit that is not plain.
  defp change(:hit, [atom], _inside, state) do
    hit = {:command, "\\class", [{:group, [{:symbol, state.hit}]}, {:group, [atom]}]}
    {[hit], state.content, %{state | count: state.count + 1}}
  end

  # A dropped part leaves a mark in the new line, and `trim_all/1` removes the
  # mark with the spaces after it, so no space stays in the place of the part.
  defp change(:drop, [atom], _inside, state), do: {[atom], [:dropped], state}

  defp change(:deep, [atom], inside, state), do: deep(atom, inside, state)

  # A base with its scripts: the base and each script that holds an
  # occurrence change on their own, and a plain script stays as it is, because
  # LaTeX takes one atom after a script mark. A new base or a new script of
  # more than one atom goes into a group.
  defp change(:deep, unit, inside, state) do
    unit
    |> Enum.with_index()
    |> Enum.reduce({[], [], state}, fn
      {{:script, _mark} = mark, _i}, {old, new, state} ->
        {old ++ [mark], new ++ [mark], state}

      {atom, i}, {old, new, state} ->
        if i > 0 and kind([atom], inside, state) == :plain do
          {old ++ [atom], new ++ [atom], state}
        else
          {old_atoms, new_atoms, state} = walk([atom], inside, state)
          {old ++ one(old_atoms), new ++ one(new_atoms), state}
        end
    end)
  end

  defp one([atom]), do: [atom]
  defp one(atoms), do: [{:group, atoms}]

  defp deep({:group, atoms}, inside, state) do
    {old, new, state} = walk(atoms, inside, state)
    {[{:group, old}], [{:group, new}], state}
  end

  # The link of an earlier rewrite goes away in the new line, and its body
  # stays.
  defp deep({:command, "\\from", [label, {:group, _body}]} = atom, inside, state) do
    [{body, inside}] = bodies(atom, inside, state)
    {old, new, state} = walk(body, inside, state)
    {[{:command, "\\from", [label, {:group, old}]}], new, state}
  end

  defp deep({:command, name, [label, {:group, _body}]} = atom, inside, state)
       when name in @names do
    [{body, inside}] = bodies(atom, inside, state)
    {old, new, state} = walk(body, inside, state)

    # A part that holds only dropped parts goes away with them.
    new =
      if :dropped in new and Enum.all?(new, &(&1 == :dropped or blank?(&1))),
        do: [:dropped],
        else: [{:command, name, [label, {:group, new}]}]

    {[{:command, name, [label, {:group, old}]}], new, state}
  end

  defp deep({:command, name, groups}, inside, state) do
    {old, new, state} =
      Enum.reduce(groups, {[], [], state}, fn {:group, atoms}, {old, new, state} ->
        {o, n, state} = walk(atoms, inside, state)
        {old ++ [{:group, o}], new ++ [{:group, n}], state}
      end)

    {[{:command, name, old}], [{:command, name, new}], state}
  end

  # A run of plain atoms gets a part in the old line and a link in the new
  # line. Temml gives an operator in a part no space, so the run splits at
  # each relation and at each binary operator, and each operator gets its own
  # part inside `\\mathrel` or `\\mathbin`, which give the space back. A `+`
  # or a `-` with no operand before it is a sign, and it stays in its run.
  # `follows` is true when an atom comes before the run in its group. The spaces
  # at the ends of a piece stay outside, and a run of spaces only stays as it
  # is.
  defp keep([], _after, state), do: {[], [], state}

  defp keep(run, follows, state) do
    run
    |> pieces(follows)
    |> Enum.reduce({[], [], state}, fn piece, {old, new, state} ->
      {o, n, state} = piece(piece, state)
      {old ++ o, new ++ n, state}
    end)
  end

  # The run in pieces: `{:run, atoms}` and `{:operator, wrapper, atom}`.
  defp pieces(run, follows) do
    {pieces, current, _operand} =
      Enum.reduce(run, {[], [], follows}, fn atom, {pieces, current, operand} ->
        case operator(atom, operand) do
          nil ->
            {pieces, current ++ [atom], operand(atom, operand)}

          wrapper ->
            {pieces ++ [{:run, current}, {:operator, wrapper, atom}], [], false}
        end
      end)

    Enum.reject(pieces ++ [{:run, current}], &(&1 == {:run, []}))
  end

  @relations ~w(= < > : \\le \\ge \\leq \\geq \\neq \\to \\equiv \\approx \\sim \\mapsto \\Rightarrow \\iff \\in \\subset \\subseteq)
  @binaries ~w(+ - * \\cdot \\times \\pm \\mp \\div \\circ \\cup \\cap \\wedge \\vee)

  defp operator(atom, operand) do
    text = op_text(atom)

    cond do
      text in @relations -> "\\mathrel"
      text in @binaries and operand -> "\\mathbin"
      true -> nil
    end
  end

  defp op_text({:symbol, text}), do: text
  defp op_text({:command, name, []}), do: name
  defp op_text(_atom), do: nil

  # True when the atoms so far end with an operand, so a `+` after them is a
  # binary operator.
  defp operand({:space, _text}, operand), do: operand
  defp operand({:symbol, text}, _operand) when text in ["(", "[", ","], do: false
  defp operand(_atom, _operand), do: true

  defp piece({:operator, wrapper, atom}, state) do
    n = state.n + 1
    name = [{:symbol, "#{state.prefix}-#{n}"}]

    old =
      {:command, wrapper, [{:group, [{:command, "\\part", [{:group, name}, {:group, [atom]}]}]}]}

    new =
      {:command, wrapper, [{:group, [{:command, "\\from", [{:group, name}, {:group, [atom]}]}]}]}

    {[old], [new], %{state | n: n}}
  end

  # An empty group, such as the guard of a part, is blank as a space is. A
  # run of blanks only gets no part, and its empty groups stay in the old line.
  defp piece({:run, run}, state) do
    {lead, rest} = Enum.split_while(run, &blank?/1)
    {trail, core} = rest |> Enum.reverse() |> Enum.split_while(&blank?/1)
    core = Enum.reverse(core)
    trail = Enum.reverse(trail)

    if core == [] do
      {run, Enum.filter(run, &space?/1), state}
    else
      n = state.n + 1
      name = [{:symbol, "#{state.prefix}-#{n}"}]

      {lead ++ [{:command, "\\part", [{:group, name}, {:group, core}]}] ++ trail,
       lead ++ [{:command, "\\from", [{:group, name}, {:group, unlink(core)}]}] ++ trail,
       %{state | n: n}}
    end
  end

  # The parts of `drop` leave their spaces, so the spaces at the ends of the
  # new line and of each group in it go away.
  defp trim_all(atoms) do
    atoms
    |> undrop()
    |> trim()
    |> Enum.map(fn
      {:group, inner} -> {:group, trim_all(inner)}
      {:command, name, groups} -> {:command, name, Enum.map(groups, &trim_group/1)}
      atom -> atom
    end)
  end

  defp trim_group({:group, inner}), do: {:group, trim_all(inner)}

  # A run of dropped parts and spaces becomes one space when it holds a space
  # and the kept atoms on its two sides need one: the left atom does not end
  # with `(`, and the right atom does not start with `)`. Otherwise it goes
  # away.
  defp undrop(atoms) do
    chunks = Enum.chunk_by(atoms, &gap?/1)

    chunks
    |> Enum.with_index()
    |> Enum.flat_map(fn {chunk, i} ->
      cond do
        :dropped not in chunk -> chunk
        i == 0 or i == length(chunks) - 1 -> []
        true -> join(List.last(Enum.at(chunks, i - 1)), hd(Enum.at(chunks, i + 1)), chunk)
      end
    end)
  end

  defp gap?(atom), do: atom == :dropped or space?(atom)

  defp join(left, right, chunk) do
    space = Enum.find(chunk, &space?/1)

    if space != nil and edge(left, &List.last/1) != "(" and edge(right, &hd/1) != ")",
      do: [space],
      else: []
  end

  # The first or the last symbol of an atom, inside its groups and its names.
  defp edge({:symbol, text}, _pick), do: text
  defp edge({:group, [_ | _] = inner}, pick), do: edge(pick.(inner), pick)

  defp edge({:command, _name, [_label, {:group, [_ | _] = body}]} = atom, pick) do
    if Latex.name_of(atom), do: edge(pick.(body), pick), else: nil
  end

  defp edge(_atom, _pick), do: nil

  defp trim(atoms) do
    atoms
    |> Enum.drop_while(&space?/1)
    |> Enum.reverse()
    |> Enum.drop_while(&space?/1)
    |> Enum.reverse()
  end

  defp space?({:space, _text}), do: true
  defp space?(_atom), do: false

  defp blank?(atom), do: space?(atom) or atom == {:group, []}

  # The links of an earlier rewrite go away in a copy, and their bodies stay.
  defp unlink(atoms) do
    Enum.flat_map(atoms, fn
      {:command, "\\from", [_label, {:group, body}]} -> unlink(body)
      {:command, name, groups} -> [{:command, name, Enum.map(groups, &unlink_group/1)}]
      {:group, inner} -> [{:group, unlink(inner)}]
      atom -> [atom]
    end)
  end

  defp unlink_group({:group, atoms}), do: {:group, unlink(atoms)}
end
