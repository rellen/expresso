defmodule Expresso.E2E.LazyImagesTest do
  use Expresso.E2E, async: false

  import ExUnit.CaptureIO

  alias Expresso.MediaFiles
  alias PlaywrightEx.BrowserContext

  # Each image of the deck keeps its file next to the document, because the
  # deck has the external option, so each image has `loading="lazy"`. Slide 3
  # is hidden. The image of slide 4 is larger than the slide, and the rule of
  # the deck lets it keep its size, so the layout check finds it only when the
  # browser has the file.
  setup %{tmp_dir: tmp_dir} do
    files = %{
      "first.png" => png(40, 30),
      "second.png" => png(50, 30),
      "backup.png" => png(60, 30),
      "large.png" => png(3000, 1700)
    }

    for {name, bytes} <- files, do: File.write!(Path.join(tmp_dir, name), bytes)
    input = Path.join(tmp_dir, "talk.exs")

    File.write!(input, """
    import Expresso.Builder

    deck(
      [
        slide("first", heading: "First", elements: [image("first.png", alt: "The first image")]),
        slide("second", heading: "Second", elements: [image("second.png", alt: "The second image")]),
        slide("backup",
          hidden: true,
          heading: "Backup",
          elements: [image("backup.png", alt: "The backup image")]
        ),
        slide("large",
          heading: "Large",
          elements: [image("large.png", alt: "A large image", class: "natural")]
        )
      ],
      name: "a deck with lazy images",
      root: #{inspect(tmp_dir)},
      external: true,
      css: ".natural { flex: none; } .natural img { max-width: none; max-height: none; }"
    )
    """)

    names = Map.new(files, fn {name, bytes} -> {name, MediaFiles.name(name, bytes)} end)
    %{input: input, names: names}
  end

  # A PNG file of one color with a width and a height.
  defp png(width, height) do
    row = <<0>> <> :binary.copy(<<30, 90, 200>>, width)
    data = :zlib.compress(:binary.copy(row, height))

    chunk = fn type, body ->
      <<byte_size(body)::32, type::binary, body::binary, :erlang.crc32(type <> body)::32>>
    end

    <<137, "PNG", 13, 10, 26, 10>> <>
      chunk.("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
      chunk.("IDAT", data) <> chunk.("IEND", "")
  end

  defp open_deck(page, input, query \\ "") do
    {:ok, deck} = Expresso.load_file(input)
    open(page, render(deck, Path.dirname(input), "talk") <> query)
  end

  # The browser of the context calls no function of `requestIdleCallback`. The
  # page keeps each function in `window.idle`, and the test calls them.
  defp hold_idle(context) do
    {:ok, _result} =
      BrowserContext.add_init_script(context.guid,
        timeout: 10_000,
        source: """
        window.idle = [];
        window.requestIdleCallback = (callback) => window.idle.push(callback);
        """
      )

    context
  end

  # The address of each image with a file next to the document, and true when
  # the browser has its file.
  @images """
  Object.fromEntries(
    [...document.querySelectorAll(".screen img[loading]")].map((image) => [
      image.getAttribute("src").split("/").pop(),
      image.complete && image.naturalWidth > 0,
    ]),
  )
  """

  # True when the browser has the file of each image with `loading`, also of
  # each copy in the handout view, the menu and the overview.
  @all_loaded """
  [...document.querySelectorAll("img[loading]")].every(
    (image) => image.complete && image.naturalWidth > 0,
  )
  """

  describe "the present view" do
    test "asks for the image of the first slide at the load, and for each other image when the browser is idle",
         %{context: context, page: page, input: input, names: names} do
      hold_idle(context)
      audience = open_deck(page, input)
      wait_for(audience, "document.querySelector('#slide-1 img').naturalWidth > 0")

      assert js(audience, @images) == %{
               names["first.png"] => true,
               names["second.png"] => false,
               names["backup.png"] => false,
               names["large.png"] => false
             }

      assert js(audience, "window.idle.length") > 0
      js(audience, "window.idle.splice(0).forEach((callback) => callback())")
      wait_for(audience, @all_loaded)

      assert js(
               audience,
               "[...new Set([...document.querySelectorAll('img[loading]')].map((i) => i.loading))]"
             ) ==
               ["eager"]

      # The image of slide 2 shows with no wait.
      audience |> press("j") |> wait_for_position("2.1")
      assert js(audience, "document.querySelector('#slide-2 img').complete")
    end

    test "asks for each image after a time in a browser with no requestIdleCallback", %{
      context: context,
      page: page,
      input: input
    } do
      {:ok, _result} =
        BrowserContext.add_init_script(context.guid,
          timeout: 10_000,
          source: "window.requestIdleCallback = undefined;"
        )

      audience = open_deck(page, input)
      wait_for(audience, @all_loaded)
      assert js(audience, "window.requestIdleCallback") == nil
    end
  end

  describe "the views that show each page" do
    setup %{context: context} do
      hold_idle(context)
      :ok
    end

    test "the handout view asks for each image at once", %{page: page, input: input} do
      audience = open_deck(page, input)
      refute js(audience, @all_loaded)

      audience |> press("p") |> wait_for(@all_loaded)
      assert js(audience, "window.idle.length") > 0
    end

    test "a print asks for each image at once", %{page: page, input: input} do
      audience = open_deck(page, input)
      refute js(audience, @all_loaded)

      js(audience, "window.dispatchEvent(new Event('beforeprint'))")
      wait_for(audience, @all_loaded)
    end
  end

  describe "the layout check" do
    test "the page waits for each image, and it finds the image that is too large", %{
      context: context,
      page: page,
      input: input
    } do
      hold_idle(context)
      audience = open_deck(page, input, "?check")
      wait_for(audience, "document.body.dataset.layout !== undefined")

      assert js(audience, "document.body.dataset.layout") == "problems"

      assert js(audience, "document.getElementById('layout-check').textContent") =~
               ~r/Slide 4, step 1: the image “A large image” goes \d+ px past the/

      assert js(audience, @all_loaded)
    end

    test "--check=layout finds the image that is too large on a later slide", %{
      input: input,
      names: names,
      tmp_dir: tmp_dir
    } do
      output = Path.join(tmp_dir, "out.html")

      report =
        capture_io(fn ->
          assert Expresso.Check.run(input, output, :layout, []) == 1
        end)

      assert report =~ ~r/Slide 4 “large”, step 1: the image “A large image” goes \d+ px past the/
      assert File.read!(output) =~ ~s(<img loading="lazy" src="out_files/#{names["large.png"]}")
    end
  end
end
