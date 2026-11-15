defmodule Expresso.E2E.StyleSheetTest do
  use Expresso.E2E, async: false

  defmodule Deck do
    use Expresso

    name "style deck"

    slide "start" do
      text_box do
        text_area(text: "Start")
      end
    end
  end

  # Each rule of a style sheet as the browser reads it, with each nested rule.
  # The browser writes each rule in one form, so two style sheets with the
  # same rules give the same list.
  @rules """
  ((sheet) => {
    const read = (rules) => [...rules].map((rule) => rule.cssText);
    return read(sheet.cssRules);
  })
  """

  # The browser keeps the white space of a value with `var()` as the style
  # sheet has it. The function writes one space for each sequence of white
  # space, and it removes the space after `(`, in front of `)` and on each
  # side of `,`, where a space has no meaning. Each other space stays, so a
  # value that lost a space with a meaning is different.
  defp same(rule) do
    rule
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\( /, "(")
    |> String.replace(~r/ \)/, ")")
    |> String.replace(~r/ ?, ?/, ",")
  end

  # The renderer writes `assets/style.css` with no comment and with no white
  # space that CSS does not need. `Expresso.Css.minify/1` makes that text, and
  # it must change no rule. The test gives the browser the file as it is, and
  # it compares the rules with the rules of the document.
  test "the browser reads the same rules from the style sheet of the document and from the file",
       %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    source = File.read!("assets/style.css")

    from_file =
      js(audience, """
      (() => {
        const sheet = new CSSStyleSheet();
        sheet.replaceSync(#{JSON.encode!(source)});
        return #{@rules}(sheet);
      })()
      """)

    from_document =
      js(audience, """
      (() => {
        const sheet = new CSSStyleSheet();
        sheet.replaceSync(#{JSON.encode!(Expresso.Css.minify(source))});
        return #{@rules}(sheet);
      })()
      """)

    assert length(from_file) > 300
    assert length(from_document) == length(from_file)

    differences =
      from_file
      |> Enum.zip(from_document)
      |> Enum.reject(fn {file, document} -> same(file) == same(document) end)

    assert differences == []

    # The document holds the style sheet of `minify/1`, after the theme.
    assert File.read!(Path.join(tmp_dir, "deck.html")) =~ Expresso.Css.minify(source)
  end
end
