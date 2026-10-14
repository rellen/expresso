defmodule Expresso.JsonTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  doctest Expresso.Json

  @moduletag :tmp_dir

  @script ~r/<script id="expresso-[a-z]+" type="application\/json">(.*?)<\/script>/s

  test "the JSON of each script element of a document escapes each <", %{tmp_dir: dir} do
    page = Path.join(dir, "page.html")
    File.write!(page, "<p>A page</p><script></script>")

    html =
      [Builder.slide("one", elements: [Builder.embed(page, title: "A page")])]
      |> Builder.deck()
      |> Expresso.Deck.render()

    scripts = Regex.scan(@script, html, capture: :all_but_first)

    assert length(scripts) == 3
    assert html =~ ~S(\u003cp>A page\u003c/p>\u003cscript>\u003c/script>)

    for [json] <- scripts, do: refute(json =~ "<")
  end
end
