# The callout element

The `callout` element is a box with a kind, a header and other elements, such as a note or
a warning.

```elixir
slide "deploy" do
  callout :warning do
    text_area(text: "A hot upgrade needs an appup file.")
  end
end
```

`Expresso.Builder` takes the same options, such as
`callout(:tip, title: "Faster", elements: [text_area(text: "...")])`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | `:note`, `:tip`, `:important`, `:warning`, `:caution`, `:definition` or `:example`, required | The kind of the callout. The kind gives the color, the icon and the default title. |
| `title` | A string, or `false` | The text of the header in place of the name of the kind. The value `false` removes the header. The text is not HTML. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The kinds

Each kind takes its color from a role of the theme. The header and the icon have that
color, the border has that color, and the box has a light tint of it. The text of the body
keeps the color of the text.

| Kind | Default title | Role | Use |
| --- | --- | --- | --- |
| `:note` | Note | `--accent` | A fact that the audience needs. |
| `:tip` | Tip | `--success` | A better way to do a task. |
| `:important` | Important | `--emphasis` | A fact that the audience must not miss. |
| `:warning` | Warning | `--warning` | A risk to the result. |
| `:caution` | Caution | `--danger` | A risk of damage or of a loss of data. |
| `:definition` | Definition | `--muted` | The meaning of a term. Give the term as the `title`. |
| `:example` | Example | `--success` | An example of the point of the slide. |

![The seven kinds of the callout, each with its icon and its color](https://raw.githubusercontent.com/rellen/expresso/media/callout-kinds.png)

## The content

A callout holds the elements that a text box holds: `text_area`, `image`, `list`, `table`,
`quotation`, `spacer`, `code`, `math`, `diagram`, `embed`, `video`, `audio`, `qr_code` and
`chart`. A callout cannot hold a callout or a `columns` element.

```elixir
slide "the release" do
  callout :example do
    title "Make a release"
    text_area(text: "Run this command:")

    code do
      text "MIX_ENV=prod mix release"
    end
  end
end
```

A slide, a text box and a column can hold a callout. A callout without elements shows only
its header.

Each element of a callout takes its own overlay options, so a callout can build inside. An
element without `at` shows at each step at which the callout shows.

## The HTML

The renderer writes a `div` with the classes `callout` and `callout-<kind>`, and the role
`note`. The header is a `p` with the class `callout-title`, so it does not change the
outline of the headings of the slide. The icon is an inline `svg` with the class
`callout-icon` and `aria-hidden="true"`, so a screen reader reads the title only. The
elements are in a `div` with the class `callout-body`.

A deck can change the color of a kind with the `css` option. Each kind reads
`--callout-color` and `--callout-dim`:

```css
.callout-example {
  --callout-color: var(--accent);
  --callout-dim: var(--accent-dim);
}
```

## The errors

The compiler gives an error for these:

- a kind that is not in the list;
- a `title` that is not a string or `false`.
