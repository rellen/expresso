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

    assert document |> Floki.find(".screen .my-header") |> Enum.map(&Floki.text/1) ==
             ["Part 1", "my deck"]

    assert document |> Floki.find(".screen .my-slide h2") |> Floki.text() == "Hello"
    assert length(Floki.find(document, ".screen .my-slide")) == 1
  end

  test "the code block of the theme option makes a deck with the colors of Dracula" do
    [code] = blocks("docs/reference/theme-option.md")

    assert deck(code).metadata.theme == :dracula
  end

  test "the table of the theme option holds each built-in theme, with its change and its dim opacities" do
    text = File.read!("docs/reference/theme-option.md")

    for name <- Expresso.Palette.Builtin.names(),
        palette = Expresso.Palette.Builtin.fetch!(name) do
      change = :erlang.float_to_binary(palette.change, decimals: 2)

      row =
        ~r/^\| `#{inspect(name)}` \| [^|]+ \| #{palette.variant} \| #{change} \| #{elem(palette.dimmed.text, 0)} \| #{elem(palette.dimmed.code_comment, 0)} \|$/m

      assert Regex.match?(row, text), "the row of #{inspect(name)}"
    end
  end

  test "the example of Expresso.Builder in the overlay options makes four steps" do
    [code] =
      "docs/reference/overlay-options.md" |> blocks() |> Enum.filter(&(&1 =~ "Expresso.Builder"))

    assert [%{metadata: %{max_step: 4}}] = deck(code).slides
  end

  @tag :tmp_dir
  test "the deck of the guide to code from the project of the deck renders from another directory",
       %{tmp_dir: tmp_dir} do
    [code] =
      "docs/how-to/show-code.md" |> blocks() |> Enum.filter(&(&1 =~ "__DIR__"))

    lines = Enum.map_join(1..60, &"# line #{&1}\n")
    File.mkdir_p!(Path.join(tmp_dir, "talk"))
    File.mkdir_p!(Path.join(tmp_dir, "lib/my_app"))
    File.write!(Path.join(tmp_dir, "lib/my_app/server.ex"), lines)
    File.write!(Path.join(tmp_dir, "talk/deck.exs"), String.replace(code, ~r/^   /m, ""))

    assert {:ok, html} = Expresso.render_file(Path.join(tmp_dir, "talk/deck.exs"))
    assert html =~ "# line 40"
    assert html =~ "# line 58"
    refute html =~ "# line 59"
  end

  test "the warnings of the guide to colors of your own come from its map, and its deck takes each color" do
    text = File.read!("docs/how-to/use-colors-of-your-own.md")
    [map] = Regex.run(~r/theme (%\{.*?\})\n   ```/s, text, capture: :all_but_first)
    {start, _bindings} = Code.eval_string(map)

    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Expresso.Builder.deck([Expresso.Builder.slide("one")], theme: start)
      end)

    [warnings] = Regex.run(~r/```text\n(.*?)\n```/s, text, capture: :all_but_first)
    for line <- String.split(warnings, "\n"), do: assert(output =~ line <> "\n", line)

    {value, _bindings} = Code.eval_file("examples/animations/theme_map.exs")
    {:ok, deck} = Expresso.to_deck(value)
    fixed = Map.merge(start, start |> Expresso.Palette.of() |> Expresso.Palette.suggestions())

    assert deck.metadata.theme == fixed
    assert fixed |> Expresso.Palette.of() |> Expresso.Palette.problems() == []
  end
end
