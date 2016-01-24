vector = require "Utils.HUMP.vector"

WindowSize = {800,800} 
TIME_FACTOR = 1

math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

math.sign = math.sign or function(x) return x<0 and -1 or x>0 and 1 or 0 end
function damping(f,p,t,dt)
    return p + ((t - p) / f * dt)
end
function getBias(time,bias)
  return (time / ((((1.0/bias) - 2.0)*(1.0 - time))+1.0));
end
function getGain(time,gain)
  	if(time < 0.5) then
    	return getBias(time * 2.0,gain)/2.0;
 	else
    	return getBias(time * 2.0 - 1.0,1.0 - gain)/2.0 + 0.5;
	end
end

Gravity = vector(0,-700)
FloorHeight = 0
FloorFriction = .1

love.load = function()
	love.window.setMode(WindowSize[1], WindowSize[2])
	IntroState:Load()
	SlashAnimation:Load()
	RechargeGaugeManager:Load()

	GameStateManager:SetState("Intro")
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

GamepadHolder = {
	GpadNumber = 1,

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
		local joystick = love.joystick.getJoysticks()[o.GpadNumber]
		if joystick then
			return joystick:isGamepadDown(key)
		end
	end,

	Update = function(o)
		local joystick = love.joystick.getJoysticks()[o.GpadNumber]
		if joystick then
			for key,callbacks in pairs(o.KeyListeners) do
				local ns = joystick:isGamepadDown(key)
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
		end
	end,	
}


Camera = {
	ShakeForce = false,
	ShakeVector = vector(0,0),
	Time = 0,

	GetPosition = function(o,pos)
		local bias = o.ShakeForce and o.ShakeVector or vector(0,0)

		return vector(pos.x,pos.y * -1 + WindowSize[2]) + bias
	end,

	Update = function(o,dt)
		if o.ShakeForce then
			o.Time = o.Time + dt * 80
			o.ShakeVector = vector(math.sin(o.Time),math.cos(o.Time)) * o.ShakeForce
			o.ShakeForce = damping(.35,o.ShakeForce,0,dt)
			if o.ShakeForce < .2 then
				o.ShakeForce = false
			end
		end
	end,

	Impulse = function(o)
		o.ShakeForce = 4
		o.Time = 0
	end,
}


