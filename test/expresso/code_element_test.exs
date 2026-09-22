defmodule Expresso.Element.CodeTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Code, Lines}
  alias Expresso.Overlay

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

      code "no-such-language" do
        at from: 2
        text "x"
      end
    end
  end

  defp slide(name) do
    Enum.find(Expresso.parse(CodeDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/2" do
    test "makes a code element and its groups of lines" do
      code = Code.new("a\nb\nc", lang: "elixir", reveal: [1, 2..3])

      assert %Code{lang: "elixir", reveal: [1, 2..3]} = code
      assert [%Lines{numbers: [1]}, %Lines{numbers: [2, 3]}] = code.elements
      assert Enum.all?(code.elements, &(&1.at == Overlay.from_next()))
      assert Code.new("a").elements == []
    end

    test "takes a line number to the last line, and a text ends with one line break" do
      assert [%Lines{numbers: [2]}] = Code.new("a\nb", reveal: [2]).elements
      assert [%Lines{numbers: [2]}] = Code.new("a\nb\n", reveal: [2]).elements
      assert [%Lines{numbers: [1, 2, 3]}] = Code.new("a\nb\n\n", reveal: [1..3]).elements
    end

    test "raises for a line number that the text does not have" do
      message = "the reveal option has the line 3, and the code element has 2 lines"

      assert_raise ArgumentError, message, fn -> Code.new("a\nb\n", reveal: [1, 3]) end
      assert_raise ArgumentError, message, fn -> Code.new("a\nb", reveal: [2..3]) end

      assert_raise ArgumentError,
                   "the reveal option has the line 2, and the code element has 1 line",
                   fn ->
                     Code.new("a", reveal: [2])
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

    test "escapes a line without a language, and without a lexer", %{document: document} do
      [plain, unknown] = Floki.find(document, "#slide-3 .code")

      assert plain |> Floki.find("span.line") |> Enum.map(&Floki.text/1) ==
               ["a < b\n", "\u200B\n", "  c\n"]

      assert [] = Floki.find([plain], "span.line span")
      assert Floki.attribute([unknown], "data-on") == ["2"]
    end

    test "keeps the white space of each line through the document" do
      html = document(CodeDeck)

      assert html =~ ~s(<span class="kd">defmodule </span>)
      assert html =~ "  c\n</span>"
      assert html =~ ~s(<span class="line">\u200B\n</span>)
    end

    test "writes the rules of the token classes into the document", %{document: document} do
      styles = document |> Floki.find("head style") |> Enum.map(&Floki.text/1)

      assert Enum.any?(styles, &(&1 =~ ".highlight .kd"))
    end
  end
end
