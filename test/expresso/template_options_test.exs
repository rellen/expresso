defmodule Expresso.TemplateOptionsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  defmodule SectionTemplate do
    use Expresso.Template

    def render(assigns) do
      temple do
        div class: "section-slide" do
          Keyword.get(@metadata[:meta] || [], :section, "none")
        end
      end
    end
  end

  defp texts(deck, selector) do
    deck
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen #{selector}")
    |> Enum.map(&Floki.text/1)
  end

  test "the meta option goes into the metadata under :meta" do
    [first, second] =
      Builder.deck([Builder.slide("one", meta: [section: "Part 3", n: 1]), Builder.slide("two")]).slides

    assert first.metadata.meta == [section: "Part 3", n: 1]
    refute Map.has_key?(second.metadata, :meta)
  end

  test "a value of meta cannot replace a key of Expresso" do
    [slide] =
      Builder.deck([Builder.slide("one", heading: "Real", meta: [heading: "Mine"])]).slides

    assert slide.metadata.heading == "Real"
    assert slide.metadata.meta == [heading: "Mine"]
  end

  test "the meta option takes a keyword list only" do
    assert_raise ArgumentError, ~r/meta/, fn -> Builder.slide("one", meta: "Part 3") end
  end

  test "slide_template gives the template of each slide without a template option" do
    deck =
      Builder.deck(
        [
          Builder.slide("one", meta: [section: "Part 1"]),
          Builder.slide("two", heading: "Built in", template: {:builtins, :default})
        ],
        slide_template: SectionTemplate
      )

    assert texts(deck, ".section-slide") == ["Part 1"]
    assert texts(deck, "h1") == ["Built in"]
  end

  test "a deck without slide_template uses the built-in slide template" do
    deck = Builder.deck([Builder.slide("one", heading: "Default")])

    refute Map.has_key?(deck.metadata, :slide_template)
    assert texts(deck, "h1") == ["Default"]
  end

  test "the DSL takes slide_template and meta" do
    [{module, _bytecode}] =
      Code.compile_string("""
      defmodule Expresso.TemplateOptionsTest.Deck do
        use Expresso

        slide_template Expresso.TemplateOptionsTest.SectionTemplate

        slide "one" do
          meta section: "Part 2"
        end
      end
      """)

    assert module |> Expresso.parse() |> texts(".section-slide") == ["Part 2"]
  end
end
