defmodule Expresso.StepsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Deck
  alias Expresso.Steps
  alias Expresso.Test.Steps, as: Document

  # A deck from the imperative API, with the number of steps of each slide.
  defp deck(counts, metadata \\ %{}) do
    counts
    |> Enum.with_index(1)
    |> Enum.reduce(Deck.new("deck", metadata), fn {steps, number}, deck ->
      Deck.add_slide(deck, "slide #{number}", %{max_step: steps}, [])
    end)
  end

  # Three slides. Slide 2 has three steps, and slide 3 has two steps.
  @three [1, 3, 2]

  describe "entries/1" do
    test "gives each step of each slide, in sequence" do
      assert Enum.map(Steps.entries(deck(@three)), &{&1.slide, &1.step}) ==
               [{1, 1}, {2, 1}, {2, 2}, {2, 3}, {3, 1}, {3, 2}]
    end

    test "fraction counts each step of each slide, from 0 to 1" do
      # Six steps give five moves.
      assert Enum.map(Steps.entries(deck(@three)), & &1.fraction) ==
               [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
    end

    test "done gives the part of the steps before the step, with a part for the last step" do
      assert Enum.map(Steps.entries(deck(@three)), & &1.done) ==
               [0.0, 0.1667, 0.3333, 0.5, 0.6667, 0.8333]
    end

    test "position gives the slide, and the step of a slide with more than one step" do
      assert Enum.map(Steps.entries(deck(@three)), & &1.position) == [
               "Slide 1 of 3",
               "Slide 2 of 3, step 1 of 3",
               "Slide 2 of 3, step 2 of 3",
               "Slide 2 of 3, step 3 of 3",
               "Slide 3 of 3, step 1 of 2",
               "Slide 3 of 3, step 2 of 2"
             ]
    end

    test "a deck of one step gives 0 for fraction and done" do
      assert [%{fraction: +0.0, done: +0.0, position: "Slide 1 of 1"}] = Steps.entries(deck([1]))
    end

    test "a slide from the imperative API has one step" do
      deck = "deck" |> Deck.new() |> Deck.add_slide("one", %{}, [])

      assert [%{slide: 1, step: 1}] = Steps.entries(deck)
    end

    test "a deck with no slide gives no entry" do
      assert Steps.entries(Deck.new("deck")) == []
    end
  end

  describe "slides/1" do
    test "gives the index of the first step and the number of steps of each slide" do
      assert Enum.map(Steps.slides(deck(@three)), &{&1.first, &1.steps}) ==
               [{0, 1}, {1, 3}, {4, 2}]
    end

    test "gives the transition of the slide, then of the deck, then fade" do
      deck =
        "deck"
        |> Deck.new(%{transition: :zoom})
        |> Deck.add_slide("one", %{}, [])
        |> Deck.add_slide("two", %{transition: :slide}, [])
        |> Deck.add_slide("three", %{transition: :spin}, [])

      assert Enum.map(Steps.slides(deck), & &1.transition) == ["zoom", "slide", "zoom"]
      assert Enum.map(Steps.slides(deck([1])), & &1.transition) == ["fade"]
    end
  end

  describe "duration/1" do
    test "gives the minutes of the deck in milliseconds" do
      assert Steps.duration(Deck.new("deck", %{duration: 20})) == 1_200_000
    end

    test "gives nil for a deck with no duration or a value that is not a positive integer" do
      for metadata <- [nil, %{}, %{duration: 0}, %{duration: -5}, %{duration: "15"}] do
        assert Steps.duration(%Deck{Deck.new("deck") | metadata: metadata}) == nil
      end
    end
  end

  describe "json/1" do
    test "gives the steps as arrays, the slides as objects and the duration" do
      assert JSON.decode!(Steps.json(deck([1, 2], %{duration: 5}))) == %{
               "steps" => [
                 [1, 1, 0.0, 0.0, "Slide 1 of 2"],
                 [2, 1, 0.5, 0.3333, "Slide 2 of 2, step 1 of 2"],
                 [2, 2, 1.0, 0.6667, "Slide 2 of 2, step 2 of 2"]
               ],
               "slides" => [
                 %{"first" => 0, "steps" => 1, "transition" => "fade"},
                 %{"first" => 1, "steps" => 2, "transition" => "fade"}
               ],
               "duration_ms" => 300_000
             }
    end

    test "gives the keys of each object in alphabetical order" do
      assert Steps.json(deck([1])) ==
               ~s({"duration_ms":null,"slides":[{"first":0,"steps":1,"transition":"fade"}],) <>
                 ~s("steps":[[1,1,0.0,0.0,"Slide 1 of 1"]]})
    end

    test "gives null for a deck with no duration, and empty lists for a deck with no slide" do
      assert JSON.decode!(Steps.json(Deck.new("deck"))) == %{
               "steps" => [],
               "slides" => [],
               "duration_ms" => nil
             }
    end
  end

  describe "the document" do
    test "holds the list in a JSON script element in front of the presenter script" do
      html = Deck.render(deck(@three))
      [first, _program, bundle] = html |> Floki.parse_document!() |> Floki.find("body > script")

      assert Floki.attribute(first, "id") == ["expresso-deck"]
      assert Floki.attribute(first, "type") == ["application/json"]
      assert Floki.attribute(bundle, "id") == []
      assert length(Document.read(deck(@three))["steps"]) == 6
    end

    test "gives no data-duration and no data-transition, because the list holds them" do
      document = deck([1, 2], %{duration: 5}) |> Deck.render() |> Floki.parse_document!()

      assert Floki.find(document, "[data-duration]") == []
      assert Floki.find(document, "section[data-transition]") == []
    end
  end

  # A deck of 1 to 12 slides, each with 1 to 6 steps.
  defp counts, do: list_of(integer(1..6), min_length: 1, max_length: 12)

  describe "properties" do
    property "fraction goes from 0 to 1 and never down, and done is index / total" do
      check all counts <- counts() do
        entries = Steps.entries(deck(counts))
        total = Enum.sum(counts)
        fractions = Enum.map(entries, & &1.fraction)

        assert length(entries) == total
        assert hd(fractions) == 0.0
        assert List.last(fractions) == if(total > 1, do: 1.0, else: 0.0)
        assert fractions == Enum.sort(fractions)

        for {entry, index} <- Enum.with_index(entries) do
          assert entry.done == Float.round(index / total, 4)
          assert entry.done < 1
          assert entry.done <= entry.fraction
        end
      end
    end

    property "the first step of each slide is at the index that slides/1 gives" do
      check all counts <- counts() do
        entries = Steps.entries(deck(counts))
        slides = Steps.slides(deck(counts))

        assert Enum.map(slides, & &1.steps) == counts

        for {slide, number} <- Enum.with_index(slides, 1) do
          steps = Enum.slice(entries, slide.first, slide.steps)
          assert Enum.map(steps, &{&1.slide, &1.step}) == Enum.map(1..slide.steps, &{number, &1})
        end
      end
    end

    property "the position gives the slide, and a step part only for a slide with more than one step" do
      check all counts <- counts() do
        for entry <- Steps.entries(deck(counts)) do
          steps = Enum.at(counts, entry.slide - 1)

          assert String.starts_with?(entry.position, "Slide #{entry.slide} of #{length(counts)}")

          assert String.contains?(entry.position, ", step #{entry.step} of #{steps}") ==
                   steps > 1
        end
      end
    end
  end
end
