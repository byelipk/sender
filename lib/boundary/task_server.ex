defmodule Sender.Boundary.TaskServer do
  use GenServer

  @initial_state %{
    concurrency: 4,
    q: :queue.new(),
    tasks: %{},
    products: %{},
    media: %{},
    stages: %{}
  }

  # Client API

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def start_task(handle) do
    GenServer.call(__MODULE__, {:start_task, handle})
  end

  def get do
    GenServer.call(__MODULE__, :get_state)
  end

  def clear do
    GenServer.cast(__MODULE__, :reset_state)
  end

  # Server API

  @impl true
  def init(_init_args) do
    {:ok, @initial_state}
  end

  @impl true
  def handle_call({:start_task, handle}, _from, state) do
    case Map.fetch(state.products, handle) do
      {:ok, _product} ->
        IO.puts("Product already exists for #{handle}")
        state = put_in(state.stages[handle], :product)
        {:reply, :ok, state, {:continue, {:get_media, handle}}}

      :error ->
        IO.puts("Looking up product for #{handle}...")
        state = put_in(state.stages[handle], :initial)
        {:reply, :ok, state, {:continue, {:get_product, handle}}}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:reset_state, state) do
    tasks = state.tasks

    Enum.each(tasks, fn {ref, _} ->
      Process.demonitor(ref, [:flush])
    end)

    {:noreply, @initial_state}
  end

  @impl true
  def handle_info({ref, result}, state) do
    # The task succeeded so we can demonitor its reference
    Process.demonitor(ref, [:flush])

    {handle, state} = pop_in(state.tasks[ref])

    case result do
      {:not_found, "product", "get", _} ->
        IO.puts("Product not found for #{handle}")

        {
          :noreply,
          state,
          {:continue, {:create_product, handle, %{name: "My Product"}}}
        }

      {:ok, "product", "create", product} ->
        IO.puts("Product created for #{handle}")

        state = put_in(state.products[handle], product)
        state = put_in(state.stages[handle], :product)

        {:noreply, state, {:continue, {:create_media, handle}}}

      {:error, "product", "create", _} ->
        IO.puts("Product creation failed for #{handle}")
        IO.puts("Nothing left to do.")

        {:noreply, state}

      {:ok, "product", "get", product} ->
        IO.puts("Product found for #{handle}")

        state = put_in(state.products[handle], product)
        state = put_in(state.stages[handle], :product)

        {:noreply, state, {:continue, {:get_media, handle}}}

      {:not_found, "media", "get", _} ->
        IO.puts("Media not found for #{handle}")

        {:noreply, state, {:continue, {:create_media, handle}}}

      {:ok, "media", "get", media} ->
        IO.puts("Media found for #{handle}")

        state = put_in(state.media[handle], media)
        state = put_in(state.stages[handle], :media)

        IO.puts("Nothing left to do.")

        {:noreply, state}

      {:ok, "media", "create", _} ->
        IO.puts("Media created for #{handle}")
        IO.puts("Nothing left to do.")

        state = put_in(state.stages[handle], :media)

        {:noreply, state}

      {:error, "media", "create", _} ->
        IO.puts("Media creation failed for #{handle}")
        IO.puts("All done.")
        state = put_in(state.stages[handle], :media)

        {:noreply, state}

      _ ->
        raise "Unknown task result"
    end
  end

  @impl true
  def handle_info({:DOWN, ref, _, _, reason}, state) do
    {handle, state} = pop_in(state.tasks[ref])

    IO.puts("Task failed for #{handle} with reason #{inspect(reason)}")

    current_stage = state.stages[handle]
    state = put_in(state.stages[handle], {current_stage, :failed, reason})

    {:noreply, state}
  end

  @impl true
  def handle_continue({:get_product, handle}, state) do
    new_state =
      create_faux_supervised_task(state, handle, fn ->
        Process.sleep(3000)

        case :rand.uniform(2) do
          1 ->
            {
              :ok,
              "product",
              "get",
              %{name: "My Product", handle: handle}
            }

          2 ->
            {
              :not_found,
              "product",
              "get",
              nil
            }
        end
      end)

    # Here we will wait for the task to complete and then handle the result
    # in our `handle_info` handler.
    {:noreply, new_state}
  end

  @impl true
  def handle_continue({:get_media, handle}, state) do
    %{name: name} = state.products[handle]

    case Map.fetch(state.media, handle) do
      {:ok, _media} ->
        IO.puts("Media already exists for #{handle}")
        {:noreply, state}

      :error ->
        IO.puts("Looking up media for #{handle}...")

        new_state =
          create_faux_supervised_task(state, handle, fn ->
            Process.sleep(3000)

            case :rand.uniform(2) do
              1 ->
                {
                  :ok,
                  "media",
                  "get",
                  %{name: name <> ".jpg", product_handle: handle}
                }

              2 ->
                {
                  :not_found,
                  "media",
                  "get",
                  nil
                }
            end
          end)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_continue({:create_media, handle}, state) do
    %{name: name} = state.products[handle]

    new_state =
      create_faux_supervised_task(state, handle, fn ->
        Process.sleep(3000)

        case :rand.uniform(2) do
          1 ->
            {:ok, "media", "create", %{name: name <> ".jpg", product_handle: handle}}

          2 ->
            {:error, "media", "create", %{errors: ["lolz"]}}
        end
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_continue({:create_product, handle, data}, state) do
    new_state =
      create_faux_supervised_task(state, handle, fn ->
        Process.sleep(3000)

        case :rand.uniform(2) do
          1 ->
            {:ok, "product", "create", data}

          2 ->
            raise "Product creation failed"
            # {:error, "product", "create", %{errors: ["lolz"]}}
        end
      end)

    {:noreply, new_state}
  end

  defp create_faux_supervised_task(state, value, fun) do
    task = Task.Supervisor.async_nolink(Sender.TaskSupervisor, fun)

    new_state = put_in(state.tasks[task.ref], value)

    new_state
  end
end
