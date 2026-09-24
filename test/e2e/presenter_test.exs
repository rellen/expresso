defmodule Expresso.E2E.PresenterTest do
  use Expresso.E2E, async: false

  # Three slides. Slide 1 has one step, slide 2 has three steps, and slide 3
  # has two steps. The second box of slide 2 appears at step 2.
  defmodule Deck do
    use Expresso

    name "presenter deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      steps 3

      text_box do
        text_area(text: "Always")
      end

      text_box do
        at from: 2
        text_area(text: "From step 2")
      end
    end

    slide "three" do
      steps 2

      text_box do
        text_area(text: "Three")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  test "j and k move through the steps and the slides, and the address follows", %{page: page} do
    assert position(page) == "1.1"

    page |> keys(["j", "j"])
    assert position(page) == "2.2"
    assert js(page, "location.hash") == "#2.2"

    page |> keys(["j", "j", "j"])
    assert position(page) == "3.2"

    # The last step of the last slide stays, and k at step 1 goes to the last
    # step of the slide before.
    page |> press("j")
    assert position(page) == "3.2"

    page |> keys(["k", "k"])
    assert position(page) == "2.3"
  end

  test "the keys of a presentation remote and the arrow keys move as j and k do", %{page: page} do
    page |> keys(["ArrowRight", "Space", "PageDown"])
    assert position(page) == "2.3"

    page |> keys(["ArrowLeft", "PageUp", "ArrowUp"])
    assert position(page) == "1.1"
  end

  test "Home, End and a slide number with Enter go to step 1 of a slide", %{page: page} do
    page |> press("End")
    assert position(page) == "3.1"

    page |> press("Home")
    assert position(page) == "1.1"

    page |> keys(["2", "Enter"])
    assert position(page) == "2.1"
  end

  test "an element appears at its step", %{page: page} do
    box = "[...document.querySelectorAll('.screen [data-on]')][0]"

    page |> press("j")
    assert js(page, "getComputedStyle(#{box}).opacity") == "0"

    page |> press("j")
    assert js(page, "getComputedStyle(#{box}).opacity") == "1"
  end

  test "a reload shows the same step", %{page: page} do
    page |> keys(["j", "j"]) |> reload()

    assert position(page) == "2.2"
  end

  test "b gives a black screen, and the next key shows the slide again", %{page: page} do
    page |> press("b")
    assert js(page, "getComputedStyle(document.body).backgroundColor") == "rgb(0, 0, 0)"
    assert js(page, "getComputedStyle(document.querySelector('.screen')).visibility") == "hidden"

    page |> press("j")
    assert js(page, "getComputedStyle(document.querySelector('.screen')).visibility") == "visible"
    assert position(page) == "1.1"
  end

  test "? shows the list of keys, and the next key closes it", %{page: page} do
    page |> press("Shift+Slash")
    assert js(page, "getComputedStyle(document.getElementById('help')).display") == "grid"

    names = js(page, "[...document.querySelectorAll('#help kbd')].map((key) => key.textContent)")
    assert "s" in names
    assert "?" in names

    page |> press("j")
    assert js(page, "getComputedStyle(document.getElementById('help')).display") == "none"
    assert position(page) == "1.1"
  end

  test "the progress bar follows the step, and g hides it", %{page: page} do
    bar = "document.getElementById('progress')"
    assert js(page, "#{bar}.getBoundingClientRect().width") == 0

    # Six steps give five moves, so step 2 of slide 2 is two fifths.
    page |> keys(["j", "j"])
    assert js(page, "#{bar}.style.width") == "40%"

    page |> press("g")
    assert js(page, "getComputedStyle(#{bar}).display") == "none"
  end
end
