defmodule Tanx.Core.Tank do

  defstruct t: 0, x: 0.0, y: 0.0, a: 0.0, v: 0.0, av: 0.0

  def init(time, x, y) do
    %Tanx.Core.Tank{t: time, x: x, y: y}
  end


  defimpl Tanx.Core.Object do

    def view(object) do
      %Tanx.Core.View.Tank{x: object.x, y: object.y, a: object.a, v: object.v, av: object.av}
    end

    def update(object, time, params \\ []) do
      # TODO: Update position/heading
      # TODO: Respond to velocity and angular velocity changes.
      %Tanx.Core.Tank{object | t: time}
    end

  end

end
