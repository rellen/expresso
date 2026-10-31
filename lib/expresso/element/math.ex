defmodule Expresso.Element.Math do
  @moduledoc """
  An element that shows a formula in MathML

  The `math` entity takes the formula in one of two forms:

  - The MathML as its first argument, from the `<math>` tag to the `</math>`
    tag. Give the `math` tag the attribute `display="block"` for a formula on
    its own line, which is the usual form on a slide.
  - The LaTeX in the `tex` option. `typeset/1` makes the MathML with
    `Expresso.Element.Math.Tex`, in one run of Node for the deck.

  A browser renders MathML Core without a script and without a font file, and
  each browser of the floor of this project supports it. The text goes into
  the document as it is, as the text of a text area does.
  `docs/math-parts.md` gives the design of the LaTeX.
  """

  use Expresso.Element

  alias Expresso.Element.Diagram.Cache
  alias Expresso.Element.Math.Tex

  @typedoc "The struct of a math element"
  @type t :: %__MODULE__{}

  defstruct [
              :class,
              :text,
              :tex,
              elements: [],
              lines: [],
              # The names of the lines in order, from `check/1`.
              line_names: [],
              reveal: false,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  # The name of a part: a letter, then letters, digits, "-" and "_".
  @part_name ~r/^[A-Za-z][\w-]*$/

  @doc """
  Check a math element, and write its lines into one formula

  A math element has one source: the MathML, the `tex` option, or `line`
  entities. The function writes the lines into the LaTeX of one formula of the
  environment `aligned`, a row for each line, with the relation, the term and
  the reason in three columns. Each line becomes a part with its name, and
  with `reveal true` it shows at its own step. The function then checks the
  name of each `\\part{name}{…}` and `\\id{name}{…}` of the LaTeX. The entity of
  the DSL and `Expresso.Builder` call this function.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{} = math) do
    with :ok <- links_in_lines(math),
         {:ok, math} <- write_lines(math),
         :ok <- one_source(math),
         :ok <- part_names_ok(math),
         {:ok, parts} <- Expresso.Element.Copy.expand(math.elements) do
      {:ok, %__MODULE__{math | elements: parts}}
    end
  end

  defp write_lines(%__MODULE__{lines: []} = math), do: {:ok, math}

  defp write_lines(%__MODULE__{lines: _lines, text: text, tex: tex})
       when is_binary(text) or is_binary(tex),
       do:
         {:error,
          "a math element takes the MathML, the tex option or line entities, and one only"}

  defp write_lines(%__MODULE__{lines: lines, elements: parts, reveal: reveal} = math) do
    named =
      Enum.with_index(lines, 1) |> Enum.map(fn {line, n} -> {line.name || "line#{n}", line} end)

    at = if reveal, do: Expresso.Overlay.from_next()

    rows = Enum.map_join(named, " \\\\\n", fn {name, line} -> row(name, line) end)

    # A part of the deck with the name of a line gives that line its options,
    # such as an `on` entity, so the line has one set of overlay attributes.
    own = Map.new(parts, &{&1.id, &1})

    line_parts =
      Enum.map(named, fn {name, _line} ->
        case own do
          %{^name => %Expresso.Element.Part{} = part} ->
            %Expresso.Element.Part{part | at: part.at || at}

          _own ->
            %Expresso.Element.Part{id: name, at: at}
        end
      end)

    names = Enum.map(named, &elem(&1, 0))
    parts = Enum.reject(parts, &(&1.id in names))

    {:ok,
     %__MODULE__{
       math
       | tex: "\\begin{aligned}\n" <> rows <> "\n\\end{aligned}",
         lines: [],
         line_names: names,
         reveal: false,
         elements: line_parts ++ parts
     }}
  end

  # A row of the environment `aligned`: the relation in the first column, at
  # the right, the term in the second column, and the reason in the fourth
  # column, at the left. Each cell is in the part of the line.
  defp row(name, line) do
    relation = if line.relation, do: "\\part{#{name}}{#{line.relation}}", else: ""
    why = if line.why, do: " && \\part{#{name}}{\\text{#{escape(line.why)}}}", else: ""
    "#{relation} & \\part{#{name}}{#{line.tex}}#{why}"
  end

  # The characters of plain text that LaTeX reads as commands in `\text`.
  @escapes %{
    "\\" => "\\textbackslash{}",
    "{" => "\\{",
    "}" => "\\}",
    "$" => "\\$",
    "&" => "\\&",
    "#" => "\\#",
    "_" => "\\_",
    "%" => "\\%",
    "^" => "\\textasciicircum{}",
    "~" => "\\textasciitilde{}"
  }

  defp escape(text),
    do: String.replace(text, Map.keys(@escapes), &Map.fetch!(@escapes, &1))

  defp one_source(%__MODULE__{text: nil, tex: nil}),
    do:
      {:error, "a math element takes the MathML as its argument, the tex option or line entities"}

  defp one_source(%__MODULE__{text: text, tex: tex}) when is_binary(text) and is_binary(tex),
    do: {:error, "a math element takes the MathML or the tex option, and not both"}

  defp one_source(_math), do: :ok

  defp part_names_ok(%__MODULE__{tex: tex}) when is_binary(tex) do
    case Enum.reject(part_names(tex) ++ link_names(tex), &Regex.match?(@part_name, &1)) do
      [] ->
        :ok

      [name | _names] ->
        {:error,
         "the part name #{inspect(name)} of a math element must start with a letter, and " <>
           "hold only letters, digits, \"-\" and \"_\""}
    end
  end

  defp part_names_ok(_math), do: :ok

  # The name of each `\part{name}` and `\id{name}` of a source in LaTeX.
  defp part_names(tex) do
    ~r/\\(?:part|id)\s*\{([^}]*)\}/
    |> Regex.scan(tex, capture: :all_but_first)
    |> List.flatten()
  end

  # The name of each `\from{name}` of a source in LaTeX.
  defp link_names(tex) do
    ~r/\\from\s*\{([^}]*)\}/
    |> Regex.scan(tex, capture: :all_but_first)
    |> List.flatten()
  end

  # A link names a part of an earlier line, so only a math element with line
  # entities takes `\from`.
  defp links_in_lines(%__MODULE__{lines: [], tex: tex}) when is_binary(tex) do
    if link_names(tex) == [],
      do: :ok,
      else:
        {:error,
         "\\from links a line to an earlier line, so it needs line entities. " <>
           "See docs/reference/math-element.md"}
  end

  defp links_in_lines(%__MODULE__{lines: [%Expresso.Element.MathLine{} = first | _lines]}) do
    if link_names(first.tex <> (first.relation || "")) == [],
      do: :ok,
      else: {:error, "the first line of a math element has \\from, and no line comes before it"}
  end

  defp links_in_lines(_math), do: :ok

  @doc """
  Give the names of the parts of the MathML of a formula, in the order of the
  MathML, without a repeat

  A part has a name in the attribute `data-part`, from `\\part{name}{…}`, or
  in the attribute `class`, from `\\class{name}{…}`. The list also holds the
  classes that Temml writes, such as `tml-display`.

      iex> Expresso.Element.Math.parts(~s(<math class="tml-display"><mrow data-part="redex"><mi class="bind">f</mi></mrow></math>))
      ["tml-display", "redex", "bind"]
  """
  @spec parts(String.t()) :: [String.t()]
  def parts(mathml) do
    mathml
    |> Floki.parse_fragment!()
    |> Floki.find("[data-part], [class]")
    |> Enum.flat_map(fn {_tag, attrs, _children} ->
      attrs = Map.new(attrs)
      List.wrap(attrs["data-part"]) ++ String.split(attrs["class"] || "")
    end)
    |> Enum.uniq()
  end

  @doc """
  Make the MathML of each math element of a deck with the `tex` option

  `Expresso.Renderer` calls this function before the render. One run of Node
  makes the MathML of each formula of the deck, and the watch mode keeps the
  MathML of each source from one render to the next, so a change of one slide
  runs Node for the formulas that changed. A deck with no LaTeX runs no Node.

  `render` makes the MathML of a list of sources. The default is
  `Expresso.Element.Math.Tex.render!/1`, and a test can give a function that
  needs no Node. The function raises an `ArgumentError` with the message of
  Temml for a source that Temml cannot read.
  """
  @spec typeset(Expresso.Deck.t(), ([String.t()] -> [Tex.result()])) :: Expresso.Deck.t()
  def typeset(%Expresso.Deck{} = deck, render \\ &Tex.render!/1) do
    {_deck, sources} =
      Expresso.Element.Tree.map_reduce_deck(deck, [], fn
        %__MODULE__{text: nil, tex: tex} = math, sources when is_binary(tex) ->
          {math, [tex | sources]}

        element, sources ->
          {element, sources}
      end)

    case sources |> Enum.reverse() |> Enum.uniq() do
      [] -> deck
      sources -> typeset(deck, sources, render)
    end
  end

  defp typeset(deck, sources, render) do
    # The key of each source holds the version of Temml, so a new version
    # makes each formula again.
    keys = Enum.map(sources, &{Tex, Tex.version(), &1})

    results =
      keys
      |> Cache.fetch_many(fn missing -> missing |> Enum.map(&elem(&1, 2)) |> render.() end)
      |> then(&Map.new(Enum.zip(sources, &1)))

    Expresso.Element.Tree.map_deck(deck, fn
      %__MODULE__{text: nil, tex: tex} = math when is_binary(tex) ->
        %__MODULE__{math | text: mathml!(Map.fetch!(results, tex), tex)}

      element ->
        element
    end)
  end

  defp mathml!({:ok, mathml}, _tex), do: mathml

  defp mathml!({:error, message}, tex) do
    raise ArgumentError,
          "Temml cannot read the formula #{inspect(tex)} of a math element:\n\n#{message}"
  end

  @doc """
  Replace each `move_to` of the parts of a deck with a move that the browser
  measures

  An `on` entity of a part of a formula can take `move_to`, the name of a
  different part of the same formula. The place of a part comes from the
  fonts of the browser, so the render cannot measure it. This function puts
  `x: "var(--to-x-name)"` and `y: "var(--to-y-name)"` into `set`, and the
  presenter script gives the part these two custom properties: the distance
  from the center of the part to the center of the part `name`. A browser
  with no script then shows the part at its place.

  `Expresso.Renderer` calls this function after `typeset/1`. It raises for a
  name that the formula does not have, and for a part that moves to itself.
  """
  @spec place(Expresso.Deck.t()) :: Expresso.Deck.t()
  def place(%Expresso.Deck{} = deck), do: Expresso.Element.Tree.map_deck(deck, &place_one/1)

  defp place_one(%__MODULE__{text: text} = math) when is_binary(text) do
    %__MODULE__{text: text, elements: parts} = math = Expresso.Element.Math.Links.place(math)
    parts = Enum.map(parts, &Expresso.Element.Copy.moves/1)
    math = %__MODULE__{math | elements: parts}

    if Enum.any?(parts, &(targets(&1) != [])) do
      names = parts(text)
      %__MODULE__{math | elements: Enum.map(parts, &place_part(&1, names))}
    else
      math
    end
  end

  defp place_one(element), do: element

  defp place_part(%Expresso.Element.Part{id: id, on: on} = part, names) do
    on =
      Enum.map(on || [], fn
        %Expresso.Element.On{move_to: nil} = entity ->
          entity

        %Expresso.Element.On{move_to: ^id} ->
          raise ArgumentError, "the part #{inspect(id)} of a math element moves to itself"

        %Expresso.Element.On{move_to: target, set: set} = entity ->
          if target not in names do
            raise ArgumentError,
                  "the part #{inspect(id)} of a math element moves to #{inspect(target)}, and " <>
                    "the formula has no part with that name"
          end

          move = [x: "var(--to-x-#{target})", y: "var(--to-y-#{target})"]
          %Expresso.Element.On{entity | set: move ++ (set || [])}
      end)

    %Expresso.Element.Part{part | on: on}
  end

  # The names of the parts that a part moves to, in order, without a repeat.
  defp targets(%Expresso.Element.Part{on: on}),
    do: (on || []) |> Enum.map(& &1.move_to) |> Enum.reject(&is_nil/1) |> Enum.uniq()

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(math) do
    %__MODULE__{text: text, elements: parts} = math
    %{text: mark(text, parts), overlay: Expresso.Overlay.Render.attributes(math)}
  end

  # Put the overlay attributes of each part on each element of the MathML with
  # its name, in `data-part` or in `class`. The class `math-part` gives the
  # element the rules of the theme for an element with steps. A name that the
  # MathML does not have stops the render.
  defp mark(text, []), do: text

  defp mark(text, parts) do
    names = parts(text)
    {copies, parts} = Enum.split_with(parts, & &1.copy_of)

    for %Expresso.Element.Part{id: id} <- parts, id not in names do
      raise ArgumentError,
            "the math element has no part with the name #{inspect(id)}. Its parts are: " <>
              Enum.map_join(names -- ["tml-display"], ", ", &inspect/1)
    end

    tree = Floki.parse_fragment!(text)

    parts
    |> Enum.reduce(tree, fn %Expresso.Element.Part{id: id} = part, tree ->
      attributes =
        [{"class", "math-part"} | Expresso.Overlay.Render.attributes(part)] ++ moves(part)

      Floki.traverse_and_update(tree, &mark_one(&1, id, attributes))
    end)
    |> Kernel.++(Enum.map(copies, &copy_math(&1, root(&1, copies), tree)))
    |> Floki.raw_html()
  end

  # A copy of a part is its own `math` element after the formula, so the
  # formula keeps its layout. It holds a copy of each element with the name of
  # the source, from the MathML before the marks of the overlays, and a copy
  # inside it gives no name of a part. The style sheet puts the copy out of
  # the flow, and the presenter script puts it on its source. A screen reader
  # does not read it, because it repeats the source.
  defp copy_math(%Expresso.Element.Part{id: id} = part, source, tree) do
    display =
      case tree do
        [{"math", attrs, _children} | _rest] -> List.keyfind(attrs, "display", 0)
        _tree -> nil
      end

    attributes =
      [{"class", "math-copy math-part part-copy"} | Expresso.Overlay.Render.attributes(part)] ++
        moves(part) ++
        [{"data-part", id}, {"data-copy-of", source}, {"aria-hidden", "true"}] ++
        covers(part) ++ List.wrap(display)

    {"math", merge(attributes, []), [{"mrow", [], Enum.map(named(tree, source), &unname/1)}]}
  end

  # The part of the formula that a copy comes from. A copy of a copy comes from
  # the source of its source.
  defp root(%Expresso.Element.Part{copy_of: source}, copies) do
    case Enum.find(copies, &(&1.id == source)) do
      nil -> source
      copy -> root(copy, copies)
    end
  end

  # The copy of a link hides its target, the linked sub-term, when the script
  # puts the copy on its place.
  defp covers(%Expresso.Element.Part{covers: true, copy_to: target}),
    do: [{"data-covers", target}]

  defp covers(_part), do: []

  defp named(nodes, id) when is_list(nodes), do: Enum.flat_map(nodes, &named(&1, id))

  defp named({tag, attrs, children} = node, id) when is_binary(tag) do
    if named?(attrs, id), do: [node], else: named(children, id)
  end

  defp named(_node, _id), do: []

  defp unname({tag, attrs, children}) when is_binary(tag),
    do: {tag, List.keydelete(attrs, "data-part", 0), Enum.map(children, &unname/1)}

  defp unname(node), do: node

  # The attribute `data-move-to` names each part that a part moves to, so the
  # presenter script knows which distances to measure.
  defp moves(part) do
    case targets(part) do
      [] -> []
      targets -> [{"data-move-to", Enum.join(targets, " ")}]
    end
  end

  defp mark_one({tag, attrs, children} = node, id, attributes) do
    if named?(attrs, id), do: {tag, merge(attributes, attrs), children}, else: node
  end

  defp mark_one(node, _id, _attributes), do: node

  defp named?(attrs, id) do
    attrs = Map.new(attrs)
    attrs["data-part"] == id or id in String.split(attrs["class"] || "")
  end

  # An HTML parser keeps the first of two attributes with the same name, so a
  # `class` and a `style` of the element join the attribute of the overlay.
  defp merge(overlay, attrs) do
    {overlay, attrs} =
      Enum.map_reduce(overlay, attrs, fn {name, value}, attrs ->
        case List.keytake(attrs, name, 0) do
          {{"class", own}, attrs} -> {{"class", "#{value} #{own}"}, attrs}
          {{"style", own}, attrs} -> {{"style", "#{own}; #{value}"}, attrs}
          {_own, attrs} -> {{name, value}, attrs}
          nil -> {{name, value}, attrs}
        end
      end)

    overlay ++ attrs
  end

  @doc """
  Make the HTML of a math element

  The MathML goes into one block element inside the root tag.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("math", assigns[:class]), rest!: @overlay do
        div do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
