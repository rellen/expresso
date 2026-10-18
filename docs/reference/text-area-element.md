# The text area element

The `text_area` element shows text. The text can contain HTML, such as `<b>`, `<em>` or a
link.

```elixir
slide "the answer" do
  text_box do
    text_area do
      text "The answer is <b>42</b>."
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`text_area(text: "The answer is <b>42</b>.")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| `text` | A string | The text. The document holds it as HTML, so `<`, `>` and `&` need an entity, such as `&lt;`, to show as characters. |
| `goto` | A slide and a step, such as `[slide: 5]` or `[slide: "summary"]` | Makes the element a link to that slide and step. See [the goto option](goto-option.md). |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The HTML

The document writes a `div` with the class `text-area`, and a second `div` that holds the
text. The text thus stays one block, and an inline element such as `<b>` does not break
the line. The theme makes `.text-area` a flex container.

The text goes into the document as it is, with no escape. Write only HTML that you trust,
such as the text of your own deck. Give text from a different source to
`Phoenix.HTML.html_escape/1` before the deck uses it.

The presenter runs the commands of a click from three kinds of element:

- a link with the class `goto` and the attribute `data-link`, which holds the number of a
  link of the `goto` option;
- an element with the class `handout-page` and the attribute `data-commands`;
- an element with the class `menu-slide` or `menu-step` and the attribute
  `data-commands`, in the element with the id `menu`.

These names are reserved. Do not use them in the text, because a click on such an element
runs commands. A link with the class `goto` runs only the commands that the compiler wrote
for a link of the deck, and it ignores an attribute `data-commands`. A command that the
presenter does not know stops the click with an error.

## A link

With `goto`, the text goes into a link to a slide and a step of the deck. A click goes to
that step, and the key `Enter` does the same when the link has the focus. A link to a web
page is an `<a href>` tag in the text.
