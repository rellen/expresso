defmodule Expresso.Lexer do
  @moduledoc """
  The tools of the Makeup lexers of Expresso

  Hex has a Makeup lexer for some languages only, and `Expresso.Highlight`
  registers the lexers of `Expresso.Lexers` for more. A slide needs clear
  colors and not a full parser, so each lexer of Expresso is a short list of
  rules. A rule is a NimbleParsec combinator that makes one token, such as a
  comment, a string or a word.

  A lexer module writes `use Expresso.Lexer, language: :toml`, makes its rules
  with the functions of this module, and calls `deflexer/2` with the rules and
  a table of words:

      defmodule Expresso.Lexers.Example do
        use Expresso.Lexer, language: :example

        deflexer(
          [whitespace(), line_comment("#"), delimited("\\"", "\\"", :string_double), word()],
          %{"true" => :keyword_constant}
        )
      end

  `deflexer/2` adds a last rule that takes any one character, so a lexer
  always reads the whole text. A rule of `line_start/1` matches only at the
  start of a line, such as a table header of TOML. The table gives the token type of a word, such
  as `:keyword` for `"let"`. A word that is not in the table keeps the type
  `:name`. `Expresso.Highlight` gives each token type a role of the theme.
  """

  import NimbleParsec
  import Makeup.Lexer.Combinators

  @typedoc "A NimbleParsec combinator"
  @type combinator :: NimbleParsec.t()

  @doc false
  defmacro __using__(opts) do
    language = Keyword.fetch!(opts, :language)

    quote do
      import NimbleParsec
      import Makeup.Lexer.Combinators, only: [token: 2, lexeme: 1]
      import Expresso.Lexer

      @behaviour Makeup.Lexer
      @language unquote(language)
    end
  end

  @doc """
  Define the callbacks of `Makeup.Lexer` from the rules and the table of words

  The rules come first, in order, and a rule for any one character comes
  last. Each token gets the language in its metadata. The table applies to
  the tokens of the types in `types`, by default `[:name]`.
  """
  defmacro deflexer(rules, words, types \\ [:name]) do
    quote do
      @words unquote(words)
      @word_types unquote(types)

      @impl Makeup.Lexer
      defparsec(
        :root_element,
        choice(unquote(rules) ++ [Expresso.Lexer.character()])
        |> map({Expresso.Lexer, :__language__, [@language]})
      )

      @impl Makeup.Lexer
      defparsec(:root, repeat(parsec(:root_element)))

      @impl Makeup.Lexer
      def postprocess(tokens, _opts),
        do: Expresso.Lexer.classify(tokens, @words, @word_types)

      @impl Makeup.Lexer
      def match_groups(tokens, _prefix), do: tokens

      @impl Makeup.Lexer
      def lex(text, opts \\ []) do
        {:ok, [{:whitespace, _meta, "\n"} | tokens], "", _context, _line, _offset} =
          root("\n" <> text)

        tokens |> postprocess(opts) |> match_groups(opts[:group_prefix])
      end
    end
  end

  @doc false
  def __language__({type, meta, value}, language),
    do: {type, Map.put(meta, :language, language), value}

  @doc """
  Give each word of the table its token type

  The function looks for each token of the types in `types` in the table. A
  token that is not in the table keeps its type.
  """
  @spec classify([Makeup.Lexer.Types.token()], %{String.t() => atom()}, [atom()]) ::
          [Makeup.Lexer.Types.token()]
  def classify(tokens, words, types \\ [:name]) do
    Enum.map(tokens, fn {type, meta, value} = token ->
      with true <- type in types, {:ok, new_type} <- Map.fetch(words, value) do
        {new_type, meta, value}
      else
        _not_a_word -> token
      end
    end)
  end

  @spaces [?\s, ?\t, ?\f]

  @doc """
  A rule for white space: one line break, or spaces and tabs

  Each line break is a token of its own, so a rule of `line_start/1` can
  start at each line break.
  """
  @spec whitespace() :: combinator()
  def whitespace,
    do: one_of([line_break(), ascii_string(@spaces, min: 1)]) |> token(:whitespace)

  defp line_break, do: one_of([string("\r\n"), string("\n")])

  @doc """
  A rule that matches only at the start of a line, after its indentation

  The rule starts with the line break before the line, and `lex/2` puts a
  line break before the text, so the first line has one too. The line break
  and the indentation become tokens of white space. Put such a rule before
  `whitespace/0`. With `indent: false`, the rule matches only at the first
  column, such as a definition at the top level of Haskell.
  """
  @spec line_start(combinator(), keyword()) :: combinator()
  def line_start(combinator, opts \\ []) do
    indentation =
      if Keyword.get(opts, :indent, true),
        do: optional(ascii_string(@spaces, min: 1) |> token(:whitespace)),
        else: empty()

    line_break()
    |> token(:whitespace)
    |> concat(indentation)
    |> concat(combinator)
  end

  @doc "A rule for any one character, the last rule of each lexer"
  @spec character() :: combinator()
  def character, do: utf8_string([], 1) |> token(:text)

  @doc "The text up to the end of the line, without the line break"
  @spec rest_of_line() :: combinator()
  def rest_of_line, do: optional(utf8_string([not: ?\n], min: 1))

  @doc """
  A rule for a comment from a prefix, such as `"#"`, to the end of the line
  """
  @spec line_comment(String.t(), atom()) :: combinator()
  def line_comment(prefix, type \\ :comment_single),
    do: string(prefix) |> concat(rest_of_line()) |> lexeme() |> token(type)

  @doc """
  A rule for a text from `open` to `close`, such as a comment or a string

  The text can have line breaks. With `escape: "\\\\"`, the escape and the
  character after it do not close the text. A text with no `close` goes to
  the end of the source.
  """
  @spec delimited(String.t(), String.t(), atom(), keyword()) :: combinator()
  def delimited(open, close, type, opts \\ []) do
    inside =
      case Keyword.get(opts, :escape) do
        nil ->
          lookahead_not(string(close)) |> utf8_string([], 1)

        escape ->
          choice([
            string(escape) |> utf8_string([], 1),
            lookahead_not(string(close)) |> utf8_string([], 1)
          ])
      end

    string(open)
    |> repeat(inside)
    |> optional(string(close))
    |> lexeme()
    |> token(type)
  end

  # The characters of a word. A word starts with a letter or `_`.
  @first [?a..?z, ?A..?Z, ?_]
  @rest [?a..?z, ?A..?Z, ?0..?9, ?_]

  @doc """
  A rule for a word, a token of the type `:name`

  `first` and `rest` give the characters of the first character and of the
  other characters. `deflexer/2` then looks for the word in the table.
  """
  @spec word(list(), list(), atom()) :: combinator()
  def word(first \\ @first, rest \\ @rest, type \\ :name),
    do: utf8_string(first, 1) |> optional(utf8_string(rest, min: 1)) |> lexeme() |> token(type)

  @doc """
  A rule for the key of a field: a word before a separator, such as `=` or `:`

  The rule does not take the separator. White space can come between the word
  and the separator. With `then: [?\\s, ?\\n]`, one of these characters, or the
  end of the text, must come after the separator. With `not: [?=]`, none of
  these characters can come after it, so the key of `a = 1` does not match
  `a == 1`.
  """
  @spec key(list(), list(), [String.t()], atom(), keyword()) :: combinator()
  def key(first, rest, separators, type \\ :name_attribute, opts \\ []) do
    after_separator =
      case Keyword.get(opts, :then) do
        nil -> empty()
        chars -> choice([ascii_char(chars), eos()])
      end

    after_separator =
      case Keyword.get(opts, :not) do
        nil -> after_separator
        chars -> lookahead_not(after_separator, ascii_char(chars))
      end

    utf8_string(first, 1)
    |> optional(utf8_string(rest, min: 1))
    |> lookahead(
      optional(ascii_string([?\s, ?\t], min: 1))
      |> concat(one_of(Enum.map(separators, &string/1)))
      |> concat(after_separator)
    )
    |> lexeme()
    |> token(type)
  end

  @digits [?0..?9, ?_]

  @doc """
  A rule for a number: an integer, a decimal number with an exponent, or a
  hexadecimal, octal or binary integer with a prefix

  An underscore can separate the digits.
  """
  @spec number() :: combinator()
  def number do
    prefixed = fn prefix, digits ->
      string(prefix) |> ascii_string(digits, min: 1) |> lexeme() |> token(:number_integer)
    end

    exponent =
      ascii_char([?e, ?E]) |> optional(ascii_char([?+, ?-])) |> ascii_string(@digits, min: 1)

    decimal =
      ascii_string([?0..?9], 1)
      |> optional(ascii_string(@digits, min: 1))
      |> optional(
        string(".")
        |> ascii_string([?0..?9], 1)
        |> optional(ascii_string(@digits, min: 1))
      )
      |> optional(exponent)
      |> lexeme()
      |> token(:number)

    choice([
      prefixed.("0x", [?0..?9, ?a..?f, ?A..?F, ?_]),
      prefixed.("0o", [?0..?7, ?_]),
      prefixed.("0b", [?0, ?1, ?_]),
      decimal
    ])
  end

  @doc """
  A rule for an operator from a list, such as `["->", "=", "+"]`

  The rule tries the longest operator first.
  """
  @spec operators([String.t()], atom()) :: combinator()
  def operators(list, type \\ :operator) do
    list
    |> Enum.sort_by(&byte_size/1, :desc)
    |> Enum.map(&string/1)
    |> one_of()
    |> token(type)
  end

  @doc """
  A combinator that takes the first of the combinators that matches

  NimbleParsec's `choice/1` needs two combinators or more, and this function
  also takes one.
  """
  @spec one_of([combinator()]) :: combinator()
  def one_of([combinator]), do: combinator
  def one_of(combinators), do: choice(combinators)

  @doc "A rule for one punctuation character, such as `{` or `,`"
  @spec punctuation(charlist()) :: combinator()
  def punctuation(chars), do: ascii_string(chars, 1) |> token(:punctuation)

  @doc """
  A table that gives one token type to each word of a list

      iex> Expresso.Lexer.words(["let", "in"], :keyword)
      %{"in" => :keyword, "let" => :keyword}
  """
  @spec words([String.t()], atom()) :: %{String.t() => atom()}
  def words(list, type), do: Map.new(list, &{&1, type})
end
