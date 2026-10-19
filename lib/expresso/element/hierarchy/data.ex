defmodule Expresso.Element.Hierarchy.Data do
  @moduledoc """
  The nodes of a tree from a flat list: the rows of a CSV file, or nodes with
  the `parent` option

  A CSV file gives a tree in one of two forms:

  | Form | Columns |
  | --- | --- |
  | Parent | `id`, `parent`, and the other columns. An empty `parent` makes the root. |
  | Path | `path`, and the other columns. The separator divides a path into its levels. |

  The other columns have the names of the options of a node: `label`,
  `detail`, `image`, `icon`, `value`, `color`, `layout` and `class`. The
  `fields` option of the tree names more columns, and each one becomes a
  field of the box with its heading as its name.

  In the path form, a level without a row of its own becomes a node with no
  options, so `home/photos` makes the node `home` too. The identity of a node
  is its path without a separator at the start or at the end, such as
  `home/photos`. When the paths start with more than one level, such as
  `home` and `var`, a root with the label of the separator holds them.

  `assemble/1` makes the tree from the parent of each node, for both forms of
  a file and for the `parent` option of the DSL.
  """

  alias Expresso.Element.Chart.Csv
  alias Expresso.Element.Hierarchy.Layout
  alias Expresso.Element.Icon
  alias Expresso.Element.Node

  @options ~w(label detail image icon value color layout class)

  @typedoc "A node, the name of its parent or `nil`, and the place that gives it, for an error"
  @type entry :: {Node.t(), String.t() | nil, String.t()}

  @doc """
  Return the roots of a tree from its entries, in the order of the entries

  Each node holds the nodes whose parent it is, after the nodes that it
  already holds. The function returns an error for two nodes with one name,
  for a parent that no node has, and for a loop of parents.

      iex> alias Expresso.Element.Node
      iex> entries = [{%Node{name: "a"}, nil, "a"}, {%Node{name: "b"}, "a", "b"}, {%Node{name: "c"}, "b", "c"}]
      iex> {:ok, [root]} = Expresso.Element.Hierarchy.Data.assemble(entries)
      iex> {root.name, hd(root.elements).name, hd(hd(root.elements).elements).name}
      {"a", "b", "c"}
  """
  @spec assemble([entry()]) :: {:ok, [Node.t()]} | {:error, String.t()}
  def assemble(entries) do
    names = Enum.map(entries, fn {node, _parent, _where} -> node.name end)

    with :ok <- unique(entries),
         :ok <- parents(entries, MapSet.new(names)) do
      children = Enum.group_by(entries, &elem(&1, 1), &elem(&1, 0))
      roots = Map.get(children, nil, [])
      built = Enum.map(roots, &build(&1, children))

      case names -- Enum.flat_map(built, &names/1) do
        [] ->
          {:ok, built}

        loop ->
          {:error, "the parents of the nodes #{quoted(loop)} make a loop, so no root holds them"}
      end
    end
  end

  defp unique(entries) do
    entries
    |> Enum.group_by(fn {node, _parent, _where} -> node.name end, &elem(&1, 2))
    |> Enum.find(fn {_name, places} -> length(places) > 1 end)
    |> case do
      nil ->
        :ok

      {name, [_first, second | _rest]} ->
        {:error,
         "#{second} gives the node \"#{name}\" a second time. A name is the identity of a node"}
    end
  end

  defp parents(entries, names) do
    Enum.find_value(entries, :ok, fn {_node, parent, where} ->
      if parent != nil and not MapSet.member?(names, parent),
        do: {:error, "#{where} names the parent \"#{parent}\", and no node has that name"}
    end)
  end

  defp build(%Node{} = node, children) do
    added = Map.get(children, node.name, [])
    %Node{node | elements: Enum.map((node.elements || []) ++ added, &build(&1, children))}
  end

  defp names(%Node{} = node), do: [node.name | Enum.flat_map(node.elements || [], &names/1)]

  defp quoted(names), do: Enum.map_join(names, ", ", &~s("#{&1}"))

  @doc """
  Return the roots of a tree from the rows of a CSV file

  `rows` are the rows of `Expresso.Element.Chart.Csv.rows/3`, with the
  headings first. `fields` names the columns of the fields, and `separator`
  divides a path.

      iex> rows = [{1, ["path", "value"]}, {2, ["/home/photos", "412"]}, {3, ["/var", "21"]}]
      iex> {:ok, [root]} = Expresso.Element.Hierarchy.Data.rows(rows, "a.csv", fields: [], separator: "/")
      iex> {root.label, Enum.map(root.elements, & &1.name)}
      {"/", ["home", "var"]}
  """
  @spec rows([{pos_integer(), [String.t()]}], String.t(), keyword()) ::
          {:ok, [Node.t()]} | {:error, String.t()}
  def rows([{_line, headings} | data], src, opts) do
    headings = Enum.map(headings, &String.trim/1)
    fields = opts[:fields] || []

    with :ok <- columns(headings, fields, src),
         {:ok, entries} <- entries(headings, data, src, opts) do
      assemble(entries)
    end
  end

  def rows([], src, _opts), do: {:error, "the tree file \"#{src}\" has no rows"}

  defp columns(headings, fields, src) do
    cond do
      not ("path" in headings or ("id" in headings and "parent" in headings)) ->
        {:error,
         "the tree file \"#{src}\" needs the columns id and parent, or the column path, " <>
           "in its first row"}

      missing = Enum.find(fields, &(&1 not in headings)) ->
        {:error,
         "the fields option names the column \"#{missing}\", and the tree file \"#{src}\" " <>
           "has no column with that heading"}

      true ->
        :ok
    end
  end

  defp entries(headings, data, src, opts) do
    form = if "path" in headings, do: :path, else: :parent

    data
    |> Enum.reduce_while({:ok, []}, fn {line, cells}, {:ok, entries} ->
      row = headings |> Enum.zip(Enum.map(cells, &String.trim/1)) |> Map.new()
      where = "line #{line} of the tree file \"#{src}\""

      case node(row, where, opts[:fields] || []) do
        {:ok, node} -> {:cont, {:ok, [{node, row, where} | entries]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, form(form, Enum.reverse(entries), opts[:separator])}
      error -> error
    end
  end

  defp form(:parent, entries, _separator) do
    for {node, row, where} <- entries do
      parent = if row["parent"] in [nil, ""], do: nil, else: row["parent"]
      {%{node | name: row["id"]}, parent, where}
    end
  end

  defp form(:path, entries, separator) do
    rows =
      for {node, row, where} <- entries do
        {split(row["path"], separator), node, where}
      end

    tops =
      rows |> Enum.flat_map(fn {path, _node, _where} -> Enum.take(path, 1) end) |> Enum.uniq()

    root? = length(tops) > 1 or Enum.any?(rows, fn {path, _node, _where} -> path == [] end)
    given = MapSet.new(rows, &elem(&1, 0))

    ordered = with_levels(rows, given, root?)

    for {path, node, where} <- ordered do
      name = if path == [], do: separator, else: Enum.join(path, separator)
      label = node.label || if(path == [], do: separator, else: List.last(path))
      parent = parent(path, root?, separator)
      {%{node | name: name, label: label}, parent, where}
    end
  end

  # Each level without a row of its own comes just before the first row
  # under it, so the nodes keep the order of the file.
  defp with_levels(rows, given, root?) do
    {ordered, _seen} =
      Enum.flat_map_reduce(rows, MapSet.new(), fn {path, _node, where} = row, seen ->
        missing =
          for n <- 0..(length(path) - 1)//1,
              level = Enum.take(path, n),
              not MapSet.member?(given, level) and not MapSet.member?(seen, level),
              level != [] or root?,
              do: {level, %Node{}, where}

        {missing ++ [row], MapSet.union(seen, MapSet.new(missing, &elem(&1, 0)))}
      end)

    ordered
  end

  defp parent([], _root?, _separator), do: nil
  defp parent([_top], true, separator), do: separator
  defp parent([_top], false, _separator), do: nil
  defp parent(path, _root?, separator), do: path |> Enum.drop(-1) |> Enum.join(separator)

  defp split(path, separator),
    do: path |> String.split(separator) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  # The node of a row, with the options of its cells. An empty cell gives no
  # option.
  defp node(row, where, fields) do
    options = for key <- @options, (row[key] || "") != "", do: {key, row[key]}

    Enum.reduce_while(options, {:ok, %Node{fields: fields(row, fields)}}, fn {key, text},
                                                                             {:ok, node} ->
      case option(key, text) do
        {:ok, value} -> {:cont, {:ok, Map.put(node, String.to_existing_atom(key), value)}}
        {:error, problem} -> {:halt, {:error, "#{where}: #{problem}"}}
      end
    end)
  end

  defp fields(_row, []), do: nil

  defp fields(row, fields) do
    case for(field <- fields, (row[field] || "") != "", do: {field, row[field]}) do
      [] -> nil
      fields -> fields
    end
  end

  defp option("value", text) do
    case Csv.number(text) do
      value when is_number(value) and value >= 0 -> {:ok, value}
      _other -> {:error, "the value \"#{text}\" is not a number that is not negative"}
    end
  end

  defp option("color", text), do: atom(text, Icon.colors(), "color")
  defp option("layout", text), do: atom(text, Layout.layouts(), "layout")
  defp option(_key, text), do: {:ok, text}

  defp atom(text, allowed, key) do
    case Enum.find(allowed, &(Atom.to_string(&1) == text)) do
      nil ->
        {:error,
         "the #{key} \"#{text}\" is not one of #{Enum.map_join(allowed, ", ", &Atom.to_string/1)}"}

      atom ->
        {:ok, atom}
    end
  end
end
