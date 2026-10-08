defmodule Expresso.ThemeOptionTest do
  # `capture_io(:stderr)` replaces the standard error of each process. A test
  # that runs at the same time can then write its warning into a capture of
  # this module, and some tests here make sure that a warning does not occur.
  # Therefore this module runs alone, after the async modules.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Expresso.Builder
  alias Expresso.Palette
  alias Expresso.Palette.Builtin

  defp head_theme(deck) do
    [_fonts, theme | _rest] =
      deck |> Expresso.Deck.render() |> Floki.parse_document!() |> Floki.find("head style")

    Floki.text(theme)
  end

  defp property(role), do: "--" <> (role |> Atom.to_string() |> String.replace("_", "-"))

  test "the document writes the roles of the theme on :root, and the default theme for paper" do
    text = head_theme(Builder.deck([Builder.slide("one")], theme: :dracula))
    [screen, print] = String.split(text, "@media print", parts: 2)

    assert screen =~ "--background: #282a36;"
    assert screen =~ "--dim-opacity: 0.65;"
    assert print =~ "--background: #ffffff;"
    assert print =~ "--text: #000000;"
  end

  test "a deck without the option gets the default theme" do
    deck = Builder.deck([Builder.slide("one")])

    assert deck.metadata.theme == :default
    assert head_theme(deck) =~ ":root { " <> Palette.declarations(Builtin.fetch!(:default))
  end

  test "each color of the highlight style sheet is a role of the theme or its dimmed color" do
    roles =
      for {role, _slot} <- Palette.roles(),
          name <- [property(role), property(role) <> "-dim"],
          into: MapSet.new(["--dimmed"]),
          do: name

    used =
      for [_all, name] <- Regex.scan(~r/var\((--[a-z-]+)\)/, Expresso.Highlight.stylesheet()),
          do: name

    assert used != []
    assert Enum.all?(used, &(&1 in roles)), inspect(Enum.uniq(used) -- MapSet.to_list(roles))
    refute Expresso.Highlight.stylesheet() =~ ~r/#[0-9a-fA-F]{3,6}\b/
  end

  test "the style sheet takes its colors from the roles, except the black screen and the shadows of the menu and the list of keys" do
    css = File.read!("assets/style.css")

    for role <- [:text, :background, :muted, :accent, :warning, :danger],
        do: assert(css =~ "var(#{property(role)})", "#{role}")

    for role <- [:text, :muted, :accent, :code_comment],
        do: assert(css =~ "var(#{property(role)}-dim)", "#{role}")

    assert css =~ "var(--dimmed)"
    assert css =~ "var(--dim-opacity)"

    assert Regex.scan(~r/#[0-9a-fA-F]{3,6}\b|rgba?\([^)]*\)/, css) == [
             ["#000"],
             ["rgba(0, 0, 0, 0.4)"],
             ["rgba(0, 0, 0, 0.4)"]
           ]
  end

  test "a built-in theme compiles with no warning" do
    output =
      capture_io(:stderr, fn ->
        Code.compile_quoted(
          quote do
            defmodule Expresso.ThemeOptionTest.Dracula do
              use Expresso

              theme(:dracula)

              slide "one" do
              end
            end
          end
        )
      end)

    refute output =~ "contrast"
  end

  test "a theme of 16 colors under a minimum compiles with a warning for each role" do
    colors = Map.merge(Builtin.fetch!(:default).colors, %{base03: "#dddddd"})

    output =
      capture_io(:stderr, fn ->
        Code.compile_quoted(
          quote do
            defmodule Expresso.ThemeOptionTest.Pale do
              use Expresso

              theme(unquote(Macro.escape(colors)))

              slide "one" do
              end
            end
          end
        )
      end)

    assert output =~ "the theme gives code_comment a contrast of"
    assert output =~ "and WCAG asks for 4.5:1"
    assert output =~ "the theme gives code_comment a lightness contrast of Lc"
    assert output =~ "and APCA asks for Lc 60"

    %{base03: color} = colors |> Expresso.Palette.of() |> Expresso.Palette.suggestions()
    assert output =~ "The color #{color} for base03 passes"
    assert output =~ "the theme gives dimmed_text a contrast of"
    assert output =~ "It passes when each role of text passes"

    [example] =
      Regex.run(~r/```text\n(.*)\n```/, File.read!("docs/reference/theme-option.md"),
        capture: :all_but_first
      )

    assert output =~ example <> "\n"
  end

  test "a theme with no color that passes for a slot says so" do
    colors = Map.merge(Builtin.fetch!(:default).colors, %{base00: "#808080", base01: "#808080"})

    output = capture_io(:stderr, fn -> Builder.deck([Builder.slide("one")], theme: colors) end)

    assert output =~ "the theme gives text a lightness contrast of Lc"
    assert output =~ "No lightness of the color of base05 passes"
  end

  test "a name that is not a built-in theme stops the compile" do
    assert_raise Spark.Error.DslError, ~r/is not a built-in theme/, fn ->
      Code.compile_quoted(
        quote do
          defmodule Expresso.ThemeOptionTest.Plaid do
            use Expresso

            theme(:plaid)

            slide "one" do
            end
          end
        end
      )
    end
  end

  test "the builder takes the option and gives the same warning" do
    colors = Map.merge(Builtin.fetch!(:default).colors, %{base05: "#cccccc"})

    output = capture_io(:stderr, fn -> Builder.deck([Builder.slide("one")], theme: colors) end)

    assert output =~ "the theme gives text a contrast of"
  end

  describe "the keyword form" do
    @pale Map.merge(Builtin.fetch!(:default).colors, %{base03: "#dddddd"})

    defp warnings(theme) do
      capture_io(:stderr, fn -> Builder.deck([Builder.slide("one")], theme: theme) end)
    end

    test "adjust true gives a map no warning, and the roles that pass" do
      assert warnings(colors: @pale) =~ "the theme gives code_comment a contrast of"
      assert warnings(colors: @pale, adjust: true) == ""

      deck = Builder.deck([Builder.slide("one")], theme: [colors: @pale, adjust: true])
      html = Expresso.Deck.render(deck)

      refute html =~ "--code-comment: #dddddd;"
    end

    test "a warning names the variant of a map, and a built-in variant gets no check" do
      output = warnings(dark: :dracula, light: @pale)

      assert output =~ "the light theme gives code_comment a contrast of"
      refute output =~ "the dark theme"
    end

    test "an adjustment of more than 0.4 gives a warning" do
      gray = Map.merge(Builtin.fetch!(:default).colors, %{base05: "#ffffff", base03: "#ffffff"})

      assert warnings(colors: gray, adjust: true) =~
               ~r/the adjustment changes a color of the theme by 0\.\d+ in lightness, more than 0.4/
    end

    test "two variants give the light roles, the dark roles of a dark screen, the rules of the key t, and paper" do
      deck = Builder.deck([Builder.slide("one")], theme: [dark: :dracula, light: :default])
      html = Expresso.Deck.render(deck)
      dracula = Expresso.Palette.declarations(Builtin.fetch!(:dracula))
      default = Expresso.Palette.declarations(Builtin.fetch!(:default))

      assert html =~ ":root { #{default} }"
      assert html =~ "@media (prefers-color-scheme: dark) { :root { #{dracula} } }"
      assert html =~ ~s(:root[data-scheme="light"] { #{default} })
      assert html =~ ~s(:root[data-scheme="dark"] { #{dracula} })
      assert html =~ "@media print { :root, :root[data-scheme] { #{default} } }"
      assert html =~ ~s(<html lang="en" data-variants="data-variants">)
    end

    test "one variant writes no rule of a scheme and no data-variants" do
      html = [Builder.slide("one")] |> Builder.deck(theme: :dracula) |> Expresso.Deck.render()

      refute html =~ "@media (prefers-color-scheme: dark)"
      assert html =~ ~s(<html lang="en"><head>)
    end

    test "the DSL takes the keyword form" do
      [{module, _bytecode}] =
        Code.compile_string("""
        defmodule Expresso.ThemeOptionTest.Variants do
          use Expresso

          theme dark: :dracula, light: :solarized_light

          slide "one" do
          end
        end
        """)

      assert Expresso.parse(module).metadata.theme == [dark: :dracula, light: :solarized_light]
    end
  end
end
