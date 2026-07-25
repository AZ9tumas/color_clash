local Typewriter = {}

function Typewriter.Typewrite(textLabel, text, speed)
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0

	local len = utf8.len(textLabel.ContentText)
	if not len or len == 0 then
		textLabel.MaxVisibleGraphemes = -1
		return
	end

	for i = 1, len do
		textLabel.MaxVisibleGraphemes = i
		task.wait(speed)
	end
	
	textLabel.MaxVisibleGraphemes = -1
end

function Typewriter.CountUp(startVal, endVal, duration, callback)
	if startVal == endVal then
		callback(endVal)
		return
	end
	
	local steps = math.max(10, math.floor(duration * 30))
	for i = 1, steps do
		local current = startVal + (endVal - startVal) * (i / steps)
		callback(current)
		task.wait(duration / steps)
	end
	callback(endVal)
end

return Typewriter