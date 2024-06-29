defmodule Sender.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Sender.Worker.start_link(arg)
      {Sender.Boundary.Machine, []},
      {Sender.Boundary.Server, []},
      {Sender.Boundary.Counter, 0},
      {Sender.Boundary.TaskServer, [name: Sender.Boundary.TaskServer]},
      {Task.Supervisor, [name: Sender.TaskSupervisor]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sender.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
