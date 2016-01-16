vector = require "Utils.HUMP.vector"

WindowSize = {800,800} 

function damping(f,p,t,dt)
    return p + ((t - p) / f * dt)
end

Gravity = vector(0,-200)

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

	CharacterColors = {
		{255,0,0},
		{64,128,192},
		{25,255,25},
	},
	
	Size = 15,
	NBJump = 2,
	JumpConsumed = false,
	NBJumpOnGround = 2,

	HorizontalVelocity = 150,
	JumpImpulse = 200,

	FloorHeight = 0,
	FloorFriction = .1,
	IsOnGround = function(o)
		return o.Position.y < (o.FloorHeight + o.Size)
	end,

	Update = function(o, dt)
		o.Velocity = o.Velocity + Gravity * dt
		
		local isOnGround = o:IsOnGround()
		if isOnGround then
			o.Position.y = o.FloorHeight+o.Size
			o.Velocity.x = o.Velocity.x * (1 - o.FloorFriction)
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
	end,
}

love.update = function(dt)
	if love.keyboard.isDown("escape") then
  		love.event.push('quit')
	end

	KeyboardHolder:Update()
	Character:Update(dt)
end

love.draw = function()
	love.graphics.clear()

	local cColor = Character.CharacterColors[Character.NBJump + 1]
	love.graphics.setColor(unpack(cColor))
	local position = vector(Character.Position.x ,Character.Position.y * -1) + vector(0,WindowSize[2])
	love.graphics.circle("fill",position.x,position.y,Character.Size)
end