defmodule Expresso.E2E.MathPartsTest do
  use Expresso.E2E, async: false

  # The binder turns red at step 2, the argument shows from step 3, and the
  # binder moves 40px down at step 4.
  defmodule PartsDeck do
    use Expresso

    slide "the redex" do
      math ~S(<math display="block"><mrow data-part="redex"><mi data-part="bind">f</mi><mo>+</mo><mi class="arg">g</mi></mrow></math>) do
        part "bind" do
          on 2..3, set: [color: "rgb(255, 0, 0)"]
          on [from: 4], set: [y: "40px"]
        end

        part "arg", at: [from: 3]
      end
    end
  end

  @bind "document.querySelector('.screen .math [data-part=\"bind\"]')"
  @arg "document.querySelector('.screen .math .arg')"

  # The theme mixes the color of an element with `color-mix`, so the browser
  # gives the color in the form `color(srgb r g b)`.
  defp color(element), do: "getComputedStyle(#{element}).color"
  defp opacity(element), do: "getComputedStyle(#{element}).opacity"
  defp top(element), do: "Math.round(#{element}.getBoundingClientRect().top)"

  test "a part of a formula changes its color, shows and moves at its steps", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(PartsDeck, tmp_dir))
    wait_for(page, "#{opacity(@arg)} === '0'")
    refute js(page, color(@bind)) == "color(srgb 1 0 0)"
    start = js(page, top(@bind))

    press(page, "ArrowRight")
    wait_for(page, "#{color(@bind)} === 'color(srgb 1 0 0)'")
    assert js(page, opacity(@arg)) == "0"

    press(page, "ArrowRight")
    wait_for(page, "#{opacity(@arg)} === '1'")

    press(page, "ArrowRight")
    wait_for(page, "#{top(@bind)} === #{start + 40}")
  end
end
