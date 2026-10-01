defmodule Expresso.Builder do
  @moduledoc """
  Makes a deck with functions, in place of the DSL

  Each entity of the DSL has a function with the same name, such as `slide`,
  `text_box` and `list`. `Expresso.Builder.Generator` makes the functions from
  `Expresso.Extension`, so they take the same options as the DSL and they give
  the same errors. A function takes the arguments of the entity, then a keyword
  list with the options and the children:

  ```elixir
  import Expresso.Builder

  deck(
    [
      slide("first",
        heading: "Hello",
        elements: [
          text_box(elements: [text_area(text: "A text area in a text box")]),
          list(reveal: true, elements: [item("One"), item("Two")])
        ]
      )
    ],
    name: "my deck"
  )
  ```

  `deck/2` runs the transformers and the verifiers of the DSL. Therefore an
  overlay, a `pause` and an `on` entity give the same steps as in the DSL. A
  script can return the deck, and `mix expresso` renders it.

  The functions are for a deck that a program makes at runtime. A deck of many
  slides is one example: the DSL compiles a module of 2000 slides in
  approximately 30 seconds, and these functions make the same deck in
  approximately 0.1 seconds. `docs/overlays.md` gives the reasons for this
  design.
  """

  use Expresso.Builder.Generator, extension: Expresso.Extension

  @doc """
  Make a deck from slides and the options of the deck

  The options are the options of the DSL, such as `name`, `duration` and
  `transition`. The function runs the transformers and the verifiers of the
  DSL. It writes each warning of a verifier to the standard error, and it
  raises an exception for an error.
  """
  @spec deck([Expresso.Slide.t()], keyword()) :: Expresso.Deck.t()
  def deck(slides, opts \\ []) do
    {state, warnings} = dsl_state(slides, opts)
    Enum.each(warnings, &IO.warn(&1, []))
    Expresso.from_dsl_state(state)
  end
end
