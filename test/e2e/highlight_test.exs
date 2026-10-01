defmodule Expresso.E2E.HighlightTest do
  use Expresso.E2E, async: false

  # Line 2 is in focus at step 1, and lines 3 and 4 at step 2. Lines 1 and 5
  # are in no group.
  defmodule Deck do
    use Expresso

    slide "highlight" do
      code "elixir" do
        highlight([2, 3..4])
        text "a = 1\nb = 2\nc = 3\nd = 4\ne = 5\n"
      end
    end
  end

  # The horizontal offset of the shadow of the bar, the last shadow of each line.
  defp bar_offsets(page) do
    js(page, """
    Array.from(document.querySelectorAll(".screen .code .line")).map((line) =>
      parseFloat(getComputedStyle(line).boxShadow.trim().split(" ").slice(-4)[0]))
    """)
  end

  # True for each line that dims.
  defp dim(page) do
    js(page, """
    Array.from(document.querySelectorAll(".screen .code .line")).map((line) =>
      !getComputedStyle(line).filter.includes("opacity(1)"))
    """)
  end

  test "the group in focus shows in full with a bar, and each other line dims", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    assert dim(page) == [true, false, true, true, true]
    assert Enum.map(bar_offsets(page), &(&1 < 0)) == [false, true, false, false, false]

    press(page, "j")
    assert position(page) == "1.2"
    assert dim(page) == [true, true, false, false, true]
    assert Enum.map(bar_offsets(page), &(&1 < 0)) == [false, false, true, true, false]
  end
end
