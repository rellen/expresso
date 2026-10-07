# Use colors of your own

This guide shows how to give a deck a theme of your own colors, and how to correct each
color that is too weak on its background. For each value of the option, see
[The theme option](../reference/theme-option.md).

## Give the deck your colors

A theme of your own is a map with a `#rrggbb` color for each slot of base16, from `:base00`
to `:base0F`. `base00` is the background, `base01` the background of the code, `base05` the
text, `base03` the comments, and `base08` to `base0F` the accents. The roles in
[the theme option](../reference/theme-option.md#the-roles) give each slot its purpose.

1. Start from a base16 scheme, or write 16 colors of your own:

   ```elixir
   theme %{
     base00: "#13233a",
     base01: "#1b2f4b",
     base02: "#27405f",
     base03: "#4f6a8a",
     base04: "#8fa3bc",
     base05: "#dfe7f1",
     base06: "#eef3f9",
     base07: "#ffffff",
     base08: "#e0605a",
     base09: "#e8964a",
     base0A: "#e6c45c",
     base0B: "#7cbf6e",
     base0C: "#5fbfbf",
     base0D: "#5c9ce6",
     base0E: "#b48ae6",
     base0F: "#c47a5a"
   }
   ```

2. Render the deck. The compiler gives a warning for each color that is too weak on its
   background, and the deck still renders.

## Correct the colors that are too weak

Each warning names the role, the measure, the minimum, and a color for the slot that
passes. These are the first warnings for the map above:

```text
the theme gives muted a lightness contrast of Lc 49, and APCA asks for Lc 60. The color #a3b8d1 for base04 passes
the theme gives accent a lightness contrast of Lc 45, and APCA asks for Lc 60. The color #87bdfe for base0D passes
```

1. Replace the color of each slot in a warning with the color of the warning, such as
   `base04: "#a3b8d1"`. The color keeps the hue of the slot, and only its lightness
   changes.
2. Render the deck again.
3. Do the steps again until the compiler gives no warning.

A slot that colors two roles, such as `base05` for the text and for the code, gets one
color that passes for each role. When a warning says that no lightness of a color passes,
change the hue of the slot or the background.

## Let Expresso correct the colors

To keep the hue of each color and let Expresso find the lightness, give the map with
`adjust: true`:

```elixir
theme colors: %{base00: "#13233a", ...}, adjust: true
```

1. Render the deck. The document gets each color that passes, as a built-in theme does.
2. Read the warnings. A warning tells you when a color moves more than 0.4 in lightness,
   because the color can then look different from your map.

Your map stays as you write it, so the slides and your map can show different colors.
Copy the colors of the warnings into the map, as above, to keep the two the same.

## The complete deck

This deck has the map above with each color of the warnings. The compiler gives no
warning, and the dimmed item keeps its contrast:

```elixir
defmodule Examples.ThemeMap do
  use Expresso

  theme %{
    base00: "#13233a",
    base01: "#1b2f4b",
    base02: "#27405f",
    base03: "#9fbde0",
    base04: "#a3b8d1",
    base05: "#dfe7f1",
    base06: "#eef3f9",
    base07: "#ffffff",
    base08: "#fea198",
    base09: "#faa75b",
    base0A: "#e6c45c",
    base0B: "#86ca78",
    base0C: "#69c9c9",
    base0D: "#87bdfe",
    base0E: "#cfa9fe",
    base0F: "#c47a5a"
  }

  slide "harbor" do
    heading "Harbor"

    code "elixir" do
      text ~S"""
      # Count the slides of a deck
      def count(%{slides: slides}), do: length(slides)
      """
    end

    list do
      reveal true
      dim true
      item "A dimmed item"
      item "The next item"
    end
  end
end

Examples.ThemeMap
```

![A slide in the colors of the map, and the first item dims at step 2](https://raw.githubusercontent.com/rellen/expresso/media/theme-map.gif)
