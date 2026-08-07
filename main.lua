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

local function formatPlayTime(seconds)
	if seconds >= 3600 then
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		local s = math.floor(seconds % 60)
		return string.format("%02d:%02d:%02d", h, m, s)
	else
		return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
	end
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
		maxHp = 100,
		damageCooldown = 0,
		damageInterval = 1,
		experience = 0,
		level = 1,
	}

	boomerangsUnlocked = false
	boomerangLevel = 0

	camera = {
		x = 0,
		y = 0,
	}

	xpNeededA = 0
	xpNeededB = 50
	xpNeeded = xpNeededA + xpNeededB

	enemies = {}
	enemySize = 32
	enemySpeed = 48
	enemyExperience = 5
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
	specialEnemyHpScale = 1.25
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

	missilesUnlocked = false
	missileLevel = 0
	missiles = {}
	missileCooldown = 0
	missileSpawnInterval = 3.0
	missileSpreadTime = 1.0
	missileSpreadSpeed = 45
	missileAcceleration = 500
	missileSize = 5
	missileExplosionRadius = 45
	missileMaxAge = 6
	missileMaxRange = 600
	missileMaxRangeSq = missileMaxRange * missileMaxRange

	explosions = {}

	laserGunUnlocked = false
	laserGunLevel = 0
	laserGunState = "idle"
	laserGunTimer = 0
	laserGunTargetEnemy = nil
	laserGunTargetX = 0
	laserGunTargetY = 0
	laserGunDirX = 0
	laserGunDirY = 0
	laserGunStartX = 0
	laserGunStartY = 0
	laserGunDamageBase = 3

	sessionTimer = 0

	gameOver = false
	gameOverSelectedOption = 1
	gameOverOptions = { "Restart", "Quit" }

	joystick = nil
	deadzone = 0.2

	levelUpActive = false
	levelUpChoices = {}
	selectedChoice = 1
	levelUpInputDelay = 0
	levelUpInputDelayDuration = 1.0

	paused = false
	pauseSelectedOption = 1
	pauseOptions = { "Continue", "Restart", "Quit" }

	playerMoveDirX = 0
	playerMoveDirY = 0

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
			name = "Pistol",
			description = "+1 damage, +1 shot/s",
			level = 0,
			maxLevel = 5,
			apply = function()
				bulletDamage = bulletDamage + 1
				fireRateLevel = fireRateLevel + 1
				bulletFireRate = 1 / fireRateLevel
			end,
		},
		{
			name = "Boomerang",
			description = "Unlock / +1 boomerang",
			level = 0,
			maxLevel = 5,
			apply = function()
				if not boomerangsUnlocked then
					boomerangsUnlocked = true
				else
					boomerangLevel = boomerangLevel + 1
				end
			end,
		},
		{
			name = "Laser Gun",
			description = "Unlock / +1 damage",
			level = 0,
			maxLevel = 5,
			apply = function()
				if not laserGunUnlocked then
					laserGunUnlocked = true
				else
					laserGunLevel = laserGunLevel + 1
				end
			end,
		},
		{
			name = "Missiles",
			description = "Unlock / +10 missile damage",
			level = 0,
			maxLevel = 5,
			apply = function()
				if not missilesUnlocked then
					missilesUnlocked = true
					missileLevel = 1
				else
					missileLevel = missileLevel + 1
				end
			end,
		},
	}

	healthUpgrade = {
		name = "Vitality",
		description = "+20 max HP",
		apply = function()
			player.maxHp = player.maxHp + 20
			player.hp = math.min(player.maxHp, player.hp + 20)
		end,
	}

	bulletPool = {}
	bulletPoolMax = 500

	totalKills = 0
	chests = {}
	powerBulletsRemaining = 0
	powerBulletsPerChest = 60

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
	player.maxHp = 100
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

	boomerangsUnlocked = false
	boomerangLevel = 0

	missilesUnlocked = false
	missileLevel = 0

	laserGunUnlocked = false
	laserGunLevel = 0
	laserGunState = "idle"
	laserGunTimer = 0
	laserGunTargetEnemy = nil
	laserGunTargetX = 0
	laserGunTargetY = 0
	laserGunDirX = 0
	laserGunDirY = 0
	laserGunStartX = 0
	laserGunStartY = 0

	-- Reset all weapon upgrade progress so a restart starts from base state
	for i, v in ipairs(upgradePool) do
		v.level = 0
	end

	xpNeededA = 0
	xpNeededB = 50
	xpNeeded = xpNeededA + xpNeededB

	camera.x = player.x - (window_width / 2)
	camera.y = player.y - (window_height / 2)

	enemies = {}
	bullets = {}
	bulletCooldown = 0
	boomerangs = {}
	boomerangCooldown = 0
	missiles = {}
	missileCooldown = 0
	explosions = {}

	levelUpActive = false
	levelUpChoices = {}
	selectedChoice = 1
	levelUpInputDelay = 0

	paused = false
	pauseSelectedOption = 1

	playerMoveDirX = 0
	playerMoveDirY = 0

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

	sessionTimer = 0
	gameOver = false
	gameOverSelectedOption = 1
