defmodule Expresso.DevDependencyTest do
  use ExUnit.Case, async: false

  # A project of a user that takes Expresso as a dev dependency, as
  # `docs/how-to/render-a-deck-in-your-project.md` tells. The test makes the
  # project, fetches the dependencies, and runs `mix expresso` there. It takes
  # the repository from its path, so it tests the code of the working tree, and
  # it needs the network for the dependencies of Expresso.
  # `mix test --only dependency` runs it.
  #
  # The project is in `_build/dependency_project`, and the test keeps it. The
  # next run then compiles only the files that changed, and the cache of the
  # workflow keeps the directory with `_build`. The project gets the lockfile of
  # Expresso, so its dependencies have the versions of Expresso.
  @moduletag :dependency
  @moduletag timeout: :timer.minutes(15)

  @root Path.expand("../..", __DIR__)
  @project Path.join([@root, "_build", "dependency_project"])

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

  setup do
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
        [{:expresso, path: #{inspect(@root)}, only: :dev, runtime: false}]
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
    text = html |> Floki.parse_document!() |> Floki.find(".screen .code") |> Floki.text()

    assert text =~ "def start, do: :ok"
  end
end
