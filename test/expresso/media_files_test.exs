defmodule Expresso.MediaFilesTest do
  # One test changes the working directory of the VM, so the module does not
  # run with other modules.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.MediaFiles
  alias Expresso.Presenter.Schema.Check

  doctest MediaFiles

  @moduletag :tmp_dir

  @clip "test/fixtures/clip.webm"
  @chime "test/fixtures/chime.wav"
  @poster "test/fixtures/dot.png"

  defp video(options \\ []),
    do: Builder.video(@clip, [title: "A clip", poster: @poster] ++ options)

  defp audio(options \\ []), do: Builder.audio(@chime, [title: "A chime"] ++ options)

  defp image(options \\ []), do: Builder.image(@poster, [alt: "A dot"] ++ options)

  defp deck(elements, options \\ []),
    do: Builder.deck([Builder.slide("one", elements: elements)], [name: "deck"] ++ options)

  # The document of a deck and the copies of its render, with the directory
  # `talk_files`.
  defp render(elements, options \\ []) do
    {html, files} =
      MediaFiles.collect("talk_files", fn -> Expresso.Deck.render(deck(elements, options)) end)

    {LazyHTML.from_document(html), html, files}
  end

  defp clip_name, do: MediaFiles.name(@clip, File.read!(@clip))
  defp chime_name, do: MediaFiles.name(@chime, File.read!(@chime))
  defp dot_name, do: MediaFiles.name(@poster, File.read!(@poster))

  # The `src` attribute of each image of the present view.
  defp sources(document),
    do: document |> LazyHTML.query(".screen .image img") |> LazyHTML.attribute("src")

  describe "collect/2 and put/3" do
    test "put/3 returns the address of the copy, and collect/2 returns the copy" do
      {address, files} =
        MediaFiles.collect("talk_files", fn ->
          MediaFiles.put("clips/run.webm", "abc", "video")
        end)

      assert address == "talk_files/run-ba7816bf.webm"
      assert files == [{"talk_files/run-ba7816bf.webm", "abc"}]
    end

    test "the same file two times gives one copy" do
      {addresses, files} =
        MediaFiles.collect("talk_files", fn ->
          for _each <- 1..2, do: MediaFiles.put("run.webm", "abc", "video")
        end)

      assert Enum.uniq(addresses) == ["talk_files/run-ba7816bf.webm"]
      assert [{"talk_files/run-ba7816bf.webm", "abc"}] = files
    end

    test "a file with a different content gets a different name" do
      {_result, files} =
        MediaFiles.collect("talk_files", fn ->
          MediaFiles.put("run.webm", "abc", "video")
          MediaFiles.put("run.webm", "abd", "video")
        end)

      assert Enum.map(files, &elem(&1, 0)) ==
               ["talk_files/run-ba7816bf.webm", "talk_files/run-a52d159f.webm"]
    end

    test "the address has a percent sign for a space in the name of the directory" do
      {address, [{path, "abc"}]} =
        MediaFiles.collect("my talk_files", fn -> MediaFiles.put("run.webm", "abc", "video") end)

      assert address == "my%20talk_files/run-ba7816bf.webm"
      assert path == "my talk_files/run-ba7816bf.webm"
    end

    test "put/3 raises with no directory, and the error names the option" do
      message = MediaFiles.no_directory("run.webm", "video")

      assert_raise ArgumentError, message, fn ->
        MediaFiles.collect(nil, fn -> MediaFiles.put("run.webm", "abc", "video") end)
      end

      assert_raise ArgumentError, message, fn -> MediaFiles.put("run.webm", "abc", "video") end
      assert message =~ "external true"
    end

    test "collect/2 gives a render in a render its own copies" do
      {inner, outer} =
        MediaFiles.collect("outer_files", fn ->
          MediaFiles.put("a.webm", "abc", "video")
          {_result, inner} = MediaFiles.collect("inner_files", fn -> :ok end)
          MediaFiles.put("b.webm", "abd", "video")
          inner
        end)

      assert inner == []

      assert Enum.map(outer, &elem(&1, 0)) ==
               ["outer_files/a-ba7816bf.webm", "outer_files/b-a52d159f.webm"]
    end

    test "collect/2 keeps no copy after an exception" do
      assert_raise RuntimeError, fn ->
        MediaFiles.collect("talk_files", fn -> raise "stop" end)
      end

      assert_raise ArgumentError, fn -> MediaFiles.put("run.webm", "abc", "video") end
    end
  end

  describe "write/2" do
    test "writes each copy into the directory of the document", %{tmp_dir: dir} do
      files = [{"talk_files/run-ba7816bf.webm", "abc"}, {"talk_files/bell-a52d159f.wav", "abd"}]

      assert MediaFiles.write(files, Path.join(dir, "talk.html")) == :ok
      assert File.read!(Path.join(dir, "talk_files/run-ba7816bf.webm")) == "abc"
      assert File.read!(Path.join(dir, "talk_files/bell-a52d159f.wav")) == "abd"
    end

    test "does not write a copy that is already there", %{tmp_dir: dir} do
      path = Path.join(dir, "talk_files/run-ba7816bf.webm")
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "abc")
      File.touch!(path, {{2020, 1, 1}, {0, 0, 0}})
      before = File.stat!(path).mtime

      assert MediaFiles.write([{"talk_files/run-ba7816bf.webm", "abc"}], Path.join(dir, "t.html")) ==
               :ok

      assert File.stat!(path).mtime == before
    end

    test "writes nothing with no document, and for no copy", %{tmp_dir: dir} do
      assert MediaFiles.write([{"talk_files/run.webm", "abc"}], nil) == :ok
      assert MediaFiles.write([], Path.join(dir, "talk.html")) == :ok
      assert File.ls!(dir) == []
    end

    test "returns an error for a directory that it cannot make", %{tmp_dir: dir} do
      # A file has the name of the directory of the copies.
      File.write!(Path.join(dir, "talk_files"), "")

      assert {:error, message} =
               MediaFiles.write([{"talk_files/run.webm", "abc"}], Path.join(dir, "talk.html"))

      assert message =~ "Couldn't write the file"
      assert message =~ "talk_files/run.webm"
    end
  end

  describe "a video with external true" do
    test "the list of the videos holds the address of the copy, and no data URI" do
      {document, html, files} = render([video(external: true)])
      address = "talk_files/" <> clip_name()

      assert script_json(document, "videos") == [address]
      assert Check.check([address], :written_videos) == :ok
      refute html =~ "data:video/"
      assert files == [{address, File.read!(@clip)}]
    end

    test "the poster stays a data URI in the document" do
      {document, _html, _files} = render([video(external: true)])

      assert ["data:image/png;base64," <> _data | _rest] =
               document |> LazyHTML.query("img.embed-fallback") |> LazyHTML.attribute("src")
    end

    test "two elements with the same file share one copy and one number" do
      {document, _html, files} =
        render([video(external: true), video(external: true, loop: false)])

      assert length(script_json(document, "videos")) == 1
      assert length(files) == 1

      assert document
             |> LazyHTML.query(".screen video.video-frame")
             |> LazyHTML.attribute("data-video") == ["0", "0"]
    end

    test "an element with the option and one with no option have a source each" do
      {document, _html, files} = render([video(), video(external: true)])

      assert ["data:video/webm;base64," <> _data, address] = script_json(document, "videos")
      assert address == "talk_files/" <> clip_name()
      assert length(files) == 1

      assert document
             |> LazyHTML.query(".screen video.video-frame")
             |> LazyHTML.attribute("data-video") == ["0", "1"]
    end

    test "a deck with no such element has no copy" do
      assert {_document, _html, []} = render([video()])
    end

    test "the render raises with no directory, and the error names the file and the option" do
      assert_raise ArgumentError, ~r/the video "#{@clip}" has external true/, fn ->
        Expresso.Deck.render(deck([video(external: true)]))
      end
    end

    test "a file that the render cannot read still stops the render with its path" do
      missing = Builder.video("no/such.webm", title: "None", poster: @poster, external: true)

      assert_raise ArgumentError, ~r|cannot read the video "no/such.webm"|, fn ->
        MediaFiles.collect("talk_files", fn -> Expresso.Deck.render(deck([missing])) end)
      end
    end

    test "the render reads the file through Expresso.DeckFile, so the watch mode sees it" do
      {_result, paths} =
        Expresso.DeckFile.track(fn ->
          MediaFiles.collect("talk_files", fn ->
            Expresso.Deck.render(deck([video(external: true)]))
          end)
        end)

      assert @clip in paths
    end

    test "the DSL takes the option" do
      defmodule ExternalDeck do
        use Expresso

        name "external"

        slide "one" do
          video "test/fixtures/clip.webm" do
            title "A clip"
            poster "test/fixtures/dot.png"
            external true
          end

          audio "test/fixtures/chime.wav" do
            title "A chime"
            external true
          end
        end
      end

      {html, files} =
        MediaFiles.collect("d_files", fn -> Expresso.Deck.render(Expresso.parse(ExternalDeck)) end)

      assert Enum.map(files, &elem(&1, 0)) == [
               "d_files/" <> clip_name(),
               "d_files/" <> chime_name()
             ]

      refute html =~ "data:video/"
      refute html =~ "data:audio/"
    end
  end

  describe "an image with external true" do
    test "each img element holds the address of the copy, and the document holds no data URI" do
      {document, html, files} = render([image(external: true)])
      address = "talk_files/" <> dot_name()

      assert sources(document) == [address]
      # The present view, the handout view and the menu show the image.
      sources = document |> LazyHTML.query(".image img") |> LazyHTML.attribute("src")
      assert length(sources) >= 3
      assert Enum.uniq(sources) == [address]
      refute html =~ "data:image/png"
      assert files == [{address, File.read!(@poster)}]
    end

    test "each img element of the image has loading=lazy, and an image in a data URI has none" do
      {document, html, _files} = render([image(external: true), image(alt: "B")])

      # The present view, the handout view and the menu show each image.
      lazy =
        document |> LazyHTML.query(~s(.image img[loading="lazy"])) |> LazyHTML.attribute("src")

      assert length(lazy) >= 3
      assert Enum.uniq(lazy) == ["talk_files/" <> dot_name()]

      inline =
        document |> LazyHTML.query(".image img:not([loading])") |> LazyHTML.attribute("src")

      assert length(inline) >= 3
      assert Enum.all?(inline, &String.starts_with?(&1, "data:image/png;base64,"))

      # `Expresso.Export.eager/1` finds the attribute at the start of the tag.
      assert html =~ ~s(<img loading="lazy" src="talk_files/#{dot_name()}")
    end

    test "an image with the goto option has loading=lazy in its link" do
      {document, _html, _files} = render([image(external: true, goto: [slide: 1])])

      assert document
             |> LazyHTML.query(~s(.screen .image a.goto img[loading="lazy"]))
             |> Enum.count() ==
               1
    end

    test "two elements with the same file share one copy" do
      {document, _html, files} = render([image(external: true), image(external: true, alt: "B")])

      assert sources(document) == List.duplicate("talk_files/" <> dot_name(), 2)
      assert length(files) == 1
    end

    test "an element with the option and one with no option have a source each" do
      {document, _html, files} = render([image(), image(external: true)])

      assert ["data:image/png;base64," <> _data, address] = sources(document)
      assert address == "talk_files/" <> dot_name()
      assert length(files) == 1
    end

    test "the render raises with no directory, and the error names the file and the option" do
      assert_raise ArgumentError, ~r/the image "#{@poster}" has external true/, fn ->
        Expresso.Deck.render(deck([image(external: true)]))
      end
    end

    test "a file that the render cannot read, or of a type that it does not know, stops the render" do
      for {path, message} <- [
            {"no/such.png", ~r|no/such.png|},
            {"test/fixtures/dot.txt", ~r/is not an image of a type that Expresso knows/}
          ] do
        assert_raise ArgumentError, message, fn ->
          render([Builder.image(path, alt: "None", external: true)])
        end
      end
    end

    test "the render reads the file through Expresso.DeckFile, so the watch mode sees it" do
      {_result, paths} = Expresso.DeckFile.track(fn -> render([image(external: true)]) end)

      assert @poster in paths
    end
  end

  describe "the external option of the deck" do
    test "each image, video and audio element with no option keeps its file next to the document" do
      {document, html, files} = render([image(), video(), audio()], external: true)

      assert sources(document) == ["talk_files/" <> dot_name()]
      assert script_json(document, "videos") == ["talk_files/" <> clip_name()]
      assert script_json(document, "audios") == ["talk_files/" <> chime_name()]
      refute html =~ "data:video/"
      refute html =~ "data:audio/"

      assert Enum.map(files, &elem(&1, 0)) |> Enum.sort() ==
               Enum.sort(
                 for name <- [dot_name(), clip_name(), chime_name()], do: "talk_files/" <> name
               )
    end

    test "the poster of a video stays a data URI" do
      {document, _html, _files} = render([video()], external: true)

      assert ["data:image/png;base64," <> _data | _rest] =
               document |> LazyHTML.query("img.embed-fallback") |> LazyHTML.attribute("src")
    end

    test "each image with no option has loading=lazy, and an image with external false has none" do
      {document, _html, _files} =
        render([image(), image(external: false, alt: "B")], external: true)

      assert document
             |> LazyHTML.query(~s(.screen .image img[loading="lazy"]))
             |> LazyHTML.attribute("alt") ==
               ["A dot"]

      assert document
             |> LazyHTML.query(".screen .image img:not([loading])")
             |> LazyHTML.attribute("alt") ==
               ["B"]
    end

    test "an element with external false keeps its file in the document" do
      {document, _html, files} =
        render([image(external: false), video(external: false), audio()], external: true)

      assert ["data:image/png;base64," <> _data] = sources(document)
      assert ["data:video/webm;base64," <> _data] = script_json(document, "videos")
      assert Enum.map(files, &elem(&1, 0)) == ["talk_files/" <> chime_name()]
    end

    test "a deck with external false, or with no option, keeps each file in the document" do
      for options <- [[], [external: false]] do
        assert {_document, _html, []} = render([image(), video(), audio()], options)
      end
    end

    test "the render raises with no directory, and the error names the first file" do
      assert_raise ArgumentError, ~r/has external true/, fn ->
        Expresso.Deck.render(deck([image()], external: true))
      end
    end

    test "the DSL takes the option of the deck and the option of an image" do
      defmodule ExternalDefaultDeck do
        use Expresso

        name "external"
        external true

        slide "one" do
          image "test/fixtures/dot.png", alt: "A dot"

          image "test/fixtures/halves.png" do
            alt "Two halves"
            external false
          end
        end
      end

      {html, files} =
        MediaFiles.collect("d_files", fn ->
          Expresso.Deck.render(Expresso.parse(ExternalDefaultDeck))
        end)

      assert Enum.map(files, &elem(&1, 0)) == ["d_files/" <> dot_name()]
      assert html =~ ~s(src="d_files/#{dot_name()}")
      assert html =~ "data:image/png"
    end
  end

  describe "an audio with external true" do
    test "the list of the sounds holds the address of the copy, and no data URI" do
      {document, html, files} = render([audio(external: true)])
      address = "talk_files/" <> chime_name()

      assert script_json(document, "audios") == [address]
      assert Check.check([address], :written_audios) == :ok
      refute html =~ "data:audio/"
      assert files == [{address, File.read!(@chime)}]
    end

    test "the schema refuses an address of a different host, and a path from the root" do
      for {list, form} <- [
            {["https://example.com/chime.wav"], :written_audios},
            {["/talk_files/chime.wav"], :written_audios},
            {["https://example.com/run.webm"], :written_videos},
            {["talk_files/run.txt"], :written_videos}
          ] do
        assert {:error, _message} = Check.check(list, form), inspect(list)
      end
    end
  end

  describe "Expresso.main/2" do
    defp script(path) do
      File.write!(path, """
      import Expresso.Builder

      deck(
        [
          slide("one",
            elements: [
              video(#{inspect(Path.expand(@clip))},
                title: "A clip",
                poster: #{inspect(Path.expand(@poster))},
                external: true
              )
            ]
          )
        ],
        name: "deck"
      )
      """)

      path
    end

    test "writes each copy into a directory next to the output file", %{tmp_dir: dir} do
      input = script(Path.join(dir, "deck.exs"))
      output = Path.join(dir, "my talk.html")

      assert Expresso.main(input, output) == :ok

      assert File.ls!(Path.join(dir, "my talk_files")) == [clip_name()]
      assert File.read!(Path.join([dir, "my talk_files", clip_name()])) == File.read!(@clip)

      document = output |> File.read!() |> LazyHTML.from_document()
      assert script_json(document, "videos") == ["my%20talk_files/" <> clip_name()]
    end

    test "raises for the standard output, and writes no document", %{tmp_dir: dir} do
      input = script(Path.join(dir, "deck.exs"))

      for output <- [nil, "-"] do
        text =
          capture_io(fn ->
            assert_raise ArgumentError, ~r/has external true/, fn ->
              Expresso.main(input, output)
            end
          end)

        assert text == ""
      end

      assert File.ls!(dir) == ["deck.exs"]
    end

    test "a deck with no such element makes no directory", %{tmp_dir: dir} do
      input = Path.join(dir, "plain.exs")
      File.write!(input, ~s|import Expresso.Builder\ndeck([slide("one", [])], name: "d")\n|)

      assert Expresso.main(input, Path.join(dir, "plain.html")) == :ok
      assert Enum.sort(File.ls!(dir)) == ["plain.exs", "plain.html"]
    end
  end
end
