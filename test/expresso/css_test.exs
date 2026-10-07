defmodule Expresso.CssTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Spark.Test, only: [dsl_errors: 1, dsl_warnings: 1, refute_dsl_warnings: 1]

  alias Expresso.Builder
  alias Expresso.Css

  doctest Expresso.Css

  @moduletag :tmp_dir

  # The deck gives an effect with keyframes, an effect with the properties of
  # the theme, a state and a color for the heading.
  defmodule CssDeck do
    use Expresso

    name "css deck"

    css ~S"""
    @keyframes bounce { 60% { transform: scale(1.15); } }
    [data-effect="bounce"] { --enter-animation: bounce; }
    [data-effect="drop"] { --enter-y: -3rem; }
    .text-box { background: color-mix(in srgb, #ffe066 calc(var(--mark, 0) * 100%), transparent); }
    h1 { color: #c92a2a; }
    /* A comment that holds </style> */
    """

    slide "one" do
      text_box do
        at 2
        effect :bounce
        text_area(text: "Bounce")
      end

      text_box do
        at 2
        effect :drop
        on 2, state: :mark
        text_area(text: "Drop")
      end
    end
  end

  describe "resolve/1" do
    test "gives a style sheet as it is, and an empty one for nil" do
      assert Css.resolve("h1 { color: red; }") == {:ok, "h1 { color: red; }"}
      assert Css.resolve("h1\n") == {:ok, "h1\n"}
      assert Css.resolve(nil) == {:ok, ""}
    end

    test "reads a path", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "deck.css")
      File.write!(path, "h1 { color: red; }")

      assert Css.resolve(path) == {:ok, "h1 { color: red; }"}
    end

    test "gives an error for a file that it cannot read" do
      assert {:error, message} = Css.resolve("no/such/deck.css")
      assert message =~ ~s(cannot read the CSS file "no/such/deck.css")
    end
  end

  describe "the files of url()" do
    @png "data:image/png;base64," <> Base.encode64(File.read!("test/fixtures/dot.png"))

    test "embed/2 puts a local file into the style sheet, with or without quotes" do
      for value <- ["dot.png", ~s("dot.png"), "'dot.png'", " dot.png "] do
        assert Css.embed("a { background: url(#{value}); }", "test/fixtures") ==
                 {:ok, ~s|a { background: url("#{@png}"); }|},
               value
      end
    end

    test "embed/2 keeps an address, a data URI and a fragment, and keeps the fragment of a file" do
      for css <- [
            "a { background: url(https://example.com/a.png); }",
            "a { background: url(//example.com/a.png); }",
            ~s|a { background: url("data:image/png;base64,AA"); }|,
            "a { filter: url(#shadow); }"
          ] do
        assert Css.embed(css, "test/fixtures") == {:ok, css}
      end

      assert {:ok, css} = Css.embed("a { mask: url(flow.svg#arrow?v=1); }", "test/fixtures")
      assert css =~ ~r|url\("data:image/svg\+xml;base64,[^"]+#arrow\?v=1"\)|
    end

    test "embed/2 gives a font its media type, and an error for a missing file or an unknown type" do
      File.write!(Path.join(System.tmp_dir!(), "expresso-css-font.woff2"), "font")

      assert {:ok, "src: url(\"data:font/woff2;base64,Zm9udA==\");"} =
               Css.embed("src: url(expresso-css-font.woff2);", System.tmp_dir!())

      assert {:error, message} = Css.embed("a { background: url(none.png); }", "test/fixtures")
      assert message =~ ~s|cannot read the file "|
      assert message =~ ~s|none.png" of a url() of the CSS: enoent|

      assert {:error, message} = Css.embed("a { background: url(code.js); }", "test/fixtures")
      assert message =~ "is not a font or an image of a type that Expresso knows"
    end

    test "render/2 resolves the url() of a file from its directory, and of a style sheet from the root",
         %{tmp_dir: tmp_dir} do
      File.mkdir_p!(Path.join(tmp_dir, "styles"))
      File.cp!("test/fixtures/dot.png", Path.join(tmp_dir, "styles/dot.png"))
      File.cp!("test/fixtures/dot.png", Path.join(tmp_dir, "root.png"))
      file = Path.join(tmp_dir, "styles/deck.css")
      File.write!(file, "a { background: url(dot.png); }")

      assert Css.render(file, nil) == {:ok, ~s|a { background: url("#{@png}"); }|}

      assert Css.render("b { background: url(root.png); }", tmp_dir) ==
               {:ok, ~s|b { background: url("#{@png}"); }|}

      assert Css.render("b { background: url(test/fixtures/dot.png); }", nil) ==
               {:ok, ~s|b { background: url("#{@png}"); }|}
    end

    test "the document holds the file of a url() of the css option" do
      html =
        [Builder.slide("one")]
        |> Builder.deck(css: "h1 { background: url(test/fixtures/dot.png); }")
        |> Expresso.Deck.render()

      assert html =~ ~s|h1 { background: url("#{@png}"); }|
    end
  end

  describe "the properties" do
    defp name do
      map(
        list_of(string(?a..?z, min_length: 1, max_length: 5), min_length: 1, max_length: 3),
        &Enum.join(&1, "-")
      )
    end

    defp fragment,
      do: member_of(["<", "/", "\\", "</", "<\\/", "style>", "a { }", " ", "\n", "*"])

    defp text, do: map(list_of(fragment(), max_length: 12), &Enum.join/1)

    defp declaration do
      map(
        {name(),
         one_of([map(integer(0..9), &Integer.to_string/1), member_of(["2rem", "red", "300ms"])])},
        fn {name, value} ->
          {name, value}
        end
      )
    end

    defp number?(value), do: value =~ ~r/^\d+$/

    property "escape/1 leaves no </, and its result can be read back" do
      check all css <- text() do
        escaped = Css.escape(css)

        refute escaped =~ "</"
        assert String.replace(escaped, "<\\/", "</") == String.replace(css, "<\\/", "</")
      end
    end

    property "resolve/1 gives a style sheet with a brace or a line break as it is" do
      check all css <- text(), marker <- member_of(["{", "\n"]) do
        assert Css.resolve(css <> marker) == {:ok, css <> marker}
      end
    end

    property "scan/1 finds each effect, use, declaration and registration of a style sheet" do
      check all effects <- list_of(name(), max_length: 3),
                declarations <- list_of(declaration(), max_length: 4),
                reads <- list_of(name(), max_length: 3),
                registered <-
                  list_of({name(), member_of(["<length>", "<number>", "<color>"])}, max_length: 2) do
        css =
          Enum.map_join(effects, "\n", &~s([data-effect="#{&1}"] { opacity: 1; })) <>
            "\n.x { " <>
            Enum.map_join(declarations, " ", fn {name, value} -> "--#{name}: #{value};" end) <>
            " width: " <>
            Enum.map_join(reads, " ", &"var(--#{&1})") <>
            "; }\n" <>
            Enum.map_join(registered, "\n", fn {name, syntax} ->
              ~s(@property --#{name} { syntax: "#{syntax}"; inherits: false; })
            end)

        names = Css.scan(css)

        property_names =
          Enum.map(declarations, &elem(&1, 0)) ++ reads ++ Enum.map(registered, &elem(&1, 0))

        assert names.effects == MapSet.new(effects, &String.replace(&1, "-", "_"))
        assert names.used == MapSet.new(property_names)
        assert names.registered == Map.new(registered)

        assert names.declared ==
                 MapSet.new(for {name, value} <- declarations, not number?(value), do: name)
      end
    end
  end

  describe "the DSL" do
    test "accepts an effect and a state of the CSS of the deck" do
      assert %Expresso.Deck{metadata: %{css: css}} = Expresso.parse(CssDeck)
      assert css =~ "@keyframes bounce"

      refute_dsl_warnings do
        defmodule Elixir.Expresso.CssTest.StateDeck do
          use Expresso

          css ".x { opacity: var(--glow, 0); }"

          slide "one" do
            text_box do
              on 1, state: :glow
            end
          end
        end
      end
    end

    test "still warns for a state that neither the theme nor the CSS uses" do
      warnings =
        dsl_warnings do
          defmodule Elixir.Expresso.CssTest.UnusedDeck do
            use Expresso

            css ".x { color: red; }"

            slide "one" do
              text_box do
                on 1, state: :glow
              end
            end
          end
        end

      assert [{Expresso.CssTest.UnusedDeck, [{message, _location}]}] = warnings
      assert message =~ "neither the theme nor the CSS of the deck uses that property"
    end

    test "gives an error for a CSS file that it cannot read" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.CssTest.MissingDeck do
            use Expresso

            css "no/such/deck.css"
          end
        end

      assert [{Expresso.CssTest.MissingDeck, [error]}] = errors
      assert Exception.message(error) =~ ~s(cannot read the CSS file "no/such/deck.css")
    end

    test "gives an error for an effect without a rule in the element" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.CssTest.TypoDeck do
            use Expresso

            css ~S([data-effect="bounce"] { --enter-animation: bounce; })

            slide "one" do
              text_box do
                at 1
                effect :bounse
              end
            end
          end
        end

      assert [{Expresso.CssTest.TypoDeck, [error]}] = errors
      assert Exception.message(error) =~ "the effect :bounse has no rule"
    end
  end

  describe "the document" do
    defp styles(deck) do
      deck
      |> Expresso.Deck.render()
      |> Floki.parse_document!()
      |> Floki.find("head style")
      |> Enum.map(&Floki.text/1)
    end

    test "puts the CSS of the deck last, after the generated rules, and escapes it" do
      [_fonts, _theme, _highlight, generated, css] = styles(Expresso.parse(CssDeck))

      assert generated =~ "animation-name: var(--enter-animation)"
      assert css =~ ~s([data-effect="bounce"] { --enter-animation: bounce; })
      assert css =~ "<\\/style>"
      refute css =~ "</style>"
    end

    test "reads the CSS of a deck from the builder", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "deck.css")
      File.write!(path, "h2 { color: teal; }")

      deck = Expresso.Builder.deck([Expresso.Builder.slide("one")], css: path)

      assert [_, _, _, _, "h2 { color: teal; }"] = styles(deck)
    end

    test "writes no fifth style element without CSS" do
      deck = Expresso.Builder.deck([Expresso.Builder.slide("one")])

      assert length(styles(deck)) == 4
    end
  end
end
