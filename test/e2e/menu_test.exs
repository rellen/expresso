defmodule Expresso.E2E.MenuTest do
  use Expresso.E2E, async: false

  # Three slides. Slide 2 has three steps with labels, and slide 3 has one step.
  defmodule Deck do
    use Expresso

    name "menu deck"

    slide "one" do
      heading "The start"

      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      heading "Three steps"
      labels ["The question", "The idea", "The answer"]

      list do
        reveal true
        item "A question"
        item "An idea"
        item "An answer"
      end
    end

    slide "three" do
      text_box do
        text_area(text: "Three")
      end
    end
  end

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    url = render(Deck, tmp_dir)
    %{page: open(page, url), context: context}
  end

  defp menu?(page), do: js(page, "document.body.dataset.menu === 'true'")

  defp display(page, selector),
    do: js(page, "getComputedStyle(document.querySelector('#{selector}')).display")

  defp marked(page, attribute) do
    js(page, """
    [...document.querySelectorAll(".menu-step[#{attribute}]")].map((row) => row.dataset.index)
    """)
  end

  # The center of an element of the menu, in the viewport.
  defp center(page, selector) do
    js(page, """
    (() => {
      const box = document.querySelector(#{inspect(selector)}).getBoundingClientRect();
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    })()
    """)
  end

  test "m shows the menu with the cursor at the current step, and the labels of the steps", %{
    page: page
  } do
    page |> keys(["j", "j"]) |> press("m")

    assert menu?(page)
    assert display(page, "#menu") == "block"
    assert marked(page, "data-cursor") == ["2"]
    assert marked(page, "data-current") == ["2"]

    assert js(
             page,
             "[...document.querySelectorAll('#menu .menu-label')].map((l) => l.textContent)"
           ) ==
             ["", "The question", "The idea", "The answer", ""]

    assert js(
             page,
             "[...document.querySelectorAll('#menu .menu-name')].map((n) => n.textContent)"
           ) ==
             ["The start", "Three steps", "three"]
  end

  test "j moves the cursor, the step does not change, and Enter goes to the cursor", %{
    page: page
  } do
    page |> press("m") |> keys(["j", "j", "j"])

    assert marked(page, "data-cursor") == ["3"]
    assert position(page) == "1.1"

    page |> press("Enter")

    refute menu?(page)
    assert display(page, "#menu") == "none"
    assert position(page) == "2.3"
  end

  test "Escape closes the menu at the same step", %{page: page} do
    page |> press("m") |> keys(["j", "Escape"])

    refute menu?(page)
    assert position(page) == "1.1"
  end

  test "a click on a step goes to it, and a click on a slide goes to its step 1", %{page: page} do
    page |> press("m")
    %{"x" => x, "y" => y} = center(page, ~s(.menu-step[data-index="3"]))
    page |> click(x, y)

    refute menu?(page)
    assert position(page) == "2.3"

    page |> press("m")
    %{"x" => x, "y" => y} = center(page, ".menu-group:nth-child(3) .menu-slide")
    page |> click(x, y)

    assert position(page) == "3.1"
  end

  test "the copy of each slide shows its last step", %{page: page} do
    page |> press("m")

    shown =
      js(page, """
      [...document.querySelectorAll('.menu-thumb li')]
        .filter((item) => getComputedStyle(item).visibility === 'visible')
        .map((item) => item.textContent.trim())
      """)

    assert Enum.uniq(shown) == ["A question", "An idea", "An answer"]
  end

  test "the menu of 30 slides scrolls to keep the cursor in view", %{page: page, tmp_dir: tmp_dir} do
    slides = for number <- 1..30, do: Expresso.Builder.slide("slide #{number}")
    deck = Expresso.Builder.deck(slides, name: "thirty slides")

    page |> open(render(deck, tmp_dir, "thirty") <> "#28") |> press("m")

    inside = """
    (() => {
      const menu = document.querySelector('#menu').getBoundingClientRect();
      const row = document.querySelector('.menu-step[data-cursor]').getBoundingClientRect();
      return row.top >= menu.top && row.bottom <= menu.bottom;
    })()
    """

    assert js(page, "document.querySelector('#menu').scrollTop") > 0
    assert js(page, inside)

    page |> keys(["j", "j"])
    assert js(page, inside)

    page |> keys(List.duplicate("k", 20))
    assert js(page, inside)
  end

  test "m in the speaker view shows the menu in that window only", %{
    page: audience,
    context: context
  } do
    speaker = popup(context, fn -> press(audience, "s") end)

    speaker |> press("m")
    assert menu?(speaker)
    refute menu?(audience)

    speaker |> keys(["j", "Enter"])

    wait_for(audience, "location.hash === '#2.1'")
    refute menu?(speaker)
  end
end
