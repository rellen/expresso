# The stat element

The `stat` element is a big number with a label, such as "1,250 orders". It can count up to
its value when it shows.

```elixir
slide "results" do
  stat 1250 do
    label "orders this year"
    count true
  end
end
```

`Expresso.Builder` takes the same options, such as
`stat(4.2, prefix: "$", suffix: "M", label: "revenue")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A number, required | The value, such as `1250` or `98.6`. |
| `label` | A string | The text under the number. Without it, the stat has no label. |
| `prefix` | A string | The text before the number, such as `"$"`. |
| `suffix` | A string | The text after the number, such as `"%"` or `"k"`. |
| `decimals` | A non-negative integer | The number of digits after the point. The default is the decimals of the value: 0 for `1250`, and 1 for `98.6`. |
| `group` | `true` or `false` | Put a comma between each group of three digits, such as `1,250`. The default is `true`. |
| `count` | `true` or `false` | Count from `from` to the value when the stat shows. The default is `false`, and the number shows at once. |
| `from` | A number | The number at the start of the count. The default is `0`. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

A slide, a text box, a column and a callout can hold a stat. Put stats in the columns of a
`columns` element to show them in a row.

## The count

With `count true`, the number counts from `from` to the value:

- A stat without `at` counts when its slide shows.
- A stat with `at` counts at the first step at which it shows.
- The count lasts three times the time of the animations of the element, which the `speed`
  option of the deck, the slide or the stat gives.
- The number keeps its decimals and its commas during the count.
- A reader who asks for reduced motion, the handout view and paper see the value at once.

![Two stats count when the slide shows, and a third stat counts at step 2](https://raw.githubusercontent.com/rellen/expresso/media/stat.gif)

## The look

The number has the accent color and a bold weight, and the label has the muted color. Each
dims with the state `dim`. The number is 3em high, and at most a quarter of the width of
its box, so three stats fit in a row. A deck can set `--stat-size` in the `css` option to
change the size, such as `.stat { --stat-size: 4em; }`.

## The HTML

The renderer writes a `figure` with the class `stat`. It holds a `p` with the class
`stat-value` and a `figcaption` with the class `stat-label`. The `p` holds:

- a `span` with `aria-hidden="true"`, with the prefix, the number and the suffix, each in
  a `span` with the class `stat-prefix`, `stat-number` and `stat-suffix`;
- a `span` with the class `stat-text` that holds the whole value, such as `$4.2M`. The
  style sheet hides it from the eye, so a screen reader reads the value and never a number
  in the middle of the count.

With `count`, the number also has the class `stat-count`.

## The errors

The compiler gives an error for these:

- a value that is not a number, such as `"1,250"`;
- a `decimals` value that is not a non-negative integer.
