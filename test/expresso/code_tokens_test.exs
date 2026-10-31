defmodule Expresso.CodeTokensTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.{Lines, On}

  @text """
  def add(count, step) do
    count = count + step
    {count, step, counter, @count}
  end
  """

  defp document(opts) do
    [Builder.slide("a", elements: [Builder.code([text: @text, lang: "elixir"] ++ opts)])]
    |> Builder.deck()
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  defp texts(document, selector),
    do: document |> LazyHTML.query(".screen .code " <> selector) |> Enum.map(&LazyHTML.text/1)

  test "a token group has the text of its tokens and no line numbers" do
    code = Builder.code(text: @text, lang: "elixir", highlight: [[each: "count"], 4])

    assert [%Lines{each: "count", numbers: []}, %Lines{numbers: [4]}, %Lines{numbers: [1, 2, 3]}] =
             code.elements
  end

  test "each token with the text gets the class code-token and the overlay attributes" do
    document = document(highlight: [[each: "count"], 4])

    assert texts(document, ".code-token") |> Enum.map(&String.trim/1) ==
             ["count", "count", "count", "count"]

    assert texts(document, ".code-token[data-el]") |> length() == 4
    # A name that holds the text, such as a longer name, is not a token of it.
    assert texts(document, ".line .code-token") |> Enum.map(&String.trim/1) |> Enum.uniq() ==
             ["count"]
  end

  test "each line keeps its white space, and a token holds only its word" do
    plain = document(highlight: [4])
    marked = document(highlight: [[each: "count"], [each: "step"], 4])

    # Floki drops a text node of white space only, so a split of a token must
    # keep each space next to a visible character.
    assert texts(marked, ".line") == texts(plain, ".line")
    assert texts(marked, ".line") |> Enum.at(1) == "  count = count + step\n"

    # A token at the start of a line keeps its indent, and the other tokens
    # hold only the word.
    assert texts(marked, ".code-token") ==
             ["count", "step", "  count", "count", "step\n", "count", "step"]
  end

  test "at the step of a token group, each line dims, and the tokens show in full color" do
    deck =
      [
        Builder.slide("a",
          elements: [Builder.code(text: @text, lang: "elixir", highlight: [[each: "step"], 4])]
        )
      ]
      |> Builder.deck()

    html = Expresso.Deck.render(deck)

    # The token group sets --dimmed: 0 at its step, and the lines dim then.
    [_all, token_el] = Regex.run(~r/class="[^"]*code-token[^"]*" data-el="([^"]+)"/, html)
    assert html =~ ~r/\[data-el="#{token_el}"\] \{ --highlight: 1; --dimmed: 0; \}/

    # The token group does not dim at the step of the line group.
    refute html =~ ~r/\[data-el="#{token_el}"\] \{ --dim: 1;/
  end

  test "a token group in reveal, and a token group with no token, give an error" do
    assert_raise ArgumentError, ~r/the reveal option of a code element takes no group/, fn ->
      Builder.code(text: @text, lang: "elixir", reveal: [[each: "count"]])
    end

    assert_raise ArgumentError, ~r/\[each: "total"\] of a code element selects no token/, fn ->
      document(highlight: [[each: "total"]])
    end

    # A code element without a lexer has no token.
    assert_raise ArgumentError, ~r/selects no token/, fn ->
      [
        Builder.slide("a",
          elements: [Builder.code(text: "count + 1", highlight: [[each: "count"]])]
        )
      ]
      |> Builder.deck()
      |> Expresso.Deck.render()
    end
  end

  test "the DSL takes a token group in highlight" do
    defmodule TokenDeck do
      use Expresso

      slide "code" do
        code "elixir" do
          text "count = count + 1"
          highlight [[each: "count"]]
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(TokenDeck)
    [code] = hd(deck.slides).elements
    assert [%Lines{each: "count", on: [%On{state: :highlight}]} | _rest] = code.elements
  end
end
