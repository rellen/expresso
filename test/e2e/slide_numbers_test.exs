defmodule Expresso.E2E.SlideNumbersTest do
  use Expresso.E2E, async: false

  # Three slides with slide numbers. Slide 2 has notes.
  defmodule Deck do
    use Expresso

    name "numbered deck"
    slide_numbers true

    slide "title" do
      text_box do
        text_area(text: "Title")
      end
    end

    slide "two" do
      notes "The notes of slide 2."

      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
      text_box do
        text_area(text: "Three")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # The text and the box of each number that a reader sees, in the viewport.
  defp numbers(page) do
    js(page, """
    [...document.querySelectorAll(".slide-number")]
      .filter((number) => number.checkVisibility({ visibilityProperty: true }))
      .map((number) => {
        const box = number.getBoundingClientRect();
        return { text: number.textContent, right: box.right, bottom: box.bottom, top: box.top };
      })
    """)
  end

  test "the present view shows the number in the corner of the window, and slide 1 shows none",
       %{page: page} do
    assert numbers(page) == []

    page |> press("j")
    assert [%{"text" => "2 / 3", "right" => right, "bottom" => bottom}] = numbers(page)
    assert right > 1280 - 40 and right <= 1280
    assert bottom > 720 - 30 and bottom <= 720

    page |> press("j")
    assert [%{"text" => "3 / 3"}] = numbers(page)
  end

  test "a black screen hides the number", %{page: page} do
    page |> keys(["j", "b"])

    assert js(
             page,
             "getComputedStyle(document.querySelector('#slide-2 .slide-number')).visibility"
           ) ==
             "hidden"
  end

  test "a page of the handout view shows the number in its right corner, above the notes",
       %{page: page} do
    page |> press("p")

    [number] =
      js(page, """
      [...document.querySelectorAll('.handout-page[data-slide="2"]')].map((page) => {
        const number = page.querySelector(".slide-number").getBoundingClientRect();
        const notes = page.querySelector(".notes").getBoundingClientRect();
        const box = page.getBoundingClientRect();
        return { gap: box.right - number.right, above: notes.top - number.bottom };
      })
      """)

    assert number["gap"] >= 0 and number["gap"] < 40
    assert number["above"] >= 0

    assert js(page, "document.querySelector('.handout-page[data-slide=\"1\"] .slide-number')") ==
             nil
  end
end
