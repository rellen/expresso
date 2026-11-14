defmodule Expresso.E2E.InlineStepsTest do
  use Expresso.E2E, async: false

  # A sentence with a part that shows from step 2, a part with the state
  # `alert` at step 3, and a part with the state `dim` at step 4. The item has
  # a part that shows at step 2 only.
  defmodule Deck do
    use Expresso

    name "inline deck"

    slide "parts" do
      text_box do
        text_area(
          text:
            ~s(The answer is <span at="2-">42</span>. It is <em at="3" state="alert">not</em> 41, ) <>
              ~s(as <b at="4" state="dim">we said</b>.)
        )
      end

      list do
        item ~s(An item with <code at="2">a part</code> in it)
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # A value of the computed style of each part of the present view, in the
  # order of the document.
  defp styles(page, property) do
    js(page, """
    [...document.querySelectorAll(".screen [data-text-part]")]
      .map((part) => getComputedStyle(part)[#{JSON.encode!(property)}])
    """)
  end

  # A custom property of the theme, as the browser gives a color.
  defp theme(page, name) do
    js(page, """
    (() => {
      const probe = document.createElement("div");
      probe.style.color = "var(#{name})";
      document.querySelector(".screen .text-area").append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
    |> rgb()
  end

  defp width(page) do
    js(page, "document.querySelector('.screen .text-area > div').getBoundingClientRect().width")
  end

  test "a part shows at its steps, and a hidden part keeps its space", %{page: page} do
    assert styles(page, "visibility") == ["hidden", "visible", "visible", "hidden"]
    hidden = width(page)

    page |> press("j")
    assert position(page) == "1.2"
    assert styles(page, "visibility") == ["visible", "visible", "visible", "visible"]
    assert styles(page, "opacity") == ["1", "1", "1", "1"]

    # The sentence has the same width with the part and without it.
    assert width(page) == hidden

    page |> press("j")
    assert styles(page, "visibility") == ["visible", "visible", "visible", "hidden"]
  end

  test "the state alert gives a part the accent color at its step", %{page: page} do
    text = theme(page, "--text")
    accent = theme(page, "--accent")
    refute text == accent

    assert page |> styles("color") |> Enum.at(1) |> rgb() == text

    page |> keys(["j", "j"])

    wait_for(
      page,
      "getComputedStyle(document.querySelectorAll('.screen [data-text-part]')[1]).color !== ''"
    )

    finish_animations(page, ".screen [data-text-part]")
    assert page |> styles("color") |> Enum.at(1) |> rgb() == accent

    page |> press("j")
    finish_animations(page, ".screen [data-text-part]")
    assert page |> styles("color") |> Enum.at(1) |> rgb() == text
  end

  test "the state dim gives a part the dimmed color of the text at its step", %{page: page} do
    page |> keys(["j", "j", "j"])
    assert position(page) == "1.4"
    finish_animations(page, ".screen [data-text-part]")

    assert page |> styles("color") |> Enum.at(2) |> rgb() == theme(page, "--text-dim")
  end

  test "the handout view shows each part at the step of its page", %{page: page} do
    page |> press("p")

    assert js(page, """
           [...document.querySelectorAll(".handout-page")].map((page) =>
             [...page.querySelectorAll("[data-text-part]")]
               .filter((part) => getComputedStyle(part).visibility === "visible")
               .map((part) => part.textContent))
           """) == [
             ["not", "we said"],
             ["42", "not", "we said", "a part"],
             ["42", "not", "we said"],
             ["42", "not", "we said"]
           ]
  end
end
