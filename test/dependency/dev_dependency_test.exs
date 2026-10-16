defmodule Expresso.DevDependencyTest do
  use ExUnit.Case, async: false

  # A project of a user that takes Expresso as a dev dependency, as
  # `docs/how-to/render-a-deck-in-your-project.md` tells. The test makes the
  # project, fetches the dependencies, and runs `mix expresso` there. It needs
  # the network for the dependencies of Expresso.
  # `mix test --only dependency` runs it.
  #
  # The project takes Expresso from a copy of the files that Git holds, in
  # `_build/dependency_source`. A dependency from GitHub has only these files, so
  # it has no presenter bundle and none of the files that a build of the working
  # tree makes. The copy holds the changes of the working tree, so the test
  # tests that code.
  #
  # The project is in `_build/dependency_project`, and the test keeps it and the
  # copy. The next run then compiles only the files that changed, and the cache
  # of the workflow keeps the directories with `_build`. The project gets the
  # lockfile of Expresso, so its dependencies have the versions of Expresso.
  @moduletag :dependency
  @moduletag timeout: :timer.minutes(15)

  @root Path.expand("../..", __DIR__)
  @project Path.join([@root, "_build", "dependency_project"])
  @source Path.join([@root, "_build", "dependency_source"])

  defp mix(project, args) do
    System.cmd("mix", args,
      cd: project,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}, {"MIX_DEPS_PATH", nil}, {"MIX_BUILD_PATH", nil}]
    )
  end

  # Write a file of the project when its text changed. A file with the same
  # text keeps its time, so Mix does not compile it again.
  defp write(project, path, text) do
    path = Path.join(project, path)
    File.mkdir_p!(Path.dirname(path))

    if File.read(path) != {:ok, text} do
      File.write!(path, text)
    end
  end

  # Copy each file that Git holds, and each new file that it does not ignore,
  # into the source. A file with the same text keeps its time. A file that the
  # working tree no longer has goes from the source, and so does the bundle that
  # the last run made, so each run makes the bundle as a dependency from GitHub
  # does.
  defp copy_source do
    File.rm_rf!(Path.join(@source, "priv/static"))

    {files, 0} =
      System.cmd("git", ~w(ls-files -z --cached --others --exclude-standard), cd: @root)

    files =
      files
      |> String.split("\0", trim: true)
      |> Enum.filter(&File.regular?(Path.join(@root, &1)))

    for file <- files, do: write(@source, file, File.read!(Path.join(@root, file)))

    kept = MapSet.new(files)

    for path <- Path.wildcard(Path.join(@source, "**"), match_dot: true),
        File.regular?(path),
        file = Path.relative_to(path, @source),
        not MapSet.member?(kept, file),
        do: File.rm!(path)
  end

  setup do
    copy_source()
    project = @project
    write(project, "mix.lock", File.read!(Path.join(@root, "mix.lock")))
    File.rm_rf!(Path.join(project, "talk/deck.html"))

    write(project, "mix.exs", """
    defmodule UserProject.MixProject do
      use Mix.Project

      def project do
        [app: :user_project, version: "0.1.0", deps: deps()]
      end

      defp deps do
        [{:expresso, path: #{inspect(@source)}, only: :dev, runtime: false}]
      end
    end
    """)

    write(project, "lib/server.ex", """
    defmodule UserProject.Server do
      def start, do: :ok
    end
    """)

    write(project, "talk/deck.exs", """
    defmodule UserProject.Talk do
      use Expresso

      root Path.expand("..", __DIR__)

      slide "the server" do
        code "elixir" do
          src "lib/server.ex"
          lines from: "def start"
        end
      end
    end
    """)

    %{project: project}
  end

  test "mix expresso renders a deck of the project with code of the project", %{project: project} do
    assert {_output, 0} = mix(project, ["deps.get"])

    assert {output, 0} = mix(project, ["expresso", "talk/deck.exs", "talk/deck.html"])
    refute output =~ "error"

    html = File.read!(Path.join(project, "talk/deck.html"))
    text = html |> LazyHTML.from_document() |> LazyHTML.query(".screen .code") |> LazyHTML.text()

    assert text =~ "def start, do: :ok"
  end
end
