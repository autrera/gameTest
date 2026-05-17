local window_width  = 1280
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
        experience = 0
    }

    camera = {
        x = 0,
        y = 0
    }

    enemies = {}
    enemySize = 32
    enemySpeed = 48
    maxEnemies = 10

    bullets = {}
    bulletSpeed = 600
    bulletSize = 4
    bulletFireRate = 1 / 3
    bulletCooldown = 0
    detectionRange = 300

    gameOver = false

    joystick = nil
    deadzone = 0.2

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

    camera.x = player.x - (window_width / 2)
    camera.y = player.y - (window_height / 2)

    enemies = {}
    bullets = {}
    bulletCooldown = 0

    spawnEnemies()

    gameOver = false
end

function spawnEnemies()
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

        table.insert(enemies, { x = x, y = y, size = enemySize, hp = 5 })
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
    if gameOver then
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

        if math.abs(stickX) < deadzone then stickX = 0 end
        if math.abs(stickY) < deadzone then stickY = 0 end

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

        if playerRight > enemyLeft and playerLeft < enemyRight and
            playerBottom > enemyTop and playerTop < enemyBottom then
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

    if player.experience >= 100 then
        player.experience = 0
        bulletSpeed = bulletSpeed + 100
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

    love.graphics.print("Experience: " .. tostring(player.experience), 10, 30)
    love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 50)
    love.graphics.print("Bullet Speed: " .. tostring(bulletSpeed), 10, 70)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", (window_width / 2) - player.size / 2, (window_height / 2) - player.size / 2,
        player.size, player
        .size)

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
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        resetGame()
    elseif gameOver and key == "return" then
        resetGame()
    end
end

function love.gamepadpressed(j, button)
    if button == "a" and gameOver then
        resetGame()
    end
end
