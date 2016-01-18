defmodule ExRated.Utils do
  @moduledoc false

  @doc """
  Determines the current version of OTP running this node. The result is
  cached for fast lookups in performance-sensitive functions.
  ## Example
      iex> rel = ExRated.Utils.get_otp_release
      ...> '\#{rel}' == :erlang.system_info(:otp_release)
      true
  """
  def get_otp_release do
    case Process.get(:current_otp_release) do
      nil ->
        case ("#{:erlang.system_info(:otp_release)}" |> Integer.parse) do
          {ver, _} when is_integer(ver) ->
            Process.put(:current_otp_release, ver)
            ver
        end
      ver ->
        ver
    end
  end
end
