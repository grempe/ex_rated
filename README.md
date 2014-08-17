# ExRated

ExRated is:

1. A port of the Erlang '[ratelimiter](https://github.com/Gromina/raterlimiter)' project to Elixir.
2. An OTP GenServer process that allows you to rate limit calls to anything, for example an external API.


## Usage

Needs writing.

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

## Is it fast?

On my old Macbook Pro I can do 65,000 checks in about 1.6 seconds.

    ````elixir
    iex> Benchwarmer.benchmark fn -> {:ok, _} = ExRated.check_rate("my-bucket", 1000000, 10_000_000) end
    *** #Function<20.90072148/0 in :erl_eval.expr/5> ***
    1.6 sec    65K iterations   25.42 μs/op
    ````

## License

ExRated source code is released under Apache 2 License.
Check LICENSE file for more information.
