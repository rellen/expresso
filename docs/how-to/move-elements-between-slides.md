# Move elements from one slide to the next

This guide shows how to move an element from its place on one slide to its place on the
next slide. For each value, see [The morph option](../reference/morph-option.md).

## Let the deck find the elements

The deck finds the elements that two neighbor slides share, and it moves them. You do not
write an option. This deck shows a total, then puts the total into a column next to its
detail:

```elixir
defmodule Examples.Morph do
  use Expresso

  slide "total" do
    heading "This year"

    stat 1250 do
      label "orders"
    end
  end

  slide "detail" do
    heading "This year"

    columns do
      column do
        stat 1250 do
          label "orders"
        end
      end

      column do
        text_area(text: "Up from 900 last year, and each month grew.")
      end
    end
  end
end

Examples.Morph
```

The two stats have the same label, so they are partners. The two headings have the same
text, so the heading stays. The text fades in:

![A stat moves from the center of a slide into a column](https://raw.githubusercontent.com/rellen/expresso/media/morph.gif)

## Change code in place

Two code elements with the same language are partners. Each token that the two codes share
moves to its new place, and the new tokens fade in:

```elixir
defmodule Examples.MorphCode do
  use Expresso

  slide "first" do
    heading "A greeting"

    code "elixir" do
      text """
      def greet(name) do
        "Hello, " <> name
      end
      """
    end
  end

  slide "second" do
    heading "A greeting"

    code "elixir" do
      text """
      def greet(name, greeting \\\\ "Hello") do
        greeting <> ", " <> name
      end
      """
    end
  end
end

Examples.MorphCode
```

![The tokens of a function move to their places in a longer function](https://raw.githubusercontent.com/rellen/expresso/media/morph-code.gif)

## Give two elements a key

Give two elements the same `morph` key to make them partners. Use a key when the two
elements have a different content or a different kind, or when a slide has two elements
with the same content. This deck moves the icon of the cover into a column of the agenda,
and the icon gets smaller:

```elixir
defmodule Examples.MorphKey do
  use Expresso

  slide "cover" do
    icon "coffee" do
      label "Expresso"
      size "8em"
      color :accent
      morph "brand"
    end
  end

  slide "agenda" do
    columns do
      column do
        width "25%"

        icon "coffee" do
          label "Expresso"
          size "3em"
          color :accent
          morph "brand"
        end
      end

      column do
        list do
          item "Why slides from code"
          item "The DSL"
          item "The presenter"
        end
      end
    end
  end
end

Examples.MorphKey
```

![An icon moves from the center of the cover to a column of the next slide and gets smaller](https://raw.githubusercontent.com/rellen/expresso/media/morph-key.gif)

## Move only the elements with a key

Write `morph :named` in the deck to move only the elements with a key. Write `morph :off`
to stop the morph. A slide can have its own mode for the change from the slide before:

```elixir
defmodule Examples.MorphModes do
  use Expresso

  morph :named

  slide "cover" do
    heading "Expresso"
  end

  slide "agenda" do
    morph :off
    heading "Expresso"
  end
end
```
