defmodule Expresso.E2E.SlideLayoutTest do
  use Expresso.E2E, async: false

  # Slide 1 has a heading and two columns. Slide 2 has two code elements in
  # one parent, and slide 3 has one code element.
  defmodule Deck do
    use Expresso

    slide "columns" do
      heading "Columns"

      columns do
        column do
          text_area(text: "Left")
        end

        column do
          text_area(text: "Right")
        end
      end
    end

    slide "two codes" do
      code "elixir" do
        text "a = 1"
      end

      code "elixir" do
        text "defmodule Long do\n  def name, do: :long\nend"
      end
    end

    slide "one code" do
      code "elixir" do
        text "a = 1"
      end
    end
  end

  # The same slides, with a padding and a heading at the left from the deck.
  defmodule CssDeck do
    use Expresso

    css ~S"""
    :root { --slide-padding: 0 2rem; }
    h1 { text-align: left; }
    """

    slide "columns" do
      heading "Columns"
      text_area(text: "Text")
    end
  end

  # A text box with a short text that moves 300 px at step 2, and a text that
  # moves past the right edge at step 3.
  defmodule MoveDeck do
    use Expresso

    slide "move" do
      text_box do
        on [from: 2], set: [x: "-300px"]
        text_area(text: "A short text")
      end

      text_box do
        on [from: 3], set: [x: "2000px"]
        text_area(text: "Away")
      end
    end
  end

  # The boxes of the slide that shows. The other slides have no box.
  defp boxes(page, selector) do
    js(page, """
    Array.from(document.querySelectorAll(".screen #{selector}"))
      .filter((element) => element.getClientRects().length > 0)
      .map((element) => {
      const box = element.getBoundingClientRect();
      return {left: box.left, right: box.right, width: box.width};
    })
    """)
  end

  defp padding(page) do
    js(page, ~s|getComputedStyle(document.querySelector(".screen .slide-body")).paddingLeft|)
  end

  test "a slide takes the full width of the window, with a padding of 1rem at each side", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    width = js(page, "window.innerWidth")

    assert [body] = boxes(page, ".slide-body")
    assert body["left"] == 0
    assert body["width"] == width
    assert padding(page) == "48px"

    # Each column takes half of the width, without the padding and the gap.
    assert [left, right] = boxes(page, ".column")
    assert_in_delta left["width"], (width - 3 * 48) / 2, 1
    assert_in_delta right["width"], left["width"], 1
    assert_in_delta left["left"], 48, 1
  end

  test "the heading is in the center, with no style of its own", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    assert js(page, ~s|document.querySelector(".screen h1").getAttribute("style")|) == nil

    assert js(page, ~s|getComputedStyle(document.querySelector(".screen h1")).textAlign|) ==
             "center"
  end

  test "the css option changes the padding, and a rule h1 puts the heading at the left", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(CssDeck, tmp_dir))

    assert padding(page) == "96px"

    assert js(page, ~s|getComputedStyle(document.querySelector(".screen h1")).textAlign|) ==
             "left"
  end

  test "code elements of one parent start at one left edge, and one code element stays in the center",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir) <> "#2")

    assert [first, second] = boxes(page, ".code pre")
    assert first["width"] < second["width"]
    assert_in_delta first["left"], second["left"], 1
    assert_in_delta first["left"], 48, 1

    page = open(page, render(Deck, tmp_dir, "one") <> "#3")
    width = js(page, "window.innerWidth")

    assert [code] = boxes(page, ".code pre")
    assert_in_delta (code["left"] + code["right"]) / 2, width / 2, 1
  end

  test "the layout check measures the text of a box that moves, and not the box", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page =
      page
      |> open(render(MoveDeck, tmp_dir) <> "?check")
      |> wait_for("document.body.dataset.layout !== undefined")

    problems =
      js(
        page,
        ~s|Array.from(document.querySelectorAll("#layout-check li a")).map((a) => a.textContent)|
      )

    assert [problem] = problems
    assert problem =~ ~r/^Slide 1, step 3: the text area “Away” goes \d+ px past the right edge$/
  end
end
