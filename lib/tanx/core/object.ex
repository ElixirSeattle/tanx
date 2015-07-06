defprotocol Tanx.Core.Object do
  def view(object)
  def update(object, time)
  def control(object, params)
end
