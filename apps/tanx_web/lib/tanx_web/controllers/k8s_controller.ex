defmodule TanxWeb.K8sController do
  use TanxWeb, :controller

  def ready(conn, _params) do
    text(conn, "ok")
  end

  def live(conn, _params) do
    text(conn, "ok")
  end

  def pre_stop(conn, _params) do
    #Tanx.Cluster.stop()
    text(conn, "ok")
  end
end
