defmodule Expresso.ExamplesTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Expresso.Gifs

  # The pages that show the examples and their GIFs.
  @guides Path.wildcard("docs/{how-to,reference}/*.md")
  @media "https://raw.githubusercontent.com/rellen/expresso/media/"

  defp guides, do: Enum.map_join(@guides, "\n", &File.read!/1)

  test "each example deck gives a deck" do
    for example <- Gifs.examples() do
      {value, _bindings} = Code.eval_file(example.deck)
      assert {:ok, %Expresso.Deck{}} = Expresso.to_deck(value), example.deck
    end
  end

  test "each example deck is in the directory of the examples, and the list holds each one" do
    listed = Enum.map(Gifs.examples(), & &1.deck) |> Enum.sort()

    assert listed == Enum.sort(Path.wildcard("examples/animations/*.exs"))
  end

  test "a how-to guide shows the code of each example deck, as it is in the file" do
    how_to = Enum.map_join(Path.wildcard("docs/how-to/*.md"), "\n", &File.read!/1)

    for example <- Gifs.examples() do
      code = example.deck |> File.read!() |> String.trim_trailing()
      assert how_to =~ "```elixir\n" <> code <> "\n```", example.deck
    end
  end

  test "the guides show each GIF, and no GIF that the task does not record" do
    names = Enum.map(Gifs.examples(), & &1.name)

    shown =
      ~r{#{Regex.escape(@media)}([\w-]+)\.gif}
      |> Regex.scan(guides(), capture: :all_but_first)
      |> List.flatten()
      |> Enum.uniq()

    assert Enum.sort(shown) == Enum.sort(names)
  end

  test "each guide is an extra of ExDoc" do
    extras = Mix.Project.config()[:docs][:extras]

    for guide <- @guides, do: assert(guide in extras, guide)
  end
end
