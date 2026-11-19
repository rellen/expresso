# Rules for Expresso

Expresso makes one HTML document from a deck of slides. You write the deck in a DSL of
Elixir, render it with `mix expresso`, and a browser presents the document.

## The shape of a deck

A deck is a module with `use Expresso`. This is a complete deck file, such as `talk.exs`:

```elixir
defmodule Talk do
  use Expresso

  name "A talk about supervisors"
  theme :dracula
  root __DIR__

  slide "title" do
    heading "Supervisors in practice"

    text_box do
      text_area do
        text "A process stops. A supervisor starts it again."
      end
    end
  end

  slide "points" do
    heading "Three points"
    notes "Go **slow** on this slide."

    list do
      reveal true
      item "A supervisor starts its children"
      item "A child stops with an error"
      item "The supervisor starts the child again"
    end
  end
end
```

- Put `use Expresso` on the first line of the module.
- Give each slide a `heading`. `heading` is an option of a slide, and not an element.
- Put a text in a `text_area`. Expresso has no `text` element and no `paragraph` element.
- Put a `text_area` in a `text_box`, a `column` or a `callout`.
- A text accepts HTML. Write `&lt;` for the character `<` in a text.
- Give a slide a name, such as `slide "points"`, when a `goto` link refers to it.
- Give the deck `root __DIR__`. Each path of the deck is then relative to the deck file.
- A slide is a column with a flexible height. Put no more than six short items on one slide.

## Render, watch and check

```sh
mix expresso talk.exs talk.html      # render one HTML document
mix expresso talk.exs --watch        # serve the deck, and reload it after each change
mix expresso talk.exs --check        # check the deck, and write a report
mix expresso talk.exs --check=layout # also measure each slide in Chrome or Chromium
mix expresso talk.exs --pdf talk.pdf # a PDF with one page for each slide
mix expresso talk.exs --png slides   # a PNG file of each slide
```

- Run `mix expresso <deck> --check` after each change to a deck. Exit status 1 shows a problem.
- Read each line of the report, and correct each line under `Problems:`.
- Make the directory of the output file before the render. The render does not make it.
- Do not edit the HTML document. Change the deck, and render it again.
- `--check=layout`, `--check=a11y`, `--check=browser`, `--pdf` and `--png` need Chrome or Chromium.

## The steps of a slide

An overlay divides a slide into steps. Step 1 is the first step, and the key `j` goes to
the next step.

```elixir
defmodule Steps do
  use Expresso

  slide "steps" do
    heading "Steps"

    list do
      reveal true
      dim true
      item "This item shows at step 1"
      item "This item shows at step 2"
    end

    text_box do
      at from: 3
      on 4, state: :alert
      on [from: 5], set: [x: "-4rem", opacity: 0.5]

      text_area do
        text "This box shows from step 3."
      end
    end
  end
end
```

| Option | Effect |
| --- | --- |
| `reveal true` | Each child gets a step of its own: an item, a row, a series, a group of lines. |
| `dim true` | Each earlier child dims when a later child shows. Use it with `reveal true`. |
| `at 2`, `at 2..4`, `at from: 2`, `at [2, 5..7]` | The steps that show the element. |
| `on 3, state: :alert` | An outline around the element at step 3. |
| `on 3, state: :dim` | The dimmed colors at step 3. |
| `on 3, set: [x: "4rem", y: "0", scale: 1.5, rotate: "-8deg", opacity: 0.3, color: "#c92a2a"]` | A move, a size, a turn, an opacity or a color at step 3. |
| `effect :fly_up` | How the element shows, such as `:fade`, `:grow`, `:fly_up`, `:wipe`, `:blur` or `:type`. |
| `auto_reveal true` on a slide | Each element of the slide gets a step of its own. |

- Do not use step 0. The first step is step 1.
- A child shows only at the steps of its parent.
- Use `reveal true` for a list. Do not give each item its own `at`.

## The elements

