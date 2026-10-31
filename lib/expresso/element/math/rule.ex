defmodule Expresso.Element.Math.Rule do
  @moduledoc """
  A rule with variables for a rewrite of a derivation

  The `rule` option of a rewrite gives a left side and a right side in LaTeX,
  such as `{~S"a\\,(b + c)", ~S"a\\,b + a\\,c"}`, and `vars` names the
  variables. `match/6` finds the first match of the left side in the old line,
  from the left and from the outside in, and binds each variable to one
  operand:

    * a symbol or a command, with its scripts unless the pattern puts a
      script after the variable,
    * a brace group,
    * a group in parentheses, from `(` to its `)`.

  The match skips spaces, such as `\\,`. A variable that occurs two times
  must bind equal LaTeX. A brace group or a command of the pattern matches
  its groups in full.

  The function gives the first binding of each variable the part `var-k-x`
  and the match the part `rule-k` in the old line, and it returns the right
  side as a template of `Expresso.Element.Math.Rewrite`, with
  `\\use{var-k-x}` in place of each variable. The match does not cross a
  `\\part` or a `\\from` of the old line, but it looks inside them.
  `docs/line-rewrites.md` gives the design.
  """

  alias Expresso.Element.Math.Latex

  @names ["\\part", "\\id", "\\class", "\\from", "\\data"]

  @doc """
  Match a rule in the atoms of an old line

  `scope` is the name of a part that holds the match, or `nil` for the whole
  line. The function returns the atoms of the old line with the parts of the
  match, and the template of the new content.

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"y = 2\\,(x + 1)")
      iex> {:ok, old, template} =
      ...>   Expresso.Element.Math.Rule.match(atoms, ~S"a\\,(b + c)", ~S"a\\,b + a\\,c", ~w(a b c), nil, 2)
      iex> Expresso.Element.Math.Latex.write(old)
      ~S"y = \\part{rule-2}{\\part{var-2-a}{2}\\,(\\part{var-2-b}{x} + \\part{var-2-c}{1})}"
      iex> template
      ~S"\\use{var-2-a}\\,\\use{var-2-b} + \\use{var-2-a}\\,\\use{var-2-c}"
  """
  @spec match(
          [Latex.atom_t()],
          String.t(),
          String.t(),
          [String.t()],
          String.t() | nil,
          pos_integer()
        ) ::
          {:ok, [Latex.atom_t()], String.t()} | {:error, String.t()}
  def match(atoms, left, right, vars, scope, k) do
    with {:ok, pattern} <- parse(left),
         {:ok, template} <- parse(right),
         :ok <- known(pattern, template, vars) do
      ctx = %{vars: vars, k: k}

      case search(strip(pattern), atoms, scope == nil, scope, ctx) do
        {:ok, atoms} ->
          {:ok, atoms, template |> uses(ctx) |> Latex.write()}

        :error ->
          {:error,
           "the rule of the rewrite of the line #{k} of a math element matches nothing in its " <>
             "old line"}
      end
    end
  end

  defp parse(tex) do
    case Latex.parse(tex) do
      {:ok, atoms} -> {:ok, atoms}
      {:error, message} -> {:error, "a rule of a rewrite cannot read its LaTeX: " <> message}
    end
  end

  # Each variable of the right side must be in the left side.
  defp known(pattern, template, vars) do
    used = symbols(pattern)

    case Enum.find(vars, &(&1 in symbols(template) and &1 not in used)) do
      nil ->
        :ok

      var ->
        {:error,
         "the variable #{inspect(var)} of a rule is in its right side and not in its left side"}
    end
  end

  defp symbols(atoms) do
    Enum.flat_map(atoms, fn
      {:symbol, text} -> [text]
      {:group, inner} -> symbols(inner)
      {:command, _name, groups} -> Enum.flat_map(groups, fn {:group, inner} -> symbols(inner) end)
      _atom -> []
    end)
  end

  # The atoms without spaces, at each depth.
  defp strip(atoms) do
    atoms
    |> Enum.reject(&match?({:space, _text}, &1))
    |> Enum.map(fn
      {:group, inner} ->
        {:group, strip(inner)}

      {:command, name, groups} ->
        {:command, name, Enum.map(groups, fn {:group, g} -> {:group, strip(g)} end)}

      atom ->
        atom
    end)
  end

  # The first match from the left, at this depth and then inside each atom.
  defp search(pattern, atoms, inside, scope, ctx) do
    atoms
    |> Enum.with_index()
    |> Enum.find_value(:error, fn {atom, i} ->
      case here(pattern, atoms, i, inside, ctx) do
        {:ok, atoms} -> {:ok, atoms}
        :error -> within(atom, atoms, i, inside, scope, pattern, ctx)
      end
    end)
  end

  # A match that starts at the atom `i`.
  defp here(pattern, atoms, i, inside, ctx) do
    with true <- inside and not space?(Enum.at(atoms, i)),
         {:ok, n, matched, _binds} <- seq(pattern, Enum.drop(atoms, i), %{}, ctx, false) do
      part = {:command, "\\part", [name("rule-#{ctx.k}"), {:group, matched}]}
      {:ok, Enum.take(atoms, i) ++ [part] ++ Enum.drop(atoms, i + n)}
    else
      _no -> :error
    end
  end

  # A match inside the atom `i`, or `nil`.
  defp within(atom, atoms, i, inside, scope, pattern, ctx) do
    case inner(atom, inside, scope, pattern, ctx) do
      {:ok, atom} -> {:ok, List.replace_at(atoms, i, atom)}
      :error -> nil
    end
  end

  defp inner({:group, atoms}, inside, scope, pattern, ctx) do
    with {:ok, atoms} <- search(pattern, atoms, inside, scope, ctx), do: {:ok, {:group, atoms}}
  end

  defp inner({:command, name, [label, {:group, body}]} = atom, inside, scope, pattern, ctx)
       when name in @names do
    inside = inside or Latex.name_of(atom) == scope

    with {:ok, body} <- search(pattern, body, inside, scope, ctx),
         do: {:ok, {:command, name, [label, {:group, body}]}}
  end

  defp inner({:command, name, groups}, inside, scope, pattern, ctx) do
    groups
    |> Enum.with_index()
    |> Enum.find_value(:error, fn {{:group, atoms}, i} ->
      case search(pattern, atoms, inside, scope, ctx) do
        {:ok, atoms} -> {:ok, {:command, name, List.replace_at(groups, i, {:group, atoms})}}
        :error -> nil
      end
    end)
  end

  defp inner(_atom, _inside, _scope, _pattern, _ctx), do: :error

  # Match a pattern at the start of a list of atoms. The function returns the
  # number of atoms of the match, the matched atoms with the parts of the
  # variables, and the bindings. With `anchored`, the pattern must take the
  # whole list.
  defp seq([], rest, binds, _ctx, anchored) do
    if anchored and Enum.any?(rest, &(not space?(&1))), do: :error, else: {:ok, 0, [], binds}
  end

  defp seq(_pattern, [], _binds, _ctx, _anchored), do: :error

  defp seq(pattern, [{:space, _text} = space | rest], binds, ctx, anchored) do
    with {:ok, n, matched, binds} <- seq(pattern, rest, binds, ctx, anchored),
         do: {:ok, n + 1, [space | matched], binds}
  end

  defp seq([p | ps], [t | rest] = target, binds, ctx, anchored) do
    if var?(p, ctx) do
      {:symbol, var} = p
      bind(var, ps, target, binds, ctx, anchored)
    else
      with {:ok, t, binds} <- same(p, t, binds, ctx),
           {:ok, n, matched, binds} <- seq(ps, rest, binds, ctx, anchored),
           do: {:ok, n + 1, [t | matched], binds}
    end
  end

  defp var?({:symbol, text}, ctx), do: text in ctx.vars
  defp var?(_atom, _ctx), do: false

  # Bind a variable to the operand at the start of the target.
  defp bind(var, ps, target, binds, ctx, anchored) do
    base_only = match?([{:script, _mark} | _rest], ps)

    with {:ok, span, rest} <- operand(target, base_only),
         {:ok, bound, binds} <- check(var, span, binds, ctx),
         {:ok, n, matched, binds} <- seq(ps, rest, binds, ctx, anchored) do
      {:ok, length(span) + n, bound ++ matched, binds}
    end
  end

  # The first binding of a variable gets its part. A second binding must have
  # the same LaTeX.
  defp check(var, span, binds, ctx) do
    key = span |> strip() |> Latex.write()

    case Map.fetch(binds, var) do
      :error ->
        part = {:command, "\\part", [name("var-#{ctx.k}-#{var}"), {:group, span}]}
        {:ok, [part], Map.put(binds, var, key)}

      {:ok, ^key} ->
        {:ok, span, binds}

      {:ok, _other} ->
        :error
    end
  end

  defp operand([{:symbol, "("} | _rest] = target, base_only) do
    case close(target, 0, 0) do
      nil -> :error
      i -> scripts(Enum.take(target, i + 1), Enum.drop(target, i + 1), base_only)
    end
  end

  defp operand([{:script, _mark} | _rest], _base_only), do: :error
  defp operand([atom | rest], base_only), do: scripts([atom], rest, base_only)

  # The index of the `)` that closes the `(` at the start.
  defp close([], _depth, _i), do: nil
  defp close([{:symbol, "("} | rest], depth, i), do: close(rest, depth + 1, i + 1)
  defp close([{:symbol, ")"} | _rest], 1, i), do: i
  defp close([{:symbol, ")"} | rest], depth, i), do: close(rest, depth - 1, i + 1)
  defp close([_atom | rest], depth, i), do: close(rest, depth, i + 1)

  defp scripts(span, rest, true), do: {:ok, span, rest}

  defp scripts(span, [{:script, _mark} = mark, arg | rest], false),
    do: scripts(span ++ [mark, arg], rest, false)

  defp scripts(span, rest, false), do: {:ok, span, rest}

  # An atom of the pattern that is not a variable.
  defp same({:group, ps}, {:group, ts}, binds, ctx) do
    with {:ok, _n, matched, binds} <- seq(ps, ts, binds, ctx, true),
         do: {:ok, {:group, matched}, binds}
  end

  defp same({:command, name, pgs}, {:command, name, tgs}, binds, ctx)
       when length(pgs) == length(tgs) do
    pgs
    |> Enum.zip(tgs)
    |> Enum.reduce_while({:ok, [], binds}, fn {{:group, ps}, {:group, ts}},
                                              {:ok, groups, binds} ->
      case seq(ps, ts, binds, ctx, true) do
        {:ok, _n, matched, binds} -> {:cont, {:ok, groups ++ [{:group, matched}], binds}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, groups, binds} -> {:ok, {:command, name, groups}, binds}
      :error -> :error
    end
  end

  defp same(atom, atom, binds, _ctx), do: {:ok, atom, binds}
  defp same(_p, _t, _binds, _ctx), do: :error

  # The right side with `\use{var-k-x}` in place of each variable.
  defp uses(atoms, ctx) do
    Enum.map(atoms, fn
      {:symbol, var} = atom ->
        if var in ctx.vars, do: {:command, "\\use", [name("var-#{ctx.k}-#{var}")]}, else: atom

      {:group, inner} ->
        {:group, uses(inner, ctx)}

      {:command, name, groups} ->
        {:command, name, Enum.map(groups, fn {:group, g} -> {:group, uses(g, ctx)} end)}

      atom ->
        atom
    end)
  end

  defp name(text), do: {:group, [{:symbol, text}]}

  defp space?({:space, _text}), do: true
  defp space?(_atom), do: false
end
