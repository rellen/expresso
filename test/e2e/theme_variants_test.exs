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
