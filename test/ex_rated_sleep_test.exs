defmodule ExRatedSleepTest do
  use ExUnit.Case, async: true

  setup context do

    table = :ex_rated_buckets_test

    {:ok, pid} = start_server(table, context[:persistent] || false)

    on_exit fn ->
      if context[:persistent] do
        File.rm(table |> to_string)
      end
    end

    {:ok, exrated_server: pid, exrated_table: table}
  end

  def display_date do
    d = DateTime.utc_now
    IO.puts "#{d.year}/#{d.month}/#{d.day} #{d.hour}:#{d.minute}:#{d.second} #{inspect d.microsecond}"
  end

  test "test with sleep" do
    # run 100 check_rate
    _res = for _i <- 1..100 do
      ExRated.check_rate("my-bucket", 1_000, 10_000)
    end
    # Sleep for 0.5 second, could also use (Process.sleep(500))
    :timer.sleep(500)
    # inspect the bucket
    {count, count_remaining, _, _, _} = ExRated.inspect_bucket("my-bucket", 1_000, 10_000)
    assert [count, count_remaining] == [100, 9900]
  end

  defp start_server(table, persistent) do
    GenServer.start_link(ExRated, [
      {:timeout, 10_000},
      {:cleanup_rate,10_000},
      {:ets_table_name, table},
      {:persistent, persistent},
    ], [name: :ex_rated])
  end

end
