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
      :pool_size,
      :acceptors,
      :acceptor_counter
    ]
  end

  def serve!(port \\ 4020, opts \\ [pool_size: 1, ip_address: {192, 168, 1, 177}]) do
    %Connection{
      ip_address: config(:ip_address, opts[:ip_address]),
      port: port,
      pool_size: config(:pool_size, opts[:pool_size]),
    }
    |> start_link()
  end

  def status() do
    GenServer.call(__MODULE__, :status)
  end

  ## @behaviour GenServer

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection, name: __MODULE__)
  end

  def init(conn), do: {:ok, conn, {:continue, :create_listener}}

  def handle_continue(
        :create_listener,
        %{port: port, pool_size: pool_size, ip_address: ip_address} = conn
      ) do
    {:ok, listener} =
      :gen_tcp.listen(port, [{:ip, ip_address}, {:packet, :http}, {:active, false}])


    pool = AcceptorPool.new(:free, :accepting, :busy, pool_size)
    send(self(), :loop)

    {:noreply, %{%{conn | listener: listener} | acceptor_pool: pool}}
  end

  def handle_call(:status, _from, conn) do
    pool_info = AcceptorPool.info(conn.acceptor_pool)

    {:reply, pool_info, conn}
  end

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}

  @doc "Checkin the acceptor, move from :busy -> :free"
  def handle_info({:checkin, acceptor}, %{acceptor_pool: acceptor_pool} = conn) do
    log(["handle_info({:checkin, acceptor}, conn)"])

    {:ok, nil} = AcceptorPool.checkin(acceptor, acceptor_pool)
    send(self(), :loop)

    {:noreply, conn}
  end

  def handle_info({:busy, acceptor}, %{acceptor_pool: acceptor_pool} = conn) do
    log(["handle_info({:loop, :running}, conn)"])
    {:ok, _acceptor} = AcceptorPool.move(acceptor, :accepting, :busy, acceptor_pool)

    send(self(), :loop)

    {:noreply, conn}
  end

  def handle_info({:accepting, acceptor}, %{acceptor_pool: pool} = conn) do
    log(["handle_info({:accepting, acceptor}, conn)"])
    {:ok, _acceptor} = AcceptorPool.move(acceptor, :free, :accepting, pool)

    {:noreply, conn}
  end

  def handle_info(:loop, %{acceptor_pool: pool} = conn) do
    log(["Looping"])

    _ = with {:ok, acceptor} <- AcceptorPool.checkout(pool) do
      send(acceptor, {:accept, conn.listener, self()})
    end

    {:noreply, conn}
  end

  @doc """
  Logging is insanely slow, this is kind of crazy to see, uncomment to find out
  """
  defp log(message) do
    ["[server", inspect(self()), "]", " ", message]
    |> Enum.join("")
    |> Logger.info()
  end

  defp config(key, nil), do: Application.get_env(:shorts, key)

  defp config(_key, override), do: override
end
