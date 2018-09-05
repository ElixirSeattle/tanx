defprotocol Tanx.Game.Variant do
  def init_arena(data, time)
  def control(data, arena, time, params)
  def event(data, event)
  def stats(data, arena, time)
  def stop(data, arena, time)
end
