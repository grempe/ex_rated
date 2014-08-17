defmodule ExRatedServerTest do
  use ExUnit.Case, async: true

  doctest ExRated

  setup do
    {:ok, buckets} = ExRated.start_link
    {:ok, buckets: buckets}
  end

  # test "spawns buckets", %{buckets: buckets} do
  #   assert ExRated.Server.lookup(registry, "shopping") == :error

  #   ExRated.Server.create(registry, "shopping")
  #   assert {:ok, bucket} = ExRated.Server.lookup(registry, "shopping")
  # end
end
