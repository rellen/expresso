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
         {:ok, atoms} <- mark(atoms, redex, redex_term, k) do
      line = %MathLine{old | tex: Latex.write(atoms)}

      rewrite = %MathRewrite{
        rewrite(reduce, redex, redex_term, k, line, index)
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

  defp part(atoms, i, j, name) do
    inner = Enum.slice(atoms, i..j//1)
    command = {:command, "\\part", [{:group, [{:symbol, name}]}, {:group, inner}]}
    Enum.take(atoms, i) ++ [command] ++ Enum.drop(atoms, j + 1)
  end

  # Change the list of atoms at a path.
  defp update(atoms, [], fun), do: fun.(atoms)

  defp update(atoms, [{:group, i} | rest], fun) do
    List.update_at(atoms, i, fn {:group, inner} -> {:group, update(inner, rest, fun)} end)
  end

  defp update(atoms, [{:body, i} | rest], fun) do
    List.update_at(atoms, i, fn {:command, name, [label, {:group, body}]} ->
      {:command, name, [label, {:group, update(body, rest, fun)}]}
    end)
  end

  # The rewrite of the reduction. An argument of more than one variable gets
  # parentheses in each place, unless it has its own.
  defp rewrite(reduce, %{bound: []}, _term, k, line, index) do
    %MathRewrite{
      relation: reduce.relation || "\\to_\\beta",
      replace: "redex-#{k}",
      to: "\\use{body-#{k}}",
      from: line.name || "line#{index + 1}",
      why: reduce.why,
      name: reduce.name,
      steps: reduce.steps,
      kind: :body
    }
  end

  defp rewrite(reduce, redex, term, k, line, index) do
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
