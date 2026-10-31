defmodule Expresso.Element.Math.Latex do
  @moduledoc """
  A parser of the LaTeX of a formula into a tree of atoms

  A `rewrite` entity of a derivation makes the LaTeX of a new line from the
  LaTeX of an old line, so it must find the parts, the symbols and the groups
  of the old line. `parse/1` reads LaTeX into a list of atoms, and `write/1`
  writes the list back. `write(parse(tex))` returns `tex`, except for the
  white space between a command and its brace groups. `docs/line-rewrites.md`
  gives the design.

  An atom is one of these tuples:

    * `{:symbol, text}`, a letter, a number, an operator or a parenthesis.
      A number is a run of digits, with a point in it.
    * `{:command, name, groups}`, a command such as `\\lambda` or
      `\\frac`, with the brace groups that follow it. A command with no group,
      such as `\\alpha`, is a symbol for a rewrite.
    * `{:group, atoms}`, a brace group.
    * `{:script, mark}`, the mark `^` or `_` of an index.
    * `{:space, text}`, white space or a command of space, such as `\\,`.

  `\\part{name}{…}` is a command with two groups, and `part/2` finds its body.
  """

  @typedoc "An atom of a formula"
  @type atom_t ::
          {:symbol, String.t()}
          | {:command, String.t(), [{:group, [atom_t()]}]}
          | {:group, [atom_t()]}
          | {:script, String.t()}
          | {:space, String.t()}

  @spaces ["\\,", "\\;", "\\:", "\\!", "\\quad", "\\qquad", "\\space"]
  @names ~w(\\part \\id \\class \\from \\data)

  @doc """
  Read LaTeX into a list of atoms

  The function returns an error for a brace that has no partner.

      iex> Expresso.Element.Math.Latex.parse(~S"\\lambda x.\\,x^{2}")
      {:ok,
       [
         {:command, "\\\\lambda", []},
         {:space, " "},
         {:symbol, "x"},
         {:symbol, "."},
         {:space, "\\\\,"},
         {:symbol, "x"},
         {:script, "^"},
         {:group, [{:symbol, "2"}]}
       ]}
  """
  @spec parse(String.t()) :: {:ok, [atom_t()]} | {:error, String.t()}
  def parse(tex) when is_binary(tex) do
    case atoms(tex, []) do
      {atoms, ""} -> {:ok, atoms}
      {_atoms, "}" <> _rest} -> {:error, "the LaTeX #{inspect(tex)} has a } with no {"}
    end
  catch
    :open -> {:error, "the LaTeX #{inspect(tex)} has a { with no }"}
  end

  @doc """
  Write a list of atoms as LaTeX

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"\\frac{a}{b} + \\part{x}{y}")
      iex> Expresso.Element.Math.Latex.write(atoms)
      ~S"\\frac{a}{b} + \\part{x}{y}"
  """
  @spec write([atom_t()]) :: String.t()
  def write(atoms) when is_list(atoms) do
    atoms
    |> Enum.map(&write_atom/1)
    |> Enum.reduce("", fn text, acc ->
      # A command of letters, such as `\lambda`, ends at the first other
      # character, so a letter after it needs a space.
      if acc =~ ~r/\\[A-Za-z]+$/ and text =~ ~r/^[A-Za-z]/,
        do: acc <> " " <> text,
        else: acc <> text
    end)
  end

  @doc """
  Return the body of the `\\part` or `\\id` with a name, or `nil`

  The function looks at each depth of the tree.

      iex> {:ok, atoms} = Expresso.Element.Math.Latex.parse(~S"a + \\part{b}{c\\,d}")
      iex> Expresso.Element.Math.Latex.part(atoms, "b")
      [{:symbol, "c"}, {:space, "\\\\,"}, {:symbol, "d"}]
  """
  @spec part([atom_t()], String.t()) :: [atom_t()] | nil
  def part(atoms, name) do
    Enum.find_value(atoms, fn
      {:command, command, [{:group, label}, {:group, body}]}
      when command in ["\\part", "\\id"] ->
        if write(label) == name, do: body, else: part(body, name)

      {:command, _name, groups} ->
        part(groups, name)

      {:group, inner} ->
        part(inner, name)

      _atom ->
        nil
    end)
  end

  @doc """
  Return the name of a command that gives a name to its second group, such as
  `\\part`, or `nil` for each other atom
  """
  @spec name_of(atom_t()) :: String.t() | nil
  def name_of({:command, command, [{:group, label}, {:group, _body}]})
      when command in @names,
      do: write(label)

  def name_of(_atom), do: nil

  # The atoms up to the end of the text or up to a closing brace, which the
  # caller reads.
  defp atoms("", acc), do: {Enum.reverse(acc), ""}
  defp atoms("}" <> _rest = text, acc), do: {Enum.reverse(acc), text}

  defp atoms("{" <> rest, acc) do
    {group, rest} = group(rest)
    atoms(rest, [group | acc])
  end

  defp atoms("\\" <> rest, acc) do
    {name, rest} = command_name(rest)

    if name in @spaces do
      atoms(rest, [{:space, name} | acc])
    else
      {groups, rest} = groups(rest, [])
      atoms(rest, [{:command, name, groups} | acc])
    end
  end

  defp atoms(<<mark, rest::binary>>, acc) when mark in [?^, ?_],
    do: atoms(rest, [{:script, <<mark>>} | acc])

  defp atoms("~" <> rest, acc), do: atoms(rest, [{:space, "~"} | acc])

  defp atoms(text, acc) do
    cond do
      match = Regex.run(~r/^\s+/, text) ->
        [space] = match

        atoms(binary_part(text, byte_size(space), byte_size(text) - byte_size(space)), [
          {:space, space} | acc
        ])

      match = Regex.run(~r/^[0-9]+(?:\.[0-9]+)?/, text) ->
        [number] = match
        rest = binary_part(text, byte_size(number), byte_size(text) - byte_size(number))
        atoms(rest, [{:symbol, number} | acc])

      true ->
        {char, rest} = String.next_grapheme(text)
        atoms(rest, [{:symbol, char} | acc])
    end
  end

  defp group(text) do
    case atoms(text, []) do
      {inner, "}" <> rest} -> {{:group, inner}, rest}
      {_inner, ""} -> throw(:open)
    end
  end

  # A command is a backslash and letters, or a backslash and one other
  # character, such as `\,` or `\{`.
  defp command_name(text) do
    case Regex.run(~r/^[A-Za-z]+/, text) do
      [letters] ->
        {"\\" <> letters,
         binary_part(text, byte_size(letters), byte_size(text) - byte_size(letters))}

      nil ->
        case String.next_grapheme(text) do
          {char, rest} -> {"\\" <> char, rest}
          nil -> {"\\", ""}
        end
    end
  end

  # The brace groups right after a command.
  defp groups("{" <> rest, acc) do
    {group, rest} = group(rest)
    groups(rest, [group | acc])
  end

  defp groups(text, acc), do: {Enum.reverse(acc), text}

  defp write_atom({:symbol, text}), do: text
  defp write_atom({:space, text}), do: text
  defp write_atom({:script, mark}), do: mark
  defp write_atom({:group, atoms}), do: "{" <> write(atoms) <> "}"
  defp write_atom({:command, name, groups}), do: name <> write(groups)
end
