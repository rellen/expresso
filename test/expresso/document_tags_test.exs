defmodule Expresso.DocumentTagsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Palette.Builtin

  # The `meta` elements of the head of the document. `docs/document-tags.md`
  # gives the decision for each tag.
  defp head(options) do
    html =
      [Builder.slide("one", heading: "One")] |> Builder.deck(options) |> Expresso.Deck.render()

    [head, _body] = String.split(html, "<style>", parts: 2)
    {LazyHTML.from_fragment(head), html}
  end

  # The `content` and the `media` attribute of each `meta` element with a name.
  defp tags(document, name) do
    for meta <- LazyHTML.query(document, ~s(meta[name="#{name}"])) do
      [content] = LazyHTML.attribute(meta, "content")
      {content, meta |> LazyHTML.attribute("media") |> List.first()}
    end
  end

  describe "a deck with no option" do
    test "has the generator, the color scheme and the theme color, and no other name" do
      {document, _html} = head(name: "deck")

      assert tags(document, "generator") == [{Expresso.CommandLine.version(), nil}]
      assert tags(document, "color-scheme") == [{"light", nil}]
      assert tags(document, "theme-color") == [{"#ffffff", nil}]

      names = document |> LazyHTML.query("meta[name]") |> LazyHTML.attribute("name")
      assert names == ["generator", "color-scheme", "theme-color"]
    end

    test "the encoding stays the first element of the head, and the title is in front of the tags" do
      {_document, html} = head(name: "deck")

      assert html =~
               ~s(<head><meta charset="utf-8"/><title>deck</title><meta name="generator")
    end

    # `width=device-width` gives a slide the width of a phone, and the text
    # of a slide has a fixed size, so the browser cuts the text. Without the
    # tag, a phone shows the whole slide at a smaller scale.
    test "has no viewport tag" do
      {document, _html} = head(name: "deck")

      assert tags(document, "viewport") == []
    end

    test "names no address of a network" do
      {document, _html} = head(name: "deck", description: "A talk", author: "Ada")

      for content <- document |> LazyHTML.query("meta") |> LazyHTML.attribute("content") do
        refute content =~ "://"
      end

      assert LazyHTML.query(document, "link") |> Enum.to_list() == []
    end
  end

  describe "the description and the author" do
    test "each option gives a tag, in front of the generator" do
      {document, _html} = head(description: "How a deck gets its tags.", author: "Ada Lovelace")

      assert tags(document, "description") == [{"How a deck gets its tags.", nil}]
      assert tags(document, "author") == [{"Ada Lovelace", nil}]

      names = document |> LazyHTML.query("meta[name]") |> LazyHTML.attribute("name")
      assert Enum.take(names, 3) == ["description", "author", "generator"]
    end

    test "a text of more than one line goes on one line" do
      {document, _html} = head(description: "  A talk\n   about  tags.\n")

      assert tags(document, "description") == [{"A talk about tags.", nil}]
    end

    test "the document escapes each character of the text" do
      text = ~s(Ada "The Count" <Lovelace> & co)
      {document, html} = head(author: text)

      assert tags(document, "author") == [{text, nil}]
      assert html =~ ~s(content="Ada &quot;The Count&quot; &lt;Lovelace&gt; &amp; co")
    end

    test "an empty text gives no tag" do
      {document, _html} = head(description: "  \n ", author: "")

      assert tags(document, "description") == []
      assert tags(document, "author") == []
    end

    test "the DSL takes the options" do
      defmodule TaggedDeck do
        use Expresso

        name "tagged"
        description("A talk about tags.")
        author("Ada Lovelace")

        slide "one" do
          heading "One"
        end
      end

      html = TaggedDeck |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ ~s(<meta name="description" content="A talk about tags."/>)
      assert html =~ ~s(<meta name="author" content="Ada Lovelace"/>)
    end
  end

  describe "the theme" do
    test "a dark theme gives the dark scheme, its background, and the light scheme for paper" do
      {document, html} = head(theme: :dracula)
      paper = ~s|:root:where(:not([data-print="slides"]))|

      assert tags(document, "color-scheme") == [{"dark", nil}]
      assert tags(document, "theme-color") == [{Builtin.fetch!(:dracula).roles.background, nil}]
      assert html =~ "@media print { #{paper}, #{paper}[data-scheme] { color-scheme: light; } }"
      refute html =~ ~s(:root[data-scheme="dark"] { color-scheme)
    end

    test "a light theme needs no rule of the color scheme" do
      {_document, html} = head(theme: :github)

      refute html =~ "{ color-scheme:"
    end

    test "two variants give the two schemes, a theme color for each, and a rule for the key t" do
      {document, html} = head(theme: [dark: :dracula, light: :default])

      assert tags(document, "color-scheme") == [{"light dark", nil}]

      assert tags(document, "theme-color") == [
               {"#ffffff", "(prefers-color-scheme: light)"},
               {Builtin.fetch!(:dracula).roles.background, "(prefers-color-scheme: dark)"}
             ]

      assert html =~ ~s(:root[data-scheme="light"] { color-scheme: light; })
      assert html =~ ~s(:root[data-scheme="dark"] { color-scheme: dark; })
    end
  end
end
