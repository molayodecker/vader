defmodule VaderBackend.Application do
  use Application

  @impl true
  def start(_type, _args) do
    database_children =
      if Application.get_env(:vader_backend, :database_url) do
        [{Postgrex, name: VaderBackend.DB, url: Application.fetch_env!(:vader_backend, :database_url), pool_size: 5}]
      else
        []
      end

    children = database_children ++ [
      {Phoenix.PubSub, name: VaderBackend.PubSub},
      VaderBackendWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: VaderBackend.Supervisor)
  end
end
