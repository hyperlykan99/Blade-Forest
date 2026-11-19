-- UIIcons: small icons drawn from UI frames (no image uploads needed).
local M = {}

local function frame(props, parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end
local function round(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = p
end
local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t
	s.Parent = p
end

-- A cartoon log: bark body with a ringed end. `size` = width in pixels.
function M.Log(parent, size, position, anchor, zindex)
	local h = math.floor(size * 0.62)
	local holder = frame({ Name = "LogIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, h),
		Position = position or UDim2.new(), AnchorPoint = anchor or Vector2.new(0, 0.5), ZIndex = zindex or 1 }, parent)
	local body = frame({ Size = UDim2.new(0.82, 0, 0.78, 0), Position = UDim2.new(0, 0, 0.11, 0), BackgroundColor3 = Color3.fromRGB(150, 92, 48), ZIndex = (zindex or 1) }, holder)
	round(body, UDim.new(0.45, 0))
	stroke(body, Color3.fromRGB(80, 45, 20), math.max(1, size / 22))
	for i, y in ipairs({ 0.3, 0.62 }) do
		frame({ Size = UDim2.new(0.5, 0, 0, math.max(1, size / 18)), Position = UDim2.new(0.12 + i * 0.05, 0, y, 0), BackgroundColor3 = Color3.fromRGB(105, 62, 30), ZIndex = (zindex or 1) }, body)
	end
	local cap = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.8, 0, 0.5, 0), Size = UDim2.fromOffset(h, h),
		BackgroundColor3 = Color3.fromRGB(232, 190, 128), ZIndex = (zindex or 1) + 1 }, holder)
	round(cap, UDim.new(1, 0))
	stroke(cap, Color3.fromRGB(120, 72, 32), math.max(1, size / 22))
	local ring = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58),
		BackgroundColor3 = Color3.fromRGB(205, 155, 92), ZIndex = (zindex or 1) + 1 }, cap)
	round(ring, UDim.new(1, 0))
	local dot = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = Color3.fromRGB(232, 190, 128), ZIndex = (zindex or 1) + 1 }, ring)
	round(dot, UDim.new(1, 0))
	return holder
end

return M
