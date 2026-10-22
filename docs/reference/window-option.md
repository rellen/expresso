# The window option

The `window` option puts a code element, an image or an embed into a frame that looks like
a window of an operating system. The frame has a bar with a title, and it can have the three
colored dots of macOS.

```elixir
defmodule MyDeck do
  use Expresso

  window :macos

  slide "the server" do
    code "elixir", src: "lib/my_app/server.ex"
  end

  slide "the tests" do
    code do
      window :terminal
      window_title "~/my_app — zsh"
      text "$ mix test"
    end
  end
end
```

`Expresso.Builder` takes the same options, such as `code(text: "x", window: :plain)` and
`deck(slides, window: :macos)`.

[Show code on a slide](../how-to/show-code.md#put-the-code-into-a-window) gives an example
deck with its recording.

## The styles

| Style | The bar | The corners |
| --- | --- | --- |
| `:macos` | Three dots at the left, and the title at the center. | Round |
| `:terminal` | Three dots, and the title at the left in the font of the code. The bar has the color of the code, so the bar and the code are one surface. | Round |
| `:plain` | The title at the left, and no dots. | Almost square |
| `:none` | No frame. | |

The dots take the colors of the roles `danger`, `warning` and `success` of the theme, as the
red, yellow and green dots of macOS.

## The options

| Option | Where | Value | Effect |
| --- | --- | --- | --- |
| `window` | The deck | A style | The style of each code element, image and embed without the option. The default is `:none`. |
| `window` | A `code`, `image` or `embed` element | A style | The style of the element. It replaces the style of the deck, and `:none` turns off the frame. |
| `window_title` | A `code`, `image` or `embed` element | A string | The text of the bar. |

A code element with `src` and without `window_title` shows the name of its file, such as
`server.ex`. Each other element without `window_title` has a bar with no text.

The frame does not change the steps of the element. The lines of a code element still show,
dim and come into focus as their options give.

## The look

A deck can change these custom properties in the `css` option:

| Property | Effect | Default |
| --- | --- | --- |
| `--window-border` | The color of the border and of the line under the bar | the muted color at 45% |
| `--window-radius` | The radius of the corners | `0.35rem`, or `0.15rem` for `:plain` |
| `--window-background` | The color behind the content | the color of the code for a code element, else the background color |
| `--window-bar-background` | The color of the bar | a mix of the muted color and the background, or the color of the code for `:terminal` |
| `--window-shadow` | The shadow of the frame | a soft black shadow |
| `--window-bar` | The height of the bar | `1.1rem` |

## The HTML

The element holds a `div` with the classes `window` and `window-<style>`, such as
`window window-macos`. The frame holds:

1. A `div` with the class `window-bar`. It holds a `span` with the class `window-dots` and
   `aria-hidden="true"` for `:macos` and `:terminal`, then a `span` with the class
   `window-title`. A screen reader reads the title and not the dots.
2. The content of the element: the `pre` of a code element, the `img` of an image, or the
   `embed-box` of an embed.
