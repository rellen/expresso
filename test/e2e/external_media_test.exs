defmodule Expresso.E2E.ExternalMediaTest do
  use Expresso.E2E, async: false

  import ExUnit.CaptureIO

  alias Expresso.MediaFiles

  # Slide 2 plays a clip from a file next to the document, and slide 3 plays
  # a chime from such a file.
  defmodule Deck do
    use Expresso

    name "external deck"

    slide "start" do
      text_box do
        text_area(text: "Start")
      end
    end

    slide "clip" do
      video "test/fixtures/clip.webm" do
        title "A clip"
        poster "test/fixtures/dot.png"
        external true
      end
    end

    slide "chime" do
      audio "test/fixtures/chime.wav" do
        title "A chime"
        external true
        loop true
      end
    end
  end

  # Each image of the deck keeps its file next to the document, because the
  # deck has the option. The image of slide 2 shows at step 2.
  defmodule ImageDeck do
    use Expresso

    name "image deck"
    external true

    slide "start" do
      heading "Start"
      image "test/fixtures/dot.png", alt: "A dot"
    end

    slide "halves" do
      heading "Halves"

      list do
        item "One"
      end

      image "test/fixtures/halves.png", alt: "Two halves", at: 2
    end
  end

  defp dot_name, do: MediaFiles.name("dot.png", File.read!("test/fixtures/dot.png"))
  defp halves_name, do: MediaFiles.name("halves.png", File.read!("test/fixtures/halves.png"))

  # A PNG file of one color with a width and a height.
  defp png(width, height) do
    row = <<0>> <> :binary.copy(<<200, 30, 30>>, width)
    data = :zlib.compress(:binary.copy(row, height))

    chunk = fn type, body ->
      <<byte_size(body)::32, type::binary, body::binary, :erlang.crc32(type <> body)::32>>
    end

    <<137, "PNG", 13, 10, 26, 10>> <>
      chunk.("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
      chunk.("IDAT", data) <> chunk.("IEND", "")
  end

  # The address and the state of each image that shows: the browser decoded
  # an image when it is complete and has a width.
  @images """
  [...document.querySelectorAll(".image img")]
    .filter((image) => image.getClientRects().length > 0)
    .map((image) => [image.getAttribute("src"), image.complete && image.naturalWidth > 0])
  """

  describe "an image with the external option of the deck" do
    test "the present view shows each image from the copy next to the document", %{
      page: page,
      tmp_dir: tmp_dir
    } do
      audience = open(page, render(ImageDeck, tmp_dir))
      wait_for(audience, "document.querySelector('#slide-1 .image img').complete")

      assert js(audience, @images) == [["deck_files/" <> dot_name(), true]]

      assert js(audience, "document.querySelector('#slide-1 .image img').currentSrc") ==
               "file://" <> Path.join([tmp_dir, "deck_files", dot_name()])

      refute File.read!(Path.join(tmp_dir, "deck.html")) =~ "data:image/png"

      assert Enum.sort(File.ls!(Path.join(tmp_dir, "deck_files"))) ==
               Enum.sort([dot_name(), halves_name()])

      # The browser has the image of slide 2 before the slide shows, so the
      # image shows at its step with no wait.
      assert js(audience, "document.querySelector('#slide-2 .image img').complete")
      audience |> press("j") |> press("j") |> wait_for_position("2.2")
      assert js(audience, @images) == [["deck_files/" <> halves_name(), true]]
    end

    for {view, key} <- [{"handout view", "p"}, {"menu", "m"}, {"overview", "o"}] do
      test "the #{view} shows each image from the copy", %{page: page, tmp_dir: tmp_dir} do
        audience = page |> open(render(ImageDeck, tmp_dir)) |> press(unquote(key))

        wait_for(audience, """
        (() => {
          const images = #{@images};
          return images.length >= 2 && images.every(([_src, shown]) => shown);
        })()
        """)

        addresses = audience |> js(@images) |> Enum.map(&hd/1) |> Enum.uniq() |> Enum.sort()

        assert addresses ==
                 Enum.sort(["deck_files/" <> dot_name(), "deck_files/" <> halves_name()])
      end
    end
  end

  defp clip_name, do: MediaFiles.name("clip.webm", File.read!("test/fixtures/clip.webm"))
  defp chime_name, do: MediaFiles.name("chime.wav", File.read!("test/fixtures/chime.wav"))

  @video "document.querySelector('#slide-2 video')"
  @audio "document.querySelector('#slide-3 audio')"

  test "the video loads its file only when its slide shows", %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))

    # Slide 1 shows. The video has no source, so the browser did not ask for
    # the file. 0 is NETWORK_EMPTY.
    assert js(audience, "[#{@video}.getAttribute('src'), #{@video}.networkState]") == [nil, 0]
    refute File.read!(Path.join(tmp_dir, "deck.html")) =~ "data:video/"

    audience |> press("j")
    wait_for(audience, "#{@video}.paused === false && #{@video}.readyState >= 2")

    # The source is the copy next to the document.
    assert js(audience, "#{@video}.getAttribute('src')") == "deck_files/" <> clip_name()

    assert js(audience, "#{@video}.currentSrc") ==
             "file://" <> Path.join([tmp_dir, "deck_files", clip_name()])

    # The browser decoded the clip of the deck.
    assert js(audience, "#{@video}.videoWidth") > 0
    assert js(audience, "#{@video}.error") == nil
  end

  test "the sound loads its file only when its slide shows", %{page: page, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    assert js(audience, "[#{@audio}.getAttribute('src'), #{@audio}.networkState]") == [nil, 0]

    audience |> press("j") |> press("j")
    wait_for(audience, "#{@audio}.readyState >= 2")

    assert js(audience, "#{@audio}.getAttribute('src')") == "deck_files/" <> chime_name()
    refute File.read!(Path.join(tmp_dir, "deck.html")) =~ "data:audio/"
  end

  test "the speaker view and the handout view load no file", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)

    speaker |> press("j")
    wait_for(audience, "#{@video}.paused === false")

    assert js(speaker, """
           [...document.querySelectorAll("video, audio")]
             .every((medium) => medium.getAttribute("src") === null)
           """)
  end

  describe "the watch mode" do
    setup %{tmp_dir: tmp_dir} do
      input = Path.join(tmp_dir, "talk.exs")
      clip = Path.expand("test/fixtures/clip.webm")
      poster = Path.expand("test/fixtures/dot.png")

      File.write!(input, """
      import Expresso.Builder

      box = fn text -> text_box(elements: [text_area(text: text)]) end

      deck(
        [
          slide("start", elements: [box.("Start")]),
          slide("clip",
            elements: [
              video(#{inspect(clip)}, title: "A clip", poster: #{inspect(poster)}, external: true)
            ]
          )
        ],
        name: "a watched deck"
      )
      """)

      {:ok, device} = StringIO.open("")
      test = self()

      pid =
        spawn_link(fn ->
          Expresso.Watch.run(input, nil,
            port: 0,
            interval: 50,
            notify: test,
            device: device,
            error_device: device
          )
        end)

      on_exit(fn -> Process.exit(pid, :kill) end)
      assert_receive {Expresso.Watch, {:serving, url}}, 5_000
      assert_receive {Expresso.Watch, {:rendered, 1}}, 10_000
      %{url: url}
    end

    test "the server gives the copy to the video", %{page: page, url: url} do
      audience = open(page, url)
      assert js(audience, "#{@video}.getAttribute('src')") == nil

      audience |> press("j")
      wait_for(audience, "#{@video}.paused === false && #{@video}.readyState >= 2")

      assert js(audience, "#{@video}.currentSrc") == url <> "talk_files/" <> clip_name()
      assert js(audience, "#{@video}.videoWidth") > 0
    end

    test "the video goes to a time of the clip", %{page: page, url: url} do
      audience = open(page, url)
      audience |> press("j")
      wait_for(audience, "#{@video}.readyState >= 2")

      # The server sends a part of the file, so the browser knows the length
      # of the clip, and it can go to each time of it.
      wait_for(audience, "#{@video}.seekable.length === 1 && #{@video}.seekable.end(0) > 0.5")

      js(audience, "#{@video}.pause(); #{@video}.currentTime = 0.6; 0")

      wait_for(
        audience,
        "#{@video}.seeking === false && Math.abs(#{@video}.currentTime - 0.6) < 0.2"
      )

      assert js(audience, "#{@video}.error") == nil
    end
  end

  describe "the watch mode with an image" do
    setup %{tmp_dir: tmp_dir} do
      input = Path.join(tmp_dir, "talk.exs")

      File.write!(input, """
      import Expresso.Builder

      deck(
        [slide("start", elements: [image(#{inspect(Path.expand("test/fixtures/dot.png"))}, alt: "A dot")])],
        name: "a watched deck",
        external: true
      )
      """)

      {:ok, device} = StringIO.open("")
      test = self()

      pid =
        spawn_link(fn ->
          Expresso.Watch.run(input, nil,
            port: 0,
            interval: 50,
            notify: test,
            device: device,
            error_device: device
          )
        end)

      on_exit(fn -> Process.exit(pid, :kill) end)
      assert_receive {Expresso.Watch, {:serving, url}}, 5_000
      assert_receive {Expresso.Watch, {:rendered, 1}}, 10_000
      %{url: url}
    end

    test "the server gives the copy to the image", %{page: page, url: url} do
      audience = open(page, url)
      wait_for(audience, "document.querySelector('#slide-1 .image img').complete")

      assert js(audience, "document.querySelector('#slide-1 .image img').currentSrc") ==
               url <> "talk_files/" <> dot_name()

      assert js(audience, "document.querySelector('#slide-1 .image img').naturalWidth") > 0
    end
  end

  describe "the tools with an image" do
    # The image is larger than the slide, and the rule of the deck lets it
    # keep its size. The check can find the problem only when the browser
    # has the file, because the size comes from the file.
    setup %{tmp_dir: tmp_dir} do
      input = Path.join(tmp_dir, "talk.exs")
      File.write!(Path.join(tmp_dir, "large.png"), png(3000, 1700))

      File.write!(input, """
      import Expresso.Builder

      deck(
        [
          slide("large",
            heading: "Large",
            elements: [image("large.png", alt: "A large image", class: "natural", external: true)]
          )
        ],
        name: "a deck with a large image",
        root: #{inspect(tmp_dir)},
        css: ".natural { flex: none; } .natural img { max-width: none; max-height: none; }"
      )
      """)

      %{input: input, name: MediaFiles.name("large.png", png(3000, 1700))}
    end

    test "the layout check measures the image from the copy next to its document", %{
      input: input,
      name: name,
      tmp_dir: tmp_dir
    } do
      output = Path.join(tmp_dir, "out.html")

      report =
        capture_io(fn ->
          assert Expresso.Check.run(input, output, :layout, []) == 1
        end)

      assert report =~ ~r/Slide 1 “large”, step 1: the image “A large image” goes \d+ px past the/
      assert File.ls!(Path.join(tmp_dir, "out_files")) == [name]
      refute File.read!(output) =~ "data:image/png"
    end

    test "the export writes the copy next to the output file, and it makes the PDF and the picture",
         %{input: input, name: name, tmp_dir: tmp_dir} do
      output = Path.join(tmp_dir, "out.html")
      png = Path.join(tmp_dir, "slides")
      pdf = Path.join(tmp_dir, "out.pdf")
      options = %{Expresso.Export.defaults() | png: png, pdf: pdf}

      assert {:ok, lines} = Expresso.Export.export(input, output, options)
      assert Enum.any?(lines, &(&1 =~ "Wrote 1 PNG file"))
      assert File.ls!(Path.join(tmp_dir, "out_files")) == [name]
      assert File.ls!(png) == ["slide-1.png"]

      # The page of the PDF holds the image of the copy. A page with only text
      # has no image object.
      assert File.read!(pdf) =~ "/Subtype /Image"
    end
  end

  describe "the tools" do
    setup %{tmp_dir: tmp_dir} do
      input = Path.join(tmp_dir, "talk.exs")
      clip = Path.expand("test/fixtures/clip.webm")
      poster = Path.expand("test/fixtures/dot.png")

      File.write!(input, """
      import Expresso.Builder

      deck(
        [
          slide("clip",
            elements: [
              video(#{inspect(clip)}, title: "A clip", poster: #{inspect(poster)}, external: true)
            ]
          )
        ],
        name: "a deck with a clip"
      )
      """)

      %{input: input}
    end

    test "the layout check writes the copy next to its document and next to the output file", %{
      input: input,
      tmp_dir: tmp_dir
    } do
      output = Path.join(tmp_dir, "out.html")

      report =
        capture_io(fn ->
          assert Expresso.Check.run(input, output, :layout, []) == 0
        end)

      assert report =~ "No problems."
      assert File.ls!(Path.join(tmp_dir, "out_files")) == [clip_name()]
      refute File.read!(output) =~ "data:video/"
    end

    test "the check with no output file writes no file next to the input file", %{
      input: input,
      tmp_dir: tmp_dir
    } do
      capture_io(fn -> assert Expresso.Check.run(input, nil, :layout, []) == 0 end)

      assert File.ls!(tmp_dir) == ["talk.exs"]
    end

    test "the export writes the copy next to the output file, and it makes the picture", %{
      input: input,
      tmp_dir: tmp_dir
    } do
      output = Path.join(tmp_dir, "out.html")
      png = Path.join(tmp_dir, "slides")
      options = %{Expresso.Export.defaults() | png: png}

      assert {:ok, [line]} = Expresso.Export.export(input, output, options)
      assert line =~ "Wrote 1 PNG file"
      assert File.ls!(Path.join(tmp_dir, "out_files")) == [clip_name()]
      assert File.ls!(png) == ["slide-1.png"]
    end
  end
end
