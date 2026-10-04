# Style one slide or one element

This guide shows how to change the style of one slide or of one element, and keep the
style of the other slides. For each value of the option, see
[The class option](../reference/class-option.md).

## Make the code of one slide smaller

1. Give the slide a class name:

   ```elixir
   slide "the loop" do
     class "dense"

     code "js" do
       src "assets/src/main.ts"
       lines 120..160
     end
   end
   ```

2. Write a rule for that class in the `css` option of the deck:

   ```elixir
   css ~S"""
   .dense .code pre {
     font-size: 0.4rem;
   }
   """
   ```

3. Render the deck, and open it with `?check` at the end of the address. The report shows
   whether the code still breaks. See [Check that a deck fits the screen](check-the-layout.md).

The other slides keep the size of the theme.

## Give one element a different look

Give the element a class name, and write a rule for it:

```elixir
css ~S"""
.warning {
  border-left: 0.2rem solid var(--warning);
  padding-left: 0.5rem;
}
"""

slide "a warning" do
  text_box do
    class "warning"
    text_area(text: "Do not run this in production.")
  end
end
```

Use a role of the theme, such as `var(--warning)`, so the color changes with the theme.
[The theme option](../reference/theme-option.md) lists the roles.

## Make a color of your own dim

A rule of the deck that gives a color to text does not dim with the state `dim`. Do these
steps for such a rule:

1. Find the role of the color, such as `--accent`. Its dimmed color has the same name with
   `-dim` at the end, such as `--accent-dim`.
2. In the rule, write the color as a mix of the role and its dimmed color. Use `--dimmed`
   as the amount.
3. Render the deck, and go to a step where the element dims. The text of the element
   changes to the dimmed color.

In this deck, the first item has the accent color. It changes to `--accent-dim` when the
second item shows:

```elixir
defmodule Examples.OverlayDimColor do
  use Expresso

  css ~S"""
  .callout {
    color: color-mix(
      in srgb,
      var(--accent-dim) calc(var(--dimmed) * 100%),
      var(--accent)
    );
  }
  """

  slide "dim color" do
    heading "Dim a color of your own"

    list do
      reveal true
      dim true

      item "A point in the accent color" do
        class "callout"
      end

      item "The next point"
      item "The last point"
    end
  end
end

Examples.OverlayDimColor
```

![The item in the accent color dims when the next item shows](https://raw.githubusercontent.com/rellen/expresso/media/overlay-dim-color.gif)

The text then dims as the text of the theme does, and it keeps 3:1 and Lc 30 on its
background. Each built-in role has a dimmed color. For the names, see
[The theme option](../reference/theme-option.md).

## Use the same style on many slides

Give each of those slides the same class name. One rule then styles each of them:

```elixir
slide "first listing" do
  class "dense"
  # ...
end

slide "second listing" do
  class "dense"
  # ...
end
```
