# The math element

The `math` element shows a formula in MathML. The browser draws the formula with no script
and no font file.

```elixir
slide "the formula" do
  math ~S"""
  <math display="block">
    <mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup>
  </math>
  """
end
```

`Expresso.Builder` takes the same argument, such as `math(~S"<math>...</math>")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | MathML, from `<math>` to `</math>` | The formula. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## MathML

The text goes into the document as it is. Each browser of the floor of this project
supports MathML Core. Give the `math` tag the attribute `display="block"` for a formula on
its own line.

Use the `~S` sigil for the text, so that Elixir does not change a `\` or a `#{`.

A tool such as Pandoc or Temml makes MathML from LaTeX. Put its output into the element.
