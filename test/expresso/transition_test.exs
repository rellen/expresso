defmodule Expresso.TransitionTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1]

  # The deck slides, slide two zooms, and slide three has no transition.
  defmodule MixedDeck do
    use Expresso

    name "mixed deck"
    transition :slide

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      transition :zoom

      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
      transition :none

      text_box do
        text_area(text: "Three")
      end
    end
  end

  defmodule PlainDeck do
    use Expresso

    name "plain deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  # The kind of each slide in the list of the steps of the document.
  defp kinds(deck) do
    deck
    |> Expresso.Test.Steps.read()
    |> Map.fetch!("slides")
    |> Enum.map(& &1["transition"])
  end

  test "a deck without the option fades" do
    deck = Expresso.parse(PlainDeck)

    assert deck.metadata.transition == :fade
    assert kinds(deck) == ["fade"]
  end

  test "the option of a slide replaces the option of the deck" do
    deck = Expresso.parse(MixedDeck)

    assert deck.metadata.transition == :slide
    assert Enum.map(deck.slides, & &1.metadata[:transition]) == [nil, :zoom, :none]
    assert kinds(deck) == ["slide", "zoom", "none"]
  end

  test "no element of the document gets a transition attribute" do
    document = MixedDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

    assert document |> Floki.find("[data-transition]") == []
  end

  # Slide two wipes down with a transition of the CSS of the deck.
  defmodule CustomDeck do
    use Expresso

    name "custom deck"

    css ~S"""
    html[data-transition="wipe-down"]::view-transition-new(slide) {
      animation-name: wipe-down;
    }
    """

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      transition :wipe_down

      text_box do
        text_area(text: "Two")
      end
    end
  end

  test "a transition of the CSS of the deck goes to the presenter with hyphens" do
    deck = Expresso.parse(CustomDeck)

    assert Enum.map(deck.slides, & &1.metadata[:transition]) == [nil, :wipe_down]
    assert kinds(deck) == ["fade", "wipe-down"]
  end

  test "a deck struct takes the kinds from its metadata" do
    slide = &%Expresso.Slide{name: &1, metadata: &2, elements: []}

    slides = [
      slide.("one", %{}),
      slide.("two", %{transition: :slide}),
      slide.("three", %{transition: :wipe_down})
    ]

    deck =
      "deck" |> Expresso.Deck.new(%{transition: :zoom}, slides) |> Expresso.Deck.number_slides()

    assert kinds(deck) == ["zoom", "slide", "wipe-down"]
    assert [Expresso.Builder.slide("one")] |> Expresso.Builder.deck() |> kinds() == ["fade"]
  end

  test "the DSL refuses a transition of the deck without a rule, and tells the selector" do
    errors =
      dsl_errors do
        defmodule Elixir.Expresso.TransitionTest.SpinDeck do
          use Expresso

          transition :spin_out
        end
      end

    assert [{Expresso.TransitionTest.SpinDeck, [error]}] = errors
    assert error.path == [:deck]

    assert Exception.message(error) =~
             "the transition :spin_out has no rule in the theme or in the CSS of the deck"

    assert Exception.message(error) =~
             ~s|html[data-transition="spin-out"]::view-transition-new(slide)|
  end

  test "the DSL refuses a transition of a slide without a rule, and names the slide" do
    errors =
      dsl_errors do
        defmodule Elixir.Expresso.TransitionTest.SpinSlideDeck do
          use Expresso

          # A rule for an element is not a rule for the html element.
          css ~S"""
          .box[data-transition="spin"] { color: red; }
          """

          slide "one" do
            transition :slide
          end

          slide "two" do
            transition :spin
          end
        end
      end

    assert [{Expresso.TransitionTest.SpinSlideDeck, [error]}] = errors
    assert error.path == [:deck, :slide, "two"]
    assert Exception.message(error) =~ "the transition :spin has no rule"
  end

  test "Expresso.Builder.deck/2 refuses a transition without a rule, as the DSL does" do
    slides = [Expresso.Builder.slide("one", transition: :spin)]

    assert_raise Spark.Error.DslError, ~r/the transition :spin has no rule/, fn ->
      Expresso.Builder.deck(slides)
    end

    css = ~s|html[data-transition="spin"]::view-transition-new(slide) { opacity: 1; }|
    assert slides |> Expresso.Builder.deck(css: css) |> kinds() == ["spin"]
  end

  test "the builtin kinds of the schema are the transitions of the theme" do
    assert Expresso.Theme.transitions() ==
             MapSet.new(Expresso.Presenter.Schema.transitions(), &Atom.to_string/1)
  end
end
