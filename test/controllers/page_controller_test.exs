defmodule Tanx.PageControllerTest do
  use Tanx.ConnCase

  test "GET /" do
    conn = get conn(), "/"
    assert html_response(conn, 200) =~ "Welcome to Elixir Tanx"
  end
end
