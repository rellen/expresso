defmodule Expresso.CodeLongLinesTest do
  use ExUnit.Case, async: true

  alias Expresso.{Builder, Highlight}

  defp code(opts) do
    [Builder.slide("s", elements: [Builder.code("js", opts)])]
    |> Builder.deck(name: "code")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen .code")
  end

  defp texts(code), do: code |> Floki.find(".line") |> Enum.map(&Floki.text/1)

  describe "trailing_comments false" do
    test "removes a comment at the end of a line of code, and the space before it" do
      lines =
        Highlight.lines("let a = 1; // one\n// only a comment", "js", trailing_comments: false)

      assert Enum.map(lines, &(&1 |> Floki.parse_fragment!() |> Floki.text())) ==
               ["let a = 1;\n", "// only a comment\n"]
    end

    test "keeps each comment by default" do
      assert [line] = Highlight.lines("let a = 1; // one", "js")
      assert line =~ "// one"
    end

    test "keeps the comments of a code with no lexer" do
      assert [line] = Highlight.lines("a = 1 # one", nil, trailing_comments: false)
      assert line =~ "# one"
    end

    test "the code element takes it" do
      [code] = code(text: "let a = 1; // one\nlet b = 2;", trailing_comments: false)
      assert texts(code) == ["let a = 1;\n", "let b = 2;\n"]
    end
  end

  describe "wrap true" do
    test "gives the element the class code-wrap, and each line its indent" do
      [code] = code(text: "if (a) {\n  b();\n\tc();\n}", wrap: true)

      assert "code code-wrap" in Floki.attribute(code, "class")

      assert code |> Floki.find(".line") |> Enum.map(&hd(Floki.attribute(&1, "style"))) ==
               ["--indent: 0ch", "--indent: 2ch", "--indent: 8ch", "--indent: 0ch"]
    end

    test "is off by default" do
      [code] = code(text: "a")
      assert Floki.attribute(code, "class") == ["code"]
      assert code |> Floki.find(".line") |> Floki.attribute("style") == []
    end
  end
end
