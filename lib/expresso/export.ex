defmodule Expresso.Export do
  @moduledoc """
  Runs `mix expresso <input> --pdf <file>` and `--png <directory>`: a PDF of a deck, and a PNG of each slide

  The export renders the deck, and a headless Chrome or Chromium writes the
  files. `Expresso.Check.Browser.find/3` finds the browser, so the export
  needs the browser of `--check=layout`, and no other tool.

  | Option | File |
  | --- | --- |
  | `--pdf deck.pdf` | A PDF with one page for each slide, as the present view shows its last step. The page has the size of `--size`, or 1920 × 1080, and the theme of the deck. |
  | `--pdf deck.pdf --pdf-pages handout` | A PDF of the handout view, as the print dialog of the browser gives it: the steps of the `handout` option, the notes and the theme of paper. `--pdf-paper` gives the paper, `a4` or `letter`. |
  | `--pdf-steps all` | A page for each step, in either form. |
  | `--png slides` | One PNG file for the last step of each slide, such as `slides/slide-03.png`, at the size of `--size`, or 1920 × 1080. |
  | `--png-steps all` | One PNG file for each step, such as `slides/slide-03-step-2.png`. |

  A hidden slide has no page and no file, as it has no page on paper. The
  deck option `handout_hidden true` gives it its pages and its files.

  The browser prints a copy of the document for the PDF. `print_document/2`
  writes the form and the size of the page into that copy, and the style
  sheet of the theme reads them in its rules for paper. For each PNG file, the
  browser opens the present view at the step and takes a picture of the
  window. `docs/export.md` gives the design.
  """

  alias Expresso.Check.Browser
  alias Expresso.Overlay.Render

  @typedoc """
  The options of an export

  `pdf` is the path of the PDF, and `png` is the directory of the PNG files.
  Each is `nil` when the command line does not give it. `size` is `nil` for
  the default size.
  """
  @type options :: %{
          pdf: Path.t() | nil,
          pdf_pages: :slides | :handout,
          pdf_steps: :selected | :all,
          pdf_paper: :a4 | :letter,
          png: Path.t() | nil,
          png_steps: :last | :all,
          size: Expresso.Check.size() | nil
        }

  # The size of a page of the slides and of a PNG file without `--size`. It
  # is the size of the page of `--check`.
  @default_size {1920, 1080}

  # The time in the page that the browser gives the document before it
  # prints or takes a picture. The browser advances this time only when the
  # page waits, so the export does not wait for this time.
  @budget 10_000

  # The time in milliseconds that one run of the browser can take.
  @timeout 120_000

  @need "--pdf and --png need"
  @guide "docs/how-to/export-a-deck.md"

  @doc """
  Return the options of an export with no file

      iex> Expresso.Export.defaults()
      %{
        pdf: nil,
        pdf_pages: :slides,
        pdf_steps: :selected,
        pdf_paper: :a4,
        png: nil,
        png_steps: :last,
        size: nil
      }
  """
  @spec defaults() :: options()
  def defaults do
    %{
      pdf: nil,
      pdf_pages: :slides,
      pdf_steps: :selected,
      pdf_paper: :a4,
      png: nil,
      png_steps: :last,
      size: nil
    }
  end

  @doc """
  Export the deck of an input file, write a line for each export, and return the exit status

  With `output`, the function also writes the HTML to that file. A line such
  as `Wrote deck.pdf: 12 pages.` goes to the standard output, and an error
  goes to the standard error. The exit status is 1 for an error, and 0
  otherwise.
  """
  @spec run(Path.t(), Path.t() | nil, options()) :: 0 | 1
  def run(input, output, options) do
    case export(input, output, options) do
      {:ok, lines} ->
        Enum.each(lines, &IO.puts/1)
        0

      {:error, message} ->
        IO.puts(:stderr, message)
        1
    end
  end

  @doc """
  Export the deck of an input file, and return a line for each export

  The function writes the HTML to `output` when it is not `nil`, and it
  writes the files of the options. It finds the browser before the render,
  so a missing browser gives its error at once. `env` holds the variables of
  the environment, and `EXPRESSO_CHROMIUM` in it gives the path of the
  browser.
  """
  @spec export(Path.t(), Path.t() | nil, options(), %{String.t() => String.t()}) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def export(input, output, options, env \\ System.get_env()) do
    with {:ok, browser} <- Browser.find(env, @need, @guide),
         {:ok, deck} <- Expresso.load_file(input),
         html = Expresso.Deck.render(deck),
         :ok <- write(output, html, "output file") do
      files(html, deck, browser, options)
    end
  end

  defp files(html, deck, browser, options) do
    private_dir = Expresso.PrivateDir.open!("export")

    try do
      with {:ok, pdf} <- pdf(html, browser, private_dir.path, options),
           {:ok, png} <- png(html, deck, browser, private_dir.path, options),
           do: {:ok, pdf ++ png}
    after
      Expresso.PrivateDir.close(private_dir)
    end
  end

  # The PDF. The browser writes it into the private directory, and the
  # function then writes it to its path, so an error leaves no part of a file.
  defp pdf(_html, _browser, _directory, %{pdf: nil}), do: {:ok, []}

  # sobelow_skip ["Traversal"]
  defp pdf(html, browser, directory, %{pdf: path} = options) do
    page = Path.join(directory, "print.html")
    file = Path.join(directory, "deck.pdf")
    File.write!(page, print_document(html, options))

    args = [
      "--no-pdf-header-footer",
      "--virtual-time-budget=#{@budget}",
      "--print-to-pdf=#{file}",
      "file://#{page}"
    ]

    with {:ok, _output} <- Browser.command(browser, args, directory, timeout: @timeout),
         {:ok, bytes} <- written(file, browser, "PDF"),
         :ok <- write(path, bytes, "PDF file") do
      {:ok, ["Wrote #{path}: #{count(pages(bytes), "page")}."]}
    end
  end

  @doc """
  Make the copy of a document that the browser prints for the PDF

  The function writes `data-print="slides"` on the `html` element for the
  pages of the slides, and `data-print-steps="all"` for a page of each step.
  The presenter script does not change these attributes, and the style sheet
  reads them in its rules for paper. The function also adds the rule of the
  page: the size of `--size` with no margin for the slides, and the paper of
  `--pdf-paper` for the handout view.

      iex> options = %{Expresso.Export.defaults() | size: {1280, 720}, pdf_steps: :all}
      iex> Expresso.Export.print_document(~s(<!DOCTYPE html>\\n<html lang="en"><head></head></html>), options)
      ~s(<!DOCTYPE html>\\n<html data-print="slides" data-print-steps="all" lang="en"><head>) <>
        "<style>@page { size: 1280px 720px; margin: 0; }</style></head></html>"

      iex> options = %{Expresso.Export.defaults() | pdf_pages: :handout, pdf_paper: :letter}
      iex> Expresso.Export.print_document("<html><head></head></html>", options)
      "<html><head><style>@page { size: letter landscape; margin: 1cm; }</style></head></html>"
  """
  @spec print_document(String.t(), options()) :: String.t()
  def print_document(html, options) do
    attributes =
      [
        if(options.pdf_pages == :slides, do: ~s( data-print="slides")),
        if(options.pdf_steps == :all, do: ~s( data-print-steps="all"))
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join()

    html
    |> String.replace("<html", "<html" <> attributes, global: false)
    |> String.replace("</head>", "<style>#{page_rule(options)}</style></head>", global: false)
  end

  defp page_rule(%{pdf_pages: :slides, size: size}) do
    {width, height} = size || @default_size
    "@page { size: #{width}px #{height}px; margin: 0; }"
  end

  defp page_rule(%{pdf_pages: :handout, pdf_paper: :a4}),
    do: "@page { size: A4 landscape; margin: 1cm; }"

  defp page_rule(%{pdf_pages: :handout, pdf_paper: :letter}),
    do: "@page { size: letter landscape; margin: 1cm; }"

  @doc """
  Return the number of pages of a PDF

  The function counts the page objects of the file, so it needs no PDF tool.

      iex> Expresso.Export.pages("1 0 obj <</Type /Pages /Count 2>> 2 0 obj <</Type /Page>> 3 0 obj <</Type/Page /Parent 1 0 R>>")
      2
  """
  @spec pages(binary()) :: non_neg_integer()
  def pages(pdf), do: length(Regex.scan(~r{/Type\s*/Page(?![a-zA-Z])}, pdf))

  # The PNG files. The browser opens the present view at each step in a window
  # of the size, and it takes a picture. Each run of the browser has its own
  # profile, so the runs can go at the same time.
  defp png(_html, _deck, _browser, _directory, %{png: nil}), do: {:ok, []}

  # sobelow_skip ["Traversal"]
  defp png(html, deck, browser, directory, %{png: target} = options) do
    size = options.size || @default_size
    page = Path.join(directory, "deck.html")
    File.write!(page, screen_document(html))

    with {:ok, window} <- Browser.window(browser, directory, size),
         {:ok, files} <- pictures(shots(deck, options.png_steps), page, browser, window, size),
         :ok <- make_directory(target),
         :ok <- copy(files, target) do
      {:ok, ["Wrote #{count(length(files), "PNG file")} to #{target}."]}
    end
  end

  @doc """
  Make the copy of a document that the browser opens for a PNG file

  The copy does not show the progress bar, because a picture of a slide is
  not a talk.

      iex> Expresso.Export.screen_document("<html><head></head></html>")
      "<html><head><style>#progress { display: none !important; }</style></head></html>"
  """
  @spec screen_document(String.t()) :: String.t()
  def screen_document(html) do
    String.replace(
      html,
      "</head>",
      "<style>#progress { display: none !important; }</style></head>",
      global: false
    )
  end

  @doc """
  Return the slide, the step and the name of each PNG file of a deck

  `steps` is `:last` for the last step of each slide, and `:all` for each
  step. The name holds the number of the slide in the deck, which is the
  number in the address of the slide. Each number has the digits of the
  largest number, so the names sort in the order of the deck. A hidden slide
  gives no file, except with the deck option `handout_hidden true`.

      iex> alias Expresso.Builder
      iex> box = Builder.text_box(elements: [Builder.text_area(text: "A box")], at: [from: 2])
      iex> deck = Builder.deck([Builder.slide("one", elements: [box]), Builder.slide("two", elements: [])])
      iex> Expresso.Export.shots(deck, :last)
      [{1, 2, "slide-1.png"}, {2, 1, "slide-2.png"}]
      iex> Expresso.Export.shots(deck, :all)
      [{1, 1, "slide-1-step-1.png"}, {1, 2, "slide-1-step-2.png"}, {2, 1, "slide-2-step-1.png"}]
  """
  @spec shots(Expresso.Deck.t(), :last | :all) :: [{pos_integer(), pos_integer(), String.t()}]
  def shots(deck, steps) do
    slides =
      for {slide, number} <- Enum.with_index(deck.slides, 1),
          not Expresso.Slide.hidden?(slide) or (deck.metadata || %{})[:handout_hidden] == true,
          do: {number, Render.max_step(slide)}

    slide_digits = digits(length(deck.slides))
    step_digits = slides |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end) |> digits()

    for {number, max} <- slides, step <- steps_of(steps, max) do
      name =
        case steps do
          :last -> "slide-#{pad(number, slide_digits)}.png"
          :all -> "slide-#{pad(number, slide_digits)}-step-#{pad(step, step_digits)}.png"
        end

      {number, step, name}
    end
  end

  defp steps_of(:last, max), do: [max]
  defp steps_of(:all, max), do: Enum.to_list(1..max//1)

  defp digits(number), do: number |> Integer.to_string() |> String.length()
  defp pad(number, digits), do: number |> Integer.to_string() |> String.pad_leading(digits, "0")

  # Take each picture. The result holds the path of each file in the private
  # directory, or the first error.
  defp pictures(shots, page, browser, window, size) do
    shots
    |> Task.async_stream(&picture(&1, page, browser, window, size),
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, file}}, {:ok, files} -> {:cont, {:ok, [file | files]}}
      {:ok, {:error, message}}, _files -> {:halt, {:error, message}}
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      error -> error
    end
  end

  defp picture({slide, step, name}, page, browser, {width, height}, size) do
    directory = Path.dirname(page)
    file = Path.join(directory, name)

    args = [
      "--window-size=#{width},#{height}",
      "--force-prefers-reduced-motion",
      "--virtual-time-budget=#{@budget}",
      "--screenshot=#{file}",
      "file://#{page}##{slide}.#{step}"
    ]

    opts = [timeout: @timeout, profile: "profile-#{slide}-#{step}"]

    with {:ok, _output} <- Browser.command(browser, args, directory, opts),
         {:ok, bytes} <- written(file, browser, "PNG"),
         :ok <- same_size(bytes, size, browser) do
      {:ok, {file, name}}
    end
  end

  @doc """
  Make sure that a PNG file has the size of the export

  A Chrome window is not narrower than 500 px, so Chrome can give a picture
  that is larger than the size of `--size`. The headless shell gives each
  size.

      iex> header = <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, "IHDR", 1920::32, 1080::32>>
      iex> Expresso.Export.same_size(header, {1920, 1080}, "chrome")
      :ok
      iex> {:error, message} = Expresso.Export.same_size(header, {375, 667}, "chrome")
      iex> message
      "The browser chrome made a picture of 1920 × 1080, and not of 375 × 667. Chrome cannot " <>
        "make a page narrower than 500 px. Use the headless shell of Playwright in " <>
        "EXPRESSO_CHROMIUM, or a larger --size."
  """
  @spec same_size(binary(), Expresso.Check.size(), Path.t()) :: :ok | {:error, String.t()}
  def same_size(
        <<_signature::binary-size(16), width::32, height::32, _rest::binary>>,
        size,
        browser
      ) do
    if {width, height} == size do
      :ok
    else
      {expected_width, expected_height} = size

      {:error,
       "The browser #{browser} made a picture of #{width} × #{height}, and not of " <>
         "#{expected_width} × #{expected_height}. Chrome cannot make a page narrower than " <>
         "500 px. Use the headless shell of Playwright in EXPRESSO_CHROMIUM, or a larger --size."}
    end
  end

  def same_size(_bytes, _size, browser),
    do: {:error, "The browser #{browser} wrote a file that is not a PNG file."}

  # The file that the browser wrote. A browser that writes no file gives the
  # exit status 0 too.
  # sobelow_skip ["Traversal"]
  defp written(file, browser, kind) do
    case File.read(file) do
      {:ok, bytes} when bytes != "" -> {:ok, bytes}
      _no_file -> {:error, "The browser #{browser} wrote no #{kind} file."}
    end
  end

  defp write(nil, _bytes, _name), do: :ok

  # sobelow_skip ["Traversal"]
  defp write(path, bytes, name) do
    case File.write(path, bytes) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Couldn't write #{name} #{path}: #{:file.format_error(reason)}"}
    end
  end

  # sobelow_skip ["Traversal"]
  defp make_directory(target) do
    case File.mkdir_p(target) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Couldn't make directory #{target}: #{:file.format_error(reason)}"}
    end
  end

  # sobelow_skip ["Traversal"]
  defp copy(files, target) do
    Enum.reduce_while(files, :ok, fn {file, name}, :ok ->
      case File.cp(file, Path.join(target, name)) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, "Couldn't write PNG file #{name}: #{:file.format_error(reason)}"}}
      end
    end)
  end

  defp count(1, name), do: "1 #{name}"
  defp count(number, name), do: "#{number} #{name}s"
end
