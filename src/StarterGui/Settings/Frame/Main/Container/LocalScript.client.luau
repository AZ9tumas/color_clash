local barSize = UDim.new(0.02075, 0)

local scrollingFrame = script.Parent
local scrollingFrameParent = script.Parent.Parent

local function update()
	scrollingFrame.ScrollBarThickness = scrollingFrameParent.AbsoluteSize.X * barSize.Scale + barSize.Offset
end

update()
scrollingFrameParent:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)