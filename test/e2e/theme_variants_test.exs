defmodule Expresso.E2E.ThemeVariantsTest do
  use Expresso.E2E, async: false

  alias Expresso.Builder
  alias Expresso.Palette.Builtin
  alias PlaywrightEx.{Browser, BrowserContext}

  defp deck(theme) do
    Builder.deck([Builder.slide("one", heading: "Variants")], theme: theme)
  end

  # A page in a window that asks for a dark or a light scheme.
  defp page(browser, scheme) do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        color_scheme: scheme
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
    page
  end

  defp background(page),
    do: page |> js(~s|getComputedStyle(document.documentElement).backgroundColor|) |> rgb()

  defp background_of(name), do: Builtin.fetch!(name).roles.background |> hex()

  defp hex("#" <> hex) do
    [r, g, b] = for <<pair::binary-2 <- hex>>, do: String.to_integer(pair, 16)
    "rgb(#{r}, #{g}, #{b})"
  end

  test "a dark screen gets the dark variant, the key t changes the variant, and paper gets the default theme",
       %{
         browser: browser,
         tmp_dir: tmp_dir
       } do
    page = browser |> page(:dark) |> open(render(deck(dark: :dracula, light: :default), tmp_dir))

    assert background(page) == background_of(:dracula)

    press(page, "t")
    assert background(page) == background_of(:default)
    assert js(page, "document.documentElement.dataset.scheme") == "light"

    press(page, "t")
    assert background(page) == background_of(:dracula)

    emulate(page, "print")
    assert background(page) == background_of(:default)
  end

  test "a light screen gets the light variant", %{browser: browser, tmp_dir: tmp_dir} do
    page =
      browser |> page(:light) |> open(render(deck(dark: :dracula, light: :default), tmp_dir))

    assert background(page) == background_of(:default)

    press(page, "t")
    assert background(page) == background_of(:dracula)
  end

  test "the address chooses the variant at the load", %{browser: browser, tmp_dir: tmp_dir} do
    html = render(deck(dark: :dracula, light: :default), tmp_dir)
    page = browser |> page(:light) |> open(html <> "?scheme=dark")

    assert background(page) == background_of(:dracula)

    press(page, "t")
    assert background(page) == background_of(:default)
  end

  test "the key t in either window changes the variant of the two windows", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    slides = [Builder.slide("one", heading: "One"), Builder.slide("two", heading: "Two")]
    two = Builder.deck(slides, theme: [dark: :dracula, light: :default])
    audience = open(page, render(two, tmp_dir))
    dark = "document.documentElement.dataset.scheme === 'dark'"
    light = "document.documentElement.dataset.scheme === 'light'"

    # The speaker view opens in the variant of the present view.
    press(audience, "t")
    speaker = popup(context, fn -> press(audience, "s") end)
    assert js(speaker, "location.search") =~ "scheme=dark"
    wait_for(speaker, dark)
    assert background(speaker) == background_of(:dracula)

    press(speaker, "t")
    wait_for(audience, light)
    assert background(audience) == background_of(:default)

    press(audience, "t")
    wait_for(speaker, dark)

    # A move sends the variant again, and the two windows keep it.
    press(speaker, "j")
    wait_for(audience, "location.hash.startsWith('#2')")
    assert js(audience, dark)
    assert js(speaker, dark)
  end

  test "the key t changes nothing in a deck with one variant", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page = browser |> page(:dark) |> open(render(deck(:dracula), tmp_dir))

    press(page, "t")
    assert background(page) == background_of(:dracula)
    assert js(page, "document.documentElement.dataset.scheme") == nil
  end
end
