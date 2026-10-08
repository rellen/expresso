defmodule Expresso.Element.Video do
  @moduledoc """
  An element that plays a video file in a slide

  The `video` entity takes the path of a WebM or an MP4 file as its first
  argument, relative to the working directory of the command or to the `root`
  option of the deck. The `title` option names the video for a screen reader,
  and the `poster` option gives the path of an image. Both are required. The
  poster shows on paper, in the handout view, in the speaker view, in the
  overview, in the menu and while the video loads.

  The document holds a copy of each slide for the present view and one for
  each page of the handout view. A video in each copy would make the document
  many times larger, so no copy holds the video. The `video` element holds
  only `data-video`, the number of the element in the deck, and the renderer
  writes each video one time, as a data URI, into the element
  `expresso-videos`. The presenter gives a video its source when it plays.

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
  def source(value) when is_binary(value) do
    if Map.has_key?(@types, extension(value)) and not String.contains?(value, ":"),
      do: {:ok, value},
      else: {:error, @source_error}
  end

  def source(_value), do: {:error, @source_error}

  defp extension(path), do: path |> Path.extname() |> String.downcase()

  @doc """
  Give each video of a deck its number

  Each file gets a number in document order, from 0, and two elements with
  the same file get the same number. `sources/1` writes the file at that
  position, so the document holds each file one time. The render function
  writes the number into `data-video`. `Expresso.Renderer` calls this
  function before the render.
  """
  @spec number(Expresso.Deck.t()) :: Expresso.Deck.t()
  def number(%Expresso.Deck{slides: slides} = deck) do
    {slides, _files} =
      Enum.map_reduce(slides, %{}, fn slide, files ->
        {elements, files} = number_all(slide.elements || [], files)
        {%{slide | elements: elements}, files}
      end)

    %Expresso.Deck{deck | slides: slides}
  end

  defp number_all(elements, files) do
    Enum.map_reduce(elements, files, fn
      %__MODULE__{src: src} = video, files ->
        files = Map.put_new(files, src, map_size(files))
        {%__MODULE__{video | index: files[src]}, files}

      %{elements: children} = element, files when is_list(children) ->
        {children, files} = number_all(children, files)
        {%{element | elements: children}, files}

      element, files ->
        {element, files}
    end)
  end

  @doc """
  Return the data URI of each file of the videos of a deck, in the order of
  their numbers

  The function reads each file through `Expresso.DeckFile`, so the watch mode
  renders the deck again after a change to the file. It raises for a file
  that it cannot read.
  """
  @spec sources(Expresso.Deck.t()) :: [String.t()]
  def sources(%Expresso.Deck{slides: slides}) do
    slides
    |> Enum.flat_map(&videos(&1.elements || []))
    |> Enum.uniq_by(& &1.index)
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&data_uri/1)
  end

  defp videos(elements) do
    Enum.flat_map(elements, fn
      %__MODULE__{} = video -> [video]
      %{elements: children} when is_list(children) -> videos(children)
      _element -> []
    end)
  end

  defp data_uri(%__MODULE__{src: src}) do
    case Expresso.DeckFile.read(src) do
      {:ok, bytes} ->
        "data:#{Map.fetch!(@types, extension(src))};base64," <> Base.encode64(bytes)

      {:error, reason} ->
        raise ArgumentError,
              "cannot read the video \"#{src}\": #{:file.format_error(reason)}. " <>
                "A path is relative to the working directory of the command, or to the " <>
                "root option of the deck."
    end
  end

  @doc """
  Write the videos of a deck as JSON, or return `nil`

  The value is a list with the data URI of each video, in the order of their
  numbers. The renderer writes it into a `script` element. A data URI holds
  no `<`, and the function escapes each `<` as for the list of the steps. A
  deck with no video gets `nil`, and the document then holds no such element.
  """
  @spec json(Expresso.Deck.t()) :: String.t() | nil
  def json(deck) do
    case sources(deck) do
      [] -> nil
      sources -> sources |> JSON.encode!() |> String.replace("<", "\\u003c")
    end
  end

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
