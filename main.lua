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

function getShieldWaveCooldown()
	local cooldown = shieldWaveCooldownBase - (shieldWaveLevel - 1) * shieldWaveCooldownStep
	return math.max(cooldown, 0)
end

function triggerShieldWave()
	table.insert(shieldWaves, {
		x = player.x,
		y = player.y,
		age = 0,
		radius = 0,
		maxRadius = shieldWaveMaxRadius,
		duration = shieldWaveExpansionDuration,
		pushedEnemies = {},
	})
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

	-- Launch in desktop fullscreen; resolution is derived from the active
	-- monitor so every layout scales to any screen size.
	love.window.setMode(window_width, window_height, {
		fullscreen = true,
		fullscreentype = "desktop",
		resizable = true,
		vsync = 1,
	})
	window_width, window_height = love.graphics.getDimensions()

	font16 = love.graphics.newFont(16)
	font18 = love.graphics.newFont(18)
	font20 = love.graphics.newFont(20)
	font24 = love.graphics.newFont(24)
	font28 = love.graphics.newFont(28)
	font48 = love.graphics.newFont(48)
	font64 = love.graphics.newFont(64)

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

	shieldWaveUnlocked = false
	shieldWaveLevel = 0
	shieldWaveCooldown = 0
	shieldWaveCooldownBase = 5.0
	shieldWaveCooldownStep = 0.5
	shieldWaveMaxRadius = 200
	shieldWaveExpansionDuration = 1.0
	shieldWavePushbackForce = 280
	shieldWavePushbackDuration = 0.35
	shieldWaveColor = { 0.2, 0.6, 1.0 }
	shieldWaveAlpha = 0.6
	shieldWaveLineWidth = 4
	shieldWaves = {}

	missilesUnlocked = false
	missileLevel = 0
	missiles = {}
	missileCooldown = 0
	missileSpawnInterval = 3.0
	missileSpreadTime = 0.75
	missileSpreadSpeed = 45
	missileAcceleration = 500
	missileSize = 6
	missileExplosionRadius = 40
	missileMaxAge = 6
	missileMaxRange = 800
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
		{
			name = "Shield Wave",
			description = "Unlock / wave knocks enemies back",
			level = 0,
			maxLevel = 5,
			apply = function()
				if not shieldWaveUnlocked then
					shieldWaveUnlocked = true
					shieldWaveLevel = 1
					triggerShieldWave()
					shieldWaveCooldown = getShieldWaveCooldown()
				else
					shieldWaveLevel = shieldWaveLevel + 1
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

	resetGame()

	titleScreen = true
	titleOptions = { "Start Game", "Quit" }
	titleSelectedOption = 1
	titleTime = 0
end

function love.resize(w, h)
	window_width = w
	window_height = h
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

	shieldWaveUnlocked = false
	shieldWaveLevel = 0
	shieldWaveCooldown = 0
	shieldWaves = {}

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
	titleTime = titleTime + dt

	if titleScreen then
		return
	end

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
		if enemy.knockbackTimer and enemy.knockbackTimer > 0 then
			-- Shield Wave pushback: briefly override chase with a decaying knockback
			local falloff = enemy.knockbackTimer / shieldWavePushbackDuration
			enemy.x = enemy.x + enemy.knockbackVx * falloff * dt
			enemy.y = enemy.y + enemy.knockbackVy * falloff * dt
			enemy.knockbackTimer = enemy.knockbackTimer - dt
		else
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
	end

	shieldWaveCooldown = shieldWaveCooldown - dt

	if shieldWaveUnlocked and shieldWaveCooldown <= 0 then
		triggerShieldWave()
		shieldWaveCooldown = getShieldWaveCooldown()
	end

	for i = #shieldWaves, 1, -1 do
		local wave = shieldWaves[i]
		wave.age = wave.age + dt
		wave.radius = math.min(wave.maxRadius, wave.maxRadius * (wave.age / wave.duration))

		if wave.age >= wave.duration then
			swapRemove(shieldWaves, i)
		else
			-- The expanding ring reaches enemies as it grows; push normal/elite enemies
			-- backward (away from the wave origin) once per wave. Special enemies are immune.
			local nearby = getNearbyEnemies(wave.x, wave.y, wave.radius + enemySize)
			for _, enemy in ipairs(nearby) do
				if not enemy.isSpecial and not wave.pushedEnemies[enemy] then
					local touchRadius = wave.radius + enemy.size / 2
					if distSq(enemy.x, enemy.y, wave.x, wave.y) <= touchRadius * touchRadius then
						wave.pushedEnemies[enemy] = true
						local dx = enemy.x - wave.x
						local dy = enemy.y - wave.y
						local len = math.sqrt(dx * dx + dy * dy)
						if len > 0 then
							enemy.knockbackVx = (dx / len) * shieldWavePushbackForce
							enemy.knockbackVy = (dy / len) * shieldWavePushbackForce
							enemy.knockbackTimer = shieldWavePushbackDuration
						end
					end
				end
			end
		end
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
			bullet.damageRemaining = bulletDamage
			bullet.hitEnemies = {}
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
		local count = 3 * missileLevel
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
			swapRemove(chests, i)
			generateLevelUpChoices()
			selectedChoice = 1
			levelUpActive = true
			levelUpInputDelay = levelUpInputDelayDuration
			break
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

-- =====================================================================
-- Modern UI system: palette, glass panels, gradient bars, overlays
-- =====================================================================

local UI_ACCENT = { 0.32, 0.75, 1.0 }
local UI_HP = { 1.0, 0.26, 0.34 }
local UI_HP_DARK = { 0.82, 0.12, 0.22 }
local UI_XP = { 0.58, 0.36, 1.0 }
local UI_XP_DARK = { 0.32, 0.52, 1.0 }

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(v)
	return math.max(0, math.min(1, v))
end

local function mixColor(c1, c2, t)
	return {
		lerp(c1[1], c2[1], t),
		lerp(c1[2], c2[2], t),
		lerp(c1[3], c2[3], t),
		lerp(c1[4] or 1, c2[4] or 1, t),
	}
end

local function getUpgradeAccent(name)
	if name == "Boomerang" then
		return { 0.05, 0.9, 0.95 }
	elseif name == "Laser Gun" then
		return { 1.0, 0.32, 0.36 }
	elseif name == "Missiles" then
		return { 1.0, 0.62, 0.22 }
	elseif name == "Shield Wave" then
		return { 0.35, 0.72, 1.0 }
	elseif name == "Vitality" then
		return { 0.35, 0.92, 0.55 }
	end
	return { 0.62, 0.68, 0.78 } -- Pistol / default
end

local function getWeaponIcon(name)
	if name == "Pistol" then
		return "pistol"
	elseif name == "Boomerang" then
		return "boomerang"
	elseif name == "Laser Gun" then
		return "laser"
	elseif name == "Missiles" then
		return "missiles"
	elseif name == "Shield Wave" then
		return "shield"
	end
	return "pistol"
end

-- Rounded rect filled with a vertical gradient (c1 top -> c2 bottom).
local function drawGradientRounded(x, y, w, h, r, c1, c2)
	if w <= 0 or h <= 0 then
		return
	end
	r = math.min(r, h / 2, w / 2)
	local base = mixColor(c1, c2, 0.5)
	love.graphics.setColor(base[1], base[2], base[3], base[4])
	love.graphics.rectangle("fill", x, y, w, h, r, r)
	local coreX = x + r
	local coreW = w - r * 2
	if coreW > 0 then
		for i = 0, h - 1 do
			local t = h <= 1 and 0 or (i / (h - 1))
			local c = mixColor(c1, c2, t)
			love.graphics.setColor(c[1], c[2], c[3], c[4])
			love.graphics.rectangle("fill", coreX, y + i, coreW, 1)
		end
		love.graphics.setColor(c1[1], c1[2], c1[3], c1[4] or 1)
		love.graphics.rectangle("fill", x, y, r, h, r * 0.8, r * 0.8)
		love.graphics.setColor(c2[1], c2[2], c2[3], c2[4] or 1)
		love.graphics.rectangle("fill", x + w - r, y, r, h, r * 0.8, r * 0.8)
	end
end

-- Translucent glass panel with border and a subtle top sheen.
local function drawPanel(x, y, w, h, r, fill, border)
	if w <= 0 or h <= 0 then
		return
	end
	r = math.min(r, h / 2, w / 2)
	local f = fill or { 0.05, 0.07, 0.12, 0.6 }
	love.graphics.setColor(f[1], f[2], f[3], f[4])
	love.graphics.rectangle("fill", x, y, w, h, r, r)
	local b = border or { 1, 1, 1, 0.12 }
	love.graphics.setLineWidth(1.5)
	love.graphics.setColor(b[1], b[2], b[3], b[4])
	love.graphics.rectangle("line", x + 0.75, y + 0.75, w - 1.5, h - 1.5, r, r)
	love.graphics.setLineWidth(1)
end

-- Rounded progress bar: dark track + gradient fill.
local function drawProgressBar(x, y, w, h, ratio, r, c1, c2)
	ratio = clamp01(ratio)
	love.graphics.setColor(0.02, 0.03, 0.06, 0.8)
	love.graphics.rectangle("fill", x, y, w, h, r, r)
	love.graphics.setColor(1, 1, 1, 0.1)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)
	local pad = 1.5
	local fw = (w - pad * 2) * ratio
	if fw > 1 then
		drawGradientRounded(x + pad, y + pad, fw, h - pad * 2, math.max(2, r - pad), c1, c2)
	end
