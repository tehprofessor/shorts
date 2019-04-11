defmodule Shorts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Shorts.Server, [port: 4020, pool_size: 8, ip_address: {192, 168, 1, 182}]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Shorts.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
