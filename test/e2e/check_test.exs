defmodule Expresso.E2E.CheckTest do
  # The check starts its own headless browser, so the module does not use the
  # Playwright of `Expresso.E2E`. The tag puts it with the browser tests.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :e2e
  @moduletag :tmp_dir
  @moduletag timeout: 300_000

  # The CI job installs the headless shell of Playwright, and the runner can
  # have a different browser on the PATH. Without EXPRESSO_CHROMIUM, the tests
  # use that headless shell, as the other browser tests do.
  setup_all do
    shell = Expresso.Check.Browser.playwright()

    if System.get_env("EXPRESSO_CHROMIUM") == nil and shell != nil do
      System.put_env("EXPRESSO_CHROMIUM", shell)
      on_exit(fn -> System.delete_env("EXPRESSO_CHROMIUM") end)
    end

    :ok
  end

  # Slide 2 holds a line of code that is too long for its box, at step 2.
  # Slide 3 holds text with a low contrast, from the `css` option. The text of
  # the deck holds `</script>`, so the result of the page must escape it.
  @deck """
  defmodule CheckDeck do
    use Expresso

    name "check deck"

    css ".low { color: #777777; background: #888888; }"

    slide "good" do
      heading "A good slide </script>"
      text_area(text: "This slide has no problem.")
    end

    slide "long" do
      heading "Long"

      code "js" do
        reveal [1, 2]
        text "const a = 1;\\nconst b = [#{Enum.join(1..120, ", ")}];\\n"
      end
    end

    slide "low" do
      heading "Low"
      text_area(text: "Grey on grey", class: "low")
    end
  end
  """

  # A deck with no problem.
  @good """
  defmodule GoodCheckDeck do
    use Expresso

    name "good check deck"
    dim_contrast 4.5

    slide "start" do
      heading "The start"

      list do
        reveal true
        item "One"
        item "Two"
      end
    end
  end
  """

  defp check(dir, source, level, sizes \\ []) do
    input = Path.join(dir, "deck.exs")
    # Each run defines its module with a new name, so the compiler gives no
    # warning for a module that it defines again.
    name = "Deck#{System.unique_integer([:positive])}"
    File.write!(input, String.replace(source, ~r/defmodule \w+/, "defmodule #{name}"))

    output =
      capture_io(fn ->
        send(self(), {:status, Expresso.Check.run(input, nil, level, sizes)})
      end)

    assert_received {:status, status}
    {status, output}
  end

  test "--check=layout finds a long line of code at its step", %{tmp_dir: dir} do
    {status, output} = check(dir, @deck, :layout)

    assert status == 1

    assert output =~
             "the layout at 1920 × 1080\nBrowser: #{System.get_env("EXPRESSO_CHROMIUM")}\n"

    assert output =~ "  - Slide 2 “long”, step 2: 1 line breaks in the code “const a = 1;"
    refute output =~ "color-contrast"
  end

  test "--check=a11y names the text with a low contrast one time, and each problem of the layout",
       %{
         tmp_dir: dir
       } do
    {status, output} = check(dir, @deck, :a11y)

    assert status == 1
    assert output =~ "and axe-core at each step and in each view\n"
    assert output =~ "  - Slide 2 “long”, step 2: 1 line breaks in the code “const a = 1;"

    assert output =~
             ~r/  - Slide 3 “low”, step 1: color-contrast, Elements must meet minimum color contrast .*: the text area “Grey on grey”\n/

    # The overview and the handout view hold a copy of the text, and a step
    # already gives it.
    refute output =~ "The overview: color-contrast"
    refute output =~ "The handout view: color-contrast"
    refute output =~ ".low"
  end

  test "--check=browser presses each key, and finds no problem in a good deck", %{tmp_dir: dir} do
    {status, output} = check(dir, @good, :browser)

    assert output =~ "and the keys of the presenter in Playwright\nBrowser: "
    assert {status, output} == {0, output}
    assert String.ends_with?(output, "\nNo problems.\n")
  end

  test "--check=browser finds a key that does not move, and an error of the script" do
    {:ok, deck} =
      Expresso.to_deck(
        Expresso.Builder.deck(
          [
            Expresso.Builder.slide("one",
              heading: "One",
              elements: [
                Expresso.Builder.text_area(text: "a"),
                Expresso.Builder.text_area(text: "b", at: 2)
              ]
            )
          ],
          name: "broken keys",
          dim_contrast: 4.5
        )
      )

    # A script that takes the key `j` before the presenter, and an error.
    script = """
    <script>
    addEventListener("keydown", (event) => {
      if (event.key === "j") event.stopImmediatePropagation();
    }, true);
    setTimeout(() => { throw new Error("boom"); }, 0);
    </script>
    """

    html = String.replace(Expresso.Deck.render(deck), "</head>", script <> "</head>")
    {:ok, tools} = Expresso.Check.Session.find([File.cwd!()])
    {:ok, [{{{1920, 1080}, nil}, result}]} = Expresso.Check.Session.run(html, deck, tools)

    assert result.layout == []
    assert result.accessibility == []

    assert "The keys: j at 1.1 shows 1.1, and not the next step 1.2" in result.session
    assert Enum.any?(result.session, &(&1 =~ ~r/^The script: .*boom/))
  end

  # A deck with two variants. The text has a low contrast in the dark variant
  # only.
  @variants """
  defmodule VariantsCheckDeck do
    use Expresso

    name "variants check deck"
    theme light: :default, dark: :dracula
    dim_contrast 4.5
    css ":root[data-scheme=dark] .quiet { color: #777777; background: #888888; }"

    slide "start" do
      heading "Two variants"
      text_area(text: "Grey on grey in the dark", class: "quiet")
    end
  end
  """

  test "--check=a11y checks each variant, and names the variant of a problem", %{tmp_dir: dir} do
    {status, output} = check(dir, @variants, :a11y)

    assert status == 1
    assert output =~ "in the light and the dark variants\n"

    assert output =~
             "  - Slide 1 “start”, step 1 (dark): color-contrast, Elements must meet minimum color contrast"

    refute output =~ "(light)"
  end

  test "--check=browser checks each variant, and presses the keys one time", %{tmp_dir: dir} do
    {status, output} = check(dir, @variants, :browser)

    assert status == 1
    assert output =~ "in the light and the dark variants\n"
    assert output =~ "  - Slide 1 “start”, step 1 (dark): color-contrast"
    refute output =~ "The keys"
    refute output =~ "(light)"
  end

  # A box of 1500 px fits the slide of a page of 16:9, and it goes past an edge
  # of the slide of a page of 4:3. The width is in pixels, so the fonts of the
  # browser do not change the result.
  @wide """
  defmodule WideCheckDeck do
    use Expresso

    name "wide check deck"
    css ".wide { width: 1500px; max-width: none; flex: none; } .wide img { width: 100%; height: 100px; }"

    slide "wide" do
      heading "Wide"

      image "#{Path.expand("test/fixtures/dot.png")}" do
        alt "A wide image"
        class "wide"
      end
    end
  end
  """

  test "--check=layout checks each size of --size, and names the size of a problem", %{
    tmp_dir: dir
  } do
    {status, output} = check(dir, @wide, :layout, [{1920, 1080}, {1024, 768}])

    assert status == 1
    assert output =~ "the layout at 1920 × 1080 and 1024 × 768\n"

    assert output =~
             ~r/  - Slide 1 “wide”, step 1 \(1024 × 768\): the image .* past the (left|right) edge/

    refute output =~ "(1920 × 1080)"

    assert {0, small} = check(dir, @wide, :layout, [{1920, 1080}])
    assert small =~ "the layout at 1920 × 1080\n"
  end

  test "--check=browser checks each size in Playwright", %{tmp_dir: dir} do
    {status, output} = check(dir, @wide, :browser, [{1920, 1080}, {1024, 768}])

    assert status == 1
    assert output =~ "the layout at 1920 × 1080 and 1024 × 768, axe-core"
    assert output =~ ~r/  - Slide 1 “wide”, step 1 \(1024 × 768\): the image/
    refute output =~ "The keys"
  end

  test "--check=a11y finds no problem in a good deck", %{tmp_dir: dir} do
    {status, output} = check(dir, @good, :a11y)

    assert {status, output} == {0, output}
    assert String.ends_with?(output, "\nNo problems.\n")
  end
end
