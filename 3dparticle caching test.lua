--!strict
-- it is HIGHLY recommended that this module is used locally



export type NumberSequence2D = {
	X: NumberSequence,
	Y: NumberSequence
}

export type NumberRange3D = {
	X: NumberRange,
	Y: NumberRange,
	Z: NumberRange
}

export type ParticleEmitter3D = {
	__index: ParticleEmitter3D,
	particles: {Particle},
	Cache: {Particle},
	Enabled: boolean,
	Container: Folder,
	Mesh: string,
	Texture: string,
	Anchor: BasePart,
	preSpawn: (Particle) -> (),
	Rate: number,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Speed: number,
	SpreadAngle: Vector2,
	RotSpeed: NumberRange3D,
	Lifetime: NumberRange,
	Acceleration: Vector3,
	ShapeStyle: "Volume" | "Surface",
	ShapeInOut: "Outward" | "Inward" | "InAndOut",
	EmissionDirection: "Top" | "Bottom" | "Left" | "Right" | "Front" | "Back",
	__dead: boolean,
	__elapsedTime: number,
	__runServiceConnection: RBXScriptConnection,
	new: (Anchor: BasePart, Mesh: string, Texture: string) -> (ParticleEmitter3D),
	Emit: (self: ParticleEmitter3D, count: number) -> (ParticleEmitter3D),
	Destroy: (self: ParticleEmitter3D) -> (),
	CreateParticle: (self: ParticleEmitter3D) -> (ParticleEmitter3D)
}


export type Particle = {
	__index: Particle,
	Instance: BasePart,
	DestroyOnComplete: boolean,
	Emitter: ParticleEmitter3D,
	Mesh: SpecialMesh,
	Speed: Vector3,
	CFrame: CFrame,
	SpreadAngle: Vector2,
	RotSpeed: Vector3,
	Acceleration: Vector3,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Color: ColorSequence,
	EmissionDirection: Vector3,
	Age: number,
	Ticks: number,
	maxAge: number,
	isDead: boolean,
	Position: Vector3,
	Rotation: Vector3,
	Cached: boolean,
	Revive: (self: Particle) -> Particle,
	Cache: (self: Particle) -> Particle,
	new: (Emitter: ParticleEmitter3D, DestroyOnComplete: boolean) -> (Particle),
	Update: (self: Particle, delta: number) -> (),
	Destroy: (self: Particle) -> ()
}


local ParticleClass: Particle = {} :: Particle
ParticleClass.__index = ParticleClass
function Rotate(Vector: Vector3, Angle: number, Axis: Vector3)
	return CFrame.fromAxisAngle(Axis, Angle):VectorToWorldSpace(Vector)
end

local function Normalize(min: number, max: number, alpha: number)
	return (alpha - min)/(max-min)
end

-- sequence evaluation functions taken from developer hub 