Controler = {
	JumpAsked = false,
	DirectionAsked = 0,
	AttackAsked = false,
	
	Initialize = function(o)

		o.JumpAsked = false
		o.DirectionAsked = 0
		o.AttackAsked = false

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

		-- GPAD
		GamepadHolder:RegisterListener("dpright",{
				OnPress = function()
					o.DirectionAsked = o.DirectionAsked + 1
				end,
				OnRelease = function()
					o.DirectionAsked = o.DirectionAsked - 1
				end,
			})
		GamepadHolder:RegisterListener("dpleft",{
				OnPress = function()
					o.DirectionAsked = o.DirectionAsked - 1
				end,
				OnRelease = function()
					o.DirectionAsked = o.DirectionAsked + 1
				end,
			})

		GamepadHolder:RegisterListener("a",{
				OnPress = function()
					o.JumpAsked = true
				end,
				OnRelease = function()
					o.JumpAsked = false
				end,
			})

		GamepadHolder:RegisterListener("x",{
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
	JumpImpulse = 350,

	AttackRate = .5,
	AttackRange = 90,

	LifePoint = 5,
	InvincibilityTimer = false,
	InvincibilityTime = 1.5,
	BlinkFrequency = 9,

	Initialize = function(o)
		o.Position = vector(100,100)
		o.Velocity = vector(0,0)
		o.NBJump = 2
		o.JumpConsumed = false
		o.AttackTimer = false
		o.HasHit = false
		o.InvincibilityTimer = false
		o.LifePoint = 5
	end,

	IsOnGround = function(o)
		return o.Position.y < (FloorHeight + o.Size)
	end,

	Hit = function(o)
		o.AttackTimer = o.AttackRate

		local hasHit = false
		local direction =(ProjectileLauncher.Position - o.Position) 
		local distance = direction:len()
		if distance < o.AttackRange then
			hasHit = ProjectileLauncher:Hit()
		end
		if not hasHit then
			local target
			target, distance, direction = o:GetClosestProjectile()
			if target and distance < o.AttackRange then
				table.remove(Projectiles,target)
				hasHit = true
			end
		end

		if hasHit then
			o.NBJump = o.NBJumpOnGround
			Camera:Impulse()

			direction = direction:normalized()
			local angle = math.acos(direction:dot(vector(0,1))) * math.sign(direction.x)
			SlashAnimation:StartAnimation(o.Position,angle )
			print("angle : " .. angle / (math.pi* 2) * 360)

			GameplayState:NotifyHit()
		end
	end,

	GetClosestProjectile = function(o)
		local closestTarget = Projectiles[1]
		if closestTarget then
			local characterPosition = o.Position
			local direction = (closestTarget.Position - characterPosition)
			local currentLenght = direction:len()
			local index = 1
			for i = 2, #Projectiles do
				pPos = Projectiles[i].Position
				direction = (pPos - characterPosition)
				local l = direction:len()
				if l < currentLenght then
					index = i
					currentLenght = l
				end
			end
			return index, currentLenght, direction
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
			o.HasHit = false
			o:Hit()
			o.HasHit = true
		end

		local closestProjectile,distance = o:GetClosestProjectile()
		if closestProjectile and not o.InvincibilityTimer and distance < (o.Size + Projectiles[closestProjectile].Size) then
			o.LifePoint = math.max(o.LifePoint - 1,0)
			table.remove(Projectiles,closestProjectile)
			Camera:Impulse()
			o.InvincibilityTimer = o.InvincibilityTime
			o.AttackTimer = o.AttackRate
			GameplayState:NotifyHit()
		elseif o.InvincibilityTimer then
			o.InvincibilityTimer = o.InvincibilityTimer - dt
			if o.InvincibilityTimer <= 0 then
				o.InvincibilityTimer = false
			end
		end
	end,

	Draw = function(o)
		local visible = true
		if o.InvincibilityTimer and math.cos(math.pi * o.BlinkFrequency * o.InvincibilityTimer) < 0 then
			visible = false
		end
		if visible then
			local position = Camera:GetPosition(o.Position)
			local cColor = o.CharacterColors[o.NBJump + 1]
			love.graphics.setColor(unpack(cColor))
			love.graphics.circle("fill",position.x,position.y,o.Size)
		end
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
	Speed = 80,

	FireRate = .25,
	Range = math.pi * 0.75,
	ShootForceRange = 300,
	MinShootForce = 160,

	LifePoint = 6,

	InvincibilityTime = 4,
	InvincibilityTimer = false,
	BlinkFrequency = 10,

	Timer = 1,

	Initialize = function(o)

		o.Position = vector(400,700)
		o.Direction = 1
		o.InvincibilityTimer = false
		o.Timer = 1
		o.LifePoint = 6
		Projectiles = {}
	end,

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

		if o.InvincibilityTimer then
			o.InvincibilityTimer = o.InvincibilityTimer - dt
			if o.InvincibilityTimer <= 0 then
				o.InvincibilityTimer = false
			end
		end
	end,

	Hit = function(o)
		if not o.InvincibilityTimer then
			o.LifePoint = math.max(0,o.LifePoint - 1)
			o.InvincibilityTimer = o.InvincibilityTime
			return true
		end
	end,

	Size = vector(100,65),
	Color = {251,108,153},
	Draw = function(o)
		local visible = true
		if o.InvincibilityTimer then
			visible = math.cos(math.pi * o.InvincibilityTimer * o.BlinkFrequency) < 0
		end

		if visible then
			local pos = Camera:GetPosition(o.Position)
			pos = pos - (o.Size/2)
			love.graphics.setColor(unpack(o.Color))
			love.graphics.rectangle("fill",pos.x,pos.y,o.Size.x,o.Size.y)
		end
	end,

}

SlashAnimation = {
	Textures = {
		"Media/Slash/slash1.png",
		"Media/Slash/slash2.png",
		"Media/Slash/slash3.png",
		"Media/Slash/slash4.png",
		"Media/Slash/slash5.png",
		"Media/Slash/slash6.png",
		"Media/Slash/slash1.png",
	},
	AnimationAccumulator = false,
	CurrentTexture = false,
	AnimationTime = .5,
	AnimationGain = .18,
	Position = vector(0,0),
	Orientation = 0,

	Load = function(o)
		for i = 1,#o.Textures do
			o.Textures[i] = love.graphics.newImage(o.Textures[i])
		end
	end,

	Initialize = function(o)
	end,

	Update = function(o,dt)
		if o.AnimationAccumulator then
			o.AnimationAccumulator = o.AnimationAccumulator + dt
			if o.AnimationAccumulator > o.AnimationTime then
				o.AnimationAccumulator = false
				return
			end
			local progression = o.AnimationAccumulator / o.AnimationTime
			progression = getGain(progression,o.AnimationGain)
			o.CurrentTexture = o.Textures[math.floor(progression * #o.Textures) + 1]
		end
	end,

	Draw = function(o)
		if o.AnimationAccumulator then
			love.graphics.draw(o.CurrentTexture,o.Position.x,o.Position.y,o.Orientation,1,1,o.CurrentTexture:getWidth()/2,o.CurrentTexture:getHeight())
		end
	end,

	StartAnimation = function(o,pos,orientation)
		o.Position = Camera:GetPosition(pos:clone())
		o.Orientation = orientation
		o.AnimationAccumulator = 0
	end,
}


RechargeGaugeManager = {
	GaugeShader = "Media/Shader/RechargeGauge.shader",
	GaugeQuad = false,
	GaugeImage = false,
	Size = Character.AttackRange - 5,
	GaugeColor = {25,25,25},

	Load = function(o)
		o.GaugeShader = love.graphics.newShader(o.GaugeShader)
		local s = o.Size*2
		o.GaugeQuad = love.graphics.newQuad(0,0,s,s,s,s)
		o.GaugeImage = love.graphics.newImage("Media/White.png")
	end,

	Initialize = function(o)
	end,

	Draw = function(o)
		local pos = Camera:GetPosition(Character.Position)
		love.graphics.setColor(unpack(o.GaugeColor))
		if Character.AttackTimer then
			local pos = Camera:GetPosition(Character.Position - vector(o.Size,-o.Size))
			love.graphics.setShader(o.GaugeShader)
			o.GaugeShader:send("progression",1 - Character.AttackTimer / Character.AttackRate)
			love.graphics.draw(o.GaugeImage, o.GaugeQuad,pos.x,pos.y)
			love.graphics.setShader()
		else
			love.graphics.circle("fill",pos.x,pos.y,o.Size)
		end
	end,
}

GUI = {
	PlayerLifePosition = vector(750,750),
	PlayerLifeColor = {25,255,25},
	
	BossLifePosition = vector(750,20),
	BossLifeColor = {245,30,65},

	Update = function(o,dt)
	end,

	Draw = function(o)
		local cellSize = vector(45,30)
		if Character.LifePoint > 0 then
			local currentPose = o.PlayerLifePosition:clone()
			love.graphics.setColor(unpack(o.PlayerLifeColor))

			for i = 1, Character.LifePoint do
				love.graphics.rectangle("fill",currentPose.x,currentPose.y,cellSize.x,cellSize.y)
				currentPose.y = currentPose.y - cellSize.y - 5
			end
		end

		if ProjectileLauncher.LifePoint > 0 then
			local currentPose = o.BossLifePosition:clone()
			love.graphics.setColor(unpack(o.BossLifeColor))
			for i = 1,ProjectileLauncher.LifePoint do
				love.graphics.rectangle("fill",currentPose.x,currentPose.y,cellSize.x,cellSize.y)
				currentPose.y = currentPose.y + cellSize.y + 5
			end
		end
	end,
}

GameStateManager = {
	CurrentState = false,
	States = {},

	SetState = function(o,state)
		if o.States[state] then
			if o.CurrentState and o.States[o.CurrentState].OnEnd then
				o.States[o.CurrentState]:OnEnd()
			end
			if o.States[state].OnStart then
				o.States[state]:OnStart()
			end
			o.CurrentState = state
		end
	end,

	Update = function(o,dt)
		if o.States[o.CurrentState].OnUpdate then
			o.States[o.CurrentState]:OnUpdate(dt)
		end
	end,

	Draw = function(o)
		if o.States[o.CurrentState].OnDraw then
			o.States[o.CurrentState]:OnDraw()
		end
	end,
}

DebugAnimation = {
	WasPressed = false,
	Update = function(o)
		local ns  = love.mouse.isDown("l")
		if ns and not o.WasPressed then
			o:onClick()
		end
		o.WasPressed = ns
	end,
	onClick = function(o)
		local p = vector(400,400)
		local position = vector(love.mouse.getX(),love.mouse.getY())
		local direction = (position - p):normalized()
		local angle = math.acos(direction:dot(vector(0,-1))) * math.sign(direction.x) 
		SlashAnimation:StartAnimation(p,angle)
	end,
}

GameplayState = {
	OnStart = function(o)
		KeyboardHolder:Reset()
		GamepadHolder:Reset()
		Controler:Initialize()
		SlashAnimation:Initialize()
		RechargeGaugeManager:Initialize()
		Character:Initialize()
		ProjectileLauncher:Initialize()
	end,
	OnUpdate = function(o,dt)
		KeyboardHolder:Update(dt)
		GamepadHolder:Update(dt)
		Camera:Update(dt)
		Character:Update(dt)
		DebugAnimation:Update(dt)
		SlashAnimation:Update(dt)
		ProjectileManager:Update(dt)
		ProjectileLauncher:Update(dt)
		GUI:Update(dt)
	end,
	OnDraw = function(o)
		love.graphics.clear()
		RechargeGaugeManager:Draw()
		Character:Draw()
		ProjectileManager:Draw()
		ProjectileLauncher:Draw()
		SlashAnimation:Draw()
		GUI:Draw()
	end,

	NotifyHit = function(o)
		if Character.LifePoint == 0 or ProjectileLauncher.LifePoint == 0 then
			GameStateManager:SetState("GameOver")
		end
	end,
}
GameStateManager.States["Gameplay"] = GameplayState

IntroState = {
	TitleImage = false,
	StartText = "Press START or SPACE to fight !",

	Load = function(o)
		o.TitleImage = love.graphics.newImage("Media/JumpSlashJump.png")
	end,

	OnStart = function(o)
		KeyboardHolder:Reset()
		GamepadHolder:Reset()

		KeyboardHolder:RegisterListener(" ",{OnPress =function() GameStateManager:SetState("Gameplay") end})
		GamepadHolder:RegisterListener("start",{OnPress =function() GameStateManager:SetState("Gameplay") end})
	end,

	OnUpdate = function(o)
		KeyboardHolder:Update()
		GamepadHolder:Update()
	end,


	OnDraw = function(o)
		love.graphics.draw(o.TitleImage, (WindowSize[1] - o.TitleImage:getWidth()) / 2 ,50)

		love.graphics.setColor(255,255,255)
		love.graphics.print(o.StartText, 300 ,700)
	end,
}
GameStateManager.States["Intro"] = IntroState

GameOverState = {
	WinMessage = "Congratulation you win this time but the next fight will be mine !",
	LooseMessage = "I Am the winner of this clash ! You loose !",
	
	OnStart = function(o)
		KeyboardHolder:Reset()
		GamepadHolder:Reset()

		KeyboardHolder:RegisterListener("r",{OnPress = function() GameStateManager:SetState("Intro") end})
		GamepadHolder:RegisterListener("back",{OnPress =function() GameStateManager:SetState("Intro") end})
	end,


	OnDraw = function(o)
		local hasWin = Character.LifePoint > 0 and ProjectileLauncher.LifePoint < 1 
		local endMessage = hasWin and o.WinMessage or o.LooseMessage
									  
		love.graphics.setColor(255,255,255)
		love.graphics.print(endMessage, 250 ,200) 


		love.graphics.print("R or Back to go to Title", 300 ,700)

	end,
	OnUpdate = function(o)
		KeyboardHolder:Update()
		GamepadHolder:Update()
	end,
}
GameStateManager.States["GameOver"] = GameOverState

love.update = function(dt)
	if love.keyboard.isDown("escape") then
  		love.event.push('quit')
	end
	dt = dt * TIME_FACTOR
	GameStateManager:Update(dt)
end

love.draw = function()
	GameStateManager:Draw()
end
