defmodule Expresso.Element.DiagramThemeTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Diagram.{D2, Font, Graphviz}

  @graphviz File.read!("test/fixtures/graphviz/flow.svg")
  @d2 File.read!("test/fixtures/d2/flow.svg")

  describe "Graphviz.theme/1" do
    test "removes the background and changes black to currentColor" do
      tree = @graphviz |> Graphviz.theme() |> Floki.parse_fragment!()

      assert Floki.find(tree, ~s(g.graph > polygon[fill="white"])) == []
      assert Floki.find(tree, ~s([fill="black"], [stroke="black"])) == []
      assert Floki.find(tree, ~s([stroke="currentColor"])) != []
    end

    test "keeps a color that the source gives" do
      svg = ~s(<svg><g class="node"><polygon fill="lightblue" stroke="red"></polygon></g></svg>)
      assert Graphviz.theme(svg) == svg
    end
  end

  describe "D2.theme/1" do
    test "writes each color of the palette as a custom property, with the color of D2 as the fallback" do
      svg = D2.theme(@d2)

      assert svg =~ ".fill-N1{fill:var(--graph-N1, #0A0F25);}"
      assert svg =~ ".stroke-B1{stroke:var(--graph-B1, #0D32B2);}"
      refute svg =~ ~r/\.(fill|stroke)-(N\d|B\d|AA\d|AB\d)\{(fill|stroke):#/
    end

    test "removes the rectangle of the background, and keeps the other shapes" do
      before = @d2 |> Floki.parse_fragment!() |> Floki.find("rect") |> length()
      tree = @d2 |> D2.theme() |> Floki.parse_fragment!()

      assert Floki.find(tree, "svg.d2-svg > rect") == []
      assert length(Floki.find(tree, "rect")) == before - 1
    end
  end

  describe "the classes of a graph" do
    defp classes(diagram) do
      [diagram] |> one_slide() |> document() |> screen(".diagram") |> LazyHTML.attribute("class")
    end

    defp drawn(src, svg, opts),
      do: struct!(Builder.diagram(src, opts), svg: svg, names: [])

    test "a graph with the colors of the theme has the class of the graph and of its tool" do
      assert classes(drawn("test/fixtures/graphviz/flow.dot", @graphviz, [])) ==
               ["diagram diagram-graph diagram-graphviz"]

      assert classes(drawn("test/fixtures/d2/flow.d2", @d2, [])) == [
               "diagram diagram-graph diagram-d2"
             ]
    end

    test "a graph with colors :tool and a diagram of an SVG file have the class diagram only" do
      assert classes(drawn("test/fixtures/d2/flow.d2", @d2, colors: :tool)) == ["diagram"]
      assert classes(Builder.diagram("test/fixtures/flow.svg")) == ["diagram"]
    end

    test "the style sheet gives each class of the palette of D2 a property" do
      css = File.read!("assets/style.css")

      for key <- ~w(N1 N2 N3 N4 N5 N6 N7 B1 B2 B3 B4 B5 B6 AA2 AA4 AA5 AB4 AB5) do
        assert css =~ "--graph-#{key}:", key
      end
    end
  end

  describe "the options" do
    test "colors and font are refused for an SVG file" do
      for {option, value} <- [colors: :tool, font: "fonts"] do
        assert_raise ArgumentError, ~r/so the diagram "flow.svg" takes no #{option} option/, fn ->
          Builder.diagram("flow.svg", [{option, value}])
        end
      end
    end

    test "colors takes :theme and :tool, and font takes a directory" do
      assert Builder.diagram("g.d2", colors: :tool, font: "fonts").colors == :tool
    end
  end

  describe "Font" do
    test "the built-in font is Atkinson Hyperlegible, with a file for each style" do
      font = Font.builtin()
      assert font.family == "Atkinson Hyperlegible"

      for {style, name} <- [
            regular: "Regular",
            bold: "Bold",
            italic: "Italic",
            bold_italic: "Bold Italic"
          ] do
        assert Font.names(font[style]) == {"Atkinson Hyperlegible", name}
      end
    end

    test "advances/2 gives the width of each character in each style, as a part of an em" do
      widths = Font.advances(Font.builtin(), "W l漢")

      assert Map.keys(widths) == ["0", "1", "2", "3"]
      assert widths["0"]["87"] == 0.84
      assert widths["0"]["32"] == 0.28
      assert widths["0"]["108"] < widths["0"]["87"]
      assert widths["1"]["87"] != widths["0"]["87"]

      # The font has no glyph for 漢, so a measurer gives it the default width.
      refute Map.has_key?(widths["0"], "28450")
    end

    test "advances/2 reads a cmap of the format 12" do
      # A font with three glyphs, an em of 1000 units, and a cmap of the format
      # 12 that maps U+1F600 to glyph 1 and U+0041 to glyph 2.
      head = <<0::size(18)-unit(8), 1000::16, 0::size(34)-unit(8)>>
      hhea = <<0::size(34)-unit(8), 3::16>>
      hmtx = <<500::16, 0::16, 700::16, 0::16, 300::16, 0::16>>
      groups = <<0x41::32, 0x41::32, 2::32, 0x1F600::32, 0x1F600::32, 1::32>>
      subtable = <<12::16, 0::16, 16 + 24::32, 0::32, 2::32>> <> groups
      cmap = <<0::16, 1::16, 3::16, 10::16, 12::32>> <> subtable

      tables = [{"cmap", cmap}, {"head", head}, {"hhea", hhea}, {"hmtx", hmtx}]
      offset = 12 + 16 * length(tables)

      {records, data, _offset} =
        Enum.reduce(tables, {<<>>, <<>>, offset}, fn {tag, bytes}, {records, data, at} ->
          {records <> <<tag::binary, 0::32, at::32, byte_size(bytes)::32>>, data <> bytes,
           at + byte_size(bytes)}
        end)

      ttf = <<0x00010000::32, length(tables)::16, 0::48>> <> records <> data
      font = %{family: "Test", regular: ttf, bold: ttf, italic: ttf, bold_italic: ttf}

      assert Font.advances(font, "A😀b")["0"] == %{"65" => 0.3, "128512" => 0.7}
    end

    test "files/1 names a file for each style" do
      assert Font.builtin() |> Font.files() |> Enum.map(&elem(&1, 0)) ==
               ["font-regular.ttf", "font-bold.ttf", "font-italic.ttf", "font-bold_italic.ttf"]
    end

    @tag :tmp_dir
    test "read!/1 takes the family and the style from each file, and a missing style takes the regular file",
         %{tmp_dir: tmp_dir} do
      for name <- ["Regular", "Bold"] do
        File.cp!(
          "assets/fonts/AtkinsonHyperlegible-#{name}.ttf",
          Path.join(tmp_dir, "#{name}.ttf")
        )
      end

      font = Font.read!(tmp_dir)
      assert font.family == "Atkinson Hyperlegible"
      assert font.bold == Font.builtin().bold
      assert font.italic == Font.builtin().regular
    end

    @tag :tmp_dir
    test "read!/1 refuses a directory without a regular file, and a directory without a TTF file",
         %{tmp_dir: tmp_dir} do
      assert_raise ArgumentError, ~r/has no TTF file$/, fn -> Font.read!(tmp_dir) end

      File.cp!("assets/fonts/AtkinsonHyperlegible-Bold.ttf", Path.join(tmp_dir, "Bold.ttf"))

      assert_raise ArgumentError, ~r/has no TTF file with the style Regular/, fn ->
        Font.read!(tmp_dir)
      end
    end
  end

  describe "with Graphviz" do
    @describetag :graphviz

    # A node with a long label, so the width of its box depends on the font.
    @source "test/fixtures/graphviz/label.dot"

    defp width(svg) do
      [points] =
        svg
        |> Floki.parse_fragment!()
        |> Floki.find("g.node polygon")
        |> Floki.attribute("points")

      xs =
        for [x] <- Regex.scan(~r/(-?[\d.]+),/, points, capture: :all_but_first),
            do: x |> Float.parse() |> elem(0)

      Enum.max(xs) - Enum.min(xs)
    end

    test "Graphviz measures the text with the font of the theme, and names the font in the SVG" do
      {svg, _names} = Graphviz.draw!(@source, :dot)
      assert svg =~ ~s(font-family="Atkinson Hyperlegible")

      # Graphviz takes a font of the system for a font that fontconfig does not
      # find, and it writes no warning. Without the files of the theme font,
      # the box would have the width of that fallback font.
      {fallback, 0} =
        System.cmd("dot", ["-Tsvg", "-Nfontname=Expresso No Such Font", @source])

      assert width(svg) != width(fallback)
    end

    test "the render gives the graph the colors of the theme, and colors :tool keeps black" do
      themed = [Builder.diagram(@source)] |> one_slide() |> document() |> screen(".diagram > svg")
      assert count(themed, ~s([stroke="black"])) == 0

      tool =
        [Builder.diagram(@source, colors: :tool)]
        |> one_slide()
        |> document()
        |> screen(".diagram > svg")

      assert count(tool, ~s([stroke="black"])) > 0
    end
  end

  describe "with D2" do
    @describetag :d2

    test "D2 measures the text with the font of the theme" do
      {svg, _names} = D2.draw!("test/fixtures/d2/flow.d2", :elk)

      # The fixture has the font of D2, so the shapes of the theme font differ.
      box = fn svg -> Regex.run(~r/viewBox="([^"]+)"/, svg, capture: :all_but_first) end
      assert box.(svg) != box.(@d2)
    end
  end
end
