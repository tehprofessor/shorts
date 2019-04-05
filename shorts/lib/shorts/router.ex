defmodule Shorts.Router do
  @moduledoc false

  alias Shorts.{GetShortUrl, NewShortUrl, Response}

  def route(request) do
    cond do
      request.path =~ ~r/^(\/u\/)/ && request.method == :POST ->
        NewShortUrl.handle_request(request)

      request.path =~ ~r/^(\/u\/)/ && request.method == :GET ->
        GetShortUrl.handle_request(request)

      true ->
        %Response{
          body: "{\"error\": \"Error! Not Found.\"}",
          status: 200
        }
    end
  end
end
