defmodule Expresso.PrivateDir do
  @moduledoc """
  Makes a new private directory in the temporary directory of the system

  The watch mode and the browser levels of `--check` write a copy of the deck
  into such a directory. Many computers have one `/tmp` for all the users, so
  each directory obeys these rules:

    * The name is `expresso-<kind>-<random>`, and `<random>` has 26 random
      characters.
    * `File.mkdir/1` makes the directory, so a directory or a symbolic link
      that is already there is an error. The function then tries a different
      name.
    * The mode of the directory is 0700, so no other user can read or write
      its files.

  `open!/1` also starts a small `sh` process that removes the directory when
  the process that owns it stops, and when the VM stops. Ctrl-C and SIGTERM
  halt the VM before an `after` block can run, but the operating system then
  closes the pipe to the `sh` process, and that process removes the
  directory. `close/1` removes the directory at once.
  """

  @enforce_keys [:path]
  defstruct [:path, :guard]

  @typedoc "A private directory, and the process that removes it"
  @type t :: %__MODULE__{path: Path.t(), guard: port() | nil}

  # The number of names to try before the function raises.
  @attempts 10

  # The script of the `sh` process. It ignores the signals of the terminal, so
  # Ctrl-C does not stop it before the VM. `read` returns when the VM closes
  # the pipe, and the script then removes the directory.
  @script ~S"""
  trap '' INT TERM HUP
  read -r _line
  rm -rf -- "$1" 2>/dev/null
  """

  @doc """
  Make a new private directory, and remove it when the calling process stops

  The function raises when it cannot make the directory.
  """
  @spec open!(String.t()) :: t()
  def open!(kind) do
    path = create!(kind, System.tmp_dir!())
    %__MODULE__{path: path, guard: guard(path)}
  end

  @doc """
  Remove the directory, and stop its `sh` process
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{path: path, guard: guard}) do
    remove(path)
    stop_guard(guard)
  end

  # The `sh` process can stop first, for example after a SIGKILL. A closed port
  # then raises `ArgumentError`, and the function ignores it.
  defp stop_guard(nil), do: :ok

  defp stop_guard(guard) do
    Process.unlink(guard)
    Port.close(guard)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Make a new directory with the mode 0700 in `parent`, and return its path

  `random` returns the random part of each name that the function tries. The
  tests give a different function.
  """
  @spec create!(String.t(), Path.t(), (-> String.t())) :: Path.t()
  def create!(kind, parent, random \\ &random/0), do: create!(kind, parent, random, @attempts)

  defp create!(kind, parent, _random, 0) do
    path = name(parent, kind, "*")
    raise File.Error, reason: :eexist, action: "make directory", path: path
  end

  defp create!(kind, parent, random, attempts) do
    path = name(parent, kind, random.())

    case make(path) do
      :ok ->
        path

      {:error, :eexist} ->
        create!(kind, parent, random, attempts - 1)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "make directory", path: path
    end
  end

  defp name(parent, kind, random), do: Path.join(parent, "expresso-#{kind}-#{random}")

  # The directory is new, because `File.mkdir/1` does not accept a path that is
  # already there. No file goes into it before the mode is 0700.
  # sobelow_skip ["Traversal.FileModule"]
  defp make(path) do
    with :ok <- File.mkdir(path) do
      case File.chmod(path, 0o700) do
        :ok ->
          :ok

        {:error, reason} ->
          File.rmdir(path)
          {:error, reason}
      end
    end
  end

  # The name only has to be hard to guess. `File.mkdir/1` and the mode 0700
  # keep the directory private, so `:rand` is sufficient, and the release
  # needs no `crypto` application.
  defp random, do: 16 |> :rand.bytes() |> Base.encode32(case: :lower, padding: false)

  # The path comes from `create!/3`.
  # sobelow_skip ["Traversal.FileModule"]
  defp remove(path) do
    File.rm_rf(path)
    :ok
  end

  # A system with no `sh` gets no process. The directory then stays after a
  # halt of the VM.
  defp guard(path) do
    case System.find_executable("sh") do
      nil -> nil
      sh -> Port.open({:spawn_executable, sh}, [:binary, args: ["-c", @script, "sh", path]])
    end
  end
end
