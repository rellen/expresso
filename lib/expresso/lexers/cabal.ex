defmodule Expresso.Lexers.Cabal do
  @moduledoc """
  The Makeup lexer of a Cabal package file

  A field before `:` is an attribute, and the word of a section, such as
  `library` or `executable`, is a keyword. A comment starts a line with
  `--`. A version, such as `4.18.1`, is a number.
  """

  use Expresso.Lexer, language: :cabal

  field_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-]
  rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?.]

  version =
    ascii_string([?0..?9], min: 1)
    |> times(string(".") |> ascii_string([?0..?9, ?*], min: 1), min: 1)
    |> lexeme()
    |> token(:number)

  deflexer(
    [
      line_start(line_comment("--")),
      whitespace(),
      key(field_chars, field_chars, [":"], :name_attribute),
      version,
      number(),
      word([?a..?z, ?A..?Z, ?_], rest),
      operators(~w(^>= >= <= == && || < > ! : ,)),
      punctuation(~c"(){}")
    ],
    Map.merge(
      words(
        ~w(library executable test-suite benchmark foreign-library common flag source-repository custom-setup if elif else),
        :keyword
      ),
      Map.merge(
        words(~w(os arch impl flag), :name_builtin),
        words(~w(True False true false), :keyword_constant)
      )
    )
  )
end
