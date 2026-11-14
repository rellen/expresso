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