| Element | Use | A short form |
| --- | --- | --- |
| `text_box`, `text_area` | A text | `text_box do text_area(text: "A text") end` |
| `list`, `item` | A list of points | `list do item "A point" end` |
| `image` | An image file | `image "photo.jpg", alt: "The team", width: "60%"` |
| `code` | Code with colors, from a file or from a text | `code "elixir" do src "lib/app.ex" end` |
| `columns`, `column` | Two or more columns | `columns do column do list do item "Left" end end end` |
| `table`, `row` | A table | `table do header true; row ["Key", "Action"]; row ["j", "Next"] end` |
| `chart` | A chart from data | `chart :bar do title "Orders"; categories ["2024", "2025"]; series "Orders", [180, 240] end` |
| `diagram` | An SVG file, or a graph of Graphviz, D2 or Mermaid | `diagram "flow.svg" do alt "A request goes to the server" end` |
| `math` | A formula in LaTeX | `math tex: ~S"E = mc^2"` |
| `tree`, `node` | A hierarchy | `tree do title "The team"; node "Ana" do node "Ben" end end` |
| `callout` | A note, a tip or a warning | `callout :warning do text_area(text: "Read the log first.") end` |
| `quotation` | A quotation | `quotation "Less is more." do by "Mies van der Rohe" end` |
| `stat` | One large number | `stat 1250 do label "orders this year" end` |
| `video` | A video file | `video "demo.webm" do title "The demo"; poster "demo.png" end` |
| `embed` | A web page | `embed "https://example.com/" do title "The page"; fallback "page.png" end` |
| `qr_code` | A QR code of an address | `qr_code "https://example.com/talk/"` |
| `audio`, `icon`, `shape`, `spacer`, `footnote`, `toc` | Small parts of a slide | See the reference page of each one. |

- Read `docs/reference/<name>-element.md` before you use an element. Do not guess an option.
- A chart takes one of 13 kinds, such as `:bar`, `:line`, `:pie`, `:scatter`, `:treemap`,
  `:sankey` and `:waterfall`.
- A `chart` and a `tree` need a `title` option.
- A `code` element takes `src` with a path, or `text` with the code. Do not give both.
- Write LaTeX in a sigil with no escape, such as `~S"\frac{a}{b}"`.
- A `math` element with `tex` and a graph of Mermaid need Node at the render.

## The options of a deck

| Option | Effect |
| --- | --- |
| `name "A talk"` | The title of the document. |
| `theme :dracula` | One of 27 built-in themes. `theme dark: :dracula, light: :default` gives two variants. |
| `transition :slide` | How each slide comes in: `:fade`, `:slide`, `:zoom` or `:none`. |
| `duration 20` | The length of the talk in minutes, for the speaker view. |
| `lang "de"` | The language of the text, for a screen reader. |
| `slide_numbers true` | The number of each slide. |
| `css "deck.css"` | A style sheet of your own, after the theme. |
| `external true` | Keep each image, video and sound file next to the document. |
| `description "..."`, `url "https://example.com/talk/"`, `card "card.png"` | The tags for a search engine and for a link preview. |

`docs/reference/deck-options.md` lists each option. A slide can replace `transition`,
`background` and `advance` for itself.

## Notes for the speaker

- `notes "..."` in a slide gives the note of the slide. The text is Markdown.
- `note "...", at: 2` gives a note for one step.
- The key `s` opens the speaker view, which shows the notes.

## A deck from data

A module of the DSL accepts a `for` loop around `slide` and around `item`. A program can
also make a deck with `Expresso.Builder`, which has one function for each entity:

```elixir
defmodule FromData do
  import Expresso.Builder

  def deck do
    topics = [{"Why Elixir", ["Concurrency", "Fault tolerance"]}]

    slides =
      for {title, points} <- topics do
        slide(title,
          heading: title,
          elements: [list(reveal: true, elements: Enum.map(points, &item/1))]
        )
      end

    deck(slides, name: "A talk from data")
  end
end
```

- A function of `Expresso.Builder` takes the arguments of the entity, then a keyword list.
- Give the children of an element in the `elements` key.
- A deck file can end with a call to `deck/2` in place of a module.

## Lengths

- Use `rem` or pixels for a length, such as `"4rem"` or `"300px"`. 48 pixels are 1rem.
- A percentage of a `width` option is a part of the width of the slide.
- In the `css` option, use `rem` and not pixels. A slide becomes smaller in a small window.

## Accessibility

- Give each `image` an `alt` option, unless the image is decorative.
- Give each `diagram` an `alt` option, and each `video`, `audio` and `embed` a `title`.
- Do not give a `video` the option `controls true` when the audience can use forced colors.
  Chromium does not show the controls of a video in forced colors.
- Do not tell a meaning with a color only. Add a word, or a state such as `:alert`.
- Give the deck the `dim_contrast` option when it has small dimmed text. See
  `docs/reference/dim-contrast-option.md`.

## More documents

The documents are in the package, which is `deps/expresso/` in your project. Each path of
this file starts at that directory:

- `docs/tutorials/make-your-first-deck.md` teaches the basics.
- `docs/how-to/` has one guide for each task, such as `animate-elements.md` and `show-code.md`.
- `docs/reference/` has one page for each element and each option.
- `docs/reference/presenter.md` gives each key of the presenter.
