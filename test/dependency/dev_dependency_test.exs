defmodule Expresso.DevDependencyTest do
  use ExUnit.Case, async: false

  # A project of a user that takes Expresso as a dev dependency, as
  # `docs/how-to/render-a-deck-in-your-project.md` tells. The test makes the
  # project in a new directory, fetches the dependencies, and runs
  # `mix expresso` there. It takes the repository from its path, so it tests the
  # code of the working tree, and it needs the network for the dependencies of
  # Expresso. `mix test --only dependency` runs it.
  @moduletag :dependency
  @moduletag timeout: :timer.minutes(15)

  @root Path.expand("../..", __DIR__)

  defp mix(project, args) do
    System.cmd("mix", args,
      cd: project,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}, {"MIX_DEPS_PATH", nil}, {"MIX_BUILD_PATH", nil}]
    )
  end

  setup do
    project = Path.join(System.tmp_dir!(), "expresso-user-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(project, "lib"))
    File.mkdir_p!(Path.join(project, "talk"))
    on_exit(fn -> File.rm_rf!(project) end)

    File.write!(Path.join(project, "mix.exs"), """
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

    File.write!(Path.join(project, "lib/server.ex"), """
    defmodule UserProject.Server do
      def start, do: :ok
    end
    """)

    File.write!(Path.join(project, "talk/deck.exs"), """
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
