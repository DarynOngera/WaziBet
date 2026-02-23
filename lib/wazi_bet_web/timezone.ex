defmodule WaziBetWeb.Timezone do
  @moduledoc """
  Timezone helper functions.
  Currently hardcoded to UTC+3 (Africa/Nairobi).
  """

  @utc_offset 3

  @doc """
  Get the configured timezone.
  """
  def timezone, do: "Africa/Nairobi"

  @doc """
  Get the UTC offset in hours.
  """
  def utc_offset, do: @utc_offset

  @doc """
  Convert UTC DateTime to local timezone (UTC+3).
  """
  def to_local(%DateTime{} = utc_datetime) do
    DateTime.add(utc_datetime, @utc_offset * 3600, :second)
  end

  def to_local(%NaiveDateTime{} = utc_datetime) do
    NaiveDateTime.add(utc_datetime, @utc_offset * 3600, :second)
  end

  @doc """
  Get current time in local timezone.
  """
  def local_now do
    DateTime.add(DateTime.utc_now(), @utc_offset * 3600, :second)
  end

  @doc """
  Get current UTC time.
  """
  def utc_now do
    DateTime.utc_now()
  end

  @doc """
  Convert local datetime input to UTC for storage.
  When admin selects "15:00" in datetime picker (local time),
  convert to UTC for storage.
  Returns a DateTime in UTC.
  """
  def to_utc(%DateTime{} = local_datetime) do
    DateTime.add(local_datetime, -@utc_offset * 3600, :second)
  end

  def to_utc(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.add(-@utc_offset * 3600, :second)
  end
end