end

-- Level pips for upgrade tier indicators.
local function drawLevelPips(x, y, level, maxLevel, r, gap, color)
	for i = 1, maxLevel do
		local px = x + (i - 1) * (r * 2 + gap) + r
		if i <= level then
			love.graphics.setColor(color[1], color[2], color[3], 0.95)
			love.graphics.circle("fill", px, y + r, r)
		else
			love.graphics.setColor(1, 1, 1, 0.14)
			love.graphics.circle("fill", px, y + r, r)
		end
	end
end

-- Edge-darkening vignette.
local function drawVignette(alpha, edge)
	edge = edge or 90
	local w, h = window_width, window_height
	local strips = 12
	for i = 1, strips do
		local t = i / strips
		local a = alpha * (1 - t) * (1 - t)
		love.graphics.setColor(0, 0, 0, a)
		local thick = edge / strips
		love.graphics.rectangle("fill", 0, (i - 1) * thick, w, thick + 1)
		love.graphics.rectangle("fill", 0, h - i * thick, w, thick + 1)
		love.graphics.rectangle("fill", (i - 1) * thick, 0, thick + 1, h)
		love.graphics.rectangle("fill", w - i * thick, 0, thick + 1, h)
	end
end

local function wrapText(text, font, maxW)
	local lines = {}
	local line = ""
	for w in text:gmatch("%S+") do
		local trial = line == "" and w or (line .. " " .. w)
		if font:getWidth(trial) <= maxW or line == "" then
			line = trial
		else
			table.insert(lines, line)
			line = w
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

