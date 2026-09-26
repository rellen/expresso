defmodule Expresso.CssTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1, dsl_warnings: 1, refute_dsl_warnings: 1]

  alias Expresso.Css

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

  test "escape/1 writes <\\/ for </, so the style sheet cannot close its element" do
    assert Css.escape("a { } /* </style> */") == "a { } /* <\\/style> */"
  end

  test "scan/1 gives the names of a style sheet" do
    names =
      Css.scan("""
      @property --size { syntax: "<length>"; inherits: false; initial-value: 0px; }
      [data-effect="fly-far"] { --size: 2rem; --count: 3; }
      .x { width: var(--size); }
      """)

    assert names.used == MapSet.new(["size", "count"])
    assert names.declared == MapSet.new(["size"])
    assert names.registered == %{"size" => "<length>"}
    assert names.effects == MapSet.new(["fly_far"])
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

    test "reads the CSS of a deck from the imperative API", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "deck.css")
      File.write!(path, "h2 { color: teal; }")

      deck = "deck" |> Expresso.Deck.new(%{css: path}) |> Expresso.Deck.add_slide("one", %{}, [])

      assert [_, _, _, _, "h2 { color: teal; }"] = styles(deck)
    end

    test "writes no fifth style element without CSS" do
      deck = "deck" |> Expresso.Deck.new() |> Expresso.Deck.add_slide("one", %{}, [])

      assert length(styles(deck)) == 4
    end
  end
end
