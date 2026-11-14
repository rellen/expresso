defmodule Expresso.HiddenSlidesTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.{Builder, Deck, Slide, Steps}
  alias Expresso.Presenter.{Definition, Interpreter, Program}
  alias Expresso.Test.Presenter, as: Model

  doctest Expresso.Slide, only: [hidden?: 1]
  doctest Expresso.Deck, only: [talk_length: 1]
  doctest Expresso.Presenter.Program, only: [start: 1]

  # A deck with the number of steps of each slide. `hidden` gives the place of
  # each hidden slide.
  defp deck(counts, hidden, deck_opts \\ []) do
    counts
    |> Enum.with_index(1)
    |> Enum.map(fn {steps, place} ->
      Builder.slide("slide #{place}",
        steps: steps,
        hidden: place in hidden,
        elements: [Builder.text_box(elements: [Builder.text_area(text: "Text #{place}")])]
      )
    end)
    |> Builder.deck([name: "deck"] ++ deck_opts)
  end

  # Four slides of 1, 2, 1 and 2 steps. Slide 2 is hidden, so the talk has
  # three slides.
  @counts [1, 2, 1, 2]
  defp four(deck_opts \\ []), do: deck(@counts, [2], deck_opts)
  defp program(deck), do: Program.compile(Definition.presenter(), deck)

  describe "the numbers of the slides" do
    test "the place counts each slide, and the number in the talk counts only the slides that show" do
      slides = four().slides

      assert Enum.map(slides, & &1.metadata.slide_number) == [1, 2, 3, 4]
      assert Enum.map(slides, & &1.metadata.talk_number) == [1, nil, 2, 3]
      assert Deck.talk_length(four()) == 3
    end

    test "a deck with no hidden slide has the same two numbers" do
      slides = deck([1, 1, 1], []).slides

      assert Enum.map(slides, & &1.metadata.talk_number) ==
               Enum.map(slides, & &1.metadata.slide_number)
    end
  end

  describe "Expresso.Steps" do
    test "gives each step of each slide, and a hidden slide keeps its place" do
      assert Enum.map(Steps.entries(four()), &{&1.slide, &1.step}) ==
               [{1, 1}, {2, 1}, {2, 2}, {3, 1}, {4, 1}, {4, 2}]
    end

    test "previous and next skip the hidden slide, and they go through its steps" do
      assert Enum.map(Steps.entries(four()), &{&1.previous, &1.next}) == [
               {nil, 3},
               {0, 2},
               {1, 3},
               {0, 4},
               {3, 5},
               {4, nil}
             ]
    end

    test "fraction and done count only the steps of the talk, and a hidden slide keeps the values of the step before it" do
      entries = Steps.entries(four())

      # The talk has four steps, so it has three moves.
      assert Enum.map(entries, & &1.fraction) == [0.0, 0.0, 0.0, 0.3333, 0.6667, 1.0]
      assert Enum.map(entries, & &1.done) == [0.0, 0.0, 0.0, 0.25, 0.5, 0.75]
    end

    test "position counts only the slides of the talk, and it names a hidden slide" do
      assert Enum.map(Steps.entries(four()), & &1.position) == [
               "Slide 1 of 3",
               "Hidden slide after slide 1 of 3, step 1 of 2",
               "Hidden slide after slide 1 of 3, step 2 of 2",
               "Slide 2 of 3",
               "Slide 3 of 3, step 1 of 2",
               "Slide 3 of 3, step 2 of 2"
             ]
    end

    test "a hidden slide in front of the talk, and a deck with only hidden slides" do
      assert Enum.map(Steps.entries(deck([1, 1], [1])), & &1.position) ==
               ["Hidden slide before slide 1 of 1", "Slide 1 of 1"]

      entries = Steps.entries(deck([1, 2], [1, 2]))

      assert Enum.map(entries, & &1.position) ==
               ["Hidden slide", "Hidden slide, step 1 of 2", "Hidden slide, step 2 of 2"]

      # No step of a different slide is a step of the talk.
      assert Enum.map(entries, &{&1.previous, &1.next}) == [{nil, nil}, {nil, 2}, {1, nil}]
      assert Enum.map(entries, &{&1.fraction, &1.done}) == [{0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}]
    end

    test "two hidden slides in sequence are one gap in the talk" do
      entries = Steps.entries(deck([1, 1, 1, 1], [2, 3]))

      assert Enum.map(entries, &{&1.previous, &1.next}) ==
               [{nil, 3}, {0, 3}, {0, 3}, {0, nil}]
    end

    test "slides/1 gives each slide its number in the talk, or nil" do
      assert Enum.map(Steps.slides(four()), &{&1.first, &1.steps, &1.number}) ==
               [{0, 1, 1}, {1, 2, nil}, {3, 1, 2}, {4, 2, 3}]
    end
  end

  describe "the presenter" do
    defp at(program, slide, step), do: Model.at(program, slide, step)
    defp key(program, state, key), do: Model.run(program, state, {:key, key})
    defp where(program, state), do: Model.where(program, state)

    test "j and k skip a hidden slide" do
      program = program(four())

      assert where(program, key(program, at(program, 1, 1), "j")) == {3, 1}
      assert where(program, key(program, at(program, 3, 1), "k")) == {1, 1}
    end

    test "on a hidden slide, j and k go through its steps and then into the talk" do
      program = program(four())

      assert where(program, key(program, at(program, 2, 1), "j")) == {2, 2}
      assert where(program, key(program, at(program, 2, 2), "j")) == {3, 1}
      assert where(program, key(program, at(program, 2, 1), "k")) == {1, 1}
    end

    test "a typed number goes to the slide of the talk with that number" do
      program = program(four())

      assert where(program, Model.keys(program, at(program, 1, 1), ["2", "Enter"])) == {3, 1}
      assert where(program, Model.keys(program, at(program, 1, 1), ["3", "Enter"])) == {4, 1}
    end

    test "a hidden slide has no number, so the number after the last slide makes no change" do
      program = program(four())
      state = Model.keys(program, at(program, 1, 1), ["4", "Enter"])

      assert where(program, state) == {1, 1}
      assert state.digits == ""
    end

    test "the address and a message of the other window go to a hidden slide by its place" do
      program = program(four())
      start = at(program, 1, 1)

      assert where(program, Model.run(program, start, {:hash, "#2.2"})) == {2, 2}

      message = {:message, %{slide: 2, step: 1, fields: %{}}}
      assert where(program, Model.run(program, start, message)) == {2, 1}
    end

    test "the overview selects a hidden slide, and Enter goes to it" do
      program = program(four())
      state = Model.keys(program, at(program, 1, 1), ["o", "ArrowRight", "Enter"])

      assert where(program, state) == {2, 1}
      refute state.overview
    end

    test "End in the overview selects the last slide of the deck, which can be a hidden slide" do
      program = program(deck([1, 1, 1], [3]))
      state = Model.keys(program, at(program, 1, 1), ["o", "End"])

      assert state.selected == 3
    end

    test "the deck starts at the first slide of the talk, and Home and End stay in the talk" do
      program = program(deck([2, 1, 1, 1], [1, 4]))

      assert where(program, Interpreter.initial(program)) == {2, 1}
      assert where(program, key(program, at(program, 3, 1), "Home")) == {2, 1}
      assert where(program, key(program, at(program, 2, 1), "End")) == {3, 1}
    end

    test "k on the first slide of the talk and j on its last slide make no change" do
      program = program(deck([1, 1, 1], [1, 3]))

      assert where(program, key(program, at(program, 2, 1), "k")) == {2, 1}
      assert where(program, key(program, at(program, 2, 1), "j")) == {2, 1}
    end

    test "a deck with only hidden slides starts at its first step, and Home and End make no change" do
      program = program(deck([1, 1], [1, 2]))

      assert where(program, Interpreter.initial(program)) == {1, 1}
      assert where(program, key(program, at(program, 2, 1), "Home")) == {2, 1}
      assert where(program, key(program, at(program, 1, 1), "End")) == {1, 1}
      assert where(program, key(program, at(program, 1, 1), "j")) == {1, 1}
    end
  end

  describe "the document" do
    test "the present view shows the first slide of the talk before the script starts" do
      html = document(deck([1, 1, 1], [1]))

      assert html
             |> LazyHTML.query(".screen > .slide")
             |> LazyHTML.attribute("style")
             |> Enum.map(&(&1 =~ "display: flex")) == [false, true, false]
    end

    test "the name of a slide for a screen reader counts only the slides of the talk" do
      html = document(four())

      assert html |> LazyHTML.query(".screen > .slide") |> LazyHTML.attribute("aria-label") == [
               "Slide 1 of 3: slide 1",
               "Hidden slide: slide 2",
               "Slide 2 of 3: slide 3",
               "Slide 3 of 3: slide 4"
             ]

      assert html |> LazyHTML.query(".handout-page") |> LazyHTML.attribute("aria-label") == [
               "Slide 1 of 3: slide 1",
               "Hidden slide, step 1 of 2: slide 2",
               "Hidden slide, step 2 of 2: slide 2",
               "Slide 2 of 3: slide 3",
               "Slide 3 of 3, step 1 of 2: slide 4",
               "Slide 3 of 3, step 2 of 2: slide 4"
             ]
    end

    test "the slide numbers count only the slides of the talk, and a hidden slide shows no number" do
      html = document(four(slide_numbers: true))

      assert texts(html, ".screen .slide-number") == ["2 / 3", "3 / 3"]
      assert count(html, ".screen #slide-2 .slide-number") == 0
    end

    test "the handout view leaves out each page of a hidden slide, and the overview marks its page" do
      html = document(four())
      pages = LazyHTML.query(html, ".handout-page")

      assert Enum.map(pages, &LazyHTML.attribute(&1, "data-omit")) ==
               [[], ["hidden"], ["hidden"], [], [], []]

      assert Enum.map(pages, &(LazyHTML.attribute(&1, "data-hidden") != [])) ==
               [false, true, true, false, false, false]

      # The overview shows the page of the last step of each slide.
      assert count(html, ".handout-page[data-thumbnail][data-hidden]") == 1
    end

    test "the handout_hidden option gives a hidden slide the pages of its handout option" do
      html = document(four(handout_hidden: true, handout: :last))
      pages = LazyHTML.query(html, ".handout-page")

      # No page has the value "hidden", and the handout option of the deck
      # selects the last step of each slide.
      assert Enum.map(pages, &LazyHTML.attribute(&1, "data-omit")) ==
               [[], ["data-omit"], [], [], ["data-omit"], []]

      assert count(html, ".handout-page[data-hidden]") == 2
    end

    test "the menu shows a dash for the number of a hidden slide, and it marks the slide" do
      html = document(four())

      assert html
             |> LazyHTML.query("#menu .menu-slide > .menu-number")
             |> Enum.map(&LazyHTML.text/1) == ["1", "Hidden slide–", "2", "3"]

      assert html
             |> LazyHTML.query("#menu .menu-group")
             |> Enum.map(&(LazyHTML.attribute(&1, "data-hidden") != [])) ==
               [false, true, false, false]
    end

    test "a hidden slide with no name gets the name \"Hidden slide\"" do
      # The tests make the structs, because the DSL gives each slide a name.
      slides = [
        %Slide{elements: [], metadata: %{}},
        %Slide{elements: [], metadata: %{hidden: true}}
      ]

      html = "deck" |> Deck.new(%{}, slides) |> Deck.number_slides() |> document()

      assert texts(html, "#menu .menu-name") == ["Slide 1", "Hidden slide"]

      assert html |> LazyHTML.query(".screen > .slide") |> LazyHTML.attribute("aria-label") ==
               ["Slide 1 of 1", "Hidden slide"]
    end

    test "the page of the sources leaves out a hidden slide, except with handout_hidden" do
      slides = fn ->
        [
          Builder.slide("shown", elements: [Builder.footnote("Book")]),
          Builder.slide("backup", hidden: true, elements: [Builder.footnote("Paper")]),
          Builder.slide("last", elements: [Builder.footnote("Talk")])
        ]
      end

      html = document(Builder.deck(slides.(), name: "deck"))
      assert texts(html, ".sources h3") == ["1. shown", "2. last"]

      html = document(Builder.deck(slides.(), name: "deck", handout_hidden: true))
      assert texts(html, ".sources h3") == ["1. shown", "Hidden slide: backup", "2. last"]
    end

    test "the list of the steps holds the number of each slide and the moves of each step" do
      steps = Expresso.Test.Steps.read(four())

      assert Enum.map(steps["slides"], & &1["number"]) == [1, nil, 2, 3]

      assert Enum.map(steps["steps"], &Enum.take(&1, -2)) ==
               [[nil, 3], [0, 2], [1, 3], [0, 4], [3, 5], [4, nil]]
    end
  end

  describe "the option" do
    test "the DSL takes hidden and handout_hidden" do
      defmodule BackupDeck do
        use Expresso

        handout_hidden true

        slide "talk" do
          heading "The talk"
        end

        slide "backup" do
          hidden true
          heading "The numbers"
        end
      end

      {:ok, deck} = Expresso.to_deck(BackupDeck)

      assert Enum.map(deck.slides, &Slide.hidden?/1) == [false, true]
      assert deck.metadata.handout_hidden == true
    end

    test "a deck without the options has no hidden slide and no handout_hidden key" do
      deck = deck([1, 1], [])

      refute Enum.any?(deck.slides, &Slide.hidden?/1)
      refute Map.has_key?(deck.metadata, :handout_hidden)
    end

    test "the compiler refuses a value that is not a boolean" do
      assert_raise ArgumentError, ~r/invalid value for :hidden option/, fn ->
        Builder.deck([Builder.slide("s", hidden: :yes, elements: [])], name: "deck")
      end
    end
  end
end
