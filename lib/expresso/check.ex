defmodule Expresso.Check do
  @moduledoc """
  Runs `mix expresso <input> --check`, and writes a report of the problems of the deck

  The check has four levels. Each level runs the checks of the level before
  it, and it needs one more tool:

  | Level | Option | Checks | Needs |
  | --- | --- | --- | --- |
  | `:basic` | `--check` | The render, the contrast of the theme, the size of the document, and the text for a screen reader | Nothing |
  | `:layout` | `--check=layout` | Each element in the window, and each line of code on one line, at each step at 1920 × 1080 | Chrome or Chromium |
  | `:a11y` | `--check=a11y` | The rules of axe-core at each step, and in the menu, the list of keys, the overview and the handout view | Chrome or Chromium, and axe-core |
  | `:browser` | `--check=browser` | The checks of `:a11y` in Playwright, and the keys of the presenter: each step, each view, the focus and the errors of the script | Node, the npm packages `playwright` and `axe-core`, and the Hex package `playwright_ex` |

  `Expresso.Check.Document` gives the checks with no tool, and
  `Expresso.Check.Browser` runs the checks in the browser.
  `Expresso.Check.Session` runs the browser level in Playwright. A problem makes the
  exit status 1. A note does not.
  """

  alias Expresso.Check.{Browser, Document, Session}

  @typedoc "A level of the check"
  @type level :: :basic | :layout | :a11y | :browser

  @doc """
  Check the deck of an input file, write the report, and return the exit status

  With `output`, the function also writes the HTML to that file. The report
  goes to the standard output, and an error goes to the standard error. The
  exit status is 1 for a problem or an error, and 0 otherwise.
  """
  @spec run(Path.t(), Path.t() | nil, level()) :: 0 | 1
  def run(input, output, level) do
    case check(input, output, level) do
      {:ok, report} ->
        IO.write(report.text)
        if report.problems == 0, do: 0, else: 1

      {:error, message} ->
        IO.puts(:stderr, message)
        1
    end
  end

  @doc """
  Check the deck of an input file, and return the text of the report and the number of problems

  The function writes the HTML to `output` when it is not `nil`. It writes
  nothing else.
  """
  @spec check(Path.t(), Path.t() | nil, level()) ::
          {:ok, %{text: String.t(), problems: non_neg_integer()}} | {:error, String.t()}
  def check(input, output, level) do
    with {:ok, tools} <- tools(level, input),
         {:ok, deck} <- Expresso.load_file(input),
         html = Expresso.Deck.render(deck),
         :ok <- write(html, output),
         {:ok, page} <- page(html, deck, tools) do
      checks = [Document.theme(deck), Document.size(html), Document.slides(html)]
      problems = named(Enum.flat_map(checks, & &1.problems) ++ page_problems(page), deck)
      notes = named(Enum.flat_map(checks, & &1.notes), deck)
      {:ok, %{text: text(input, deck, level, page, notes, problems), problems: length(problems)}}
    end
  end

  @doc """
  Put the name of the slide after its number, in each line that starts with a slide

  The reports of the checks name a slide by its number, and the deck names it
  by its name. A slide with no name keeps its number alone.

      iex> deck = Expresso.Builder.deck([Expresso.Builder.slide("resHit", elements: [])], name: "n")
      iex> Expresso.Check.named(["Slide 1, step 2: a problem", "Slide 1: a note", "The keys: j"], deck)
      ["Slide 1 “resHit”, step 2: a problem", "Slide 1 “resHit”: a note", "The keys: j"]
  """
  @spec named([String.t()], Expresso.Deck.t()) :: [String.t()]
  def named(lines, deck) do
    names =
      deck.slides
      |> Enum.with_index(1)
      |> Map.new(fn {slide, number} -> {Integer.to_string(number), slide.name} end)

    Enum.map(
      lines,
      &Regex.replace(~r/^Slide (\d+)(?=[,:])/, &1, fn all, number ->
        name(all, number, names[number])
      end)
    )
  end

  defp name(all, _number, nil), do: all
  defp name(_all, number, name), do: "Slide #{number} “#{name}”"

  # Find each tool of the level before the render, so a missing tool gives
  # its error at once.
  defp tools(:basic, _input), do: {:ok, nil}

  defp tools(:layout, _input) do
    with {:ok, browser} <- Browser.find(), do: {:ok, {browser, nil}}
  end

  defp tools(:a11y, input) do
    with {:ok, browser} <- Browser.find(),
         {:ok, axe} <- Browser.find_axe(directories(input)),
         do: {:ok, {browser, axe}}
  end

  defp tools(:browser, input) do
    with {:ok, tools} <- Session.find(directories(input)), do: {:ok, {:session, tools}}
  end

  # The directories where the check looks for the npm packages.
  defp directories("-"), do: [File.cwd!()]
  defp directories(input), do: [File.cwd!(), Path.dirname(input)]

  defp write(_html, nil), do: :ok

  # sobelow_skip ["Traversal"]
  defp write(html, output) do
    case File.write(output, html) do
      :ok -> :ok
      {:error, reason} -> {:error, "Couldn't write output file: #{:file.format_error(reason)}"}
    end
  end

  defp page(_html, _deck, nil), do: {:ok, nil}
  defp page(html, deck, {:session, tools}), do: Session.run(html, deck, tools)
  defp page(html, _deck, {browser, axe}), do: Browser.run(html, browser, axe)

  defp page_problems(nil), do: []

  defp page_problems(page) do
    accessibility =
      Enum.map(page.accessibility || [], fn finding ->
        "#{finding["where"]}: #{finding["rule"]}, #{finding["help"]}: " <>
          Enum.join(finding["targets"], ", ")
      end)

    page.layout ++ accessibility ++ Map.get(page, :session, [])
  end

  defp text(input, deck, level, page, notes, problems) do
    [
      "Check of #{input}: #{length(deck.slides)} #{plural(length(deck.slides), "slide")}\n",
      ran(level, page),
      section("Notes", notes),
      section("Problems", problems),
      "\n",
      summary(problems)
    ]
    |> IO.iodata_to_binary()
  end

  defp ran(:basic, _page),
    do: "Checks: the render, the theme and the text for a screen reader\n"

  defp ran(:layout, page),
    do:
      "Checks: the render, the theme, the text for a screen reader, and the layout at #{size(page)}\n"

  defp ran(:a11y, page),
    do:
      "Checks: the render, the theme, the text for a screen reader, the layout at #{size(page)}, " <>
        "and axe-core at each step and in each view\n"

  defp ran(:browser, page),
    do:
      "Checks: the render, the theme, the text for a screen reader, the layout at #{size(page)}, " <>
        "axe-core at each step and in each view, and the keys of the presenter in Playwright\n"

  defp size(page), do: "#{page.width} × #{page.height}"

  defp section(_title, []), do: []

  defp section(title, lines),
    do: ["\n", title, ":\n", Enum.map(lines, &["  - ", &1, "\n"])]

  defp summary([]), do: "No problems.\n"
  defp summary(problems), do: "#{length(problems)} #{plural(length(problems), "problem")}.\n"

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"
end
