defmodule Expresso.ExamplesTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Expresso.Gifs

  # The pages that show the examples of the guides and their GIFs.
  @guides Path.wildcard("docs/{how-to,reference}/*.md")
  @media "https://raw.githubusercontent.com/rellen/expresso/media/"

  defp guides, do: Enum.map_join(@guides, "\n", &File.read!/1)

  defp of(page), do: Enum.filter(Gifs.examples(), &(&1.page == page))

  # The files of the media branch that a text shows.
  defp shown(text) do
    ~r{#{Regex.escape(@media)}([\w-]+\.(?:gif|png))}
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  test "each example deck gives a deck" do
    for deck <- Gifs.examples() |> Enum.map(& &1.deck) |> Enum.uniq() do
      {value, _bindings} = Code.eval_file(deck)
      assert {:ok, %Expresso.Deck{}} = Expresso.to_deck(value), deck
    end
  end

  test "each example deck is in a directory of the examples, and the list holds each one" do
    listed = Gifs.examples() |> Enum.map(& &1.deck) |> Enum.uniq() |> Enum.sort()

    assert listed == Enum.sort(Path.wildcard("examples/{animations,presenter,themes}/*.exs"))
  end

  test "each example of the guides is in examples/animations, and each of the README in examples/presenter" do
    for example <- of(:guides), do: assert(example.deck =~ ~r{^examples/animations/})
    for example <- of(:readme), do: assert(example.deck =~ ~r{^examples/presenter/})
    for example <- of(:themes), do: assert(example.deck =~ ~r{^examples/themes/})
  end

  test "each built-in theme has a still, and the theme option shows each one" do
    themes = Enum.map(of(:themes), & &1.theme)
    shown = shown(File.read!("docs/reference/theme-option.md"))

    assert Enum.sort(themes) == Expresso.Palette.Builtin.names()
    assert shown == of(:themes) |> Enum.map(&Gifs.file/1) |> Enum.sort()
  end

  test "a how-to guide shows the code of each example deck of the guides, as it is in the file" do
    how_to = Enum.map_join(Path.wildcard("docs/how-to/*.md"), "\n", &File.read!/1)

    for example <- of(:guides) do
      code = example.deck |> File.read!() |> String.trim_trailing()
      assert how_to =~ "```elixir\n" <> code <> "\n```", example.deck
    end
  end

  test "the guides show each file of the guides and of the themes, and no file that the task does not record" do
    files = Enum.map(of(:guides) ++ of(:themes), &Gifs.file/1)

    assert shown(guides()) == Enum.sort(files)
  end

  test "the README shows each file of its examples, and no file that the task does not record" do
    shown = shown(File.read!("README.md"))
    readme = of(:readme) |> Enum.map(&Gifs.file/1) |> Enum.sort()
    all = Gifs.examples() |> Enum.map(&Gifs.file/1)

    assert readme -- shown == []
    assert shown -- all == []
  end

  test "the talk about Line 4 renders each of its slides" do
    {value, _bindings} = Code.eval_file("examples/line4/line4.exs")
    assert {:ok, deck} = Expresso.to_deck(value)

    document = deck |> Expresso.Deck.render() |> Floki.parse_document!()

    assert document |> Floki.find("section.slide") |> length() == length(deck.slides)
    assert document |> Floki.find(".screen .diagram svg") |> length() == 10
  end

  test "the talk about Line 4 shows the start of its deck module on the slide of the DSL" do
    {value, _bindings} = Code.eval_file("examples/line4/line4.exs")
    assert {:ok, deck} = Expresso.to_deck(value)

    [code] = Enum.find(deck.slides, &(&1.name == "this deck")).elements

    assert code.text =~ ~r/\Adefmodule Line4.Deck do\n  use Expresso\n/
    assert code.text =~ ~r/  easing :ease_out\z/
  end

  test "each guide is an extra of ExDoc" do
    extras = Mix.Project.config()[:docs][:extras]

    for guide <- @guides, do: assert(guide in extras, guide)
  end
end
