defmodule Expresso.NotesTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  defmodule NotesDeck do
    use Expresso

    name "notes deck"

    slide "with notes" do
      heading "One"
      notes "Say hello.\nThen <b>pause</b>."
      steps 2

      text_box do
        text_area(text: "A box")
      end
    end

    slide "without notes" do
      text_box do
        text_area(text: "Another box")
      end
    end
  end

  defmodule UnprintedNotesDeck do
    use Expresso

    name "unprinted notes deck"
    print_notes false

    slide "with notes" do
      notes "Only for the speaker."

      text_box do
        text_area(text: "A box")
      end
    end
  end

  test "the slide entity puts the notes option into the metadata" do
    [with_notes, without] = Expresso.parse(NotesDeck).slides

    assert with_notes.metadata.notes == "Say hello.\nThen <b>pause</b>."
    assert with_notes.metadata.heading == "One"
    refute Map.has_key?(without.metadata, :notes)
  end

  test "the handout view shows the notes under each page of the slide" do
    document = document(NotesDeck)

    pages = LazyHTML.query(document, ".handout-page[data-slide='1']")
    assert Enum.count(pages) == 2

    for page <- pages do
      assert [aside] = page |> LazyHTML.query(".handout-page > aside.notes") |> Enum.to_list()
      assert LazyHTML.text(aside) == "Say hello.\nThen <b>pause</b>."
      assert aside |> LazyHTML.filter(":not(:has(b))") |> Enum.count() == 1
    end

    assert count(document, ".handout-page[data-slide='2']:not(:has(aside.notes))") == 1
  end

  test "the present view does not show the notes" do
    document = document(NotesDeck)

    assert count(document, ".screen:not(:has(aside.notes))") == 1
  end

  test "a slide from the builder takes the notes option" do
    box = Expresso.Builder.text_box(elements: [Expresso.Builder.text_area(text: "A box")])

    deck =
      Expresso.Builder.deck([
        Expresso.Builder.slide("one", notes: "From the builder", elements: [box])
      ])

    assert deck |> document() |> texts(".handout-page aside.notes") == ["From the builder"]
  end

  defp print_notes(document) do
    document |> LazyHTML.query("body") |> LazyHTML.attribute("data-print-notes")
  end

  test "a deck prints the notes without the print_notes option" do
    assert Expresso.parse(NotesDeck).metadata.print_notes == true
    assert NotesDeck |> document() |> print_notes() == ["true"]
  end

  test "print_notes false marks the body, and the notes stay for the speaker view" do
    deck = Expresso.parse(UnprintedNotesDeck)
    document = document(deck)

    assert deck.metadata.print_notes == false
    assert print_notes(document) == ["false"]

    assert texts(document, ".handout-page aside.notes") == ["Only for the speaker."]
  end

  test "a deck struct takes print_notes from its metadata" do
    assert "deck" |> Expresso.Deck.new() |> document() |> print_notes() == ["true"]

    assert "deck"
           |> Expresso.Deck.new(%{print_notes: false})
           |> document()
           |> print_notes() == ["false"]
  end

  describe "the Markdown of a note" do
    doctest Expresso.Notes

    defp note_html(text), do: LazyHTML.from_fragment(Expresso.Notes.html(text))

    test "makes bold text, italic text, code and a link" do
      html =
        note_html("**Bold**, *italic*, ~~old~~, `code` and [a link](https://example.com/a).")

      assert texts(html, "strong") == ["Bold"]
      assert texts(html, "em") == ["italic"]
      assert texts(html, "del") == ["old"]
      assert texts(html, "code") == ["code"]
      assert LazyHTML.attribute(LazyHTML.query(html, "a"), "href") == ["https://example.com/a"]
    end

    test "makes a list with bullets, a list with numbers and a block of code" do
      html = note_html("- one\n- two\n\n1. first\n2. second\n\n```\nmix test\n```\n")

      assert texts(html, "ul > li") == ["one", "two"]
      assert texts(html, "ol > li") == ["first", "second"]
      assert texts(html, "pre > code") == ["mix test\n"]
    end

    test "makes a link of an address" do
      html = note_html("See https://example.com/b for more.")

      assert LazyHTML.attribute(LazyHTML.query(html, "a"), "href") == ["https://example.com/b"]
    end

    test "keeps each line break of a paragraph" do
      html = note_html("The first line.\nThe second line.")

      assert count(html, "p") == 1
      assert count(html, "p > br") == 1
    end

    test "shows HTML as text" do
      html = note_html("Press <Enter>, <b>not</b> <script>alert(1)</script>.")

      assert count(html, "b") == 0
      assert count(html, "script") == 0
      assert LazyHTML.text(html) =~ "Press <Enter>, <b>not</b> <script>alert(1)</script>."
    end

    test "gives no address to a link that runs a script" do
      html = note_html("[run](javascript:alert(1))")

      assert LazyHTML.attribute(LazyHTML.query(html, "a"), "href") == [""]
    end

    test "returns the text of a note with no Markdown as one paragraph" do
      assert Expresso.Notes.plain("  One *line*.\nTwo <b>lines</b>.\n") ==
               ~s(<p class="note-plain">One *line*.\nTwo &lt;b&gt;lines&lt;/b&gt;.</p>)
    end
  end

  describe "a note of a step" do
    doctest Expresso.Element.Note

    alias Expresso.Builder
    alias Expresso.Element.Note

    defmodule StepNotesDeck do
      use Expresso

      name "step notes deck"

      slide "steps" do
        notes "For **each** step."

        text_box do
          at from: 2
          text_area(text: "Two")
        end

        text_box do
          at from: 3
          text_area(text: "Three")
        end

        note "Ask the *room*.", at: 2
        note "Show the answer.", at: [from: 3]
        note at: 1..2, text: "Do not go too fast."
      end

      slide "last" do
        handout :last

        text_box do
          at from: 2
          text_area(text: "Two")
        end

        text_box do
          at from: 3
          text_area(text: "Three")
        end

        note "The first.", at: 1
        note "The first two.", at: 1..2
        note "The last.", at: 3
        note "At each step."
      end
    end

    # The text of each note of the page of a step of a slide, and the label of
    # a note of an earlier step.
    defp page_notes(document, slide, step) do
      document
      |> LazyHTML.query(~s(.handout-page[data-slide="#{slide}"][data-step="#{step}"] .note))
      |> Enum.map(fn note ->
        case texts(note, ".note-step") do
          [] -> LazyHTML.text(note)
          [label] -> {label, note |> LazyHTML.query("p") |> LazyHTML.text()}
        end
      end)
    end

    test "the note entity puts the text and the steps into a note of the slide" do
      [slide | _rest] = Expresso.parse(StepNotesDeck).slides

      assert slide |> Note.of_slide() |> Enum.map(&{&1.text, &1.steps}) == [
               {"Ask the *room*.", [2]},
               {"Show the answer.", [3]},
               {"Do not go too fast.", [1, 2]}
             ]
    end

    test "a note adds no step to its slide and shows nothing on the slide" do
      [slide | _rest] = Expresso.parse(StepNotesDeck).slides
      document = document(StepNotesDeck)

      assert slide.metadata.max_step == 3
      assert texts(document, "#slide-1 .text-area") == ["Two", "Three"]
      assert count(document, ".screen .note") == 0
    end

    test "the page of a step shows the note of the slide, then the notes of the step" do
      document = document(StepNotesDeck)

      assert page_notes(document, 1, 1) == ["For each step.", "Do not go too fast."]

      assert page_notes(document, 1, 2) == [
               "For each step.",
               "Ask the room.",
               "Do not go too fast."
             ]

      assert page_notes(document, 1, 3) == ["For each step.", "Show the answer."]
      assert count(document, ~s(.handout-page[data-slide="1"] .note em)) == 1
      assert count(document, ~s(.handout-page[data-slide="1"] .note[data-covered])) == 0
    end

    test "a page of the handout view also shows the notes of the steps with no page" do
      document = document(StepNotesDeck)

      assert page_notes(document, 2, 3) == [
               {"Step 1", "The first."},
               {"Steps 1, 2", "The first two."},
               "The last.",
               "At each step."
             ]

      assert count(document, ~s(.handout-page[data-slide="2"][data-step="3"] .note[data-covered])) ==
               2
    end

    test "a page that the handout view does not show has only the notes of its step" do
      document = document(StepNotesDeck)

      assert page_notes(document, 2, 1) == ["The first.", "The first two.", "At each step."]
      assert page_notes(document, 2, 2) == ["The first two.", "At each step."]
    end

    test "a slide with only a note of a step has notes on the page of that step only" do
      box = Builder.text_box(elements: [Builder.text_area(text: "A box")], at: [from: 2])
      document = document(one_slide([box, Builder.note("Only at two.", at: 2)]))

      assert count(document, ~s(.handout-page[data-step="1"] aside.notes)) == 0
      assert texts(document, ~s(.handout-page[data-step="2"] aside.notes)) == ["Only at two."]
    end

    test "the builder takes the text as an argument or as an option" do
      assert %Note{text: "one", at: %Expresso.Overlay{pairs: [{2, 2}]}} =
               Builder.note("one", at: 2)

      assert %Note{text: "two", at: nil} = Builder.note(text: "two")
    end

    test "a note takes no step from the counter, also with auto_reveal" do
      area = &Builder.text_box(elements: [Builder.text_area(text: &1)])

      {:ok, slide} =
        Expresso.Overlay.Expand.slide(
          Builder.slide("s",
            auto_reveal: true,
            elements: [area.("one"), Builder.note("a note"), area.("two")]
          )
        )

      assert Enum.map(slide.elements, & &1.steps) == [[1, 2], nil, [2]]
      assert slide.metadata.max_step == 2
    end

    test "a step that the slide does not have is an error" do
      slide = Builder.slide("s", elements: [Builder.note("late", at: 4)], steps: 2)

      assert Expresso.Overlay.Expand.slide(slide) ==
               {:error,
                "a note has the step 4, and the slide has 2 steps. A note does not add a step " <>
                  "to its slide"}
    end

    test "the at option takes no :next" do
      assert {:error, message} = Note.at(:next)
      assert message =~ "the at option of a note cannot hold :next"

      assert {:error, message} = Note.at(from: :next)
      assert message =~ "the at option of a note cannot hold :next"

      assert_raise ArgumentError, ~r/the at option of a note cannot hold :next/, fn ->
        Builder.note("one", at: :next)
      end
    end

    test "a note inside an element is refused" do
      box = Builder.text_box(elements: [Builder.note("inside")])

      assert {:error, message} = Expresso.Placement.slide(Builder.slide("s", elements: [box]))
      assert message =~ "a note is inside a text_box"
    end
  end
end
