defmodule Tanx.PageController do
  use Tanx.Web, :controller

  def index(conn, _params) do
    conn |> render("index.html")
  end
end
