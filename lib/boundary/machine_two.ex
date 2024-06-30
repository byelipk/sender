defmodule Sender.Boundary.MachineTwo do
  use GenServer

  # Client API
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def transition(next_state) do
    GenServer.cast(__MODULE__, {:transition, next_state})
  end

  def send_message(%{type: type, data: data}) do
    GenServer.cast(__MODULE__, {:send_message, type, data})
  end

  def send_message(%{type: type}) do
    GenServer.cast(__MODULE__, {:send_message, type})
  end

  # Server API

  def init(_) do
    IO.puts("Initializing machine...")
    {:ok, %{value: "Idle"}}
  end

  def handle_call(:get_state, _from, state) do
    IO.puts("Getting state...")
    {:reply, state, state}
  end

  def handle_cast({:transition, "Running"}, %{value: "Idle"} = state) do
    IO.puts("Running machine...")
    {:noreply, %{state | value: "Running"}}
  end

  def handle_cast({:transition, "Stopped"}, %{value: "Running"} = state) do
    IO.puts("Stopping machine...")
    {:noreply, %{state | value: "Stopped"}}
  end

  def handle_cast({:transition, "Running"}, %{value: "Stopped"} = state) do
    IO.puts("Restarting machine...")
    {:noreply, %{state | value: "Running"}}
  end

  def handle_cast({:transition, "Running"}, %{value: "Ponging"} = state) do
    IO.puts("Back in action...")
    {:noreply, %{state | value: "Running"}}
  end

  def handle_cast({:transition, "Ponging"}, %{value: "Running"} = state) do
    IO.puts("Ponging...")
    {:noreply, %{state | value: "Ponging"}}
  end

  def handle_cast({:transition, invalid}, state) do
    IO.puts("Invalid transition: #{state.value} -> #{invalid}")
    {:noreply, state}
  end

  def handle_cast({:send_message, "PING"}, %{value: "Running"} = state) do
    Task.Supervisor.start_child(
      Sender.TaskSupervisor,
      fn ->
        IO.puts("About to pong...")
        Process.sleep(3000)
        IO.puts("Fin with pong...")
        __MODULE__.transition("Running")
      end
    )

    transition("Ponging")

    {:noreply, state}
  end

  def handle_cast({:send_message, "PING"}, state) do
    IO.puts("Bad call: #{state.value} // PING")
    {:noreply, state}
  end

  def handle_cast({:send_message, "STOP"}, %{value: "Running"} = state) do
    transition("Stopped")
    {:noreply, state}
  end

  def handle_cast({:send_message, "START"}, %{value: "Idle"} = state) do
    transition("Running")
    {:noreply, state}
  end

  def handle_cast({:send_message, "START"}, %{value: "Stopped"} = state) do
    transition("Running")
    {:noreply, state}
  end

  def handle_cast({:send_message, invalid}, state) do
    IO.puts("Invalid message: #{state.value} -> #{invalid}")
    {:noreply, state}
  end
end
