defmodule Sender.Boundary.Machine do
  use GenServer

  # Client API

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def transition("start") do
    GenServer.cast(__MODULE__, {:transition, "start"})
  end

  def transition("stop") do
    GenServer.cast(__MODULE__, {:transition, "stop"})
  end

  def transition(arg) do
    GenServer.cast(__MODULE__, {:transition, arg})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server API

  def init(_init_args) do
    IO.puts("Initializing machine...")
    {:ok, %{value: "Idle"}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:transition, "start"}, %{value: "Idle"} = state) do
    IO.puts("Starting machine...")
    {:noreply, %{state | value: "Running"}}
  end

  def handle_cast({:transition, "start"}, %{value: "Stopped"} = state) do
    IO.puts("Starting machine...")
    {:noreply, %{state | value: "Running"}}
  end

  def handle_cast({:transition, "stop"}, %{value: "Running"} = state) do
    IO.puts("Stopping machine...")
    {:noreply, %{state | value: "Stopping"}, {:continue, {:transition, "end"}}}
  end

  def handle_cast({:transition, arg}, state) do
    IO.puts("Invalid transition: #{state.value} -> #{arg}")
    {:noreply, state}
  end

  def handle_continue({:transition, "end"}, %{value: "Stopping"} = state) do
    IO.puts("Machine has stopped")
    {:noreply, %{state | value: "Stopped"}}
  end
end
