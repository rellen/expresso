defmodule Expresso.Lexers.Dhall do
  @moduledoc """
  The Makeup lexer of Dhall

  A field before `=` or `:` is an attribute, a built-in type such as
  `Natural` is a type, and a built-in function such as `List/length` is a
  built-in. An import, such as `./types.dhall`, `env:HOME` or an address, is
  a string.
  """

  use Expresso.Lexer, language: :dhall

  first = [?a..?z, ?A..?Z, ?_]
  rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?/]
  path_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/]

  import =
    choice([
      ascii_string([?a..?z], min: 4)
      |> string("://")
      |> ascii_string(path_chars ++ [?:, ??, ?=, ?&, ?%, ?~, ?+, ?#], min: 1),
      choice([string("./"), string("../"), string("~/"), string("/")])
      |> ascii_string(path_chars, min: 1),
      string("env:") |> ascii_string([?A..?Z, ?a..?z, ?0..?9, ?_], min: 1)
    ])
    |> lexeme()
    |> token(:string_other)

  builtins =
    ~w(Some Natural/fold Natural/build Natural/isZero Natural/even Natural/odd Natural/toInteger
       Natural/show Natural/subtract Integer/toDouble Integer/show Integer/negate Integer/clamp
       Double/show List/build List/fold List/length List/head List/last List/indexed List/reverse
       Text/show Text/replace Date/show Time/show TimeZone/show)

  deflexer(
    [
      whitespace(),
      line_comment("--"),
      delimited("{-", "-}", :comment_multiline),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("''", "''", :string_heredoc),
      import,
      key(first, rest, ["=", ":"], :name_attribute, not: [?=, ?:]),
      number(),
      word(first, rest),
      operators(~w(λ → ∀ ⩓ ≡ ⫽ ∧ \\ -> // /\\ //\\\\ === == != && || ++ # + * : = ? :: <)),
      punctuation(~c"{}[](),.|>")
    ],
    Map.merge(
      words(
        ~w(let in if then else merge with forall as using missing assert toMap showConstructor),
        :keyword
      ),
      Map.merge(
        Map.merge(
          words(~w(True False None), :keyword_constant),
          words(
            ~w(Natural Integer Double Text Bool List Optional Type Kind Sort Date Time TimeZone Bytes),
            :keyword_type
          )
        ),
        words(builtins, :name_builtin)
      )
    ),
    [:name, :name_attribute]
  )
end
