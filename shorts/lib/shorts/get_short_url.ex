defmodule Shorts.GetShortUrl do
  @moduledoc false

  alias Shorts.Response

  def handle_request(url) do
    %Response{
      body: "{\"url\": \"https://www.weedmaps.com\"}",
      status: 200,
    }
  end
end
