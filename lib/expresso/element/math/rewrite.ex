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
  has 3 steps: the occurrences and the source of `by` get a color, then the
  kept runs move, then the copies of `by` move. Without `why`, the reason is
  `replace := by` in LaTeX.

  The links of `Expresso.Element.Math.Links` and the copies of
  `Expresso.Element.Copy` then move the symbols. `docs/line-rewrites.md` gives
  the design.
  """

  alias Expresso.Element.{MathLine, MathRewrite}
  alias Expresso.Element.Math.Latex

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
    end)
  end

  defp rewrite(_rewrite, _k, []),
    do: {:error, "a rewrite of a math element needs a line before it"}

  defp rewrite(%MathRewrite{} = rewrite, k, done) do
    with {:ok, index} <- source(rewrite, done),
         %MathLine{} = old <- Enum.at(done, index),
         {:ok, atoms} <- parse(old.tex),
         {:ok, content} <- content(rewrite, done),
         :ok <- present(rewrite, atoms) do
      kind = if Latex.part(atoms, rewrite.replace), do: :part, else: :symbol

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

      {old_atoms, new_atoms, state} = walk(atoms, rewrite.within == nil, state)

      if state.count == 0 do
        {:error,
         "the rewrite of the line #{k} of a math element finds no #{inspect(rewrite.replace)} " <>
           "to replace"}
      else
        line = %MathLine{
          relation: rewrite.relation || "=",
          tex: new_atoms |> trim() |> Latex.write(),
          why: rewrite.why,
          why_tex: if(rewrite.why, do: nil, else: reason(rewrite, atoms, content)),
          name: rewrite.name,
          steps: 3,
          rewrite: %{hit: "hit-#{k}", by: rewrite.by}
        }

        {:ok,
         List.replace_at(done, index, %MathLine{old | tex: Latex.write(old_atoms)}) ++ [line]}
      end
    end
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

  # The atoms that go into the place of each occurrence.
  defp content(%MathRewrite{by: nil, by_tex: nil}, _done),
    do: {:error, "a rewrite of a math element takes the by option or the by_tex option"}

  defp content(%MathRewrite{by: by, by_tex: tex}, _done) when by != nil and tex != nil,
    do:
      {:error,
       "a rewrite of a math element takes the by option or the by_tex option, and not both"}

  defp content(%MathRewrite{by_tex: tex}, _done) when is_binary(tex), do: parse(tex)

  defp content(%MathRewrite{by: by}, done) do
    done
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      with {:ok, atoms} <- Latex.parse(line.tex), do: Latex.part(atoms, by)
    end)
    |> case do
      nil ->
        {:error,
         "a rewrite of a math element takes the part #{inspect(by)}, and no line before it has that part"}

      body ->
        {:ok, [{:command, "\\from", [{:group, [{:symbol, by}]}, {:group, unlink(body)}]}]}
    end
  end

  # The default reason: the symbol or the part of `replace`, `:=`, and the new
  # content, in LaTeX and without links.
  defp reason(%MathRewrite{replace: replace}, atoms, content) do
    old =
      case Latex.part(atoms, replace) do
        nil -> replace
        body -> body |> unlink() |> Latex.write()
      end

    old <> " := " <> (content |> unlink() |> Latex.write())
  end

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
            {old_run, new_run, state} = keep(run, state)
            {old_unit, new_unit, state} = change(kind, unit, inside, state)
            {old ++ old_run ++ old_unit, new ++ new_run ++ new_unit, [], state}
        end
      end)

    {old_run, new_run, state} = keep(run, state)
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

  defp change(:drop, [atom], _inside, state), do: {[atom], [], state}

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

    {[{:command, name, [label, {:group, old}]}], [{:command, name, [label, {:group, new}]}],
     state}
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
  # line. The spaces at its ends stay outside, and a run of spaces only stays
  # as it is.
  defp keep([], state), do: {[], [], state}

  defp keep(run, state) do
    {lead, rest} = Enum.split_while(run, &space?/1)
    {trail, core} = rest |> Enum.reverse() |> Enum.split_while(&space?/1)
    core = Enum.reverse(core)
    trail = Enum.reverse(trail)

    if core == [] do
      {run, run, state}
    else
      n = state.n + 1
      name = [{:symbol, "#{state.prefix}-#{n}"}]

      {lead ++ [{:command, "\\part", [{:group, name}, {:group, core}]}] ++ trail,
       lead ++ [{:command, "\\from", [{:group, name}, {:group, unlink(core)}]}] ++ trail,
       %{state | n: n}}
    end
  end

  # The parts of `drop` leave their spaces, so the spaces at the ends of the
  # new line go away.
  defp trim(atoms) do
    atoms
    |> Enum.drop_while(&space?/1)
    |> Enum.reverse()
    |> Enum.drop_while(&space?/1)
    |> Enum.reverse()
  end

  defp space?({:space, _text}), do: true
  defp space?(_atom), do: false

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