local function drawTextCentered(text, font, x, y, color)
	love.graphics.setFont(font)
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
	local w = font:getWidth(text)
	love.graphics.print(text, x - w / 2, y)
	return w
end

local function drawTextRight(text, font, x, y, color)
	love.graphics.setFont(font)
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
	love.graphics.print(text, x - font:getWidth(text), y)
end

-- Modern menu button; accent highlights the selected entry.
local function drawMenuButton(x, y, w, h, label, font, selected, accent)
	local acc = accent or UI_ACCENT
	if selected then
		drawPanel(x - 4, y - 4, w + 8, h + 8, 14, { acc[1], acc[2], acc[3], 0.16 }, { acc[1], acc[2], acc[3], 0.9 })
		love.graphics.setColor(acc[1], acc[2], acc[3], 1)
		love.graphics.rectangle("fill", x - 4, y + 10, 3, h - 20, 1.5, 1.5)
	else
		drawPanel(x, y, w, h, 12, { 0.05, 0.06, 0.11, 0.7 }, { 1, 1, 1, 0.14 })
	end
	local col = selected and { 1, 1, 1, 1 } or { 0.7, 0.74, 0.82, 1 }
	drawTextCentered(label, font, x + w / 2, y + (h - font:getHeight()) / 2 - 2, col)
end

-- Circular level badge.
local function drawLevelBadge(cx, cy, r, level)
	love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.28)
	love.graphics.circle("fill", cx, cy, r + 3)
	love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.9)
	love.graphics.circle("fill", cx, cy, r)
	love.graphics.setColor(0.03, 0.05, 0.1, 0.95)
	love.graphics.circle("fill", cx, cy, r - 3.5)
	love.graphics.setColor(1, 1, 1, 0.1)
	love.graphics.circle("fill", cx, cy - r * 0.3, r * 0.6)
	love.graphics.setFont(font28)
	local txt = tostring(level)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(txt, cx - font28:getWidth(txt) / 2, cy - font28:getHeight() / 2)
end

-- Tiny weapon glyphs used in icon tiles.
local function drawWeaponGlyph(icon, cx, cy, color)
	love.graphics.setColor(color[1], color[2], color[3], 1)
	if icon == "pistol" then
		love.graphics.rectangle("fill", cx - 8, cy - 3, 14, 6, 2, 2)
		love.graphics.rectangle("fill", cx + 5, cy - 1, 7, 2, 1, 1)
	elseif icon == "boomerang" then
		love.graphics.polygon("fill", cx - 8, cy + 7, cx + 8, cy + 7, cx, cy - 8)
	elseif icon == "laser" then
		love.graphics.setLineWidth(3)
		love.graphics.line(cx - 8, cy - 8, cx + 8, cy + 8)
		love.graphics.setLineWidth(1)
	elseif icon == "missiles" then
		love.graphics.circle("fill", cx, cy - 4, 5)
		love.graphics.circle("fill", cx + 6, cy + 4, 3.5)
		love.graphics.circle("fill", cx - 6, cy + 4, 3.5)
	elseif icon == "shield" then
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", cx, cy, 7)
		love.graphics.circle("line", cx, cy, 3.5)
		love.graphics.setLineWidth(1)
	elseif icon == "heart" then
		love.graphics.rectangle("fill", cx - 2, cy - 7, 4, 14, 1, 1)
		love.graphics.rectangle("fill", cx - 7, cy - 2, 14, 4, 1, 1)
	end
end

