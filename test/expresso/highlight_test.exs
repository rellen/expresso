defmodule Expresso.HighlightTest do
  use ExUnit.Case, async: true

  # The text of each line, with no HTML.
  defp texts(text, language) do
    text
    |> Expresso.Highlight.lines(language)
    |> Enum.map(fn html -> html |> Floki.parse_fragment!() |> Floki.text() end)
  end

  test "keeps the order of the tokens of the last line" do
    assert texts("x = 1\n|> IO.puts()", "elixir") == ["x = 1\n", "|> IO.puts()\n"]
  end

  test "keeps the order of the tokens of a text of one line" do
    assert texts("Greeter.greet(\"world\")", "elixir") == ["Greeter.greet(\"world\")\n"]
  end

  test "gives the same number of lines with a lexer and without one" do
    for text <- ["a\nb c", "a\n", "", "\n\nd(e)"] do
      assert length(texts(text, "elixir")) == length(texts(text, nil)), inspect(text)
    end
  end
end
