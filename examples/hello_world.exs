Mix.install([:expresso])

Expresso.Deck.new("hello_world")
|> Expresso.Deck.add_slide("slide1", %{heading: "Hello"}, [
  Expresso.Element.TextBox.new("<b>World!!!</b>")
])
|> Expresso.Deck.add_slide("slide2", %{heading: "Foo"}, [
  Expresso.Element.TextBox.new("<b>Bar</b>")
])
