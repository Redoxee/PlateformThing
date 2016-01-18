vector = require "Utils.HUMP.vector"

WindowSize = {800,800} 

function damping(f,p,t,dt)
    return p + ((t - p) / f * dt)
end

Gravity = vector(0,-300)
FloorHeight = 0
FloorFriction = .1

love.load = function()
	love.window.setMode(WindowSize[1], WindowSize[2])
	Controler:Initialize()
end

KeyboardHolder = {
	KeyListeners = {},
	KeyState = {},
	Reset = function(o)
		o.KeyListeners = {}
		o.KeyState = {}
	end,

	RegisterListener = function(o,key,callbacks)
		o.KeyListeners[key] = callbacks
	end,

	IsKeyPressed = function(o,key)
		return love.keyboard.isDown(key)
	end,

	Update = function(o)
		for key,callbacks in pairs(o.KeyListeners) do
			local ns = love.keyboard.isDown(key)
			local ls = o.KeyState[key]
			if ns and not ls then
				o.KeyState[key] = true
				if callbacks.OnPress then
					callbacks.OnPress()
				end
			elseif not ns and ls then
				o.KeyState[key] = false
				if callbacks.OnRelease then
					callbacks.OnRelease()
				end
			end
		end
	end,
}
Camera = {
	GetPosition = function(o,pos)
		return vector(pos.x,pos.y * -1 + WindowSize[2])
	end,
}


Controler = {
	JumpAsked = false,
	DirectionAsked = 0,
	AttackAsked = false,
	
	Initialize = function(o)
		KeyboardHolder:RegisterListener("right",{
				OnPress = function()
					o.DirectionAsked = o.DirectionAsked + 1
				end,
				OnRelease = function()
					o.DirectionAsked = o.DirectionAsked - 1
				end,
			})
		KeyboardHolder:RegisterListener("left",{
				OnPress = function()
					o.DirectionAsked = o.DirectionAsked - 1
				end,
				OnRelease = function()
					o.DirectionAsked = o.DirectionAsked + 1
				end,
			})

		KeyboardHolder:RegisterListener("up",{
				OnPress = function()
					o.JumpAsked = true
				end,
				OnRelease = function()
					o.JumpAsked = false
				end,
			})

		KeyboardHolder:RegisterListener("a",{
				OnPress = function()
					o.AttackAsked = true
				end,
				OnRelease = function()
					o.AttackAsked = false
				end,
			})
	end,
}

Character = {
	Position = vector(100,100),
	Velocity = vector(0,0),
	NBJump = 2,
	JumpConsumed = false,
	AttackTimer = false,
	HasHit = false,

	CharacterColors = {
		{255,0,0},
		{64,128,192},
		{25,255,25},
	},
	
	Size = 15,
	NBJumpOnGround = 2,
	HorizontalVelocity = 150,
	JumpImpulse = 200,

	AttackRate = .7,
	AttackRange = 90,

	IsOnGround = function(o)
		return o.Position.y < (FloorHeight + o.Size)
	end,

	Hit = function(o)
		local target, distance = o:GetClosestProjectile()
		if target and distance < o.AttackRange then
			table.remove(Projectiles,target)
			o.NBJump = o.NBJumpOnGround
		end
	end,

	GetClosestProjectile = function(o)
		local closestTarget = Projectiles[1]
		if closestTarget then
			local cPos = o.Position
			local currentLenght = (closestTarget.Position - cPos):len()
			local index = 1
			for i = 2, #Projectiles do
				pPos = Projectiles[i].Position
				local l = (pPos - cPos):len()
				if l < currentLenght then
					index = i
					currentLenght = l
				end
			end
			return index, currentLenght
		end
	end,

	Update = function(o, dt)
		o.Velocity = o.Velocity + Gravity * dt
		
		local isOnGround = o:IsOnGround()
		if isOnGround then
			o.Position.y = FloorHeight+o.Size
			o.Velocity.x = o.Velocity.x * (1 - FloorFriction)
			o.Velocity.y = 0
			
			o.NBJump = o.NBJumpOnGround
			o.JumpConsumed = false
		end

		if Controler.DirectionAsked ~= 0 then
			o.Velocity.x = damping(.2,o.Velocity.x,o.HorizontalVelocity * Controler.DirectionAsked,dt) 
		end
		if o.Position.x - o.Size < 0 then
			o.Position.x = o.Size
			o.Velocity.x = 0
		elseif o.Position.x + o.Size > WindowSize[1] then
			o.Position.x = WindowSize[1] - o.Size
			o.Velocity.x = 0
		end

		if Controler.JumpAsked and o.NBJump > 0 and not o.JumpConsumed then
			o.Velocity.y = o.JumpImpulse
			o.NBJump = o.NBJump - 1
			o.JumpConsumed = true
		elseif not Controler.JumpAsked and o.JumpConsumed then
			o.JumpConsumed = false
		end
		o.Position = o.Position + o.Velocity * dt
	
		if o.AttackTimer then
			o.AttackTimer = o.AttackTimer - dt
			if o.AttackTimer < 0 then
				o.AttackTimer = false
			end
		end
		if Controler.AttackAsked and not o.AttackTimer then
			o.AttackTimer = o.AttackRate
			o.HasHit = false
			o:Hit()
			o.HasHit = true
		end
	end,

	Draw = function(o)
		local cColor = o.CharacterColors[o.NBJump + 1]
		
		love.graphics.setColor(unpack(cColor))
		local position = Camera:GetPosition(o.Position)
		love.graphics.circle("fill",position.x,position.y,o.Size)
	end,
}

