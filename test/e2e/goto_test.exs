defmodule Expresso.E2E.GotoTest do
  use Expresso.E2E, async: false

  # Three slides. Slide 1 has a link to slide 3, and slide 2 has two steps.
  defmodule Deck do
    use Expresso

    name "goto deck"

    slide "contents" do
      text_box do
        text_area(text: "Go to the summary", goto: [slide: 3])
      end

      # The HTML of a text area can hold `data-commands`. The script does not
      # run commands that the renderer did not write.
      text_box do
        text_area(text: ~s(<span class="stray" data-commands='[["goto",3]]'>Not a link</span>))
      end
    end

    slide "details" do
      steps 2

      text_box do
        text_area(text: "Details")
      end
    end

    slide "summary" do
      text_box do
        text_area(text: "Summary")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # The center of the first element that a selector finds and that shows, in
  # the viewport.
  defp center(page, selector) do
    js(page, """
    (() => {
      const box = [...document.querySelectorAll('#{selector}')]
        .map((element) => element.getBoundingClientRect())
        .find((box) => box.width > 0);
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    })()
    """)
  end

  test "a click on a link goes to its slide, and the history gets no entry", %{page: page} do
    entries = js(page, "history.length")
    %{"x" => x, "y" => y} = center(page, ".screen a.goto")

    page |> click(x, y)

    assert position(page) == "3.1"
    assert js(page, "location.hash") == "#3.1"
    assert js(page, "history.length") == entries
  end

  test "a click on data-commands in the HTML of a deck runs no commands", %{page: page} do
    %{"x" => x, "y" => y} = center(page, ".screen .stray")

    page |> click(x, y)

    # The click is a plain click, so it goes to the next step or it does nothing.
    assert position(page) in ["1.1", "2.1"]
  end

  test "Tab and Enter on a link go to its slide", %{page: page} do
    page |> press("Tab")
    assert js(page, "document.activeElement.getAttribute('href')") == "#3.1"

    page |> press("Enter")
    assert position(page) == "3.1"
  end

  test "a click on a link in the overview goes to the slide of the page", %{page: page} do
    page |> press("j") |> press("o")
    %{"x" => x, "y" => y} = center(page, ".handout-page[data-thumbnail] a.goto")

    page |> click(x, y)

    assert js(page, "document.body.dataset.overview") == nil
    assert position(page) == "1.1"
  end

  test "the list of keys of the present view names a click on a link", %{page: page} do
    page |> press("Shift+Slash")

    assert js(page, "document.getElementById('help').innerText") =~ "Click or tap a link"
  end
end
