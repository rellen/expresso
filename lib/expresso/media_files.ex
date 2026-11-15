defmodule Expresso.MediaFiles do
  @moduledoc """
  The files of a deck that the render keeps next to the document

  An `image`, a `video` or an `audio` element with `external true` does not go
  into the document as a data URI. The render makes a copy of its file for a directory
  next to the document, such as `talk_files/` for `talk.html`, and the
  document holds the relative address of the copy. The browser then gets the
  file only when its slide plays, and it can keep the file in its cache.
  `docs/external-media.md` gives the design.

  The picture of the `card` option of the deck is such a file too, because
  the tag `og:image` holds an address. `Expresso.LinkPreview` gives the rules.

  The name of a copy holds the first eight digits of the SHA-256 of its
  content, such as `run-3f2a1c9e.webm`. A changed file thus gets a new name,
  and two elements with the same file get the same copy.

  The code that renders a deck calls `collect/2` with the name of the
  directory. That function returns each copy that the render made, and
  `write/2` then writes them next to a document. `collect/2` keeps the copies
  in the process dictionary, as `Expresso.DeckFile.track/1` keeps its paths.
  Two renders in two processes therefore keep their copies apart.

  A render with no directory has no place for a copy: the standard output,
  and `Expresso.Deck.render/1` with no `collect/2`. `put/3` then raises an
  error that names the `external` option.
  """

  @key {__MODULE__, :files}

  @typedoc """
  A copy: its path relative to the directory of the document, and its bytes
  """
  @type file :: {Path.t(), binary()}

  # The number of digits of the hash in the name of a copy.
  @digits 8

  @doc """
  Return the name of the directory of the copies for a document or an input
  file

  The name is the name of the file with no extension, and `_files`. A render
  with an output file takes the name of that file. A render with no output
  file, such as the watch mode, takes the name of the input file. The
  standard input has no name, so it gives `deck_files`.

      iex> Expresso.MediaFiles.directory("out/talk.html")
      "talk_files"
      iex> Expresso.MediaFiles.directory("talk.exs")
      "talk_files"
      iex> Expresso.MediaFiles.directory("-")
      "deck_files"
  """
  @spec directory(Path.t()) :: String.t()
  def directory("-"), do: "deck_files"
  def directory(path), do: Path.basename(path, Path.extname(path)) <> "_files"

  @doc """
  Run a render, and return its result with each copy that the render made

  `directory` is the name of the directory of the copies, from `directory/1`,
  or `nil` for a render with no directory. The copies are in the order of
  their first use, and each copy is in the list one time. An exception, an
  exit or a throw goes on to the caller.
  """
  @spec collect(String.t() | nil, (-> result)) :: {result, [file()]} when result: var
  def collect(directory, function) do
    previous = Process.put(@key, {directory, []})

    try do
      result = function.()
      {_directory, files} = Process.get(@key)
      {result, files |> Enum.reverse() |> Enum.uniq_by(&elem(&1, 0))}
    after
      if previous == nil, do: Process.delete(@key), else: Process.put(@key, previous)
    end
  end

  @doc """
  Keep a copy of a file of a deck, and return its address relative to the
  document

  `src` is the path of the file in the deck, and `bytes` is its content. The
  `noun` names the file in the error, such as `"video"`. The address has a
  percent sign for each character that an address does not take, such as a
  space in the name of the directory.

  The function raises when the render has no directory for the copies. The
  `option` names the option that asks for the copy in the error: `:external`
  for an element with `external true`, or `:card` for the `card` option of
  the deck.
  """
  @spec put(Path.t(), binary(), String.t(), :external | :card) :: String.t()
  def put(src, bytes, noun, option \\ :external) do
    case Process.get(@key) do
      {directory, files} when is_binary(directory) ->
        name = name(src, bytes)
        Process.put(@key, {directory, [{Path.join(directory, name), bytes} | files]})
        URI.encode(directory, &URI.char_unreserved?/1) <> "/" <> name

      _no_directory ->
        raise ArgumentError, no_directory(src, noun, option)
    end
  end

  @doc """
  Return the name of the copy of a file: the name of the file, the first
  eight digits of the SHA-256 of its content, and its extension in lower case

  Each character of the name that is not a letter of ASCII, a digit, `.`, `_`
  or `-` becomes `-`, so the name needs no percent sign in an address.

      iex> Expresso.MediaFiles.name("clips/My Run.WEBM", "abc")
      "My-Run-ba7816bf.webm"
  """
  @spec name(Path.t(), binary()) :: String.t()
  def name(src, bytes) do
    extension = Expresso.Media.extension(src)
    base = src |> Path.basename(Path.extname(src)) |> String.replace(~r/[^A-Za-z0-9._-]/, "-")
    hash = :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)
    "#{base}-#{binary_part(hash, 0, @digits)}#{extension}"
  end

  @doc """
  Return the message for a file with `external true` in a render with no
  directory

      iex> Expresso.MediaFiles.no_directory("run.webm", "video")
      ~s(the video "run.webm" has external true, so the render must write a copy of the file ) <>
        "next to the document. This render has no output file, so it has no directory for " <>
        "the copy. Give an output file, or remove the external option."
  """
  @spec no_directory(Path.t(), String.t(), :external | :card) :: String.t()
  def no_directory(src, noun, option \\ :external)

  def no_directory(src, noun, :external) do
    "the #{noun} \"#{src}\" has external true, so the render must write a copy of the file " <>
      "next to the document. This render has no output file, so it has no directory for " <>
      "the copy. Give an output file, or remove the external option."
  end

  def no_directory(src, noun, :card) do
    "the #{noun} \"#{src}\" needs an address, so the render must write a copy of the file " <>
      "next to the document. This render has no output file, so it has no directory for " <>
      "the copy. Give an output file, or remove the card option."
  end

  @doc """
  Write each copy next to a document

  `document` is the path of the document, and each copy goes to its path in
  the directory of that document. The function makes the directory of the
  copies. A copy that is already there with the same name has the same
  content, so the function does not write it again. With `nil` as the
  document, the function writes nothing.
  """
  @spec write([file()], Path.t() | nil) :: :ok | {:error, String.t()}
  def write(_files, nil), do: :ok

  def write(files, document) do
    root = Path.dirname(document)

    Enum.reduce_while(files, :ok, fn {relative, bytes}, :ok ->
      case write_one(Path.join(root, relative), bytes) do
        :ok -> {:cont, :ok}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  # The user who runs the command gives the path of the document, and the
  # name of a copy comes from `name/2`.
  # sobelow_skip ["Traversal.FileModule"]
  defp write_one(path, bytes) do
    with false <- File.regular?(path),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, bytes) do
      :ok
    else
      true ->
        :ok

      {:error, reason} ->
        {:error, "Couldn't write the file #{path}: #{:file.format_error(reason)}"}
    end
  end
end
