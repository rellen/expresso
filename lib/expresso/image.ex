defmodule Expresso.Image do
  @moduledoc """
  The data URI of an image file

  The document of a deck is one file, so an image cannot be a second file. This
  module reads an image at render time and makes a data URI from the bytes.
  The `img` element of `Expresso.Element.Image` then holds the image.

  `media_type/1` gives the media type of a path, and `data_uri/1` gives the
  full URI. The extension of the path gives the media type.
  """

  @media_types %{
    ".avif" => "image/avif",
    ".gif" => "image/gif",
    ".jpeg" => "image/jpeg",
    ".jpg" => "image/jpeg",
    ".png" => "image/png",
    ".svg" => "image/svg+xml",
    ".webp" => "image/webp"
  }

  @extensions @media_types |> Map.keys() |> Enum.sort() |> Enum.join(", ")

  @doc """
  Give the media type of an image path

  The function reads the extension of the path, and it does not read the file.
  An extension that this module does not know gives an error tuple with the
  list of the extensions.
  """
  @spec media_type(Path.t()) :: {:ok, String.t()} | {:error, String.t()}
  def media_type(path) do
    extension = path |> Path.extname() |> String.downcase()

    case Map.fetch(@media_types, extension) do
      {:ok, media_type} ->
        {:ok, media_type}

      :error ->
        {:error,
         "#{inspect(path)} is not an image of a type that Expresso knows: " <>
           "expected one of #{@extensions}"}
    end
  end

  @doc """
  Make the data URI of an image path

  The path is relative to the working directory of the command. The function
  reads the file, and it gives an error tuple for a file that it cannot read.
  """
  @spec data_uri(Path.t()) :: {:ok, String.t()} | {:error, String.t()}
  def data_uri(path) do
    with {:ok, media_type} <- media_type(path),
         {:ok, bytes} <- read(path) do
      {:ok, "data:#{media_type};base64,#{Base.encode64(bytes)}"}
    end
  end

  @doc """
  Make the data URI of an image path, or raise

  `Expresso.Element.Image` calls this function, because a render function has
  no way to report an error tuple.
  """
  @spec data_uri!(Path.t()) :: String.t()
  def data_uri!(path) do
    case data_uri(path) do
      {:ok, uri} -> uri
      {:error, message} -> raise ArgumentError, message
    end
  end

  # The path comes from the deck, and the person who runs the command wrote the
  # deck. `Expresso.main/2` already evaluates that deck with `Code.eval_file/1`,
  # so the deck has the rights of that person. A path of the deck is not the
  # input of a different user, and the traversal of a directory is the behavior
  # that the author asks for.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:error,
         "Expresso cannot read the image #{inspect(path)}: #{:file.format_error(reason)}. " <>
           "A path is relative to the working directory of the command."}
    end
  end
end