function evalCS(cs: ColorSequence, t: number): Color3 | false
	-- If we are at 0 or 1, return the first or last value respectively
	if t == 0 then return cs.Keypoints[1].Value end
	if t == 1 then return cs.Keypoints[#cs.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #cs.Keypoints - 1 do
		local this = cs.Keypoints[i]
		local next = cs.Keypoints[i + 1]
		if t >= this.Time and t < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (t - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return Color3.new(
				(next.Value.R - this.Value.R) * alpha + this.Value.R,
				(next.Value.G - this.Value.G) * alpha + this.Value.G,
				(next.Value.B - this.Value.B) * alpha + this.Value.B
			)
		end
	end
	return false
end

local function evalNS(ns: NumberSequence, t: number): number | false
	-- If we are at 0 or 1, return the first or last value respectively
	if t == 0 then return ns.Keypoints[1].Value end
	if t == 1 then return ns.Keypoints[#ns.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if t >= this.Time and t < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (t - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return (next.Value - this.Value) * alpha + this.Value
		end
	end
	return false
end

local function newObj(emitter: ParticleEmitter3D)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = Vector3.one * emitter.Size.Keypoints[1].Value
	part.Color = evalCS(emitter.Color, 0) :: Color3
	local mesh = Instance.new("SpecialMesh", part)
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = emitter.Mesh
	mesh.TextureId = emitter.Texture
	mesh.Scale = part.Size
	return part, mesh
end

local function getInverseVector(vector: Vector3)
	vector = Vector3.new(
		math.abs(vector.X),
		math.abs(vector.Y),
		math.abs(vector.Z)
	)
	return -vector + Vector3.one
end

local function splitInverseVector(v)
	local v1, v2

	if v.X == 0 then v1 = Vector3.xAxis
	elseif v.Y == 0 then v1 = Vector3.yAxis
	elseif v.Z == 0 then v1 = Vector3.zAxis
	end

	return v1, v
end

local function surfaceToVector(surface)
	if surface == "Top" then
		return Vector3.yAxis
	elseif surface == "Bottom" then
		return -Vector3.yAxis
	elseif surface == "Front" then
		return -Vector3.zAxis
	elseif surface == "Back" then
		return Vector3.zAxis
	elseif surface == "Left" then
		return -Vector3.xAxis
	elseif surface == "Right" then
		return Vector3.xAxis
	end
	return Vector3.zero
end

local function getDirection(shape)
	if shape == "Inward" then
		return -1
	elseif shape == "Outward" then
		return 1
	else
		return math.random(0,1) == 0 and -1 or 1
	end
end


local function randomUnitVector()
	return Vector3.new(
		(2*math.random()) - 1,
		(2*math.random()) - 1,
		(2*math.random()) - 1
	)
end

local function getSpawnPosition(emissionDirection: Vector3, emitter: ParticleEmitter3D)
	if emitter.ShapeStyle == "Surface" then
		return emitter.Anchor.CFrame:ToWorldSpace(CFrame.new(emissionDirection + (randomUnitVector() * getInverseVector(emissionDirection)) * (emitter.Anchor.Size/2))).Position	
	else
		return emitter.Anchor.CFrame:ToWorldSpace(CFrame.new(randomUnitVector() * (emitter.Anchor.Size/2))).Position
	end
end

function ParticleClass.new(emitter: ParticleEmitter3D, DestroyOnComplete: boolean)
	
	local self: Particle = {} :: Particle
	self.Instance, self.Mesh = newObj(emitter)
	self.DestroyOnComplete = DestroyOnComplete
	self.Color = emitter.Color
	self.Transparency = emitter.Transparency
	self.Emitter = emitter
	self.EmissionDirection = surfaceToVector(emitter.EmissionDirection) * getDirection(emitter.ShapeInOut) 
	self.Position = getSpawnPosition(self.EmissionDirection, emitter)
	self.Instance.Position = self.Position
	self.Size = emitter.Size
	emitter.preSpawn(self)
	self.Speed = emitter.Speed * self.EmissionDirection
	self.SpreadAngle = Vector2.new(
		math.rad(math.random(-emitter.SpreadAngle.X, emitter.SpreadAngle.X)),
		math.rad(math.random(-emitter.SpreadAngle.Y, emitter.SpreadAngle.Y))
	)

	self.RotSpeed = Vector3.new(
		math.rad(math.random(emitter.RotSpeed.X.Min, emitter.RotSpeed.X.Max)),
		math.rad(math.random(emitter.RotSpeed.Y.Min, emitter.RotSpeed.Y.Max)),
		math.rad(math.random(emitter.RotSpeed.Z.Min, emitter.RotSpeed.Z.Max))
	)
	self.Acceleration = emitter.Acceleration
	self.Rotation = Vector3.zero
	self.Transparency = emitter.Transparency
	self.Age = 0
	self.Ticks = 0
	self.maxAge = math.random(emitter.Lifetime.Min, emitter.Lifetime.Max)
	self.isDead = false
	self.Instance.Parent = emitter.Container

	return setmetatable(self :: any, ParticleClass)
end

function ParticleClass:Revive()
	self.Mesh.MeshId = self.Emitter.Mesh
	self.Mesh.TextureId = self.Emitter.Texture
	self.Color = self.Emitter.Color
	self.Transparency = self.Emitter.Transparency
	self.EmissionDirection = surfaceToVector(self.Emitter.EmissionDirection) * getDirection(self.Emitter.ShapeInOut) 
	self.Position = getSpawnPosition(self.EmissionDirection, self.Emitter)
	self.Size = self.Emitter.Size
	self.Emitter.preSpawn(self)
	self.Speed = self.Emitter.Speed * self.EmissionDirection
	self.SpreadAngle = Vector2.new(
		math.rad(math.random(-self.Emitter.SpreadAngle.X, self.Emitter.SpreadAngle.X)),
		math.rad(math.random(-self.Emitter.SpreadAngle.Y, self.Emitter.SpreadAngle.Y))
	)

	self.RotSpeed = Vector3.new(
		math.rad(math.random(self.Emitter.RotSpeed.X.Min, self.Emitter.RotSpeed.X.Max)),
		math.rad(math.random(self.Emitter.RotSpeed.Y.Min, self.Emitter.RotSpeed.Y.Max)),
		math.rad(math.random(self.Emitter.RotSpeed.Z.Min, self.Emitter.RotSpeed.Z.Max))
	)
	self.Acceleration = self.Emitter.Acceleration
	self.Rotation = Vector3.zero
	self.Transparency = self.Emitter.Transparency
	self.Ticks = 0
	
	self.maxAge = math.random(self.Emitter.Lifetime.Min, self.Emitter.Lifetime.Max)
	self.Age = 0
	self.Cached = false
	self.isDead = false
	table.remove(self.Emitter.Cache, table.find(self.Emitter.Cache, self))
	return self
end

function ParticleClass:Cache()
	self.Position = Vector3.one * 10e8
	self.Cached = true
	table.insert(self.Emitter.Cache, self)
	
	return self
end


function ParticleClass:Update(delta)

	if self.Age >= self.maxAge and self.maxAge > 0 and not self.Cached then
		if self.DestroyOnComplete then
			self:Destroy()
		else
			self:Cache()
		end
		return
	end


	self.Ticks = self.Ticks + 1
	self.Age = self.Age + delta	
	local size = evalNS(self.Size, Normalize(0, self.maxAge, self.Age)) :: number
	if size then
		self.Instance.Size = Vector3.one * math.abs(size)
		if self.Mesh then
			self.Mesh.Scale = Vector3.one * math.abs(size)
		end
	end
	local nextColor = evalCS(self.Color, Normalize(0, self.maxAge, self.Age)) :: Color3
	if nextColor then
		self.Instance.Color = nextColor
	end
	self.Instance.Transparency = evalNS(self.Transparency, Normalize(0, self.maxAge, self.Age)) :: number

	local xAxis, yAxis = splitInverseVector(self.EmissionDirection)
	local dir = Rotate(Rotate(self.Speed, self.SpreadAngle.X, xAxis), self.SpreadAngle.Y, yAxis)
	self.Speed += Rotate(Rotate(self.Acceleration * delta, -self.SpreadAngle.X, xAxis), -self.SpreadAngle.Y, yAxis)
	self.Position += (dir) * delta
	self.Rotation += self.RotSpeed * delta
	self.Instance.CFrame = CFrame.new(self.Position) * CFrame.fromEulerAnglesXYZ(self.Rotation.X, self.Rotation.Y, self.Rotation.Z)

end

function ParticleClass:Destroy()
	self.isDead = true
	table.remove(self.Emitter.particles, table.find(self.Emitter.particles, self))
	if self.Cached then
		table.remove(self.Emitter.Cache, table.find(self.Emitter.Cache, self))
	end
	self.Instance:Destroy()
end





local ParticleEmitterClass: ParticleEmitter3D = {} :: ParticleEmitter3D
ParticleEmitterClass.__index = ParticleEmitterClass


--NOTE: COLOR DOES NOT HAVE ANY EFFECT IF A TEXTURE IS PROVIDED
function ParticleEmitterClass.new(Anchor: BasePart, Mesh: string, Texture: string)
	local self = {} :: ParticleEmitter3D
	self.Container = Instance.new("Folder", workspace)
	self.Container.Name = "ParticleContainer"
	self.particles = {}
	self.Cache = {}
	self.Enabled = false
	self.Mesh = Mesh
	self.Anchor = Anchor
	self.Texture = Texture

	self.preSpawn = function(p) end

	--properties
	self.Rate = 20
	self.Color = ColorSequence.new(Color3.new(1,1,1))
	self.Size = NumberSequence.new(1)
	self.Transparency = NumberSequence.new(0)
	self.Speed = 1
	self.SpreadAngle = Vector2.new(0,0)
	self.RotSpeed = {
		X = NumberRange.new(0,0),
		Y = NumberRange.new(0,0),
		Z = NumberRange.new(0,0),
	}
	self.Lifetime = NumberRange.new(5,10)
	self.Acceleration = Vector3.new(0,0,0)
	self.EmissionDirection = "Top"

	self.ShapeInOut = "Outward"
	self.ShapeStyle = "Volume"



	self.__dead = false
	self.__elapsedTime = 0

	self.__runServiceConnection = game:GetService("RunService").Heartbeat:Connect(function(delta)


		self.__elapsedTime = self.__elapsedTime + delta	
		for index, particle in ipairs(self.particles) do
			if particle.isDead then 
				table.remove(self.particles, index)
			else
				if not particle.Cached then
					particle:Update(delta)
				end
			end
		end


		if self.Rate > 0 and (self.__dead == false) and self.Enabled then
			while self.__elapsedTime >= (1/self.Rate) do
				self:CreateParticle()
				self.__elapsedTime = self.__elapsedTime - (1/self.Rate)
			end
		end
	end)

	return setmetatable(self :: any, ParticleEmitterClass)
end

local rand = Random.new()

function ParticleEmitterClass:CreateParticle()
	local maxParticlesActive: number = self.Rate * self.Lifetime.Max
	
	if #self.particles <= maxParticlesActive then
		print("creating new")
		table.insert(self.particles, ParticleClass.new(self, false))
	else
		if #self.Cache > 0 then
			print("pulling from cache")
			self.Cache[rand:NextInteger(1,#self.Cache)]:Revive()
		end
	end
	return self
end


function ParticleEmitterClass:Emit(count: number)
	local counter = 0

	while counter < count do
		counter += 1
		table.insert(self.particles, ParticleClass.new(self, true))
	end
	return self
end

function ParticleEmitterClass:Destroy()

	if self.__dead then
		error('Cannot destroy dead particle emitter.')
		return
	end

	self.__dead = true
	for _,particle in ipairs(self.particles) do
		if particle then
			particle:Destroy()
		end
	end

	if self.__runServiceConnection then
		self.__runServiceConnection:Disconnect()
	end
end

return ParticleEmitterClass
