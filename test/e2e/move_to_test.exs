defmodule Expresso.E2E.MoveToTest do
  use Expresso.E2E, async: false

  # The token moves to the circle at step 2, and to the station in a moved
  # group at step 3. The small rect is in a scaled group, and it moves to the
  # circle at step 2.
  defmodule Deck do
    use Expresso

    slide "move" do
      diagram "test/fixtures/move.svg" do
        width "80%"

        part "token" do
          on 2, move_to: "target"
          on 3, move_to: "station"
        end

        part "small" do
          on [from: 2], move_to: "target"
        end
      end
    end
  end

  # The distance in screen pixels between the centers of two elements.
  defp gap(page, from, to) do
    js(page, """
    (() => {
      const center = (id) => {
        const box = document.querySelector(".screen #" + CSS.escape(id) + ", .screen [id^='" + id + "-']").getBoundingClientRect();
        return [box.left + box.width / 2, box.top + box.height / 2];
      };
      const [a, b] = [center("#{from}"), center("#{to}")];
      return Math.hypot(a[0] - b[0], a[1] - b[1]);
    })()
    """)
  end

  test "a part moves to the center of its target, and back", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    assert gap(page, "token", "target") > 100

    press(page, "j")
    assert gap(page, "token", "target") < 1
    assert gap(page, "small", "target") < 1

    press(page, "j")
    assert gap(page, "token", "station") < 1
    assert gap(page, "small", "target") < 1

    press(page, "k")
    press(page, "k")
    assert gap(page, "token", "target") > 100
  end
end
