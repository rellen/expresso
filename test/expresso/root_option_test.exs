defmodule Expresso.RootOptionTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  @moduletag :tmp_dir

  # A project of a talk: the deck file is in talk/, and its files are next to
  # it or in the directory above it.
  defp project(tmp_dir) do
    talk = Path.join(tmp_dir, "talk")
    File.mkdir_p!(Path.join(talk, "styles"))
    File.mkdir_p!(Path.join(tmp_dir, "lib"))

    File.write!(
      Path.join(tmp_dir, "lib/server.ex"),
      "defmodule Server do\n  def start, do: :ok\nend\n"
    )

    File.cp!("test/fixtures/dot.png", Path.join(talk, "dot.png"))
    File.cp!("test/fixtures/dot.png", Path.join(talk, "styles/mark.png"))
    File.cp!("test/fixtures/flow.svg", Path.join(talk, "flow.svg"))
    File.cp!("test/fixtures/page.html", Path.join(talk, "page.html"))
    File.write!(Path.join(talk, "styles/deck.css"), "h1 { background: url(mark.png); }")
    talk
  end

  defp data_uri(path), do: "data:image/png;base64," <> Base.encode64(File.read!(path))

  test "a deck file with root __DIR__ renders its files from another directory", %{
    tmp_dir: tmp_dir
  } do
    talk = project(tmp_dir)

    File.write!(Path.join(talk, "deck.exs"), """
    defmodule Expresso.RootOptionTest.Deck do
      use Expresso

      root __DIR__
      css "styles/deck.css"

      slide "one" do
        heading "Root"

        code "elixir" do
          src "../lib/server.ex"
          lines from: "def start"
        end

        image "dot.png" do
          alt "A dot"
        end
      end

      slide "two" do
        diagram "flow.svg"

        embed "page.html" do
          title "A page"
          fallback "dot.png"
        end
      end
    end
    """)

    assert {:ok, html} = Expresso.render_file(Path.join(talk, "deck.exs"))
    document = Floki.parse_document!(html)

    assert document |> Floki.find(".screen .code") |> Floki.text() =~ "def start, do: :ok"
    assert html =~ ~s|h1 { background: url("#{data_uri(Path.join(talk, "styles/mark.png"))}"); }|

    assert document |> Floki.find(".screen .image img") |> Floki.attribute("src") == [
             data_uri(Path.join(talk, "dot.png"))
           ]

    assert Floki.find(document, ".screen .diagram svg") != []
    assert html =~ ~s("kind":"srcdoc")
  end

  test "the builder takes root, and an absolute path and an address stay as they are", %{
    tmp_dir: tmp_dir
  } do
    talk = project(tmp_dir)
    absolute = Path.expand("test/fixtures/code.js")

    deck =
      Builder.deck(
        [
          Builder.slide("one",
            elements: [
              Builder.code("elixir", src: "../lib/server.ex"),
              Builder.code("js", src: absolute),
              Builder.embed("https://example.com/", title: "An address", fallback: "dot.png")
            ]
          )
        ],
        root: talk,
        css: "styles/deck.css"
      )

    [server, js, embed] = hd(deck.slides).elements

    assert server.src == Path.join(tmp_dir, "lib/server.ex")
    assert server.text =~ "defmodule Server"
    assert js.src == absolute
    assert embed.src == "https://example.com/"
    assert embed.fallback == Path.join(talk, "dot.png")
    assert deck.metadata.root == talk
    assert deck.metadata.css == Path.join(talk, "styles/deck.css")
  end

  test "a relative root starts from the working directory" do
    deck =
      Builder.deck([Builder.slide("one", elements: [Builder.code("js", src: "code.js")])],
        root: "test/fixtures"
      )

    assert deck.metadata.root == Path.expand("test/fixtures")
    assert hd(hd(deck.slides).elements).text =~ "function sum"
  end

  test "without root, a path stays relative to the working directory, and the metadata has no root" do
    deck =
      Builder.deck([
        Builder.slide("one", elements: [Builder.code("js", src: "test/fixtures/code.js")])
      ])

    assert hd(hd(deck.slides).elements).src == "test/fixtures/code.js"
    refute Map.has_key?(deck.metadata, :root)
  end

  test "the error of a missing file names the path from the root, and the watch mode records it",
       %{
         tmp_dir: tmp_dir
       } do
    missing = Path.join(tmp_dir, "missing.ex")

    assert_raise Spark.Error.DslError,
                 ~r/cannot read the code file "#{Regex.escape(missing)}"/,
                 fn ->
                   Builder.deck(
                     [Builder.slide("one", elements: [Builder.code(src: "missing.ex")])],
                     root: tmp_dir
                   )
                 end

    talk = project(tmp_dir)

    {_deck, paths} =
      Expresso.DeckFile.track(fn ->
        Builder.deck([Builder.slide("one", elements: [Builder.code(src: "../lib/server.ex")])],
          root: talk
        )
      end)

    assert paths == [Path.join(tmp_dir, "lib/server.ex")]
  end
end
