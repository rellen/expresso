# The toc element

The `toc` element is a table of contents: a numbered list of the sections of the deck, with
a link to the first slide of each section.

```elixir
slide "agenda" do
  toc do
    reveal true
  end
end

slide "why" do
  section "Why a release"
end

slide "build" do
  section "Build it"
end
```

`Expresso.Builder` takes the same options, such as `toc(reveal: true, dim: true)` and
`slide("why", section: "Why a release")`.

## The section option of a slide

| Option | Value | Effect |
| --- | --- | --- |
| `section` | A string | The title of the section that starts at this slide. |

A section runs from its slide to the next slide with a `section` option. A slide without
the option belongs to the section of the slide before it. The slides before the first
section belong to no section.

A template reads the title of the section of a slide from the metadata of the slide: a
slide template from `@metadata[:section]`, and a deck template from
`@slide.metadata[:section]`. A slide before the first section has no key `:section`. See
[the template option](template-option.md).

## The options of the toc

| Option | Value | Effect |
| --- | --- | --- |
| `reveal` | `true` or `false` | Show the entries one after the other, one at each step. The default is `false`, and each entry shows with the toc. |
| `dim` | `true` or `false` | Dim each entry when a later entry shows. The default is `false`. |
| `progress` | `:dim_rest`, `:dim_earlier`, `:check_earlier` or `:strike_earlier` | How the entries other than the current section look. The default is `:dim_rest`. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

A slide, a text box and a column can hold a toc. A deck can have a toc on more than one
slide, such as an agenda at the start and a recap at the start of each section.

## The current section

The section of the slide of the toc is the current section. Its entry has the accent color
and bold text. The `progress` option tells how each other entry looks:

| Value | Each earlier entry | Each later entry |
| --- | --- | --- |
| `:dim_rest` | Dims. | Dims. |
| `:dim_earlier` | Dims. | Keeps the color of the text. |
| `:check_earlier` | Gets a check mark after its title. | Keeps the color of the text. |
| `:strike_earlier` | Gets a line through its title. | Keeps the color of the text. |

![Four tables of contents on the slide of the third section, one for each value of progress](https://raw.githubusercontent.com/rellen/expresso/media/toc-progress.png)

A toc on a slide before the first section has no current section. Each entry then keeps the
color of the text, whatever the value of `progress`.

## The steps

Without `reveal`, the entries show at each step at which the toc shows. With `reveal`, the
first entry shows at the first step of the toc, and each later entry takes the next step.
Each entry stays after its step. With `dim`, an entry dims at the step of the next entry.

The `dim` option and the `progress` option are independent. On a recap slide, `progress`
marks the current section. On an agenda that builds, `dim` keeps the eye on the newest
entry.

## The HTML

The renderer writes a `nav` with the label "Contents" and the classes `toc` and
`toc-<progress>`, such as `toc-dim-rest`. The `nav` holds an `ol` with one `li` for each
entry. Each `li` has the class `toc-entry` and one of `toc-earlier`, `toc-current`,
`toc-later` or `toc-none`. The entry of the current section has
`aria-current="location"`, so a screen reader names it.

Each title is a link of the [goto option](goto-option.md) with the class `toc-link`. A
click on it in the present view goes to step 1 of the first slide of its section. The title
is text, and not HTML.

## The errors

The compiler gives an error for these:

- a toc in a deck in which no slide has the `section` option;
- a `progress` value that is not in the list.
