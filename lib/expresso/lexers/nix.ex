defmodule Expresso.Lexers.Nix do
  @moduledoc """
  The Makeup lexer of the Nix language

  An attribute before `=` is an attribute, and a path such as
  `./default.nix` or `<nixpkgs>`, or an address, is a string. An
  interpolation `${...}` stays in its string.
  """

  use Expresso.Lexer, language: :nix

  first = [?a..?z, ?A..?Z, ?_]
  rest = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?']
  path_chars = [?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?/, ?+]

  path =
    choice([string("./"), string("../"), string("~/"), string("/")])
    |> ascii_string(path_chars, min: 1)
    |> lexeme()
    |> token(:string_other)

  search_path =
    string("<")
    |> ascii_string(path_chars, min: 1)
    |> string(">")
    |> lexeme()
    |> token(:string_other)

  url =
    ascii_string([?a..?z], min: 2)
    |> string("://")
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?., ?/, ?:, ??, ?=, ?&, ?%, ?~, ?+, ?#],
      min: 1
    )
    |> lexeme()
    |> token(:string_other)

  deflexer(
    [
      whitespace(),
      line_comment("#"),
      delimited("/*", "*/", :comment_multiline),
      delimited(~s("), ~s("), :string_double, escape: "\\"),
      delimited("''", "''", :string_heredoc),
      url,
      path,
      search_path,
      key(first, rest, ["="], :name_attribute, not: [?=]),
      number(),
      word(first, rest),
      operators(~w(== != <= >= && || -> // ++ ... + - * / ! ? @ : = . < >)),
      punctuation(~c"{}[]();,")
    ],
    Map.merge(
      words(~w(let in with rec inherit if then else assert or), :keyword),
      Map.merge(
        words(~w(true false null), :keyword_constant),
        words(
          ~w(import builtins map toString throw abort baseNameOf dirOf derivation fetchTarball isNull removeAttrs),
          :name_builtin
        )
      )
    )
  )
end
