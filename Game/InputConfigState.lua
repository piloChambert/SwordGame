inputConfigState = {}

inputConfigState.keyboard_img = love.graphics.newImage("UI/keyboard.png")
inputConfigState.keyboard_img:setFilter("nearest", "nearest")

inputConfigState.pad_img = love.graphics.newImage("UI/xpad.png")
inputConfigState.pad_img:setFilter("nearest", "nearest")

function inputConfigState:load(game)
	self.selectedEvent = 1

	game:playMusic("Music/main_title.xm")
end

function inputConfigState:actiontriggered(game, action)
	if action == "down" and self.selectedEvent < 7 then
		self.selectedEvent = self.selectedEvent + 1
		sound.menu_select:play()
	end		

	if action == "up" and self.selectedEvent > 1 then
		self.selectedEvent = self.selectedEvent - 1
		sound.menu_select:play()
	end

	if action == "start" or action == "attack" then
		sound.menu_valid:play()
	end

	if action == "back" then
		game:popState()
		game:pushState(levelState)
	end
end

function inputConfigState:update(game, dt)
end

function inputConfigState:drawKeyboard()
	local events = {"up", "down", "left", "right", "jump", "attack", "defend"}
	for i, event in ipairs(events) do
		local y = 70 + i * 12

		if i == self.selectedEvent then
			love.graphics.setColor(255, 255, 0, 255)
		else
			love.graphics.setColor(255, 255, 255, 255)
		end	


		love.graphics.print(event, 10, y)

		local keys = PlayerControl.player1Control.event[event] 

		if keys[1] ~= nil then
			love.graphics.print(keys[1], 80, y)
		end

		if keys[2] ~= nil then
			love.graphics.print(keys[2], 150, y)
		end

		if keys[3] ~= nil then
			love.graphics.print(keys[3], 220, y)
		end

	end	

	love.graphics.setColor(255, 255, 255, 255)

end

function inputConfigState:draw(game)
	love.graphics.setColor(255, 255, 255, 255)	
	love.graphics.print("Choose controller", 50, 20)
	love.graphics.print("Player1", 50, 30)

	love.graphics.draw(self.keyboard_img, 32, 60)
	love.graphics.draw(self.pad_img, 192, 60)

	-- print config
	self:drawKeyboard()
end
