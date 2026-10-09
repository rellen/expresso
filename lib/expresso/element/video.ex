defmodule Expresso.Element.Video do
  @moduledoc """
  An element that plays a video file in a slide

  The `video` entity takes the path of a WebM or an MP4 file as its first
  argument, relative to the working directory of the command or to the `root`
  option of the deck. The `title` option names the video for a screen reader,
  and the `poster` option gives the path of an image. Both are required. The
  poster shows on paper, in the handout view, in the speaker view, in the
  overview, in the menu and while the video loads.

  The `video` element holds only `data-video`, the number of the element in
  the deck, and the renderer writes each video one time, as a data URI, into
  the element `expresso-videos`. `Expresso.Media` gives the reasons. The
  presenter gives a video its source when it plays.

  The video plays in the present view only, while its slide shows and the
  element shows at the current step. Thus `at` gives the step where it
  starts. A black screen, the menu and the overview pause it. A video starts
  again from the start when its slide shows again. It has no sound, because a
  browser starts a video with sound only after a click. With
  `controls true`, the video shows the controls of the browser, and the
  presenter can turn the sound on. `docs/reference/video-element.md` gives
  the rules.
  """

  use Expresso.Element

  @typedoc "The struct of a video element"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :src,
    :title,
    :poster,
    :width,
    :aspect,
    :index,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    loop: true,
    controls: false,
    on: [],
    __spark_metadata__: nil
  ]

  # The media type of each extension of a video file.
  @types %{".webm" => "video/webm", ".mp4" => "video/mp4"}

  @source_error "a video takes the path of a .webm or a .mp4 file"

  @doc """
  Make sure that the source of a video is the path of a WebM or an MP4 file

  This function is the custom type of the first argument. It does not read
  the file, so a missing file gives an error at render time, as for an image.

      iex> Expresso.Element.Video.source("demo/demo.webm")
      {:ok, "demo/demo.webm"}

      iex> {:error, _message} = Expresso.Element.Video.source("demo/demo.mov")
  """
  @spec source(term()) :: {:ok, String.t()} | {:error, String.t()}
  def source(value), do: Expresso.Media.source(value, @types, @source_error)

  @doc """
  Give each video of a deck its number

  `Expresso.Renderer` calls this function before the render, and the render
  function writes the number into `data-video`. `Expresso.Media.number/2`
  gives the rules.
  """
  @spec number(Expresso.Deck.t()) :: Expresso.Deck.t()
  def number(deck), do: Expresso.Media.number(deck, __MODULE__)

  @doc """
  Return the data URI of each file of the videos of a deck, in the order of
  their numbers

  It raises for a file that it cannot read. `Expresso.Media.sources/4` gives
  the rules.
  """
  @spec sources(Expresso.Deck.t()) :: [String.t()]
  def sources(deck), do: Expresso.Media.sources(deck, __MODULE__, @types, "video")

  @doc """
  Write the videos of a deck as JSON, or return `nil`

  The value is a list with the data URI of each video, in the order of their
  numbers. A deck with no video gets `nil`, and the document then holds no
  element `expresso-videos`.
  """
  @spec json(Expresso.Deck.t()) :: String.t() | nil
  def json(deck), do: deck |> sources() |> Expresso.Media.json()

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, and the
  `style` attribute of the `width` and `aspect` options. The key `poster`
  holds the data URI of the poster.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(video) do
    %__MODULE__{title: title, width: width, aspect: aspect} = video

    style =
      [
        width && "--embed-width: #{Expresso.Element.Image.viewport_unit(width)}",
        aspect && "--embed-aspect: #{aspect}"
      ]
      |> Enum.reject(&is_nil/1)

    %{
      title: title,
      index: video.index,
      loop: video.loop,
      controls: video.controls,
      poster: Expresso.Image.data_uri!(video.poster),
      overlay:
        Expresso.Overlay.Render.attributes(video) ++
          if(style == [], do: [], else: [{"style", Enum.join(style, "; ")}])
    }
  end

  @doc """
  Make the HTML of a video

  The element has the box of an embed: the poster, and the `video` element on
  it. The `video` element has no source, and the presenter gives it one. It
  has no sound, and it plays inline on a phone. A video with no controls gets
  `tabindex="-1"`, so the key Tab does not go into it.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("embed video", assigns[:class]), rest!: @overlay do
        div class: "embed-box" do
          img class: "embed-fallback", src: @poster, alt: @title

          video class: "embed-frame video-frame",
                aria_label: @title,
                data_video: @index,
                data_interactive: @controls,
                muted: true,
                playsinline: true,
                preload: "none",
                loop: @loop,
                controls: @controls,
                tabindex: if(@controls, do: nil, else: "-1") do
          end
        end
      end
    end
  end
end
