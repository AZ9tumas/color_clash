local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HapticService = game:GetService("HapticService")

local Shared = ReplicatedStorage.Shared
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local WeaponClient = require(Shared.Classes.WeaponClient)
local CrosshairController = require(Shared.UIControllers.CrosshairController)
local SettingsController = require(Shared.UIControllers.SettingsController)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

local CombatClient = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local activeWeapons = setmetatable({}, {__mode = "k"})
local equippedWeapon = nil

local currentRecoil = 0
local targetRecoil = 0
local currentSwayX, currentSwayY = 0, 0

local function addRecoil(amount)
	targetRecoil = targetRecoil + amount
	
	if SettingsController.GetValue("Controller Vibration") then
		pcall(function()
			if HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, math.min(1, amount * 15))
				task.delay(0.15, function()
					HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
				end)
			end
		end)
	end
end

local function setupTool(tool)
	if not tool:IsA("Tool") then return end
	if activeWeapons[tool] then return end 
	
	local weapon = WeaponClient.new(tool, addRecoil)
	activeWeapons[tool] = weapon

	tool.Equipped:Connect(function() equippedWeapon = weapon end)
	tool.Unequipped:Connect(function() if equippedWeapon == weapon then equippedWeapon = nil end end)
end

function CombatClient.Init()
	CrosshairController.SetCrosshairVisible(false)

	CombatRemotes.GetDamageVFX().OnClientEvent:Connect(function(position, damage, hitPart, hitNormal)
		local isHeadshot = hitPart and string.find(string.lower(hitPart.Name), "head") ~= nil
		
		if hitPart then
			CrosshairController.ShowHitMarker(isHeadshot and 2 or 1)
		end
		
		local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder") or Instance.new("Folder", Workspace)
		debrisFolder.Name = "WallDebrisFolder"
		
		local numberPart = Instance.new("Part")
		numberPart.Name = "DamageNumberPart"
		numberPart.Size = Vector3.new(0.01, 0.01, 0.01)
		numberPart.CFrame = CFrame.new(position)
		numberPart.Anchored = true
		numberPart.CanCollide = false
		numberPart.Transparency = 1
		numberPart.Parent = debrisFolder
		
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(1.3, 1.3)
		billboard.StudsOffset = Vector3.new(math.random(-15, 15)/10, math.random(5, 15)/10, math.random(-15, 15)/10)
		billboard.AlwaysOnTop = true
		billboard.Parent = numberPart
		
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.Position = UDim2.fromScale(0.5, 0.5)
		textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = tostring(math.floor(tonumber(damage) or 0))
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextScaled = true
		textLabel.Rotation = math.random(-12, 12) 
		
		if isHeadshot then
			textLabel.TextColor3 = Color3.fromRGB(255, 30, 30)
			local grad = Instance.new("UIGradient", textLabel)
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 15, 15)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 85, 85))
			})
			grad.Rotation = 90
		else
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Color = Color3.fromRGB(20, 0, 0)
		uiStroke.Thickness = isHeadshot and 3.5 or 2.0
		uiStroke.Parent = textLabel
		textLabel.Parent = billboard
		
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0
		uiScale.Parent = textLabel
		
		local popTarget = isHeadshot and 1.7 or 1.2
		TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = popTarget}):Play()
		
		task.delay(0.2, function()
			if not uiScale or not uiScale.Parent then return end
			
			TweenService:Create(billboard, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				StudsOffset = billboard.StudsOffset + Vector3.new(0, 3.5, 0)
			}):Play()
			
			TweenService:Create(uiScale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				Scale = isHeadshot and 0.85 or 0.6
			}):Play()
			
			TweenService:Create(textLabel, TweenInfo.new(0.55, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
				TextTransparency = 1
			}):Play()
			
			TweenService:Create(uiStroke, TweenInfo.new(0.55, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
				Transparency = 1
			}):Play()
		end)
		
		game.Debris:AddItem(numberPart, 0.9)
		
		if SettingsController.GetValue("Blood Effects") then
			local holeColor = Color3.fromRGB(60, 0, 0)
			local splatterColor = Color3.fromRGB(170, 0, 0)
			
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {player.Character, debrisFolder}
			
			if hitPart and hitNormal then
				local hole = Instance.new("Part")
				hole.Shape = Enum.PartType.Cylinder
				local r = math.random(5, 8) / 10
				hole.Size = Vector3.new(0.02, r, r)
				hole.Color = holeColor
				hole.Material = Enum.Material.SmoothPlastic
				hole.Anchored = false
				hole.CanCollide = false
				hole.CanQuery = false
				hole.CanTouch = false
				hole.Massless = true
				
				local pPos = position + (hitNormal * 0.01)
				local right = hitNormal
				local up = (math.abs(right.Y) > 0.99) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
				local back = right:Cross(up).Unit
				up = back:Cross(right).Unit
				
				hole.CFrame = CFrame.fromMatrix(pPos, right, up, back)
				hole.Parent = debrisFolder

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hitPart
				weld.Part1 = hole
				weld.Parent = hole
				
				task.delay(1.5, function()
					if hole and hole.Parent then
						local tw = TweenService:Create(hole, TweenInfo.new(0.5), {Transparency = 1})
						tw:Play()
						tw.Completed:Connect(function() hole:Destroy() end)
					end
				end)
			end

			local damageVal = tonumber(damage) or 15
			local numDrops = math.clamp(math.floor(damageVal / 5), 3, 6)
			
			for i = 1, numDrops do
				local chunk = Instance.new("Part")
				chunk.Size = Vector3.new(0.25, 0.25, 0.25)
				chunk.Color = splatterColor
				chunk.Material = Enum.Material.SmoothPlastic
				chunk.Anchored = true
				chunk.CanCollide = false
				chunk.CanQuery = false
				chunk.CanTouch = false
				chunk.CFrame = CFrame.new(position)
				chunk.Parent = debrisFolder
				
				local pushNormal = hitNormal or Vector3.new(0, 1, 0)
				local splatVelocity = (pushNormal * math.random(15, 25)) + Vector3.new(
					math.random(-10, 10),
					math.random(5, 15),
					math.random(-10, 10)
				)
				
				task.spawn(function()
					local pCur = position
					local alive = true
					local st = 0
					local sGravity = Vector3.new(0, -60, 0)
					
					while alive and st < 1.5 do
						local dt = RunService.RenderStepped:Wait()
						st += dt
						
						local nextPos = pCur + (splatVelocity * dt)
						splatVelocity = splatVelocity + (sGravity * dt)
						
						local result = Workspace:Raycast(pCur, nextPos - pCur, params)
						
						if result then
							alive = false
							chunk:Destroy()
							
							local puddle = Instance.new("Part")
							puddle.Shape = Enum.PartType.Cylinder
							local radius = math.random(5, 12) / 10
							puddle.Size = Vector3.new(0.02, radius, radius)
							puddle.Color = splatterColor
							puddle.Material = Enum.Material.SmoothPlastic
							puddle.Anchored = true
							puddle.CanCollide = false
							puddle.CanQuery = false
							puddle.CanTouch = false
							
							local ppPos = result.Position + result.Normal * 0.01
							
							local rightVec = result.Normal
							local upVec = (math.abs(rightVec.Y) > 0.99) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
							local backVec = rightVec:Cross(upVec).Unit
							upVec = backVec:Cross(rightVec).Unit
							
							puddle.CFrame = CFrame.fromMatrix(ppPos, rightVec, upVec, backVec)
							puddle.Parent = debrisFolder
							
							task.delay(math.random(3, 5), function()
								if puddle and puddle.Parent then
									local tw = TweenService:Create(puddle, TweenInfo.new(1.5), {Transparency = 1})
									tw:Play()
									tw.Completed:Connect(function() puddle:Destroy() end)
								end
							end)
						else
							pCur = nextPos
							chunk.CFrame = CFrame.new(pCur)
						end
					end
					
					if alive then chunk:Destroy() end
				end)
			end
		end
	end)

	RoundRemotes.GetKillFeedEvent().OnClientEvent:Connect(function(killerName, victimName)
		if killerName == player.Name then
			CrosshairController.ShowHitMarker(3)
		end
	end)

	CombatRemotes.GetBulletTracer().OnClientEvent:Connect(function(origin, targetPos)
		local distance = (targetPos - origin).Magnitude
		if distance < 0.1 then return end

		FXUtil.MuzzleFlash(origin)

		local tracer = Instance.new("Part")
		tracer.Name = "Tracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.new(1, 0.9, 0.5)
		tracer.Transparency = 0.2
		tracer.Size = Vector3.new(0.1, 0.1, distance)
		tracer.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
		
		local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder") or Instance.new("Folder", Workspace)
		debrisFolder.Name = "WallDebrisFolder"
		tracer.Parent = debrisFolder
		
		local tween = TweenService:Create(tracer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1, Size = Vector3.new(0, 0, distance)
		})
		tween:Play()
		tween.Completed:Connect(function() tracer:Destroy() end)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local isAlive = humanoid and humanoid.Health > 0

		local isFirstPerson = false
		if isAlive and camera.CameraType == Enum.CameraType.Custom then
			local distance = (camera.Focus.Position - camera.CFrame.Position).Magnitude
			if distance < 1.25 then
				isFirstPerson = true
			end
		end

		if SettingsController.GetValue("Camera Shake") then
			local prev = currentRecoil
			currentRecoil = currentRecoil + (targetRecoil - currentRecoil) * math.min(1, dt * 18)
			targetRecoil = targetRecoil * (1 - dt * 9)

			local delta = currentRecoil - prev
			if math.abs(delta) > 0.00005 then
				camera.CFrame = camera.CFrame * CFrame.Angles(-delta, 0, 0)
			end
		else
			targetRecoil = 0
			currentRecoil = 0
		end
		
		if isFirstPerson and isAlive then
			local targetSwayX = 0
			local targetSwayY = 0
			
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				local md = UserInputService:GetMouseDelta()
				targetSwayX = math.clamp(-md.X * 0.035, -2, 2)
				targetSwayY = math.clamp(-md.Y * 0.035, -2, 2)
			end
			
			currentSwayX = currentSwayX + (targetSwayX - currentSwayX) * math.min(1, dt * 8)
			currentSwayY = currentSwayY + (targetSwayY - currentSwayY) * math.min(1, dt * 8)

			local walkSpeedRatio = root.AssemblyLinearVelocity.Magnitude / 22
			local bobVal = math.sin(tick() * 12) * math.clamp(walkSpeedRatio * 0.015, 0, 0.06)
			
			camera.CFrame = camera.CFrame 
				* CFrame.Angles(math.rad(currentSwayY), math.rad(currentSwayX), 0)
				* CFrame.new(0, bobVal, 0)
			
			for _, p in char:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					local pName = p.Name
					if p.Parent:IsA("Accessory") or string.find(pName, "Head") or string.find(pName, "Torso") then
						p.LocalTransparencyModifier = 1
					else
						p.LocalTransparencyModifier = 0
					end
				end
			end
		else
			currentSwayX = 0
			currentSwayY = 0
			if char then
				for _, p in char:GetDescendants() do
					if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
						p.LocalTransparencyModifier = 0
					end
				end
			end
		end

		local shouldForceManualRot = false
		if player:GetAttribute("InMenu") == false then
			shouldForceManualRot = (equippedWeapon ~= nil) or isFirstPerson
		end

		local moveState = player:GetAttribute("MovementState")

		if shouldForceManualRot then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

			if root and isAlive then
				humanoid.AutoRotate = false

				local camLook = camera.CFrame.LookVector
				local targetLook = Vector3.new(camLook.X, 0, camLook.Z).Unit

				local isCustomMoving = moveState == "Slide" or (moveState and string.find(moveState, "WallRun"))

				if targetLook.Magnitude > 0.001 and not isCustomMoving then
					local targetRot = CFrame.lookAt(Vector3.zero, targetLook)
					
					if isFirstPerson then
						root.CFrame = CFrame.new(root.Position) * targetRot
					else
						local currentRot = root.CFrame - root.Position
						local newRot = currentRot:Lerp(targetRot, math.min(1, dt * 30))
						root.CFrame = CFrame.new(root.Position) * newRot
					end
				end
			end
		else
			if not isFirstPerson and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			
			if humanoid then
				local isCustomMoving = false
				if moveState then
					isCustomMoving = string.find(moveState, "WallRun") or moveState == "Slide"
				end
				
				if not isCustomMoving then
					humanoid.AutoRotate = true
				end
			end
		end

		if humanoid then
			local targetCamOffset = Vector3.zero
			if isAlive and player:GetAttribute("IsPlaying") == true then
				if isFirstPerson then
					if moveState == "Slide" then
						targetCamOffset = Vector3.new(0, -2, 0)
					else
						targetCamOffset = Vector3.zero
					end
				elseif equippedWeapon then
					targetCamOffset = Vector3.new(1.75, 0, 0)
				end
			end
			
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetCamOffset, math.min(1, dt * 15))
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.R and equippedWeapon then
			equippedWeapon:Reload()
		end
	end)

	local function onCharacterAdded(character)
		character.ChildAdded:Connect(setupTool)
		for _, child in character:GetChildren() do setupTool(child) end
	end

	if player.Character then onCharacterAdded(player.Character) end
	player.CharacterAdded:Connect(onCharacterAdded)

	player.Backpack.ChildAdded:Connect(setupTool)
	for _, child in player.Backpack:GetChildren() do setupTool(child) end
end

return CombatClient