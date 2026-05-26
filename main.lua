local window_width = 1280
local window_height = 720

local function distSq(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return dx * dx + dy * dy
end

local function swapRemove(t, i)
	local n = #t
	t[i] = t[n]
	t[n] = nil
end

local GRID_CELL = 128
local grid = {}

local function gridKey(cx, cy)
	return cx + cy * 100000
end

local function buildGrid()
	for k in pairs(grid) do
		grid[k] = nil
	end
	for i, enemy in ipairs(enemies) do
		local cx = math.floor(enemy.x / GRID_CELL)
		local cy = math.floor(enemy.y / GRID_CELL)
		local key = gridKey(cx, cy)
		if not grid[key] then
			grid[key] = {}
		end
		table.insert(grid[key], i)
	end
end

local function getNearbyEnemies(x, y, radius)
	local result = {}
	local r2 = radius * radius
	local minCx = math.floor((x - radius) / GRID_CELL)
	local maxCx = math.floor((x + radius) / GRID_CELL)
	local minCy = math.floor((y - radius) / GRID_CELL)
	local maxCy = math.floor((y + radius) / GRID_CELL)
	for cx = minCx, maxCx do
		for cy = minCy, maxCy do
			local key = gridKey(cx, cy)
			local cell = grid[key]
			if cell then
				for _, idx in ipairs(cell) do
					local e = enemies[idx]
					if e and distSq(x, y, e.x, e.y) < r2 + (e.size * e.size) / 4 then
						table.insert(result, e)
					end
				end
			end
		end
	end
	return result
end

function love.load()
	math.randomseed(os.time())
	love.window.setMode(window_width, window_height)

	font20 = love.graphics.newFont(20)
	font24 = love.graphics.newFont(24)
	font28 = love.graphics.newFont(28)
	font48 = love.graphics.newFont(48)

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

	xpNeededA = 0
	xpNeededB = 100
	xpNeeded = xpNeededA + xpNeededB

	enemies = {}
	enemySize = 32
	enemySpeed = 48
	enemyExperience = 50
	baseMaxEnemies = 10

	eliteEnemySize = 40
	eliteEnemyHp = 6
	eliteEnemySpeed = 40
	eliteEnemyExperience = 100

	specialEnemySize = 64
	specialEnemyHp = 100
	specialEnemySpeed = 64
	specialEnemyExperience = 200
	specialEnemySpawnCount = 0
	specialEnemyHpScale = 2
	specialEnemySpeedScale = 1.05
	specialEnemyXpScale = 2

	bullets = {}
	bulletSpeed = 600
	bulletSize = 4
	bulletDamage = 1
	bulletFireRate = 1 / 3
	fireRateLevel = 3
	bulletCooldown = 0
	detectionRange = 300
	detectionRangeSq = detectionRange * detectionRange

	boomerangs = {}
	boomerangCooldown = 0
	boomerangSize = 12
	boomerangRotationSpeed = 6
	boomerangExpandSpeed = 60

	gameOver = false

	joystick = nil
	deadzone = 0.2

	levelUpActive = false
	levelUpChoices = {}
	selectedChoice = 1
	levelUpInputDelay = 0
	levelUpInputDelayDuration = 1.0

	paused = false

	dashWanted = false
	dashTimer = 0
	dashCooldown = 0
	dashDuration = 0.05
	dashRecovery = 0.40
	dashDirX = 0
	dashDirY = 0

	killsForSpecial = 200
	killsForSpecialScale = 1.5

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
				detectionRangeSq = detectionRange * detectionRange
			end,
		},
		{
			name = "Bullet Damage",
			description = "+1 bullet damage",
			apply = function()
				bulletDamage = bulletDamage + 1
			end,
		},
	}

	bulletPool = {}
	bulletPoolMax = 500

	totalKills = 0
	chests = {}
	powerBulletsRemaining = 0
	powerBulletsPerChest = 100

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
	bulletDamage = 1
	detectionRange = 300
	detectionRangeSq = detectionRange * detectionRange
	fireRateLevel = 3
	bulletFireRate = 1 / 3

	xpNeededA = 0
	xpNeededB = 100
	xpNeeded = xpNeededA + xpNeededB

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
	levelUpInputDelay = 0

	paused = false

	dashWanted = false
	dashTimer = 0
	dashCooldown = 0
	dashDirX = 0
	dashDirY = 0

	for i = 1, #bulletPool do
		bulletPool[i] = nil
	end

	totalKills = 0
	chests = {}
	powerBulletsRemaining = 0
	specialEnemySpawnCount = 0
	killsForSpecial = 200

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
	local maxEnemies = baseMaxEnemies + (player.level - 1) * 20
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

		local enemyType = "normal"
		if player.level >= 5 then
			local roll = math.random()
			if roll < 0.2 then
				enemyType = "elite"
			end
		end

		if enemyType == "elite" then
			table.insert(enemies, {
				x = x,
				y = y,
				size = eliteEnemySize,
				hp = eliteEnemyHp,
				isElite = true,
				isSpecial = false,
			})
		else
			table.insert(enemies, {
				x = x,
				y = y,
				size = enemySize,
				hp = 3,
				isElite = false,
				isSpecial = false,
			})
		end
	end
