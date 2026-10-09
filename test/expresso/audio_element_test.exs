defmodule Expresso.Element.AudioTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Audio
  alias Expresso.Presenter.Schema.Check

  doctest Audio
  doctest Expresso.Media

  defmodule AudioDeck do
    use Expresso

    slide "one" do
      audio "test/fixtures/chime.wav" do
        title "A chime"
      end
    end

    slide "two" do
      steps 2

      columns do
        column do
          audio "test/fixtures/chime.wav" do
            at from: 2
            title "The same chime"
            loop true
            controls true
          end
        end
      end
    end
  end

  defp document,
    do: AudioDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

  defp json(document),
    do: document |> Floki.find("script#expresso-audios") |> Floki.text(js: true) |> JSON.decode!()

  test "writes no source on a sound, and each sound names its file" do
    sounds = Floki.find(document(), "audio")

    assert sounds != []
    assert Enum.flat_map(sounds, &Floki.attribute(&1, "src")) == []
    assert sounds |> Enum.flat_map(&Floki.attribute(&1, "data-audio")) |> Enum.uniq() == ["0"]
  end

  test "writes each file one time, as a data URI that the schema takes" do
    list = json(document())

    assert [uri] = list
    assert "data:audio/wav;base64," <> data = uri
    assert Base.decode64!(data) == File.read!("test/fixtures/chime.wav")
    assert Check.check(list, :written_audios) == :ok
  end

  test "a sound without options has no controls, no loop and no tab stop, and a caption with its title" do
    [first | _copies] = Floki.find(document(), "#slide-1 figure.audio")
    [sound] = Floki.find(first, "audio")

    assert Floki.attribute(sound, "aria-label") == ["A chime"]
    assert Floki.attribute(sound, "preload") == ["none"]
    assert Floki.attribute(sound, "controls") == []
    assert Floki.attribute(sound, "loop") == []
    assert Floki.attribute(sound, "muted") == []
    assert Floki.attribute(sound, "tabindex") == ["-1"]
    assert first |> Floki.find("figcaption") |> Floki.text() == "♪ A chime"
  end

  test "gives the controls, the loop and the overlay to a sound with those options" do
    [figure | _copies] = Floki.find(document(), "#slide-2 figure.audio")
    [sound] = Floki.find(figure, "audio")

    assert Floki.attribute(sound, "controls") == ["controls"]
    assert Floki.attribute(sound, "loop") == ["loop"]
    assert Floki.attribute(sound, "tabindex") == []
    assert Floki.attribute(figure, "data-on") == ["2"]
  end

  test "a deck with no sound has no list of sounds" do
    deck = Builder.deck([Builder.slide("s")], name: "quiet")

    assert Audio.json(deck) == nil

    assert deck
           |> Expresso.Deck.render()
           |> Floki.parse_document!()
           |> Floki.find("#expresso-audios") == []
  end

  test "the compiler refuses a file that is not a sound of the list, and an address" do
    assert_raise ArgumentError, ~r/\.mp3/, fn -> Builder.audio("bell.flac", title: "x") end

    assert_raise ArgumentError, ~r/\.mp3/, fn ->
      Builder.audio("https://x/bell.mp3", title: "x")
    end
  end

  test "the render names the sound of a file that it cannot read" do
    deck =
      Builder.deck([Builder.slide("s", elements: [Builder.audio("missing.ogg", title: "x")])])

    assert_raise ArgumentError, ~r/cannot read the sound "missing.ogg"/, fn ->
      Expresso.Deck.render(deck)
    end
  end
end
