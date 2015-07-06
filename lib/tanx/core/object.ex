defprotocol Tanx.Core.Object do
  def view(object)
  def update(object, clock, params \\ [])
end
