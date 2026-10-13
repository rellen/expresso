defmodule Expresso.Check do
  @moduledoc """
  Runs `mix expresso <input> --check`, and writes a report of the problems of the deck

  The check has four levels. Each level runs the checks of the level before
  it, and it needs one more tool:

  | Level | Option | Checks | Needs |
  | --- | --- | --- | --- |
  | `:basic` | `--check` | The render, the contrast of the theme, the size of the document, and the text for a screen reader | Nothing |
  | `:layout` | `--check=layout` | Each element in the window, and each line of code on one line, at each step at 1920 × 1080, or at each size of `--size` | Chrome or Chromium |
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

  @typedoc "A size of the page in pixels, such as `{1280, 720}`"
  @type size :: {pos_integer(), pos_integer()}

  # The size of the page without the option `--size`.
  @default_size {1920, 1080}

  @doc """
  Check the deck of an input file, write the report, and return the exit status

  With `output`, the function also writes the HTML to that file. The report
  goes to the standard output, and an error goes to the standard error. The
  exit status is 1 for a problem or an error, and 0 otherwise. `sizes` gives
  the sizes of the page for a browser level, and `[]` gives 1920 × 1080.
  """
  @spec run(Path.t(), Path.t() | nil, level(), [size()]) :: 0 | 1
  def run(input, output, level, sizes \\ []) do
    case check(input, output, level, sizes) do
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
  @spec check(Path.t(), Path.t() | nil, level(), [size()]) ::
          {:ok, %{text: String.t(), problems: non_neg_integer()}} | {:error, String.t()}
  def check(input, output, level, sizes \\ []) do
    sizes = if sizes == [], do: [@default_size], else: Enum.uniq(sizes)

    with {:ok, tools} <- tools(level, input),
         {:ok, deck} <- Expresso.load_file(input),
         html = Expresso.Deck.render(deck),
         :ok <- write(html, output),
         {:ok, page} <- page(html, deck, tools, sizes) do
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

  # Run the checks of the page one time for each size and each variant of
  # the theme. The result is a list of `{{size, scheme}, result}`, with `nil`
  # as the scheme of a theme with one variant.
  defp page(_html, _deck, nil, _sizes), do: {:ok, nil}

  defp page(html, deck, {:session, tools}, sizes),
    do: Session.run(html, deck, tools, schemes: schemes(deck), sizes: sizes)

  defp page(html, deck, {browser, axe}, sizes) do
    runs = for size <- sizes, scheme <- schemes(deck), do: {size, scheme}

    Enum.reduce_while(runs, {:ok, []}, fn {size, scheme} = run, {:ok, pages} ->
      case Browser.run(html, browser, axe, scheme: scheme, size: size) do
        {:ok, result} -> {:cont, {:ok, pages ++ [{run, result}]}}
        error -> {:halt, error}
      end
    end)
  end

  # The variants of the theme of a deck: `[:light, :dark]` for a theme with
  # two variants, and `[nil]` otherwise.
  defp schemes(deck) do
    deck.metadata |> Map.get(:theme, :default) |> Expresso.Palette.variants() |> Keyword.keys()
  end

  defp page_problems(nil), do: []

  defp page_problems(pages) do
    sizes = pages |> Enum.map(fn {{size, _scheme}, _page} -> size end) |> Enum.uniq()

    pages
    |> Enum.map(fn {run, page} -> {label(run, length(sizes)), problems_of(page)} end)
    |> variants()
  end

  # The name of a run in the report: the size when the check has more than
  # one size, and the variant of the theme when the theme has two variants.
  defp label({{width, height}, scheme}, sizes) do
    [if(sizes > 1, do: "#{width} × #{height}"), scheme]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp problems_of(page) do
    accessibility =
      Enum.map(page.accessibility || [], fn finding ->
        "#{finding["where"]}: #{finding["rule"]}, #{finding["help"]}: " <>
          Enum.join(finding["elements"], ", ")
      end)

    page.layout ++ accessibility ++ Map.get(page, :session, [])
  end

  @doc """
  Merge the problems of the runs of the checks of the page

  Each run has a name, such as `dark` or `1280 × 720`. A problem of each run
  gives one line. A problem of some runs names them before the first colon.

      iex> Expresso.Check.variants([{"", ["Slide 1, step 1: a"]}])
      ["Slide 1, step 1: a"]
      iex> Expresso.Check.variants([
      ...>   {"light", ["Slide 1, step 1: a", "Slide 2, step 1: b"]},
      ...>   {"dark", ["Slide 1, step 1: a", "Slide 3, step 2: c"]}
      ...> ])
      ["Slide 1, step 1: a", "Slide 2, step 1 (light): b", "Slide 3, step 2 (dark): c"]
      iex> Expresso.Check.variants([
      ...>   {"1920 × 1080", []},
      ...>   {"1280 × 720", ["Slide 2, step 1: d"]},
      ...>   {"1024 × 768", ["Slide 2, step 1: d"]}
      ...> ])
      ["Slide 2, step 1 (1280 × 720; 1024 × 768): d"]
  """
  @spec variants([{String.t(), [String.t()]}]) :: [String.t()]
  def variants([{_label, problems}]), do: problems

  def variants(runs) do
    runs
    |> Enum.flat_map(fn {_label, problems} -> problems end)
    |> Enum.uniq()
    |> Enum.map(&merged(&1, runs))
  end

  # A problem with the names of the runs that have it, or alone when each run
  # has it.
  defp merged(problem, runs) do
    case for {label, problems} <- runs, problem in problems, do: label do
      labels when length(labels) == length(runs) -> problem
      labels -> in_runs(problem, Enum.join(labels, "; "))
    end
  end

  defp in_runs(problem, labels) do
    case String.split(problem, ": ", parts: 2) do
      [where, what] -> "#{where} (#{labels}): #{what}"
      [_one] -> "#{problem} (#{labels})"
    end
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

  defp ran(level, nil), do: checks(level, nil) <> "\n"

  defp ran(level, pages) do
    variants =
      if Enum.any?(pages, fn {{_size, scheme}, _page} -> scheme != nil end),
        do: ", in the light and the dark variants",
        else: ""

    checks(level, sizes(pages)) <> variants <> "\n"
  end

  defp checks(:basic, _sizes),
    do: "Checks: the render, the theme and the text for a screen reader"

  defp checks(:layout, sizes),
    do: "Checks: the render, the theme, the text for a screen reader, and the layout at #{sizes}"

  defp checks(:a11y, sizes),
    do:
      "Checks: the render, the theme, the text for a screen reader, the layout at #{sizes}, " <>
        "and axe-core at each step and in each view"

  defp checks(:browser, sizes),
    do:
      "Checks: the render, the theme, the text for a screen reader, the layout at #{sizes}, " <>
        "axe-core at each step and in each view, and the keys of the presenter in Playwright"

  # The sizes of the pages, as the pages give them, such as
  # `1920 × 1080 and 1280 × 720`.
  defp sizes(pages) do
    pages
    |> Enum.map(fn {_run, page} -> "#{page.width} × #{page.height}" end)
    |> Enum.uniq()
    |> Enum.join(" and ")
  end

  defp section(_title, []), do: []

  defp section(title, lines),
    do: ["\n", title, ":\n", Enum.map(lines, &["  - ", &1, "\n"])]

  defp summary([]), do: "No problems.\n"
  defp summary(problems), do: "#{length(problems)} #{plural(length(problems), "problem")}.\n"

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"
end
