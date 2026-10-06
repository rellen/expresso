# The template option

The `template` option selects a template, which makes the HTML of a part of each slide. A
deck template makes the header and the footer. A slide template makes the body of the
slide.

## Where you write it

| Place | Default | Effect |
| --- | --- | --- |
| `template` of the deck | `{:builtins, :default}` | The header and the footer of each slide. |
| `slide_template` of the deck | `{:builtins, :default}` | The body of each slide without a `template` option. |
| `template` of a slide | The `slide_template` of the deck | The body of this slide. |

`Expresso.Builder` takes the same options, such as
`deck(slides, template: MyDeckTemplate, slide_template: MySlideTemplate)` and
`slide("first", template: MySlideTemplate)`.

## The values

| Value | Template |
| --- | --- |
| `{:builtins, :default}` | The built-in template. It is the only built-in template at this time. |
| A module, such as `MySlideTemplate` | That module. |

The DSL refuses a value of a different type. The module must exist when the deck renders.
A module that does not exist gives an `UndefinedFunctionError` at render.

## A deck template

A deck template uses `Expresso.Template.Deck`, and it defines `header/1` and `footer/1`.
Each function takes the assigns `@deck` and `@slide`, and it returns HTML from Temple:

```elixir
defmodule MyDeckTemplate do
  use Expresso.Template.Deck

  def header(assigns) do
    temple do
      div class: "my-header" do
        Keyword.get(@slide.metadata[:meta] || [], :section, @deck.name)
      end
    end
  end

  def footer(_assigns) do
    temple do
      div class: "my-footer" do
        "expresso.example"
      end
    end
  end
end
```

This header writes the section of the slide from the `meta` option, or the name of the
deck. The default deck template writes the name of the deck in the header, and its footer
is empty. The `slide_numbers` option writes the number of the slide next to the footer of
each deck template.

## A slide template

A slide template uses `Expresso.Template`, and it defines `render/1`. The function takes
the assigns `@name`, `@metadata` and `@elements` of the slide.
`Expresso.Template.render_elements/1` writes the elements:

```elixir
defmodule MySlideTemplate do
  use Expresso.Template

  def render(assigns) do
    temple do
      div class: "my-slide" do
        h2 do: Map.get(@metadata, :heading, @name)
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
```

`@metadata` holds the options of the slide, such as `:heading` and `:notes`. The default
slide template writes the heading, then the elements.

## Values of your own

The `meta` option of a slide takes a keyword list of your own values, such as
`meta section: "Part 1"`. Each template reads it from the metadata: a slide template from
`@metadata[:meta]`, and a deck template from `@slide.metadata[:meta]`. The values stay
under the key `:meta`, so a value cannot replace an option of Expresso. A slide without
the option has no key `:meta`.

## Use the templates

Give the deck template to the deck with `template`, and the slide template of each slide
with `slide_template`. The `template` option of a slide replaces the slide template for
that slide:

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"
  template MyDeckTemplate
  slide_template MySlideTemplate

  slide "first" do
    heading "Hello"
    meta section: "Part 1"

    text_box do
      text_area(text: "A slide with my slide template")
    end
  end

  slide "second" do
    template {:builtins, :default}

    text_box do
      text_area(text: "A slide with the built-in slide template")
    end
  end
end
```

## Rules

- The template modules must compile before the deck renders. Put them in the same script
  as the deck, in front of the deck.
- `Expresso.load_templates/0` compiles each file in `./priv/templates/decks/` and in
  `./priv/templates/slides/` before a render. A module in one of these files is available
  as a template.
- The watch mode renders again after a change to a file in `./priv/templates/`.
- For the design of the templates, see "The templates" in
  [the architecture](../architecture.md).
