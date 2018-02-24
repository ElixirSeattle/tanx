defmodule TanxWeb.PageControllerTest do
  use TanxWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Elixir Tanx"
  end
end