Projectiles = {
	-- {Position,Velocity,Size,IsOnGround}
}

ProjectileManager = {

	Update = function(o,dt)
		local dGrav = Gravity * dt
		local toDestroy = {}
		for i = 1,#Projectiles do
			local projectile = Projectiles[i]
			if not projectile.IsOnGround then
				projectile.Velocity = projectile.Velocity + dGrav
				if projectile.Position.y < FloorHeight + projectile.Size then
					projectile.IsOnGround = true
					projectile.Velocity.y = 0
					projectile.Position.y = projectile.Size
				end
				local nPos = projectile.Position + projectile.Velocity * dt
				if nPos.x < 0 then
					nPos.x = nPos.x * -1
					projectile.Velocity.x = projectile.Velocity.x * -1
				elseif nPos.x > WindowSize[1] then
					nPos.x = WindowSize[1] * 2 - nPos.x 
					projectile.Velocity.x = projectile.Velocity.x * -1
				end
				projectile.Position = nPos
			end
			projectile.LifeTime = projectile.LifeTime - dt
			if projectile.LifeTime <= 0 then
				table.insert(toDestroy,i)
			end
		end
		for i = #toDestroy,1,-1 do
			table.remove(Projectiles,toDestroy[i])
		end
	end,

	Draw = function(o)
		local pColor = {245,12,26}

		love.graphics.setColor(unpack(pColor))
		for i = 1,#Projectiles do
			projectile = Projectiles[i]
			local pos = Camera:GetPosition(projectile.Position)
			love.graphics.circle("fill",pos.x,pos.y,projectile.Size)
		end
	end,


	DefaultProjectile = {
		Size = 10,
		Position = vector(0,0),
		Velocity = vector(0,0),
		IsOnGround = false,
		LifeTime = 10,
	},

	AddProjectile = function(o,args)
		for k,v in pairs(o.DefaultProjectile) do
			if not args[k] then
				args[k] = v
			end
		end
		table.insert(Projectiles,args)
	end,
}

ProjectileLauncher = {
	Position = vector(400,700),
	Direction = 1,
	Speed = 100,

	FireRate = .8,
	Range = math.pi * 0.7,
	ShootForceRange = 300,
	MinShootForce = 150,

	Timer = 1,
	Update = function(o,dt)
		o.Position.x = o.Position.x + o.Speed * dt * o.Direction
		if o.Position.x < 0 then
			o.Position.x = o.Position.x * -1
			o.Direction = 1
		elseif o.Position.x > WindowSize[1] then
			o.Position.x = WindowSize[1] * 2 - o.Position.x
			o.Direction = -1
		end

		o.Timer = o.Timer - dt
		if o.Timer < 0 then
			o.Timer = o.FireRate

			local angle = math.random() * o.Range - (math.pi + o.Range)/2
			local force = math.random() * (o.ShootForceRange) + o.MinShootForce
			local v = vector(math.cos(angle),math.sin(angle)) * force

			ProjectileManager:AddProjectile({Position = o.Position, Velocity = v})
		end
	end,
	Size = vector(100,65),
	Color = {251,108,153},
	Draw = function(o)
		local pos = Camera:GetPosition(o.Position)
		pos = pos - (o.Size/2)
		love.graphics.setColor(unpack(o.Color))
		love.graphics.rectangle("fill",pos.x,pos.y,o.Size.x,o.Size.y)
	end,

}

love.update = function(dt)
	if love.keyboard.isDown("escape") then
  		love.event.push('quit')
	end

	KeyboardHolder:Update()
	Character:Update(dt)
	
	ProjectileManager:Update(dt)
	ProjectileLauncher:Update(dt)
end

love.draw = function()
	love.graphics.clear()

	Character:Draw()
	ProjectileManager:Draw()
	ProjectileLauncher:Draw()
end