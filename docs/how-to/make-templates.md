# Make templates of your own

This guide shows how to put a value of each slide into the header, such as the part of the
talk, and how to give each slide the same slide template of your own. For each option, see
[The template option](../reference/template-option.md).

## Show the part of the talk in the header

1. Give each slide its part with `meta`:

   ```elixir
   slide "boxes" do
     heading "Every thing is a box"
     meta section: "Part 1: the picture"
   end
   ```

2. Write a deck template that reads the value from `@slide.metadata[:meta]`. A slide
   without `meta` has no value, so give a default, such as the name of the deck:

   ```elixir
   def header(assigns) do
     temple do
       div do
         span class: "header" do
           Keyword.get(@slide.metadata[:meta] || [], :section, @deck.name)
         end
       end
     end
   end
   ```

3. Give the module to the deck with `template`.

A value of `meta` stays under the key `:meta`, so it cannot replace an option of the slide,
such as `heading`.

## Give each slide your slide template

1. Write a slide template with `render/1`. Write the elements with
   `Expresso.Template.render_elements/1`.
2. Give the module to the deck with `slide_template`. Each slide then uses it.
3. Give `template {:builtins, :default}` to a slide that keeps the built-in slide template,
   such as the title slide.

The class `slide-body` gives your template the padding at the sides of the built-in
template. A rule of the `css` option can then style the parts of your template.

## The complete deck

This deck shows the part of the talk in the header. Its slide template puts the heading at
the left, with a bar in the accent color. The title slide keeps the built-in slide
template:

```elixir
defmodule Examples.SectionHeader do
  use Expresso.Template.Deck

  def header(assigns) do
    temple do
      div do
        span class: "header" do
          Keyword.get(@slide.metadata[:meta] || [], :section, @deck.name)
        end
      end
    end
  end

  def footer(_assigns) do
    temple do
      div do
      end
    end
  end
end

defmodule Examples.HeadingAtLeft do
  use Expresso.Template

  def render(assigns) do
    temple do
      div class: "slide-body heading-at-left" do
        h2 do: Map.get(@metadata, :heading, @name)

        div class: "slide-main" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end

defmodule Examples.TemplateSection do
  use Expresso

  name "The factory"
  template Examples.SectionHeader
  slide_template Examples.HeadingAtLeft

  css """
  .heading-at-left h2 { border-left: 0.2rem solid var(--accent); padding-left: 0.5rem; }
  """

  slide "title" do
    heading "The factory"
    template {:builtins, :default}
  end

  slide "boxes" do
    heading "Every thing is a box"
    meta section: "Part 1: the picture"
    text_area(text: "A box has a size and a place.")
  end

  slide "cycle" do
    heading "The cycle of a machine"
    meta section: "Part 2: the loop"
    text_area(text: "Each machine takes, works and gives.")
  end
end

Examples.TemplateSection
```

![The header shows the name of the deck, then the part of each slide, and the heading of each part is at the left](https://raw.githubusercontent.com/rellen/expresso/media/template-section.gif)
