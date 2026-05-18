local window_width = 1280
local window_height = 720

function love.load()
	love.window.setMode(window_width, window_height)

	player = {
		x = 0,
		y = 0,
		size = 32,
		speed = 32,
		hp = 100,
		damageCooldown = 0,
		damageInterval = 1,
		experience = 0,
		level = 1,
	}

	camera = {
		x = 0,
		y = 0,
	}

	enemies = {}
	enemySize = 32
	enemySpeed = 48
	baseMaxEnemies = 10

	bullets = {}
	bulletSpeed = 600
	bulletSize = 4
	bulletFireRate = 1 / 3
	fireRateLevel = 3
	bulletCooldown = 0
	detectionRange = 300

	boomerangs = {}
	boomerangCooldown = 0
	boomerangSize = 8
	boomerangRotationSpeed = 5
	boomerangExpandSpeed = 200

	gameOver = false

	joystick = nil
	deadzone = 0.2

	levelUpActive = false
	levelUpChoices = {}
	selectedChoice = 1

	upgradePool = {
		{
			name = "Fire Rate",
			description = "+1 shot per second",
			apply = function()
				fireRateLevel = fireRateLevel + 1
				bulletFireRate = 1 / fireRateLevel
			end,
		},
		{
			name = "Move Speed",
			description = "+16 move speed",
			apply = function()
				player.speed = player.speed + 16
			end,
		},
		{
			name = "Detection Range",
			description = "+100 gun range",
			apply = function()
				detectionRange = detectionRange + 100
			end,
		},
	}

	resetGame()
end

function love.joystickadded(j)
	if not joystick then
		joystick = j
	end
end

function love.joystickremoved(j)
	if joystick == j then
		joystick = nil
	end
end

function resetGame()
	player.x = 0
	player.y = 0
	player.hp = 100
	player.damageCooldown = 0
	player.speed = 32
	player.experience = 0
	player.level = 1

	bulletSpeed = 600
	detectionRange = 300
	fireRateLevel = 3
	bulletFireRate = 1 / 3

	camera.x = player.x - (window_width / 2)
	camera.y = player.y - (window_height / 2)

	enemies = {}
	bullets = {}
	bulletCooldown = 0
	boomerangs = {}
	boomerangCooldown = 0

	levelUpActive = false
	levelUpChoices = {}
	selectedChoice = 1

	spawnEnemies()

	gameOver = false
end

