defmodule Expresso.E2E.FootnoteTest do
  use Expresso.E2E, async: false

  # Two slides with a footnote each. The footnote of slide 2 shows at step 2.
  defmodule Deck do
    use Expresso

    slide "first" do
      text_box do
        text_area(text: "A claim.<sup>1</sup>")
      end

      footnote "The first source."
    end

    slide "second" do
      steps 2

      text_box do
        text_area(text: "A second claim.")
      end

      footnote "The second source.", at: [from: 2]
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # An element of a hidden view keeps its own `display`, so the test asks the
  # browser whether the element shows, with its `visibility` too.
  defp visible?(page, selector),
    do:
      js(
        page,
        "document.querySelector('#{selector}').checkVisibility({visibilityProperty: true})"
      )

  test "a footnote shows at the bottom of the slide, and at its step", %{page: page} do
    assert visible?(page, "#slide-1 li.footnote")

    {top, bottom} =
      {js(page, "document.querySelector('#slide-1 ol.footnotes').getBoundingClientRect().top"),
       js(page, "innerHeight")}

    assert top > bottom * 0.8

    page |> press("j")
    refute visible?(page, "#slide-2 li.footnote")

    page |> press("j")

    wait_for(
      page,
      "document.querySelector('#slide-2 li.footnote').checkVisibility({visibilityProperty: true})"
    )
  end

  test "the page of the sources shows in the handout view, and not in the overview or the speaker view",
       %{page: page, context: context} do
    refute visible?(page, ".sources")

    page |> press("p")
    assert visible?(page, ".sources")
    assert js(page, "document.querySelector('.sources').innerText") =~ "The second source."

    page |> press("p")
    page |> press("o")
    refute visible?(page, ".sources")
    page |> press("o")

    speaker = popup(context, fn -> press(page, "s") end)
    refute visible?(speaker, ".sources")
  end
end
