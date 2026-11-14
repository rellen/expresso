defmodule Expresso.StepsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Expresso.Test.HTML

  alias Expresso.{Deck, Slide}
  alias Expresso.Steps
  alias Expresso.Test.Steps, as: Document

  doctest Expresso.Steps

  # A deck with the number of steps of each slide. The tests make the structs,
  # so a slide can have metadata that the DSL does not give.
  defp deck(counts, metadata \\ %{}) do
    slides =
      for {steps, number} <- Enum.with_index(counts, 1),
          do: slide("slide #{number}", %{max_step: steps})

    "deck" |> Deck.new(metadata, slides) |> Deck.number_slides()
  end

  defp slide(name, metadata), do: %Slide{name: name, metadata: metadata, elements: []}

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

    test "position ends with the label of a step that has one" do
      slides = [
        slide("one", %{max_step: 1, labels: %{1 => "Title"}}),
        slide("two", %{max_step: 2, labels: %{2 => "The answer"}})
      ]

      deck = "deck" |> Deck.new(%{}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.position) == [
               "Slide 1 of 2: Title",
               "Slide 2 of 2, step 1 of 2",
               "Slide 2 of 2, step 2 of 2: The answer"
             ]
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

    test "a slide with no maximum step has one step" do
      deck = "deck" |> Deck.new(%{}, [slide("one", %{})]) |> Deck.number_slides()

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

    test "gives the transition of the slide, then of the deck, then fade, with hyphens" do
      slides = [
        slide("one", %{}),
        slide("two", %{transition: :slide}),
        slide("three", %{transition: :spin_out})
      ]

      deck = "deck" |> Deck.new(%{transition: :zoom}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.slides(deck), & &1.transition) == ["zoom", "slide", "spin-out"]
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

  describe "the advance option" do
    test "the time of the deck is the time of each step" do
      assert Enum.map(Steps.entries(deck(@three, %{advance: 15_000})), & &1.advance) ==
               List.duplicate(15_000, 6)
    end

    test "a deck with no time gives no time to a step" do
      assert Enum.map(Steps.entries(deck(@three)), & &1.advance) == List.duplicate(nil, 6)
    end

    test "the time of a slide replaces the time of the deck, and false gives no time" do
      slides = [
        slide("one", %{max_step: 1, advance: false}),
        slide("two", %{max_step: 2, advance: 5_000}),
        slide("three", %{max_step: 1})
      ]

      deck = "deck" |> Deck.new(%{advance: 20_000}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.advance) == [nil, 5_000, 5_000, 20_000]
    end

    test "a list gives the time of each step in sequence" do
      slides = [slide("one", %{max_step: 3, advance: [12_000, 8_000, 5_000]})]
      deck = "deck" |> Deck.new(%{advance: 20_000}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.advance) == [12_000, 8_000, 5_000]
    end

    test "a step after the end of a list takes the last time of the list" do
      slides = [
        slide("short", %{max_step: 3, advance: [12_000, 8_000]}),
        slide("long", %{max_step: 1, advance: [3_000, 4_000]})
      ]

      deck = "deck" |> Deck.new(%{}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.advance) == [12_000, 8_000, 8_000, 3_000]
    end

    test "an empty list gives the time of the deck" do
      slides = [slide("one", %{max_step: 2, advance: []})]
      deck = "deck" |> Deck.new(%{advance: 20_000}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.advance) == [20_000, 20_000]
    end

    test "the DSL takes a list of times, and it refuses a list with a different value" do
      defmodule ListDeck do
        use Expresso

        name "list"

        slide "one" do
          steps 2
          advance [12_000, 8_000]
        end
      end

      assert Enum.map(Steps.entries(Expresso.parse(ListDeck)), & &1.advance) == [12_000, 8_000]

      assert_raise Spark.Error.DslError, ~r/advance/, fn ->
        defmodule ZeroList do
          use Expresso

          name "zero list"

          slide "one" do
            advance [12_000, 0]
          end
        end
      end
    end

    test "a value that is not a positive integer gives no time" do
      for advance <- [0, -5, "15", 1.5, true] do
        assert Enum.map(Steps.entries(deck([1], %{advance: advance})), & &1.advance) == [nil]
      end
    end

    test "the DSL takes the option of the deck and of a slide" do
      defmodule TimedDeck do
        use Expresso

        name "timed"
        advance 20_000
        loop true

        slide "title" do
          advance false
        end

        slide "short" do
          advance 5_000
        end

        slide "other" do
        end
      end

      deck = Expresso.parse(TimedDeck)

      assert Enum.map(Steps.entries(deck), &{&1.advance, &1.next}) ==
               [{nil, 1}, {5_000, 2}, {20_000, 0}]
    end

    test "the DSL refuses a time that is not a positive integer" do
      message = ~r/advance/

      assert_raise Spark.Error.DslError, message, fn ->
        defmodule NoTime do
          use Expresso

          name "no time"
          advance 0
        end
      end

      assert_raise Spark.Error.DslError, message, fn ->
        defmodule TrueTime do
          use Expresso

          name "true time"

          slide "one" do
            advance true
          end
        end
      end
    end

    test "the builder takes the two options" do
      deck =
        Expresso.Builder.deck(
          [
            Expresso.Builder.slide("one", advance: 3_000),
            Expresso.Builder.slide("two", [])
          ],
          name: "built",
          advance: 8_000,
          loop: true
        )

      assert Enum.map(Steps.entries(deck), &{&1.advance, &1.next}) == [{3_000, 1}, {8_000, 0}]
    end
  end

  describe "the loop option" do
    test "the step after the last step is the first step of the talk" do
      entries = Steps.entries(deck(@three, %{loop: true}))

      assert Enum.map(entries, & &1.next) == [1, 2, 3, 4, 5, 0]
      # The option does not change the step before the first step.
      assert Enum.map(entries, & &1.previous) == [nil, 0, 1, 2, 3, 4]
    end

    test "a deck with no loop has no step after the last step" do
      for metadata <- [%{}, %{loop: false}, %{loop: nil}] do
        assert List.last(Steps.entries(deck(@three, metadata))).next == nil
      end
    end

    test "the first step of the talk is not a step of a hidden slide" do
      slides = [
        slide("backup", %{max_step: 2, hidden: true}),
        slide("one", %{max_step: 1}),
        slide("two", %{max_step: 1}),
        slide("more", %{max_step: 1, hidden: true})
      ]

      deck = "deck" |> Deck.new(%{loop: true}, slides) |> Deck.number_slides()

      # The talk is the steps 2 and 3. The last step of each hidden slide
      # goes back into the talk.
      assert Enum.map(Steps.entries(deck), & &1.next) == [1, 2, 3, 2, 2]
    end

    test "a deck with only hidden slides has no first step of the talk" do
      slides = [slide("backup", %{max_step: 2, hidden: true})]
      deck = "deck" |> Deck.new(%{loop: true}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.entries(deck), & &1.next) == [1, nil]
    end
  end

  describe "the name of a slide" do
    test "slides/1 gives the name of each slide, and nil for a slide with no name" do
      slides = [slide("intro", %{max_step: 1}), slide(nil, %{max_step: 1})]
      deck = "deck" |> Deck.new(%{}, slides) |> Deck.number_slides()

      assert Enum.map(Steps.slides(deck), & &1.name) == ["intro", nil]
    end
  end

  describe "json/1" do
    test "gives the steps as arrays, the slides as objects and the duration" do
      assert JSON.decode!(Steps.json(deck([1, 2], %{duration: 5}))) == %{
               "steps" => [
                 [1, 1, 0.0, 0.0, "Slide 1 of 2", nil, 1, nil],
                 [2, 1, 0.5, 0.3333, "Slide 2 of 2, step 1 of 2", 0, 2, nil],
                 [2, 2, 1.0, 0.6667, "Slide 2 of 2, step 2 of 2", 1, nil, nil]
               ],
               "slides" => [
                 %{
                   "first" => 0,
                   "name" => "slide 1",
                   "number" => 1,
                   "steps" => 1,
                   "transition" => "fade"
                 },
                 %{
                   "first" => 1,
                   "name" => "slide 2",
                   "number" => 2,
                   "steps" => 2,
                   "transition" => "fade"
                 }
               ],
               "duration_ms" => 300_000
             }
    end

    test "gives the keys of each object in alphabetical order" do
      assert Steps.json(deck([1])) ==
               ~s({"duration_ms":null,"slides":[{"first":0,"name":"slide 1","number":1,"steps":1,) <>
                 ~s("transition":"fade"}],"steps":[[1,1,0.0,0.0,"Slide 1 of 1",null,null,null]]})
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

      [first, _program, bundle] =
        html |> LazyHTML.from_document() |> LazyHTML.query("body > script") |> Enum.to_list()

      assert LazyHTML.attribute(first, "id") == ["expresso-deck"]
      assert LazyHTML.attribute(first, "type") == ["application/json"]
      assert LazyHTML.attribute(bundle, "id") == []
      assert length(Document.read(deck(@three))["steps"]) == 6
    end

    test "gives no data-duration and no data-transition, because the list holds them" do
      document = deck([1, 2], %{duration: 5}) |> document()

      assert count(document, "[data-duration]") == 0
      assert count(document, "section.slide:not([data-transition])") == 2
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
