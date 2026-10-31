defmodule Expresso.E2E.MathRewriteTest do
  use Expresso.E2E, async: false

  # A β-reduction that a rewrite writes. At step 2, each f of the body and the
  # argument get a color. At step 3, the kept symbols move down from the first
  # line. At step 4, a copy of g moves into the place of each f, and the line
  # shows.
  defmodule Deck do
    use Expresso

    slide "rewrite" do
      math do
        reveal true

        line tex:
               ~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}\part{close}{)}\,\part{arg}{g}"

        rewrite ~S"\to_\beta",
          replace: "f",
          within: "body",
          by: "arg",
          drop: ["lam", "close", "arg"],
          why: "f := g"
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

  defp copy(name), do: ~s(math.math-copy[data-part="#{name}"])

  defp step(page, n) do
    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '#{n}'")
  end

  defp color(page, selector),
    do: js(page, "getComputedStyle(document.querySelector('.screen .math #{selector}')).color")

  defp opacity(page, selector),
    do: js(page, "getComputedStyle(document.querySelector('.screen .math #{selector}')).opacity")

  defp moved?(page, name, n), do: gap(center(page, copy(name)), center(page, ".link-#{n}")) < 1

  test "the occurrences get a color, then the kept runs move, then the copies move", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    wait_for(
      page,
      "document.querySelector('.screen .math #{copy("arg@link-3")}').hasAttribute('data-placed')"
    )

    black = color(page, ".hit-2")
    source = center(page, ~s([data-part="arg"]))

    # Step 2: the occurrences and the argument get a color, and nothing moves.
    step(page, 2)

    wait_for(
      page,
      "getComputedStyle(document.querySelector('.screen .math .hit-2')).color !== '#{black}'"
    )

    refute color(page, ~s(mi[data-part="arg"])) == black
    refute moved?(page, "keep-2-1@link-2", 2)
    assert gap(center(page, copy("arg@link-1")), source) < 1

    # Step 3: the kept runs move, and the copies of the argument wait.
    step(page, 3)
    assert moved?(page, "keep-2-1@link-2", 2)
    assert moved?(page, "keep-2-2@link-4", 4)
    assert gap(center(page, copy("arg@link-1")), source) < 1
    assert opacity(page, ~s(mtd [data-line="line2"])) == "0"

    # Step 4: each copy of the argument moves into its place, and the line
    # shows with its relation and its reason.
    step(page, 4)
    assert moved?(page, "arg@link-1", 1)
    assert moved?(page, "arg@link-3", 3)

    wait_for(
      page,
      "getComputedStyle(document.querySelector('.screen .math mtd [data-line=\"line2\"]')).opacity === '1'"
    )
  end
end
