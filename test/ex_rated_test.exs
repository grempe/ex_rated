defmodule ExRatedServerTest do
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

  doctest ExRated

  test "returns {:ok, 1} tuple on first access" do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 10)
  end

  test "returns {:ok, 4} tuple on in-limit checks" do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 10)
    assert {:ok, 2} = ExRated.check_rate("my-bucket", 10_000, 10)
    assert {:ok, 3} = ExRated.check_rate("my-bucket", 10_000, 10)
    assert {:ok, 4} = ExRated.check_rate("my-bucket", 10_000, 10)
  end

  test "returns expected tuples on mix of in-limit and out-of-limit checks" do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket", 10_000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket", 10_000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket", 10_000, 2)
  end

  test "returns expected tuples on 1000ms bucket check with a sleep in the middle" do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 1000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket", 1000, 2)
    :timer.sleep 1000
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 1000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket", 1000, 2)
  end

  test "returns expected tuples on inspect_bucket" do
    assert {0, 2, _, nil, nil} = ExRated.inspect_bucket("my-bucket1", 1000, 2)
    assert {:ok, 1} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {1, 1, _, _, _} = ExRated.inspect_bucket("my-bucket1", 1000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {:ok, 1} = ExRated.check_rate("my-bucket2", 1000, 2)
    assert {2, 0, _, _, _} = ExRated.inspect_bucket("my-bucket1", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {3, 0, ms_to_next_bucket, _, _} = ExRated.inspect_bucket("my-bucket1", 1000, 2)
    assert ms_to_next_bucket < 1000
  end

  test "returns expected tuples on delete_bucket" do
    assert {:ok, 1} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {:ok, 1} = ExRated.check_rate("my-bucket2", 1000, 2)
    assert {:ok, 2} = ExRated.check_rate("my-bucket2", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket2", 1000, 2)
    assert :ok = ExRated.delete_bucket("my-bucket1")
    assert {:ok, 1} = ExRated.check_rate("my-bucket1", 1000, 2)
    assert {:error, 2} = ExRated.check_rate("my-bucket2", 1000, 2)

    assert :error = ExRated.delete_bucket("unknown-bucket")
  end


  @tag persistent: false
  test "data is not persisted on server stop", context do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 10)
    ExRated.stop(context[:exrated_server])
    assert File.exists?("ex_rated_buckets_test") == false
  end

  @tag persistent: true
  test "data is persisted on server stop", context do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 10)
    ExRated.stop(context[:exrated_server])
    assert File.exists?("ex_rated_buckets_test")
  end

  @tag persistent: true
  test "in memory data and on disk data are the same when persisted", context do
    assert {:ok, 1} = ExRated.check_rate("my-bucket", 10_000, 10)
    data = ExRated.inspect_bucket("my-bucket", 10_000, 10)
    ExRated.stop(context[:exrated_server])

    # assert process is not running
    assert Process.alive?(context[:exrated_server]) == false

    # restart server in persistent mode
    {:ok, pid} = start_server(context[:exrated_table], true)

    # assert it reloads the data from disk
    # remove key #2 in data before comparison: it is a timestamp and it's never the same
    volatile   = data |> Tuple.delete_at(2)
    persistent = ExRated.inspect_bucket("my-bucket", 10_000, 10) |> Tuple.delete_at(2)

    assert volatile == persistent
    ExRated.stop(pid)
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
