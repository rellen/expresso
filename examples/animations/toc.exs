defmodule Examples.Toc do
  use Expresso

  slide "agenda" do
    heading "Agenda"

    toc do
      reveal true
    end
  end

  slide "why" do
    section "Why a release"
    heading "Why a release"
  end

  slide "build" do
    section "Build it"
    heading "Build it"
  end

  slide "test" do
    section "Test it"
    heading "Test it"
  end

  slide "deploy" do
    section "Deploy it"
    heading "Deploy it"
  end
end

Examples.Toc
