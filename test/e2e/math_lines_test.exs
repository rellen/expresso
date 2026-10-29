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
      getComputedStyle(document.querySelector(`.screen .math [data-part="${name}"]`)).opacity
    ).join(' ')
    """
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
