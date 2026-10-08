defmodule Expresso.Lexers.Toml do
  @moduledoc """
  The Makeup lexer of TOML

  A key before `=` is an attribute. A table header at the start of a line,
  such as `[server]` or `[[servers]]`, is a namespace, so it gets the color
  of a keyword. A date and a time, such as `1979-05-27T07:32:00Z`, are a
  date.
  """

  use Expresso.Lexer, language: :toml

  key_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-]

  header =
    choice([string("[["), string("[")])
    |> utf8_string([not: ?], not: ?\n], min: 1)
    |> choice([string("]]"), string("]")])
    |> lexeme()
    |> token(:keyword_namespace)

  date =
    ascii_string([?0..?9], 4)
    |> string("-")
    |> ascii_string([?0..?9], 2)
    |> string("-")
    |> ascii_string([?0..?9], 2)
    |> optional(ascii_string([?0..?9, ?T, ?t, ?\s, ?:, ?., ?Z, ?z, ?+, ?-], min: 1))
    |> lexeme()
    |> token(:literal_date)

  time =
    ascii_string([?0..?9], 2)
    |> string(":")
    |> ascii_string([?0..?9], 2)
    |> string(":")
    |> ascii_string([?0..?9], 2)
    |> optional(ascii_string([?0..?9, ?.], min: 1))
    |> lexeme()
    |> token(:literal_date)

  deflexer(
    [
      line_start(header),
      whitespace(),
      line_comment("#"),
      delimited(~s("""), ~s("""), :string_heredoc, escape: "\\"),
      delimited("'''", "'''", :string_heredoc),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("'", "'", :string_single),
      key(key_chars, key_chars, ["="]),
      date,
      time,
      word([?a..?z, ?A..?Z], key_chars),
      number(),
      operators(["=", "+", "-", "."]),
      punctuation(~c"[]{},")
    ],
    words(["true", "false", "inf", "nan"], :keyword_constant)
  )
end
