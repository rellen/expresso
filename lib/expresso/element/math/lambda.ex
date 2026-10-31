defmodule Expresso.Element.Math.Lambda do
  @moduledoc """
  A parser of the λ-terms in the LaTeX of a line

  A `reduce` entity of a derivation makes the next line by one β-reduction,
  so it must know the terms of the old line. `parse/1` reads the atoms of
  `Expresso.Element.Math.Latex` into a term:

    * `%{kind: :var, name: name}`, a variable: a letter, a number, or a
      command with no group, such as `\\alpha`, with its scripts,
    * `%{kind: :abs, var: name, binder: i, body: term}`, an abstraction
      `\\lambda x.` with its body,
    * `%{kind: :app, fun: term, arg: term}`, an application,
    * `%{kind: :paren, term: term}`, a term in parentheses.

  Each term also has `first` and `last`, the indices of its first token and
  of its last token. `tokens/1` returns the tokens, each with its atom and the
  path of the atom in the tree, so a caller can find the LaTeX of a term.

  The parser reads through a `\\part`, an `\\id`, a `\\class`, a `\\from`, a
  `\\data` and a brace group, and it skips spaces. A body goes as far right as
  it can, and an application groups from the left. `docs/beta-reductions.md`
  gives the design.
  """

  alias Expresso.Element.Math.Latex

  @names ["\\part", "\\id", "\\class", "\\from", "\\data"]

  @typedoc "A λ-term with the indices of its first and last tokens"
  @type term_t :: %{
          required(:kind) => atom(),
          required(:first) => non_neg_integer(),
          optional(atom()) => term()
        }

  @typedoc """
  A token: its text, its atoms, the names of the naming commands around it,
  and the path of its first atom. Each step of
  the path is the index of an atom in its list, `{:group, i}` into the brace
  group `i`, or `{:body, i}` into the body of the naming command `i`.
  """
  @type token :: %{
          text: String.t(),
          atoms: [Latex.atom_t()],
          path: [non_neg_integer() | {:group | :body, non_neg_integer()}],
          names: [String.t()]
        }

  @doc """
  Read a λ-term from the atoms of a line

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"(\\lambda f.\\,f\\,x)\\,g")
      iex> {:ok, term} = Expresso.Element.Math.Lambda.parse(atoms)
      iex> Expresso.Element.Math.Lambda.show(term)
      "((λf. (f x)) g)"
  """
  @spec parse([Latex.atom_t()]) :: {:ok, term_t()} | {:error, String.t()}
  def parse(atoms) do
    tokens = tokens(atoms)

    case term(tokens, 0) do
      {:ok, term, n} when n == length(tokens) ->
        {:ok, term}

      {:ok, _term, n} ->
        {:error,
         "the λ-term #{inspect(Latex.write(atoms))} has #{inspect(Enum.at(tokens, n).text)} where it ends"}

      {:error, n} ->
        at = if n < length(tokens), do: inspect(Enum.at(tokens, n).text), else: "its end"
        {:error, "the LaTeX #{inspect(Latex.write(atoms))} is not a λ-term at #{at}"}
    end
  end

  @doc """
  Return the tokens of a line, in order

  A variable with its scripts is one token. A space is not a token.
  """
  @spec tokens([Latex.atom_t()]) :: [token()]
  def tokens(atoms), do: atoms |> collect([], []) |> Enum.reverse()

  @doc """
  Write a term in a short form with each application in parentheses, for a
  test or an error
  """
  @spec show(term_t()) :: String.t()
  def show(%{kind: :var, name: name}), do: name
  def show(%{kind: :abs, var: var, body: body}), do: "(λ#{var}. #{show(body)})"
  def show(%{kind: :app, fun: fun, arg: arg}), do: "(#{show(fun)} #{show(arg)})"
  def show(%{kind: :paren, term: term}), do: show(term)

  @doc """
  Return the atoms without the naming commands, each with its body, so the
  LaTeX holds no names
  """
  @spec plain([Latex.atom_t()]) :: [Latex.atom_t()]
  def plain(atoms) do
    Enum.flat_map(atoms, fn
      {:command, name, [_label, {:group, body}]} when name in @names ->
        plain(body)

      {:command, name, groups} ->
        [{:command, name, Enum.map(groups, fn {:group, g} -> {:group, plain(g)} end)}]

      {:group, inner} ->
        [{:group, plain(inner)}]

      atom ->
        [atom]
    end)
  end

  @doc """
  Return the free variables of a term

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"\\lambda x.\\,f\\,x\\,y")
      iex> {:ok, term} = Expresso.Element.Math.Lambda.parse(atoms)
      iex> Expresso.Element.Math.Lambda.free(term) |> Enum.sort()
      ["f", "y"]
  """
  @spec free(term_t()) :: MapSet.t(String.t())
  def free(%{kind: :var, name: name}), do: MapSet.new([name])
  def free(%{kind: :abs, var: var, body: body}), do: body |> free() |> MapSet.delete(var)
  def free(%{kind: :app, fun: fun, arg: arg}), do: MapSet.union(free(fun), free(arg))
  def free(%{kind: :paren, term: term}), do: free(term)

  @doc """
  Return true for a redex: an application of an abstraction, in parentheses
  or not
  """
  @spec redex?(term_t()) :: boolean()
  def redex?(%{kind: :app, fun: fun}), do: match?(%{kind: :abs}, unwrap(fun))
  def redex?(_term), do: false

  @doc """
  Return the parts of a redex, by the indices of their tokens

  The map has these keys:

    * `head`, the first and the last token of the λ, its variable and its dot,
      with the parenthesis before it,
    * `close`, the token of the parenthesis after the body, or `nil`,
    * `body` and `arg`, the first and the last token of the body and of the
      argument,
    * `var`, the variable, and `bound`, the token of each bound variable: each
      free occurrence of the variable in the body.

  An inner λ with the same variable hides the occurrences in its own body.
  The function returns an error for a capture: a λ of the body around a bound
  variable binds a free variable of the argument.

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"(\\lambda f.\\,f\\,(\\lambda f.\\,f))\\,g")
      iex> {:ok, term} = Expresso.Element.Math.Lambda.parse(atoms)
      iex> {:ok, redex} = Expresso.Element.Math.Lambda.redex(term)
      iex> {redex.var, redex.bound, redex.head, redex.close, redex.arg}
      {"f", [4], {0, 3}, 11, {12, 12}}
  """
  @spec redex(term_t()) :: {:ok, map()} | {:error, String.t()}
  def redex(%{kind: :app, fun: fun, arg: arg} = term) do
    case {fun, unwrap(fun)} do
      {_fun, %{kind: :abs, var: var, body: body} = abs} ->
        {open, close} = parens(fun)
        bound = occurrences(body, var, [])

        with :ok <- no_capture(bound, free(arg), var) do
          {:ok,
           %{
             var: var,
             bound: Enum.map(bound, &elem(&1, 0)),
             head: {open || abs.first, body.first - 1},
             close: close,
             body: {body.first, body.last},
             arg: {arg.first, arg.last},
             term: {term.first, term.last}
           }}
        end

      _other ->
        {:error, "the term #{show(term)} is not a redex"}
    end
  end

  def redex(term), do: {:error, "the term #{show(term)} is not a redex"}

  @doc """
  Return the leftmost outermost redex of a term, the redex of normal order, or
  `nil`
  """
  @spec leftmost(term_t()) :: term_t() | nil
  def leftmost(term) do
    if redex?(term), do: term, else: term |> children() |> Enum.find_value(&leftmost/1)
  end

  defp children(%{kind: :abs, body: body}), do: [body]
  defp children(%{kind: :app, fun: fun, arg: arg}), do: [fun, arg]
  defp children(%{kind: :paren, term: term}), do: [term]
  defp children(_term), do: []

  # The term inside each pair of parentheses.
  defp unwrap(%{kind: :paren, term: term}), do: unwrap(term)
  defp unwrap(term), do: term

  # The first parenthesis before a term and the last one after it, from the
  # outer pair.
  defp parens(%{kind: :paren, first: open, last: close}), do: {open, close}
  defp parens(_term), do: {nil, nil}

  # Each free occurrence of a variable in a term, with the variables of the
  # λs around it.
  defp occurrences(%{kind: :var, name: name, first: i}, var, around) when name == var,
    do: [{i, around}]

  defp occurrences(%{kind: :var}, _var, _around), do: []
  defp occurrences(%{kind: :abs, var: var}, var, _around), do: []

  defp occurrences(%{kind: :abs, var: inner, body: body}, var, around),
    do: occurrences(body, var, [inner | around])

  defp occurrences(%{kind: :app, fun: fun, arg: arg}, var, around),
    do: occurrences(fun, var, around) ++ occurrences(arg, var, around)

  defp occurrences(%{kind: :paren, term: term}, var, around), do: occurrences(term, var, around)

  defp no_capture(bound, free, var) do
    captured =
      bound
      |> Enum.flat_map(fn {_i, around} -> around end)
      |> Enum.find(&MapSet.member?(free, &1))

    case captured do
      nil ->
        :ok

      name ->
        {:error,
         "the β-reduction of #{var} captures the free variable #{name} of the argument, " <>
           "because a λ#{name} of the body binds it. Give that λ a different variable"}
    end
  end

  # The tokens of a list of atoms. A naming command and a brace group are
  # transparent, and a symbol with its scripts is one token.
  defp collect(atoms, path, names) do
    atoms
    |> Enum.with_index()
    |> units()
    |> Enum.reduce([], fn unit, acc -> token(unit, path, names) ++ acc end)
  end

  defp units(indexed) do
    indexed
    |> Enum.reduce([], fn
      {{:script, _mark}, _i} = mark, [unit | rest] ->
        [unit ++ [mark] | rest]

      atom, [[_ | _] = unit | rest] = all ->
        if match?({{:script, _mark}, _i}, List.last(unit)),
          do: [unit ++ [atom] | rest],
          else: [[atom] | all]

      atom, all ->
        [[atom] | all]
    end)
    |> Enum.reverse()
  end

  defp token([{{:space, _text}, _i}], _path, _names), do: []

  defp token([{{:group, inner}, i}], path, names),
    do: collect(inner, path ++ [{:group, i}], names)

  defp token([{{:command, name, [label, {:group, body}]}, i}], path, names)
       when name in @names,
       do: collect(body, path ++ [{:body, i}], names ++ [Latex.write(elem(label, 1))])

  defp token([{atom, i} | _rest] = unit, path, names) do
    atoms = Enum.map(unit, &elem(&1, 0))
    text = if length(atoms) == 1, do: text(atom), else: Latex.write(atoms)
    [%{text: text, atoms: atoms, path: path ++ [i], names: names}]
  end

  defp text({:symbol, text}), do: text
  defp text({:command, name, []}), do: name
  defp text(atom), do: Latex.write([atom])

  # A term: one or more atoms in an application, from the left.
  defp term(tokens, i) do
    with {:ok, first, i} <- atom(tokens, i), do: apply_more(tokens, first, i)
  end

  defp apply_more(tokens, fun, i) do
    if starts_atom?(tokens, i) do
      with {:ok, arg, i} <- atom(tokens, i) do
        apply_more(tokens, %{kind: :app, fun: fun, arg: arg, first: fun.first, last: arg.last}, i)
      end
    else
      {:ok, fun, i}
    end
  end

  defp starts_atom?(tokens, i) do
    case Enum.at(tokens, i) do
      nil -> false
      %{text: text} -> text not in [")", "."]
    end
  end

  # An atom of an application: a variable, a term in parentheses or an
  # abstraction, whose body goes to the end of the term around it.
  defp atom(tokens, i) do
    case Enum.at(tokens, i) do
      %{text: "("} ->
        with {:ok, inner, j} <- term(tokens, i + 1),
             %{text: ")"} <- Enum.at(tokens, j) do
          {:ok, %{kind: :paren, term: inner, first: i, last: j}, j + 1}
        else
          {:error, n} -> {:error, n}
          _other -> {:error, i}
        end

      %{text: "\\lambda"} ->
        with %{text: var} = token when token != nil <- Enum.at(tokens, i + 1),
             true <- variable?(token),
             %{text: "."} <- Enum.at(tokens, i + 2),
             {:ok, body, j} <- term(tokens, i + 3) do
          {:ok, %{kind: :abs, var: var, binder: i + 1, body: body, first: i, last: body.last}, j}
        else
          {:error, n} -> {:error, n}
          _other -> {:error, i}
        end

      %{} = token ->
        if variable?(token),
          do: {:ok, %{kind: :var, name: token.text, first: i, last: i}, i + 1},
          else: {:error, i}

      nil ->
        {:error, i}
    end
  end

  # A variable is a letter, a number, or a command with no group, with its
  # scripts.
  defp variable?(%{atoms: [first | _rest]}) do
    case first do
      {:symbol, text} -> text =~ ~r/^[\p{L}\p{N}]/u
      {:command, name, []} -> name != "\\lambda"
      _atom -> false
    end
  end
end
