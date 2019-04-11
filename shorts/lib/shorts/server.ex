defmodule Shorts.Server do
  @moduledoc false

  require Logger

  use GenServer

  defmodule Connection do
    defstruct [
      :acceptor_pool,
      :ip_address,
      :listener,
      :port,
      :pool_size
    ]
  end

  def serve!(port \\ 4020, opts \\ [pool_size: 8, ip_address: {192, 168, 1, 177}]) do
    connection = %Connection{
      ip_address: config(:ip_address, opts[:ip_address]),
      port: port,
      pool_size: config(:pool_size, opts[:pool_size])
    }

    {:ok, server} = start_link(4020)

    server
  end

  # Kick everyone outta the pool
  def pee! do
    GenServer.call(__MODULE__, :pee!)
  end

  def status() do
    GenServer.call(__MODULE__, :status)
  end

  ## @behaviour GenServer

  def start_link(opts \\ [port: 4020, pool_size: 8, ip_address: {192, 168, 1, 177}]) do
    connection = %Connection{
      ip_address: config(:ip_address, opts[:ip_address]),
      port: opts[:port],
      pool_size: config(:pool_size, opts[:pool_size])
    }

    GenServer.start_link(__MODULE__, connection, name: __MODULE__)
  end

  def init(conn), do: {:ok, conn, {:continue, :create_listener}}

  def handle_continue(
        :create_listener,
        %{port: port, pool_size: pool_size, ip_address: ip_address} = conn
      ) do
    {:ok, listener} =
      :gen_tcp.listen(port, [
        {:ip, ip_address},
        {:reuseaddr, true},
        {:packet, :http},
        {:active, false},
        {:send_timeout_close, false},
        {:keepalive, true},
        {:delay_send, true}
      ])

    pool = AcceptorPool.new(pool_size)
    send(self(), :loop)

    {:noreply, %{%{conn | listener: listener} | acceptor_pool: pool}}
  end

  def handle_call(:pee!, _from, conn) do
    Process.exit(self(), :stop)
  end

  def handle_call(:status, _from, conn) do
    pool_info = AcceptorPool.info(conn.acceptor_pool)

    {:reply, pool_info, conn}
  end

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  def handle_info(:loop, %{acceptor_pool: pool} = conn) do
    _ = log(["Looping"])

    _ =
      with {:ok, acceptor} <- AcceptorPool.checkout(pool) do
        _msg = send(acceptor, {:accept, conn.listener})
        _msg = send(self(), :loop)
      end

    {:noreply, conn}
  end

  @doc """
  Logging is insanely slow, this is kind of crazy to see, uncomment to find out
  """
  defp log(message) do
#    ["[server", inspect(self()), "]", " ", message]
#    |> Enum.join("")
#    |> Logger.info()
  end

  defp config(key, nil), do: Application.get_env(:shorts, key)

  defp config(_key, override), do: override
end
