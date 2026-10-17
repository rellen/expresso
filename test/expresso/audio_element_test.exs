defmodule Expresso.Element.AudioTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

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
    do: document(AudioDeck)

  test "writes no source on a sound, and each sound names its file" do
    document = document()
    sounds = count(document, "audio")

    assert sounds > 0
    assert count(document, "audio:not([src])") == sounds

    assert document |> LazyHTML.query("audio") |> LazyHTML.attribute("data-audio") |> Enum.uniq() ==
             ["0"]
  end

  test "writes each file one time, as a data URI that the schema takes" do
    list = script_json(document(), "audios")

    assert [uri] = list
    assert "data:audio/wav;base64," <> data = uri
    assert Base.decode64!(data) == File.read!("test/fixtures/chime.wav")
    assert Check.check(list, :written_audios) == :ok
  end

  test "a sound without options has no controls, no loop and no tab stop, and a caption with its title" do
    [first | _copies] = document() |> LazyHTML.query("#slide-1 figure.audio") |> Enum.to_list()
    [sound] = first |> LazyHTML.query("audio") |> Enum.to_list()

    assert LazyHTML.attribute(sound, "aria-label") == ["A chime"]
    assert LazyHTML.attribute(sound, "preload") == ["none"]
    assert LazyHTML.attribute(sound, "controls") == []
    assert LazyHTML.attribute(sound, "loop") == []
    assert LazyHTML.attribute(sound, "muted") == []
    assert LazyHTML.attribute(sound, "tabindex") == ["-1"]
    assert texts(first, "figcaption") == ["♪ A chime"]
  end

  test "gives the controls, the loop and the overlay to a sound with those options" do
    [figure | _copies] = document() |> LazyHTML.query("#slide-2 figure.audio") |> Enum.to_list()
    [sound] = figure |> LazyHTML.query("audio") |> Enum.to_list()

    assert LazyHTML.attribute(sound, "controls") == ["controls"]
    assert LazyHTML.attribute(sound, "loop") == ["loop"]
    assert LazyHTML.attribute(sound, "tabindex") == []
    assert LazyHTML.attribute(figure, "data-on") == ["2"]
  end

  test "a deck with no sound has no list of sounds" do
    deck = Builder.deck([Builder.slide("s")], name: "quiet")

    assert Audio.json(deck) == nil

    document = document(deck)

    assert count(document, "body:not(:has(#expresso-audios))") == 1
  end

  test "the compiler refuses a file that is not a sound of the list, and an address" do
    assert_raise ArgumentError, ~r/\.mp3/, fn -> Builder.audio("bell.flac", title: "x") end

    assert_raise ArgumentError, ~r/\.mp3/, fn ->
      Builder.audio("https://x/bell.mp3", title: "x")
    end
  end

  test "the render names the sound of a file that it cannot read" do
    deck =
      one_slide(Builder.audio("missing.ogg", title: "x"))

    assert_raise ArgumentError, ~r/cannot read the sound "missing.ogg"/, fn ->
      Expresso.Deck.render(deck)
    end
  end
end
