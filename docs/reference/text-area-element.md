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

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The HTML

The document writes a `div` with the class `text-area`, and a second `div` that holds the
text. The text thus stays one block, and an inline element such as `<b>` does not break
the line. The theme makes `.text-area` a flex container.

The text goes into the document as it is, with no escape. Write only HTML that you trust,
such as the text of your own deck. Give text from a different source to
`Phoenix.HTML.html_escape/1` before the deck uses it.

## A link

With `goto`, the text goes into a link to a slide and a step of the deck. A click goes to
that step, and the key `Enter` does the same when the link has the focus. A link to a web
page is an `<a href>` tag in the text.
