# Show the plan of a talk

This guide shows how to divide a deck into sections, how to show an agenda that builds one
section at a time, and how to remind the audience where the talk is. For each option, see
[The toc element](../reference/toc-element.md).

## Divide the deck into sections

Give the first slide of each section a `section` option with its title. A section runs to
the next slide with a `section` option, so the other slides of a section need no option.

## Show an agenda that builds

Write a `toc` element on the agenda slide. The toc lists each section, with a link to its
first slide. The `reveal` option shows one entry at each step, so you can say a few words
about each part before the next one shows:

```elixir
defmodule Examples.Toc do
  use Expresso

  slide "agenda" do
    heading "Agenda"

    toc do
      reveal true
    end
  end

  slide "why" do
    section "Why a release"
    heading "Why a release"
  end

  slide "build" do
    section "Build it"
    heading "Build it"
  end

  slide "test" do
    section "Test it"
    heading "Test it"
  end

  slide "deploy" do
    section "Deploy it"
    heading "Deploy it"
  end
end

Examples.Toc
```

![The agenda shows the first section, then each later section at the next step](https://raw.githubusercontent.com/rellen/expresso/media/toc.gif)

Add `dim true` to dim each entry when the next entry shows. The audience then reads the
newest entry:

```elixir
toc do
  reveal true
  dim true
end
```

## Show where the talk is

Put a toc on the first slide of each section. The entry of the current section takes the
accent color, and the other entries dim:

```elixir
defmodule Examples.TocRecap do
  use Expresso

  slide "why" do
    section "Why a release"
    heading "Where we are"
    toc()
  end

  slide "build" do
    section "Build it"
    heading "Where we are"
    toc()
  end

  slide "test" do
    section "Test it"
    heading "Where we are"
    toc()
  end

  slide "deploy" do
    section "Deploy it"
    heading "Where we are"
    toc()
  end
end

Examples.TocRecap
```

![The recap marks each section in turn with the accent color, and dims the other sections](https://raw.githubusercontent.com/rellen/expresso/media/toc-recap.gif)

A click on an entry in the present view goes to the first slide of its section. Use it to
answer a question about an earlier part of the talk.

## Mark the sections that are done

The `progress` option tells how the other entries look. `:dim_earlier` dims only the earlier
sections, `:check_earlier` puts a check mark after each earlier section, and
`:strike_earlier` puts a line through each earlier section:

```elixir
defmodule Examples.TocProgress do
  use Expresso

  slide "why" do
    section "Why"
    heading "Why"
  end

  slide "build" do
    section "Build"
    heading "Build"
  end

  slide "progress" do
    section "Test"
    heading "The progress option"

    columns do
      column do
        text_area(text: "Dim the rest")
        toc()
      end

      column do
        text_area(text: "Dim earlier")

        toc do
          progress :dim_earlier
        end
      end

      column do
        text_area(text: "Check earlier")

        toc do
          progress :check_earlier
        end
      end

      column do
        text_area(text: "Strike earlier")

        toc do
          progress :strike_earlier
        end
      end
    end
  end

  slide "deploy" do
    section "Deploy"
    heading "Deploy"
  end
end

Examples.TocProgress
```

![Four tables of contents on the slide of the third section, one for each value of progress](https://raw.githubusercontent.com/rellen/expresso/media/toc-progress.png)

## Show the section in the header of each slide

A template reads the title of the section of a slide from `@metadata[:section]`. A deck
template can thus write the section in the header of each slide, with no `meta` option on
the slides. See [Make templates of your own](make-templates.md).