-- ---------------------------------------------------------------
-- In-game HUD
-- ---------------------------------------------------------------
local function drawHUD()
	local pad = 18

	-- Left panel: player vitals
	local panelW = 340
	local panelH = 110
	local x, y = pad, pad
	drawPanel(x, y, panelW, panelH, 14)

	drawLevelBadge(x + 36, y + 55, 24, player.level)

	local bx = x + 84
	local bw = panelW - 84 - 14

	love.graphics.setFont(font16)
	love.graphics.setColor(0.85, 0.32, 0.4, 1)
	love.graphics.print("HEALTH", bx, y + 10)
	local hpRatio = player.maxHp > 0 and (player.hp / player.maxHp) or 0
	drawProgressBar(bx, y + 28, bw, 13, hpRatio, 7, UI_HP, UI_HP_DARK)
	drawTextRight(player.hp .. " / " .. player.maxHp, font20, bx + bw, y + 25, { 1, 1, 1, 1 })

	love.graphics.setFont(font16)
	love.graphics.setColor(0.72, 0.55, 1, 1)
	love.graphics.print("XP", bx, y + 48)
	local xpRatio = xpNeeded > 0 and (player.experience / xpNeeded) or 0
	drawProgressBar(bx + 24, y + 48, bw - 24, 13, xpRatio, 7, UI_XP, UI_XP_DARK)
	drawTextRight(player.experience .. " / " .. xpNeeded, font20, bx + bw, y + 45, { 1, 1, 1, 1 })

	love.graphics.setFont(font16)
	love.graphics.setColor(0.55, 0.6, 0.7, 1)
	love.graphics.print("TIME " .. formatPlayTime(sessionTimer), x + 14, y + panelH - 22)
	drawTextRight("KILLS " .. totalKills, font16, x + panelW - 14, y + panelH - 22, { 1, 0.75, 0.3, 1 })

	-- Right panel: arsenal (owned weapons + tiers + live stats)
	local owned = {}
	local pistolUp = getUpgradeByName("Pistol")
	table.insert(owned, {
		name = "Pistol",
		level = pistolUp.level,
		maxLevel = pistolUp.maxLevel,
		stat = "DMG " .. bulletDamage .. "   ·   " .. fireRateLevel .. "/S",
	})
	if boomerangsUnlocked then
		local up = getUpgradeByName("Boomerang")
		table.insert(owned, {
			name = "Boomerang",
			level = up.level,
			maxLevel = up.maxLevel,
			stat = "×" .. (1 + boomerangLevel) .. "   ·   CD " .. string.format("%.1f", boomerangCooldown) .. "S",
		})
	end
	if laserGunUnlocked then
		local up = getUpgradeByName("Laser Gun")
		table.insert(owned, {
			name = "Laser Gun",
			level = up.level,
			maxLevel = up.maxLevel,
			stat = "DMG " .. (laserGunDamageBase + laserGunLevel),
		})
	end
	if missilesUnlocked then
		local up = getUpgradeByName("Missiles")
		table.insert(owned, {
			name = "Missiles",
			level = up.level,
			maxLevel = up.maxLevel,
			stat = "DMG " .. (10 * missileLevel) .. "   ·   CD " .. string.format("%.1f", missileCooldown) .. "S",
		})
	end
	if shieldWaveUnlocked then
		local up = getUpgradeByName("Shield Wave")
		table.insert(owned, {
			name = "Shield Wave",
			level = up.level,
			maxLevel = up.maxLevel,
			stat = "CD " .. string.format("%.1f", shieldWaveCooldown) .. "/" .. string.format("%.1f", getShieldWaveCooldown()) .. "S",
		})
	end

	local ax = window_width - pad - panelW
	local arowH = 58
	local apanelH = 44 + #owned * arowH + 8
	drawPanel(ax, y, panelW, apanelH, 14)

	love.graphics.setFont(font16)
	love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 1)
	love.graphics.print("ARSENAL", ax + 14, y + 12)
	drawGradientRounded(ax + 14, y + 32, 90, 3, 1.5, UI_ACCENT, UI_XP)

	for rowIdx, entry in ipairs(owned) do
		local ry = y + 44 + (rowIdx - 1) * arowH
		local accent = getUpgradeAccent(entry.name)
		local icon = getWeaponIcon(entry.name)

		love.graphics.setColor(accent[1], accent[2], accent[3], 0.14)
		love.graphics.rectangle("fill", ax + 14, ry + 4, 36, 36, 9, 9)
		love.graphics.setColor(accent[1], accent[2], accent[3], 0.55)
		love.graphics.setLineWidth(1.5)
		love.graphics.rectangle("line", ax + 14, ry + 4, 36, 36, 9, 9)
		love.graphics.setLineWidth(1)
		drawWeaponGlyph(icon, ax + 14 + 18, ry + 4 + 18, accent)

		love.graphics.setFont(font20)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print(entry.name, ax + 60, ry + 3)
		drawTextRight("LV " .. entry.level .. "/" .. entry.maxLevel, font16, ax + panelW - 14, ry + 7, { 0.6, 0.66, 0.76, 1 })

		love.graphics.setFont(font16)
		love.graphics.setColor(0.62, 0.68, 0.78, 1)
		love.graphics.print(entry.stat, ax + 60, ry + 26)
		local pipR = 3.5
		local pipGap = 4
		local pipW = entry.maxLevel * (pipR * 2) + (entry.maxLevel - 1) * pipGap
		drawLevelPips(ax + panelW - 14 - pipW, ry + 27, entry.level, entry.maxLevel, pipR, pipGap, accent)
	end

	-- FPS readout, bottom-right corner
	local fpsText = "FPS " .. tostring(love.timer.getFPS())
	local fpsW = font16:getWidth(fpsText)
	love.graphics.setColor(0.02, 0.03, 0.06, 0.55)
	love.graphics.rectangle("fill", window_width - fpsW - 22, window_height - 34, fpsW + 12, 22, 11, 11)
	drawTextRight(fpsText, font16, window_width - 10, window_height - 30, { 0.72, 0.78, 0.88, 1 })
