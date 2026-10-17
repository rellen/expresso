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
end
