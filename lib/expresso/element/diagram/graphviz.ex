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

  Each edge also gets the names of its two ends, in the attributes
  `data-graph-from` and `data-graph-to`. An end is the `id` of its node, so
  `db [id="store"]` gives the end `store`. `Expresso.Element.Diagram` reads
  the ends for the `edges` option. A port of an end, such as `web:out`, is not
  a part of the name of the end.
  """

  alias Expresso.Element.Diagram.{Font, Tool}

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

  @doc "The tool, for `Expresso.Element.Diagram.Tool`"
  @spec tool() :: Tool.t()
  def tool, do: @tool

  @doc "The layout engines of Graphviz, for the `layout` option"
  @spec layouts() :: [atom()]
  def layouts, do: @layouts

  @doc """
  Run Graphviz on a source file, and return the SVG and the names

  The names are the `id` of each node, edge and cluster, in the order of the
  file. Graphviz measures each text with the font, and a `fontname` of the
  source still applies to its element. The function raises an
  `ArgumentError` when Graphviz is not present and when Graphviz fails.
  """
  @spec draw!(Path.t(), atom(), Font.t()) :: {String.t(), [String.t()]}
  def draw!(src, layout, font \\ Font.builtin()) do
    family = font.family

    command = fn dir ->
      args =
        ["-Tsvg", "-K#{layout}"] ++
          for(kind <- ~w(N E G), do: "-#{kind}fontname=#{family}") ++
          ["-o", Path.join(dir, "graph.svg"), src]

      {args, [{"FONTCONFIG_FILE", fontconfig(dir)}]}
    end

    @tool
    |> Tool.run!(src, command, Font.files(font))
    |> name()
  end

  # Graphviz finds a font through fontconfig. The file of the configuration
  # names the private directory, which holds the files of the font, and it
  # keeps the fonts of the system for a `fontname` of the source. `dir` is the
  # private directory of the run.
  # sobelow_skip ["Traversal"]
  defp fontconfig(dir) do
    path = Path.join(dir, "fonts.conf")

    File.write!(path, """
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <dir>#{dir}</dir>
      <cachedir>#{Path.join(dir, "cache")}</cachedir>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
    </fontconfig>
    """)

    path
  end

  @doc """
  Give a graph of Graphviz the colors of the theme

  Graphviz writes black lines, black text and a white background. The function
  removes the polygon of the background, and it changes `black` to
  `currentColor`, so the lines take the color of the text of the theme. A
  color that the source gives stays. The style sheet gives a text without a
  `fill` the color of the text.

      iex> svg = ~s(<svg><g class="graph"><polygon fill="white" stroke="transparent"></polygon><path stroke="black"></path></g></svg>)
      iex> Expresso.Element.Diagram.Graphviz.theme(svg)
      ~s(<svg><g class="graph"><path stroke="currentColor"></path></g></svg>)
  """
  @spec theme(String.t()) :: String.t()
  def theme(svg), do: svg |> Floki.parse_fragment!() |> colors(nil) |> Floki.raw_html()

  defp colors(nodes, parent) when is_list(nodes) do
    for node <- nodes, not background?(node, parent), do: colors(node, parent)
  end

  defp colors({tag, attrs, children}, _parent) when is_binary(tag) do
    attrs =
      Enum.map(attrs, fn
        {name, "black"} when name in ["fill", "stroke"] -> {name, "currentColor"}
        attr -> attr
      end)

    {tag, attrs, colors(children, {tag, attrs})}
  end

  defp colors(node, _parent), do: node

  # The background is the white polygon in the group of the graph.
  defp background?({"polygon", attrs, _children}, {"g", parent}) do
    List.keyfind(parent, "class", 0) == {"class", "graph"} and
      List.keyfind(attrs, "fill", 0) == {"fill", "white"}
  end

  defp background?(_node, _parent), do: false

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

    {tree |> put_ends(ids(tree)) |> Floki.raw_html(), Enum.reverse(names)}
  end

  # The `id` of each node and cluster, by its title. An edge names its ends by
  # their titles.
  defp ids(tree) do
    for {"g", attrs, children} <- Floki.find(tree, "g.node, g.cluster"),
        title = title(children),
        {"id", id} <- [List.keyfind(attrs, "id", 0)],
        title != nil,
        into: %{},
        do: {title, id}
  end

  defp put_ends(nodes, ids) when is_list(nodes), do: Enum.map(nodes, &put_ends(&1, ids))

  defp put_ends({"g", attrs, children}, ids) do
    children = put_ends(children, ids)

    with {"class", class} <- List.keyfind(attrs, "class", 0),
         true <- "edge" in String.split(class),
         [from, to] <- ends(title(children), ids) do
      {"g", attrs ++ [{"data-graph-from", from}, {"data-graph-to", to}], children}
    else
      _other -> {"g", attrs, children}
    end
  end

  defp put_ends({tag, attrs, children}, ids) when is_binary(tag),
    do: {tag, attrs, put_ends(children, ids)}

  defp put_ends(node, _ids), do: node

  # The two ends of the title of an edge, such as `web->api`, as the ids of
  # their nodes.
  defp ends(nil, _ids), do: nil

  defp ends(title, ids) do
    case String.split(title, ["->", "--"], parts: 2) do
      [from, to] -> [end_id(from, ids), end_id(to, ids)]
      _other -> nil
    end
  end

  # An end can have a port, such as `web:out`. The name without the port is
  # the name of the node.
  defp end_id(name, ids) do
    case Map.fetch(ids, name) do
      {:ok, id} ->
        id

      :error ->
        node = name |> String.split(":") |> Enum.drop(-1) |> Enum.join(":")
        Map.get(ids, node, name)
    end
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