end

-- ---------------------------------------------------------------
-- Level-up cards
-- ---------------------------------------------------------------
local LEVELUP_CARD_W = 300
local LEVELUP_CARD_H = 258
local LEVELUP_CARD_GAP = 34

local function getLevelUpLayout()
	local totalW = LEVELUP_CARD_W * 3 + LEVELUP_CARD_GAP * 2
	local startX = (window_width - totalW) / 2
	local startY = window_height / 2 - LEVELUP_CARD_H / 2 - 40
	return startX, startY
end

local function drawLevelUpOverlay()
	love.graphics.setColor(0, 0, 0, 0.82)
	love.graphics.rectangle("fill", 0, 0, window_width, window_height)
	drawVignette(0.5)

	drawTextCentered("LEVEL UP", font48, window_width / 2, 84, { 1, 1, 1, 1 })
	drawGradientRounded(window_width / 2 - 70, 142, 140, 4, 2, UI_ACCENT, UI_XP)
	drawTextCentered("CHOOSE AN UPGRADE", font16, window_width / 2, 156, { 0.55, 0.6, 0.7, 1 })

	local startX, startY = getLevelUpLayout()
	for i, choice in ipairs(levelUpChoices) do
		local cardX = startX + (i - 1) * (LEVELUP_CARD_W + LEVELUP_CARD_GAP)
		local cardY = startY
		local selected = i == selectedChoice
		local accent = getUpgradeAccent(choice.name)
		local isSupport = choice == healthUpgrade

		if selected then
			cardY = cardY - 8
			love.graphics.setColor(accent[1], accent[2], accent[3], 0.16)
			love.graphics.rectangle("fill", cardX - 8, cardY - 8, LEVELUP_CARD_W + 16, LEVELUP_CARD_H + 16, 20, 20)
		end

		drawPanel(
			cardX,
			cardY,
			LEVELUP_CARD_W,
			LEVELUP_CARD_H,
			16,
			selected and { accent[1], accent[2], accent[3], 0.1 } or { 0.05, 0.07, 0.12, 0.72 },
			selected and { accent[1], accent[2], accent[3], 0.95 } or { 1, 1, 1, 0.14 }
		)

		if selected then
			love.graphics.setLineWidth(2.5)
			love.graphics.setColor(accent[1], accent[2], accent[3], 1)
			love.graphics.rectangle("line", cardX + 2, cardY + 2, LEVELUP_CARD_W - 4, LEVELUP_CARD_H - 4, 14, 14)
			love.graphics.setLineWidth(1)
		end

		-- category badge
		local catText = isSupport and "SUPPORT" or "WEAPON"
		love.graphics.setFont(font16)
		local catW = font16:getWidth(catText) + 18
		love.graphics.setColor(isSupport and { 0.35, 0.92, 0.55, 0.2 } or { accent[1], accent[2], accent[3], 0.22 })
		love.graphics.rectangle("fill", cardX + 14, cardY + 14, catW, 22, 11, 11)
		love.graphics.setColor(isSupport and { 0.35, 0.92, 0.55, 1 } or { accent[1], accent[2], accent[3], 1 })
		love.graphics.print(catText, cardX + 14 + 9, cardY + 14 + (22 - font16:getHeight()) / 2)

		-- progression counter
		local progText
		if choice.level ~= nil and choice.level > 0 then
			progText = "LV " .. choice.level .. " -> " .. (choice.level + 1)
		elseif choice.level ~= nil then
			progText = "NEW"
		else
			progText = "LV 0 -> 1"
		end
		love.graphics.setFont(font16)
		local progW = font16:getWidth(progText)
		love.graphics.setColor(0.7, 0.75, 0.85, 1)
		love.graphics.print(progText, cardX + LEVELUP_CARD_W - 14 - progW, cardY + 14 + (22 - font16:getHeight()) / 2)

		-- icon tile
		local iconX = cardX + LEVELUP_CARD_W / 2
		local iconY = cardY + 78
		love.graphics.setColor(accent[1], accent[2], accent[3], 0.12)
		love.graphics.rectangle("fill", iconX - 30, iconY - 30, 60, 60, 14, 14)
		love.graphics.setColor(accent[1], accent[2], accent[3], 0.6)
		love.graphics.setLineWidth(1.5)
		love.graphics.rectangle("line", iconX - 30, iconY - 30, 60, 60, 14, 14)
		love.graphics.setLineWidth(1)
		drawWeaponGlyph(isSupport and "heart" or getWeaponIcon(choice.name), iconX, iconY, accent)

		-- name + description
		drawTextCentered(choice.name, font28, iconX, cardY + 118, { 1, 1, 1, 1 })
		local descLines = wrapText(choice.description, font18, LEVELUP_CARD_W - 44)
		local descY = cardY + 158
		for li, dl in ipairs(descLines) do
			drawTextCentered(dl, font18, iconX, descY + (li - 1) * (font18:getHeight() + 2), { 0.68, 0.72, 0.82, 1 })
		end

		-- tier pips + next-level highlight
		local pipsLevel = choice.level or 0
		local pipCount = 5
		local pipR = 5
		local pipGap = 8
		local pipW = pipCount * (pipR * 2) + (pipCount - 1) * pipGap
		local pipsY = cardY + LEVELUP_CARD_H - 34
		for j = 1, pipCount do
			local px = iconX - pipW / 2 + (j - 1) * (pipR * 2 + pipGap) + pipR
			if j <= pipsLevel then
				love.graphics.setColor(accent[1], accent[2], accent[3], 1)
				love.graphics.circle("fill", px, pipsY, pipR)
			else
				love.graphics.setColor(1, 1, 1, 0.15)
				love.graphics.circle("fill", px, pipsY, pipR)
			end
		end
		if choice.level ~= nil and choice.level < pipCount then
			local px = iconX - pipW / 2 + choice.level * (pipR * 2 + pipGap) + pipR
			love.graphics.setColor(1, 1, 1, 0.9)
			love.graphics.circle("line", px, pipsY, pipR + 2)
		end

		-- key hint
		love.graphics.setFont(font18)
		love.graphics.setColor(0.25, 0.28, 0.36, 0.9)
		love.graphics.circle("fill", cardX + 22, cardY + LEVELUP_CARD_H - 18, 11)
		love.graphics.setColor(1, 1, 1, selected and 0.95 or 0.6)
		local numTxt = tostring(i)
		love.graphics.print(numTxt, cardX + 22 - font18:getWidth(numTxt) / 2, cardY + LEVELUP_CARD_H - 18 - font18:getHeight() / 2)
	end

	drawTextCentered("PRESS 1 / 2 / 3  ·  ARROWS + ENTER  ·  GAMEPAD A", font16, window_width / 2, startY + LEVELUP_CARD_H + 26, { 0.5, 0.55, 0.65, 1 })
