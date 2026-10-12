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

  defp check(dir, source, level) do
    input = Path.join(dir, "deck.exs")
    # Each run defines its module with a new name, so the compiler gives no
    # warning for a module that it defines again.
    name = "Deck#{System.unique_integer([:positive])}"
    File.write!(input, String.replace(source, ~r/defmodule \w+/, "defmodule #{name}"))

    output =
      capture_io(fn ->
        send(self(), {:status, Expresso.Check.run(input, nil, level)})
      end)

    assert_received {:status, status}
    {status, output}
  end

  test "--check=layout finds a long line of code at its step", %{tmp_dir: dir} do
    {status, output} = check(dir, @deck, :layout)

    assert status == 1
    assert output =~ "the layout at 1920 × 1080\n"
    assert output =~ "  - Slide 2 “long”, step 2: 1 line breaks in the code “const a = 1;"
    refute output =~ "color-contrast"
  end

  test "--check=a11y finds the text with a low contrast, and each problem of the layout", %{
    tmp_dir: dir
  } do
    {status, output} = check(dir, @deck, :a11y)

    assert status == 1
    assert output =~ "and axe-core at each step and in each view\n"
    assert output =~ "  - Slide 2 “long”, step 2: 1 line breaks in the code “const a = 1;"

    assert output =~
             "  - Slide 3 “low”, step 1: color-contrast, Elements must meet minimum color contrast"

    assert output =~ "  - The overview: color-contrast"
    assert output =~ ".low"
  end

  test "--check=browser presses each key, and finds no problem in a good deck", %{tmp_dir: dir} do
    {status, output} = check(dir, @good, :browser)

    assert output =~ "and the keys of the presenter in Playwright\n"
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
    {:ok, result} = Expresso.Check.Session.run(html, deck, tools)

    assert result.layout == []
    assert result.accessibility == []

    assert "The keys: j at 1.1 shows 1.1, and not the next step 1.2" in result.session
    assert Enum.any?(result.session, &(&1 =~ ~r/^The script: .*boom/))
  end

  test "--check=a11y finds no problem in a good deck", %{tmp_dir: dir} do
    {status, output} = check(dir, @good, :a11y)

    assert {status, output} == {0, output}
    assert String.ends_with?(output, "\nNo problems.\n")
  end
end
