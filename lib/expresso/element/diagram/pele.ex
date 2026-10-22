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
      |> walk(plan, {[], MapSet.new(), MapSet.new(), %{}})

    {Floki.raw_html(tree), Enum.reverse(names)}
  end

  # The plan of each type that this module names. `Expresso.Element.Diagram.Pele.Plan`
  # gives the contract of a plan.
  @plans %{
    "architecture" => Expresso.Element.Diagram.Pele.Architecture,
    "block" => Expresso.Element.Diagram.Pele.Block,
    "c4" => Expresso.Element.Diagram.Pele.C4,
    "class" => Expresso.Element.Diagram.Pele.Class,
    "er" => Expresso.Element.Diagram.Pele.Er,
    "flowchart" => Expresso.Element.Diagram.Pele.Flowchart,
    "sequence" => Expresso.Element.Diagram.Pele.Sequence,
    "state" => Expresso.Element.Diagram.Pele.State
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

  # Each element gets its name. The first element of a name whose plan gives
  # marks gets them, so a lifeline or a label before its part does not take
  # the marks of the part.
  defp give_name(attrs, data_id, plan, {names, seen, marked, counts}) do
    class =
      case List.keyfind(attrs, "class", 0) do
        {"class", class} -> class
        nil -> ""
      end

    count = Map.get(counts, {data_id, class}, 0)
    counts = Map.put(counts, {data_id, class}, count + 1)

    {name, marks} =
      if is_function(plan, 3),
        do: plan.(data_id, String.split(class), count),
        else: plan.(data_id, String.split(class))

    names = if MapSet.member?(seen, name), do: names, else: [name | names]
    seen = MapSet.put(seen, name)

    if marks == [] or MapSet.member?(marked, name) do
      {attrs ++ [{"id", name}], {names, seen, marked, counts}}
    else
      {attrs ++ [{"id", name} | marks], {names, seen, MapSet.put(marked, name), counts}}
    end
  end
end