end

-- ---------------------------------------------------------------
-- Pause overlay
-- ---------------------------------------------------------------
local PAUSE_PANEL_W = 470
local PAUSE_PANEL_H = 420

local function getPauseMenuLayout()
	local panelX = (window_width - PAUSE_PANEL_W) / 2
	local panelY = (window_height - PAUSE_PANEL_H) / 2
	local itemW = 300
	local itemH = 54
	local gap = 12
	local startY = panelY + 150
	return panelX, panelY, itemW, itemH, gap, startY
end

local function drawPauseOverlay()
	love.graphics.setColor(0, 0, 0, 0.68)
	love.graphics.rectangle("fill", 0, 0, window_width, window_height)
	drawVignette(0.55)

	local panelX, panelY, itemW, itemH, gap, startY = getPauseMenuLayout()
	drawPanel(panelX, panelY, PAUSE_PANEL_W, PAUSE_PANEL_H, 18, { 0.04, 0.05, 0.1, 0.92 }, { 1, 1, 1, 0.16 })

	drawTextCentered("PAUSED", font48, window_width / 2, panelY + 36, { 1, 1, 1, 1 })
	drawGradientRounded(window_width / 2 - 60, panelY + 94, 120, 4, 2, UI_ACCENT, UI_XP)

	local summary = "TIME " .. formatPlayTime(sessionTimer) .. "   ·   LEVEL " .. player.level .. "   ·   KILLS " .. totalKills
	drawTextCentered(summary, font16, window_width / 2, panelY + 112, { 0.55, 0.6, 0.7, 1 })

	for i, option in ipairs(pauseOptions) do
		local itemX = window_width / 2 - itemW / 2
		local itemY = startY + (i - 1) * (itemH + gap)
		local acc = UI_ACCENT
		if option == "Restart" then
			acc = { 1.0, 0.65, 0.2 }
		elseif option == "Quit" then
			acc = { 1.0, 0.35, 0.4 }
		end
		drawMenuButton(itemX, itemY, itemW, itemH, option, font24, i == pauseSelectedOption, acc)
	end

	drawTextCentered("ARROWS / D-PAD TO NAVIGATE  ·  ENTER / A TO SELECT", font16, window_width / 2, panelY + PAUSE_PANEL_H - 34, { 0.5, 0.55, 0.65, 1 })
