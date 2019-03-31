defmodule Shorts.ShortUrl do
  @moduledoc false

  defstruct [:hash, :hex, :url]

  def new(url) do
    %__MODULE__{url: url} |> hash() |> hex()
  end

  def hash(short_url) do
    hash = to_charlist(short_url) |> WyhashEx.hash()

    %{short_url | hash: hash}
  end

  def hex(%{hash: hash} = short_url) do
    %{short_url | hex: Integer.to_string(hash, 36)}
  end
end
