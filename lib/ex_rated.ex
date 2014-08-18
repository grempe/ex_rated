defmodule ExRated do
  use GenServer

  @moduledoc """
    An OTP GenServer that provides the ability to manage rate limiting
    for any process that needs it.  This rate limiter is based on the
    concept of a 'token bucket'.  You can read more here:

      http://en.wikipedia.org/wiki/Token_bucket

    This application is a direct port of the Erlang 'raterlimiter' project
    created by Alexander Sorokin (https://github.com/Gromina/raterlimiter,
    gromina@gmail.com, http://alexsorokin.ru) and the primary credit for
    the functionality goes to him. This has been implemented in Elixir
    since I needed it, and as a learning experiment.
  """

  ## Client API

  @doc """
  Starts the ExRated rate limit counter server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__,
                        [
                           {:timeout,        (Application.get_env(:ex_rated, :timeout) || 90_000_000)},
                           {:cleanup_rate,   (Application.get_env(:ex_rated, :cleanup_rate) || 60_000)},
                           {:ets_table_name, (Application.get_env(:ex_rated, :ets_table_name) || :ex_rated_buckets)}
                        ], opts)
  end

  @doc """
  Check if the action you wish to take is within the rate limit bounds.

  ## Arguments:

  - `id` (String) name of the client
  - `scale` (Integer) of time (e.g. 60_000 = bucket every minute)
  - `limit` (Integer) max size of bucket

  ## Examples

      # Limit to 2500 API requests in one day.
      iex> ExRated.check_rate("my-bucket", 86400000, 2500)
      {:ok, 1}

  """
  @spec check_rate(id::String.t, scale::integer, limit::integer) :: {:ok, count::integer} | {:fail, limit::integer}
  def check_rate(id, scale, limit) do
    GenServer.call(:ex_rated, {id, scale, limit})
  end

  @doc """
  Stop the rate limit counter server.
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  ## Server Callbacks

  def init(args) do

    [{:timeout, timeout}, {:cleanup_rate, cleanup_rate}, {:ets_table_name, ets_table_name}] = args

    :ets.new(ets_table_name, [:named_table, :ordered_set, :private])

    :timer.send_interval(cleanup_rate, :prune)
    {:ok, %{timeout: timeout, cleanup_rate: cleanup_rate, ets_table_name: ets_table_name}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({id, scale, limit}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    result = count_hit(id, scale, limit, ets_table_name)
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

  def terminate(_reason, _state) do
    :ok
  end

  def code_change(_old_version, state, _extra) do
    {:ok, state}
  end


  ## Private Functions

  defp count_hit(id, scale, limit, ets_table_name) do
    stamp         = timestamp()
    bucket_number = trunc(stamp/scale)      # with scale = 1 bucket changes every millisecond
    key           = {bucket_number, id}

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
          {:fail, limit}
        else
          {:ok, counter}
        end
    end
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
  defp timestamp() do
    timestamp(:erlang.now())
  end

  defp timestamp({mega, sec, micro}) do
    1000 * (mega * 1000000 + sec) + round(micro/1000)
  end

end
