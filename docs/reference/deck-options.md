# The deck options

This page lists each option that a deck takes. Write an option in the deck to apply it to
each slide:

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"
  theme :dracula
  slide_numbers true

  slide do
    heading "Hello"
  end
end
```

| Option | Effect |
| --- | --- |
| `transition :slide` | How each slide comes in: `:fade`, `:slide`, `:zoom`, `:none` or a transition of the `css` option. The default is `:fade`. |
| `morph :named` | Which elements move from one slide to the next: `:auto`, `:named` or `:off`. The default is `:auto`. See [the morph option](morph-option.md). |
| `duration 20` | The length of the talk in minutes. The speaker view then shows the time left. |
| `progress false` | Hide the progress bar at the start. |
| `slide_numbers true` | Show the number of each slide, such as `3 / 12`. |
| `handout :last` | The pages of the handout view: `:last` or `:all`. |
| `print_notes false` | Leave the notes out of the handout view and of the print. |
| `css "deck.css"` | A style sheet, or the path of one. It applies after the theme. |
| `effect`, `speed`, `easing` | The animation of each overlay. See [Animate elements in a slide](../how-to/animate-elements.md). |
| `root __DIR__` | The directory of each relative path of the deck. See [the root option](root-option.md). |
| `template MyDeckTemplate` | A module that makes the header and the footer. See [the template option](template-option.md). |
| `slide_template MySlideTemplate` | A module that makes the body of each slide. |
| `lang "de"` | The language of the text of the deck, for a screen reader. The default is `"en"`. See [the lang option](lang-option.md). |
| `dim_contrast 4.5` | The minimum contrast of dimmed text, from 3 to 7. The default is 3. See [the dim_contrast option](dim-contrast-option.md). |
| `window :macos` | A frame that looks like a window around each code element, image and embed: `:macos`, `:terminal`, `:plain` or `:none`. The default is `:none`. See [the window option](window-option.md). |
| `icons logo: "assets/logo.svg"` | SVG files of your own for the `icon` element and for `:icon:name:` in a text. See [the icon element](icon-element.md). |
| `theme :dracula` | The colors of the slides and of the code. Each built-in theme meets the contrast minimums of WCAG. `theme dark: :dracula, light: :default` gives two variants. See [the theme option](theme-option.md). |


## The options of a slide

slide replaces the option of the deck for that slide. The `template` option of a slide
replaces `slide_template`, and its `meta` option gives values of your own to the
templates.

