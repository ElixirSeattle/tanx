defmodule Tanx.Core.Missle do 
  def start(_type, {time, x, y}) do 

    #We don't want it to link?
    Task.start(fn -> _run_missile(time,x,y))

  end

  defp _run_missile(time, x, y) do


    recieve do ->

      {:updated, }


    end

  end



end
