defmodule ShortsTest do
  use ExUnit.Case
  doctest Shorts

  test "greets the world" do
    assert Shorts.hello() == :world
  end
end
