defmodule Shorts.Request do
  @moduledoc false

  defstruct [
    method: nil,
    headers: [],
    body: "",
    path: "",
    length: 0
  ]
end
