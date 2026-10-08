defmodule Expresso.Lexers.Yaml do
  @moduledoc """
  The Makeup lexer of YAML

  A key before `: ` is a tag, an anchor such as `&base` and an alias such as
  `*base` are a label, and a tag such as `!!str` is a type. A marker of a
  document, `---` or `...`, is a keyword. The lines of a block scalar after
  `|` or `>` are plain text.
  """

  use Expresso.Lexer, language: :yaml

  key_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/, ?\s]
  word_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/]

  marker = choice([string("---"), string("...")]) |> token(:keyword)

  anchor =
    ascii_string([?&, ?*], 1)
    |> ascii_string(word_chars, min: 1)
    |> lexeme()
    |> token(:name_label)

  tag =
    string("!")
    |> optional(ascii_string([?!, ?a..?z, ?A..?Z, ?0..?9, ?-, ?:, ?/, ?.], min: 1))
    |> lexeme()
    |> token(:keyword_type)

  block =
    ascii_string([?|, ?>], 1)
    |> optional(ascii_string([?-, ?+, ?0..?9], min: 1))
    |> lexeme()
    |> token(:operator)

  constants =
    for word <- ~w(true false yes no on off null),
        form <- [word, String.capitalize(word), String.upcase(word)],
        into: %{"~" => :keyword_constant},
        do: {form, :keyword_constant}

  deflexer(
    [
      line_start(marker),
      whitespace(),
      line_comment("#"),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("'", "'", :string_single),
      key([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/, ?<], key_chars ++ [?<], [":"], :name_tag,
        then: [?\s, ?\t, ?\r, ?\n]
      ),
      anchor,
      tag,
      block,
      number(),
      word([?a..?z, ?A..?Z, ?_, ?~], word_chars),
      punctuation(~c"-:,?[]{}")
    ],
    constants
  )
end
