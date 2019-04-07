defmodule Shorts.Acceptor do
  @moduledoc false
  require Logger

  use GenServer

  alias Shorts.Request

  defstruct [:listener, :writer, :request]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    log(["Initializing acceptor()"])

    {:ok, nil}
  end

  @doc "Tell the acceptor, to accept a connection"
  def handle_info({:accept, listener}, conn) do
    log("Accept -> Waiting for request ...")

    with {:ok, socket} <- :gen_tcp.accept(listener) do
      :inet.setopts(socket, [{:packet, :http_bin}, {:active, :once}, {:send_timeout_close, true}])

      {:noreply, %__MODULE__{listener: listener, writer: socket, request: %Request{}}}
    else
      {:error, timeout} ->
        send(self(), {:accept, listener})

        {:noreply, conn}
    end
  end

  def handle_info({:loop}, conn) do
    :inet.setopts(conn.writer, [{:packet, :http_bin}, {:active, :once}])

    {:noreply, conn}
  end

  @doc "Handle errors, likely from the recvbuf not being big enough (the OS will fix it)"
  def handle_info({:tcp_error, _port, message}, conn) do
    log(["Error! -> received `:tcp_error` #{inspect(message)}"])
    {:noreply, conn}
  end

  @doc "Handle timeout"
  def handle_info({:error, :timeout}, %{listener: listener} = conn) do
    log(["ERROR! -> received timeout... Closing socket."])
    :gen_tcp.close(conn.writer)

    send(self(), {:accept, listener})

    {:noreply, conn}
  end

  @doc "Set all other headers"
  def handle_info({:http, _port, {:http_header, _line_maybe, field, _reserved, value}}, conn) do
    log(["Header ->", " ", to_string(field), ":", " ", value])
    request = handle_header(field, value, conn.request)

    # Continue to the next header
    send(self(), {:loop})

    {:noreply, %{conn | request: request}}
  end

  @doc "Adds the http_method and path to the request struct"
  def handle_info({:http, _port, {:http_request, method, {:abs_path, path}, _http_version}}, conn) do
    request = %{%{conn.request | method: method} | path: path}
    log(["Request ->", " ", inspect(request.method), " @ ", request.path])

    send(self(), {:loop})

    {:noreply, %{conn | request: request}}
  end

  @doc "Handle :http_eoh (end of header), and read body"
  def handle_info({:http, _port, :http_eoh}, conn) do
    log(["Header -> End"])

    send(self(), :route)

    {:noreply, conn}
  end

  @doc "Handle the connection closed event and return this acceptor to the pool."
  def handle_info({:tcp_closed, _port}, %{listener: listener} = conn) do
    # Log the connection being closed
    log(["TCP connection closed ...", "Going to checkin self for reuse."])
    # Checkin the acceptor and start accepting again.
    send(self(), {:accept, listener})

    {:noreply, %{conn | writer: nil, request: nil}}
  end

  @doc "Checkin the acceptor"
  def handle_info({:checkin}, %{listener: listener} = conn) do
    log("Checkin -> Go... ?")

    send(self(), {:accept, listener})

    {:noreply, conn}
  end

  def handle_info(:route, %{request: %Request{method: :GET} = request} = conn) do
    log(["routing -> no-read-body"])

    :inet.setopts(conn.writer, [:binary, {:packet, :raw}, {:active, false}])

    response = Shorts.Router.route(request)

    send(self(), {:send_response, response})

    {:noreply, conn}
  end

  @doc "Routes the request"
  def handle_info(:route, %{request: request} = conn) do
    log(["routing -> read-body"])
    # To receive the body we need to change the connection packet option
    # to 'raw'. `{:active, false}` lets us receive the data by calling
    # `gen_tcp.recv/2` instead of waiting for a message.
    :inet.setopts(conn.writer, [:binary, {:packet, :raw}, {:active, false}])

    log([
      "Set inet options",
      " ",
      "request length:",
      " ",
      inspect(conn.request.length)
    ])

    # Read the data
    {:ok, data} = :gen_tcp.recv(conn.writer, conn.request.length)

    log(["Data ->", inspect(data)])
    request = %{conn.request | body: data}

    response = Shorts.Router.route(request)

    send(self(), {:send_response, response})

    {:noreply, conn}
  end

  @doc "Sends the response"
  def handle_info({:send_response, response}, conn) do
    log(["Send -> Response"])
    response_body = ["{\"url\":", " ", "my-url", "}"] |> to_string()
    response_length = byte_size(response.body) |> to_string()
    response_status = to_string(response.status)

    data = [
      ["HTTP/1.1", " ", response_status, " ", "OK"],
      "\r\n",
      ["Server:", " ", "ShortUrl"],
      "\r\n",
      ["Content-Length:", " ", response_length],
      "\r\n",
      ["Content-Type:", " ", "application/json"],
      "\r\n",
      ["Connection:", " ", "Close"],
      "\r\n",
      ["\r\n"],
      [response.body]
    ]

    # Send the response
    :gen_tcp.send(conn.writer, data)

    # Close the connection
    :gen_tcp.close(conn.writer)

    send(self(), {:checkin})

    {:noreply, conn}
  end

  @doc "Set the content length, make it an integer for make benefit myself."
  defp handle_header(:"Content-Length" = header, raw_length, %Request{length: 0} = request) do
    {content_length, _} = raw_length |> to_string() |> Integer.parse()

    handle_header(header, content_length, %{request | length: content_length})
  end

  defp handle_header(header, value, request) do
    headers = [{header, value} | request.headers]

    %{request | headers: headers}
  end

  @doc """
  Logging is insanely slow, this is kind of crazy to see, uncomment to find out
  """
  defp log(message) do
    ["[acceptor", inspect(self()), "]", " ", message]
    |> Enum.join("")
    |> Logger.info()
  end
end
