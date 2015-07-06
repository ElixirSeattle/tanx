defmodule Tanx.PageController do
  use Tanx.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
