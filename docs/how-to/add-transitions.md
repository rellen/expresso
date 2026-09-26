# Add transitions between slides

This guide shows how to change the transition from one slide to the next. The transition
runs in the present view of the browser. Each section gives a complete deck and a
recording of it. The recording presses `j` for the next slide and `k` for the slide
before.

For the rules of each kind, see [The transition option](../reference/transition-option.md).

## Use the default fade

A deck without the `transition` option fades from one slide to the next. You do not write an
option.

```elixir
defmodule Examples.TransitionFade do
  use Expresso

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionFade
```

![The first slide fades out, and the second slide fades in](https://raw.githubusercontent.com/rellen/expresso/media/transition-fade.gif)

## Push the next slide in from the side

Write `transition :slide` in the deck. The next slide comes in from the right. A move back
brings the slide before in from the left.

```elixir
defmodule Examples.TransitionSlide do
  use Expresso

  transition :slide

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionSlide
```

![The second slide pushes the first slide out to the left](https://raw.githubusercontent.com/rellen/expresso/media/transition-slide.gif)

## Zoom into the next slide

Write `transition :zoom` in the deck. The next slide grows from the center, and the slide
before fades out. A move back plays the zoom in reverse.

```elixir
defmodule Examples.TransitionZoom do
  use Expresso

  transition :zoom

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionZoom
```

![The second slide grows from the center of the window](https://raw.githubusercontent.com/rellen/expresso/media/transition-zoom.gif)

## Change the slide at once

Write `transition :none` in the deck. The next slide shows at once, with no animation.

```elixir
defmodule Examples.TransitionNone do
  use Expresso

  transition :none

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The first slide")
    end
  end

  slide "two" do
    heading "Two"

    text_box do
      text_area(text: "The second slide")
    end
  end
end

Examples.TransitionNone
```

![The second slide replaces the first slide at once](https://raw.githubusercontent.com/rellen/expresso/media/transition-none.gif)

## Give one slide its own transition

Write the `transition` option in a slide. The option replaces the transition of the deck
between that slide and the slide before, in the two directions. The other slides keep the
transition of the deck.

```elixir
defmodule Examples.TransitionOverride do
  use Expresso

  transition :fade

  slide "one" do
    heading "One"

    text_box do
      text_area(text: "The deck fades")
    end
  end

  slide "two" do
    heading "Two"
    transition :slide

    text_box do
      text_area(text: "This slide slides in")
    end
  end

  slide "three" do
    heading "Three"

    text_box do
      text_area(text: "This slide fades in")
    end
  end
end

Examples.TransitionOverride
```

![Slide two slides in, and slide three fades in](https://raw.githubusercontent.com/rellen/expresso/media/transition-override.gif)
