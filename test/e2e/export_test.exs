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

  # The deck of issue #602. The image is larger than a page, so it must become
  # smaller to fit its slide. The handout view gives a page to each step: three
  # pages of the slide "blue" and one page of the slide "gold".
  @large_images """
  defmodule LargeImageDeck do
    use Expresso
    root __DIR__

    slide "blue" do
      heading "Blue"

      list do
        reveal true
        item "One"
        item "Two"
      end

      image "large.png", alt: "Blue", at: 3
    end

    slide "gold" do
      heading "Gold"
      image "large.png", alt: "Gold"
      image "large.png", alt: "Gold again"
    end
  end

  LargeImageDeck
  """

  describe "--pdf-pages handout with a large image" do
    test "each page holds the whole image of its step", %{tmp_dir: dir} = context do
      input = Path.join(dir, "large.exs")
      File.write!(input, @large_images)
      File.write!(Path.join(dir, "large.png"), solid_png(3000, 1700))
      options = %{Export.defaults() | pdf: context.pdf, pdf_pages: :handout}

      assert {:ok, [line]} = Export.export(input, nil, options)

      # Step 3 of "blue" shows one image, and "gold" shows two. The image of
      # a step that does not show it does not print. Without the fix, the
      # image of "blue" goes onto the page of "gold", and the second image of
      # "gold" goes onto a fifth page.
      boxes = image_boxes(context.pdf)
      assert Enum.map(boxes, &length/1) == [0, 0, 1, 2]
      assert line == "Wrote #{context.pdf}: 4 pages."

      # A4 landscape is 841.92 × 594.96 points, and the margin is 1 cm, which
      # is 28.35 points. Each image is in the area inside the margin. The
      # browser puts an image on the pixels of 300 dpi, so the limit is 1 point
      # larger.
      margin = 28.35 - 1

      for {x0, y0, x1, y1} <- List.flatten(boxes) do
        assert x0 >= margin and y0 >= margin
        assert x1 <= 841.92 - margin and y1 <= 594.96 - margin
      end
    end
  end

  # Each image keeps its file next to the document, so it has
  # `loading="lazy"`. Slide 3 is hidden, and the deck gives it its pages.
  @external_images """
  defmodule ExternalImageDeck do
    use Expresso
    root __DIR__
    external true
    handout_hidden true

    slide "one" do
      heading "One"
      image "photo.png", alt: "One"
    end

    slide "two" do
      heading "Two"
      image "photo.png", alt: "Two"
    end

    slide "backup" do
      hidden true
      heading "Backup"
      image "photo.png", alt: "Backup"
    end

    slide "four" do
      heading "Four"
      image "photo.png", alt: "Four"
    end
  end

  ExternalImageDeck
  """

  describe "a deck with images next to the document" do
    setup %{tmp_dir: dir} do
      input = Path.join(dir, "external.exs")
      File.write!(input, @external_images)
      File.write!(Path.join(dir, "photo.png"), solid_png(400, 300))
      %{input: input, output: Path.join(dir, "external.html")}
    end

    test "each page of the slides and of the handout view holds its image, also on a hidden slide or a later slide",
         %{input: input, output: output} = context do
      for pages <- [:slides, :handout] do
        options = %{Export.defaults() | pdf: context.pdf, pdf_pages: pages}

        assert {:ok, [_line]} = Export.export(input, output, options)
        assert File.read!(output) =~ ~s(<img loading="lazy")
        assert context.pdf |> image_boxes() |> Enum.map(&length/1) == [1, 1, 1, 1]
      end
    end
  end

  # A PNG file of one color, with a width and a height in pixels.
  defp solid_png(width, height, {red, green, blue} \\ {240, 160, 0}) do
    row = [0, :binary.copy(<<red, green, blue>>, width)]
    data = :zlib.compress(List.duplicate(row, height))
    header = <<width::32, height::32, 8, 2, 0, 0, 0>>

    IO.iodata_to_binary([
      <<137, "PNG", 13, 10, 26, 10>>,
      chunk("IHDR", header),
      chunk("IDAT", data),
      chunk("IEND", "")
    ])
  end

  defp chunk(type, data),
    do: [<<byte_size(data)::32>>, type, data, <<:erlang.crc32([type, data])::32>>]

  # The box of each image that each page of a PDF draws, as `{x0, y0, x1, y1}`
  # in points, in the order of the pages. The browser writes each page with
  # one content stream. The stream draws an image with the operator `Do`, in
  # the unit square of the current transformation matrix. The operators `q`,
  # `Q` and `cm` keep and change that matrix.
  defp image_boxes(pdf) do
    objects = pdf |> File.read!() |> objects()
    images = for {number, {dict, _stream}} <- objects, dict =~ "/Subtype /Image", do: number

    [kids] = Regex.run(~r{/Kids \[([^\]]*)\]}, root_pages(objects), capture: :all_but_first)

    for page <- references(kids) do
      {dict, _stream} = objects[page]
      [contents] = Regex.run(~r{/Contents (\d+) 0 R}, dict, capture: :all_but_first)
      {_dict, stream} = objects[String.to_integer(contents)]

      names =
        ~r{/(\w+) (\d+) 0 R}
        |> Regex.scan(dict, capture: :all_but_first)
        |> Map.new(fn [name, number] -> {name, String.to_integer(number)} end)

      stream
      |> :zlib.uncompress()
      |> draws()
      |> Enum.filter(fn {name, _box} -> names[name] in images end)
      |> Enum.map(fn {_name, box} -> box end)
    end
  end

  defp root_pages(objects) do
    Enum.find_value(objects, fn {_number, {dict, _stream}} ->
      if dict =~ ~r{/Type /Pages\b}, do: dict
    end)
  end

  defp references(text) do
    ~r{(\d+) 0 R}
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
  end

  # Each object of a PDF, as its number and a tuple of its dictionary and its
  # stream. An object with no stream has `nil`.
  defp objects(data) do
    ~r{(\d+) 0 obj\b(.*?)endobj}s
    |> Regex.scan(data, capture: :all_but_first)
    |> Map.new(fn [number, body] ->
      case Regex.run(~r{\A(.*?)stream\r?\n(.*)\r?\nendstream\s*\z}s, body,
             capture: :all_but_first
           ) do
        [dict, stream] -> {String.to_integer(number), {dict, stream}}
        nil -> {String.to_integer(number), {body, nil}}
      end
    end)
  end

  # The name and the box of each `Do` operator of a content stream. The
  # state has the current matrix, the stack of `q`, the operands and the boxes.
  defp draws(content) do
    {_matrix, _stack, _operands, draws} =
      content
      |> String.split()
      |> Enum.reduce({{1, 0, 0, 1, 0, 0}, [], [], []}, &operator/2)

    Enum.reverse(draws)
  end

  defp operator("q", {matrix, stack, _operands, draws}), do: {matrix, [matrix | stack], [], draws}

  defp operator("Q", {_matrix, [matrix | stack], _operands, draws}),
    do: {matrix, stack, [], draws}

  defp operator("cm", {matrix, stack, operands, draws}) do
    [f, e, d, c, b, a] = Enum.take(operands, 6)
    {multiply({a, b, c, d, e, f}, matrix), stack, [], draws}
  end

  defp operator("Do", {matrix, stack, ["/" <> name | _operands], draws}),
    do: {matrix, stack, [], [{name, unit_box(matrix)} | draws]}

  defp operator(token, {matrix, stack, operands, draws}) do
    case operand(token) do
      nil -> {matrix, stack, [], draws}
      value -> {matrix, stack, [value | operands], draws}
    end
  end

  # A number or a name is an operand. Each other token is an operator.
  defp operand("/" <> _name = token), do: token

  defp operand(token) do
    case Float.parse(String.replace(token, ~r{\A(-?)\.}, "\\g{1}0.")) do
      {value, ""} -> value
      _other -> nil
    end
  end

  # The product of two matrices of PDF. A point gets the first matrix first.
  defp multiply({a1, b1, c1, d1, e1, f1}, {a2, b2, c2, d2, e2, f2}) do
    {a1 * a2 + b1 * c2, a1 * b2 + b1 * d2, c1 * a2 + d1 * c2, c1 * b2 + d1 * d2,
     e1 * a2 + f1 * c2 + e2, e1 * b2 + f1 * d2 + f2}
  end

  defp unit_box({a, b, c, d, e, f}) do
    points =
      for {x, y} <- [{0, 0}, {1, 0}, {0, 1}, {1, 1}], do: {a * x + c * y + e, b * x + d * y + f}

    {xs, ys} = Enum.unzip(points)
    {Enum.min(xs), Enum.min(ys), Enum.max(xs), Enum.max(ys)}
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

  # Slide 1 has a blue background, and slide 2 has a gold background. The
  # `card` option names the file of `--card`, and that file does not exist
  # before the export.
  @card_deck """
  defmodule CardDeck do
    use Expresso
    root __DIR__

    name "card deck"
    url "https://example.com/talk/"
    card image: "card.png", alt: "The title slide"

    slide "blue" do
      background "blue.png"
      heading "Blue"
    end

    slide "gold" do
      background "gold.png"
      heading "Gold"
    end
  end

  CardDeck
  """

  describe "--card" do
    setup %{tmp_dir: dir} do
      input = Path.join(dir, "card.exs")
      File.write!(input, @card_deck)
      File.write!(Path.join(dir, "blue.png"), solid_png(64, 36, {0, 90, 200}))
      File.write!(Path.join(dir, "gold.png"), solid_png(64, 36, {240, 160, 0}))
      %{input: input, card: Path.join(dir, "card.png")}
    end

    test "writes slide 1 at 1200 × 630, and the document then holds the card",
         %{tmp_dir: dir} = context do
      output = Path.join(dir, "index.html")
      options = %{Export.defaults() | card: context.card}

      assert Export.export(context.input, output, options) ==
               {:ok, ["Wrote #{context.card}: slide 1 at 1200 × 630."]}

      assert png_size(context.card) == {1200, 630}
      assert near?(corner_color(context.card), {0, 90, 200})

      # The render after the card reads the new file.
      html = File.read!(output)
      assert html =~ ~s(<meta property="og:image:width" content="1200"/>)
      assert html =~ ~s(<meta property="og:image:height" content="630"/>)
      assert [_copy] = File.ls!(Path.join(dir, "index_files"))
    end

    test "writes the slide of --card-slide, with the other exports", context do
      options = %{Export.defaults() | card: context.card, card_slide: 2, png: context.png}

      assert Export.export(context.input, nil, options) ==
               {:ok,
                [
                  "Wrote #{context.card}: slide 2 at 1200 × 630.",
                  "Wrote 2 PNG files to #{context.png}."
                ]}

      assert png_size(context.card) == {1200, 630}
      assert near?(corner_color(context.card), {240, 160, 0})
      assert png_size(Path.join(context.png, "slide-2.png")) == {1920, 1080}
    end

    test "a render with no card file gives the error that names --card", context do
      assert_raise ArgumentError, Expresso.LinkPreview.missing_card(context.card), fn ->
        Expresso.main(context.input, Path.join(Path.dirname(context.card), "index.html"))
      end
    end

    test "mix expresso writes the card", context do
      output =
        capture_io(fn ->
          assert Expresso.CommandLine.run(
                   [context.input, "--card", context.card, "--card-slide", "2"],
                   "mix expresso",
                   "help"
                 ) == 0
        end)

      assert output == "Wrote #{context.card}: slide 2 at 1200 × 630.\n"
      assert png_size(context.card) == {1200, 630}
    end
  end

  # The color of the pixel at (8, 8) of a PNG file, which the background of
  # the slide fills.
  defp corner_color(path) do
    {:ok, {width, height, rows}} = Expresso.Gif.Png.inflate(File.read!(path))
    rgb = Expresso.Gif.Nif.unfilter(rows, width, height)
    <<red, green, blue>> = binary_part(rgb, (8 * width + 8) * 3, 3)
    {red, green, blue}
  end

  # The browser can change a color by a small amount when it draws an image.
  defp near?({r1, g1, b1}, {r2, g2, b2}),
    do: abs(r1 - r2) <= 4 and abs(g1 - g2) <= 4 and abs(b1 - b2) <= 4

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
