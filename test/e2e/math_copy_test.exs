defmodule Expresso.E2E.MathCopyTest do
  use Expresso.E2E, async: false

  # At step 2, a copy of g goes to each hole, and a copy of the exponent n
  # goes to the m at the end. The formula keeps its layout.
  defmodule Deck do
    use Expresso

    slide "copies" do
      math ~S(<math display="block"><mrow><msup><mi>x</mi><mi data-part="exp">n</mi></msup><mo>+</mo><mi data-part="arg">g</mi><mo>+</mo><mi class="hole1">f</mi><mo>+</mo><mi class="hole2">f</mi><mo>+</mo><mi data-part="end">m</mi></mrow></math>) do
        part "arg" do
          on 2, copy_to: ["hole1", "hole2"]
        end

        part "exp" do
          copy "end", at: [from: 2]
        end
      end
    end
  end

  defp box(page, selector) do
    js(page, """
    (() => {
      const b = document.querySelector('.screen .math #{selector}').getBoundingClientRect();
      return {x: b.left + b.width / 2, y: b.top + b.height / 2, w: b.width};
    })()
    """)
  end

  defp gap(a, b),
    do: Float.round(:math.sqrt(:math.pow(a["x"] - b["x"], 2) + :math.pow(a["y"] - b["y"], 2)), 2)

  @copy ~s(math.math-copy[data-part="arg@hole1"])

  test "a copy of a part of a formula starts on its source and goes to its target", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    wait_for(page, "document.querySelector('.screen .math #{@copy}').hasAttribute('data-placed')")

    # Before its step, the copy is on its source, with the width of the
    # source, and it does not show.
    assert gap(box(page, @copy), box(page, ~s([data-part="arg"]))) < 1

    assert js(page, "getComputedStyle(document.querySelector('.screen .math #{@copy}')).opacity") ==
             "0"

    exponent = box(page, ~s([data-part="exp"]))
    copy = box(page, ~s(math.math-copy[data-part="exp@end"]))
    assert gap(copy, exponent) < 1
    # The font size changes in steps, so the width of the copy can differ
    # from the width of its source by one pixel.
    assert abs(copy["w"] - exponent["w"]) <= 1.5

    arg = box(page, ~s([data-part="arg"]))

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")
    assert gap(box(page, @copy), box(page, ".hole1")) < 1
    assert gap(box(page, ~s(math.math-copy[data-part="arg@hole2"])), box(page, ".hole2")) < 1

    assert gap(
             box(page, ~s(math.math-copy[data-part="exp@end"])),
             box(page, ~s([data-part="end"]))
           ) < 1

    assert box(page, ~s([data-part="arg"])) == arg
    assert js(page, "document.querySelectorAll('.math-measure').length") == 0
  end
end
