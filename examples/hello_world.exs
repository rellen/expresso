Expresso.Deck.new("hello_world")
|> Expresso.Deck.add_slide("slide1", %{}, heading: "Hello", text: "<b>World!!!</b>")
|> Expresso.Deck.add_slide("slide2", %{}, heading: "Foo", text: "<b>Bar</b>")
|> Expresso.Deck.render()
