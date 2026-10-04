defmodule Expresso.ThemeOptionTest do
  use ExUnit.Case, async: true

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
    assert screen =~ "--dim-opacity: 0.85;"
    assert print =~ "--background: #ffffff;"
    assert print =~ "--text: #000000;"
  end

  test "a deck without the option gets the default theme" do
    deck = Builder.deck([Builder.slide("one")])

    assert deck.metadata.theme == :default
    assert head_theme(deck) =~ ":root { " <> Palette.declarations(Builtin.fetch!(:default))
  end

  test "each color of the highlight style sheet is a role of the theme" do
    roles = MapSet.new(Palette.roles(), fn {role, _slot} -> property(role) end)

    used =
      for [_all, name] <- Regex.scan(~r/var\((--[a-z-]+)\)/, Expresso.Highlight.stylesheet()),
          do: name

    assert used != []
    assert Enum.all?(used, &(&1 in roles)), inspect(Enum.uniq(used) -- MapSet.to_list(roles))
    refute Expresso.Highlight.stylesheet() =~ ~r/#[0-9a-fA-F]{3,6}\b/
  end

  test "the style sheet takes its colors from the roles, except the black screen and the shadow of the list of keys" do
    css = File.read!("assets/style.css")

    for role <- [:text, :background, :muted, :accent, :warning, :danger],
        do: assert(css =~ "var(#{property(role)})", "#{role}")

    assert css =~ "var(--dim-opacity)"

    assert Regex.scan(~r/#[0-9a-fA-F]{3,6}\b|rgba?\([^)]*\)/, css) == [
             ["#000"],
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
end
