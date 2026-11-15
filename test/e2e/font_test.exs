defmodule Expresso.E2E.FontTest do
  use Expresso.E2E, async: false

  # The deck has no bold text and no italic text, and each of its characters
  # is in the range of the Latin file. A browser loads a face of a font only
  # when a text needs it, so without the script of `Expresso.Font.loader/0`
  # this deck loads one face.
  defmodule Deck do
    use Expresso

    name "font deck"

    slide "start" do
      text_box do
        text_area(text: "A text with no bold word")
      end
    end
  end

  # The same deck with one character of Latin Extended.
  defmodule ExtendedDeck do
    use Expresso

    name "extended deck"

    slide "start" do
      text_box do
        text_area(text: "A text of Paul Erdős")
      end
    end
  end

  @faces "[...document.fonts].filter((face) => face.family.includes('Atkinson Hyperlegible'))"

  # `Expresso.Font.trim/1` leaves out the four Latin Extended faces of a
  # document with no character of their range.
  test "the document loads each of its four faces, also a face that no text needs",
       %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    wait_for(audience, "#{@faces}.every((face) => face.status === 'loaded')")

    assert js(audience, "#{@faces}.length") == 4
    assert js(audience, "#{@faces}.map((face) => face.status)") |> Enum.uniq() == ["loaded"]

    assert js(audience, ~s|document.fonts.check('italic 700 1em "Atkinson Hyperlegible"')|) ==
             true
  end

  test "a deck with a character of Latin Extended has the eight faces, and it loads each one",
       %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(ExtendedDeck, tmp_dir))
    wait_for(audience, "#{@faces}.every((face) => face.status === 'loaded')")

    assert js(audience, "#{@faces}.length") == Expresso.Font.file_count()
    assert js(audience, ~s|document.fonts.check('400 1em "Atkinson Hyperlegible"', 'ő')|) == true
  end

  # The width of a text in the font of the theme is not its width in the
  # fallback font. A character that the browser draws in the fallback font
  # has the same width with the two font lists.
  test "the browser draws a character of Latin Extended in the font of the theme",
       %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(ExtendedDeck, tmp_dir))
    wait_for(audience, "#{@faces}.every((face) => face.status === 'loaded')")

    width = fn font ->
      js(audience, """
      (() => {
        const context = document.createElement("canvas").getContext("2d");
        context.font = '400 200px #{font}';
        return context.measureText("őőőőőőőő").width;
      })()
      """)
    end

    assert width.(~s("Atkinson Hyperlegible", monospace)) != width.("monospace")
  end
end
