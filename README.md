# ExRated

ExRated is:

1. A port of the Erlang '[ratelimiter](https://github.com/Gromina/raterlimiter)' project to Elixir.
2. An OTP GenServer process that allows you to rate limit calls to anything, for example an external API.
3. The Hex.pm package with the naughty name.

You can learn more about the concept for this rate limiter in [ the Token Bucket article on Wikipedia](http://en.wikipedia.org/wiki/Token_bucket)


## Usage

Call the ExRated application with `ExRated.check_rate()`.  This function takes three arguments:

1. A `bucket name` (String).  You can have as many buckets as you need.
2. A `scale` (Integer) which represents the time scale in milliseconds that the bucket is valid for.
3. A `limit` which represents how many actions you want to limit your app to in the time scale provided.

For example, if you have to enforce a rate limit of no more than 10 calls in 10 seconds to your API:

	```elixir
	iex> ExRated.check_rate("my-rate-limited-api", 10_000, 10)
	{:ok, 1}
	```

The `ExRated.check_rate` function will return an `{:ok, Integer}` tuple if its OK to proceed with your rate limited function where the Integer returned is the current incrementing counter of how many times within the time scale your function has already been called.  If you are over limit a `{:fail, Integer}` tuple will be returned where the Integer is the limit you have specified.

## Installation

You can use ExRated in your projects in two steps:

1. Add ExRated to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [{:ex_rated, "~> 0.0.1"}]
    end
    ```

2. List `:ex_rated` in your application dependencies:

    ```elixir
    def application do
      [applications: [:ex_rated]]
    end
    ```

## Testing

It is important that the OTP doesn't get automatically started by Mix.

    ```elixir
    mix test --no-start
    ```

## Is it fast?

On my old Macbook Pro I can do 65,000 checks in about 1.6 seconds.

    ```elixir
    iex> Benchwarmer.benchmark fn -> {:ok, _} = ExRated.check_rate("my-bucket", 1000000, 10_000_000) end
    *** #Function<20.90072148/0 in :erl_eval.expr/5> ***
    1.6 sec    65K iterations   25.42 μs/op
    ```

## License

ExRated source code is released under Apache 2 License.
Check LICENSE file for more information.
