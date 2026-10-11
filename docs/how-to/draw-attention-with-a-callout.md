# Draw attention with a callout

This guide shows how to put a note, a tip or a warning into a box of its own, and how to
show each box at its own step. For each option, see
[The callout element](../reference/callout-element.md).

## Put a note and a warning on a slide

Write a `callout` element with a kind, and put the text into it with a `text_area`. The kind
gives the box its color, its icon and its title. The `at` option of each callout shows it at
a step, so the audience reads one box at a time:

```elixir
defmodule Examples.Callout do
  use Expresso

  slide "deploy" do
    heading "Deploy a release"

    callout :note do
      text_area(text: "The release holds the runtime of Erlang.")
    end

    callout :tip do
      at from: 2
      text_area(text: "Build it on the system of the server.")
    end

    callout :warning do
      at from: 3
      text_area(text: "A hot upgrade needs an appup file.")
    end
  end
end

Examples.Callout
```

![The note shows first, then the tip at step 2 and the warning at step 3](https://raw.githubusercontent.com/rellen/expresso/media/callout.gif)

Use `at from: 2`, and not `at 2`, to keep a callout on the slide after its step.

## Choose a kind

Choose the kind that tells the audience why the box is there. The seven kinds have different
colors and icons:

```elixir
defmodule Examples.CalloutKinds do
  use Expresso

  slide "kinds" do
    heading "The seven kinds"

    columns do
      column do
        callout :note
        callout :tip
        callout :important
        callout :warning
      end

      column do
        callout :caution
        callout :definition
        callout :example
      end
    end
  end
end

Examples.CalloutKinds
```

![The seven kinds of the callout, each with its icon and its color](https://raw.githubusercontent.com/rellen/expresso/media/callout-kinds.png)

A callout with no elements shows only its header, as on this slide.

## Give a callout a title of its own

The `title` option replaces the name of the kind. For a definition, give the term as the
title:

```elixir
callout :definition do
  title "Release"
  text_area(text: "A package of the compiled code and the runtime of Erlang.")
end
```

`title false` removes the header, and the box keeps its color and its border.

## Change the color of a kind

Each kind reads its color from a role of the theme, so the colors follow the theme. To give
a kind a different color, set `--callout-color` and `--callout-dim` for its class in the
`css` option of the deck:

```elixir
css """
.callout-example {
  --callout-color: var(--accent);
  --callout-dim: var(--accent-dim);
}
"""
```
