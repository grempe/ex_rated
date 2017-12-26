defmodule BasicBench do
    use Benchfella
    
    setup_all do
      GenServer.start_link(ExRated, [
        {:timeout, 10_000},
        {:cleanup_rate,10_000},
        {:ets_table_name, :ex_rated_buckets_benchfella},
        {:persistent, false},
      ], [name: :ex_rated])
    end

    after_each_bench tid do
      ExRated.delete_bucket("my-bucket")
    end

    bench "Basic Bench" do
      ExRated.check_rate("my-bucket", 1000000, 10_000_000)
      {:ok}
    end
end
