defmodule Shorts.NewShortUrl do
  @moduledoc false

  alias Shorts.Response

  def handle_request(url) do
    %Response{
      body: "{\"short-code\": \"MMCOFFEEISGOOD321\"}",
      status: 201
    }
  end
end
