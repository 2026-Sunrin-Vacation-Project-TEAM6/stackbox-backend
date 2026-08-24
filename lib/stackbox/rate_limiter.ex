defmodule Stackbox.RateLimiter do
  @moduledoc """
  Fixed-window rate limiter shared across app instances via Redis, matching
  `backend/app/rate_limit.py`'s bucketing scheme exactly.
  """

  @doc """
  Returns `:ok` if `key` is still within `limit` calls in the current
  `window_seconds` bucket, or `{:error, :rate_limited}` once exceeded.
  """
  def enforce_rate_limit(key, limit, window_seconds) do
    bucket = div(System.system_time(:second), window_seconds)
    redis_key = "ratelimit:#{key}:#{bucket}"

    with {:ok, count} <- Redix.command(Stackbox.Redix, ["INCR", redis_key]) do
      if count == 1 do
        Redix.command(Stackbox.Redix, ["EXPIRE", redis_key, window_seconds])
      end

      if count > limit do
        {:error, :rate_limited}
      else
        :ok
      end
    end
  end
end
