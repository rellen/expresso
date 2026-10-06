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

  # The whole code shows at step 1. Line 2 is in focus at step 2, and lines 3
  # and 4 at step 3.
  defmodule WholeDeck do
    use Expresso

    slide "whole" do
      code "elixir" do
        highlight([2, 3..4])
        whole_first(true)
        text "a = 1\nb = 2\nc = 3\nd = 4\ne = 5\n"
      end
    end
  end

  # Line 2 is in focus at step 1, so line 1, a comment, dims.
  defmodule CommentDeck do
    use Expresso

    theme :dracula

    slide "comment" do
      code "elixir" do
        highlight([2])
        text "# a comment\nx = 1\n"
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

  # True for each line that dims: the line does not have the color of the code
  # text, which is black in the default theme.
  defp dim(page) do
    page
    |> js("""
    Array.from(document.querySelectorAll(".screen .code .line")).map((line) =>
      getComputedStyle(line).color)
    """)
    |> Enum.map(&(rgb(&1) != "rgb(0, 0, 0)"))
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

  test "whole_first shows the whole code with no bar at step 1, then each group", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(WholeDeck, tmp_dir))

    assert position(page) == "1.1"
    assert dim(page) == [false, false, false, false, false]
    assert Enum.all?(bar_offsets(page), &(&1 >= 0))

    press(page, "j")
    assert position(page) == "1.2"
    assert dim(page) == [true, false, true, true, true]

    press(page, "j")
    assert position(page) == "1.3"
    assert dim(page) == [true, true, false, false, true]
  end

  test "a dimmed comment takes the dimmed color of the comments, and its line the dimmed color of the code text",
       %{page: page, tmp_dir: tmp_dir} do
    %{dimmed: dimmed, roles: roles} = Expresso.Palette.Builtin.fetch!(:dracula)
    page = open(page, render(CommentDeck, tmp_dir))

    [[comment, line], [focus_comment, focus_line]] =
      page
      |> js("""
      Array.from(document.querySelectorAll(".screen .code .line")).map((line) => [
        getComputedStyle(line.querySelector(".c1") || line).color,
        getComputedStyle(line).color
      ])
      """)
      |> Enum.map(fn pair -> Enum.map(pair, &rgb/1) end)

    assert comment == hex(elem(dimmed.code_comment, 1))
    assert line == hex(elem(dimmed.code_text, 1))
    assert focus_line == hex(roles.code_text)
    assert focus_comment == hex(roles.code_text)
  end

  defp hex("#" <> hex) do
    [r, g, b] = for <<pair::binary-2 <- hex>>, do: String.to_integer(pair, 16)
    "rgb(#{r}, #{g}, #{b})"
  end
end
