defmodule ExRated do
  use GenServer

  @moduledoc """
    An Elixir OTP GenServer that provides the ability to manage rate limiting
    for any process that needs it.  This rate limiter is based on the
    concept of a 'token bucket'.  You can read more here:

      http://en.wikipedia.org/wiki/Token_bucket

    This application started as a direct port of the Erlang 'raterlimiter' project
    created by Alexander Sorokin (https://github.com/Gromina/raterlimiter,
    gromina@gmail.com, http://alexsorokin.ru) and the primary credit for
    the functionality goes to him. This has been implemented in Elixir
    as a learning experiment and I hope you find it useful. Pull requests are
    welcome.
  """

  ## Client API

  @doc """
  Starts the ExRated rate limit counter server.
  """
  def start_link(args, opts \\ []) do
    case args do
      [] -> GenServer.start_link(__MODULE__, app_args_with_defaults(), opts)
      _ -> GenServer.start_link(__MODULE__, args, opts)
    end
  end


  @doc """
  Check if the action you wish to take is within the rate limit bounds
  and increment the buckets counter by 1 and its updated_at timestamp.

  ## Arguments:

  - `id` (String) name of the bucket
  - `scale` (Integer) of time in ms until the bucket rolls over. (e.g. 60_000 = empty bucket every minute)
  - `limit` (Integer) the max size of a counter the bucket can hold.

  ## Examples

      # Limit to 2500 API requests in one day.
      iex> ExRated.check_rate("my-bucket", 86400000, 2500)
      {:ok, 1}

  """
  @spec check_rate(id::String.t, scale::integer, limit::integer) :: {:ok, count::integer} | {:error, limit::integer}
  def check_rate(id, scale, limit) do
    GenServer.call(:ex_rated, {:check_rate, id, scale, limit})
  end

  @doc """
  Inspect bucket to get count, count_remaining, ms_to_next_bucket, created_at, updated_at.
  This function is free of side-effects and should be called with the same arguments you
  would use for `check_rate` if you intended to increment and check the bucket counter.

  ## Arguments:

  - `id` (String) name of the bucket
  - `scale` (Integer) of time the bucket you want to inspect was created with.
  - `limit` (Integer) representing the max counter size the bucket was created with.

  ## Example - Reset counter for my-bucket

      ExRated.inspect_bucket("my-bucket", 86400000, 2500)
      {0, 2500, 29389699, nil, nil}
      ExRated.check_rate("my-bucket", 86400000, 2500)
      {:ok, 1}
      ExRated.inspect_bucket("my-bucket", 86400000, 2500)
      {1, 2499, 29381612, 1450281014468, 1450281014468}

  """
  @spec inspect_bucket(id::String.t, scale::integer, limit::integer) :: {count::integer,
                                                                         count_remaining::integer,
                                                                         ms_to_next_bucket::integer,
                                                                         created_at :: integer | nil,
                                                                         updated_at :: integer | nil}
  def inspect_bucket(id, scale, limit) do
    GenServer.call(:ex_rated, {:inspect_bucket, id, scale, limit})
  end

  @doc """
  Delete bucket to reset the counter.

  ## Arguments:

  - `id` (String) name of the bucket

  ## Example - Reset counter for my-bucket

      iex> ExRated.check_rate("my-bucket", 86400000, 2500)
      {:ok, 1}
      iex> ExRated.delete_bucket("my-bucket")
      :ok

  """
  @spec delete_bucket(id::String.t) :: :ok | :error
  def delete_bucket(id) do
    GenServer.call(:ex_rated, {:delete_bucket, id})
  end

  @doc """
  Stop the rate limit counter server.
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  ## Server Callbacks

  def init(args) do
    [
      {:timeout, timeout},
      {:cleanup_rate, cleanup_rate},
      {:ets_table_name, ets_table_name},
      {:persistent, persistent}
    ] = args

    open_table(ets_table_name, persistent || false)
    :timer.send_interval(cleanup_rate, :prune)
    {:ok, %{timeout: timeout, cleanup_rate: cleanup_rate,
      ets_table_name: ets_table_name, persistent: persistent}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:check_rate, id, scale, limit}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    result = count_hit(id, scale, limit, ets_table_name)
    {:reply, result, state}
  end

  def handle_call({:inspect_bucket, id, scale, limit}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    result = inspect_bucket(id, scale, limit, ets_table_name)
    {:reply, result, state}
  end

  def handle_call({:delete_bucket, id}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    result = delete_bucket(id, ets_table_name)
    {:reply, result, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:reply, state}
  end

  def handle_info(:prune, state) do
    %{timeout: timeout, ets_table_name: ets_table_name} = state
    prune_expired_buckets(timeout, ets_table_name)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    # if persistent is true save ETS table on disk and then close DETS table
    if persistent?(state), do: persist_and_close(state)

    :ok
  end

  def code_change(_old_version, state, _extra) do
    {:ok, state}
  end


  ## Private Functions

  defp open_table(ets_table_name, false) do
    :ets.new(ets_table_name, [:named_table, :ordered_set, :private])
  end

  defp open_table(ets_table_name, true) do
    open_table(ets_table_name, false)
    :dets.open_file(ets_table_name, [{:file, ets_table_name}, {:repair, true}])
    :ets.delete_all_objects(ets_table_name)
    :ets.from_dets(ets_table_name, ets_table_name)
  end

  defp persistent?(state) do
    Map.get(state, :persistent) == true
  end

  defp persist(state) do
    %{ets_table_name: ets_table_name} = state
    :ets.to_dets(ets_table_name, ets_table_name)
  end

  defp persist_and_close(state) do
    persist(state)
    :dets.close(Map.get(state, :ets_table_name))
  end

  defp count_hit(id, scale, limit, ets_table_name) do
    {stamp, key} = stamp_key(id, scale)

    case :ets.member(ets_table_name, key) do
      false ->
        # Insert Key {bucket_number, id} with counter (1), created_at (timestamp), updated_at (timestamp)
        # The first element of the four element Tuple becomes the key.
        true = :ets.insert(ets_table_name, {key, 1, stamp, stamp})
        {:ok, 1}
      true ->
        # Increment counter by 1, increment created_at by 0 (no-op), and updated_at to current timestamp
        [counter, _, _] = :ets.update_counter(ets_table_name, key, [{2,1},{3,0},{4,1,0, stamp}])

        if (counter > limit) do
          {:error, limit}
        else
          {:ok, counter}
        end
    end
  end

  defp inspect_bucket(id, scale, limit, ets_table_name) do
    {stamp, key} = stamp_key(id, scale)
    ms_to_next_bucket = (elem(key, 0) * scale) + scale - stamp

    case :ets.member(ets_table_name, key) do
      false ->
        {0, limit, ms_to_next_bucket, nil, nil}
      true ->
        [{_, count, created_at, updated_at}] = :ets.lookup(ets_table_name, key)
        count_remaining = if limit > count, do: limit - count, else: 0
        {count, count_remaining, ms_to_next_bucket, created_at, updated_at}
    end
  end

  defp delete_bucket(id, ets_table_name) do
    import Ex2ms
    case :ets.select_delete(ets_table_name, fun do {{bucket_number, bid},_,_,_} when bid == ^id -> true end) do
      1 -> :ok
      _ -> :error
    end
  end

  defp stamp_key(id, scale) do
    stamp         = timestamp()
    bucket_number = trunc(stamp/scale)      # with scale = 1 bucket changes every millisecond
    key           = {bucket_number, id}
    {stamp, key}
  end

  # Removes old buckets and returns the number removed.
  defp prune_expired_buckets(timeout, ets_table_name) do
    # Ex2ms does for Elixir what :ets.fun2ms() does for Erlang code.
    # It creates a match spec for use in :ets.select_delete directly.
    # See : https://github.com/ericmj/ex2ms
    # See : http://www.erlang.org/doc/man/ms_transform.html
    import Ex2ms
    now_stamp = timestamp()
    :ets.select_delete(ets_table_name, fun do {_,_,_,updated_at} when updated_at < (^now_stamp - ^timeout) -> true end)
  end

  # Returns Erlang Time as milliseconds since 00:00 GMT, January 1, 1970
  defp timestamp()
    case ExRated.Utils.get_otp_release() do
      ver when ver >= 18 ->
        defp timestamp(), do: :erlang.system_time(:milli_seconds)
      _ ->
        defp timestamp() do
          {mega, sec, micro} = :erlang.now()
          1000 * (mega * 1000000 + sec) + round(micro/1000)
        end
  end

  # Fetch configured args
  defp app_args_with_defaults() do
    [timeout: Application.get_env(:ex_rated, :timeout) || 90_000_000,
     cleanup_rate: Application.get_env(:ex_rated, :cleanup_rate) || 60_000,
     ets_table_name: Application.get_env(:ex_rated, :ets_table_name) || :ex_rated_buckets,
     persistent: Application.get_env(:ex_rated, :persistent) || false]
  end

end
