defmodule Expresso.E2E.MathMoveTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # The binder moves to the argument at step 2, and to the two cells of the
  # part "far" at step 3. The script measures each distance in the browser.
  defmodule Deck do
    use Expresso

    slide "move" do
      math ~S(<math display="block"><mrow><mi data-part="bind">f</mi><mo>+</mo><mi class="arg">g</mi><mo>+</mo><mtext>a long gap</mtext><mo>+</mo><mi data-part="far">x</mi><mo>=</mo><mi data-part="far">y</mi></mrow></math>) do
        part "bind" do
          on 2, move_to: "arg"
          on 3, move_to: "far"
        end
      end
    end
  end

  # The distance in screen pixels between the center of the part "bind" and
  # the center of the box of each element with the name `to`.
  defp gap(page, to) do
    js(page, """
    (() => {
      const center = (selector) => {
        const boxes = Array.from(document.querySelectorAll(".screen .math " + selector),
          (element) => element.getBoundingClientRect());
        const left = Math.min(...boxes.map((box) => box.left));
        const right = Math.max(...boxes.map((box) => box.right));
        const top = Math.min(...boxes.map((box) => box.top));
        const bottom = Math.max(...boxes.map((box) => box.bottom));
        return [(left + right) / 2, (top + bottom) / 2];
      };
      const [a, b] = [center('[data-part="bind"]'), center(#{JSON.encode!(to)})];
      return Math.hypot(a[0] - b[0], a[1] - b[1]);
    })()
    """)
  end

  defp moves(page) do
    assert gap(page, ".arg") > 10

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")
    assert gap(page, ".arg") < 1

    press(page, "j")
    assert gap(page, ~s([data-part="far"])) < 1
    assert gap(page, ".arg") > 10

    press(page, "k")
    press(page, "k")
    assert gap(page, ".arg") > 10
  end

  test "a part of a formula moves to the center of a different part, and back", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page |> open(render(Deck, tmp_dir)) |> moves()
    assert js(page, "document.querySelectorAll('.math-measure').length") == 0
  end

  test "the move is correct in a small window, where the slide has a different scale", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 640, height: 400},
        reduced_motion: "reduce"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
    page |> open(render(Deck, tmp_dir)) |> moves()
  end
end
