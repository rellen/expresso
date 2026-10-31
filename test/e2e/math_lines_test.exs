defmodule Expresso.E2E.MathLinesTest do
  use Expresso.E2E, async: false

  # The first line shows at step 1, and each later line at its own step. The
  # browser tests run in Node, so Temml can make the MathML of the lines.
  defmodule LinesDeck do
    use Expresso

    slide "proof" do
      math do
        reveal true
        line tex: "a + a"
        line "=", tex: "2a", why: "add"
        line "=", tex: "a \\cdot 2", why: "turn"
      end
    end
  end

  defp opacities do
    """
    ['line1', 'line2', 'line3'].map((name) =>
      getComputedStyle(document.querySelector(`.screen .math [data-line="${name}"]`)).opacity
    ).join(' ')
    """
  end

  # The opacity of each line on each page of the handout view, a page for each
  # step.
  defp handout do
    """
    Array.from(document.querySelectorAll('.handout-page')).map((page) =>
      ['line1', 'line2', 'line3'].map((name) =>
        getComputedStyle(page.querySelector(`.math [data-line="${name}"]`)).opacity
      ).join(' ')
    ).join(' / ')
    """
  end

  test "the handout view gives each step of the lines a page, and the last page shows each line",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(LinesDeck, tmp_dir))
    wait_for(page, "(#{handout()}) === '1 0 0 / 1 1 0 / 1 1 1'")
  end

  test "reveal shows each line of a derivation at its own step", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(LinesDeck, tmp_dir))
    wait_for(page, "(#{opacities()}) === '1 0 0'")

    press(page, "ArrowRight")
    wait_for(page, "(#{opacities()}) === '1 1 0'")

    press(page, "ArrowRight")
    wait_for(page, "(#{opacities()}) === '1 1 1'")
  end
end
