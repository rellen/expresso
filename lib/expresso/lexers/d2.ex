defmodule Expresso.Lexers.D2 do
  @moduledoc """
  The Makeup lexer of D2, the diagram language

  A reserved key, such as `shape`, `label` or `style.fill`, is a keyword,
  and another key before `:` is a tag. A connection, such as `->` or `<->`,
  is an operator. A block string, such as `|md # Title|`, is a string.
  """

  use Expresso.Lexer, language: :d2

  first = [?a..?z, ?A..?Z, ?_]
  rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?\s]
  word_rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-]

  reserved =
    ~w(shape label style icon near width height direction tooltip link constraint vars classes class
       layers scenarios steps grid-rows grid-columns grid-gap vertical-gap horizontal-gap
       source-arrowhead target-arrowhead filled multiple opacity fill fill-pattern stroke
       stroke-width stroke-dash border-radius shadow 3d font font-size font-color animated bold
       italic underline text-transform double-border top left content-aspect-ratio)

  reserved_key =
    reserved
    |> Enum.sort_by(&byte_size/1, :desc)
    |> Enum.map(&string/1)
    |> choice()
    |> lookahead(ascii_string([?:, ?., ?\s, ?{], 1))
    |> token(:keyword)

  block_string =
    string("|")
    |> optional(ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1))
    |> repeat(lookahead_not(string("|")) |> utf8_string([], 1))
    |> optional(string("|"))
    |> lexeme()
    |> token(:string_heredoc)

  substitution =
    string("${")
    |> utf8_string([not: ?}, not: ?\n], min: 1)
    |> string("}")
    |> lexeme()
    |> token(:name_variable)

  deflexer(
    [
      whitespace(),
      delimited(~s("""), ~s("""), :comment_multiline),
      line_comment("#"),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("'", "'", :string_single),
      block_string,
      substitution,
      reserved_key,
      key(first, rest, [":"], :name_tag),
      number(),
      word(first, word_rest),
      operators(~w(<-> -> <- -- ... @ & * . :)),
      punctuation(~c"{};()[]")
    ],
    words(~w(true false null), :keyword_constant)
  )
end
