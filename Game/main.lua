require "list"
require "sound"
require "SpriteFrame"
require "Map"
require "PlayerControl"
require "Entity"
require "PlayerEntity"
require "Enemies"
require "PowerUp"
require "Vector"
require "UIElement"
require "LevelState"
require "InputConfigState"
require "MainMenu"
require "versusLevelState"
require "Weapons"

titleScreenState = { thread = nil, game = nil }

function wait(game, time)
	while time > 0 do
		self, game, dt = coroutine.yield(true)
		time = time - dt
	end
end

function waitInput(game, input)
	while not PlayerControl.player1Control:testTrigger(input) do
		self, game, dt = coroutine.yield(true)
	end
end

function titleScreenState:updateThread(game, dt)
	-- fade text it
	local text1 = TextElement("Press Start!", Vector(20, 100))
	text1:addAnimation(BasicAnimation("opacity", 0, 255, 0.1, true), "fade")
	text1:addAnimation(BasicAnimation("position", Vector(20, 95), Vector(20, 105), 0.2, true), "move")
	self.elements:push(text1)

	local text2 = TypeWritterTextElement("It will start soon :)", Vector(20, 150))
	self.elements:push(text2)

	waitInput(game, "start")

	text1:addAnimation(BasicAnimation("opacity", 255, 0, 0.1), "fade")
	wait(game, 0.2)
	text2:addAnimation(BasicAnimation("opacity", 255, 0, 0.1), "fade")
	wait(game, 0.5)

	-- start a level
	-- change state
	game.states:pop()

	-- set level state
	levelState.levelIndex = 1
	game.states:push(levelState)
	game.states.last:load(game)
end

function titleScreenState:update(game, dt)
	self:thread(game, dt)

	for elem in self.elements:iterate() do
		-- update entity
		elem:update(dt)
	end

end

function titleScreenState:draw(game)
	for element in self.elements:iterate() do
		-- update entity
		element:draw()
	end

end

function titleScreenState:load(game)
	self.game = game
	self.thread = coroutine.wrap(self.updateThread)

	self.elements = list()
end


-- main game class
local Game = { 
	font = nil,

	levels = {  { map = "testlevel2", 	music = "title1.xm"},
				{ map = "testSegment1",	music = "main_title.xm"},
				{ map = "testlevel8",	music = "title5.xm"},
				{ map = "testlevel6", 	music = "main_title.xm"},
				{ map = "testlevel3", 	music = "title2.xm"},
				{ map = "testlevel", 	music = "title3.xm"},
				{ map = "testlevel4", 	music = "title4.xm"},
				{ map = "testlevel5",	music = "title1.xm"} }, 
	currentLevel = 0,

	musicSource = nil,
	musicVolume = 1.0,

	screenWidth = 320,
	screenHeight = 180,
	screenScale = 4,

	states = list()
}

-- load the game
function Game:load()
    -- load the default font
	self.font = love.graphics.newImageFont("Fonts/font claire 2.png",
    " !\"#$%&`()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'abcdefghijklmnopqrstuvwxyz{|}" )
    self.font:setFilter("nearest", "nearest")
    love.graphics.setFont(self.font)

    --self:pushState(titleScreenState)
   	--self:pushState(mainMenuState)
   	self:pushState(levelState)
   	--self:pushState(versusLevelState)
    
     
end

function Game:playMusic(musicFilename)
	if self.musicSource ~= nil then
		self.musicSource:stop()
	end

	if musicFilename ~= nil then
		self.musicSource = love.audio.newSource(musicFilename, "stream")
		self.musicSource:setLooping(true)
		self.musicSource:setVolume(self.musicVolume)
		self.musicSource:play()
	else
		self.musicSource = nil
	end
end

function Game:pushState(state)
	-- push the state on the stack
	self.states:push(state)

	-- and load it
	state:load(self)
end

function Game:popState()
	self.states:pop()
end

function Game:update(dt) 	
	if self.states.last ~= nil then
		self.states.last:update(self, dt)
	end
	
end

function Game:draw(dt)
	-- draw every states!
	love.graphics.setColor(255, 255, 255, 255)
	for state in self.states:iterate() do
		state:draw(self)
	end
end

function Game:actiontriggered(action)
	if self.states.last.actiontriggered then
		self.states.last:actiontriggered(self, action)
	end
end

function printOutline(str, x, y)
	love.graphics.setColor(0, 0, 0, 255)
    love.graphics.print(str, x-1, y-1)
    love.graphics.print(str, x, y-1)
	love.graphics.print(str, x+1, y-1)
    love.graphics.print(str, x-1, y)
	love.graphics.print(str, x+1, y)
    love.graphics.print(str, x-1, y+1)
    love.graphics.print(str, x, y+1)
	love.graphics.print(str, x+1, y+1)

	love.graphics.setColor(255, 255, 255, 255)	
    love.graphics.print(str, x, y)
end

local mainCanvas;

function love.load()
	-- change window mode
	love.window.setTitle("Sword Game")

	Game:load()
	love.window.setMode(Game.screenWidth * Game.screenScale, Game.screenHeight * Game.screenScale, {resizable=false, vsync=true, fullscreen=false})

	mainCanvas = love.graphics.newCanvas(Game.screenWidth, Game.screenHeight)

	local pixelcode = [[
        vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
        {
            int x = int(mod(screen_coords.x, 4));
            int y = int(mod(screen_coords.y, 4));

            vec4 texcolor = Texel(texture, texture_coords);

            float a = 0.6;

            if(x == 0 || x == 3) {
            	color = vec4(1, a, a, 1);
            } else if(x == 1) {
            	color = vec4(a, 1.0, a, 1);
        	} else {
        		color = vec4(a, a, 1.0, 1);
        	}

        	// scanline
        	if(y == 0) {
        		color *= 0.9;
           	} else if(y == 1) {
	       		color *= 0.97;
        	} else if(y == 2) {
        		color *= 1.0;
        	} else if(y == 3) {
        		color *= 0.97;
        	}


            return texcolor * color;
        }
    ]]

    local vertexcode = [[
        vec4 position( mat4 transform_projection, vec4 vertex_position )
        {
            return transform_projection * vertex_position;
        }
    ]]

    crtShader = love.graphics.newShader(pixelcode, vertexcode)

end

local time_acc = 0.0
local total_time = 0.0
local total_frame = 0

function love.update(dt)
	-- fixed time step
	local timeStep = 1.0 / 60.0

	time_acc = time_acc + dt

	while time_acc > timeStep do
		--Game:update(timeStep)

		time_acc = time_acc - timeStep
		total_time = total_time + timeStep
		total_frame = total_frame + 1
	end

	Game:update(dt)

	-- update input
	-- we always have to update this (maybe it should be done somewhere else?)
	actions = PlayerControl.player1Control:update()
	for i, action in ipairs(actions) do
		Game:actiontriggered(action)
	end

	PlayerControl.player2Control:update()
end

crtEmulation = false

function love.draw()
	love.graphics.setCanvas(mainCanvas)
	love.graphics.clear()
	love.graphics.setShader()		
   	Game:draw()

   	love.graphics.setColor(255, 255, 255, 255)
   	if crtEmulation then
   		mainCanvas:setFilter("linear", "linear")
   		love.graphics.setShader(crtShader)
   	else
   		mainCanvas:setFilter("nearest", "nearest")   		
   	end

   	love.graphics.setCanvas()
   	love.graphics.draw(mainCanvas, 0, 0, 0, Game.screenScale, Game.screenScale)
end