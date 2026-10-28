defmodule Expresso.Element.MathTexTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Diagram.Tool
  alias Expresso.Element.Math.Tex

  describe "the copy of Temml" do
    test "has the version of package.json, its license and the type module" do
      package = "package.json" |> File.read!() |> JSON.decode!()
      assert package["devDependencies"]["temml"] == Tex.version()

      assert File.read!("priv/temml/LICENSE") =~ "MIT License"

      assert File.read!("priv/temml/package.json") |> JSON.decode!() |> Map.fetch!("type") ==
               "module"

      assert File.exists?(Tex.script())
    end

    test "the tool is Node, and a missing Node names the formulas of the deck" do
      assert %{program: "node", variable: "EXPRESSO_NODE"} = Tex.tool()

      assert Tool.find(Tex.tool(), {:subject, "the formulas of the deck"}, %{
               "EXPRESSO_NODE" => "/no/node"
             }) == {:error, "EXPRESSO_NODE gives /no/node, and that file does not exist"}
    end

    test "an empty list of sources needs no Node" do
      assert Tex.render!([]) == []
    end
  end

  describe "with Temml" do
    @describetag :temml

    test "makes the MathML of each source, in display mode and in order" do
      assert [{:ok, square}, {:ok, fraction}] = Tex.render!(["x^2", ~S"\frac{a}{b}"])

      assert square =~ ~s(<math display="block")
      assert square =~ "<msup>"
      assert fraction =~ "<mfrac>"
    end

    test "gives the message of Temml for a source that it cannot read, and reads the others" do
      assert [{:ok, _x}, {:error, message}, {:ok, _y}] = Tex.render!(["x", ~S"\frac{a}{", "y"])
      assert message =~ "Unexpected end of input"
      assert message == String.trim(message)
    end

    test "trusts \\class and \\data, so a part gets its attribute" do
      assert [{:ok, class}, {:ok, data}] =
               Tex.render!([~S"\class{redex}{x+1}", ~S"\data{part=arg}{g}"])

      assert class =~ ~s(class="redex")
      assert data =~ ~s(data-part="arg")
    end

    test "refuses each other command that writes an attribute or reads a file" do
      for source <- [~S"\id{a}{x}", ~S"\style{color:red}{x}", ~S"\includegraphics{a.png}"] do
        assert [{:error, message}] = Tex.render!([source])
        assert message =~ "is not trusted", source
      end
    end
  end
end