end

-- ---------------------------------------------------------------
-- Game over overlay
-- ---------------------------------------------------------------
local GAMEOVER_PANEL_W = 520
local GAMEOVER_PANEL_H = 460

local function getGameOverMenuLayout()
	local panelX = (window_width - GAMEOVER_PANEL_W) / 2
	local panelY = (window_height - GAMEOVER_PANEL_H) / 2
	local itemW = 300
	local itemH = 54
	local gap = 12
	local startY = panelY + 300
	return panelX, panelY, itemW, itemH, gap, startY
end

local function drawGameOverOverlay()
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, window_width, window_height)
	drawVignette(0.6)

	local panelX, panelY, itemW, itemH, gap, startY = getGameOverMenuLayout()
	drawPanel(panelX, panelY, GAMEOVER_PANEL_W, GAMEOVER_PANEL_H, 18, { 0.05, 0.04, 0.08, 0.94 }, { 1, 0.35, 0.4, 0.35 })

	drawTextCentered("GAME OVER", font48, window_width / 2, panelY + 36, { 1, 0.35, 0.4, 1 })
	drawGradientRounded(window_width / 2 - 60, panelY + 94, 120, 4, 2, { 1.0, 0.3, 0.36 }, { 0.6, 0.1, 0.2 })

	-- run stats
	local stats = {
		{ "TIME", formatPlayTime(sessionTimer) },
		{ "LEVEL", tostring(player.level) },
		{ "KILLS", tostring(totalKills) },
		{ "XP", tostring(player.experience) },
	}
	local statW = 90
	local statGap = 26
	local totalStatW = #stats * statW + (#stats - 1) * statGap
	local statX0 = window_width / 2 - totalStatW / 2
	local statY = panelY + 118
	for i, s in ipairs(stats) do
		local sx = statX0 + (i - 1) * (statW + statGap)
		drawTextCentered(s[1], font16, sx + statW / 2, statY, { 0.5, 0.55, 0.65, 1 })
		drawTextCentered(s[2], font28, sx + statW / 2, statY + 26, { 1, 1, 1, 1 })
	end

	for i, option in ipairs(gameOverOptions) do
		local itemX = window_width / 2 - itemW / 2
		local itemY = startY + (i - 1) * (itemH + gap)
		local acc = option == "Quit" and { 1.0, 0.35, 0.4 } or { 0.35, 0.92, 0.55 }
		drawMenuButton(itemX, itemY, itemW, itemH, option, font24, i == gameOverSelectedOption, acc)
	end

	drawTextCentered("ARROWS / D-PAD TO NAVIGATE  ·  ENTER / A TO SELECT", font16, window_width / 2, panelY + GAMEOVER_PANEL_H - 34, { 0.5, 0.55, 0.65, 1 })
end

-- ---------------------------------------------------------------
-- Title screen
-- ---------------------------------------------------------------
local function getTitleMenuLayout()
	local itemW = 300
	local itemH = 54
	local gap = 14
	local startY = window_height / 2 + 70
	return itemW, itemH, gap, startY
end

local function drawTitleScreen()
	-- world behind is frozen; dim it
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.rectangle("fill", 0, 0, window_width, window_height)

	local titleText = "SWARM PROTOCOL"
	local f = font64
	love.graphics.setFont(f)
	local tw = f:getWidth(titleText)
	local ty = window_height * 0.24

	-- soft glow behind the title
	for i = 1, 4 do
		local a = 0.04 + i * 0.02
		love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], a)
		love.graphics.print(titleText, window_width / 2 - tw / 2 + (i - 2) * 1.5, ty + (i - 2) * 1.5)
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(titleText, window_width / 2 - tw / 2, ty)
	drawGradientRounded(window_width / 2 - 110, ty + 74, 220, 4, 2, UI_ACCENT, UI_XP)

	drawTextCentered("TOP-DOWN AUTO-SHOOTER  ·  SURVIVE THE SWARM", font18, window_width / 2, ty + 96, { 0.6, 0.66, 0.76, 1 })

	local itemW, itemH, gap, startY = getTitleMenuLayout()
	for i, option in ipairs(titleOptions) do
		local itemX = window_width / 2 - itemW / 2
		local itemY = startY + (i - 1) * (itemH + gap)
		local acc = option == "Quit" and { 1.0, 0.35, 0.4 } or UI_ACCENT
		drawMenuButton(itemX, itemY, itemW, itemH, option, font24, i == titleSelectedOption, acc)
	end

	local pulse = 0.45 + 0.25 * math.sin(titleTime * 2.5)
	drawTextCentered("ARROWS / W-S / D-PAD TO NAVIGATE  ·  ENTER / A TO START  ·  ESC TO QUIT", font16, window_width / 2, window_height * 0.78, { 0.7, 0.78, 0.9, pulse })
	drawTextCentered("v1.0  ·  LÖVE 2D", font16, window_width / 2, window_height - 40, { 0.4, 0.44, 0.54, 1 })
