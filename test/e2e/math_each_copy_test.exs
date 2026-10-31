defmodule Expresso.E2E.MathEachCopyTest do
  use Expresso.E2E, async: false

  # At step 2, a copy of g goes to each x. At step 3, a copy of each a goes to
  # the b with the same number.
  defmodule Deck do
    use Expresso

    slide "each" do
      math ~S|<math display="block"><mrow><mi data-part="arg">g</mi><mo>+</mo><mi>x</mi><mo>+</mo><mi>a</mi><mo>+</mo><mi>x</mi><mo>+</mo><mi>a</mi><mo>+</mo><mi>b</mi><mo>+</mo><mi>b</mi></mrow></math>| do
        part "xs" do
          each "x"
        end

        part "bs" do
          each "b"
        end

        part "arg" do
          on 2, copy_to: ["xs"]
        end

        part "as" do
          each "a"
          on 3, copy_to: ["bs"]
        end
      end
    end
  end

  defp box(page, selector) do
    js(page, """
    (() => {
      const b = document.querySelector('.screen .math #{selector}').getBoundingClientRect();
      return {x: b.left + b.width / 2, y: b.top + b.height / 2};
    })()
    """)
  end

  defp gap(a, b),
    do: Float.round(:math.sqrt(:math.pow(a["x"] - b["x"], 2) + :math.pow(a["y"] - b["y"], 2)), 2)

  defp copy(name), do: ~s(math.math-copy[data-part="#{name}"])

  defp step(page, n) do
    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '#{n}'")
  end

  test "a copy to a set goes to each occurrence, and a copy of a set pairs the occurrences", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    wait_for(
      page,
      "document.querySelector('.screen .math #{copy("as@bs-2")}').hasAttribute('data-placed')"
    )

    # Before its step, each copy is on its source.
    assert gap(box(page, copy("arg@xs-2")), box(page, ~s([data-part="arg"]))) < 1
    assert gap(box(page, copy("as@bs-1")), box(page, ".as-1")) < 1
    assert gap(box(page, copy("as@bs-2")), box(page, ".as-2")) < 1

    step(page, 2)
    assert gap(box(page, copy("arg@xs-1")), box(page, "mi.xs-1")) < 1
    assert gap(box(page, copy("arg@xs-2")), box(page, "mi.xs-2")) < 1

    step(page, 3)
    assert gap(box(page, copy("as@bs-1")), box(page, "mi.bs-1")) < 1
    assert gap(box(page, copy("as@bs-2")), box(page, "mi.bs-2")) < 1
  end
end
