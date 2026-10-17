defmodule Expresso.Element.VideoTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Video
  alias Expresso.Presenter.Schema.Check

  doctest Video

  defmodule VideoDeck do
    use Expresso

    slide "one" do
      video "test/fixtures/clip.webm" do
        title "A clip"
        poster "test/fixtures/dot.png"
        width "60%"
        aspect "4/3"
      end
    end

    slide "two" do
      columns do
        column do
          video "test/fixtures/clip.webm" do
            title "The same clip"
            poster "test/fixtures/dot.png"
            loop false
            controls true
          end
        end
      end
    end
  end

  defp deck, do: Expresso.parse(VideoDeck)
  defp document, do: deck() |> document()

  describe "the document" do
    test "writes no source on a video, and each video names its file" do
      document = document()
      videos = count(document, "video.video-frame")

      assert videos > 0
      assert count(document, "video.video-frame:not([src])") == videos

      assert document
             |> LazyHTML.query("video.video-frame")
             |> LazyHTML.attribute("data-video")
             |> Enum.uniq() == ["0"]
    end

    test "writes each file one time, as a data URI that the schema takes" do
      list = script_json(document(), "videos")

      assert [uri] = list
      assert "data:video/webm;base64," <> data = uri
      assert Base.decode64!(data) == File.read!("test/fixtures/clip.webm")
      assert Check.check(list, :written_videos) == :ok
    end

    test "writes a muted video with no sound, and the poster under it with the title" do
      [first | _copies] = document() |> LazyHTML.query(".video") |> Enum.to_list()
      [video] = first |> LazyHTML.query("video") |> Enum.to_list()

      assert LazyHTML.attribute(video, "muted") == ["muted"]
      assert LazyHTML.attribute(video, "playsinline") == ["playsinline"]
      assert LazyHTML.attribute(video, "loop") == ["loop"]
      assert LazyHTML.attribute(video, "aria-label") == ["A clip"]
      assert LazyHTML.attribute(video, "tabindex") == ["-1"]

      assert [poster] = first |> LazyHTML.query("img.embed-fallback") |> Enum.to_list()
      assert LazyHTML.attribute(poster, "alt") == ["A clip"]
      assert ["data:image/png;base64," <> _data] = LazyHTML.attribute(poster, "src")
      assert LazyHTML.attribute(first, "style") == ["--embed-width: 60vw; --embed-aspect: 4/3"]
    end

    test "gives the controls and no loop to a video with those options" do
      [video | _copies] = document() |> LazyHTML.query("#slide-2 video") |> Enum.to_list()

      assert LazyHTML.attribute(video, "controls") == ["controls"]
      assert LazyHTML.attribute(video, "loop") == []
      assert LazyHTML.attribute(video, "tabindex") == []
    end

    test "a deck with no video gets no list of videos" do
      html = [Builder.slide("one")] |> Builder.deck() |> Expresso.Deck.render()

      assert html |> LazyHTML.from_document() |> count("body:not(:has(script#expresso-videos))") ==
               1
    end

    test "raises for a file that it cannot read" do
      assert_raise ArgumentError, ~r/cannot read the video "no\/such.webm"/, fn ->
        [
          Builder.slide("one",
            elements: [Builder.video("no/such.webm", title: "x", poster: "test/fixtures/dot.png")]
          )
        ]
        |> Builder.deck()
        |> Expresso.Deck.render()
      end
    end

    test "records the file for the watch mode" do
      deck = deck()
      {_html, paths} = Expresso.DeckFile.track(fn -> Expresso.Deck.render(deck) end)

      assert "test/fixtures/clip.webm" in paths
    end
  end

  defmodule RootDeck do
    use Expresso

    root Path.expand("../fixtures", __DIR__)

    slide "one" do
      video "clip.webm" do
        title "A clip"
        poster "dot.png"
      end
    end
  end

  test "the root option of the deck gives the directory of the file and of the poster" do
    document = document(RootDeck)

    assert [_uri] = script_json(document, "videos")
  end

  describe "number/1" do
    test "gives each file a number in document order, and the same file the same number" do
      slides =
        for {src, number} <- Enum.with_index(["a.webm", "b.mp4", "a.webm"], 1) do
          Builder.slide("#{number}",
            elements: [Builder.video(src, title: "x", poster: "test/fixtures/dot.png")]
          )
        end

      videos =
        %Expresso.Deck{slides: slides}
        |> Video.number()
        |> Map.get(:slides)
        |> Enum.flat_map(& &1.elements)

      assert Enum.map(videos, & &1.index) == [0, 1, 0]
    end
  end

  describe "the options" do
    test "source/1 takes a .webm or a .mp4 file, and refuses each other value" do
      assert Video.source("clips/DEMO.MP4") == {:ok, "clips/DEMO.MP4"}

      for value <- [
            "clip.mov",
            "clip.gif",
            "https://example.com/clip.webm",
            "c:/clip.webm",
            :clip
          ] do
        assert {:error, _message} = Video.source(value), inspect(value)
      end
    end

    # A compile that fails leaves the state of Spark in the process, so each
    # test compiles one module only.
    test "the compiler needs a title" do
      assert compile_error("NoTitle", ~s(poster "test/fixtures/dot.png")) =~ "title"
    end

    test "the compiler needs a poster" do
      assert compile_error("NoPoster", ~s(title "x")) =~ "poster"
    end
  end

  defp compile_error(name, body) do
    source = """
    defmodule Expresso.Element.VideoTest.#{name} do
      use Expresso

      slide "one" do
        video "test/fixtures/clip.webm" do
          #{body}
        end
      end
    end
    """

    error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end
    Exception.message(error)
  end
end
