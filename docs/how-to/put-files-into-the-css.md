# Put a picture or a font into the style sheet

This guide shows how to use a picture or a font of your own in a rule of the deck. The
document holds the file, so the deck needs no network. For each rule, see
[Files in the style sheet](../reference/css-option.md#files-in-the-style-sheet).

## Use a file in a CSS file

1. Put the rules of the deck in a CSS file, such as `styles/deck.css`.
2. Put the picture or the font near the CSS file.
3. Name the file with `url()` and a path from the directory of the CSS file, as in a
   browser:

   ```css
   .slide-heading-container {
     background: url(band.png) center / cover;
   }
   ```

4. Give the CSS file to the deck. With `root __DIR__`, the path of the CSS file starts
   from the deck file:

   ```elixir
   root __DIR__
   css "styles/deck.css"
   ```

5. Render the deck. The document holds the file as a data URI.

## Use a font of your own

1. Put the font file near the CSS file, such as `styles/fonts/talk.woff2`. The types
   `.woff2`, `.woff`, `.ttf` and `.otf` go into the document.
2. Write an `@font-face` rule with the font, and use the font in a rule:

   ```css
   @font-face {
     font-family: "Talk";
     src: url(fonts/talk.woff2) format("woff2");
   }

   html {
     font-family: "Talk", sans-serif;
   }
   ```

Make sure that the license of the font lets you put the font into a document that you give
to other people.

## The complete deck

This deck gives each heading a band with the picture `examples/logo.png`. The CSS file is
`examples/animations/styles/band.css`, so its `url()` starts from `styles/`:

```css
/* A band behind the heading of each slide. The path of url() starts from the
   directory of this file. */
.slide-heading-container {
  background: url(../../logo.png) center / cover;
  color: #ffffff;
}
```

```elixir
defmodule Examples.CssFiles do
  use Expresso

  root __DIR__
  css "styles/band.css"

  slide "one" do
    heading "A band from a file"
    text_area(text: "The style sheet names the picture with url().")
  end

  slide "two" do
    heading "The same band"
    text_area(text: "The document holds the picture one time.")
  end
end

Examples.CssFiles
```

![The heading of each slide has the picture as its background](https://raw.githubusercontent.com/rellen/expresso/media/css-files.gif)
