defmodule Expresso.E2E.DimTest do
  use Expresso.E2E, async: false

  # An image and a part of a diagram dim at step 2. Their colors come from
  # their files, so they dim with the shared opacity of the theme.
  defmodule Deck do
    use Expresso

    name "dim deck"
    theme :dracula

    slide "graphics" do
      image "test/fixtures/dot.png" do
        alt "A dot"
        on 2, state: :dim
      end

      diagram "test/fixtures/flow.svg" do
        part "output" do
          on 2, state: :dim
        end
      end
    end
  end

  # Issue #358: at a dim contrast of 4.5, the default theme has
  # `--dim-opacity` 1.0, so a graphic does not dim.
  defmodule LightDeck do
    use Expresso

    name "light deck"
    dim_contrast 4.5

    slide "graphics" do
      image "test/fixtures/dot.png" do
        alt "A dot"
        on 2, state: :dim
      end

      diagram "test/fixtures/flow.svg" do
        part "output" do
          on 2, state: :dim
        end
      end
    end
  end

  # The same deck with an opacity of its own for the graphics.
  defmodule GraphicDeck do
    use Expresso

    name "graphic deck"
    dim_contrast 4.5
    dim_graphic_opacity 0.5

    slide "graphics" do
      image "test/fixtures/dot.png" do
        alt "A dot"
        on 2, state: :dim
      end

      diagram "test/fixtures/flow.svg" do
        part "output" do
          on 2, state: :dim
        end
      end
    end
  end

  # The filters of the picture in the image, of the wrapper of the part and of
  # the SVG.
  defp filters(page) do
    js(page, """
    [
      getComputedStyle(document.querySelector(".screen .image img")).filter,
      getComputedStyle(document.querySelector(".screen .diagram-part")).filter,
      getComputedStyle(document.querySelector(".screen .diagram svg")).filter
    ]
    """)
  end

  test "an image and a part of a diagram dim with the shared opacity, and the SVG does not dim",
       %{page: page, tmp_dir: tmp_dir} do
    %{dim_opacity: opacity} = Expresso.Palette.Builtin.fetch!(:dracula)
    page = open(page, render(Deck, tmp_dir))

    assert filters(page) == ["opacity(1)", "blur(0px) opacity(1)", "opacity(1)"]

    press(page, "j")

    assert filters(page) == [
             "opacity(#{opacity})",
             "blur(0px) opacity(#{opacity})",
             "opacity(1)"
           ]
  end

  test "at a dim contrast of 4.5, the graphics of a light theme do not dim without the option",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(LightDeck, tmp_dir))
    press(page, "j")

    assert filters(page) == ["opacity(1)", "blur(0px) opacity(1)", "opacity(1)"]
  end

  test "the dim_graphic_opacity option dims the graphics of a light theme at a dim contrast of 4.5",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(GraphicDeck, tmp_dir))

    assert filters(page) == ["opacity(1)", "blur(0px) opacity(1)", "opacity(1)"]

    press(page, "j")

    assert filters(page) == ["opacity(0.5)", "blur(0px) opacity(0.5)", "opacity(1)"]
  end
end
