defmodule Expresso.Lexers.Org do
  @moduledoc """
  The Makeup lexer of Org mode

  A heading, such as `** TODO Write the talk`, is a heading, and its state,
  such as `TODO` or `DONE`, is a keyword. A keyword line, such as
  `#+TITLE:` or `#+begin_src elixir`, is a preprocessor comment. Markup on a
  line, such as `*bold*`, `/italic/`, `=verbatim=` and `~code~`, gets its
  style, and a link such as `[[https://example.com][the site]]` is a string.
  """

  use Expresso.Lexer, language: :org

  heading =
    ascii_string([?*], min: 1)
    |> string(" ")
    |> lexeme()
    |> token(:generic_heading)
    |> optional(choice([string("TODO"), string("DONE")]) |> token(:keyword))
    |> concat(rest_of_line() |> lexeme() |> token(:generic_heading))

  keyword_line = string("#+") |> concat(rest_of_line()) |> lexeme() |> token(:comment_preproc)

  comment =
    string("#")
    |> lookahead(choice([string(" "), string("\n"), eos()]))
    |> concat(rest_of_line())
    |> lexeme()
    |> token(:comment_single)

  drawer =
    string(":")
    |> ascii_string([?A..?Z, ?a..?z, ?_, ?-], min: 1)
    |> string(":")
    |> lexeme()
    |> token(:name_attribute)

  bullet =
    choice([
      string("- "),
      string("+ "),
      ascii_string([?0..?9], min: 1) |> ascii_string([?., ?)], 1) |> string(" ")
    ])
    |> lexeme()
    |> token(:keyword)

  link =
    string("[[")
    |> repeat(lookahead_not(string("]]")) |> utf8_string([not: ?\n], 1))
    |> string("]]")
    |> lexeme()
    |> token(:string_other)

  timestamp =
    ascii_string([?<, ?[], 1)
    |> ascii_string([?0..?9], 4)
    |> string("-")
    |> ascii_string([?0..?9, ?-, ?\s, ?:, ?A..?Z, ?a..?z, ?+], min: 1)
    |> ascii_string([?>, ?]], 1)
    |> lexeme()
    |> token(:literal_date)

  deflexer(
    [
      line_start(heading, indent: false),
      line_start(keyword_line),
      line_start(comment),
      line_start(drawer),
      line_start(bullet),
      whitespace(),
      link,
      timestamp,
      inline("*", "*", :generic_strong),
      inline("/", "/", :generic_emph),
      inline("=", "=", :string_backtick),
      inline("~", "~", :string_backtick),
      word([?a..?z, ?A..?Z, ?0..?9], [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?']),
      punctuation(~c"|")
    ],
    %{}
  )
end
