defmodule Sender.Boundary.Server do
  use GenServer

  # Client API

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def send(email) do
    GenServer.cast(__MODULE__, {:send, email})
  end

  # Server API

  def init(init_args) do
    IO.puts("Received args: #{inspect(init_args)}")
    max_retries = Keyword.get(init_args, :max_retries, 5)
    state = %{emails: [], max_retries: max_retries}
    Process.send_after(self(), :retry, 5000)
    {:ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:send, email}, state) do
    status =
      case Sender.send_email(email) do
        {:ok, _} -> "sent"
        {:error, _} -> "failed"
      end

    emails = [%{email: email, status: status, retries: 0}] ++ state.emails

    {:noreply, %{state | emails: emails}}
  end

  def handle_info(:retry, state) do
    {failed, done} =
      Enum.split_with(state.emails, fn item ->
        item.status == "failed" && item.retries < state.max_retries
      end)

    retried =
      Enum.map(failed, fn item ->
        IO.puts("Retrying email #{item.email}...")

        new_status =
          case Sender.send_email(item.email) do
            {:ok, _} -> "sent"
            {:error, _} -> "failed"
          end

        %{email: item.email, status: new_status, retries: item.retries + 1}
      end)

    Process.send_after(self(), :retry, 5000)

    {:noreply, %{state | emails: done ++ retried}}
  end

  def terminate(_reason, state) do
    IO.puts("Terminating with state: #{inspect(state)}")
  end
end
