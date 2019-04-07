defmodule Shorts do
  @moduledoc """
  Documentation for Shorts.
  """
  alias Shorts.Server

  @doc """
  Starts the Shorts Server and returns its pid

  ## Examples

      iex> Shorts.yolo()
     #PID<0.208.0>

  """
  def yolo do
    Server.serve!(4020)
  end

  def pee! do
    Server.pee!()
  end
end