end

local function drawWorldBackdrop()
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
end

function love.draw()
	if titleScreen then
		drawWorldBackdrop()
		drawTitleScreen()
		return
	end

	drawWorldBackdrop()

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
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.circle("fill", screenX, screenY, bulletSize)
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

	for _, wave in ipairs(shieldWaves) do
		local progress = wave.age / wave.duration
		local alpha = shieldWaveAlpha * (1 - progress)
		local screenX = wave.x - camera.x
		local screenY = wave.y - camera.y
		love.graphics.setColor(shieldWaveColor[1], shieldWaveColor[2], shieldWaveColor[3], shieldWaveAlpha * 0.2)
		love.graphics.circle("fill", screenX, screenY, wave.radius)
		love.graphics.setColor(shieldWaveColor[1], shieldWaveColor[2], shieldWaveColor[3], alpha)
		love.graphics.setLineWidth(shieldWaveLineWidth)
		love.graphics.circle("line", screenX, screenY, wave.radius)
		love.graphics.setLineWidth(1)
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

	if not titleScreen then
		drawHUD()
	end

	if gameOver then
		drawGameOverOverlay()
	end

	if levelUpActive then
		drawLevelUpOverlay()
	end

	if paused then
		drawPauseOverlay()
	end

	if titleScreen then
		drawTitleScreen()
	end
end

function love.keypressed(key)
	if titleScreen then
		if key == "up" or key == "w" then
			titleSelectedOption = titleSelectedOption - 1
			if titleSelectedOption < 1 then
				titleSelectedOption = #titleOptions
			end
		elseif key == "down" or key == "s" then
			titleSelectedOption = titleSelectedOption + 1
			if titleSelectedOption > #titleOptions then
				titleSelectedOption = 1
			end
		elseif key == "return" or key == "kpenter" then
			executeTitleOption(titleSelectedOption)
		elseif key == "escape" then
			love.event.quit()
		end
		return
	end

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
	if titleScreen then
		local itemW, itemH, gap, startY = getTitleMenuLayout()
		for i = 1, #titleOptions do
			local itemX = window_width / 2 - itemW / 2
			local itemY = startY + (i - 1) * (itemH + gap)
			if x >= itemX and x <= itemX + itemW and y >= itemY and y <= itemY + itemH then
				executeTitleOption(i)
				return
			end
		end
		return
	end

	if paused then
		local _, _, itemW, itemH, gap, startY = getPauseMenuLayout()
		for i = 1, #pauseOptions do
			local itemX = window_width / 2 - itemW / 2
			local itemY = startY + (i - 1) * (itemH + gap)
			if x >= itemX and x <= itemX + itemW and y >= itemY and y <= itemY + itemH then
				executePauseOption(i)
				return
			end
		end
		return
	end

	if gameOver then
		local _, _, itemW, itemH, gap, startY = getGameOverMenuLayout()
		for i = 1, #gameOverOptions do
			local itemX = window_width / 2 - itemW / 2
			local itemY = startY + (i - 1) * (itemH + gap)
			if x >= itemX and x <= itemX + itemW and y >= itemY and y <= itemY + itemH then
				executeGameOverOption(i)
				return
			end
		end
		return
	end

	if levelUpActive then
		local startX, startY = getLevelUpLayout()
		for i = 1, #levelUpChoices do
			local cardX = startX + (i - 1) * (LEVELUP_CARD_W + LEVELUP_CARD_GAP)
			if
				x >= cardX
				and x <= cardX + LEVELUP_CARD_W
				and y >= startY
				and y <= startY + LEVELUP_CARD_H
			then
				selectUpgrade(i)
				return
			end
		end
	end
end

function love.gamepadpressed(j, button)
	if titleScreen then
		if button == "dpup" then
			titleSelectedOption = titleSelectedOption - 1
			if titleSelectedOption < 1 then
				titleSelectedOption = #titleOptions
			end
		elseif button == "dpdown" then
			titleSelectedOption = titleSelectedOption + 1
			if titleSelectedOption > #titleOptions then
				titleSelectedOption = 1
			end
		elseif button == "a" then
			executeTitleOption(titleSelectedOption)
		end
		return
	end

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

function executeTitleOption(index)
	local option = titleOptions[index]
	if option == "Start Game" then
		resetGame()
		titleScreen = false
	elseif option == "Quit" then
		love.event.quit()
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
