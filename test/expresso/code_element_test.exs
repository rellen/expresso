defmodule Expresso.Element.CodeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expresso.Builder
  alias Expresso.Element.{Code, Lines}
  alias Expresso.Overlay

  doctest Expresso.Element.Code

  defmodule CodeDeck do
    use Expresso

    name "code deck"

    slide "elixir" do
      code "elixir" do
        text """
        defmodule Hello do
          def world, do: "world <b>"
        end
        """
      end
    end

    slide "reveal" do
      code "elixir" do
        reveal [1, 2..3]

        text """
        one
        two
        three
        four
        """
      end

      text_box do
        at :next
        text_area(text: "After the code")
      end
    end

    slide "plain" do
      text_box do
        code do
          text "a < b\n\n  c"
        end
      end

      code "json" do
        at from: 2
        text "1"
      end
    end
  end

  defp slide(name) do
    Enum.find(Expresso.parse(CodeDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "Expresso.Builder.code/2" do
    test "makes a code element and its groups of lines" do
      code = Builder.code(text: "a\nb\nc", lang: "elixir", reveal: [1, 2..3])

      assert %Code{lang: "elixir", reveal: [1, 2..3]} = code
      assert [%Lines{numbers: [1]}, %Lines{numbers: [2, 3]}] = code.elements
      assert Enum.all?(code.elements, &(&1.at == Overlay.from_next()))
      assert Builder.code(text: "a").elements == []
    end

    test "takes a line number to the last line, and a text ends with one line break" do
      assert [%Lines{numbers: [2]}] = Builder.code(text: "a\nb", reveal: [2]).elements
      assert [%Lines{numbers: [2]}] = Builder.code(text: "a\nb\n", reveal: [2]).elements

      assert [%Lines{numbers: [1, 2, 3]}] =
               Builder.code(text: "a\nb\n\n", reveal: [1..3]).elements
    end

    test "raises for a line number that the text does not have" do
      message = "code: the reveal option has the line 3, and the code element has 2 lines"

      assert_raise ArgumentError, message, fn -> Builder.code(text: "a\nb\n", reveal: [1, 3]) end
      assert_raise ArgumentError, message, fn -> Builder.code(text: "a\nb", reveal: [2..3]) end

      assert_raise ArgumentError,
                   "code: the reveal option has the line 2, and the code element has 1 line",
                   fn ->
                     Builder.code(text: "a", reveal: [2])
                   end
    end
  end

  describe "reveal/1" do
    test "accepts line numbers and ranges" do
      assert Code.reveal([1, 2..3, 10]) == {:ok, [1, 2..3, 10]}
    end

    test "gives an error for another term" do
      assert {:error, message} = Code.reveal([0])
      assert message =~ "line numbers and ranges"
      assert {:error, _} = Code.reveal([3..1//-1])
      assert {:error, _} = Code.reveal([])
      assert {:error, _} = Code.reveal("1..3")
    end
  end

  describe "the DSL entity" do
    test "takes the language as its first argument and the text option" do
      [code] = slide("elixir").elements

      assert %Code{lang: "elixir", text: "defmodule Hello do\n" <> _, elements: []} = code
    end

    test "makes one group for each item of the reveal option, one step each" do
      [code, box] = slide("reveal").elements

      assert code.steps == nil
      assert Enum.map(code.elements, & &1.numbers) == [[1], [2, 3]]
      assert Enum.map(code.elements, & &1.steps) == [[1, 2, 3], [2, 3]]
      assert box.steps == [3]
    end

    test "takes no language, and goes inside a text box" do
      [%{elements: [code]}, other] = slide("plain").elements

      assert %Code{lang: nil, text: "a < b\n\n  c"} = code
      assert other.steps == [2]
    end

    test "reports a bad reveal option" do
      source = """
      defmodule Expresso.Element.CodeTest.BadReveal do
        use Expresso

        slide do
          code do
            text "x"
            reveal [0]
          end
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Elixir.Code.compile_string(source) end
      assert Exception.message(error) =~ "line numbers and ranges"
    end

    test "reports a reveal option with a line that the text does not have" do
      source = """
      defmodule Expresso.Element.CodeTest.LongReveal do
        use Expresso

        slide do
          code do
            text "one\ntwo\n"
            reveal [1, 2..4]
          end
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Elixir.Code.compile_string(source) end

      assert Exception.message(error) =~
               "the reveal option has the line 3, and the code element has 2 lines"
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: CodeDeck |> document() |> Floki.parse_document!()}
    end

    test "writes a pre element with one span for each line", %{document: document} do
      lines = Floki.find(document, "#slide-1 .code pre code.highlight > span.line")

      assert length(lines) == 3

      assert lines |> Enum.map(&Floki.text/1) == [
               "defmodule Hello do\n",
               "  def world, do: \"world <b>\"\n",
               "end\n"
             ]
    end

    test "highlights the tokens of the language, and escapes the text", %{document: document} do
      [first | _] = Floki.find(document, "#slide-1 .code span.line")

      assert first |> Floki.find("span.kd") |> Floki.text() == "defmodule "
      assert [] = Floki.find(document, "#slide-1 .code b")
    end

    test "writes the overlay attributes of the group on each line", %{document: document} do
      lines = Floki.find(document, "#slide-2 .code span.line")

      assert Enum.map(lines, &Floki.attribute([&1], "data-on")) == [
               ["1 2 3"],
               ["2 3"],
               ["2 3"],
               []
             ]
    end

    test "escapes a line without a language, and puts it in one span", %{document: document} do
      [plain, _json] = Floki.find(document, "#slide-3 .code")
      lines = Floki.find([plain], "span.line")

      assert Enum.map(lines, &Floki.text/1) == ["a < b\n", "\u200B\n", "  c\n"]

      for {"span", _attributes, children} <- lines do
        assert [{"span", [], [_text]}] = children
      end
    end

    test "keeps the white space of each line through the document" do
      html = document(CodeDeck)

      assert html =~ ~s(<span class="kd">defmodule </span>)
      assert html =~ "  c\n</span>"
      assert html =~ ~s(<span class="line"><span>\u200B\n</span></span>)
    end

    test "writes the rules of the token classes into the document", %{document: document} do
      styles = document |> Floki.find("head style") |> Enum.map(&Floki.text/1)

      assert Enum.any?(styles, &(&1 =~ ".highlight .kd"))
    end
  end

  describe "the src option" do
    @src "test/fixtures/code.js"

    test "reads each line of the file, and the first line is line 1" do
      code = Builder.code("js", src: @src)

      assert code.text == @src |> File.read!() |> String.trim_trailing("\n")
      assert code.first == 1
    end

    test "takes the lines of a range, and a reveal names the numbers of the file" do
      code = Builder.code("js", src: @src, lines: 5..11, reveal: [5..7, 9..11], dim: true)

      assert code.text |> String.split("\n") |> hd() == "function add(a, b) {"
      assert code.first == 5
      assert [%Lines{numbers: [5, 6, 7]}, %Lines{numbers: [9, 10, 11]}] = code.elements
    end

    test "writes the overlay attributes of a group on the lines of its numbers" do
      html =
        [
          Builder.slide("one",
            elements: [Builder.code("js", src: @src, lines: 5..7, reveal: [6])]
          )
        ]
        |> Builder.deck()
        |> Expresso.Deck.render()

      lines = html |> Floki.parse_document!() |> Floki.find(".screen span.line")

      assert Enum.map(lines, &Floki.attribute(&1, "data-on")) == [[], ["1"], []]
    end

    test "records the file for the watch mode" do
      {_code, paths} = Expresso.DeckFile.track(fn -> Builder.code("js", src: @src) end)

      assert paths == [@src]
    end

    test "gives an error for text and src, for neither, and for lines without src" do
      assert_raise ArgumentError,
                   "code: a code element takes the text option or the src option, and not both",
                   fn -> Builder.code(text: "a", src: @src) end

      assert_raise ArgumentError,
                   "code: a code element needs the text option or the src option",
                   fn -> Builder.code("js", []) end

      assert_raise ArgumentError,
                   "code: the lines option of a code element needs the src option",
                   fn -> Builder.code(text: "a\nb", lines: 1..2) end
    end

    test "gives an error for a file that it cannot read, and for lines past the end" do
      assert_raise ArgumentError,
                   ~s(code: cannot read the code file "no/such.js": enoent),
                   fn -> Builder.code(src: "no/such.js") end

      assert_raise ArgumentError,
                   ~s(code: the lines option ends at the line 40, and the file "#{@src}" has 12 lines),
                   fn -> Builder.code(src: @src, lines: 10..40) end
    end

    test "gives an error for a reveal number that the element does not show" do
      message =
        "code: the reveal option has the line 4, and the code element shows the lines 5 to 7"

      assert_raise ArgumentError, message, fn ->
        Builder.code(src: @src, lines: 5..7, reveal: [4..5])
      end
    end

    test "the DSL reads the file at compile time" do
      source = """
      defmodule Expresso.Element.CodeTest.SrcDeck do
        use Expresso

        slide "src" do
          code "js" do
            src "test/fixtures/code.js"
            lines 9..11
            reveal [9, 10..11]
          end
        end
      end
      """

      [{module, _bytecode}] = Elixir.Code.compile_string(source)
      [slide] = Expresso.parse(module).slides
      [code] = slide.elements

      assert code.first == 9
      assert code.text =~ "function sum(list)"
      assert slide.metadata.max_step == 2
    end
  end

  describe "lines/1" do
    test "accepts a range from line 1 or more" do
      assert Code.lines(3..8) == {:ok, 3..8}
      assert Code.lines(4..4) == {:ok, 4..4}
    end

    test "gives an error for another term" do
      for value <- [0..3, 5..2//-1, 1..9//2, 3, [1, 2], "1..3"] do
        assert {:error, _message} = Code.lines(value), inspect(value)
      end
    end
  end

  describe "the lines option with texts" do
    @src "test/fixtures/code.js"

    test "takes the lines from the line of the start text to the line of the end text" do
      code = Builder.code("js", src: @src, lines: [from: "function sum(", to: "\n}"])

      assert code.first == 9
      assert code.text == "function sum(list) {\n  return list.reduce(add, 0);\n}"
    end

    test "takes the first end text after the start text, and an end text can start a line" do
      code = Builder.code("js", src: @src, lines: [from: "function add(", to: "}"])

      assert code.first == 5
      assert code.text |> String.split("\n") |> length() == 3
    end

    test "starts at line 1 without from, and ends at the last line without to" do
      assert Builder.code("js", src: @src, lines: [to: "const two"]).text ==
               "// A file for the tests of the src option of the code element.\nconst one = 1;\nconst two = 2;"

      code = Builder.code("js", src: @src, lines: [from: "export"])
      assert code.first == 12
      assert code.text == "export { sum };"
    end

    test "a reveal names the numbers of the file" do
      code =
        Builder.code("js",
          src: @src,
          lines: [from: "function sum(", to: "\n}"],
          reveal: [9, 10..11]
        )

      assert [%Lines{numbers: [9]}, %Lines{numbers: [10, 11]}] = code.elements
    end

    test "raises for a text that is not in the file, a start text in it two times, and no end text after the start" do
      assert_raise ArgumentError,
                   ~r/the start text "def start\(" of the lines option is not in the file/,
                   fn ->
                     Builder.code("js", src: @src, lines: [from: "def start("])
                   end

      assert_raise ArgumentError,
                   ~r/the start text "function" .* 2 times, and it must be in it one time/,
                   fn ->
                     Builder.code("js", src: @src, lines: [from: "function"])
                   end

      assert_raise ArgumentError,
                   ~r/the end text "const one" of the lines option is not in the file .* after the start text/,
                   fn ->
                     Builder.code("js",
                       src: @src,
                       lines: [from: "function sum(", to: "const one"]
                     )
                   end
    end

    test "refuses another key, a key two times and an empty text" do
      for value <- [[from: ""], [at: "x"], [from: "a", from: "b"], [from: 1], []] do
        assert {:error, message} = Code.lines(value), inspect(value)
        assert message =~ "or a start text and an end text"
      end
    end

    test "the compiler gives the same error" do
      source = """
      defmodule Expresso.Element.CodeTest.MissingText do
        use Expresso

        slide "one" do
          code "js" do
            src "test/fixtures/code.js"
            lines from: "def start("
          end
        end
      end
      """

      assert_raise Spark.Error.DslError,
                   ~r/the start text "def start\(" of the lines option/,
                   fn ->
                     Elixir.Code.compile_string(source)
                   end
    end
  end

  describe "the line_numbers option" do
    defp numbered(opts), do: numbered("js", opts)

    defp numbered(lang, opts) do
      code = if lang, do: Builder.code(lang, opts), else: Builder.code(opts)

      [Builder.slide("one", elements: [code])]
      |> Builder.deck()
      |> Expresso.Deck.render()
      |> Floki.parse_document!()
      |> Floki.find(".screen .code")
    end

    test "writes the number of each line from the first line of the range" do
      [code] = numbered(src: "test/fixtures/code.js", lines: 8..11, line_numbers: true)
      numbers = Floki.find(code, "span.line > span.line-number")

      assert Enum.map(numbers, &Floki.text/1) == ["8", "9", "10", "11"]
      assert Enum.all?(numbers, &(Floki.attribute(&1, "aria-hidden") == ["true"]))

      assert code |> Floki.find("code") |> Floki.attribute("style") == [
               "--line-number-width: 2ch"
             ]
    end

    test "numbers a text from 1, and writes no number without the option" do
      [code] = numbered(text: "a\nb", line_numbers: true)
      assert code |> Floki.find(".line-number") |> Enum.map(&Floki.text/1) == ["1", "2"]

      [plain] = numbered(text: "a\nb")
      assert Floki.find(plain, ".line-number") == []
      assert plain |> Floki.find("code") |> Floki.attribute("style") == []
    end

    test "puts the text of a line after its number, with no language and with no lexer" do
      for lang <- [nil, "toml"] do
        {[code], _warning} =
          with_io(:stderr, fn -> numbered(lang, text: "a = 1\n\nb", line_numbers: true) end)

        lines = Floki.find(code, "span.line")

        assert Enum.map(lines, &Floki.text/1) == ["1a = 1\n", "2\u200B\n", "3b\n"],
               inspect(lang)

        for {"span", _attributes, children} <- lines do
          assert [{"span", [{"class", "line-number"} | _], _number}, {"span", [], [_text]}] =
                   children
        end
      end
    end
  end

  describe "the highlight option" do
    defp highlight_deck(code) do
      [Builder.slide("one", elements: [code])]
      |> Builder.deck()
    end

    test "makes one group with an on entity for each item, and one group of the other lines" do
      code = Builder.code(text: "a\nb\nc\nd\ne", highlight: [2, 3..4])

      assert [
               %Lines{numbers: [2], on: [%Expresso.Element.On{state: :highlight}]},
               %Lines{numbers: [3, 4], on: [%Expresso.Element.On{state: :highlight}]},
               %Lines{numbers: [1, 5], on: []}
             ] = code.elements

      assert Enum.all?(code.elements, &(&1.at == nil))
    end

    test "gives each group one step, and each line shows at each step" do
      [slide] = highlight_deck(Builder.code(text: "a\nb\nc", highlight: [1, 2..3])).slides
      [code] = slide.elements

      assert slide.metadata.max_step == 2
      assert Enum.map(code.elements, & &1.steps) == [nil, nil]
      assert [[1], [2]] = Enum.map(code.elements, fn %Lines{on: [on]} -> on.steps end)
    end

    test "whole_first gives one step with no group in focus before the first group" do
      [slide] =
        highlight_deck(Builder.code(text: "a\nb\nc", highlight: [1, 2..3], whole_first: true)).slides

      [code] = slide.elements

      assert slide.metadata.max_step == 3
      assert [[2], [3]] = Enum.map(code.elements, fn %Lines{on: [on]} -> on.steps end)
    end

    test "whole_first gives the steps of a pause in front of the code element" do
      text = "a\nb\nc\nd"
      whole = Builder.code(text: text, highlight: [1, 2..3], whole_first: true)
      paused = Builder.code(text: text, highlight: [1, 2..3])

      steps = fn elements ->
        [slide] = Builder.deck([Builder.slide("one", elements: elements)]).slides
        code = List.last(slide.elements)

        {slide.metadata.max_step,
         Enum.map(code.elements, &Enum.map(&1.on, fn on -> on.steps end))}
      end

      assert steps.([whole]) == steps.([Builder.pause(), paused])
    end

    test "whole_first needs the highlight option" do
      assert_raise ArgumentError,
                   ~r/the whole_first option of a code element needs the highlight option/,
                   fn ->
                     Builder.code(text: "a", whole_first: true)
                   end
    end

    test "dims each other line at the step of a group" do
      deck = highlight_deck(Builder.code(text: "a\nb\nc\nd", highlight: [2, 3]))
      [%{elements: [code]}] = Code.spotlight(deck).slides

      states =
        Enum.map(code.elements, fn group ->
          {group.numbers, Enum.map(group.on, &{&1.state, &1.steps})}
        end)

      assert states == [
               {[2], [{:highlight, [1]}, {:dim, [2]}]},
               {[3], [{:highlight, [2]}, {:dim, [1]}]},
               {[1, 4], [{:dim, [1, 2]}]}
             ]
    end

    test "writes the rules of the focus and of the dim into the style block" do
      html = deck_html(Builder.code(text: "a\nb\nc", highlight: [1, 2]))

      assert html =~ ~s(section[data-step="1"] [data-el="s1-e2"] { --highlight: 1; })
      assert html =~ ~s(section[data-step="2"] [data-el="s1-e2"] { --dim: 1; --dimmed: 1; })

      assert html =~
               ~s(section[data-step="1"] [data-el="s1-e4"], section[data-step="2"] [data-el="s1-e4"] { --dim: 1; --dimmed: 1; })
    end

    test "uses the numbers of the file with src" do
      code = Builder.code("js", src: "test/fixtures/code.js", lines: 5..11, highlight: [9..11])

      assert [%Lines{numbers: [9, 10, 11]}, %Lines{numbers: [5, 6, 7, 8]}] = code.elements
    end

    test "starts after the step of a pause" do
      [slide] =
        [
          Builder.slide("one",
            elements: [Builder.pause(), Builder.code(text: "a\nb", highlight: [1, 2])]
          )
        ]
        |> Builder.deck()
        |> Map.get(:slides)

      code = Enum.find(slide.elements, &match?(%Code{}, &1))
      assert slide.metadata.max_step == 3

      assert [[2], [3]] =
               Enum.map(Enum.take(code.elements, 2), fn %Lines{on: [on]} -> on.steps end)
    end

    test "gives an error for reveal and highlight, for dim, for a line it does not show, and for a line in two groups" do
      assert_raise ArgumentError,
                   "code: a code element takes the reveal option or the highlight option, and not both",
                   fn -> Builder.code(text: "a\nb", reveal: [1], highlight: [2]) end

      assert_raise ArgumentError, ~r/the highlight option dims the other lines itself/, fn ->
        Builder.code(text: "a\nb", highlight: [1], dim: true)
      end

      assert_raise ArgumentError,
                   "code: the highlight option has the line 3, and the code element has 2 lines",
                   fn -> Builder.code(text: "a\nb", highlight: [3]) end

      assert_raise ArgumentError,
                   "code: the line 2 is in two groups of the highlight option",
                   fn -> Builder.code(text: "a\nb\nc", highlight: [1..2, 2..3]) end
    end
  end

  defp deck_html(code) do
    [Builder.slide("one", elements: [code])]
    |> Builder.deck()
    |> Expresso.Deck.render()
  end
end
