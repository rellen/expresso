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

1. Press `t` in the window of the audience. The document shows the other variant.
2. Press `t` again to go back.

The key changes the window where you press it, so press it in the present view and not
in the speaker view. A load of the document shows the variant of the screen again. Paper
gets the default theme with each variant.

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
