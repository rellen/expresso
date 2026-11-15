defmodule Expresso.Release.MDExLibrary do
  @moduledoc """
  A step of Burrito that puts the library of MDEx for the target into the binary

  MDEx is a NIF in Rust. RustlerPrecompiled gets its library for the computer
  that compiles Expresso, and `MDExNative.Native` loads the library by the
  name of that file. A binary of Burrito runs on a different system:

  | Target | ERTS of the binary | Library of MDEx |
  | --- | --- | --- |
  | Linux | musl, which the binary carries | `*-unknown-linux-musl` |
  | macOS | macOS | `*-apple-darwin` |

  For each target, the step does these operations in the directory of the
  release:

  1. It gets the library for the target from the release of `mdex_native` on
     GitHub, or from the file cache of Burrito.
  2. It makes sure that the SHA-256 of the file is the one in the checksum
     file of `mdex_native`, which the Hex package holds.
  3. It writes the library with the name that `MDExNative.Native` loads.
  4. For Linux, it changes the library with `patch/1`, and it builds the
     unwinder `expresso.so.1` next to the library with `zig cc`.

  The library for musl needs `libgcc_s.so.1`, which unwinds the stack when
  Rust code panics. The launcher of Burrito puts the library directories of
  the host first in `LD_LIBRARY_PATH`, so the library gets the `libgcc_s.so.1`
  of glibc, which does not load in musl. The step therefore gives the library
  its own unwinder: the libunwind of LLVM, whose source Zig holds.

  The release of Expresso names the step in `mix.exs`. A release of your own
  that makes a Burrito binary with Expresso can name it in the same way:

      burrito: [
        targets: [linux_x86: [os: :linux, cpu: :x86_64]],
        extra_steps: [patch: [post: [Expresso.Release.MDExLibrary]]]
      ]

  `docs/development/release.md` gives the details.
  """

  @behaviour Burrito.Builder.Step

  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target
  alias Burrito.Util.FileCache

  @releases "https://github.com/leandrocp/mdex_native/releases/download"
  @checksums "checksum-Elixir.MDExNative.Native.exs"

  @gcc "libgcc_s.so.1"
  @libc "libc.so"
  @unwinder "expresso.so.1"
  @origin "$ORIGIN"

  @needed 1
  @rpath 15
  @runpath 29
  @dynamic 6

  @sources ~w(libunwind.cpp UnwindLevel1.c UnwindLevel1-gcc-ext.c
              UnwindRegistersRestore.S UnwindRegistersSave.S)

  # The path is the path of the library in the work directory of Burrito,
  # which `library/1` finds. It does not come from a user of the binary.
  # sobelow_skip ["Traversal.FileModule"]
  @impl Burrito.Builder.Step
  def execute(%Context{target: %Target{} = target, work_dir: work_dir} = context) do
    path = library(work_dir)
    file = archive(Path.basename(path), triple(target))
    Log.info(:step, "Putting the library of MDEx for the target into the release: #{file}")

    library = file |> fetch() |> extract()

    case target.os do
      :linux ->
        File.write!(path, patch(library))
        unwinder(target, Path.join(Path.dirname(path), @unwinder))

      :darwin ->
        File.write!(path, library)
    end

    context
  end

  @doc """
  The name of the library archive for a target, from the name of the library
  that the release holds

      iex> Expresso.Release.MDExLibrary.archive(
      ...>   "libmdex_native_nif-v0.3.1-nif-2.15-x86_64-unknown-linux-gnu.so",
      ...>   "aarch64-apple-darwin"
      ...> )
      "libmdex_native_nif-v0.3.1-nif-2.15-aarch64-apple-darwin.so.tar.gz"
  """
  @spec archive(String.t(), String.t()) :: String.t()
  def archive(name, triple) do
    case Regex.run(~r/^libmdex_native_nif-v\d+\.\d+\.\d+-nif-\d+\.\d+/, name) do
      [prefix] -> "#{prefix}-#{triple}.so.tar.gz"
      nil -> raise "The release holds a library of MDEx with a name that is not known: #{name}"
    end
  end

  @doc """
  The target of Rust for a target of Burrito

      iex> target = %Burrito.Builder.Target{
      ...>   alias: :linux_arm, os: :linux, cpu: :aarch64, cross_build: true,
      ...>   debug?: false, erts_source: nil, qualifiers: []
      ...> }
      iex> Expresso.Release.MDExLibrary.triple(target)
      "aarch64-unknown-linux-musl"
  """
  @spec triple(Target.t()) :: String.t()
  def triple(%Target{os: :linux, cpu: cpu}), do: "#{cpu}-unknown-linux-musl"
  def triple(%Target{os: :darwin, cpu: cpu}), do: "#{cpu}-apple-darwin"

  def triple(%Target{os: os}) do
    raise "Expresso has no library of MDEx for a binary for #{os}."
  end

  @doc """
  Change the library for musl so that it loads its unwinder from its directory

  The function changes two entries of the dynamic section, and each new text
  has the length of the text that it replaces, so no other byte moves:

  | Before | After |
  | --- | --- |
  | `NEEDED` `libgcc_s.so.1` | `NEEDED` `expresso.so.1` |
  | `NEEDED` `libc.so` | `RUNPATH` `$ORIGIN` |

  musl looks for a library in `LD_LIBRARY_PATH` first, so the unwinder has a
  name that no host has. musl is always present in the process, so the
  library does not need the entry for `libc.so`. The function raises for a
  library that does not have exactly these two `NEEDED` entries, or that has a
  run path.
  """
  @spec patch(binary()) :: binary()
  def patch(library) do
    {entries, strings} = dynamic(library)
    needed = for {@needed, _value, _at} = entry <- entries, do: entry
    names = needed |> Enum.map(fn {_tag, value, _at} -> text(library, strings + value) end)

    if Enum.sort(names) != [@libc, @gcc] or Enum.any?(entries, &run_path?/1) do
      raise "The library of MDEx for musl changed, and Expresso can not make it load: " <>
              "its NEEDED entries are #{inspect(names)}."
    end

    needed
    |> Enum.zip(names)
    |> Enum.reduce(library, fn
      {{_tag, value, _at}, @gcc}, acc ->
        put(acc, strings + value, @unwinder)

      {{_tag, value, at}, @libc}, acc ->
        acc |> put(strings + value, @origin) |> put(at, <<@runpath::little-64>>)
    end)
  end

  defp run_path?({tag, _value, _at}), do: tag in [@rpath, @runpath]

  # The entries of the dynamic section as `{tag, value, offset}`, and the
  # offset of its string table.
  defp dynamic(<<0x7F, "ELF", 2, 1, _rest::binary>> = library) do
    <<_head::binary-size(0x28), table::little-64, _flags::binary-size(10), size::little-16,
      count::little-16, _tail::binary>> = library

    fields = 44

    sections =
      for index <- 0..(count - 1)//1 do
        <<_name::32, type::little-32, _flags::64, _address::64, offset::little-64,
          length::little-64, link::little-32>> =
          binary_part(library, table + index * size, fields)

        %{type: type, offset: offset, length: length, link: link}
      end

    case Enum.find(sections, &(&1.type == @dynamic)) do
      nil -> raise "The library of MDEx has no dynamic section."
      section -> {entries(library, section), Enum.at(sections, section.link).offset}
    end
  end

  defp dynamic(_library) do
    raise "The library of MDEx for musl is not an ELF file for 64 bits with the little end first."
  end

  defp entries(library, section) do
    section.offset
    |> Stream.iterate(&(&1 + 16))
    |> Stream.take(div(section.length, 16))
    |> Stream.map(fn at ->
      <<tag::little-64, value::little-64>> = binary_part(library, at, 16)
      {tag, value, at}
    end)
    |> Enum.take_while(fn {tag, _value, _at} -> tag != 0 end)
  end

  defp text(library, at) do
    library |> binary_part(at, byte_size(library) - at) |> :binary.split(<<0>>) |> hd()
  end

  defp put(library, at, bytes) do
    size = byte_size(bytes)

    binary_part(library, 0, at) <>
      bytes <> binary_part(library, at + size, byte_size(library) - at - size)
  end

  # The directory `priv/native` of `mdex_native` in the release holds one
  # library: the one for the computer that compiled the release.
  defp library(work_dir) do
    case Path.wildcard(Path.join(work_dir, "lib/mdex_native-*/priv/native/*.so")) do
      [path] -> path
      found -> raise "The release must hold one library of MDEx. It holds #{inspect(found)}."
    end
  end

  defp fetch(file) do
    data =
      case FileCache.fetch(file) do
        {:hit, data} -> data
        _miss -> download(file)
      end

    sum = "sha256:" <> Base.encode16(:crypto.hash(:sha256, data), case: :lower)

    if checksums()[file] != sum do
      raise "The checksum of #{file} is not the checksum that mdex_native gives."
    end

    FileCache.put_if_not_exist(file, data)
    data
  end

  # The checksum file is Elixir source from the Hex package of `mdex_native`,
  # and the lockfile gives the checksum of that package. RustlerPrecompiled
  # reads the file in the same way.
  # sobelow_skip ["RCE.CodeModule"]
  defp checksums do
    {sums, _binding} =
      Mix.Project.deps_paths()
      |> Map.fetch!(:mdex_native)
      |> Path.join(@checksums)
      |> Code.eval_file()

    sums
  end

  defp download(file) do
    {:ok, _apps} = Application.ensure_all_started(:req)
    [_all, version] = Regex.run(~r/-v(\d+\.\d+\.\d+)-/, file)
    url = "#{@releases}/v#{version}/#{file}"
    Log.info(:step, "Downloading file: #{url}")

    case Req.get!(url, [raw: true] ++ proxy()) do
      %{status: 200, body: body} -> body
      %{status: status} -> raise "The download of #{url} gave the status #{status}."
    end
  end

  defp proxy do
    case Burrito.Util.get_proxy() do
      %{scheme: scheme, host: host, port: port} when scheme in ["http", "https"] ->
        [connect_options: [proxy: {String.to_existing_atom(scheme), host, port, []}]]

      _no_proxy ->
        []
    end
  end

  # `fetch/1` made sure of the checksum of the archive, so the archive is the
  # file that `mdex_native` published.
  # sobelow_skip ["DOS.Tar"]
  defp extract(archive) do
    {:ok, [{_name, library}]} = :erl_tar.extract({:binary, archive}, [:compressed, :memory])
    library
  end

  # Build the libunwind of LLVM as a shared library for musl. Zig holds the
  # source for its own use, and it links its copy with hidden symbols, so the
  # step compiles the source again with visible symbols. The command is the
  # `zig` of the path, and each argument comes from this module, from the
  # target or from `zig env`. No argument comes from a user of the binary.
  # sobelow_skip ["CI.System"]
  defp unwinder(%Target{cpu: cpu}, path) do
    zig = System.find_executable("zig") || raise "The step needs `zig` to build the unwinder."
    {env, 0} = System.cmd(zig, ["env"])
    [_all, lib] = Regex.run(~r/lib_dir"?\s*[=:]\s*"([^"]+)"/, env)
    source = Path.join(lib, "libunwind")

    arguments =
      ["cc", "-target", "#{cpu}-linux-musl", "-shared", "-O2", "-o", path] ++
        ["-I", Path.join(source, "include"), "-DNDEBUG", "-D_LIBUNWIND_IS_NATIVE_ONLY"] ++
        ["-funwind-tables", "-fno-exceptions", "-fno-rtti", "-nostdlib++", "-w"] ++
        ["-Wl,-soname,#{@unwinder}"] ++ Enum.map(@sources, &Path.join([source, "src", &1]))

    case System.cmd(zig, arguments, stderr_to_stdout: true) do
      {_output, 0} -> Log.success(:step, "Built the unwinder: #{path}")
      {output, status} -> raise "`zig cc` gave the status #{status} for the unwinder:\n#{output}"
    end
  end
end
