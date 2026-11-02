defmodule VaderBackendWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug VaderBackendWeb.OperatorAuth
  end

  scope "/api/v1", VaderBackendWeb do
    pipe_through :api
    get "/snapshot", FleetController, :snapshot
    get "/machines", FleetController, :machines
    get "/machines/:machine_id/inventory", FleetController, :inventory
    get "/orders", FleetController, :orders
  end
end
