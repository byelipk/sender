defmodule Sender do
  @moduledoc """
  Documentation for `Sender`.
  """

  @doc """
  Sends an email

  ## Examples

      iex> Sender.send_email("hello@example.com")
      {:ok, "email_sent"}

  """
  def send_email("bad") do
    {:error, "bad_email"}
  end

  @spec send_email(String.t()) :: {:ok, String.t()}
  def send_email(email) do
    Process.sleep(3000)
    IO.puts("Email to #{email} sent")
    {:ok, "email_sent"}
  end
end
