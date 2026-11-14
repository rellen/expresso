defmodule Expresso.Overlay.TypewriterTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Overlay.Typewriter

  doctest Expresso.Overlay.Typewriter

  # An element with steps and with the effect, around a content.
  defp typed(content, on \\ "2"), do: ~s(<p data-on="#{on}" data-effect="type">#{content}</p>)

  # The position and the content of each character of an HTML text, in order.
  defp chars(html) do
    ~r/<span class="type-char" style="--i:(\d+)">(.*?)<\/span>/s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [position, content] -> {String.to_integer(position), content} end)
  end

  # The number of characters that each element with the effect holds in
  # `--type-n`, in order.
  defp counts(html) do
    ~r/--type-n: (\d+)/
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [count] -> String.to_integer(count) end)
  end

  describe "wrap/1 and the characters" do
    test "puts white space into the span of the character before it" do
      assert chars(Typewriter.wrap(typed("ab  c\nd"))) == [
               {0, "a"},
               {1, "b  "},
               {2, "c\n"},
               {3, "d"}
             ]
    end

    test "puts the white space at the start of a text into the span of the first character" do
      assert chars(Typewriter.wrap(typed("<b>a</b> b"))) == [{0, "a"}, {1, " b"}]
    end

    test "writes no text of white space only between two tags" do
      html = Typewriter.wrap(typed("one two <b>three</b> four"))

      refute html =~ ~r/>\s+</
    end

    test "keeps a text of white space only as it is" do
      assert Typewriter.wrap(typed("<b>a</b>\n<b>b</b>")) =~ "</b>\n<b>"
    end

    test "takes a character reference as one character" do
      assert chars(Typewriter.wrap(typed("a&amp;b &#39;c&#x27; &lt;"))) == [
               {0, "a"},
               {1, "&amp;"},
               {2, "b "},
               {3, "&#39;"},
               {4, "c"},
               {5, "&#x27; "},
               {6, "&lt;"}
             ]
    end

    test "takes a grapheme of more than one code point as one character" do
      assert chars(Typewriter.wrap(typed("é 👩‍👩‍👧x"))) == [
               {0, "é "},
               {1, "👩‍👩‍👧"},
               {2, "x"}
             ]
    end

    test "keeps the whole text in front of its characters, for a screen reader" do
      html = Typewriter.wrap(typed("Hi <b>you</b>"))

      assert html =~
               ~s(<span class="type-text">Hi </span><span class="type-chars" aria-hidden="true">)

      assert html =~
               ~s(<b><span class="type-text">you</span><span class="type-chars" aria-hidden="true">)
    end

    test "counts the characters through each tag of the element" do
      html = Typewriter.wrap(typed("a <b>bc</b> <i>d</i> e"))

      assert Enum.map(chars(html), &elem(&1, 0)) == [0, 1, 2, 3, 4]
      assert counts(html) == [5]
    end
  end

  describe "wrap/1 and the elements" do
    test "changes only the text of an element with the effect" do
      html = ~s(<h1>Title</h1>#{typed("a")}<p data-on="2">fade</p><p>text</p>)
      wrapped = Typewriter.wrap(html)

      assert wrapped =~ "<h1>Title</h1>"
      assert wrapped =~ ~s(<p data-on="2">fade</p><p>text</p>)
      assert chars(wrapped) == [{0, "a"}]
    end

    test "needs steps on the element" do
      html = ~s(<p data-effect="type">no steps</p>)

      assert Typewriter.wrap(html) == html
    end

    test "leaves out an element inside with its own steps" do
      html = Typewriter.wrap(typed(~s(a <b data-on="3">fade</b> c)))

      assert html =~ ~s(<b data-on="3">fade</b>)
      assert chars(html) == [{0, "a "}, {1, " c"}]
      assert counts(html) == [2]
    end

    test "gives an element inside with its own steps and the effect its own positions" do
      html = Typewriter.wrap(typed(~s(ab <b data-on="3" data-effect="type">cd</b> e)))

      assert chars(html) == [{0, "a"}, {1, "b "}, {0, "c"}, {1, "d"}, {2, " e"}]
      assert counts(html) == [3, 2]
    end

    test "makes one sequence of the elements with the same parent and the same steps" do
      line = &~s(<span class="line" data-on="#{&1}" data-effect="type">#{&2}</span>)
      html = Typewriter.wrap("<code>" <> line.("2 3", "ab") <> line.("2 3", "cd") <> "</code>")

      assert chars(html) == [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}]
      assert counts(html) == [4, 4]
    end

    test "starts a new sequence for different steps and for a different parent" do
      line = &~s(<span class="line" data-on="#{&1}" data-effect="type">#{&2}</span>)

      steps = Typewriter.wrap("<code>" <> line.("2", "ab") <> line.("3", "c") <> "</code>")
      assert chars(steps) == [{0, "a"}, {1, "b"}, {0, "c"}]
      assert counts(steps) == [2, 1]

      parents = Typewriter.wrap("<div>#{line.("2", "ab")}</div><div>#{line.("2", "c")}</div>")
      assert chars(parents) == [{0, "a"}, {1, "b"}, {0, "c"}]
      assert counts(parents) == [2, 1]
    end

    test "keeps a picture, a formula, a script and a hidden element as they are" do
      inside =
        ~s(<svg viewBox="0 0 1 1"><text>svg</text><path d="M0 0"/><svg><text>in</text></svg></svg>) <>
          ~s(<math><mi>x</mi></math><script>let a = "<b>";</script><style>p { color: red; }</style>) <>
          ~s(<span class="line-number" aria-hidden="true">12</span>)

      html = Typewriter.wrap(typed(inside <> "a"))

      assert html =~ inside
      assert chars(html) == [{0, "a"}]
    end

    test "reads an element with no end tag" do
      html = Typewriter.wrap(typed(~s(a<br>b<img src="x.png" alt="">c<hr/>d)))

      assert chars(html) == [{0, "a"}, {1, "b"}, {2, "c"}, {3, "d"}]
      assert html =~ ~s(<img src="x.png" alt="">)
    end

    test "reads an attribute with the character > in its value" do
      html = Typewriter.wrap(typed(~s(<a title="a > b" href='x>y'>go</a>)))

      assert html =~ ~s(<a title="a > b" href='x>y'>)
      assert chars(html) == [{0, "g"}, {1, "o"}]
    end

    test "keeps a comment" do
      html = Typewriter.wrap(typed("a<!-- <b>not text</b> -->b"))

      assert html =~ "<!-- <b>not text</b> -->"
      assert chars(html) == [{0, "a"}, {1, "b"}]
    end

    test "reads a text with an end tag that has no start tag" do
      html = Typewriter.wrap(typed("a</i>b") <> typed("c", "3"))

      assert chars(html) == [{0, "a"}, {1, "b"}, {0, "c"}]
    end

    test "writes the number of the characters in front of the style of the element" do
      html = Typewriter.wrap(~s(<p data-on="2" data-effect="type" style="color: red">abc</p>))

      assert html =~ ~s(<p data-on="2" data-effect="type" style="--type-n: 3; color: red">)
    end

    test "removes the effect from an element with no character" do
      html = ~s(<div data-on="2" data-effect="type" data-speed="slow"> <img src="a.png"> </div>)

      assert Typewriter.wrap(html) ==
               ~s(<div data-on="2" data-speed="slow"> <img src="a.png"> </div>)
    end
  end

  describe "the render" do
    defp area(opts), do: Builder.text_box(elements: [Builder.text_area(opts)])

    test "the present view holds each character of a text area with the effect" do
      html = document(one_slide(area(text: "Run it", at: 2, effect: :type)))

      area = html |> screen(~s(.text-area[data-effect="type"])) |> only!()

      assert LazyHTML.attribute(area, "style") == ["--type-n: 5"]
      assert texts(html, ".screen .type-text") == ["Run it"]
      assert texts(html, ".screen .type-char") == ["R", "u", "n ", "i", "t"]
      assert count(html, ~s(.screen .type-chars[aria-hidden="true"])) == 1
    end

    test "a page of the handout view and a copy in the menu keep the text as it is" do
      html = document(one_slide(area(text: "Run it", at: 2, effect: :type)))

      assert count(html, ".type-char") == 5
      assert count(html, ".handout .type-char") == 0
      assert count(html, "#menu .type-char") == 0
      assert count(html, ~s(.handout .text-area[data-effect="type"])) == 2
    end

    test "an element with no steps keeps its text" do
      html = document(one_slide(area(text: "Run it", effect: :type)))

      assert count(html, ".type-char") == 0
    end

    test "an element takes the effect of the slide and of the deck" do
      slide = document(one_slide(area(text: "ab", at: 2), effect: :type))
      deck = document(one_slide(area(text: "ab", at: 2), [], effect: :type))

      assert texts(slide, ".screen .type-char") == ["a", "b"]
      assert texts(deck, ".screen .type-char") == ["a", "b"]
    end

    test "the lines of one group of a code element make one sequence" do
      code =
        Builder.code(
          text: "a = 1\nb = 2\nc\n",
          lang: "elixir",
          reveal: [1..2, 3],
          effect: :type
        )

      html = document(one_slide([Builder.pause(), code]))

      styles =
        html |> screen(".line") |> Enum.map(&LazyHTML.attribute(&1, "style")) |> List.flatten()

      assert styles == ["--type-n: 6", "--type-n: 6", "--type-n: 1"]

      positions =
        html
        |> screen(".line .type-char")
        |> Enum.map(&LazyHTML.attribute(&1, "style"))
        |> List.flatten()

      assert positions == ~w(--i:0 --i:1 --i:2 --i:3 --i:4 --i:5 --i:0)
    end

    test "the number of a line is not a character" do
      code =
        Builder.code(
          text: "ab\n",
          lang: "elixir",
          at: 2,
          effect: :type,
          line_numbers: true
        )

      html = document(one_slide(code))

      assert texts(html, ".screen .line-number") == ["1"]
      assert Enum.join(texts(html, ".screen .type-char")) =~ ~r/\Aab\s*\z/
    end

    test "each item of a list with reveal has its own sequence" do
      list =
        Builder.list(
          elements: [Builder.item("ab"), Builder.item("cde")],
          reveal: true,
          effect: :type
        )

      html = document(one_slide([Builder.pause(), list]))

      styles =
        html |> screen("li") |> Enum.map(&LazyHTML.attribute(&1, "style")) |> List.flatten()

      assert styles == ["--type-n: 2", "--type-n: 3"]
    end

    test "a part of a text with its own steps types at its steps" do
      html =
        document(one_slide(area(text: ~s(ab <b at="3-">cd</b> e), at: [from: 2], effect: :type)))

      part = html |> screen("[data-text-part]") |> only!()

      assert LazyHTML.attribute(part, "data-effect") == ["type"]
      assert LazyHTML.attribute(part, "style") == ["--type-n: 2"]

      area = html |> screen(".text-area") |> only!()
      assert LazyHTML.attribute(area, "style") == ["--type-n: 3"]
    end

    test "a picture with the effect fades in the present view" do
      image = Builder.image("test/fixtures/dark.png", alt: "A picture", at: 2, effect: :type)
      html = document(one_slide(image))

      assert count(html, ~s(.screen .image[data-on="2"])) == 1
      assert count(html, ~s(.screen .image[data-effect])) == 0
    end
  end
end
