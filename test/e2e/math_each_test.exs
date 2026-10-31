defmodule Expresso.E2E.MathEachTest do
  use Expresso.E2E, async: false

  # At step 2, each x of the formula turns red, and no other symbol does.
  defmodule Deck do
    use Expresso

    slide "each" do
      math ~S|<math display="block"><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo><mn>2</mn><mi>x</mi><mo>+</mo><mi>exp</mi><mo>(</mo><mi>x</mi><mo>)</mo></math>| do
        part "xs" do
          each "x"
          on 2, set: [color: "rgb(255, 0, 0)"]
        end
      end
    end
  end

  # The color of each token of the formula, with its text.
  defp colors(page) do
    js(page, """
    Array.from(document.querySelectorAll('.screen .math math > *, .screen .math msup > mi'),
      (e) => [e.textContent, getComputedStyle(e).color])
      .filter(([text]) => ["x", "exp", "2", "+"].includes(text))
    """)
  end

  test "each occurrence of a symbol changes its color at its step, and no other symbol", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    red = "color(srgb 1 0 0)"
    refute Enum.any?(colors(page), fn [_text, color] -> color == red end)

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")

    wait_for(
      page,
      "getComputedStyle(document.querySelector('.screen .math .xs')).color === '#{red}'"
    )

    for [text, color] <- colors(page) do
      if text == "x", do: assert(color == red), else: refute(color == red, text)
    end

    assert js(page, "document.querySelectorAll('.screen .math .xs').length") == 3
  end
end
