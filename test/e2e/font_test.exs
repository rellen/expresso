defmodule Expresso.E2E.FontTest do
  use Expresso.E2E, async: false

  # The deck has no bold text and no italic text, and each of its characters
  # is in the range of the Latin file. A browser loads a face of a font only
  # when a text needs it, so without the script of `Expresso.Font.loader/0`
  # this deck loads one face of the eight.
  defmodule Deck do
    use Expresso

    name "font deck"

    slide "start" do
      text_box do
        text_area(text: "A text with no bold word")
      end
    end
  end

  @faces "[...document.fonts].filter((face) => face.family.includes('Atkinson Hyperlegible'))"

  test "the document loads each face of the font, also a face that no text needs",
       %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    wait_for(audience, "#{@faces}.every((face) => face.status === 'loaded')")

    assert js(audience, "#{@faces}.length") == Expresso.Font.file_count()
    assert js(audience, "#{@faces}.map((face) => face.status)") |> Enum.uniq() == ["loaded"]
  end

  test "the text of the first slide has the font of the theme", %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    wait_for(audience, "document.fonts.status === 'loaded'")

    assert js(audience, ~s|document.fonts.check('400 1em "Atkinson Hyperlegible"')|) == true

    assert js(audience, ~s|document.fonts.check('italic 700 1em "Atkinson Hyperlegible"', 'Ā')|) ==
             true
  end
end
