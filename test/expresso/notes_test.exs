defmodule Expresso.NotesTest do
  use ExUnit.Case, async: true

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

  defp document(deck) do
    deck |> Expresso.Deck.render() |> Floki.parse_document!()
  end

  test "the slide entity puts the notes option into the metadata" do
    [with_notes, without] = Expresso.parse(NotesDeck).slides

    assert with_notes.metadata.notes == "Say hello.\nThen <b>pause</b>."
    assert with_notes.metadata.heading == "One"
    refute Map.has_key?(without.metadata, :notes)
  end

  test "the handout view shows the notes under each page of the slide" do
    document = NotesDeck |> Expresso.parse() |> document()

    pages = Floki.find(document, ".handout-page[data-slide='1']")
    assert length(pages) == 2

    for page <- pages do
      assert [aside] = Floki.find([page], ":root > aside.notes")
      assert Floki.text(aside) == "Say hello.\nThen <b>pause</b>."
      assert [] = Floki.find([aside], "b")
    end

    assert [] = Floki.find(document, ".handout-page[data-slide='2'] aside.notes")
  end

  test "the present view does not show the notes" do
    document = NotesDeck |> Expresso.parse() |> document()

    assert [] = Floki.find(document, ".screen aside.notes")
  end

  test "a slide from the imperative API takes the notes from its metadata" do
    deck =
      Expresso.Deck.new("deck")
      |> Expresso.Deck.add_slide("one", %{notes: "From the metadata"}, [
        Expresso.Element.TextBox.new("A box")
      ])

    assert deck |> document() |> Floki.find(".handout-page aside.notes") |> Floki.text() ==
             "From the metadata"
  end

  defp print_notes(document) do
    document |> Floki.find("body") |> Floki.attribute("data-print-notes")
  end

  test "a deck prints the notes without the print_notes option" do
    assert Expresso.parse(NotesDeck).metadata.print_notes == true
    assert NotesDeck |> Expresso.parse() |> document() |> print_notes() == ["true"]
  end

  test "print_notes false marks the body, and the notes stay for the speaker view" do
    deck = Expresso.parse(UnprintedNotesDeck)
    document = document(deck)

    assert deck.metadata.print_notes == false
    assert print_notes(document) == ["false"]

    assert document |> Floki.find(".handout-page aside.notes") |> Floki.text() ==
             "Only for the speaker."
  end

  test "a deck from the imperative API takes print_notes from its metadata" do
    assert "deck" |> Expresso.Deck.new() |> document() |> print_notes() == ["true"]

    assert "deck"
           |> Expresso.Deck.new(%{print_notes: false})
           |> document()
           |> print_notes() == ["false"]
  end
end
