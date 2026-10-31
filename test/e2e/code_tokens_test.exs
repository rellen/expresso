defmodule Expresso.E2E.CodeTokensTest do
  use Expresso.E2E, async: false

  # Each count is in focus at step 1, and line 3 at step 2.
  defmodule Deck do
    use Expresso

    slide "tokens" do
      code "elixir" do
        highlight [[each: "count"], 3]
        text "count = 1\nx = count + 2\ny = 3\n"
      end
    end
  end

  # The color of each token of a name, with its text, and the bar under each
  # token of the group.
  defp names(page) do
    js(page, """
    Array.from(document.querySelectorAll(".screen .code .line > .n"),
      (token) => [token.textContent.trim(),
        getComputedStyle(token.querySelector(".code-token") ?? token).color])
    """)
    |> Enum.map(fn [text, color] -> {text, rgb(color) == "rgb(0, 0, 0)"} end)
  end

  defp bars(page) do
    js(page, """
    Array.from(document.querySelectorAll(".screen .code .code-token"),
      (token) => getComputedStyle(token).boxShadow)
    """)
    |> Enum.map(&(&1 != "none" and not String.contains?(&1, " 0px 0px 0px")))
  end

  test "each token of the group shows in full color with a bar while its line dims", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    # At step 1, each count is in full color, and the other names dim.
    assert names(page) == [{"count", true}, {"x", false}, {"count", true}, {"y", false}]
    assert bars(page) == [true, true]

    press(page, "j")
    assert position(page) == "1.2"

    # At step 2, line 3 is in focus, and each count dims with its line.
    assert names(page) == [{"count", false}, {"x", false}, {"count", false}, {"y", true}]
    assert bars(page) == [false, false]
  end
end
