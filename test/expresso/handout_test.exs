defmodule Expresso.HandoutTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Handout
  alias Expresso.Overlay
  alias Expresso.Test.Overlay, as: Gen

  defmodule SelectedDeck do
    use Expresso

    name "selected deck"

    slide "three steps" do
      handout [2, :last]
      steps 3

      text_box do
        text_area(text: "One", at: 1)
        text_area(text: "Two", at: 2)
        text_area(text: "Three", at: 3)
      end
    end

    slide "two steps" do
      steps 2

      text_box do
        text_area(text: "Four", at: 2)
      end
    end
  end

  defmodule LastDeck do
    use Expresso

    name "last deck"
    handout :last

    slide "two steps" do
      steps 2

      text_box do
        text_area(text: "One", at: 2)
      end
    end

    slide "overrides the deck" do
      handout :all
      steps 2

      text_box do
        text_area(text: "Two", at: 2)
      end
    end
  end

  defp pages(deck) do
    deck
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".handout-page")
    |> Enum.map(fn page ->
      [slide] = Floki.attribute([page], "data-slide")
      [step] = Floki.attribute([page], "data-step")
      shown = Floki.attribute([page], "data-omit") == []
      {slide <> "." <> step, shown}
    end)
  end

  describe "new/1" do
    test "accepts :all, :last and the forms of an overlay specification" do
      for term <- [:all, :last, 3, 2..4, [2, 5], [from: 3], [2, :last], [:last]] do
        assert {:ok, %Handout{}} = Handout.new(term), inspect(term)
      end
    end

    property "rejects :next, because no counter runs for the option" do
      check all term <- Gen.relative_spec() do
        assert {:error, message} = Handout.new(term)
        assert message =~ "cannot hold :next"
      end
    end

    test "rejects a term of no form" do
      for term <- [[], 0, "2", [:all], [2, :first]] do
        assert {:error, message} = Handout.new(term), inspect(term)
        assert message =~ "the handout option must be :all, :last, or the steps of the slide"
      end
    end
  end

  describe "pages/2" do
    defp pages_of(term, max) do
      {:ok, handout} = Handout.new(term)
      Handout.pages(handout, max)
    end

    property "gives each step for :all and the last step for :last" do
      check all max <- Gen.max() do
        assert pages_of(:all, max) == {:ok, Enum.to_list(1..max)}
        assert pages_of(:last, max) == {:ok, [max]}
      end
    end

    property "gives the steps of the specification and the last step, in order, or an error" do
      check all term <- Gen.absolute_spec(), last <- boolean(), max <- Gen.max() do
        {:ok, overlay} = Overlay.new(term)
        term = if last, do: List.wrap(term) ++ [:last], else: term

        case Overlay.steps(overlay, max) do
          {:ok, steps} ->
            expected = if last, do: Enum.uniq(Enum.sort([max | steps])), else: steps
            assert pages_of(term, max) == {:ok, expected}

          {:error, _message} ->
            assert {:error, message} = pages_of(term, max)
            assert message =~ "the handout option has a step of no page"
        end
      end
    end

    test "gives an error for a step that the slide does not have" do
      assert {:error, message} = pages_of([2, 5], 3)
      assert message =~ "the handout option has a step of no page"
      assert message =~ "the step 5 is more than the maximum step 3"
    end
  end

  describe "the DSL" do
    test "the slide option puts the selection into the metadata of the slide" do
      [first, second] = Expresso.parse(SelectedDeck).slides

      assert %Handout{last: true} = first.metadata.handout
      refute Map.has_key?(second.metadata, :handout)
    end

    test "the handout view shows the selected steps, and marks each other page" do
      assert pages(Expresso.parse(SelectedDeck)) == [
               {"1.1", false},
               {"1.2", true},
               {"1.3", true},
               {"2.1", true},
               {"2.2", true}
             ]
    end

    test "the deck option gives the selection for each slide without the option" do
      assert Expresso.parse(LastDeck).metadata.handout == :last

      assert pages(Expresso.parse(LastDeck)) == [
               {"1.1", false},
               {"1.2", true},
               {"2.1", true},
               {"2.2", true}
             ]
    end

    test "a step that the slide does not have is an error at compile time" do
      source = """
      defmodule Expresso.HandoutTest.FarStep do
        use Expresso

        slide "short" do
          handout [2, 4]
          steps 3
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Elixir.Code.compile_string(source) end
      assert Exception.message(error) =~ "the step 4 is more than the maximum step 3"
    end

    test "a value of no form is an error at compile time" do
      source = """
      defmodule Expresso.HandoutTest.BadForm do
        use Expresso

        slide do
          handout :next
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Elixir.Code.compile_string(source) end
      assert Exception.message(error) =~ "cannot hold :next"
    end

    test "the deck option takes :all or :last only" do
      source = """
      defmodule Expresso.HandoutTest.BadDeck do
        use Expresso

        handout [2]
      end
      """

      assert_raise Spark.Error.DslError, fn -> Elixir.Code.compile_string(source) end
    end
  end

  describe "the imperative API" do
    test "the metadata of the deck and of a slide select the pages" do
      deck =
        "deck"
        |> Expresso.Deck.new(%{handout: :last})
        |> Expresso.Deck.add_slide("one", %{})
        |> Expresso.Deck.add_slide("two", %{handout: :all})

      assert pages(deck) == [{"1.1", true}, {"2.1", true}]
    end

    test "a step that the slide does not have raises at render" do
      deck = Expresso.Deck.add_slide(Expresso.Deck.new("deck"), "one", %{handout: [2]})

      assert_raise ArgumentError, ~r/slide 1: .*the step 2 is more than the maximum step 1/, fn ->
        Expresso.Deck.render(deck)
      end
    end
  end
end
