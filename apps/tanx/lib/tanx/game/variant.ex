defprotocol Tanx.Game.Variant do
  def init_arena(data, time)
  def view(data, arena, time, view_context)
  def control(data, params)
  def event(data, event)
end
