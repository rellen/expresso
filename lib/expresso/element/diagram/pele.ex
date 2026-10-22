defmodule Expresso.Element.Diagram.Pele do
  @moduledoc """
  Draws a diagram in the language of Mermaid with Pele, and names its elements

  A `diagram` with a `.mmd` file, or with the `source` option and
  `lang: :mermaid`, calls `draw!/3`. [Pele](https://pele.run) is a library in
  JavaScript, so the function runs Node with the script `priv/pele/render.mjs`,
  through `Expresso.Element.Diagram.Tool`. The project holds a copy of
  `pele.js` and its license in `priv/pele/`, so a render needs Node and no
  package of npm. `version/0` gives the version of the copy.

  The script writes the SVG of Pele and the model of its `parse()`. Pele gives
  each part of a diagram the attribute `data-id`, and the model gives the
  ends of each edge and the members of each subgraph. `name/1` gives each part
  an `id` and the marks of `Expresso.Element.Diagram.Outline`:

  | Part of a flowchart | `data-id` | Name |
  | --- | --- | --- |
  | A node | `web` | `web` |
  | A subgraph | `app` | `app` |
  | An edge | `L_web_api_0` | `web->api` |
  | A second edge between the same ends | `L_web_api_1` | `web->api:2` |
  | An edge with an id in the source, such as `web e1@--> api` | `e1` | `e1` |

  The name of an edge has its two ends and its arrow, as for Graphviz and D2,
  so a part names an edge as the source names its ends. An edge with a label
  has a second group, for its label, with the same `data-id`. That group gets
  the same `id`, so a part shows the edge and its label at the same steps.
  Only the first element of a name gets the marks, so the list for a screen
  reader holds each part one time.

  A diagram of a type that this module does not name yet keeps the `data-id`
  of Pele as the name of each part, with no marks.
  """

  alias Expresso.Element.Diagram.{Font, Tool}

  @tool %{
    name: "Node",
    program: "node",
    variable: "EXPRESSO_NODE",
    install: "https://nodejs.org"
  }

  # The version of the copy of `pele.js` in `priv/pele/`. A test compares it
  # with the version in `package.json`.
  @version "1.8.0"

  @doc "The tool, for `Expresso.Element.Diagram.Tool`"
  @spec tool() :: Tool.t()
  def tool, do: @tool

  @doc "Pele has one layout, so a diagram of Mermaid takes no `layout` option"
  @spec layouts() :: [atom()]
  def layouts, do: []

  @doc "The version of the copy of Pele"
  @spec version() :: String.t()
  def version, do: @version

  @doc "The path of the script that runs Pele"
  @spec script() :: Path.t()
  def script, do: Application.app_dir(:expresso, "priv/pele/render.mjs")

  @doc """
  Draw the source of a Mermaid diagram, and return the SVG and the names

  `label` names the diagram in a message, such as the path of its file. Pele
  writes the family of `font` in the SVG. The function raises an
  `ArgumentError` when Node is not present and when Pele cannot draw the
  source, with the message of Pele.
  """
  @spec draw!(String.t(), String.t(), Font.t()) :: {String.t(), [String.t()]}
  def draw!(source, label, font \\ Font.builtin()) do
    files = [
      {"source.mmd", source},
      {"options.json", JSON.encode!(%{"fontFamily" => font.family})}
    ]

    @tool
    |> Tool.run!(label, fn dir -> {[script(), dir], []} end, files, "graph.json")
    |> JSON.decode!()
    |> name()
  end

  @doc """
  Give a diagram of Pele the colors of the theme

  Pele writes each color as a custom property with a fallback, such as
  `var(--pele-fg, #1f1f1f)`, and the style sheet of the deck sets the
  properties for the class `diagram-pele`. Therefore the SVG needs no change.
  """
  @spec theme(String.t()) :: String.t()
  def theme(svg), do: svg

  @doc """
  Give each part of the result of the script its name and its marks

  The result holds the SVG, the type of the diagram and the model of
  `parse()`. The function returns the SVG and the names, in the order of the
  file.

      iex> svg = ~s(<svg><g class="pele-node" data-id="web"></g></svg>)
      iex> Expresso.Element.Diagram.Pele.name(%{"svg" => svg, "type" => "flowchart", "model" => %{"edges" => [], "subgraphs" => []}})
      {~s(<svg><g class="pele-node" data-id="web" id="web" data-graph-kind="node"></g></svg>), ["web"]}
  """
  @spec name(map()) :: {String.t(), [String.t()]}
  def name(%{"svg" => svg, "type" => type, "model" => model}) do
    plan = plan(type, model || %{})

    {tree, {names, _seen}} =
      svg
      |> Floki.parse_fragment!()
      |> walk(plan, {[], MapSet.new()})

    {Floki.raw_html(tree), Enum.reverse(names)}
  end

  # The plan of a type: a function that takes the `data-id` and the classes
  # of an element, and returns its name and its marks.
  defp plan("flowchart", model) do
    subgraphs = model["subgraphs"] || []

    parents =
      for subgraph <- subgraphs, child <- subgraph["nodes"] || [], into: %{} do
        {child, subgraph["id"]}
      end

    edges = edges(model["edges"] || [])
    fn data_id, classes -> flowchart_part(data_id, classes, parents, edges) end
  end

  defp plan(_type, _model), do: fn data_id, _classes -> {data_id, []} end

  # A part of a flowchart. The group of the label of an edge has the class
  # `pele-edge-label`, so it takes the name of its edge and no marks.
  defp flowchart_part(data_id, classes, parents, edges) do
    parent = for parent <- List.wrap(parents[data_id]), do: {"data-graph-parent", parent}

    cond do
      "pele-edge" in classes and Map.has_key?(edges, data_id) -> edges[data_id]
      "pele-cluster" in classes -> {data_id, [{"data-graph-kind", "container"} | parent]}
      "pele-node" in classes -> {data_id, [{"data-graph-kind", "node"} | parent]}
      true -> {edges |> Map.get(data_id, {data_id, []}) |> elem(0), []}
    end
  end

  # The name and the marks of each edge, by its `data-id`. A second edge
  # between the same ends gets `:2` after its name, as for Graphviz.
  defp edges(edges) do
    {named, _counts} =
      Enum.map_reduce(edges, %{}, fn edge, counts ->
        arrow = arrow(edge["type"])
        {from, to} = {edge["start"], edge["end"]}

        {name, counts} =
          if edge["isUserDefinedId"] do
            {edge["id"], counts}
          else
            base = from <> arrow <> to
            count = Map.get(counts, base, 0) + 1
            {if(count == 1, do: base, else: "#{base}:#{count}"), Map.put(counts, base, count)}
          end

        marks =
          [
            {"data-graph-kind", "edge"},
            {"data-graph-from", from},
            {"data-graph-to", to},
            {"data-graph-arrow", arrow}
          ] ++ label(edge["text"])

        {{edge["id"], {name, marks}}, counts}
      end)

    Map.new(named)
  end

  defp label(text) when is_binary(text) and text != "", do: [{"data-graph-label", text}]
  defp label(_text), do: []

  # The arrow of an edge for its name: `<->` for an edge with a head at each
  # end, `--` for an edge with no head, and `->` for each other edge.
  defp arrow("double_" <> _rest), do: "<->"
  defp arrow("arrow_open"), do: "--"
  defp arrow(_type), do: "->"

  defp walk(nodes, plan, acc) when is_list(nodes),
    do: Enum.map_reduce(nodes, acc, &walk(&1, plan, &2))

  defp walk({tag, attrs, children}, plan, acc) when is_binary(tag) do
    {attrs, acc} =
      case List.keyfind(attrs, "data-id", 0) do
        {"data-id", data_id} -> give_name(attrs, data_id, plan, acc)
        nil -> {attrs, acc}
      end

    {children, acc} = walk(children, plan, acc)
    {{tag, attrs, children}, acc}
  end

  defp walk(node, _plan, acc), do: {node, acc}

  defp give_name(attrs, data_id, plan, {names, seen}) do
    classes =
      case List.keyfind(attrs, "class", 0) do
        {"class", class} -> String.split(class)
        nil -> []
      end

    {name, marks} = plan.(data_id, classes)

    if MapSet.member?(seen, name) do
      {attrs ++ [{"id", name}], {names, seen}}
    else
      {attrs ++ [{"id", name} | marks], {[name | names], MapSet.put(seen, name)}}
    end
  end
end
