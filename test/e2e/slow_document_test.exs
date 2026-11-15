defmodule Expresso.E2E.SlowDocumentTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.Frame

  # The document of a deck holds each video file as a data URI in the element
  # `expresso-videos`, which comes after the presenter script. On a slow
  # network, the browser gets the slides and the script a long time before it
  # gets the file. These tests send a document in two parts: the part in
  # front of `expresso-videos`, and then the remaining part when the test
  # asks for it.
  defmodule Deck do
    use Expresso

    name "slow deck"

    slide "start" do
      text_box do
        text_area(text: "Start")
      end
    end

    slide "clip" do
      video "test/fixtures/clip.webm" do
        title "A clip"
        poster "test/fixtures/dot.png"
      end
    end
  end

  defmodule FirstDeck do
    use Expresso

    name "first deck"

    slide "clip" do
      video "test/fixtures/clip.webm" do
        title "A clip"
        poster "test/fixtures/dot.png"
      end
    end
  end

  @list ~s(<script id="expresso-videos")
  @head "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n"
  @timeout 30_000

  # Start a server on a free port of 127.0.0.1 that sends the document of a
  # deck in two parts. The test gets `{:document, pid}` when the browser asked
  # for the document and the server sent the first part. The server sends the
  # second part when that process gets `:rest`.
  defp serve(deck) do
    html = deck |> Expresso.parse() |> Expresso.Deck.render()
    [first, rest] = String.split(html, @list, parts: 2)
    # The presenter is in the first part, and the file is in the second part.
    assert first =~ "keydown"
    assert rest =~ "data:video/webm;base64,"

    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, port} = :inet.port(listen)
    test = self()
    spawn(fn -> accept(listen, test, first, @list <> rest) end)
    on_exit(fn -> :gen_tcp.close(listen) end)
    "http://127.0.0.1:#{port}/"
  end

  defp accept(listen, test, first, rest) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        handler = spawn(fn -> answer(test, first, rest) end)
        :ok = :gen_tcp.controlling_process(socket, handler)
        send(handler, {:socket, socket})
        accept(listen, test, first, rest)

      {:error, _closed} ->
        :ok
    end
  end

  defp answer(test, first, rest) do
    receive do
      {:socket, socket} ->
        {:ok, request} = :gen_tcp.recv(socket, 0, @timeout)

        if String.starts_with?(request, "GET / ") do
          :ok = :gen_tcp.send(socket, [@head, first])
          send(test, {:document, self()})

          receive do
            :rest -> :gen_tcp.send(socket, rest)
          after
            @timeout -> :ok
          end
        else
          :gen_tcp.send(socket, "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
        end

        :gen_tcp.close(socket)
    end
  end

  # Open an address, and return when the browser started to read the
  # document. `open/2` waits for the whole document.
  defp start(page, url) do
    {:ok, _response} =
      Frame.goto(page.main_frame.guid, timeout: @timeout, url: url, wait_until: "commit")

    assert_receive {:document, server}, @timeout
    {page, server}
  end

  defp video(slide), do: "document.querySelector('#slide-#{slide} video')"

  test "the presenter answers a key before the browser gets the video file", %{page: page} do
    {audience, server} = start(page, serve(Deck))
    wait_for(audience, "document.querySelector('#slide-2') !== null")

    # The browser still reads the document, and the list of the videos is not
    # there.
    assert js(audience, "document.readyState") == "loading"
    assert js(audience, "document.getElementById('expresso-videos')") == nil
    assert position(audience) == "1.1"

    audience |> press("j") |> wait_for_position("2.1")

    # The slide of the video shows, and the video waits for its file.
    assert js(audience, "document.readyState") == "loading"
    assert js(audience, "#{video(2)}.getAttribute('src')") == nil

    send(server, :rest)
    wait_for(audience, "document.readyState !== 'loading'")
    wait_for(audience, "#{video(2)}.paused === false && #{video(2)}.readyState >= 2")
    assert js(audience, "#{video(2)}.src.startsWith('data:video/webm;base64,')") == true
  end

  test "a video of the first slide plays when the browser got its file", %{page: page} do
    {audience, server} = start(page, serve(FirstDeck))
    wait_for(audience, "#{video(1)} !== null")

    assert js(audience, "document.readyState") == "loading"
    assert js(audience, "#{video(1)}.getAttribute('src')") == nil

    send(server, :rest)
    wait_for(audience, "#{video(1)}.paused === false && #{video(1)}.readyState >= 2")
    assert js(audience, "#{video(1)}.videoWidth") > 0
  end
end