function generateLevelUpChoices()
	levelUpChoices = {}
	local available = {}
	for i, v in ipairs(upgradePool) do
		available[i] = v
	end

	for i = 1, 3 do
		if #available == 0 then
			break
		end
		local idx = math.random(1, #available)
		table.insert(levelUpChoices, available[idx])
		table.remove(available, idx)
	end
end

function spawnEnemies()
	local maxEnemies = baseMaxEnemies + (player.level - 1) * 10
	while #enemies < maxEnemies do
		local edge = math.random(4)
		local margin = 50
		local x, y

		if edge == 1 then
			x = camera.x - margin
			y = camera.y + math.random() * window_height
		elseif edge == 2 then
			x = camera.x + window_width + margin
			y = camera.y + math.random() * window_height
		elseif edge == 3 then
			x = camera.x + math.random() * window_width
			y = camera.y - margin
		else
			x = camera.x + math.random() * window_width
			y = camera.y + window_height + margin
		end

		table.insert(enemies, { x = x, y = y, size = enemySize, hp = 3 })
	end
end

function findClosestEnemy()
	local closest = nil
	local closestDist = detectionRange

	for _, enemy in ipairs(enemies) do
		local dx = enemy.x - player.x
		local dy = enemy.y - player.y
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist < closestDist then
			closestDist = dist
			closest = enemy
		end
	end

	return closest
end

function love.update(dt)
	if gameOver or levelUpActive then
		return
	end

	local dx = 0
	local dy = 0

	if love.keyboard.isDown("w", "up") then
		dy = dy - 1
	end
	if love.keyboard.isDown("s", "down") then
		dy = dy + 1
	end
	if love.keyboard.isDown("a", "left") then
		dx = dx - 1
	end
	if love.keyboard.isDown("d", "right") then
		dx = dx + 1
	end

	if joystick then
		local stickX = joystick:getGamepadAxis("leftx")
		local stickY = joystick:getGamepadAxis("lefty")

		if math.abs(stickX) < deadzone then
			stickX = 0
		end
		if math.abs(stickY) < deadzone then
			stickY = 0
		end

		if stickX ~= 0 or stickY ~= 0 then
			dx = dx + stickX
			dy = dy + stickY
		end

		if joystick:isGamepadDown("dpleft") then
			dx = dx - 1
		end
		if joystick:isGamepadDown("dpdown") then
			dy = dy + 1
		end
		if joystick:isGamepadDown("dpright") then
			dx = dx + 1
		end
		if joystick:isGamepadDown("dpup") then
			dy = dy - 1
		end
	end

	if dx ~= 0 or dy ~= 0 then
		local len = math.sqrt(dx * dx + dy * dy)
		dx = dx / len
		dy = dy / len
	end

	player.x = player.x + dx * player.speed * dt
	player.y = player.y + dy * player.speed * dt

	camera.x = player.x - (window_width / 2)
	camera.y = player.y - (window_height / 2)

	for _, enemy in ipairs(enemies) do
		local dirX = player.x - enemy.x
		local dirY = player.y - enemy.y
		local len = math.sqrt(dirX * dirX + dirY * dirY)
		if len > 0 then
			dirX = dirX / len
			dirY = dirY / len
		end
		enemy.x = enemy.x + dirX * enemySpeed * dt
		enemy.y = enemy.y + dirY * enemySpeed * dt
	end

	player.damageCooldown = player.damageCooldown - dt

	for _, enemy in ipairs(enemies) do
		local playerLeft = player.x - player.size / 2
		local playerRight = player.x + player.size / 2
		local playerTop = player.y - player.size / 2
		local playerBottom = player.y + player.size / 2

		local enemyLeft = enemy.x - enemy.size / 2
		local enemyRight = enemy.x + enemy.size / 2
		local enemyTop = enemy.y - enemy.size / 2
		local enemyBottom = enemy.y + enemy.size / 2

		if
			playerRight > enemyLeft
			and playerLeft < enemyRight
			and playerBottom > enemyTop
			and playerTop < enemyBottom
		then
			if player.damageCooldown <= 0 then
				player.hp = player.hp - 10
				player.damageCooldown = player.damageInterval
			end
		end
	end

	if player.hp <= 0 then
		gameOver = true
	end

	bulletCooldown = bulletCooldown - dt

	local closest = findClosestEnemy()
	if closest and bulletCooldown <= 0 then
		local dirX = closest.x - player.x
		local dirY = closest.y - player.y
		local len = math.sqrt(dirX * dirX + dirY * dirY)
		if len > 0 then
			dirX = dirX / len
			dirY = dirY / len
		end
		table.insert(bullets, { x = player.x, y = player.y, dx = dirX, dy = dirY })
		bulletCooldown = bulletFireRate
	end

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		bullet.x = bullet.x + bullet.dx * bulletSpeed * dt
		bullet.y = bullet.y + bullet.dy * bulletSpeed * dt

		local distFromPlayer = math.sqrt((bullet.x - player.x) ^ 2 + (bullet.y - player.y) ^ 2)
		if distFromPlayer > 1000 then
			table.remove(bullets, i)
		end
	end

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		local hit = false

		for j = #enemies, 1, -1 do
			local enemy = enemies[j]
			local dx = bullet.x - enemy.x
			local dy = bullet.y - enemy.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < bulletSize + enemy.size / 2 then
				enemy.hp = enemy.hp - 1
				hit = true
				if enemy.hp <= 0 then
					table.remove(enemies, j)
					player.experience = player.experience + 10
				end
				break
			end
		end

		if hit then
			table.remove(bullets, i)
		end
	end

	if player.level >= 5 and #boomerangs == 0 then
		boomerangCooldown = boomerangCooldown - dt
		if boomerangCooldown <= 0 then
			table.insert(boomerangs, {
				x = player.x,
				y = player.y,
				originX = player.x,
				originY = player.y,
				angle = 0,
				radius = 0,
				hitEnemies = {},
			})
			boomerangCooldown = math.max(1, 6 - math.floor(player.level / 5))
		end
	end

	for i = #boomerangs, 1, -1 do
		local b = boomerangs[i]
		b.angle = b.angle + boomerangRotationSpeed * dt
		b.radius = b.radius + boomerangExpandSpeed * dt
		b.x = b.originX + math.cos(b.angle) * b.radius
		b.y = b.originY + math.sin(b.angle) * b.radius

		for j = #enemies, 1, -1 do
			local enemy = enemies[j]
			if not b.hitEnemies[enemy] then
				local dx = b.x - enemy.x
				local dy = b.y - enemy.y
				local dist = math.sqrt(dx * dx + dy * dy)
				if dist < boomerangSize + enemy.size / 2 then
					enemy.hp = enemy.hp - 1
					b.hitEnemies[enemy] = true
					if enemy.hp <= 0 then
						table.remove(enemies, j)
						player.experience = player.experience + 10
					end
				end
			end
		end

		local screenX = b.x - camera.x
		local screenY = b.y - camera.y
		if screenX < -50 or screenX > window_width + 50 or screenY < -50 or screenY > window_height + 50 then
			table.remove(boomerangs, i)
		end
	end

	local xpNeeded = 100 + (player.level - 1) * 50
	if player.experience >= xpNeeded then
		player.experience = player.experience - xpNeeded
		player.level = player.level + 1
		generateLevelUpChoices()
		selectedChoice = 1
		levelUpActive = true
	end

	spawnEnemies()
end

function love.draw()
	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("fill", 0, 0, window_width, window_height)

	local gridSize = 64
	local startX = math.floor(camera.x / gridSize) * gridSize
	local startY = math.floor(camera.y / gridSize) * gridSize

	love.graphics.setColor(0.3, 0.3, 0.3)
	for x = startX, camera.x + window_width, gridSize do
		local screenX = x - camera.x
		love.graphics.line(screenX, 0, screenX, window_height)
	end
	for y = startY, camera.y + window_height, gridSize do
		local screenY = y - camera.y
		love.graphics.line(0, screenY, window_width, screenY)
	end

	local legendFont = love.graphics.newFont(24)
	love.graphics.setFont(legendFont)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("HP: " .. player.hp, 10, 10)

	love.graphics.print("Level: " .. player.level, 10, 30)
	local xpNeeded = 100 + (player.level - 1) * 50
	love.graphics.print("XP: " .. player.experience .. "/" .. xpNeeded, 10, 50)
	love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 70)

	local statsFont = love.graphics.newFont(24)
	love.graphics.setFont(statsFont)
	local statsX = window_width - 10
	love.graphics.setColor(1, 1, 1)
	local fireRateText = "Fire Rate: " .. fireRateLevel .. "/s"
	local moveSpeedText = "Move Speed: " .. player.speed
	local detectRangeText = "Detection: " .. detectionRange
	love.graphics.print(fireRateText, statsX - statsFont:getWidth(fireRateText), 10)
	love.graphics.print(moveSpeedText, statsX - statsFont:getWidth(moveSpeedText), 30)
	love.graphics.print(detectRangeText, statsX - statsFont:getWidth(detectRangeText), 50)

	if player.level >= 5 then
		local boomerangCd = math.max(1, 6 - math.floor(player.level / 5))
		local boomerangText = "Boomerang: " .. string.format("%.1f", boomerangCooldown) .. "/" .. boomerangCd .. "s"
		love.graphics.print(boomerangText, statsX - statsFont:getWidth(boomerangText), 70)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle(
		"fill",
		(window_width / 2) - player.size / 2,
		(window_height / 2) - player.size / 2,
		player.size,
		player.size
	)

	love.graphics.setColor(1, 0, 0)
	for _, enemy in ipairs(enemies) do
		local screenX = enemy.x - camera.x
		local screenY = enemy.y - camera.y
		love.graphics.rectangle("fill", screenX - enemy.size / 2, screenY - enemy.size / 2, enemy.size, enemy.size)
	end

	love.graphics.setColor(0.5, 0.5, 0.5)
	for _, bullet in ipairs(bullets) do
		local screenX = bullet.x - camera.x
		local screenY = bullet.y - camera.y
		love.graphics.circle("fill", screenX, screenY, bulletSize)
	end

	love.graphics.setColor(0, 1, 1)
	for _, b in ipairs(boomerangs) do
		local screenX = b.x - camera.x
		local screenY = b.y - camera.y
		love.graphics.circle("fill", screenX, screenY, boomerangSize)
	end

	if gameOver then
		love.graphics.setColor(0, 0, 0, 0.7)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		local gameOverFont = love.graphics.newFont(48)
		love.graphics.setFont(gameOverFont)
		local gameOverText = "Game Over"
		local textWidth = gameOverFont:getWidth(gameOverText)
		love.graphics.print(gameOverText, (window_width / 2) - textWidth / 2, 250)

		local legendFont = love.graphics.newFont(24)
		love.graphics.setFont(legendFont)
		local legendText = "Press ENTER to restart or A in the controller (Escape to quit)"
		local legendWidth = legendFont:getWidth(legendText)
		love.graphics.print(legendText, (window_width / 2) - legendWidth / 2, 330)
	end

	if levelUpActive then
		love.graphics.setColor(0, 0, 0, 0.7)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		local titleFont = love.graphics.newFont(48)
		love.graphics.setFont(titleFont)
		local titleText = "Level Up!"
		local titleWidth = titleFont:getWidth(titleText)
		love.graphics.print(titleText, (window_width / 2) - titleWidth / 2, 100)

		local itemFont = love.graphics.newFont(28)
		love.graphics.setFont(itemFont)
		local boxWidth = 280
		local boxHeight = 150
		local boxGap = 40
		local totalWidth = (boxWidth * 3) + (boxGap * 2)
		local startX = (window_width - totalWidth) / 2
		local boxY = 220

		for i, choice in ipairs(levelUpChoices) do
			local boxX = startX + (i - 1) * (boxWidth + boxGap)

			if i == selectedChoice then
				love.graphics.setColor(0.3, 0.3, 0.5)
			else
				love.graphics.setColor(0.2, 0.2, 0.2)
			end
			love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight)

			love.graphics.setColor(1, 1, 1)
			love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight)

			local numberText = tostring(i)
			local numWidth = itemFont:getWidth(numberText)
			love.graphics.print(numberText, boxX + (boxWidth - numWidth) / 2, boxY + 10)

			local nameText = choice.name
			local nameWidth = itemFont:getWidth(nameText)
			love.graphics.print(nameText, boxX + (boxWidth - nameWidth) / 2, boxY + 50)

			local descFont = love.graphics.newFont(20)
			local descWidth = descFont:getWidth(choice.description)
			love.graphics.setFont(descFont)
			love.graphics.setColor(0.8, 0.8, 0.8)
			love.graphics.print(choice.description, boxX + (boxWidth - descWidth) / 2, boxY + 90)
		end

		love.graphics.setFont(itemFont)
		love.graphics.setColor(1, 1, 1)
		local hintText = "Press 1, 2, or 3 to choose"
		local hintWidth = itemFont:getWidth(hintText)
		love.graphics.print(hintText, (window_width / 2) - hintWidth / 2, boxY + boxHeight + 30)
	end
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "r" then
		resetGame()
	elseif gameOver and key == "return" then
		resetGame()
	elseif levelUpActive then
		if key == "1" or key == "kp1" then
			selectUpgrade(1)
		elseif key == "2" or key == "kp2" then
			selectUpgrade(2)
		elseif key == "3" or key == "kp3" then
			selectUpgrade(3)
		end
	end
end

function love.mousepressed(x, y, button)
	if levelUpActive then
		local boxWidth = 280
		local boxHeight = 150
		local boxGap = 40
		local totalWidth = (boxWidth * 3) + (boxGap * 2)
		local startX = (window_width - totalWidth) / 2
		local boxY = 220

		for i = 1, 3 do
			local boxX = startX + (i - 1) * (boxWidth + boxGap)
			if x >= boxX and x <= boxX + boxWidth and y >= boxY and y <= boxY + boxHeight then
				selectUpgrade(i)
				break
			end
		end
	end
end

function love.gamepadpressed(j, button)
	if button == "a" and gameOver then
		resetGame()
	elseif button == "a" and levelUpActive then
		selectUpgrade(selectedChoice)
	elseif levelUpActive then
		if button == "dpleft" or button == "leftshoulder" then
			selectedChoice = math.max(1, selectedChoice - 1)
		elseif button == "dpright" or button == "rightshoulder" then
			selectedChoice = math.min(3, selectedChoice + 1)
		end
	end
end

function selectUpgrade(index)
	if index >= 1 and index <= #levelUpChoices then
		levelUpChoices[index].apply()
		levelUpActive = false
		levelUpChoices = {}
	end
end
