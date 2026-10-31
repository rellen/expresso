defmodule Expresso.E2E.MathRewriteTest do
  use Expresso.E2E, async: false

  # A β-reduction that a rewrite writes: at step 2, a copy of g moves into the
  # place of each f, and the kept symbols move down from the first line.
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

  test "each copy of the argument and each kept run moves into its place in the new line", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    wait_for(
      page,
      "document.querySelector('.screen .math #{copy("arg@link-3")}').hasAttribute('data-placed')"
    )

    # Before the step, each copy is on its source in the first line.
    source = center(page, ~s([data-part="arg"]))
    assert gap(center(page, copy("arg@link-1")), source) < 1
    assert gap(center(page, copy("arg@link-3")), source) < 1

    assert gap(center(page, copy("keep-2-1@link-2")), center(page, ~s([data-part="keep-2-1"]))) <
             1

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")

    for n <- 1..4 do
      [name] =
        js(page, """
        [document.querySelector('.screen .math math.math-copy[data-part$="@link-#{n}"]').dataset.part]
        """)

      assert gap(center(page, copy(name)), center(page, ".link-#{n}")) < 1, name
    end
  end
end
