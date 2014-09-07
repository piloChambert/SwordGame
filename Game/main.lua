-- garbage
local joystick
--

local playerSprites = require "PlayerSprites"

local playerSprite
local levelMap
local font

Map = require "Map"

PlayerControl = {}

function PlayerControl.canGoLeft()
	return love.keyboard.isDown("left") or joystick:isGamepadDown("dpleft") or joystick:getGamepadAxis("leftx") < -0.5
end

function PlayerControl.canGoRight()
	return love.keyboard.isDown("right") or joystick:isGamepadDown("dpright") or joystick:getGamepadAxis("leftx") > 0.5
end

function PlayerControl.canGoUp()
	return love.keyboard.isDown("up") or joystick:isGamepadDown("dpup") or joystick:getGamepadAxis("lefty") < -0.5
end

function PlayerControl.canGoDown()
	return love.keyboard.isDown("down") or joystick:isGamepadDown("dpdown") or joystick:getGamepadAxis("lefty") > 0.5
end

function PlayerControl.canJump()
	return love.keyboard.isDown("z") or joystick:isGamepadDown("a")
end

function PlayerControl.canAttack()
	return love.keyboard.isDown("q") or joystick:isGamepadDown("x")
end

function PlayerControl.canDefend()
	return love.keyboard.isDown("d") or joystick:isGamepadDown("b")
end

local Entity = {}
Entity.__index = Entity

-- create a new entity instance, with default values
function Entity.new(spriteSheet)
	local self = setmetatable({}, Entity)

	-- start position
	self.x = 16
	self.y = 128

	-- idling
	self.speedX = 0
	self.speedY = 0

	-- use for motion
	self.maxSpeed = 64
	self.acceleration = 512

	-- reset animation timer 
	self.animationFrame = 0
	self.animationTimer = 0

	-- look right
	self.direction = 1

	-- no sprite
	self.sprite = nil

	-- bounding box
	self.width = 8
	self.height = 15

	-- no action
	self.action = nil

	return self
end

-- draw the entity
function Entity:draw()
	--love.graphics.polygon("fill", self.x - self.width * 0.5, self.y - self.height, self.x + self.width * 0.5, self.y - self.height, self.x + self.width * 0.5, self.y, self.x - self.width * 0.5, self.y)

	if self.sprite ~= nil then
		love.graphics.draw(self.sprite.image, self.sprite.quad, self.x, self.y, 0, 1.0, 1.0, -self.sprite.xoffset, -self.sprite.yoffset + 1) -- +1 because the character positin is at the bottom (and the mark on the sprite is on the last row)
	end
end

-- update animation timer and frame (based on animation frame count and frame rate)
function Entity:updateAnimation(frameCount, frameRate)
  	local dt = love.timer.getDelta()

	self.animationTimer = self.animationTimer + dt

	if self.animationTimer > frameRate then
		self.animationFrame = (self.animationFrame + 1) % frameCount
		self.animationTimer = self.animationTimer - frameRate
	end
end

-- change the action of the entity
-- this reset the animation timer & frame
function Entity:changeAction(newAction)
	self.animationTimer = 0
	self.animationFrame = 0

	self.action = newAction
end

function Entity:GetAABB()
	local aabb = { min = {}, max = {} }
	aabb.min[0] = self.x - self.width * 0.5
	aabb.max[0] = self.x + self.width * 0.5
	aabb.min[1] = self.y - self.height
	aabb.max[1] = self.y

	return aabb
end

function Entity:OnGround()
	-- just do a cast 1px below
	local aabb = self:GetAABB()
	return levelMap:AABBCast(aabb, {[0] = 0, [1] = 1}) == 0
end

-- move the entity according to its speed, and handle collsion with world
function Entity:MoveAndCollide(dt)
	local aabb = self:GetAABB()

	-- gravity
	-- if the entity is not on a solid tile, it's falling
	if not self:OnGround() then
		-- increment speed Y
  		self.speedY = math.min(self.speedY + 8.0, 256.0)
  	end

	--print("")
	--print("----------------------------------")
	--print("old position", self.x, self.y, self.speedX, self.speedY, xdisp, ydisp)

	local timeLeft = dt
	while timeLeft > 0.0 do
		aabb = self:GetAABB()

		-- compute displacement
		local xdisp = self.speedX * timeLeft
		local ydisp = self.speedY * timeLeft

		local v = {}
		v[0] = xdisp
		v[1] = ydisp

		u, n = levelMap:AABBCast(aabb, v)

		if u < 1.0 then
			xdisp = xdisp * u
			ydisp = ydisp * u

			if n == 0 then
				self.speedX = 0
			elseif n == 1 then
				self.speedY = 0
			end
		end

		-- update position
		self.x = self.x + xdisp
		self.y = self.y + ydisp

		-- update time counter
		timeLeft = timeLeft - (u * timeLeft)
	end

	--print("new position", self.x, self.y, self.speedX, self.speedY, xdisp, ydisp)
