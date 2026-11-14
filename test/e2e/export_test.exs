defmodule Expresso.E2E.ExportTest do
  # The export starts its own headless browser, so the module does not use the
  # Playwright of `Expresso.E2E`. The tag puts it with the browser tests.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Expresso.Export

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

  # Slide 1 has two steps and notes. Slide 2 has two steps, and its handout
  # option selects step 1. Slide 3 is hidden. Slide 4 has one step.
  @deck """
  defmodule ExportDeck do
    use Expresso

    name "export deck"
    theme :tomorrow_night

    slide "one" do
      heading "One"
      notes "A note of slide one."

      list do
        reveal true
        item "First"
        item "Second"
      end
    end

    slide "two" do
      handout 1
      heading "Two"

      text_box do
        at from: 2
        text_area(text: "The second step")
      end
    end

    slide "backup" do
      hidden true
      heading "Backup"
    end

    slide "four" do
      heading "Four"
    end
  end

  ExportDeck
  """

  setup %{tmp_dir: dir} do
    input = Path.join(dir, "deck.exs")
    File.write!(input, @deck)
    %{input: input, pdf: Path.join(dir, "deck.pdf"), png: Path.join(dir, "slides")}
  end

  # The width and the height of each page of a PDF, in points.
  defp page_sizes(pdf) do
    ~r{/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]}
    |> Regex.scan(File.read!(pdf), capture: :all_but_first)
    |> Enum.map(fn [width, height] -> {round(number(width)), round(number(height))} end)
    |> Enum.uniq()
  end

  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  # The width and the height of a PNG file, from its header.
  defp png_size(path) do
    <<_signature::binary-size(16), width::32, height::32, _rest::binary>> = File.read!(path)
    {width, height}
  end

  describe "--pdf" do
    test "writes one page for each slide that the talk shows, at 1920 × 1080", context do
      options = %{Export.defaults() | pdf: context.pdf}

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote #{context.pdf}: 3 pages."]}

      # 1920 × 1080 px are 1440 × 810 points.
      assert page_sizes(context.pdf) == [{1440, 810}]
      assert context.pdf |> File.read!() |> Export.pages() == 3
    end

    test "gives the page the size of --size", context do
      options = %{Export.defaults() | pdf: context.pdf, size: {1280, 720}}

      assert {:ok, [_line]} = Export.export(context.input, nil, options)
      assert page_sizes(context.pdf) == [{960, 540}]
    end

    test "writes a page for each step with --pdf-steps all", context do
      options = %{Export.defaults() | pdf: context.pdf, pdf_steps: :all}

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote #{context.pdf}: 5 pages."]}
    end

    test "prints the handout view on A4, with the steps of the handout option", context do
      options = %{Export.defaults() | pdf: context.pdf, pdf_pages: :handout}

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote #{context.pdf}: 4 pages."]}

      assert page_sizes(context.pdf) == [{842, 595}]
    end

    test "prints the handout view on letter, with each step", context do
      options = %{
        Export.defaults()
        | pdf: context.pdf,
          pdf_pages: :handout,
          pdf_paper: :letter,
          pdf_steps: :all
      }

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote #{context.pdf}: 5 pages."]}

      assert page_sizes(context.pdf) == [{792, 612}]
    end

    test "keeps the colors of the deck on the pages of the slides only", context do
      slides = %{Export.defaults() | pdf: context.pdf}
      handout = %{Export.defaults() | pdf: context.pdf <> ".handout.pdf", pdf_pages: :handout}

      assert {:ok, _lines} = Export.export(context.input, nil, slides)
      assert {:ok, _lines} = Export.export(context.input, nil, handout)

      # The background of the theme `tomorrow_night` is #1d1f21, and the PDF
      # holds it as a fill color in its page content. The pages of paper have
      # the white background of the default theme.
      assert dark_fill?(context.pdf)
      refute dark_fill?(handout.pdf)
    end

    test "also writes the HTML to the output file", %{tmp_dir: dir} = context do
      output = Path.join(dir, "deck.html")
      options = %{Export.defaults() | pdf: context.pdf}

      assert {:ok, [_line]} = Export.export(context.input, output, options)
      assert "<!DOCTYPE html>" <> html = File.read!(output)
      # The marks of the PDF are only in the copy that the browser prints.
      refute html =~ "<html data-print"
      refute html =~ "@page { size: 1920px"
    end

    test "gives an error for a path that it cannot write", %{tmp_dir: dir} = context do
      options = %{Export.defaults() | pdf: Path.join([dir, "none", "deck.pdf"])}

      assert {:error, message} = Export.export(context.input, nil, options)
      assert message =~ "Couldn't write PDF file"
    end
  end

  # Tell if a PDF fills an area with the background color of the theme
  # `tomorrow_night`. The browser writes the content of each page with Flate,
  # and the color is three numbers in front of the operator `rg`.
  defp dark_fill?(pdf) do
    ~r/stream\r?\n(.*?)endstream/s
    |> Regex.scan(File.read!(pdf), capture: :all_but_first)
    |> Enum.any?(fn [stream] ->
      case inflate(stream) do
        {:ok, content} -> content =~ ~r/(?:^|\s)\.11\d* \.12\d* \.12\d* rg/
        :error -> false
      end
    end)
  end

  defp inflate(stream) do
    {:ok, :zlib.uncompress(stream)}
  rescue
    _error -> :error
  end

  describe "--png" do
    test "writes one file for the last step of each slide that the talk shows", context do
      options = %{Export.defaults() | png: context.png}

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote 3 PNG files to #{context.png}."]}

      assert context.png |> File.ls!() |> Enum.sort() == ~w(slide-1.png slide-2.png slide-4.png)

      for name <- File.ls!(context.png) do
        assert png_size(Path.join(context.png, name)) == {1920, 1080}
      end
    end

    test "writes one file for each step with --png-steps all, at the size of --size", context do
      options = %{Export.defaults() | png: context.png, png_steps: :all, size: {1280, 720}}

      assert Export.export(context.input, nil, options) ==
               {:ok, ["Wrote 5 PNG files to #{context.png}."]}

      names = ~w(slide-1-step-1.png slide-1-step-2.png slide-2-step-1.png slide-2-step-2.png
                 slide-4-step-1.png)

      assert context.png |> File.ls!() |> Enum.sort() == names

      for name <- names do
        assert png_size(Path.join(context.png, name)) == {1280, 720}
      end

      # The two steps of a slide give two different pictures.
      refute File.read!(Path.join(context.png, "slide-1-step-1.png")) ==
               File.read!(Path.join(context.png, "slide-1-step-2.png"))
    end

    test "the picture of the last step is the picture of that step with each step", context do
      last = %{Export.defaults() | png: context.png}
      all = %{Export.defaults() | png: context.png <> "-all", png_steps: :all}

      assert {:ok, _lines} = Export.export(context.input, nil, last)
      assert {:ok, _lines} = Export.export(context.input, nil, all)

      assert File.read!(Path.join(last.png, "slide-2.png")) ==
               File.read!(Path.join(all.png, "slide-2-step-2.png"))
    end

    test "gives an error for a directory that it cannot make", %{tmp_dir: dir} = context do
      file = Path.join(dir, "a-file")
      File.write!(file, "")
      options = %{Export.defaults() | png: Path.join(file, "slides")}

      assert {:error, message} = Export.export(context.input, nil, options)
      assert message =~ "Couldn't make directory"
    end
  end

  describe "run/3" do
    test "writes a line for each export, and returns 0", context do
      options = %{Export.defaults() | pdf: context.pdf, png: context.png}

      output =
        capture_io(fn -> assert Export.run(context.input, nil, options) == 0 end)

      assert output ==
               "Wrote #{context.pdf}: 3 pages.\nWrote 3 PNG files to #{context.png}.\n"
    end

    test "writes the error of a deck to the standard error, and returns 1", %{tmp_dir: dir} do
      options = %{Export.defaults() | pdf: Path.join(dir, "deck.pdf")}

      error =
        capture_io(:stderr, fn ->
          assert Export.run(Path.join(dir, "none.exs"), nil, options) == 1
        end)

      assert error == "Couldn't find input file\n"
      refute File.exists?(options.pdf)
    end
  end

  describe "mix expresso" do
    test "runs the export of the command line", context do
      output =
        capture_io(fn ->
          assert Expresso.CommandLine.run(
                   [context.input, "--pdf", context.pdf, "--pdf-steps", "all"],
                   "mix expresso",
                   "help"
                 ) == 0
        end)

      assert output == "Wrote #{context.pdf}: 5 pages.\n"
    end
  end
end