end

function spawnSpecialEnemy()
	specialEnemySpawnCount = specialEnemySpawnCount + 1

	local hpMultiplier = specialEnemyHpScale ^ specialEnemySpawnCount
	local speedMultiplier = specialEnemySpeedScale ^ specialEnemySpawnCount
	local xpMultiplier = specialEnemyXpScale ^ specialEnemySpawnCount

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

	local hp = specialEnemyHp * hpMultiplier
	table.insert(enemies, {
		x = x,
		y = y,
		size = specialEnemySize,
		hp = hp,
		maxHp = hp,
		speed = specialEnemySpeed * speedMultiplier,
		experience = specialEnemyExperience * xpMultiplier,
		isSpecial = true,
		isElite = false,
	})
end

function findClosestEnemy()
	local closest = nil
	local closestDistSq = detectionRangeSq

	for _, enemy in ipairs(enemies) do
		local d = distSq(enemy.x, enemy.y, player.x, player.y)
		if d < closestDistSq then
			closestDistSq = d
			closest = enemy
		end
	end

	return closest
end

function love.update(dt)
	if levelUpActive and levelUpInputDelay > 0 then
		levelUpInputDelay = levelUpInputDelay - dt
	end

	if gameOver or levelUpActive or paused then
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

	if dashWanted and (dx ~= 0 or dy ~= 0) and dashTimer <= 0 and dashCooldown <= 0 then
		dashDirX = dx
		dashDirY = dy
		dashTimer = dashDuration
	end
	dashWanted = false

	if dashTimer > 0 then
		player.x = player.x + dashDirX * player.speed * 12 * dt
		player.y = player.y + dashDirY * player.speed * 12 * dt
		dashTimer = dashTimer - dt
		if dashTimer <= 0 then
			dashCooldown = dashRecovery
		end
	elseif dashCooldown > 0 then
		dashCooldown = dashCooldown - dt
	else
		player.x = player.x + dx * player.speed * dt
		player.y = player.y + dy * player.speed * dt
	end

	camera.x = player.x - (window_width / 2)
	camera.y = player.y - (window_height / 2)

	for _, enemy in ipairs(enemies) do
		local speed = enemy.speed
		if not speed then
			if enemy.isSpecial then
				speed = specialEnemySpeed
			elseif enemy.isElite then
				speed = eliteEnemySpeed
			else
				speed = enemySpeed
			end
		end
		local dirX = player.x - enemy.x
		local dirY = player.y - enemy.y
		local lenSq = dirX * dirX + dirY * dirY
		if lenSq > 0 then
			local invLen = 1 / math.sqrt(lenSq)
			dirX = dirX * invLen
			dirY = dirY * invLen
		end
		enemy.x = enemy.x + dirX * speed * dt
		enemy.y = enemy.y + dirY * speed * dt
	end

	player.damageCooldown = player.damageCooldown - dt

	local halfPlayer = player.size / 2
	for _, enemy in ipairs(enemies) do
		local halfEnemy = enemy.size / 2
		if
			player.x + halfPlayer > enemy.x - halfEnemy
			and player.x - halfPlayer < enemy.x + halfEnemy
			and player.y + halfPlayer > enemy.y - halfEnemy
			and player.y - halfPlayer < enemy.y + halfEnemy
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

	if bulletCooldown <= 0 then
		local closest = findClosestEnemy()
		if closest then
			local dirX = closest.x - player.x
			local dirY = closest.y - player.y
			local lenSq = dirX * dirX + dirY * dirY
			if lenSq > 0 then
				local invLen = 1 / math.sqrt(lenSq)
				dirX = dirX * invLen
				dirY = dirY * invLen
			end

			local bullet
			if #bulletPool > 0 then
				bullet = bulletPool[#bulletPool]
				bulletPool[#bulletPool] = nil
				bullet.damageRemaining = nil
				bullet.hitEnemies = nil
			else
				bullet = {}
			end
			bullet.x = player.x
			bullet.y = player.y
			bullet.dx = dirX
			bullet.dy = dirY
			bullet.isPower = powerBulletsRemaining > 0
			bullet.damageRemaining = bullet.isPower and (bulletDamage * 2) or bulletDamage
			bullet.hitEnemies = {}
			if powerBulletsRemaining > 0 then
				powerBulletsRemaining = powerBulletsRemaining - 1
			end
			table.insert(bullets, bullet)
			bulletCooldown = bulletFireRate
		end
	end

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		bullet.x = bullet.x + bullet.dx * bulletSpeed * dt
		bullet.y = bullet.y + bullet.dy * bulletSpeed * dt

		local distFromPlayerSq = (bullet.x - player.x) ^ 2 + (bullet.y - player.y) ^ 2
		if distFromPlayerSq > 1000000 then
			if #bulletPool < bulletPoolMax then
				bullet.damageRemaining = nil
				bullet.hitEnemies = nil
				table.insert(bulletPool, bullet)
			end
			swapRemove(bullets, i)
		end
	end

	buildGrid()

	local bulletHitRadius = bulletSize + enemySize / 2
	local bulletHitRadiusSq = bulletHitRadius * bulletHitRadius

	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		local nearby = getNearbyEnemies(bullet.x, bullet.y, bulletHitRadius + enemySize)
		local hit = false

		for _, enemy in ipairs(nearby) do
			if distSq(bullet.x, bullet.y, enemy.x, enemy.y) < bulletHitRadiusSq then
				if not bullet.hitEnemies then
					bullet.hitEnemies = {}
				end
				if not bullet.hitEnemies[enemy] and enemy.hp > 0 then
					bullet.hitEnemies[enemy] = true
					hit = true

					local damageToDeal = math.min(bullet.damageRemaining, enemy.hp)
					enemy.hp = enemy.hp - damageToDeal
					bullet.damageRemaining = bullet.damageRemaining - damageToDeal

					if enemy.hp <= 0 then
						enemy.dead = true
						local xpGain = enemy.experience
						if not xpGain then
							if enemy.isSpecial then
								xpGain = specialEnemyExperience
							elseif enemy.isElite then
								xpGain = eliteEnemyExperience
							else
								xpGain = enemyExperience
							end
						end
						player.experience = player.experience + xpGain
						if enemy.isSpecial then
							table.insert(chests, { x = enemy.x, y = enemy.y, size = player.size })
						else
							totalKills = totalKills + 1
							if totalKills >= killsForSpecial then
								totalKills = totalKills - killsForSpecial
								killsForSpecial = math.floor(killsForSpecial * killsForSpecialScale)
								spawnSpecialEnemy()
							end
						end
					end

					if bullet.damageRemaining <= 0 then
						break
					end
				end
			end
		end

		if hit and bullet.damageRemaining <= 0 then
			if #bulletPool < bulletPoolMax then
				bullet.damageRemaining = nil
				bullet.hitEnemies = nil
				table.insert(bulletPool, bullet)
			end
			swapRemove(bullets, i)
		end
	end

	local writeIdx = 1
	for readIdx = 1, #enemies do
		if not enemies[readIdx].dead then
			enemies[writeIdx] = enemies[readIdx]
			writeIdx = writeIdx + 1
		end
	end
	for i = writeIdx, #enemies do
		enemies[i] = nil
	end

	boomerangCooldown = boomerangCooldown - dt

	if player.level >= 4 and boomerangCooldown <= 0 then
		table.insert(boomerangs, {
			x = player.x,
			y = player.y,
			originX = player.x,
			originY = player.y,
			angle = 0,
			radius = 0,
			hitEnemies = {},
		})
		boomerangCooldown = math.max(1, 6 - math.floor(player.level / 4))
	end

	local boomerangHitRadius = boomerangSize + enemySize / 2
	local boomerangHitRadiusSq = boomerangHitRadius * boomerangHitRadius

	for i = #boomerangs, 1, -1 do
		local b = boomerangs[i]
		b.angle = b.angle + boomerangRotationSpeed * dt
		b.radius = b.radius + boomerangExpandSpeed * dt
		b.x = b.originX + math.cos(b.angle) * b.radius
		b.y = b.originY + math.sin(b.angle) * b.radius

		local nearby = getNearbyEnemies(b.x, b.y, boomerangHitRadius + enemySize)
		for _, enemy in ipairs(nearby) do
			if not b.hitEnemies[enemy] then
				if distSq(b.x, b.y, enemy.x, enemy.y) < boomerangHitRadiusSq then
					enemy.hp = enemy.hp - 1
					b.hitEnemies[enemy] = true
					if enemy.hp <= 0 then
						enemy.dead = true
						local xpGain = enemy.experience
						if not xpGain then
							if enemy.isSpecial then
								xpGain = specialEnemyExperience
							elseif enemy.isElite then
								xpGain = eliteEnemyExperience
							else
								xpGain = enemyExperience
							end
						end
						player.experience = player.experience + xpGain
						if enemy.isSpecial then
							table.insert(chests, { x = enemy.x, y = enemy.y, size = player.size })
						else
							totalKills = totalKills + 1
							if totalKills >= killsForSpecial then
								totalKills = totalKills - killsForSpecial
								killsForSpecial = math.floor(killsForSpecial * killsForSpecialScale)
								spawnSpecialEnemy()
							end
						end
					end
				end
			end
		end

		local screenX = b.x - camera.x
		local screenY = b.y - camera.y
		if screenX < -50 or screenX > window_width + 50 or screenY < -50 or screenY > window_height + 50 then
			swapRemove(boomerangs, i)
		end
	end

	for i = #chests, 1, -1 do
		local c = chests[i]
		local halfC = c.size / 2
		local halfP = player.size / 2
		if
			player.x + halfP > c.x - halfC
			and player.x - halfP < c.x + halfC
			and player.y + halfP > c.y - halfC
			and player.y - halfP < c.y + halfC
		then
			powerBulletsRemaining = powerBulletsRemaining + powerBulletsPerChest
			swapRemove(chests, i)
		end
	end

	xpNeeded = xpNeededA + xpNeededB
	if player.experience >= xpNeeded then
		_xpNeededB = xpNeededB
		xpNeededB = xpNeededA + xpNeededB
		xpNeededA = _xpNeededB
		player.experience = player.experience - xpNeeded
		player.level = player.level + 1
		player.hp = math.min(100, player.hp + 5)
		generateLevelUpChoices()
		selectedChoice = 1
		levelUpActive = true
		levelUpInputDelay = levelUpInputDelayDuration
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

	love.graphics.setFont(font24)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("HP: " .. player.hp, 10, 10)
	love.graphics.print("Level: " .. player.level, 10, 30)
	love.graphics.print("XP: " .. player.experience .. "/" .. xpNeeded, 10, 50)
	love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 70)
	love.graphics.print("Kills: " .. totalKills .. "/" .. killsForSpecial, 10, 90)
	if powerBulletsRemaining > 0 then
		love.graphics.setColor(0, 1, 0)
		love.graphics.print("Powered Shots: " .. powerBulletsRemaining, 10, 110)
	end

	local statsX = window_width - 10
	love.graphics.setColor(1, 1, 1)
	local fireRateText = "Fire Rate: " .. fireRateLevel .. "/s"
	local moveSpeedText = "Move Speed: " .. player.speed
	local detectRangeText = "Detection: " .. detectionRange
	local damageText = "Damage: " .. bulletDamage
	love.graphics.print(fireRateText, statsX - font24:getWidth(fireRateText), 10)
	love.graphics.print(moveSpeedText, statsX - font24:getWidth(moveSpeedText), 30)
	love.graphics.print(detectRangeText, statsX - font24:getWidth(detectRangeText), 50)
	love.graphics.print(damageText, statsX - font24:getWidth(damageText), 70)

	if player.level >= 4 then
		local boomerangCd = math.max(1, 6 - math.floor(player.level / 4))
		local boomerangText = "Boomerang: " .. string.format("%.1f", boomerangCooldown) .. "/" .. boomerangCd .. "s"
		love.graphics.print(boomerangText, statsX - font24:getWidth(boomerangText), 90)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.rectangle(
		"fill",
		(window_width / 2) - player.size / 2,
		(window_height / 2) - player.size / 2,
		player.size,
		player.size
	)

	for _, enemy in ipairs(enemies) do
		local screenX = enemy.x - camera.x
		local screenY = enemy.y - camera.y
		if
			screenX > -enemy.size
			and screenX < window_width + enemy.size
			and screenY > -enemy.size
			and screenY < window_height + enemy.size
		then
			if enemy.isSpecial then
				love.graphics.setColor(0.6, 0, 0.8)
				love.graphics.rectangle(
					"fill",
					screenX - enemy.size / 2,
					screenY - enemy.size / 2,
					enemy.size,
					enemy.size
				)
				love.graphics.setColor(1, 0.8, 0)
				love.graphics.rectangle(
					"line",
					screenX - enemy.size / 2,
					screenY - enemy.size / 2,
					enemy.size,
					enemy.size
				)
				local barWidth = enemy.size
				local barHeight = 6
				local barX = screenX - barWidth / 2
				local barY = screenY - enemy.size / 2 - 12
				local maxHp = enemy.maxHp or specialEnemyHp
				love.graphics.setColor(0.3, 0, 0)
				love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
				love.graphics.setColor(0.8, 0, 1)
				love.graphics.rectangle("fill", barX, barY, barWidth * (enemy.hp / maxHp), barHeight)
			elseif enemy.isElite then
				love.graphics.setColor(1, 0.5, 0)
				love.graphics.rectangle(
					"fill",
					screenX - enemy.size / 2,
					screenY - enemy.size / 2,
					enemy.size,
					enemy.size
				)
				love.graphics.setColor(1, 1, 0)
				love.graphics.rectangle(
					"line",
					screenX - enemy.size / 2,
					screenY - enemy.size / 2,
					enemy.size,
					enemy.size
				)
			else
				love.graphics.setColor(1, 0, 0)
				love.graphics.rectangle(
					"fill",
					screenX - enemy.size / 2,
					screenY - enemy.size / 2,
					enemy.size,
					enemy.size
				)
			end
		end
	end

	love.graphics.setColor(0.6, 0.3, 0.1)
	for _, c in ipairs(chests) do
		local screenX = c.x - camera.x
		local screenY = c.y - camera.y
		if
			screenX > -c.size
			and screenX < window_width + c.size
			and screenY > -c.size
			and screenY < window_height + c.size
		then
			love.graphics.rectangle("fill", screenX - c.size / 2, screenY - c.size / 2, c.size, c.size)
		end
	end
	love.graphics.setColor(0, 0, 0)
	for _, c in ipairs(chests) do
		local screenX = c.x - camera.x
		local screenY = c.y - camera.y
		if
			screenX > -c.size
			and screenX < window_width + c.size
			and screenY > -c.size
			and screenY < window_height + c.size
		then
			love.graphics.rectangle("line", screenX - c.size / 2, screenY - c.size / 2, c.size, c.size)
		end
	end

	for _, bullet in ipairs(bullets) do
		local screenX = bullet.x - camera.x
		local screenY = bullet.y - camera.y
		if
			screenX > -bulletSize
			and screenX < window_width + bulletSize
			and screenY > -bulletSize
			and screenY < window_height + bulletSize
		then
			if bullet.isPower then
				love.graphics.setColor(0, 1, 0)
				love.graphics.circle("fill", screenX, screenY, bulletSize * 3)
			else
				love.graphics.setColor(0.5, 0.5, 0.5)
				love.graphics.circle("fill", screenX, screenY, bulletSize)
			end
		end
	end

	love.graphics.setColor(0, 1, 1)
	for _, b in ipairs(boomerangs) do
		local screenX = b.x - camera.x
		local screenY = b.y - camera.y
		if
			screenX > -boomerangSize
			and screenX < window_width + boomerangSize
			and screenY > -boomerangSize
			and screenY < window_height + boomerangSize
		then
			love.graphics.circle("fill", screenX, screenY, boomerangSize)
		end
	end

	if gameOver then
		love.graphics.setColor(0, 0, 0, 0.7)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(font48)
		local gameOverText = "Game Over"
		local textWidth = font48:getWidth(gameOverText)
		love.graphics.print(gameOverText, (window_width / 2) - textWidth / 2, 250)

		love.graphics.setFont(font24)
		local legendText = "Press ENTER to restart or A in the controller (Escape to quit)"
		local legendWidth = font24:getWidth(legendText)
		love.graphics.print(legendText, (window_width / 2) - legendWidth / 2, 330)
	end

	if paused then
		love.graphics.setColor(0, 0, 0, 0.5)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(font48)
		local pauseText = "PAUSED"
		local textWidth = font48:getWidth(pauseText)
		love.graphics.print(pauseText, (window_width / 2) - textWidth / 2, window_height / 2 - 24)

		love.graphics.setFont(font24)
		local hintText = "Press P, ENTER, or START to resume"
		local hintWidth = font24:getWidth(hintText)
		love.graphics.print(hintText, (window_width / 2) - hintWidth / 2, window_height / 2 + 30)
	end

	if levelUpActive then
		love.graphics.setColor(0, 0, 0, 0.7)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(font48)
		local titleText = "Level Up!"
		local titleWidth = font48:getWidth(titleText)
		love.graphics.print(titleText, (window_width / 2) - titleWidth / 2, 100)

		love.graphics.setFont(font28)
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
			local numWidth = font28:getWidth(numberText)
			love.graphics.print(numberText, boxX + (boxWidth - numWidth) / 2, boxY + 10)

			local nameText = choice.name
			local nameWidth = font28:getWidth(nameText)
			love.graphics.print(nameText, boxX + (boxWidth - nameWidth) / 2, boxY + 50)

			love.graphics.setFont(font20)
			local descWidth = font20:getWidth(choice.description)
			love.graphics.setColor(0.8, 0.8, 0.8)
			love.graphics.print(choice.description, boxX + (boxWidth - descWidth) / 2, boxY + 90)
		end

		love.graphics.setFont(font28)
		love.graphics.setColor(1, 1, 1)
		local hintText = "Press 1, 2, or 3 to choose"
		local hintWidth = font28:getWidth(hintText)
		love.graphics.print(hintText, (window_width / 2) - hintWidth / 2, boxY + boxHeight + 30)
	end
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "space" and not gameOver and not levelUpActive then
		dashWanted = true
	elseif key == "r" then
		resetGame()
	elseif key == "p" then
		paused = not paused
	elseif key == "return" and not gameOver and not levelUpActive then
		paused = not paused
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
	if button == "start" then
		paused = not paused
	elseif button == "a" and gameOver then
		resetGame()
	elseif button == "a" and levelUpActive then
		selectUpgrade(selectedChoice)
	elseif button == "a" then
		dashWanted = true
	elseif levelUpActive then
		if button == "dpleft" or button == "leftshoulder" then
			selectedChoice = math.max(1, selectedChoice - 1)
		elseif button == "dpright" or button == "rightshoulder" then
			selectedChoice = math.min(3, selectedChoice + 1)
		end
	end
end

function selectUpgrade(index)
	if levelUpInputDelay > 0 then
		return
	end
	if index >= 1 and index <= #levelUpChoices then
		levelUpChoices[index].apply()
		levelUpActive = false
		levelUpChoices = {}
	end
end
