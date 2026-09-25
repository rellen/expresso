defmodule Expresso.E2E.OverviewTest do
  use Expresso.E2E, async: false

  # Five slides. Slide 2 has three steps, and slide 3 has two steps. The
  # overview has three columns.
  defmodule Deck do
    use Expresso

    name "overview deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      steps 3

      text_box do
        text_area(text: "Two")
      end

      text_box do
        at from: 3
        text_area(text: "Only at step 3")
      end
    end

    slide "three" do
      steps 2

      text_box do
        text_area(text: "Three")
      end
    end

    slide "four" do
      text_box do
        text_area(text: "Four")
      end
    end

    slide "five" do
      text_box do
        text_area(text: "Five")
      end
    end
  end

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    url = render(Deck, tmp_dir)
    %{page: open(page, url), url: url, context: context}
  end

  defp overview?(page), do: js(page, "document.body.dataset.overview === 'true'")

  defp selected(page) do
    js(page, """
    [...document.querySelectorAll(".handout-page[data-selected]")]
      .map((page) => page.dataset.slide + "." + page.dataset.step)
    """)
  end

  # The box of the thumbnail of a slide, in the viewport.
  defp box(page, slide) do
    js(page, """
    (() => {
      const box = document
        .querySelector('.handout-page[data-thumbnail][data-slide="#{slide}"]')
        .getBoundingClientRect();
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    })()
    """)
  end

  # The boxes of the pages that show, in the viewport.
  defp boxes(page) do
    js(page, """
    [...document.querySelectorAll(".handout-page")]
      .filter((page) => getComputedStyle(page).display !== "none")
      .map((page) => {
        const box = page.getBoundingClientRect();
        return [box.left, box.top, box.right, box.bottom];
      })
    """)
  end

  defp display(page, selector),
    do: js(page, "getComputedStyle(document.querySelector('#{selector}')).display")

  test "o shows the last step of each slide in a grid that fits the window", %{page: page} do
    page |> keys(["j", "j"]) |> press("o")

    assert overview?(page)
    assert shown_pages(page) == ["1.1", "2.3", "3.2", "4.1", "5.1"]
    assert selected(page) == ["2.3"]
    assert display(page, ".screen") == "none"
    assert display(page, "#progress") == "none"
    assert js(page, "location.hash") == "#2.2"

    # Three columns and two rows, each inside the viewport.
    boxes = boxes(page)

    assert boxes
           |> Enum.map(fn [_left, top, _right, _bottom] -> round(top) end)
           |> Enum.uniq()
           |> length() == 2

    assert boxes
           |> Enum.map(fn [left, _top, _right, _bottom] -> round(left) end)
           |> Enum.uniq()
           |> length() == 3

    for [left, top, right, bottom] <- boxes do
      assert left >= 0 and top >= 0 and right <= 1280 and bottom <= 720
    end

    # The thumbnail of slide 2 shows its last step.
    assert js(page, """
           getComputedStyle([...document.querySelectorAll('.handout-page[data-thumbnail][data-slide="2"] .text-area')]
             .find((area) => area.textContent.includes("Only at step 3"))).visibility
           """) == "visible"
  end

  test "the arrow keys select a slide, and Enter goes to step 1 of that slide", %{
    page: page
  } do
    page |> press("o") |> keys(["ArrowRight", "ArrowDown"])
    assert selected(page) == ["5.1"]

    page |> keys(["ArrowUp", "ArrowRight", "Enter"])

    refute overview?(page)
    assert position(page) == "3.1"
    assert display(page, ".screen") == "flex"
  end

  test "Escape and o close the overview at the same step", %{page: page} do
    page |> keys(["j", "j", "o", "End", "Escape"])
    refute overview?(page)
    assert position(page) == "2.2"

    page |> keys(["o", "Home", "o"])
    refute overview?(page)
    assert position(page) == "2.2"
  end

  test "a click on a slide of the overview goes to step 1 of that slide", %{page: page} do
    page |> press("o")
    %{"x" => x, "y" => y} = box(page, 4)

    page |> click(x, y)

    refute overview?(page)
    assert position(page) == "4.1"
  end

  test "? lists the keys of the overview, and the next key closes only the list", %{
    page: page
  } do
    page |> press("o") |> press("Shift+Slash")

    help = js(page, "document.getElementById('help').innerText")
    assert help =~ "Select the next slide"
    assert help =~ "Click or tap a slide"
    refute help =~ "Handout view"

    page |> press("Enter")
    assert js(page, "document.body.dataset.help") == nil
    assert overview?(page)
    assert position(page) == "1.1"
  end

  test "o in the speaker view shows the overview in that window only", %{
    page: audience,
    context: context
  } do
    speaker = popup(context, fn -> press(audience, "s") end)

    speaker |> press("o")
    assert overview?(speaker)
    assert display(speaker, "#speaker-timer") == "none"
    assert length(boxes(speaker)) == 5
    refute overview?(audience)

    speaker |> keys(["End", "Enter"])

    wait_for(audience, "location.hash === '#5.1'")
    refute overview?(speaker)
    refute overview?(audience)
  end

  test "the overview of 30 slides fits the window with no scroll", %{page: page, tmp_dir: tmp_dir} do
    deck =
      Enum.reduce(1..30, Expresso.Deck.new("thirty slides"), fn number, deck ->
        Expresso.Deck.add_slide(deck, "slide #{number}", %{}, [])
      end)

    page |> open(render(deck, tmp_dir, "thirty")) |> press("o")

    boxes = boxes(page)
    assert length(boxes) == 30

    for [left, top, right, bottom] <- boxes do
      assert left >= 0 and top >= 0 and right <= 1280 and bottom <= 720
    end

    assert js(page, "document.scrollingElement.scrollHeight <= innerHeight")
  end
end
