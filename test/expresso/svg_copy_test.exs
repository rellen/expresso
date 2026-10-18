defmodule Expresso.SvgCopyTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.{Builder, SvgCopy}
  alias Expresso.Element.Part

  doctest SvgCopy

  @fixtures "test/fixtures/copies"

  defp diagram_deck(files) do
    files
    |> Enum.map(&Builder.slide(&1, elements: [Builder.diagram(Path.join(@fixtures, &1))]))
    |> Builder.deck(name: "copies")
    |> document()
  end

  defp styles(document), do: document |> LazyHTML.query("svg style") |> Enum.map(&LazyHTML.text/1)

  describe "number/2" do
    test "makes a map of the ids, so an id that ends with a number does not change two times" do
      svg = File.read!(Path.join(@fixtures, "gradients.svg"))
      tree = svg |> SvgCopy.number(2) |> LazyHTML.from_fragment()

      assert tree |> LazyHTML.query("[id]") |> Enum.flat_map(&LazyHTML.attribute(&1, "id")) ==
               ["g1-2", "g1-2-2", "red-2", "blue-2"]

      assert tree |> LazyHTML.query("rect") |> Enum.flat_map(&LazyHTML.attribute(&1, "fill")) ==
               ["url(#g1-2)", "url(#g1-2-2)"]
    end

    test "numbers each reference, and keeps a reference to an id of a different file" do
      svg =
        ~s(<svg><clipPath id='c'/><use href="#c"/><use xlink:href="#c"/>) <>
          ~s|<g clip-path="url('#c')" mask="url(#other)"/><a href="#slide-2"/></svg>|

      assert SvgCopy.number(svg, 4) ==
               ~s(<svg><clipPath id='c-4'/><use href="#c-4"/><use xlink:href="#c-4"/>) <>
                 ~s|<g clip-path="url('#c-4')" mask="url(#other)"/><a href="#slide-2"/></svg>|
    end

    test "numbers an id with a point, a colon or a space" do
      svg = ~s(<svg><rect id="step.1"/><rect id="has space"/><use href="#step.1"/></svg>)

      assert SvgCopy.number(svg, 2) ==
               ~s(<svg><rect id="step.1-2"/><rect id="has space-2"/><use href="#step.1-2"/></svg>)
    end

    test "limits each rule of a style to the copy, also in @media, and keeps @keyframes" do
      svg = File.read!(Path.join(@fixtures, "mermaid.svg"))
      numbered = SvgCopy.number(svg, 5)
      scope = ~s|:where([data-svg-copy="5"], [data-svg-copy="5"] *)|

      assert numbered =~ ~s(<svg data-svg-copy="5" id="my-svg-5")
      assert numbered =~ "#my-svg-5#{scope}{font-family:sans-serif;}"
      assert numbered =~ "#my-svg-5 .node rect#{scope}{fill:#ECECFF;"
      assert numbered =~ "@media screen{#my-svg-5 .edge#{scope}{stroke:#333333;}}"
      assert numbered =~ "@keyframes dash{to{stroke-dashoffset:0;}}"
    end

    test "keeps a comment, a string and a selector list with a comma in parentheses" do
      css = ~s|/* a, b { */ .a:is(.b, .c)::after, [title="x,y"] {content: "}"; fill: url(#f)}|
      numbered = SvgCopy.number(~s(<svg><style>#{css}</style><g id="f"/></svg>), 1)
      scope = ~s|:where([data-svg-copy="1"], [data-svg-copy="1"] *)|

      assert numbered ==
               ~s|<svg data-svg-copy="1"><style>/* a, b { */ .a:is(.b, .c)#{scope}::after,| <>
                 ~s| [title="x,y"]#{scope} {content: "}"; fill: url(#f-1)}</style><g id="f-1"/></svg>|
    end
  end

  describe "a diagram" do
    test "with a style keeps its rules to its own copies" do
      document = diagram_deck(["red.svg", "blue.svg"])

      [red | _copies] = document |> LazyHTML.query("#slide-1 svg") |> Enum.to_list()
      [number] = LazyHTML.attribute(red, "data-svg-copy")
      [style] = red |> LazyHTML.query("style") |> Enum.map(&LazyHTML.text/1)

      assert style =~ ~s|.st0:where([data-svg-copy="#{number}"], [data-svg-copy="#{number}"] *)|

      numbers =
        document
        |> LazyHTML.query("svg[data-svg-copy]")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "data-svg-copy"))

      assert Enum.uniq(numbers) == numbers
      assert length(numbers) == length(styles(document))
    end

    test "from mermaid-cli gets the numbered id in each #id selector" do
      document = diagram_deck(["mermaid.svg"])

      for svg <- LazyHTML.query(document, ".diagram > svg") do
        [id] = LazyHTML.attribute(svg, "id")
        [style] = svg |> LazyHTML.query("style") |> Enum.map(&LazyHTML.text/1)
        assert id =~ ~r/^my-svg-\d+$/
        assert style =~ "##{id} .node rect"
        refute style =~ ~r/#my-svg[ .{:]/
      end
    end

    test "with the ids g1 and g1-2 keeps two different ids in each copy" do
      document = diagram_deck(["gradients.svg"])

      for svg <- LazyHTML.query(document, ".diagram > svg") do
        ids =
          svg |> LazyHTML.query("lineargradient") |> Enum.flat_map(&LazyHTML.attribute(&1, "id"))

        fills = svg |> LazyHTML.query("rect") |> Enum.flat_map(&LazyHTML.attribute(&1, "fill"))

        assert [g1, g1_2] = ids
        assert g1 != g1_2
        assert fills == ["url(##{g1})", "url(##{g1_2})"]
      end
    end

    @tag :tmp_dir
    test "with an image in a data URI holds the image one time", %{tmp_dir: tmp_dir} do
      png = Base.encode64(:crypto.strong_rand_bytes(4000))
      src = Path.join(tmp_dir, "photo.svg")

      File.write!(src, """
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 10 10">
        <image href="data:image/png;base64,#{png}" width="5" height="5"/>
        <image xlink:href="data:image/png;base64,#{png}A" x="5" width="5" height="5"/>
      </svg>
      """)

      html =
        [Builder.slide("photo", elements: [Builder.diagram(src)])]
        |> Builder.deck(name: "photo")
        |> Expresso.Deck.render()

      assert length(String.split(html, png <> "\"")) == 2
      assert length(String.split(html, png <> "A\"")) == 2

      document = LazyHTML.from_document(html)
      assert count(document, "image") > 2
      assert count(document, "image[data-asset-href]") == count(document, "image") - 2
    end
  end

  describe "a part of a diagram" do
    test "with a class keeps its class next to diagram-part" do
      part = %Part{id: "v", el: "s1-e2", steps: [1, 2], on: [Builder.on(2, state: :dim)]}

      svg =
        %Expresso.Element.Diagram{src: Path.join(@fixtures, "tspan.svg"), elements: [part]}
        |> Expresso.Element.Diagram.get_assigns()
        |> Map.fetch!(:svg)

      assert svg =~ ~r/<tspan class="diagram-part hl" [^>]*data-el="s1-e2"[^>]* id="v-\d+">/
      assert [_one] = Regex.scan(~r/<tspan[^>]*>/, svg)
      refute svg =~ ~r/<tspan[^>]*class="[^"]*"[^>]*class=/
    end

    test "with a point, a colon or a space in its id is found" do
      parts = for id <- ["step.1", "a:b", "has space"], do: Builder.part(id, at: [from: 2])
      diagram = Builder.diagram(Path.join(@fixtures, "names.svg"), elements: parts)

      svg =
        Expresso.Element.Diagram.get_assigns(%{
          diagram
          | elements: Enum.map(diagram.elements, &%{&1 | steps: [2]})
        }).svg

      for id <- ["step.1", "a:b", "has space"] do
        assert svg =~ ~r/data-on="2" id="#{Regex.escape(id)}-\d+"/
      end
    end
  end

  describe "an icon of the deck" do
    @tag :tmp_dir
    test "gets its own ids in each copy, and one signature for the morph", %{tmp_dir: tmp_dir} do
      File.cp!(Path.join(@fixtures, "figma.svg"), Path.join(tmp_dir, "figma.svg"))

      document =
        [
          Builder.slide("one", elements: [Builder.icon("fig")]),
          Builder.slide("two",
            elements: [
              Builder.icon("fig"),
              Builder.text_area(text: "A :icon:fig: and :icon:fig:")
            ]
          )
        ]
        |> Builder.deck(name: "icons", root: tmp_dir, icons: [fig: "figma.svg"])
        |> document()

      ids =
        document |> LazyHTML.query("clippath") |> Enum.flat_map(&LazyHTML.attribute(&1, "id"))

      assert length(ids) > 6
      assert Enum.uniq(ids) == ids
      assert Enum.all?(ids, &(&1 =~ ~r/^clip0_1_2-\d+$/))

      for svg <- LazyHTML.query(document, "svg.icon-svg, svg.icon-inline") do
        [id] = svg |> LazyHTML.query("clippath") |> LazyHTML.attribute("id")
        assert svg |> LazyHTML.query("g") |> LazyHTML.attribute("clip-path") == ["url(##{id})"]
      end

      signatures =
        document
        |> LazyHTML.query(".screen figure.icon")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "data-morph-signature"))

      assert [_one, _two] = signatures
      assert Enum.uniq(signatures) |> length() == 1
    end

    @tag :tmp_dir
    test "with a style in a text area keeps one signature for the morph", %{tmp_dir: tmp_dir} do
      File.cp!(Path.join(@fixtures, "red.svg"), Path.join(tmp_dir, "red.svg"))

      document =
        for(
          name <- ["one", "two"],
          do: Builder.slide(name, elements: [Builder.text_area(text: "A :icon:red:")])
        )
        |> Builder.deck(name: "icons", root: tmp_dir, icons: [red: "red.svg"])
        |> document()

      signatures =
        document
        |> LazyHTML.query(".screen [data-morph-signature]")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "data-morph-signature"))

      assert [one, one] = signatures
    end
  end
end
