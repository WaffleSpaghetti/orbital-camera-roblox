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

local function slerp(a, b, t)
	local dot = a.R*b.R + a.I*b.I + a.J*b.J + a.K*b.K

	if dot < 0 then
		b = Q(-b.R, -b.I, -b.J, -b.K)
		dot = -dot
	end

	if dot > 0.9995 then
		local r = a.R + t*(b.R - a.R)
		local i = a.I + t*(b.I - a.I)
		local j = a.J + t*(b.J - a.J)
		local k = a.K + t*(b.K - a.K)
		return normalize(Q(r, i, j, k))
	end

	local theta_0 = math.acos(dot)
	local theta = theta_0 * t
	local sin_theta = math.sin(theta)
	local sin_theta_0 = math.sin(theta_0)

	local s0 = math.cos(theta) - dot * sin_theta / sin_theta_0
	local s1 = sin_theta / sin_theta_0

	return Q(
		(s0 * a.R) + (s1 * b.R),
		(s0 * a.I) + (s1 * b.I),
		(s0 * a.J) + (s1 * b.J),
		(s0 * a.K) + (s1 * b.K)
	)
end

-- Toggles
local useMouseControl = true

-- State
local qRot = Q(1, 0, 0, 0)
local qTargetRot = Q(1, 0, 0, 0)
local rotating = false
local sensitivity = 0.003
local keyboardStep = 0.05
local radius = 100
local target = Vector3.new(0, 0, 0)
local smoothSpeed = 0.15

local function reset()
	qRot = Q(1, 0, 0, 0)
	qTargetRot = Q(1, 0, 0, 0)
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

	-- Rotate relative to target rotation (to keep smooth)
	local upAxis = rotate(qTargetRot, Vector3.new(0, 1, 0))
	local rightAxis = rotate(qTargetRot, Vector3.new(1, 0, 0))

	local qYaw = axisAngle(upAxis, dx)
	local qPitch = axisAngle(rightAxis, dy)

	qTargetRot = qYaw * qPitch * qTargetRot
	qTargetRot = normalize(qTargetRot)
end)

RunService.RenderStepped:Connect(function()
	if not useMouseControl then
		local upAxis = rotate(qRot, Vector3.new(0, 1, 0))
		local rightAxis = rotate(qRot, Vector3.new(1, 0, 0))
		local forwardAxis = rotate(qRot, Vector3.new(0, 0, 1))

		if keysPressed[Enum.KeyCode.G] then
			qTargetRot = axisAngle(upAxis, -keyboardStep) * qTargetRot
		end
		if keysPressed[Enum.KeyCode.J] then
			qTargetRot = axisAngle(upAxis, keyboardStep) * qTargetRot
		end
		if keysPressed[Enum.KeyCode.Y] then
			qTargetRot = axisAngle(rightAxis, keyboardStep) * qTargetRot
		end
		if keysPressed[Enum.KeyCode.H] then
			qTargetRot = axisAngle(rightAxis, -keyboardStep) * qTargetRot
		end
		if keysPressed[Enum.KeyCode.T] then
			qTargetRot = axisAngle(forwardAxis, -keyboardStep) * qTargetRot
		end
		if keysPressed[Enum.KeyCode.U] then
			qTargetRot = axisAngle(forwardAxis, keyboardStep) * qTargetRot
		end
	end

	-- Smoothly interpolate current rotation towards target rotation
	qRot = slerp(qRot, qTargetRot, smoothSpeed)
	qRot = normalize(qRot)

	-- Update camera
	local offset = rotate(qRot, Vector3.new(0, 0, -radius))
	local camPos = target + offset
	local upVec = rotate(qRot, Vector3.new(0, 1, 0))
	camera.CFrame = CFrame.lookAt(camPos, target, upVec)
end)