end

function getUpgradeByName(name)
	for i, v in ipairs(upgradePool) do
		if v.name == name then
			return v
		end
	end
	return nil
end

function generateLevelUpChoices()
	levelUpChoices = {}

	-- Collect all non-maxed weapon upgrades
	local available = {}
	for i, v in ipairs(upgradePool) do
		if v.level < v.maxLevel then
			table.insert(available, v)
		end
	end

	-- Shuffle so the offered weapons are picked at random
	for i = #available, 2, -1 do
		local j = math.random(1, i)
		available[i], available[j] = available[j], available[i]
	end

	-- Offer distinct weapon upgrades first. With 3+ non-maxed upgrades,
	-- all 3 choices are weapons; with fewer than 3, Vitality fills the rest.
	local weaponSlots = math.min(3, #available)
	for i = 1, weaponSlots do
		table.insert(levelUpChoices, available[i])
	end
	while #levelUpChoices < 3 do
		table.insert(levelUpChoices, healthUpgrade)
	end
end

function spawnEnemies()
	local maxEnemies = baseMaxEnemies + (player.level - 1) * 20
	while #enemies < maxEnemies do
		local edge
		local margin = 50
		local x, y

		local biased = math.random() < 0.75 and (playerMoveDirX ~= 0 or playerMoveDirY ~= 0)

		if biased then
			-- Pick an edge the player is moving toward, weighted by direction magnitude
			local absDx = math.abs(playerMoveDirX)
			local absDy = math.abs(playerMoveDirY)
			local total = absDx + absDy

			if math.random() < absDx / total then
				-- Horizontal edge
				if playerMoveDirX > 0 then
					edge = 2 -- right
				else
					edge = 1 -- left
				end
			else
				-- Vertical edge
				if playerMoveDirY > 0 then
					edge = 4 -- bottom
				else
					edge = 3 -- top
				end
			end
		else
			edge = math.random(4)
		end

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
		if not enemy.dead then
			local d = distSq(enemy.x, enemy.y, player.x, player.y)
			if d < closestDistSq then
				closestDistSq = d
				closest = enemy
			end
		end
	end

	return closest
end

function killEnemy(enemy)
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
		table.insert(chests, { x = enemy.x, y = enemy.y, size = player.size, timer = 1.0 })
	else
		totalKills = totalKills + 1
		if totalKills >= killsForSpecial then
			totalKills = totalKills - killsForSpecial
			killsForSpecial = math.floor(killsForSpecial * killsForSpecialScale)
			spawnSpecialEnemy()
		end
	end
end

function explodeMissile(x, y)
	table.insert(explosions, {
		x = x,
		y = y,
		age = 0,
		duration = 0.4,
		maxRadius = missileExplosionRadius,
	})

	local damage = 10 * missileLevel
	local nearby = getNearbyEnemies(x, y, missileExplosionRadius + enemySize)
	for _, enemy in ipairs(nearby) do
		if not enemy.dead and enemy.hp > 0 then
			enemy.hp = enemy.hp - damage
			if enemy.hp <= 0 then
				killEnemy(enemy)
			end
		end
	end
end

function love.update(dt)
	if levelUpActive and levelUpInputDelay > 0 then
		levelUpInputDelay = levelUpInputDelay - dt
	end

	if gameOver or levelUpActive or paused then
		return
	end

	sessionTimer = sessionTimer + dt

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

	if dx ~= 0 or dy ~= 0 then
		playerMoveDirX = dx
		playerMoveDirY = dy
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
		player.hp = 0
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

			if powerBulletsRemaining >= 3 then
				local spreadAngle = math.rad(30)
				for _, angle in ipairs({ -spreadAngle, 0, spreadAngle }) do
					local cosA = math.cos(angle)
					local sinA = math.sin(angle)
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
					bullet.dx = dirX * cosA - dirY * sinA
					bullet.dy = dirX * sinA + dirY * cosA
					bullet.isPower = true
					bullet.damageRemaining = bulletDamage * 3
					bullet.hitEnemies = {}
					table.insert(bullets, bullet)
				end
				powerBulletsRemaining = powerBulletsRemaining - 3
			else
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
				bullet.isPower = false
				bullet.damageRemaining = bulletDamage
				bullet.hitEnemies = {}
				table.insert(bullets, bullet)
			end
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
						killEnemy(enemy)
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

	if laserGunUnlocked then
		if laserGunState == "idle" then
			local closest = findClosestEnemy()
			if closest then
				laserGunTargetEnemy = closest
				laserGunState = "charging"
				laserGunTimer = 1.0
			end
		elseif laserGunState == "charging" then
			laserGunTimer = laserGunTimer - dt
			if laserGunTargetEnemy and laserGunTargetEnemy.dead then
				laserGunTargetEnemy = findClosestEnemy()
			end
			if laserGunTargetEnemy and not laserGunTargetEnemy.dead then
				laserGunTargetX = laserGunTargetEnemy.x
				laserGunTargetY = laserGunTargetEnemy.y
			end

			local dx = laserGunTargetX - player.x
			local dy = laserGunTargetY - player.y
			local len = math.sqrt(dx * dx + dy * dy)
			if len == 0 then
				len = 1
				dx = 1
				dy = 0
			end
			laserGunDirX = dx / len
			laserGunDirY = dy / len

			if laserGunTimer <= 0 then
				laserGunState = "firing"
				laserGunTimer = 0.1

				laserGunStartX = player.x
				laserGunStartY = player.y

				local p1x = player.x
				local p1y = player.y
				local damage = laserGunDamageBase + laserGunLevel

				for _, enemy in ipairs(enemies) do
					local vX = enemy.x - p1x
					local vY = enemy.y - p1y
					local t = vX * laserGunDirX + vY * laserGunDirY
					if t > 0 then
						local projX = p1x + t * laserGunDirX
						local projY = p1y + t * laserGunDirY

						local distSqToLine = distSq(enemy.x, enemy.y, projX, projY)
						local hitRadius = enemy.size / 2 + 30
						if distSqToLine <= hitRadius * hitRadius then
							enemy.hp = enemy.hp - damage
							if enemy.hp <= 0 and not enemy.dead then
								killEnemy(enemy)
							end
						end
					end
				end
			end
		elseif laserGunState == "firing" then
			laserGunTimer = laserGunTimer - dt
			if laserGunTimer <= 0 then
				laserGunState = "cooldown"
				laserGunTimer = 1.0
			end
		elseif laserGunState == "cooldown" then
			laserGunTimer = laserGunTimer - dt
			if laserGunTimer <= 0 then
				laserGunState = "idle"
			end
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

	if boomerangsUnlocked and boomerangCooldown <= 0 then
		local boomerangCount = 1 + boomerangLevel
		local angleStep = (2 * math.pi) / boomerangCount
		for i = 0, boomerangCount - 1 do
			table.insert(boomerangs, {
				x = player.x,
				y = player.y,
				originX = player.x,
				originY = player.y,
				angle = i * angleStep,
				radius = 0,
				spinAngle = 0,
				hitEnemies = {},
			})
		end
		boomerangCooldown = 5
	end

	local boomerangHitRadius = boomerangSize + enemySize / 2
	local boomerangHitRadiusSq = boomerangHitRadius * boomerangHitRadius

	for i = #boomerangs, 1, -1 do
		local b = boomerangs[i]
		b.angle = b.angle + boomerangRotationSpeed * dt
		b.spinAngle = b.spinAngle + 10 * dt
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
						killEnemy(enemy)
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

	missileCooldown = missileCooldown - dt

	if missilesUnlocked and missileCooldown <= 0 then
		local count = math.min(4, 1 + missileLevel)
		for i = 1, count do
			local angle = math.random() * 2 * math.pi
			table.insert(missiles, {
				x = player.x,
				y = player.y,
				vx = math.cos(angle) * missileSpreadSpeed,
				vy = math.sin(angle) * missileSpreadSpeed,
				age = 0,
				targetAcquired = false,
			})
		end
		missileCooldown = missileSpawnInterval
	end

	local missileHitRadius = missileSize + enemySize / 2
	local missileHitRadiusSq = missileHitRadius * missileHitRadius

	for i = #missiles, 1, -1 do
		local m = missiles[i]
		m.age = m.age + dt

		if m.age >= missileSpreadTime and not m.targetAcquired then
			local closest = nil
			local closestDistSq = math.huge
			for _, enemy in ipairs(enemies) do
				if not enemy.dead then
					local d = distSq(m.x, m.y, enemy.x, enemy.y)
					if d < closestDistSq then
						closestDistSq = d
						closest = enemy
					end
				end
			end
			m.targetAcquired = true
			m.dirX = 0
			m.dirY = 0
			if closest then
				local dx = closest.x - m.x
				local dy = closest.y - m.y
				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0 then
					m.dirX = dx / len
					m.dirY = dy / len
				end
			end
		end

		if m.dirX and m.dirY then
			m.vx = m.vx + m.dirX * missileAcceleration * dt
			m.vy = m.vy + m.dirY * missileAcceleration * dt
		end

		m.x = m.x + m.vx * dt
		m.y = m.y + m.vy * dt

		local exploded = false
		local nearby = getNearbyEnemies(m.x, m.y, missileHitRadius + enemySize)
		for _, enemy in ipairs(nearby) do
			if not enemy.dead and distSq(m.x, m.y, enemy.x, enemy.y) < missileHitRadiusSq then
				exploded = true
				break
			end
		end

		if exploded then
			explodeMissile(m.x, m.y)
			swapRemove(missiles, i)
		else
			local screenX = m.x - camera.x
			local screenY = m.y - camera.y
			local distFromPlayerSq = (m.x - player.x) ^ 2 + (m.y - player.y) ^ 2
			if
				m.age > missileMaxAge
				or distFromPlayerSq > missileMaxRangeSq
				or screenX < -50
				or screenX > window_width + 50
				or screenY < -50
				or screenY > window_height + 50
			then
				swapRemove(missiles, i)
			end
		end
	end

	for i = #explosions, 1, -1 do
		local ex = explosions[i]
		ex.age = ex.age + dt
		if ex.age >= ex.duration then
			swapRemove(explosions, i)
		end
	end

	for i = #chests, 1, -1 do
		local c = chests[i]
		c.timer = c.timer - dt
		local halfC = c.size / 2
		local halfP = player.size / 2
		if
			c.timer <= 0
			and player.x + halfP > c.x - halfC
			and player.x - halfP < c.x + halfC
			and player.y + halfP > c.y - halfC
			and player.y - halfP < c.y + halfC
		then
			powerBulletsRemaining = powerBulletsRemaining + powerBulletsPerChest * specialEnemySpawnCount
			swapRemove(chests, i)
		end
	end

	xpNeeded = xpNeededA + xpNeededB
	if xpNeeded > 50000 then
		xpNeeded = 50000
	end
	if player.experience >= xpNeeded then
		_xpNeededB = xpNeededB
		xpNeededB = xpNeededA + xpNeededB
		xpNeededA = _xpNeededB
		player.experience = player.experience - xpNeeded
		player.level = player.level + 1
		player.hp = math.min(player.maxHp, player.hp + 5)
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
			local p = {}
			for j = 0, 2 do
				local a = b.spinAngle + j * (2 * math.pi / 3)
				p[#p + 1] = screenX + math.cos(a) * boomerangSize
				p[#p + 1] = screenY + math.sin(a) * boomerangSize
			end
			love.graphics.polygon("fill", p)
		end
	end

	local missileBlink = (math.floor(love.timer.getTime() * 8) % 2) == 0
	love.graphics.setColor(missileBlink and 1 or 0.35, missileBlink and 0.85 or 0.3, missileBlink and 0.3 or 0.15)
	for _, m in ipairs(missiles) do
		local screenX = m.x - camera.x
		local screenY = m.y - camera.y
		if
			screenX > -missileSize
			and screenX < window_width + missileSize
			and screenY > -missileSize
			and screenY < window_height + missileSize
		then
			love.graphics.circle("fill", screenX, screenY, missileSize)
		end
	end

	for _, ex in ipairs(explosions) do
		local progress = ex.age / ex.duration
		local r = ex.maxRadius * (0.3 + 0.7 * progress)
		local alpha = 1 - progress
		local screenX = ex.x - camera.x
		local screenY = ex.y - camera.y
		love.graphics.setColor(1, 0.55, 0, alpha)
		love.graphics.circle("line", screenX, screenY, r)
		love.graphics.setColor(1, 0.85, 0.25, alpha * 0.5)
		love.graphics.circle("fill", screenX, screenY, r * 0.8)
	end

	if laserGunUnlocked then
		if laserGunState == "charging" or laserGunState == "firing" then
			local laserLength = math.sqrt(window_width * window_width + window_height * window_height)

			local startX, startY
			if laserGunState == "firing" then
				startX = laserGunStartX
				startY = laserGunStartY
			else
				startX = player.x
				startY = player.y
			end

			local screenX1 = startX - camera.x
			local screenY1 = startY - camera.y
			local screenX2 = (startX + laserGunDirX * laserLength) - camera.x
			local screenY2 = (startY + laserGunDirY * laserLength) - camera.y

			if laserGunState == "charging" then
				love.graphics.setColor(1, 0, 0, 0.5)
				love.graphics.setLineWidth(1)
			else
				love.graphics.setColor(1, 0, 0, 1)
				love.graphics.setLineWidth(30)
			end

			love.graphics.line(screenX1, screenY1, screenX2, screenY2)
			love.graphics.setLineWidth(1)
		end
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

	love.graphics.setFont(font24)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Time: " .. formatPlayTime(sessionTimer), 10, window_height - 35)

	local statsX = window_width - 10
	love.graphics.setColor(1, 1, 1)
	local pistolEntry = getUpgradeByName("Pistol")
	local boomerangEntry = getUpgradeByName("Boomerang")
	local pistolText = "Pistol: "
		.. pistolEntry.level
		.. "/"
		.. pistolEntry.maxLevel
		.. " (dmg "
		.. bulletDamage
		.. ", "
		.. fireRateLevel
		.. "/s)"
	local detectRangeText = "Detection: " .. detectionRange
	local damageText = "Damage: " .. bulletDamage
	local hpText = "HP: " .. player.hp .. "/" .. player.maxHp
	love.graphics.print(pistolText, statsX - font24:getWidth(pistolText), 10)
	love.graphics.print(detectRangeText, statsX - font24:getWidth(detectRangeText), 30)
	love.graphics.print(damageText, statsX - font24:getWidth(damageText), 50)
	love.graphics.print(hpText, statsX - font24:getWidth(hpText), 70)

	if boomerangsUnlocked then
		local boomerangCount = 1 + boomerangLevel
		local boomerangText = "Boomerangs: "
			.. boomerangCount
			.. " ("
			.. boomerangEntry.level
			.. "/"
			.. boomerangEntry.maxLevel
			.. ", "
			.. string.format("%.1f", boomerangCooldown)
			.. "/5.0s)"
		love.graphics.print(boomerangText, statsX - font24:getWidth(boomerangText), 90)
	end

	if laserGunUnlocked then
		local laserEntry = getUpgradeByName("Laser Gun")
		local laserText = "Laser: "
			.. laserEntry.level
			.. "/"
			.. laserEntry.maxLevel
			.. " (dmg "
			.. (laserGunDamageBase + laserGunLevel)
			.. ")"
		love.graphics.print(laserText, statsX - font24:getWidth(laserText), 110)
	end

	if missilesUnlocked then
		local missileEntry = getUpgradeByName("Missiles")
		local missileText = "Missiles: "
			.. missileEntry.level
			.. "/"
			.. missileEntry.maxLevel
			.. " (dmg "
			.. (10 * missileLevel)
			.. ", "
			.. string.format("%.1f", missileCooldown)
			.. "/3.0s)"
		love.graphics.print(missileText, statsX - font24:getWidth(missileText), 150)
	end

	if gameOver then
		love.graphics.setColor(0, 0, 0, 0.7)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(font48)
		local gameOverText = "Game Over"
		local textWidth = font48:getWidth(gameOverText)
		love.graphics.print(gameOverText, (window_width / 2) - textWidth / 2, 250)

		local menuStartY = 330
		local menuItemHeight = 50
		local menuBoxWidth = 260
		local menuBoxX = (window_width - menuBoxWidth) / 2

		for i, option in ipairs(gameOverOptions) do
			local itemY = menuStartY + (i - 1) * menuItemHeight

			if i == gameOverSelectedOption then
				love.graphics.setColor(0.3, 0.3, 0.6)
			else
				love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
			end
			love.graphics.rectangle("fill", menuBoxX, itemY, menuBoxWidth, menuItemHeight - 6, 6, 6)

			if i == gameOverSelectedOption then
				love.graphics.setColor(0.6, 0.6, 1)
			else
				love.graphics.setColor(0.5, 0.5, 0.5)
			end
			love.graphics.rectangle("line", menuBoxX, itemY, menuBoxWidth, menuItemHeight - 6, 6, 6)

			love.graphics.setFont(font28)
			love.graphics.setColor(1, 1, 1)
			local optionWidth = font28:getWidth(option)
			love.graphics.print(
				option,
				(window_width - optionWidth) / 2,
				itemY + (menuItemHeight - 6 - font28:getHeight()) / 2
			)
		end

		love.graphics.setFont(font20)
		love.graphics.setColor(0.6, 0.6, 0.6)
		local hintText = "Arrows/D-Pad to navigate, Enter/A to select"
		local hintWidth = font20:getWidth(hintText)
		love.graphics.print(
			hintText,
			(window_width / 2) - hintWidth / 2,
			menuStartY + #gameOverOptions * menuItemHeight + 10
		)
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

	if paused then
		love.graphics.setColor(0, 0, 0, 0.6)
		love.graphics.rectangle("fill", 0, 0, window_width, window_height)

		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(font48)
		local pauseText = "PAUSED"
		local textWidth = font48:getWidth(pauseText)
		love.graphics.print(pauseText, (window_width / 2) - textWidth / 2, window_height / 2 - 120)

		local menuStartY = window_height / 2 - 40
		local menuItemHeight = 50
		local menuBoxWidth = 260
		local menuBoxX = (window_width - menuBoxWidth) / 2

		for i, option in ipairs(pauseOptions) do
			local itemY = menuStartY + (i - 1) * menuItemHeight

			if i == pauseSelectedOption then
				love.graphics.setColor(0.3, 0.3, 0.6)
			else
				love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
			end
			love.graphics.rectangle("fill", menuBoxX, itemY, menuBoxWidth, menuItemHeight - 6, 6, 6)

			if i == pauseSelectedOption then
				love.graphics.setColor(0.6, 0.6, 1)
			else
				love.graphics.setColor(0.5, 0.5, 0.5)
			end
			love.graphics.rectangle("line", menuBoxX, itemY, menuBoxWidth, menuItemHeight - 6, 6, 6)

			love.graphics.setFont(font28)
			love.graphics.setColor(1, 1, 1)
			local optionWidth = font28:getWidth(option)
			love.graphics.print(
				option,
				(window_width - optionWidth) / 2,
				itemY + (menuItemHeight - 6 - font28:getHeight()) / 2
			)
		end

		love.graphics.setFont(font20)
		love.graphics.setColor(0.6, 0.6, 0.6)
		local hintText = "Arrows/D-Pad to navigate, Enter/A to select"
		local hintWidth = font20:getWidth(hintText)
		love.graphics.print(
			hintText,
			(window_width / 2) - hintWidth / 2,
			menuStartY + #pauseOptions * menuItemHeight + 10
		)
	end
end

function love.keypressed(key)
	if (key == "escape" or key == "p") and not gameOver then
		if paused then
			paused = false
		else
			paused = true
			pauseSelectedOption = 1
		end
	elseif key == "space" and not gameOver and not levelUpActive then
		dashWanted = true
	elseif key == "r" then
		resetGame()
	elseif paused then
		if key == "up" then
			pauseSelectedOption = pauseSelectedOption - 1
			if pauseSelectedOption < 1 then
				pauseSelectedOption = #pauseOptions
			end
		elseif key == "down" then
			pauseSelectedOption = pauseSelectedOption + 1
			if pauseSelectedOption > #pauseOptions then
				pauseSelectedOption = 1
			end
		elseif key == "return" then
			executePauseOption(pauseSelectedOption)
		end
	elseif gameOver then
		if key == "up" then
			gameOverSelectedOption = gameOverSelectedOption - 1
			if gameOverSelectedOption < 1 then
				gameOverSelectedOption = #gameOverOptions
			end
		elseif key == "down" then
			gameOverSelectedOption = gameOverSelectedOption + 1
			if gameOverSelectedOption > #gameOverOptions then
				gameOverSelectedOption = 1
			end
		elseif key == "return" then
			executeGameOverOption(gameOverSelectedOption)
		end
	elseif levelUpActive and not paused then
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
	if paused then
		local menuStartY = window_height / 2 - 40
		local menuItemHeight = 50
		local menuBoxWidth = 260
		local menuBoxX = (window_width - menuBoxWidth) / 2

		for i = 1, #pauseOptions do
			local itemY = menuStartY + (i - 1) * menuItemHeight
			if x >= menuBoxX and x <= menuBoxX + menuBoxWidth and y >= itemY and y <= itemY + menuItemHeight - 6 then
				executePauseOption(i)
				break
			end
		end
		return
	end

	if gameOver then
		local menuStartY = 330
		local menuItemHeight = 50
		local menuBoxWidth = 260
		local menuBoxX = (window_width - menuBoxWidth) / 2

		for i = 1, #gameOverOptions do
			local itemY = menuStartY + (i - 1) * menuItemHeight
			if x >= menuBoxX and x <= menuBoxX + menuBoxWidth and y >= itemY and y <= itemY + menuItemHeight - 6 then
				executeGameOverOption(i)
				break
			end
		end
		return
	end

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
	if button == "start" and not gameOver then
		if paused then
			paused = false
		else
			paused = true
			pauseSelectedOption = 1
		end
	elseif paused then
		if button == "dpup" then
			pauseSelectedOption = pauseSelectedOption - 1
			if pauseSelectedOption < 1 then
				pauseSelectedOption = #pauseOptions
			end
		elseif button == "dpdown" then
			pauseSelectedOption = pauseSelectedOption + 1
			if pauseSelectedOption > #pauseOptions then
				pauseSelectedOption = 1
			end
		elseif button == "a" then
			executePauseOption(pauseSelectedOption)
		end
	elseif gameOver then
		if button == "dpup" then
			gameOverSelectedOption = gameOverSelectedOption - 1
			if gameOverSelectedOption < 1 then
				gameOverSelectedOption = #gameOverOptions
			end
		elseif button == "dpdown" then
			gameOverSelectedOption = gameOverSelectedOption + 1
			if gameOverSelectedOption > #gameOverOptions then
				gameOverSelectedOption = 1
			end
		elseif button == "a" then
			executeGameOverOption(gameOverSelectedOption)
		end
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

function executePauseOption(index)
	local option = pauseOptions[index]
	if option == "Continue" then
		paused = false
	elseif option == "Restart" then
		paused = false
		resetGame()
	elseif option == "Quit" then
		love.event.quit()
	end
end

function executeGameOverOption(index)
	local option = gameOverOptions[index]
	if option == "Restart" then
		resetGame()
	elseif option == "Quit" then
		love.event.quit()
	end
end

function selectUpgrade(index)
	if levelUpInputDelay > 0 then
		return
	end
	if index >= 1 and index <= #levelUpChoices then
		local choice = levelUpChoices[index]
		choice.apply()
		if choice.level ~= nil then
			choice.level = choice.level + 1
		end
		levelUpActive = false
		levelUpChoices = {}
	end
end
