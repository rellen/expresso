defmodule Expresso.NotesPlainTest do
  # The tests change the application environment, so they do not run with
  # other tests.
  use ExUnit.Case, async: false

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Check.Document

  # A release, such as the binary of Burrito, does not hold MDEx. The setting
  # `notes_markdown: false` gives the notes of such a release.
  setup do
    Application.put_env(:expresso, :notes_markdown, false)
    on_exit(fn -> Application.delete_env(:expresso, :notes_markdown) end)
  end

  defp deck(slide_opts) do
    box = Builder.text_box(elements: [Builder.text_area(text: "A box")])
    one_slide([box, Builder.note("A note with `code`.", at: 1)], slide_opts)
  end

  test "markdown?/0 tells that the notes have no Markdown" do
    refute Expresso.Notes.markdown?()
  end

  test "a note shows its text as it is, in one paragraph" do
    document = document(deck(notes: "Say **hello**.\nThen <b>wait</b>."))

    assert texts(document, ".handout-page .note > p.note-plain") == [
             "Say **hello**.\nThen <b>wait</b>.",
             "A note with `code`."
           ]

    assert count(document, ".handout-page .note strong") == 0
    assert count(document, ".handout-page .note b") == 0
    assert count(document, ".handout-page .note code") == 0
  end

  test "the check gives a note for a deck with notes" do
    assert %{problems: [], notes: [note]} = Document.notes(deck(notes: "Say hello."))
    assert note =~ "The notes of the speaker show as plain text, because MDEx is not available."
  end

  test "the check gives no note for a deck with no notes" do
    box = Builder.text_box(elements: [Builder.text_area(text: "A box")])

    assert Document.notes(one_slide(box)) == %{problems: [], notes: []}
  end

  test "the check gives no note when MDEx is available" do
    Application.delete_env(:expresso, :notes_markdown)

    assert Document.notes(deck(notes: "Say hello.")) == %{problems: [], notes: []}
  end
end
