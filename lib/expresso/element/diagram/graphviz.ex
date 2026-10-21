defmodule Expresso.Element.Diagram.Graphviz do
  @moduledoc """
  Draws a graph in the language of Graphviz, and names its elements

  A `diagram` with a `.dot` or a `.gv` file calls `draw!/2`. The function runs
  `dot -Tsvg` with the layout engine of the `layout` option, through
  `Expresso.Element.Diagram.Tool`, and it returns the SVG with a name for each
  node, edge and cluster.

  Graphviz puts each node, edge and cluster in a `g` element with the class
  `node`, `edge` or `cluster`, and the `g` element holds a `<title>` with the
  name from the source. An element without an `id` in the source gets an `id`
  such as `node1`, `edge2` or `clust1`, and the numbers change when the graph
  changes. Therefore `name/1` replaces each such `id` with the text of the
  title:

  | Element | Title | Name |
  | --- | --- | --- |
  | A node | `web` | `web` |
  | A cluster | `cluster_app` | `cluster_app` |
  | An edge of a directed graph | `web->api` | `web->api` |
  | An edge of a graph with no direction | `a--b` | `a--b` |
  | A second edge between the same ends | `web->api` | `web->api:2` |

  An `id` that the source gives stays, unless it has the form of an `id` of
  Graphviz, such as `node1`.
  """

  alias Expresso.Element.Diagram.Tool

  @tool %{
    name: "Graphviz",
    program: "dot",
    variable: "EXPRESSO_DOT",
    install: "https://graphviz.org/download/"
  }

  # The layout engines of Graphviz. Each one is a value of the `-K` option.
  @layouts [:dot, :neato, :fdp, :sfdp, :circo, :twopi]

  # The classes of the elements that get a name, and the form of an `id` that
  # Graphviz gives.
  @named ~w(node edge cluster)
  @numbered ~r/\A(node|edge|clust)\d+\z/

  @doc "The layout engines of Graphviz, for the `layout` option"
  @spec layouts() :: [atom()]
  def layouts, do: @layouts

  @doc """
  Run Graphviz on a source file, and return the SVG and the names

  The names are the `id` of each node, edge and cluster, in the order of the
  file. The function raises an `ArgumentError` when Graphviz is not present
  and when Graphviz fails.
  """
  @spec draw!(Path.t(), atom()) :: {String.t(), [String.t()]}
  def draw!(src, layout) do
    @tool
    |> Tool.run!(src, &["-Tsvg", "-K#{layout}", "-o", &1, src])
    |> name()
  end

  @doc """
  Give each node, edge and cluster of an SVG of Graphviz the name from its title

  The function returns the SVG and the names, in the order of the file.

      iex> svg = ~s(<svg><g id="node1" class="node"><title>web</title></g></svg>)
      iex> Expresso.Element.Diagram.Graphviz.name(svg)
      {~s(<svg><g id="web" class="node"><title>web</title></g></svg>), ["web"]}
  """
  @spec name(String.t()) :: {String.t(), [String.t()]}
  def name(svg) do
    {tree, {names, _counts}} =
      svg
      |> Floki.parse_fragment!()
      |> walk({[], %{}})

    {Floki.raw_html(tree), Enum.reverse(names)}
  end

  defp walk(nodes, acc) when is_list(nodes), do: Enum.map_reduce(nodes, acc, &walk/2)

  defp walk({"g", attrs, children}, acc) do
    {children, acc} = walk(children, acc)

    if named?(attrs) do
      {attrs, acc} = give_name(attrs, children, acc)
      {{"g", attrs, children}, acc}
    else
      {{"g", attrs, children}, acc}
    end
  end

  defp walk({tag, attrs, children}, acc) when is_binary(tag) do
    {children, acc} = walk(children, acc)
    {{tag, attrs, children}, acc}
  end

  defp walk(node, acc), do: {node, acc}

  defp named?(attrs) do
    case List.keyfind(attrs, "class", 0) do
      {"class", class} -> class |> String.split() |> Enum.any?(&(&1 in @named))
      nil -> false
    end
  end

  # An `id` of the form of Graphviz gets the title, and a second element with
  # the same title gets `:2` after it.
  defp give_name(attrs, children, {names, counts}) do
    case {List.keyfind(attrs, "id", 0), title(children)} do
      {{"id", id}, title} when title != nil ->
        if Regex.match?(@numbered, id),
          do: rename(attrs, title, {names, counts}),
          else: {attrs, {[id | names], counts}}

      {{"id", id}, nil} ->
        {attrs, {[id | names], counts}}

      {nil, _title} ->
        {attrs, {names, counts}}
    end
  end

  defp rename(attrs, title, {names, counts}) do
    count = Map.get(counts, title, 0) + 1
    name = if count == 1, do: title, else: "#{title}:#{count}"
    attrs = List.keyreplace(attrs, "id", 0, {"id", name})
    {attrs, {[name | names], Map.put(counts, title, count)}}
  end

  defp title(children) do
    Enum.find_value(children, fn
      {"title", _attrs, text} -> text |> Floki.text() |> unescape() |> String.trim()
      _other -> nil
    end)
  end

  # Floki keeps the entities of a text. Graphviz writes a numeric entity, such
  # as `&#45;` for the hyphen of `->`, and the five entities of XML.
  @entities %{"lt" => "<", "gt" => ">", "amp" => "&", "quot" => "\"", "apos" => "'"}

  defp unescape(text) do
    Regex.replace(~r/&(#x[0-9a-fA-F]+|#[0-9]+|lt|gt|amp|quot|apos);/, text, fn
      _whole, "#x" <> hex -> <<String.to_integer(hex, 16)::utf8>>
      _whole, "#" <> decimal -> <<String.to_integer(decimal)::utf8>>
      _whole, name -> Map.fetch!(@entities, name)
    end)
  end
end