end

-- falling state
function fall(self, dt)
	-- we can attach will in air
  	if PlayerControl.canAttack() then
  		-- change state
  		self:changeAction(attack)
  	end

  	-- we can move left and right
	if PlayerControl.canGoLeft() then
		self.speedX = math.max(self.speedX - 16.0, -64.0)
		self.direction = 1
	end

	if PlayerControl.canGoRight() then
		self.speedX = math.min(self.speedX + 16.0, 64.0)
		self.direction = 0
	end

	-- we reach the ground, back to idle state
  	if self:OnGround() then
  		-- change state
  		self.action = idle
  	end

  	-- if the user can grab a ladder, do that
	if PlayerControl.canGoUp() and levelMap:distanceToLadder(self) ~= nil then
		self:changeAction(ladder)
	end

  	-- update position and velocity
  	self:MoveAndCollide(dt)

  	-- use an idling sprite
  	self.sprite = playerSprites.frames[playerSprites.runAnimation[self.animationFrame + 1] + self.direction * 10]
end

function run(self, dt)
	-- test input
  	if PlayerControl.canGoLeft() then
  		-- accelerate to the left
  		self.speedX = math.max(self.speedX - self.acceleration * dt, -self.maxSpeed)

  		-- character look to the left
		self.direction = 1
  	elseif PlayerControl.canGoRight() then
  		-- accelerate to the right
  		self.speedX = math.min(self.speedX + self.acceleration * dt, self.maxSpeed)

  		-- character look to the right
		self.direction = 0
	else
		-- no input? go back in idling state
		self.action = idle
  	end

  	-- update position and velocity
  	self:MoveAndCollide(dt)

  	-- are we still on the ground?
  	if not self:OnGround() then
  		-- no, then go into fall state
  		self.action = fall
  	else
 		-- we're on ground
	  	if PlayerControl.canJump() then

  			-- so we can jump
			self.speedY = -200.0
			self.action = fall
	  	end

  	end

	-- update sprite
	self:updateAnimation(4, 1.0 / 16.0)
	self.sprite = playerSprites.frames[playerSprites.runAnimation[self.animationFrame + 1] + self.direction * 10]

	-- we can attack while moving
  	if PlayerControl.canAttack() then
  		-- change state
  		self.speedX = 0
  		self:changeAction(attack)
  	end

  	-- and defend
	if PlayerControl.canDefend() then
  		-- change state
	  	self:changeAction(defend)
	end
end

-- idling state, the character does nothing
function idle(self, dt)
	-- we need to slow donw in order to stop moving
	if self.speedX > 0.0 then
		self.speedX = math.max(self.speedX - self.acceleration * dt, 0.0)
	end

	if self.speedX < 0.0 then
		self.speedX = math.min(self.speedX + self.acceleration * dt, 0.0)
	end

	-- if the players wants to move, change to run state
  	if PlayerControl.canGoLeft() or PlayerControl.canGoRight() then
		self.action = run
  	end

  	-- attack
  	if PlayerControl.canAttack() then
  		-- change state
  		self:changeAction(attack)
  	end

  	-- defend
	if PlayerControl.canDefend() then
  		-- change state
	  	self:changeAction(defend)
	end

	-- if we can fall, switch to fall state
  	if not self:OnGround() then
  		self.action = fall
  	else 
  		-- we're on ground
	  	if PlayerControl.canJump() then
  			-- so we can jump
			self.speedY = -200.0
			self.action = fall
	  	end
  	end

  	-- if the user can grab a ladder, do that
	if (PlayerControl.canGoDown() or PlayerControl.canGoUp()) then
		x, t, b = levelMap:distanceToLadder(self)
		if x ~= nil and ((PlayerControl.canGoDown() and b > 0) or (PlayerControl.canGoUp() and t > 0))  then
			self:changeAction(ladder)
		end
	end

	-- update position and velocity
  	self:MoveAndCollide(dt)

  	-- show idling sprite
	self.sprite = playerSprites.frames[playerSprites.runAnimation[self.animationFrame + 1] + self.direction * 10]
end

-- attack state
function attack(self, dt)
	-- we need to slow down in order to stop moving if we are on the ground
	aabb = self:GetAABB()
  	if levelMap:AABBCast(aabb, {[0] = 0, [1] = 1}) == 0.0 then
		if self.speedX > 0.0 then
			self.speedX = math.max(self.speedX - self.acceleration * dt, 0.0)
		end

		if self.speedX < 0.0 then
			self.speedX = math.min(self.speedX + self.acceleration * dt, 0.0)
		end
	end

  	-- update animation
  	self:updateAnimation(6, 1.0 / 30.0)
	self.sprite = playerSprites.frames[playerSprites.attackAnimation[self.animationFrame + 1] + self.direction * 10]

	-- we can still be moving
  	self:MoveAndCollide(dt)

  	-- end of the animation, go back to idling state
	if self.animationFrame == 5 then
		self:changeAction(idle)
	end
