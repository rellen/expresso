defmodule Expresso.Release.MDExLibraryTest do
  use ExUnit.Case, async: true

  alias Expresso.Release.MDExLibrary

  doctest MDExLibrary

  @strings <<0, "libgcc_s.so.1", 0, "libc.so", 0>>

  # A small ELF file for 64 bits: the header, the string table, the dynamic
  # section, then the header of each of the three sections. `entries` gives
  # the dynamic section as a list of `{tag, value}`.
  defp elf(entries) do
    dynamic =
      for {tag, value} <- entries ++ [{0, 0}],
          into: <<>>,
          do: <<tag::little-64, value::little-64>>

    strings_at = 64
    dynamic_at = strings_at + byte_size(@strings)
    table_at = dynamic_at + byte_size(dynamic)

    header =
      <<0x7F, "ELF", 2, 1, 1, 0::72, 3::little-16, 62::little-16, 1::little-32, 0::64, 0::64,
        table_at::little-64, 0::32, 64::little-16, 0::16, 0::16, 64::little-16, 3::little-16,
        1::little-16>>

    header <>
      @strings <>
      dynamic <>
      section(0, 0, 0, 0) <>
      section(3, strings_at, byte_size(@strings), 0) <>
      section(6, dynamic_at, byte_size(dynamic), 1)
  end

  defp section(type, offset, size, link) do
    <<0::32, type::little-32, 0::64, 0::64, offset::little-64, size::little-64, link::little-32,
      0::32, 0::64, 0::64>>
  end

  describe "patch/1" do
    test "gives the library the name of the unwinder and a run path of its directory" do
      library = elf([{1, 1}, {1, 15}, {12, 4096}])

      assert MDExLibrary.patch(library) ==
               library
               |> String.replace("libgcc_s.so.1", "expresso.so.1")
               |> String.replace("libc.so", "$ORIGIN")
               |> String.replace(
                 <<1::little-64, 15::little-64>>,
                 <<29::little-64, 15::little-64>>
               )
    end

    test "keeps the size of the library" do
      library = elf([{1, 15}, {1, 1}])
      assert byte_size(MDExLibrary.patch(library)) == byte_size(library)
    end

    test "raises for a library that needs a different set of libraries" do
      assert_raise RuntimeError, ~r/NEEDED entries are \["libgcc_s.so.1"\]/, fn ->
        MDExLibrary.patch(elf([{1, 1}]))
      end
    end

    test "raises for a library that has a run path" do
      assert_raise RuntimeError, ~r/can not make it load/, fn ->
        MDExLibrary.patch(elf([{1, 1}, {1, 15}, {29, 15}]))
      end
    end

    test "raises for a file that is not an ELF file for 64 bits" do
      assert_raise RuntimeError, ~r/not an ELF file/, fn ->
        MDExLibrary.patch(<<0xCF, 0xFA, 0xED, 0xFE, 0::64>>)
      end
    end
  end

  describe "triple/1" do
    test "gives the library of macOS to a target for macOS" do
      target = %Burrito.Builder.Target{
        alias: :macos_arm,
        os: :darwin,
        cpu: :aarch64,
        cross_build: true,
        debug?: false,
        erts_source: nil,
        qualifiers: []
      }

      assert MDExLibrary.triple(target) == "aarch64-apple-darwin"
    end

    test "raises for a target with no library" do
      target = %Burrito.Builder.Target{
        alias: :windows,
        os: :windows,
        cpu: :x86_64,
        cross_build: true,
        debug?: false,
        erts_source: nil,
        qualifiers: []
      }

      assert_raise RuntimeError, ~r/no library of MDEx for a binary for windows/, fn ->
        MDExLibrary.triple(target)
      end
    end
  end

  describe "archive/2" do
    test "raises for a library with a name that is not known" do
      assert_raise RuntimeError, ~r/name that is not known/, fn ->
        MDExLibrary.archive("libother.so", "x86_64-apple-darwin")
      end
    end
  end
end
