# Give a deck a light and a dark variant

This guide shows how to give a deck two variants of its colors, so one document suits a
light room and a dark room. For each rule, see
[Two variants](../reference/theme-option.md#two-variants).

## Give the deck two variants

1. Choose a dark theme and a light theme. Each one is the name of a built-in theme or a
   map of your own colors.
2. Give them to the `theme` option:

   ```elixir
   theme dark: :tokyo_night_storm, light: :solarized_light
   ```

3. To adjust a map of your own to the minimums of contrast, add `adjust: true`:

   ```elixir
   theme dark: %{base00: "#13233a", ...}, light: :default, adjust: true
   ```

4. Render the deck. The document shows the variant of the scheme of the screen.

## Change the variant during the talk

1. Press `t` in the window of the audience or in the speaker view. The two windows show
   the other variant.
2. Press `t` again to go back.

A load of the document shows the variant of the screen again. Paper gets the default theme
with each variant.

In the speaker view, the key changes the two pages of the slides, as it changes the
window of the audience:

![The speaker view shows the light variant, and the key t shows the dark variant](https://raw.githubusercontent.com/rellen/expresso/media/theme-variants-speaker.gif)

## Start the talk in one variant

The projector of a room can need the dark variant on a computer with a light scheme.
Add `?scheme=dark` to the address:

```text
file:///path/to/deck.html?scheme=dark
```

`?scheme=light` gives the light variant. The key `t` still shows the other variant. The
key `s` opens the speaker view in the variant of the present view.

## The complete deck

This deck has a dark and a light built-in theme. The window of the recording has a light
scheme, and the key `t` shows the dark variant:

```elixir
defmodule Examples.ThemeVariants do
  use Expresso

  theme dark: :tokyo_night_storm, light: :solarized_light

  slide "two variants" do
    heading "Two variants"

    code "elixir" do
      text ~S"""
      # The key t shows the other variant
      def other(:light), do: :dark
      def other(:dark), do: :light
      """
    end
  end
end

Examples.ThemeVariants
```

![The slide shows the light variant, and the key t shows the dark variant](https://raw.githubusercontent.com/rellen/expresso/media/theme-variants.gif)
