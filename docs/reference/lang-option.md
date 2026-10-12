# The lang option

The `lang` option gives the language of the text of a deck. A screen reader selects its
voice and its pronunciation from it, and a browser selects its hyphenation and its quotes.

```elixir
defmodule MyTalk.Deck do
  use Expresso

  lang "de"

  slide "start" do
    heading "Überwachung"
  end
end
```

## The value

| Value | Example | Effect |
| --- | --- | --- |
| A language tag | `"de"`, `"pt-BR"`, `"zh-Hant"` | The renderer writes it into the `lang` attribute of the `html` element. |

The default is `"en"`. `Expresso.Builder` takes the same option, such as
`deck(slides, lang: "de")`.

A language tag has a language of two or three letters, then subtags of letters and digits,
each after a hyphen. The compiler gives an error for another value, such as `"en_US"`.

## Rules

- One language applies to the whole deck. The texts of the presenter, such as the list of
  keys and the names of the slides for a screen reader, stay in English.
- A part of a text in a different language can have its own `lang` attribute in the HTML
  of a text area, such as `<span lang="fr">déjà vu</span>`.
