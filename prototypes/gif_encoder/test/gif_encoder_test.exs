defmodule GifEncoderTest do
  use ExUnit.Case, async: true

  alias GifEncoder.{Container, Frames, Quality}
  alias Vix.Vips.Image

  doctest GifEncoder.Container

  @frames Frames.read("test/fixtures")
  @duration @frames |> Enum.map(& &1.delay) |> Enum.sum()

  for encoder <- GifEncoder.encoders() do
    name = encoder |> Module.split() |> List.last()
    tags = for tag <- [:ffmpeg, :gifski], name =~ ~r/#{tag}/i, do: {tag, true}

    describe "#{name}" do
      @describetag tags
      @encoder encoder

      test "makes a GIF of the frames that libvips decodes" do
        assert {:ok, gif} = GifEncoder.encode(@frames, encoder: @encoder)
        assert <<"GIF89a", 800::little-16, 450::little-16, _rest::binary>> = gif

        {:ok, image} = Image.new_from_buffer(gif, n: -1)
        assert Image.width(image) == 800
        assert Image.header_value(image, "loop") == {:ok, 0}
      end

      test "keeps the time of the animation, and the frames are close to the source" do
        {:ok, gif} = GifEncoder.encode(@frames, encoder: @encoder)
        {:ok, %{psnr: psnr, duration: duration}} = Quality.psnr(@frames, gif)

        assert_in_delta duration, @duration, 20
        assert Enum.min(psnr) > 30
      end

      test "returns an error for an image that is not a PNG" do
        assert {:error, _reason} =
                 GifEncoder.encode([%{png: "not an image", delay: 40}], encoder: @encoder)
      end
    end
  end

  describe "GifEncoder.Elixir.lzw/2" do
    test "gives the indices back through a GIF decoder, past the reset of the table" do
      :rand.seed(:exsss, {1, 2, 3})
      width = 400
      height = 300
      indices = for _ <- 1..(width * height), into: <<>>, do: <<:rand.uniform(256) - 1>>
      palette = for i <- 0..255, into: <<>>, do: <<i, i, i>>

      gif =
        Container.gif([
          %{
            width: width,
            height: height,
            palette: palette,
            code_size: 8,
            lzw: GifEncoder.Elixir.lzw(indices, 8),
            delay: 0
          }
        ])

      {:ok, image} = Image.new_from_buffer(gif)
      {:ok, gray} = Vix.Vips.Operation.extract_band(image, 0)
      {:ok, pixels} = Image.write_to_binary(gray)
      assert pixels == indices
    end
  end
end
