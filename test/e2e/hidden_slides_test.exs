defmodule Expresso.E2E.HiddenSlidesTest do
  use Expresso.E2E, async: false

  # Four slides. Slide 2 is hidden and has two steps, so the talk has three
  # slides. The last slide has a link to the hidden slide.
  defmodule Deck do
    use Expresso

    name "hidden deck"
    slide_numbers true

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "backup" do
      hidden true
      steps 2

      text_box do
        text_area(text: "Backup")
      end
    end

    slide "three" do
      text_box do
        text_area(text: "Three")
      end
    end

    slide "four" do
      text_box do
        text_area(text: "The numbers", goto: [slide: "backup"])
      end
    end
  end

  # The first slide is hidden, so the first page of the document does not
  # print.
  defmodule FirstDeck do
    use Expresso

    name "first deck"

    slide "backup" do
      hidden true
      steps 2

      text_box do
        text_area(text: "Backup")
      end
    end

    slide "one" do
      steps 2

      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  # The same deck with the hidden slide on paper.
  defmodule PrintedDeck do
    use Expresso

    name "printed deck"
    handout_hidden true

    slide "backup" do
      hidden true

      text_box do
        text_area(text: "Backup")
      end
    end

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  defp fraction(page),
    do: js(page, "document.body.style.getPropertyValue('--fraction')")

  # The text of the number of the slide that shows, or nil.
  defp number(page) do
    js(page, """
    [...document.querySelectorAll(".screen .slide")]
      .find((slide) => getComputedStyle(slide).display !== "none")
      .querySelector(".slide-number")?.textContent ?? null
    """)
  end

  # The center of the thumbnail of a slide in the overview, in the viewport.
  defp thumbnail(page, slide) do
    js(page, """
    (() => {
      const box = document
        .querySelector('.handout-page[data-thumbnail][data-slide="#{slide}"]')
        .getBoundingClientRect();
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    })()
    """)
  end

  test "j and k skip the hidden slide, and the slide numbers count only the talk", %{page: page} do
    page |> press("j")
    assert position(page) == "3.1"
    assert number(page) == "2 / 3"

    page |> press("j")
    assert position(page) == "4.1"
    assert number(page) == "3 / 3"

    page |> keys(["k", "k"])
    assert position(page) == "1.1"
  end

  test "the progress bar counts only the steps of the talk", %{page: page} do
    assert fraction(page) == "0"

    page |> press("j")
    assert fraction(page) == "0.5"

    page |> press("j")
    assert fraction(page) == "1"
  end

  test "a link goes to the hidden slide, and j goes through its steps into the talk", %{
    page: page
  } do
    page |> keys(["End"])
    assert position(page) == "4.1"

    js(page, "document.querySelector('.screen a.goto').click()")
    assert position(page) == "2.1"
    assert number(page) == nil
    # The bar stays at the place of the slide of the talk before the hidden slide.
    assert fraction(page) == "0"

    page |> press("j")
    assert position(page) == "2.2"

    page |> press("j")
    assert position(page) == "3.1"
  end

  test "a typed number goes to the slide of the talk with that number", %{page: page} do
    page |> keys(["2", "Enter"])
    assert position(page) == "3.1"

    page |> keys(["4", "Enter"])
    assert position(page) == "3.1"
  end

  test "the overview shows the hidden slide with a mark, and a click goes to it", %{page: page} do
    page |> press("o")

    assert shown_pages(page) == ["1.1", "2.2", "3.1", "4.1"]

    assert js(page, """
           [...document.querySelectorAll(".handout-page[data-thumbnail]")]
             .map((page) => getComputedStyle(page).outlineStyle)
           """) == ["solid", "dashed", "solid", "solid"]

    assert js(page, """
           getComputedStyle(document.querySelector(
             '.handout-page[data-thumbnail][data-hidden] > *')).opacity
           """) == "0.45"

    %{"x" => x, "y" => y} = thumbnail(page, 2)
    page |> click(x, y)

    assert position(page) == "2.1"
  end

  test "the menu lists the hidden slide with a dash, and Enter goes to it", %{page: page} do
    page |> press("m")

    assert js(page, """
           [...document.querySelectorAll("#menu .menu-slide > .menu-number")]
             .map((number) => [...number.childNodes].map((node) => node.textContent.trim()))
           """) == [["1"], ["Hidden slide", "–"], ["2"], ["3"]]

    page |> keys(["j", "Enter"])
    assert position(page) == "2.1"
  end

  test "the handout view leaves the hidden slide out, and a does not show it", %{page: page} do
    page |> press("p")
    assert shown_pages(page) == ["1.1", "3.1", "4.1"]

    page |> press("a")
    assert shown_pages(page) == ["1.1", "3.1", "4.1"]
  end

  test "the speaker view shows the step after the hidden slide as the next step", %{
    page: audience,
    context: context
  } do
    speaker = popup(context, fn -> press(audience, "s") end)

    marks = """
    [...document.querySelectorAll(".handout-page[data-speaker]")]
      .map((page) => page.dataset.speaker + " " + page.dataset.slide + "." + page.dataset.step)
    """

    assert js(speaker, marks) == ["current 1.1", "next 3.1"]

    assert js(speaker, "document.getElementById('speaker-position').textContent") ==
             "Slide 1 of 3"
  end

  test "paper leaves the hidden slide out, and a hidden first slide gives no empty sheet", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    assert pdf_pages(page) == 3

    page = open(page, render(FirstDeck, tmp_dir, "first"))
    # The deck starts at the first slide of the talk.
    assert position(page) == "2.1"
    assert pdf_pages(page) == 3

    # Each step: the two steps of slide "one", and slide "two".
    page |> keys(["p", "a"])
    assert shown_pages(page) == ["2.1", "2.2", "3.1"]
    assert pdf_pages(page) == 3
  end

  test "the handout_hidden option shows the hidden slide in the handout view and on paper", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(PrintedDeck, tmp_dir, "printed"))

    assert position(page) == "2.1"
    assert pdf_pages(page) == 2

    page |> press("p")
    assert shown_pages(page) == ["1.1", "2.1"]
  end
end
