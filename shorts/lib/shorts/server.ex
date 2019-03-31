defmodule Shorts.Server do
  @moduledoc false

  require Logger

  use GenServer

  # Acceptor Counter Identifiers
  @acceptors_waiting 1
  @acceptors_running 2

  defmodule Connection do
    defstruct [:listener, :port, :pool_size, :acceptors, :acceptor_counter]
  end

  def serve!(port \\ 4020, opts \\ [pool_size: 500]) do
    %Connection{
      port: port,
      pool_size: opts[:pool_size],
      acceptors: :queue.new(),
      acceptor_counter: :counters.new(2, [:atomics]),
    } |> start_link()
  end

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection, [])
  end

  def init(%{port: port, pool_size: pool_size} = conn) do
    # Setup the listener, set the packet type to be http, and `{:active, true}` to
    # receive messages in this process via `handle_info/2` calls.
    IO.inspect(["port", port, pool_size])
    {:ok, listener} = :gen_tcp.listen(port, [{:packet, :http}, {:active, false}])

    send(self(), :loop)

    {:ok, %{conn | listener: listener}}
  end

  def handle_continue() do

  end

  def checkin(server, acceptor) do
    log(["CHECKIN ACCEPTOR!!"])
    GenServer.cast(server, {:checkin, acceptor})
  end

  @doc "Checkin the acceptor"
  def handle_cast({:checkin, acceptor}, conn) do
    log(["checkin acceptor!"])
    acceptors = :queue.in(acceptor, conn.acceptors)

    # Decrease running acceptors by one
    :counters.sub(conn.acceptor_counter, @acceptors_running, 1)
    # Increase waiting acceptors by one
    :counters.add(conn.acceptor_counter, @acceptors_waiting, 1)

    send(self(), :loop)

    {:noreply, %{conn | acceptors: acceptors}}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_info(:loop, state) do
    log(["Setting up new loop"])
    {acceptor, acceptors} = checkout(state)

    # It's cool to accept in a child process,
    # so that's where we'll block for the next connection.
    send(acceptor, {:accept, state.listener, self()})

    {:noreply, %{state | acceptors: acceptors}}
  end

  @doc """
  Checkout an acceptor from the pool. Marks it as in use by
  incrementing the connection's @acceptors_running counter and
  decreasing the @acceptors_waiting counter.
  """
  defp checkout(%{acceptors: acceptor_pool} = conn) do
    log(["Checking out an acceptor"])
    acceptors = case :queue.out(acceptor_pool) do
      {{:value, acceptor}, acceptors} ->
        # If we pop an acceptor from the pool, decrement the waiting
        # counter by 1.
        :counters.sub(conn.acceptor_counter, @acceptors_waiting, 1)
        {acceptor, acceptors}
      {:empty, acceptors} ->
        {:ok, acceptor} = Shorts.Acceptor.start_link()
        {acceptor, acceptors}
    end

    # Increase the running count.
    :counters.add(conn.acceptor_counter, @acceptors_running, 1)
    acceptors
  end

  @doc """
  Logging is insanely slow, this is kind of crazy to see, uncomment to find out
  """
  defp log(message) do
#    IO.inspect(["[server", self(), "]", " ", message])
  end
end