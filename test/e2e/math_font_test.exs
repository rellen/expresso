defmodule Expresso.E2E.MathFontTest do
  use Expresso.E2E, async: false

  defmodule FontDeck do
    use Expresso

    math_font(:stix)

    slide "formula" do
      math ~S(<math display="block"><mi>x</mi><mo>=</mo><mtext>the fix point</mtext></math>)
    end
  end

  # The state of the faces of a family, after the browser draws the slide.
  defp loaded(family) do
    """
    [...document.fonts].some((face) => face.family.replaceAll('"', '') === '#{family}' &&
      face.status === 'loaded')
    """
  end

  test "the browser loads the math font of the deck, and the text of a formula takes the font of the slide",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(FontDeck, tmp_dir))
    wait_for(page, loaded("STIX2"))

    assert js(page, "getComputedStyle(document.querySelector('.screen .math mi')).fontFamily") =~
             "STIX2"

    assert js(page, "getComputedStyle(document.querySelector('.screen .math mtext')).fontFamily") =~
             "Atkinson Hyperlegible"
  end
end
