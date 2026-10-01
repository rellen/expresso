defmodule Expresso.GifTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.Gif
  alias Expresso.Test.{GifDecoder, PngWriter}

  @fixtures "test/fixtures/gif/overlay-at"

  # A frame of RGB bytes, with a PNG image that has a random filter on each row.
  defp frame(rgb, width, height, delay, filters \\ []) do
    %{png: PngWriter.png(rgb, width, height, filters), delay: delay}
  end

  defp rgb(colors), do: IO.iodata_to_binary(for {r, g, b} <- colors, do: <<r, g, b>>)

  defp psnr(a, b) do
    squares =
      Enum.zip_with(:binary.bin_to_list(a), :binary.bin_to_list(b), &((&1 - &2) * (&1 - &2)))

    case Enum.sum(squares) / byte_size(a) do
      +0.0 -> :infinity
      mse -> 10 * :math.log10(255 * 255 / mse)
    end
  end

  # A palette of 1 to 255 colors, a size, and 1 to 4 frames. A frame can be
  # the same as the frame before it, or change some pixels of it.
  defp frames do
    gen all palette <-
              uniq_list_of(tuple({byte(), byte(), byte()}), min_length: 1, max_length: 255),
            width <- integer(1..12),
            height <- integer(1..12),
            first <- list_of(member_of(palette), length: width * height),
            changes <- list_of(change(palette, width * height), max_length: 3),
            delays <- list_of(map(integer(0..200), &(&1 * 10)), length: length(changes) + 1),
            filters <-
              list_of(list_of(integer(0..4), length: height), length: length(changes) + 1) do
      pixels =
        Enum.scan(changes, first, fn change, pixels ->
          Enum.reduce(change, pixels, fn {i, color}, pixels ->
            List.replace_at(pixels, i, color)
          end)
        end)

      {width, height, Enum.zip([[first | pixels], delays, filters])}
    end
  end

  defp change(palette, count),
    do: list_of(tuple({integer(0..(count - 1)), member_of(palette)}), max_length: count)

  property "a GIF of frames with 255 colors or fewer holds the exact frames and delays" do
    check all {width, height, frames} <- frames(), max_runs: 50 do
      input =
        for {pixels, delay, filters} <- frames,
            do: frame(rgb(pixels), width, height, delay, filters)

      {:ok, gif} = Gif.encode(input)
      decoded = GifDecoder.decode(gif)

      # Frames that are the same as the frame before them add their delays to that frame.
      expected =
        frames
        |> Enum.chunk_by(&elem(&1, 0))
        |> Enum.map(fn chunk ->
          {rgb(chunk |> hd() |> elem(0)), chunk |> Enum.map(&elem(&1, 1)) |> Enum.sum()}
        end)

      assert {decoded.width, decoded.height, decoded.loop} == {width, height, 0}
      assert Enum.map(decoded.frames, &{&1.rgb, &1.delay}) == expected
    end
  end

  test "a later frame holds only the rectangle of the pixels that change" do
    black = :binary.copy(<<0, 0, 0>>, 64)

    changed =
      :binary.copy(<<0, 0, 0>>, 8 * 2 + 3) <>
        <<255, 0, 0>> <> :binary.copy(<<0, 0, 0>>, 64 - 8 * 2 - 4)

    {:ok, gif} = Gif.encode([frame(black, 8, 8, 100), frame(changed, 8, 8, 100)])

    assert [%{rect: {0, 0, 8, 8}}, %{rect: {3, 2, 1, 1}, rgb: ^changed}] =
             GifDecoder.decode(gif).frames
  end

  test "a first frame with 256 colors keeps each color" do
    pixels = for i <- 0..255, do: {i, 255 - i, rem(i * 7, 256)}
    {:ok, gif} = Gif.encode([frame(rgb(pixels), 16, 16, 500)])

    assert [%{rgb: rgb}] = GifDecoder.decode(gif).frames
    assert rgb == rgb(pixels)
  end

  test "a frame with more than 4096 codes of LZW stays exact" do
    palette = for i <- 0..254, do: {i, rem(i * 3, 256), rem(i * 11, 256)}
    pixels = for i <- 1..(100 * 100), do: Enum.at(palette, rem(i * i + 7 * i, 255))

    {:ok, gif} = Gif.encode([frame(rgb(pixels), 100, 100, 40)])

    assert [%{rgb: rgb}] = GifDecoder.decode(gif).frames
    assert rgb == rgb(pixels)
  end

  test "a frame with more than 256 colors gets a palette near to its colors" do
    pixels = for y <- 0..63, x <- 0..63, do: {x * 4, y * 4, 128}
    {:ok, gif} = Gif.encode([frame(rgb(pixels), 64, 64, 40)])

    assert [%{rgb: rgb}] = GifDecoder.decode(gif).frames
    assert psnr(rgb, rgb(pixels)) > 35
  end

  test "recorded frames of a deck keep their delays and nearly each pixel" do
    pngs = for name <- ~w[000 008 018], do: File.read!(Path.join(@fixtures, "#{name}.png"))
    {:ok, gif} = Gif.encode(Enum.zip_with(pngs, [1200, 40, 1600], &%{png: &1, delay: &2}))
    decoded = GifDecoder.decode(gif)

    assert {decoded.width, decoded.height} == {800, 450}
    assert Enum.map(decoded.frames, & &1.delay) == [1200, 40, 1600]
    assert [{0, 0, 800, 450} | later] = Enum.map(decoded.frames, & &1.rect)
    assert Enum.all?(later, fn {_x, _y, w, h} -> w * h < 800 * 450 end)

    for {png, frame} <- Enum.zip(pngs, decoded.frames) do
      {:ok, {800, 450, rows}} = Gif.Png.inflate(png)
      assert psnr(frame.rgb, Gif.Nif.unfilter(rows, 800, 450)) > 55
    end
  end

  describe "an error" do
    test "for data that is not a PNG image" do
      assert Gif.encode([%{png: "GIF89a", delay: 40}]) == {:error, "not a PNG image"}
    end

    test "for a PNG image that is not 8-bit RGB" do
      <<head::binary-8, 13::32, "IHDR", w::32, h::32, 8, 2, rest::binary>> =
        PngWriter.png(<<0, 0, 0>>, 1, 1)

      rgba = <<head::binary, 13::32, "IHDR", w::32, h::32, 8, 6, rest::binary>>

      assert Gif.encode([%{png: rgba, delay: 40}]) ==
               {:error, "the PNG image is not 8-bit RGB with no interlace"}
    end

    test "for a PNG image with damaged data" do
      png = PngWriter.png(:binary.copy(<<1, 2, 3>>, 16), 4, 4)
      damaged = :binary.replace(png, "IDAT", "IDAT" <> <<0xFF>>)

      assert {:error, "the PNG image is damaged"} = Gif.encode([%{png: damaged, delay: 40}])
    end

    test "for frames of different sizes" do
      frames = [frame(<<0, 0, 0>>, 1, 1, 40), frame(<<0, 0, 0, 0, 0, 0>>, 2, 1, 40)]

      assert Gif.encode(frames) == {:error, "the frames have different sizes"}
    end
  end
end