end

-- defend, just stop and use shield
function defend(self, dt)
	-- slow down
	if self.speedX > 0.0 then
		self.speedX = math.max(self.speedX - self.acceleration * dt, 0.0)
	end

	if self.speedX < 0.0 then
		self.speedX = math.min(self.speedX + self.acceleration * dt, 0.0)
	end

	-- no longer in defense
	if not PlayerControl.canDefend() then
		self:changeAction(idle)
	end

	-- use shield sprite
	self.sprite = playerSprites.frames[13 + self.direction * 10]

	-- update position and velocity
	self:MoveAndCollide(dt)
end

-- ladder state
function ladder(self, dt)
	-- move the sprite to the ladder
	delta, distanceToTop, distanceToBottom = levelMap:distanceToLadder(self) -- return the distance from center to center

	-- delta == nil means the character is no longer on a ladder tile
	if delta == nil then
		-- so switch back to idling state
		self:changeAction(idle)
	else
		-- reset speed
		self.speedX = 0
		self.speedY = 0

		-- move the character on the ladder
		self.x = self.x + math.max(math.min(delta, 68.0 * dt), -64.0 * dt)

		local disp = 0.0


		if PlayerControl.canGoUp() then
			disp = -48 * dt
		elseif PlayerControl.canGoDown() then
			disp = 48 * dt
		end

		-- if the player is moving on the ladder
		if disp ~= 0 then
			local aabb = self:GetAABB()
			u, n = levelMap:AABBCast(aabb, {[0] = 0, [1] = disp}, "ladder")

			if u < 1.0 then
				-- we can't go lower, go back to idle state
				if disp > 0 then
					self:changeAction(idle)
				end

				disp = disp * u

			end

			if disp < -distanceToTop or disp > distanceToBottom then
				-- clamp
				disp = math.min(math.max(disp, -distanceToTop), distanceToBottom)

				self:changeAction(idle)
			end

			self.y = self.y + disp

			-- update animation
			self:updateAnimation(2, 1.0 / 8.0)
			self.sprite = playerSprites.frames[31 + self.animationFrame]
		else
			-- state idling on the ladder, use idling sprite
			self.sprite = playerSprites.frames[30]
		end

		-- jump
	  	if PlayerControl.canJump() then
			self.speedY = -10.0
			self.action = fall

			self:changeAction(fall)
	  	end

	end
end

function love.load()
	-- change window mode
	success = love.window.setMode(1280, 768, {resizable=false, vsync=true, fullscreen=false})
	love.window.setTitle("Sword Game")

	-- create player sprite
	playerSprite = Entity.new()
	playerSprite.action = idle

	-- load test level
	levelMap = Map.new(require "testlevel")
	levelMap:setSize(320, 160)

	print("Joystick count :", love.joystick.getJoystickCount())

	-- use joystick (for testing puprose)
	joysticks = love.joystick.getJoysticks()
	joystick = joysticks[1]

	font = love.graphics.newImageFont("test_font.png",
    " !\"#$%&`()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'abcdefghijklmnopqrstuvwxyz{:}" )
    font:setFilter("nearest", "nearest")
    love.graphics.setFont(font)
end

local time_acc = 0.0

function love.update(dt)
	-- get elapsed time since last frame
	dt = love.timer.getDelta()

	-- fixed time step
	timeStep = 1.0 / 60.0

	time_acc = time_acc + dt

	while time_acc > timeStep do
		time_acc = time_acc - timeStep
		
		-- update player entity
		playerSprite:action(timeStep)

		-- update scrolling to show the player
		levelMap:scrollTo(playerSprite)
	end
end

function love.draw()
	-- use scalling, make pixel bigger 
   	love.graphics.scale(4.0, 4.0)
   	love.graphics.setColor(255, 255, 255, 255)
    love.graphics.print("Ahhhhh!!!! 93556", 0, 0)
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 0, 10)

    -- draw the world 32 pixel from the top
   	love.graphics.translate(0, 32)

	-- set scissor 
	love.graphics.setScissor(0, 32 * 4, 320 * 4, 160 * 4)

	-- draw the world
   	levelMap:draw()
   	
   	-- draw the entities
   	-- translate according to current world scrolling
  	love.graphics.translate(-levelMap.dx, -levelMap.dy)

	-- draw character
	playerSprite:draw()

	-- restore state
	love.graphics.setScissor()
end