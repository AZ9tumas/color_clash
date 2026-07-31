local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Modules.Core.MapConfig)

local MapMechanic = {}

local TEMPLATE_FOLDER = "MapTemplates"
local rng = Random.new()

local templateFolder = nil
local variantNames = {}

-- Colour layout.
--
-- The grid is tiled with 2x2 blocks and each full block gets a permutation of all four
-- colours, so every aligned 2x2 block contains exactly one of each. That is the property
-- that keeps the map fair: wherever a player is standing, a cell of the called colour is
-- at most one cell away.
--
-- Blocks that fall off the edge on an odd row or column are partial. Those take the
-- globally scarcest colours instead, which keeps the total per colour within one of even.
function MapMechanic.BuildLayout(rows, cols, colorOrder, attempts, random)
	random = random or rng
	attempts = math.max(1, attempts or 1)

	local grid = {}
	for r = 1, rows do grid[r] = {} end

	local counts = {}
	for _, name in colorOrder do counts[name] = 0 end

	local function shuffled(list)
		local copy = table.clone(list)
		for i = #copy, 2, -1 do
			local j = random:NextInteger(1, i)
			copy[i], copy[j] = copy[j], copy[i]
		end
		return copy
	end

	local function scarcest(k)
		local pool = table.clone(colorOrder)
		local tieBreak = {}
		for _, name in pool do tieBreak[name] = random:NextNumber() end

		table.sort(pool, function(a, b)
			if counts[a] ~= counts[b] then return counts[a] < counts[b] end
			return tieBreak[a] < tieBreak[b]
		end)

		local picked = {}
		for i = 1, k do table.insert(picked, pool[i]) end
		return picked
	end

	for r0 = 1, rows, 2 do
		for c0 = 1, cols, 2 do
			local cells = {}
			for r = r0, math.min(r0 + 1, rows) do
				for c = c0, math.min(c0 + 1, cols) do
					table.insert(cells, { r = r, c = c })
				end
			end

			local palette = (#cells == #colorOrder) and colorOrder or scarcest(#cells)

			local bestPerm, bestScore = nil, nil
			for _ = 1, attempts do
				local perm = shuffled(palette)

				local function colorAt(r, c)
					if grid[r] and grid[r][c] then return grid[r][c] end
					for i, cell in cells do
						if cell.r == r and cell.c == c then return perm[i] end
					end
					return nil
				end

				local score = 0
				for i, cell in cells do
					if colorAt(cell.r, cell.c - 1) == perm[i] then score += 1 end
					if colorAt(cell.r - 1, cell.c) == perm[i] then score += 1 end
				end

				if not bestScore or score < bestScore then
					bestScore, bestPerm = score, perm
					if score == 0 then break end
				end
			end

			for i, cell in cells do
				grid[cell.r][cell.c] = bestPerm[i]
				counts[bestPerm[i]] += 1
			end
		end
	end

	return grid, counts
end

-- Harvests one pristine copy of every cell variant before anything regenerates, so the
-- authored geometry survives even though Generate() destroys the live cells.
function MapMechanic.Init()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("[Map] Workspace.Map not found, templates not harvested")
		return false
	end

	local existing = ServerStorage:FindFirstChild(TEMPLATE_FOLDER)
	if existing then existing:Destroy() end

	templateFolder = Instance.new("Folder")
	templateFolder.Name = TEMPLATE_FOLDER
	templateFolder.Parent = ServerStorage

	for _, folder in map:GetChildren() do
		if folder:IsA("Folder") then
			for _, cell in folder:GetChildren() do
				if cell:IsA("Model") and not templateFolder:FindFirstChild(cell.Name) then
					cell:Clone().Parent = templateFolder
				end
			end
		end
	end

	variantNames = {}
	for _, t in templateFolder:GetChildren() do table.insert(variantNames, t.Name) end
	table.sort(variantNames)

	if #variantNames == 0 then
		warn("[Map] no cell variants found under Workspace.Map, regeneration disabled")
		return false
	end

	return true
end

function MapMechanic.Generate()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("[Map] Workspace.Map not found, skipping regeneration")
		return false
	end

	-- Never tear the map down unless we can rebuild it.
	if #variantNames == 0 then
		warn("[Map] no templates harvested, skipping regeneration")
		return false
	end

	-- Validate the templates BEFORE destroying anything, so a missing or detached folder
	-- can never leave the arena torn down. Re-harvest from the live map if needed.
	local usable = {}
	if templateFolder and templateFolder.Parent then
		for _, name in variantNames do
			local template = templateFolder:FindFirstChild(name)
			if template then table.insert(usable, template) end
		end
	end

	if #usable == 0 then
		warn("[Map] template folder is empty or detached, re-harvesting")
		if not MapMechanic.Init() then return false end
		for _, name in variantNames do
			local template = templateFolder:FindFirstChild(name)
			if template then table.insert(usable, template) end
		end
	end

	if #usable == 0 then
		warn("[Map] still no usable templates, skipping regeneration")
		return false
	end

	local rows, cols = MapConfig.Rows, MapConfig.Cols
	if rows < 1 or cols < 1 then
		warn("[Map] MapConfig.Rows/Cols must be at least 1, skipping regeneration")
		return false
	end

	-- Drop folders for colours that are no longer configured, then clear the rest so the
	-- Map -> colour Folder -> cell Model hierarchy is preserved exactly.
	for _, child in map:GetChildren() do
		if child:IsA("Folder") and not MapConfig.Colors[child.Name] then child:Destroy() end
	end

	for _, name in MapConfig.ColorOrder do
		local folder = map:FindFirstChild(name)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = map
		end
		for _, cell in folder:GetChildren() do cell:Destroy() end
	end

	local grid = MapMechanic.BuildLayout(rows, cols, MapConfig.ColorOrder, MapConfig.LayoutAttempts, rng)

	local originX = MapConfig.Center.X - (cols * MapConfig.CellPitchX) / 2
	local originZ = MapConfig.Center.Z - (rows * MapConfig.CellPitchZ) / 2

	for r = 1, rows do
		for c = 1, cols do
			local colorName = grid[r][c]
			local clone = usable[rng:NextInteger(1, #usable)]:Clone()

			local tint = MapConfig.Colors[colorName]
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then d.Color = tint end
			end

			-- Only slide in X/Z: each variant's authored height above the ground plane
			-- is part of its design and must be preserved.
			local targetX = originX + (c - 0.5) * MapConfig.CellPitchX
			local targetZ = originZ + (r - 0.5) * MapConfig.CellPitchZ
			local box = clone:GetBoundingBox()
			clone:PivotTo(clone:GetPivot() + Vector3.new(targetX - box.Position.X, 0, targetZ - box.Position.Z))

			clone:SetAttribute("GridRow", r)
			clone:SetAttribute("GridCol", c)
			clone:SetAttribute("GridColor", colorName)
			clone.Parent = map[colorName]
		end
	end

	return true
end

return MapMechanic
