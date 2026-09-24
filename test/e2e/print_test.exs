defmodule Expresso.E2E.PrintTest do
  use Expresso.E2E, async: false

  # Slide 1 has three steps, and its handout option selects step 2 and the
  # last step. Slide 2 has two steps, and its handout option selects step 1,
  # so the last page of the document is a page that the view does not show.
  defmodule SelectedDeck do
    use Expresso

    name "selected deck"

    slide "three steps" do
      handout [2, :last]
      steps 3

      text_box do
        text_area(text: "One")
      end
    end

    slide "two steps" do
      handout 1
      steps 2

      text_box do
        text_area(text: "Two")
      end
    end
  end

  # No handout option, so each step gets a page.
  defmodule EveryDeck do
    use Expresso

    name "every deck"

    slide "two steps" do
      steps 2

      text_box do
        text_area(text: "One")
      end
    end

    slide "one step" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  # Notes on slide 1, and print_notes false. The speaker view still needs
  # the notes.
  defmodule UnprintedNotesDeck do
    use Expresso

    name "unprinted notes deck"
    print_notes false

    slide "with notes" do
      notes "Only for the speaker."

      text_box do
        text_area(text: "One")
      end
    end
  end

  defp notes_display(page) do
    js(page, "getComputedStyle(document.querySelector('.handout-page .notes')).display")
  end

  test "a deck with no handout option prints one page for each step", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(EveryDeck, tmp_dir))

    assert pdf_pages(page) == 3
  end

  test "the handout option selects the printed pages, with no blank sheet at the end", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(SelectedDeck, tmp_dir))

    assert pdf_pages(page) == 3
  end

  test "the handout view on a screen shows the pages of the print", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = page |> open(render(SelectedDeck, tmp_dir)) |> press("p")

    assert shown_pages(page) == ["1.2", "1.3", "2.1"]
  end

  test "a in the handout view shows and prints every step, and a again the selection", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = page |> open(render(SelectedDeck, tmp_dir)) |> keys(["p", "a"])

    assert shown_pages(page) == ["1.1", "1.2", "1.3", "2.1", "2.2"]
    assert pdf_pages(page) == 5

    page |> press("a")
    assert pdf_pages(page) == 3
  end

  test "?all in the address prints every step with no key", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(SelectedDeck, tmp_dir) <> "?all")

    assert position(page) == "1.1"
    assert pdf_pages(page) == 5
  end

  test "a print from the speaker view gets the same pages as the present view", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(SelectedDeck, tmp_dir) <> "?speaker")

    assert js(page, "document.body.dataset.view") == "speaker"
    assert pdf_pages(page) == 3
  end

  test "the notes print by default", %{page: page, tmp_dir: tmp_dir} do
    deck =
      "deck"
      |> Expresso.Deck.new()
      |> Expresso.Deck.add_slide("one", %{notes: "For the audience too."})

    page = page |> open(render(deck, tmp_dir)) |> emulate("print")

    assert notes_display(page) == "block"
  end

  test "print_notes false leaves the notes out of the print, and the speaker view keeps them",
       %{page: page, tmp_dir: tmp_dir} do
    url = render(UnprintedNotesDeck, tmp_dir)
    page = open(page, url)

    assert pdf_pages(page) == 1
    assert page |> emulate("print") |> notes_display() == "none"

    speaker = page |> emulate("screen") |> open(url <> "?speaker")

    assert js(speaker, "document.getElementById('speaker-notes').textContent") ==
             "Only for the speaker."
  end
end
