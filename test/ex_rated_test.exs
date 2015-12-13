defmodule ExRatedServerTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(ExRated, [ {:timeout, 10_000}, {:cleanup_rate,10_000}, {:ets_table_name, :ex_rated_buckets_test} ], [name: :ex_rated])
    {:ok, exrated_server: pid}
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

end
