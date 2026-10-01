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
