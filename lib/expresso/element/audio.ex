defmodule Expresso.Element.Audio do
  @moduledoc """
  An element that plays a sound file in a slide

  The `audio` entity takes the path of an MP3, an M4A, an Ogg or a WAV file
  as its first argument, relative to the working directory of the command or
  to the `root` option of the deck. The `title` option names the sound for a
  screen reader, and the handout view and paper show it with a note symbol.

  The `audio` element holds only `data-audio`, the number of the element in
  the deck, and the renderer writes each file one time, as a data URI, into
  the element `expresso-audios`. `Expresso.Media` gives the reasons.

  The sound plays in the present view only, with the rules of a video: while
  its slide shows and the element shows at the current step. A black screen,
  the menu and the overview pause it, and it starts again from the start when
  its slide shows again. A browser plays sound only after the first key or
  click in the document, so a sound of the first slide starts at the first
  key. Without `controls`, the present view shows nothing in the place of
  the element. `docs/reference/audio-element.md` gives the rules.
  """

  use Expresso.Element

  @typedoc "The struct of an audio element"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :src,
    :title,
    :index,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    loop: false,
    controls: false,
    on: [],
    __spark_metadata__: nil
  ]

  # The media type of each extension of a sound file.
  @types %{
    ".mp3" => "audio/mpeg",
    ".m4a" => "audio/mp4",
    ".ogg" => "audio/ogg",
    ".oga" => "audio/ogg",
    ".wav" => "audio/wav"
  }

  @source_error "an audio element takes the path of a .mp3, .m4a, .ogg, .oga or .wav file"

  @doc """
  Make sure that the source of a sound is the path of an MP3, an M4A, an Ogg
  or a WAV file

  This function is the custom type of the first argument. It does not read
  the file, so a missing file gives an error at render time.

      iex> Expresso.Element.Audio.source("sounds/bell.mp3")
      {:ok, "sounds/bell.mp3"}

      iex> {:error, _message} = Expresso.Element.Audio.source("sounds/bell.flac")
  """
  @spec source(term()) :: {:ok, String.t()} | {:error, String.t()}
  def source(value), do: Expresso.Media.source(value, @types, @source_error)

  @doc """
  Give each sound of a deck its number

  `Expresso.Renderer` calls this function before the render, and the render
  function writes the number into `data-audio`.
  """
  @spec number(Expresso.Deck.t()) :: Expresso.Deck.t()
  def number(deck), do: Expresso.Media.number(deck, __MODULE__)

  @doc """
  Return the data URI of each file of the sounds of a deck, in the order of
  their numbers
  """
  @spec sources(Expresso.Deck.t()) :: [String.t()]
  def sources(deck), do: Expresso.Media.sources(deck, __MODULE__, @types, "sound")

  @doc """
  Write the sounds of a deck as JSON, or return `nil` for a deck with none
  """
  @spec json(Expresso.Deck.t()) :: String.t() | nil
  def json(deck), do: deck |> sources() |> Expresso.Media.json()

  @doc """
  Make the assigns of the render function from the struct
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(audio) do
    %{
      title: audio.title,
      index: audio.index,
      loop: audio.loop,
      controls: audio.controls,
      overlay: Expresso.Overlay.Render.attributes(audio)
    }
  end

  @doc """
  Make the HTML of a sound

  The `audio` element has no source, and the presenter gives it one. An
  element with no controls gets `tabindex="-1"`, so the key Tab does not go
  into it. The caption shows the title with a note symbol in the handout
  view and on paper, and the style sheet hides it in the present view.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      figure class: Expresso.Element.classes("audio", assigns[:class]), rest!: @overlay do
        audio aria_label: @title,
              data_audio: @index,
              data_interactive: @controls,
              preload: "none",
              loop: @loop,
              controls: @controls,
              tabindex: if(@controls, do: nil, else: "-1") do
        end

        figcaption do
          div do
            "♪ #{@title}"
          end
        end
      end
    end
  end
end
