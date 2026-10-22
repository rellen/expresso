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
  ends of each edge and the members of each group. `name/1` gives each part
  an `id` and the marks of `Expresso.Element.Diagram.Outline`, with the plan
  of its type, such as `Expresso.Element.Diagram.Pele.Flowchart`.
  `Expresso.Element.Diagram.Pele.Plan` gives the contract of a plan.

  The name of an edge has its two ends and its arrow, as for Graphviz and D2,
  so a part names an edge as the source names its ends. Some parts have more
  than one element with the same `data-id`, such as an edge and its label, or
  an actor of a sequence diagram at the top and at the bottom. Each element
  gets the same `id`, so a part shows them at the same steps. Only the first
  element whose plan gives marks gets them, so the list for a screen reader
  holds each part one time.

  A diagram of a type without a plan keeps the `data-id` of Pele as the name
  of each part, with no marks.
  """

  alias Expresso.Element.Diagram.{Font, Tool}
  alias Expresso.Element.Diagram.Pele.Plan

  @tool %{
    name: "Node",
    program: "node",
    variable: "EXPRESSO_NODE",
    install: "https://nodejs.org"
  }

  # The version of the copy of `pele.js` in `priv/pele/`. A test compares it
  # with the version in `package.json`.
  @version "1.8.0"

  # The printable characters of ASCII, and the ellipsis, for the widths of a
  # text that Pele writes and that the source does not hold.
  @ascii List.to_string(Enum.to_list(32..126)) <> "…"

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
  writes the family of `font` in the SVG, and it measures each text with the
  advance widths of the characters of `font`, from
  `Expresso.Element.Diagram.Font.advances/2`. The widths cover each character
  of the source and each printable character of ASCII, because Pele can write
  a text that is not in the source, such as a number on an axis. The function
  raises an
  `ArgumentError` when Node is not present and when Pele cannot draw the
  source, with the message of Pele.
  """
  @spec draw!(String.t(), String.t(), Font.t()) :: {String.t(), [String.t()]}
  def draw!(source, label, font \\ Font.builtin()),
    do: source |> json!(label, font) |> JSON.decode!() |> name()

  @doc """
  Run the script on a source, and return the text of its JSON

  The JSON holds the SVG, the type of the diagram and the model of `parse()`.
  `draw!/3` reads it, and the fixtures of the tests hold it as it is.
  """
  @spec json!(String.t(), String.t(), Font.t()) :: String.t()
  def json!(source, label, font \\ Font.builtin()) do
    files = [
      {"source.mmd", source},
      {"options.json",
       JSON.encode!(%{
         "fontFamily" => font.family,
         "widths" => Font.advances(font, source <> @ascii)
       })}
    ]

    Tool.run!(@tool, label, fn dir -> {[script(), dir], []} end, files, "graph.json")
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

    {tree, {names, _seen, _marked, _counts}} =
      svg
      |> Floki.parse_fragment!()
      |> walk(plan, {[], MapSet.new(), MapSet.new(), %{}}, "")

    {Floki.raw_html(tree), Enum.reverse(names)}
  end

  # The plan of each type that this module names. `Expresso.Element.Diagram.Pele.Plan`
  # gives the contract of a plan.
  @plans %{
    "agentflow" => Expresso.Element.Diagram.Pele.Flowchart,
    "architecture" => Expresso.Element.Diagram.Pele.Architecture,
    "block" => Expresso.Element.Diagram.Pele.Block,
    "c4" => Expresso.Element.Diagram.Pele.C4,
    "class" => Expresso.Element.Diagram.Pele.Class,
    "cynefin" => Expresso.Element.Diagram.Pele.Cynefin,
    "er" => Expresso.Element.Diagram.Pele.Er,
    "eventmodeling" => Expresso.Element.Diagram.Pele.Eventmodeling,
    "flowchart" => Expresso.Element.Diagram.Pele.Flowchart,
    "gantt" => Expresso.Element.Diagram.Pele.Gantt,
    "gitGraph" => Expresso.Element.Diagram.Pele.Git,
    "ishikawa" => Expresso.Element.Diagram.Pele.Ishikawa,
    "journey" => Expresso.Element.Diagram.Pele.Journey,
    "kanban" => Expresso.Element.Diagram.Pele.Kanban,
    "mindmap" => Expresso.Element.Diagram.Pele.Mindmap,
    "packet" => Expresso.Element.Diagram.Pele.Packet,
    "pie" => Expresso.Element.Diagram.Pele.Pie,
    "quadrantChart" => Expresso.Element.Diagram.Pele.Quadrant,
    "radar" => Expresso.Element.Diagram.Pele.Radar,
    "requirement" => Expresso.Element.Diagram.Pele.Requirement,
    "sankey" => Expresso.Element.Diagram.Pele.Sankey,
    "sequence" => Expresso.Element.Diagram.Pele.Sequence,
    "state" => Expresso.Element.Diagram.Pele.State,
    "swimlane" => Expresso.Element.Diagram.Pele.Flowchart,
    "timeline" => Expresso.Element.Diagram.Pele.Timeline,
    "treemap" => Expresso.Element.Diagram.Pele.Treemap,
    "treeView" => Expresso.Element.Diagram.Pele.TreeView,
    "usecase" => Expresso.Element.Diagram.Pele.Usecase,
    "venn" => Expresso.Element.Diagram.Pele.Venn,
    "xychart" => Expresso.Element.Diagram.Pele.Xychart
  }

  @doc "The types of Pele that have a plan, with the names and the marks of their parts"
  @spec planned() :: [String.t()]
  def planned, do: @plans |> Map.keys() |> Enum.sort()

  defp plan(type, model) do
    case @plans[type] do
      nil -> Plan.plain()
      module -> module.plan(model)
    end
  end

  # `group` holds the classes of the parent of the nodes.
  defp walk(nodes, plan, acc, group) when is_list(nodes),
    do: Enum.map_reduce(nodes, acc, &walk(&1, plan, &2, group))

  defp walk({tag, attrs, children}, plan, acc, group) when is_binary(tag) do
    data_id =
      case List.keyfind(attrs, "data-id", 0) do
        {"data-id", data_id} -> data_id
        nil -> nil
      end

    if data_id || unnamed?(attrs, plan) do
      {named, acc} = give_name(attrs, data_id, plan, acc, group)
      {children, acc} = walk(children, plan, acc, class(attrs))
      {place(tag, attrs, named, children), acc}
    else
      {children, acc} = walk(children, plan, acc, class(attrs))
      {{tag, attrs, children}, acc}
    end
  end

  defp walk(node, _plan, acc, _group), do: {node, acc}

  defp class(attrs) do
    case List.keyfind(attrs, "class", 0) do
      {"class", class} -> class
      nil -> ""
    end
  end

  # A group takes its name and its marks itself. Another element with marks,
  # such as the `path` of a slice of a pie, goes into a group with its name
  # and its marks, as the group of a part of each other type, so
  # `Expresso.Element.Diagram` and `Expresso.Element.Diagram.Outline` find it.
  defp place(tag, attrs, named, children) do
    case named -- attrs do
      [{"id", _name}] -> {tag, named, children}
      [{"id", _name} | _marks] = marks when tag != "g" -> {"g", marks, [{tag, attrs, children}]}
      _added -> {tag, named, children}
    end
  end

  # Some types draw a part with no `data-id`, such as the line of a mindmap,
  # an event of a timeline, a series of an XY chart or the label of a point.
  # A plan with three arguments gets such a node, edge, series or label with
  # the `data-id` `nil`.
  defp unnamed?(attrs, plan) do
    case List.keyfind(attrs, "class", 0) do
      {"class", class} -> is_function(plan, 3) and kind(String.split(class)) != nil
      nil -> false
    end
  end

  defp kind(classes) do
    cond do
      "pele-edge" in classes -> :edge
      "pele-node" in classes -> :node
      "pele-series" in classes -> :series
      "pele-label" in classes -> :label
      true -> nil
    end
  end

  # Each element gets its name. The first element of a name whose plan gives
  # marks gets them, so a lifeline or a label before its part does not take
  # the marks of the part.
  defp give_name(attrs, data_id, plan, {names, seen, marked, counts}, group) do
    classes = attrs |> class() |> String.split()
    {key, classes} = count_key(data_id, classes, group)
    count = Map.get(counts, key, 0)
    counts = Map.put(counts, key, count + 1)

    case call(plan, data_id, classes, count) do
      {nil, _marks} ->
        {attrs, {names, seen, marked, counts}}

      {name, marks} ->
        names = if MapSet.member?(seen, name), do: names, else: [name | names]
        seen = MapSet.put(seen, name)

        if marks == [] or MapSet.member?(marked, name),
          do: {attrs ++ [{"id", name}], {names, seen, marked, counts}},
          else: {attrs ++ [{"id", name} | marks], {names, seen, MapSet.put(marked, name), counts}}
    end
  end

  # An element with a `data-id` counts with the elements of the same
  # `data-id` and classes. The edges with no `data-id` have one count,
  # whatever their other classes, such as a merge of a git graph, and the
  # nodes and the series have their own counts. A label with no `data-id`
  # counts in its group, and the plan gets the classes of the group too, such
  # as `pele-point-labels`.
  defp count_key(nil, classes, group) do
    case kind(classes) do
      :label -> {{:label, group}, classes ++ String.split(group)}
      kind -> {kind, classes}
    end
  end

  defp count_key(data_id, classes, _group), do: {{data_id, classes}, classes}

  defp call(plan, data_id, classes, count) when is_function(plan, 3),
    do: plan.(data_id, classes, count)

  defp call(plan, data_id, classes, _count), do: plan.(data_id, classes)
end
