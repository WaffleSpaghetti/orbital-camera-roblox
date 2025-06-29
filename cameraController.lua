-- this should be a local script!!!

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

-- Quaternion helpers
local function Q(r, i, j, k)
	local Quat = { R = r, I = i, J = j, K = k }
	setmetatable(Quat, {
		__mul = function(a, b)
			local function toQ(x) return type(x) == "number" and Q(x, 0, 0, 0) or x end
			a, b = toQ(a), toQ(b)
			return Q(
				a.R * b.R - a.I * b.I - a.J * b.J - a.K * b.K,
				a.R * b.I + a.I * b.R + a.J * b.K - a.K * b.J,
				a.R * b.J - a.I * b.K + a.J * b.R + a.K * b.I,
				a.R * b.K + a.I * b.J - a.J * b.I + a.K * b.R
			)
		end,
	})
	return Quat
end

local function axisAngle(axis, angle)
	local half = angle / 2
	local s = math.sin(half)
	local c = math.cos(half)
	return Q(c, s * axis.x, s * axis.y, s * axis.z)
end

local function conj(q)
	return Q(q.R, -q.I, -q.J, -q.K)
end

local function rotate(q, v)
	local qv = Q(0, v.x, v.y, v.z)
	local q_conj = conj(q)
	local rotated = q * qv * q_conj
	return Vector3.new(rotated.I, rotated.J, rotated.K)
end

local function normalize(q)
	local mag = math.sqrt(q.R^2 + q.I^2 + q.J^2 + q.K^2)
	return Q(q.R / mag, q.I / mag, q.J / mag, q.K / mag)
end

-- Toggles
local useMouseControl = true

-- State
local qRot = Q(1, 0, 0, 0)
local rotating = false
local sensitivity = 0.003
local keyboardStep = 0.05
local radius = 100
local target = Vector3.new(0, 0, 0)

local function reset()
	qRot = Q(1, 0, 0, 0)
end

-- Keyboard input
local keysPressed = {}

local function isControlKey(key)
	return key == Enum.KeyCode.Y or key == Enum.KeyCode.H or
		key == Enum.KeyCode.G or key == Enum.KeyCode.J or
		key == Enum.KeyCode.T or key == Enum.KeyCode.U
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.M then
		useMouseControl = not useMouseControl
		print("Mouse Control:", useMouseControl)
	end
	if input.KeyCode == Enum.KeyCode.R then
		reset()
		print("Reset")
	end

	if isControlKey(input.KeyCode) then
		keysPressed[input.KeyCode] = true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isControlKey(input.KeyCode) then
		keysPressed[input.KeyCode] = false
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rotating = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not useMouseControl or not rotating or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

	local dx = -input.Delta.X * sensitivity
	local dy = input.Delta.Y * sensitivity

	-- ALWAYS relative axes
	local upAxis = rotate(qRot, Vector3.new(0, 1, 0))
	local rightAxis = rotate(qRot, Vector3.new(1, 0, 0))

	local qYaw = axisAngle(upAxis, dx)
	local qPitch = axisAngle(rightAxis, dy)

	qRot = qYaw * qPitch * qRot
end)

-- Keyboard control handling
RunService.RenderStepped:Connect(function()
	if not useMouseControl then
		local upAxis = rotate(qRot, Vector3.new(0, 1, 0))
		local rightAxis = rotate(qRot, Vector3.new(1, 0, 0))
		local forwardAxis = rotate(qRot, Vector3.new(0, 0, 1))

		if keysPressed[Enum.KeyCode.G] then
			qRot = axisAngle(upAxis, -keyboardStep) * qRot
		end
		if keysPressed[Enum.KeyCode.J] then
			qRot = axisAngle(upAxis, keyboardStep) * qRot
		end
		if keysPressed[Enum.KeyCode.Y] then
			qRot = axisAngle(rightAxis, keyboardStep) * qRot
		end
		if keysPressed[Enum.KeyCode.H] then
			qRot = axisAngle(rightAxis, -keyboardStep) * qRot
		end
		if keysPressed[Enum.KeyCode.T] then
			qRot = axisAngle(forwardAxis, -keyboardStep) * qRot
		end
		if keysPressed[Enum.KeyCode.U] then
			qRot = axisAngle(forwardAxis, keyboardStep) * qRot
		end
	end

	-- Update camera
	local offset = rotate(qRot, Vector3.new(0, 0, -radius))
	local camPos = target + offset
	local upVec = rotate(qRot, Vector3.new(0, 1, 0))
	camera.CFrame = CFrame.lookAt(camPos, target, upVec)
	
	qRot = normalize(qRot)
end)

-- m to toggle keyboard / mouse controls
-- y/h, t/u, g/j to control in keyboard mode
-- r to reset camera
