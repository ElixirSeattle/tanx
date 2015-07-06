defmodule Tanx.Core.Tank do

  defstruct t: 0, x: 0.0, y: 0.0, a: 0.0, v: 0.0, av: 0.0

  def init(time, x, y) do
    %Tanx.Core.Tank{t: time, x: x, y: y}
  end


  defimpl Tanx.Core.Object do

    def view(object) do
      %Tanx.Core.View.Tank{x: object.x, y: object.y, a: object.a, v: object.v, av: object.av}
    end

    def update(object, time) do
      dt = max((time - object.t) / 1000, 0.0)
      a = object.a
      v = object.v
      na = a + object.av * dt
      nx = object.x + v * dt * :math.cos(a)
      ny = object.y + v * dt * :math.sin(a)
      %Tanx.Core.Tank{object | t: time, x: nx, y: ny, a: na}
    end

    def control(object, params) do
      v = params[:v] || object.v
      av = params[:av] || object.av
      %Tanx.Core.Tank{object | v: v, av: av}
    end

  end

end
