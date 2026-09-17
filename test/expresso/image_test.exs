defmodule Expresso.ImageTest do
  use ExUnit.Case, async: true

  alias Expresso.Image

  @png "test/fixtures/dot.png"

  describe "media_type/1" do
    test "reads the extension of the path" do
      assert Image.media_type("a/b/logo.png") == {:ok, "image/png"}
      assert Image.media_type("photo.jpeg") == {:ok, "image/jpeg"}
      assert Image.media_type("photo.jpg") == {:ok, "image/jpeg"}
      assert Image.media_type("drawing.svg") == {:ok, "image/svg+xml"}
    end

    test "accepts an extension in capital letters" do
      assert Image.media_type("LOGO.PNG") == {:ok, "image/png"}
    end

    test "gives an error with the list of the extensions" do
      assert {:error, message} = Image.media_type("notes.txt")
      assert message =~ ~s("notes.txt" is not an image of a type that Expresso knows)
      assert message =~ ".png"
      assert message =~ ".svg"
    end

    test "does not read the file" do
      assert Image.media_type("no/such/file.png") == {:ok, "image/png"}
    end
  end

  describe "data_uri/1" do
    test "gives the media type and the bytes of the file" do
      assert {:ok, uri} = Image.data_uri(@png)
      assert "data:image/png;base64," <> encoded = uri
      assert Base.decode64!(encoded) == File.read!(@png)
    end

    test "gives an error for a file that it cannot read" do
      assert {:error, message} = Image.data_uri("no/such/file.png")
      assert message =~ "Expresso cannot read the image"
      assert message =~ "working directory"
    end

    test "gives an error for a file of a different type" do
      assert {:error, message} = Image.data_uri("test/fixtures/dot.txt")
      assert message =~ "is not an image of a type that Expresso knows"
    end
  end

  describe "data_uri!/1" do
    test "gives the URI" do
      assert "data:image/png;base64," <> _ = Image.data_uri!(@png)
    end

    test "raises for a file that it cannot read" do
      assert_raise ArgumentError, ~r/cannot read the image/, fn ->
        Image.data_uri!("no/such/file.png")
      end
    end
  end
end
