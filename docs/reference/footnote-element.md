# The footnote element

The `footnote` element gives a source or a note at the bottom of a slide. The handout view
and paper also get a page of the sources of each slide.

```elixir
slide "the claim" do
  text_box do
    text_area do
      text "Talks with fewer than 20 slides got the best reviews.<sup>1</sup>"
    end
  end

  footnote "The reviews of a conference in 2024, from 312 talks."
end
```

`Expresso.Builder` takes the same options, such as
`footnote("The reviews of a conference in 2024.", at: [from: 2])`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string, required | The text of the footnote. It can contain HTML, such as `<em>` for the title of a book or `<a href>` for a link. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md). The `auto_reveal` option of a slide does not
give a footnote a step of its own, so a footnote without `at` shows at each step.

## The place and the number

A footnote shows nothing in the place where you write it. The renderer puts the footnotes
of a slide into one numbered list under the slide template, in the order of the deck. Each
template thus gets the list, with no change to the template.

| Fact | Rule |
| --- | --- |
| The number | The position of the footnote in the list of its slide, from 1. The next slide starts at 1 again. |
| A mark in the text | Write the number in the text yourself, such as `<sup>1</sup>`. Do not write it in the footnote, because the list gives the number. |
| A footnote at a step | The footnote keeps its number and its space at each step, so the list does not move. |
| A footnote in a text box | The list collects it too. The `at` option of the text box does not apply to it. |

## The page of the sources

The handout view and paper show a page with the title "Sources" after the last slide. The
page holds the footnotes of each slide under the number and the name of the slide. A slide
with no footnote does not show on the page, and a deck with no footnote has no page. The
present view, the speaker view and the overview do not show the page.

## The HTML and the colors

The document writes an `ol` element with the class `footnotes` after the slide template,
and an `li` element with the class `footnote` for each footnote. The page of the sources is
a `section` with the class `sources`, after the last page of the handout view.

The list has the color `--muted` of the theme. Set `--footnote-color` in
[the css option](css-option.md) to change it.
