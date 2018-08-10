defmodule TanxWeb.Router do
  use TanxWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", TanxWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    # TEMP
    get("/readyz", PageController, :ready)
  end

  scope "/k8s", TanxWeb do
    pipe_through(:api)

    get("/ready", K8sController, :ready)
    get("/live", K8sController, :live)
    get("/pre-stop", K8sController, :pre_stop)
  end
end
