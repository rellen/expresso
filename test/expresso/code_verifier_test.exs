defmodule Expresso.CodeVerifierTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expresso.Builder
  alias Expresso.Highlight

  defp compile(name, lang) do
    capture_io(:stderr, fn ->
      Code.compile_quoted(
        quote do
          defmodule unquote(Module.concat(__MODULE__, name)) do
            use Expresso

            slide "one" do
              text_box do
                code unquote(lang) do
                  text "a = 1"
                end
              end
            end
          end
        end
      )
    end)
  end

  test "a language that no lexer registers compiles with a warning that names the languages" do
    output = compile(Toml, "toml")

    assert output =~ ~s(deck -> slide -> one: no lexer registers the language "toml")
    assert output =~ "The languages with a lexer are: " <> Enum.join(Highlight.languages(), ", ")
  end

  test "a language with a lexer, and no language, compile with no warning" do
    assert compile(Elixir, "elixir") == ""
    assert compile(Plain, nil) == ""
    assert [_slide] = Expresso.parse(__MODULE__.Plain).slides
  end

  test "a deck of the builder gives the same warning" do
    output =
      capture_io(:stderr, fn ->
        Builder.deck([Builder.slide("one", elements: [Builder.code("elixr", text: "a")])])
      end)

    assert output =~ ~s(no lexer registers the language "elixr")
  end

  test "the list of languages is sorted, and holds each language of a lexer" do
    languages = Highlight.languages()

    assert languages == Enum.sort(languages)
    assert Enum.all?(["elixir", "erlang", "javascript", "rust", "sql"], &(&1 in languages))
  end

  test "the reference of the code element lists the same languages" do
    reference = File.read!("docs/reference/code-element.md")
    list = Enum.map_join(Highlight.languages(), ", ", &"`#{&1}`")

    assert reference =~ "\n" <> list <> "\n"
  end
end
