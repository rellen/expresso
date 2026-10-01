# The class option

The `class` option gives CSS class names to a slide or to an element. A rule of
[the css option](css-option.md) can then select that slide or that element only.

```elixir
defmodule MyDeck do
  use Expresso

  css ~S"""
  .dense .code pre {
    font-size: 0.4rem;
  }
  .note {
    font-style: italic;
  }
  """

  slide "the server" do
    class "dense"

    code "elixir" do
      src "lib/my_app/server.ex"
    end

    text_area(text: "A text in italics", class: "note")
  end
end
```

`Expresso.Builder` takes the same option, such as `slide("one", class: "dense")` and
`text_area(text: "a", class: "note")`.

## Where you write it

| Place | The element that gets the classes |
| --- | --- |
| A slide | The `section` of the slide in the present view, and the `section` of each page of the slide in the handout view. |
| `text_box`, `text_area`, `image`, `list`, `item`, `table`, `row`, `quotation`, `spacer`, `code`, `math`, `diagram`, `embed`, `columns` and `column` | The root element of the element, such as the `div` of a code element or the `tr` of a row. |

A `part` of a diagram, an `on` entity and `pause` do not take the option.

## The value

The value is one class name or more, with a space between two names, such as `"dense"`
or `"dense wide"`. A name starts with a letter, an underscore, or a hyphen and a letter.
The other characters are letters, digits, underscores and hyphens.

The compiler gives an error for a value that is not such a list of names.
`Expresso.Builder` raises a `Spark.Error.DslError` with the same message.

## The classes of the theme

The element keeps the class of the theme, and the classes of the option come after it.
A code element with `class "tiny"` thus has the classes `code tiny`. The rules of the theme
still apply, and a rule of the deck can select `.code.tiny`.

Use names that the theme does not use, such as `dense` or `note`. A name of the theme,
such as `code` or `slide`, gives the element the rules of that part of the theme.

## A rule for a slide

A rule that starts with the class of a slide selects the elements of that slide only,
such as `.dense .code pre`. The rule applies in the present view, in the handout view and
on paper, because each page of the slide has the class.
