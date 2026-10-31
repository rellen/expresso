defmodule Expresso.E2E.MathLinkTest do
  use Expresso.E2E, async: false

  # The second line shows at step 2, and a copy of g moves from the first line
  # into each linked sub-term of the second line.
  defmodule Deck do
    use Expresso

    slide "link" do
      math do
        reveal true
        line tex: ~S"(\lambda f.\,f\,(f\,x))\,\part{arg}{g}"
        line ~S"\to_\beta", tex: ~S"\from{arg}{g}\,(\from{arg}{g}\,x)", why: "f := g"
      end
    end
  end

  defp center(page, selector) do
    js(page, """
    (() => {
      const b = document.querySelector('.screen .math #{selector}').getBoundingClientRect();
      return [b.left + b.width / 2, b.top + b.height / 2];
    })()
    """)
  end

  defp gap([x1, y1], [x2, y2]), do: :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))

  test "a copy moves from the source in an earlier line to each linked sub-term", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    first = ~s(math.math-copy[data-part="arg@link-1"])
    wait_for(page, "document.querySelector('.screen .math #{first}').hasAttribute('data-placed')")

    source = center(page, ~s([data-part="arg"]))
    assert gap(center(page, first), source) < 1

    # The script hides each linked sub-term under its copy.
    assert js(page, "document.querySelectorAll('.screen .math [data-covered]').length") == 2

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")

    assert gap(center(page, first), center(page, ".link-1")) < 1

    assert gap(center(page, ~s(math.math-copy[data-part="arg@link-2"])), center(page, ".link-2")) <
             1

    assert gap(center(page, ~s([data-part="arg"])), source) < 1
  end
end
