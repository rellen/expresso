defmodule Expresso.GuideCodeTest do
  use ExUnit.Case, async: true

  # The Elixir code blocks of a page, in order.
  defp blocks(page) do
    for [code] <- Regex.scan(~r/```elixir\n(.*?)```/s, File.read!(page), capture: :all_but_first),
        do: code
  end

  defp deck(code) do
    {value, _bindings} = Code.eval_string(code)
    assert {:ok, %Expresso.Deck{} = deck} = Expresso.to_deck(value)
    deck
  end

  test "each code block of the guide to a deck from data makes the same deck" do
    [dsl, builder] = "docs/how-to/make-a-deck-from-data.md" |> blocks() |> Enum.map(&deck/1)

    assert Expresso.Deck.render(dsl) == Expresso.Deck.render(builder)
    assert Enum.map(dsl.slides, & &1.metadata.max_step) == [3, 3]
  end

  test "the code blocks of the template option make a deck with the templates" do
    deck = "docs/reference/template-option.md" |> blocks() |> Enum.join("\n") |> deck()
    document = deck |> Expresso.Deck.render() |> Floki.parse_document!()

    assert length(Floki.find(document, ".screen .my-header")) == 2
    assert document |> Floki.find(".screen .my-slide h2") |> Floki.text() == "Hello"
  end

  test "the code block of the theme option makes a deck with the colors of Dracula" do
    [code] = blocks("docs/reference/theme-option.md")

    assert deck(code).metadata.theme == :dracula
  end

  test "the table of the theme option holds each built-in theme, with its change and its dim opacity" do
    text = File.read!("docs/reference/theme-option.md")

    for name <- Expresso.Palette.Builtin.names(),
        palette = Expresso.Palette.Builtin.fetch!(name) do
      change = :erlang.float_to_binary(palette.change, decimals: 2)

      row =
        ~r/^\| `#{inspect(name)}` \| [^|]+ \| #{palette.variant} \| #{change} \| #{palette.dim_opacity} \|$/m

      assert Regex.match?(row, text), "the row of #{inspect(name)}"
    end
  end

  test "the example of Expresso.Builder in the overlay options makes four steps" do
    [code] =
      "docs/reference/overlay-options.md" |> blocks() |> Enum.filter(&(&1 =~ "Expresso.Builder"))

    assert [%{metadata: %{max_step: 4}}] = deck(code).slides
  end
end
