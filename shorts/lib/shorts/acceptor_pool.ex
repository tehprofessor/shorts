defmodule AcceptorPool do
  require Logger

  defstruct [:pool, :counter, :max, :initial_state, :available_state, :busy_state]

  @counter_id 1

  def new(initial_state, available_state, busy_state, max_size) do
    pool = :ets.new(:shorts_acceptor_pool, [:named_table, read_concurrency: true])
    counter = :counters.new(1, [:atomics])

    %__MODULE__{pool: pool, counter: counter, max: max_size, initial_state: initial_state, available_state: available_state, busy_state: busy_state}
  end

  def info(%{counter: counter, pool: pool, initial_state: initial_state, available_state: available_state, busy_state: busy_state}) do
    pool_info = :ets.info(pool)

    log(["initial_state", to_string(initial_state), "available_state", to_string(available_state), "busy_state", to_string(busy_state)])
    %{
      :size => pool_info[:size],
      :memory => pool_info[:memory],
      :name => pool_info[:name],
      :total_members => :counters.get(counter, @counter_id),
      initial_state => __count__(initial_state, pool),
      available_state => __count__(available_state, pool),
      busy_state => __count__(busy_state, pool),
    }
  end

  def size(%{counter: counter}) do
    :counters.get(counter, @counter_id)
  end

  def checkout(pool) do
    __checkout__(pool)
  end

  def move(member, from, to, %{pool: pool}) do
    _ = __move__(member, from, to, pool)

    {:ok, member}
  end

  def checkin(member, pool) do
    __checkin__(member, pool)
  end

  def __checkin__(member, %{busy_state: busy_state, initial_state: initial_state, pool: pool}) do
    _ = __move__(member, busy_state, initial_state, pool)
    {:ok, nil}
  end

  # Create a new member for the pool, reuse an existing member,
  # or return `{:busy, nil}`
  defp __checkout__(%{counter: counter, max: max} = pool) do
    if :counters.get(counter, @counter_id) < max,
      do: __new__(pool),
      else: __reuse__(pool)
  end

  defp __new__(%{initial_state: initial_state, pool: pool, counter: counter}) do
    {:ok, member} = Shorts.Acceptor.start_link()
    true = __add__(member, initial_state, pool)

    # We created a new acceptor, so we need to increase the pool
    # counter.
    :counters.add(counter, @counter_id, 1)

    {:ok, member}
  end

  defp __reuse__(%{initial_state: initial_state, available_state: available_state, pool: pool}) do
    with {[{member, old_state}], _} <-
           :ets.select(pool, [{{:"$1", initial_state}, [], [:"$_"]}], 1) do
      __move__(member, initial_state, available_state, pool)
      {:ok, member}
    else
      _ ->
        log(["No `free` member in pool, all members unavailable, and pool at max capacity"])
        {:unavailable, nil}
    end
  end

  # Note: Matching `true` for the below :ets calls.
  #
  # If there is a problem with ETS, we need to shit the bed, so we might
  # as well shit quickly and get the hell outta bed.

  defp __move__(member, from, to, pool) do
    true = __remove__(member, from, pool) && __add__(member, to, pool)
  end

  defp __add__(member, pool_name, pool) do
    true = :ets.insert(pool, {member, pool_name})
  end

  defp __remove__(member, pool_name, pool) do
    true = :ets.delete(pool, {member, pool_name})
  end

  defp __count__(pool_name, pool) do
    pool
    |> :ets.select([{{:'$1', pool_name}, [], [:'$_']}])
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
