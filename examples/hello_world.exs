# This example shows a deck outside a Mix project. Run it with `elixir`, and do not
# run it with `mix expresso`, because Mix.install/2 gives an error inside a Mix
# project. The example needs the expresso package on Hex, which does not have a
# release at this time. Use examples/demo.exs or examples/dsl_deck.exs instead.
Mix.install([:expresso])

Expresso.Deck.new("hello_world")
|> Expresso.Deck.add_slide("slide1", %{heading: "Hello"}, [
  Expresso.Element.TextBox.new("<b>World!!!</b>")
])
|> Expresso.Deck.add_slide("slide2", %{heading: "Foo"}, [
  Expresso.Element.TextBox.new("<b>Bar</b>")
])
