defmodule AcceptorPool do
  require Logger

  defstruct [:pool, :counter, :max, :initial_state, :available_state, :busy_state]

  @counter_id 1

  def new(max_size) do
    pool = :ets.new(:shorts_acceptor_pool, [:named_table, read_concurrency: true])
    counter = :counters.new(1, [:atomics])

    %__MODULE__{pool: pool, counter: counter, max: max_size}
  end

  def info(%{counter: counter, pool: pool}) do
    pool_info = :ets.info(pool)

    %{
      :size => pool_info[:size],
      :memory => pool_info[:memory],
      :name => pool_info[:name],
      :total_members => :counters.get(counter, @counter_id)
    }
  end

  def size(%{counter: counter}) do
    :counters.get(counter, @counter_id)
  end

  def checkout(pool) do
    __checkout__(pool)
  end

  # Create a new member for the pool, reuse an existing member,
  # or return `{:busy, nil}`
  defp __checkout__(%{counter: counter, max: max} = pool) do
    if :counters.get(counter, @counter_id) < max,
      do: __new__(pool)
  end

  defp __new__(%{pool: pool, counter: counter}) do
    {:ok, member} = Shorts.Acceptor.start_link()
    true = __add__(member, self(), pool)

    # We created a new acceptor, so we need to increase the pool
    # counter.
    :counters.add(counter, @counter_id, 1)

    {:ok, member}
  end

  defp __first__(%{pool: pool}) do
    with {[{member, old_state}], _} <-
           :ets.select(pool, [{{:"$1", self()}, [], [:"$_"]}], 1) do
      {:ok, member}
    else
      _ ->
        {:no_members_in_pool, nil}
    end
  end

  # Note: Matching `true` for the below :ets calls.
  #
  # If there is a problem with ETS, we need to shit the bed, so we might
  # as well shit quickly and get the hell outta bed.

  defp __add__(member, pool_name, pool) do
    true = :ets.insert(pool, {member, pool_name})
  end

  defp __remove__(member, pool_name, pool) do
    true = :ets.delete(pool, {member, pool_name})
  end

  defp __count__(pool_name, pool) do
    pool
    |> :ets.select([{{:"$1", pool_name}, [], [:"$_"]}])
    |> Enum.count()
  end

  @doc """
  Logging is insanely slow, this is kind of crazy to see, uncomment to find out
  """
  defp log(message) do
    ["[pool", inspect(self()), "]", " ", message]
    |> Enum.join("")
    |> Logger.info()
  end
end
