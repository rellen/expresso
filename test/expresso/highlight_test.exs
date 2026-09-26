defmodule Expresso.HighlightTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @languages [nil, "elixir", "erlang", "gleam", "heex", "html", "css", "js", "ts", "json"] ++
               ["sql", "c", "rust", "diff"]

  @zero_width_space "​"

  @tokens [
    "def",
    "end",
    "fn",
    "->",
    "|>",
    "=",
    "(",
    ")",
    "{",
    "}",
    "[",
    "]",
    "<div>",
    "</div>",
    "\"text\"",
    "'c'",
    "\#{x}",
    "%{a: 1}",
    "// note",
    "# note",
    "-- note",
    "/* x */",
    "1.5e3",
    "@spec",
    ":atom",
    "&amp;",
    "<",
    ">",
    "&",
    "+ added",
    "- removed",
    "\\"
  ]

  defp texts(text, language) do
    text
    |> Expresso.Highlight.lines(language)
    |> Enum.map(fn html -> html |> Floki.parse_fragment!() |> Floki.text() end)
  end

  defp line do
    [
      {4, member_of(@tokens)},
      {3, string(:ascii, max_length: 6)},
      {1, string(:printable, max_length: 3)},
      {2, member_of([" ", "  ", "\t"])}
    ]
    |> frequency()
    |> list_of(max_length: 8)
    |> map(&Enum.join/1)
    |> filter(&(not String.contains?(&1, ["\n", "\r", @zero_width_space])))
  end

  defp source, do: map(list_of(line(), max_length: 5), &Enum.join(&1, "\n"))

  property "keeps the text of each line, in order, for each language" do
    check all text <- source(), language <- member_of(@languages), max_runs: 300 do
      expected = text |> String.split("\n") |> Enum.map(&(&1 <> "\n"))
      shown = text |> texts(language) |> Enum.map(&String.replace(&1, @zero_width_space, ""))

      assert shown == expected
    end
  end

  test "keeps a comment of SQL, which the lexer gives as nested tokens" do
    assert texts("SELECT 1 /* x */", "sql") == ["SELECT 1 /* x */\n"]
  end

  test "keeps the order of the tokens of the last line" do
    assert texts("x = 1\n|> IO.puts()", "elixir") == ["x = 1\n", "|> IO.puts()\n"]
  end
end
