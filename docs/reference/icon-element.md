# The icon element

The `icon` element shows an icon from the Lucide set, or an SVG file of the deck. An icon
can also go into the text of a text area or an item, with the size of the text.

```elixir
slide "release" do
  icon "rocket" do
    label "Release"
    color :accent
  end

  text_area(text: "Each push runs :icon:circle-check: the checks.")
end
```

`Expresso.Builder` takes the same options, such as
`icon("rocket", label: "Release", size: "5rem")`.

## The options of the element

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A name, required | The name of a Lucide icon, such as `"rocket"`, or a name of the `icons` option of the deck. |
| `label` | A string | The text under the icon. A screen reader reads it. |
| `size` | A CSS length, such as `"5rem"` | The width and the height of the icon. The default is `"3em"`. |
| `color` | `:text`, `:muted`, `:accent`, `:success`, `:emphasis`, `:warning` or `:danger` | The role of the theme that gives the color of the icon and of its label. The default is `:text`. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md). A slide, a text box, a column and a callout can
hold an icon.

## The names

The Lucide set has 1,877 icons. Find a name at [lucide.dev/icons](https://lucide.dev/icons),
and write it as the page writes it, such as `"git-commit-horizontal"`. Expresso holds
`lucide-static` 1.55.0, so an icon that a later version adds is not available.

A name that no icon has is an error. The message gives three names that are near, such as
`rocket` for `rokcet`.

## An icon in a text

`:icon:name:` in the text of a `text_area` or an `item` becomes the icon, with the size of
the text and the color of the text. A name of the `icons` option of the deck works too.

```elixir
slide "checks" do
  list do
    item ":icon:check: The tests pass"
    item ":icon:x: The lint fails"
  end
end
```

## The icons option of the deck

The `icons` option gives names of your own, each with the path of an SVG file:

```elixir
icons logo: "assets/logo.svg", espresso: "icons/espresso.svg"
```

- A path is relative to [the root option](root-option.md) of the deck, or to the working
  directory of the command.
- A name of the deck wins over a Lucide name.
- The renderer keeps the `svg` element of the file. It removes the XML declaration, the
  doctype, the comments, and the `width`, the `height` and the `class` of the `svg`
  element.
- Each color of a `fill` or a `stroke`, in an attribute or in a `style`, becomes
  `currentColor`, so the icon takes the color of the `color` option or of the text. The
  values `none` and `currentColor` stay.
- Each copy of the icon in the document gets its own `id` values, and each `url(#id)` and
  `href="#id"` of the copy changes with them. A `clipPath`, a `mask` or a `filter` thus
  works in each view. A `<style>` element of the file applies only to its copy.
- Give the file a `viewBox`, so the icon keeps its shape at each size.
- The watch mode renders the deck again after a change to the file.

## The HTML

The element is a `figure` with the classes `icon` and `icon-<color>`, and the style
`--icon-size`. It holds an `svg` with the class `icon-svg` and `aria-hidden="true"`, and a
`figcaption` with the class `icon-label` for the label. Without a label, a screen reader
skips the icon.

An icon in a text is an `svg` with the class `icon-inline` and `aria-hidden="true"`. Write
the meaning of the icon in the text too, because a screen reader does not read the icon.

## The errors

The compiler gives an error for these:

- a name that no icon has, in the element or in a text;
- a file of the `icons` option that it cannot read, that is not UTF-8, or that has no `svg`
  element;
- a `color` that is not in the list.

## The license

The Lucide icons are under the ISC license, and the icons that come from Feather are under
the MIT license. `priv/icons/LICENSE` holds the two licenses.
