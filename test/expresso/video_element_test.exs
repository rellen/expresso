defmodule Expresso.Element.VideoTest do
  use ExUnit.Case, async: true

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
  defp document, do: deck() |> Expresso.Deck.render() |> Floki.parse_document!()

  defp json(document),
    do: document |> Floki.find("script#expresso-videos") |> Floki.text(js: true) |> JSON.decode!()

  describe "the document" do
    test "writes no source on a video, and each video names its file" do
      videos = Floki.find(document(), "video.video-frame")

      assert videos != []
      assert Enum.flat_map(videos, &Floki.attribute(&1, "src")) == []
      assert videos |> Enum.flat_map(&Floki.attribute(&1, "data-video")) |> Enum.uniq() == ["0"]
    end

    test "writes each file one time, as a data URI that the schema takes" do
      list = json(document())

      assert [uri] = list
      assert "data:video/webm;base64," <> data = uri
      assert Base.decode64!(data) == File.read!("test/fixtures/clip.webm")
      assert Check.check(list, :written_videos) == :ok
    end

    test "writes a muted video with no sound, and the poster under it with the title" do
      [first | _copies] = Floki.find(document(), ".video")
      [video] = Floki.find(first, "video")

      assert Floki.attribute(video, "muted") == ["muted"]
      assert Floki.attribute(video, "playsinline") == ["playsinline"]
      assert Floki.attribute(video, "loop") == ["loop"]
      assert Floki.attribute(video, "aria-label") == ["A clip"]
      assert Floki.attribute(video, "tabindex") == ["-1"]

      assert [poster] = Floki.find(first, "img.embed-fallback")
      assert Floki.attribute(poster, "alt") == ["A clip"]
      assert ["data:image/png;base64," <> _data] = Floki.attribute(poster, "src")
      assert Floki.attribute(first, "style") == ["--embed-width: 60vw; --embed-aspect: 4/3"]
    end

    test "gives the controls and no loop to a video with those options" do
      [video | _copies] = Floki.find(document(), "#slide-2 video")

      assert Floki.attribute(video, "controls") == ["controls"]
      assert Floki.attribute(video, "loop") == []
      assert Floki.attribute(video, "tabindex") == []
    end

    test "a deck with no video gets no list of videos" do
      html = [Builder.slide("one")] |> Builder.deck() |> Expresso.Deck.render()

      assert html |> Floki.parse_document!() |> Floki.find("script#expresso-videos") == []
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
    document = RootDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

    assert [_uri] = json(document)
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
