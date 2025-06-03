sound = require("game.sound")
music = require("game.music")

function love.load()
    player = {
        x = 0,
        y = 0,
        width = 32,
        height = 32,
        speed = 250,
        jumpForce = -350,
        velocityX = 0,
        velocityY = 0,
        is_jumping = false,
        is_stunned = false,
        is_blinking = false,
        blink_count = 0,
        blink_timer = 0,
        startX = 0,
        startY = 0,
        is_dead = false,
        is_exploding = false,
        explode_timer = 0
    }
    gravity = 800
    platforms = {}
    enemies = {}
    particles = {}
    coins = {}
    tileSize = 32
    mapWidth = config.map.width
    mapHeight = config.map.height
    camera = { x = 0 }
    isResetting = false
    resetCameraTargetX = 0
    cameraSpeed = 2000
    screen_width = 1200
    loadMap("assets/levels/map.txt")
end

function loadMap(filename)
    local file = love.filesystem.read(filename)
    local y = 0
    local enemy_positions = {}
    for line in file:gmatch("[^\r\n]+") do
        for x = 1, #line do
            local char = line:sub(x, x)
            if char == "#" then
                table.insert(platforms, {
                    x = (x - 1) * tileSize,
                    y = y * tileSize,
                    width = tileSize,
                    height = tileSize
                })
            elseif char == "@" then
                player.x = (x - 1) * tileSize
                player.y = y * tileSize
                player.startX = player.x
                player.startY = player.y
            elseif char == "a" then
                table.insert(enemy_positions, { x = (x - 1) * tileSize, y = y * tileSize })
            elseif char == "$" then
                table.insert(coins, {
                    x = (x - 1) * tileSize,
                    y = y * tileSize,
                    width = 16,
                    height = 16,
                    is_collected = false
                })
            end
        end
        y = y + 1
    end
    for i, pos in ipairs(enemy_positions) do
        table.insert(enemies, {
            x = pos.x,
            y = pos.y,
            width = 32,
            height = 32,
            speed = 100,
            direction = 1
        })
    end
end

function resetPlayerState()
    player.velocityX = 0
    player.velocityY = 0
    player.is_jumping = false
    player.is_stunned = false
    player.is_blinking = false
    player.blink_count = 0
    player.blink_timer = 0
    player.is_dead = false
    player.is_exploding = false
    player.explode_timer = 0
end

function resetLevel()
    resetPlayerState()
    isResetting = true
    resetCameraTargetX = math.max(0, math.min(player.startX + player.width / 2 - screen_width / 2, config.map.width * tileSize - screen_width))
end

function restrictPlayerBounds()
    if player.x < 0 then
        player.x = 0
        player.velocityX = 0
    elseif player.x + player.width > config.map.width * tileSize then
        player.x = config.map.width * tileSize - player.width
        player.velocityX = 0
    end
end

function createParticles(x, y)
    for i = 1, 20 do
        table.insert(particles, {
            x = x + math.random(-10, 10),
            y = y + math.random(-10, 10),
            size = math.random(4, 8),
            velocityX = math.random(-100, 100),
            velocityY = math.random(-200, -50),
            lifetime = math.random(0.5, 1.0)
        })
    end
end

function love.update(dt)
    if isResetting then
        local distance = resetCameraTargetX - camera.x
        if math.abs(distance) < 1 then
            camera.x = resetCameraTargetX
            player.x = player.startX
            player.y = player.startY
            isResetting = false
            resetPlayerState()
        else
            camera.x = camera.x + distance * math.min(cameraSpeed * dt / math.abs(distance), 1)
        end
    else
        local prevX, prevY = player.x, player.y
        if not player.is_jumping and not player.is_stunned then
            if love.keyboard.isDown("left") then
                player.velocityX = -player.speed
            elseif love.keyboard.isDown("right") then
                player.velocityX = player.speed
            else
                player.velocityX = 0
            end
        end
        if love.keyboard.isDown("up") and not player.is_jumping and not player.is_stunned then
            player.velocityY = player.jumpForce
            player.is_jumping = true
        end
        player.velocityY = player.velocityY + gravity * dt
        player.y = player.y + player.velocityY * dt
        player.x = player.x + player.velocityX * dt
        if not player.is_dead then
            for _, platform in ipairs(platforms) do
                if checkCollision(player, platform) then
                    if player.velocityY > 0 and prevY + player.height <= platform.y then
                        player.y = platform.y - player.height
                        player.velocityY = 0
                        player.velocityX = 0
                        player.is_jumping = false
                    elseif player.velocityY < 0 and prevY >= platform.y + platform.height then
                        player.y = platform.y + platform.height
                        player.velocityY = 0
                    elseif prevX + player.width <= platform.x and player.velocityX > 0 then
                        player.x = platform.x - player.width
                        player.velocityX = 0
                    elseif prevX >= platform.x + platform.width and player.velocityX < 0 then
                        player.x = platform.x + platform.width
                        player.velocityX = 0
                    end
                end
            end
            for i = #coins, 1, -1 do
                local coin = coins[i]
                if not coin.is_collected and checkCollision(player, coin) then
                    coin.is_collected = true
                end
            end
        end
        local enemies_to_remove = {}
        for i, enemy in ipairs(enemies) do
            local old_x = enemy.x
            local old_direction = enemy.direction
            local next_x = enemy.x + enemy.speed * enemy.direction * dt
            local has_platform = false
            local hits_wall = false
            for _, platform in ipairs(platforms) do
                if checkCollision({
                    x = enemy.direction == 1 and next_x + enemy.width or next_x,
                    y = enemy.y + enemy.height,
                    width = 1,
                    height = 1
                }, platform) then
                    has_platform = true
                end
                if checkCollision({
                    x = enemy.direction == 1 and next_x + enemy.width or next_x,
                    y = enemy.y,
                    width = 1,
                    height = enemy.height
                }, platform) then
                    hits_wall = true
                end
            end
            if not has_platform or hits_wall then
                enemy.direction = -enemy.direction
                next_x = enemy.x
            end
            enemy.x = next_x
            if not player.is_stunned and not player.is_dead and checkCollision(player, enemy) then
                if player.velocityY > 0 and prevY + player.height <= enemy.y + 10 then
                    table.insert(enemies_to_remove, i)
                    createParticles(enemy.x, enemy.y)
                    player.velocityY = player.jumpForce
                    player.is_jumping = true
                else
                    player.is_dead = true
                    player.is_stunned = true
                    player.is_blinking = true
                    player.blink_count = 0
                    player.blink_timer = 0
                    player.velocityY = player.jumpForce
                    player.velocityX = 0
                    player.is_jumping = true
                end
            end
        end
        for i = #enemies_to_remove, 1, -1 do
            table.remove(enemies, enemies_to_remove[i])
        end
        for i = #particles, 1, -1 do
            local particle = particles[i]
            particle.x = particle.x + particle.velocityX * dt
            particle.y = particle.y + particle.velocityY * dt
            particle.velocityY = particle.velocityY + gravity * dt
            particle.lifetime = particle.lifetime - dt
            if particle.lifetime <= 0 then
                table.remove(particles, i)
            end
        end
        if player.is_blinking then
            player.blink_timer = player.blink_timer + dt
            if player.blink_timer >= 0.1 then
                player.blink_timer = player.blink_timer - 0.1
                player.blink_count = player.blink_count + 1
                if player.blink_count >= 6 then
                    player.is_blinking = false
                    player.is_stunned = false
                end
            end
        end
        if player.is_exploding then
            player.explode_timer = player.explode_timer + dt
            if player.explode_timer >= 0.5 then
                resetLevel()
            end
        elseif player.y > 600 then
            player.is_exploding = true
            player.explode_timer = 0
            createParticles(player.x, player.y)
        end
        restrictPlayerBounds()
        local target_camera_x = player.x + player.width / 2 - screen_width / 2
        target_camera_x = math.max(0, math.min(target_camera_x, config.map.width * tileSize - screen_width))
        local distance = target_camera_x - camera.x
        camera.x = camera.x + distance * math.min(cameraSpeed * dt / math.abs(distance), 1)
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, 0)
    love.graphics.setColor(0.6, 0.4, 0.2)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)
    end
    if not isResetting and not player.is_exploding then
        if player.is_blinking and math.floor(player.blink_count) % 2 == 1 then
            love.graphics.setColor(0.7, 1, 0.7)
        else
            love.graphics.setColor(0, 1, 0)
        end
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    end
    love.graphics.setColor(1, 0, 0)
    for _, enemy in ipairs(enemies) do
        love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, player.height)
    end
    love.graphics.setColor(0.8, 0, 0)
    for _, particle in ipairs(particles) do
        love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
    end
    love.graphics.setColor(1, 1, 0)
    for _, coin in ipairs(coins) do
        if not coin.is_collected then
            love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
        end
    end
    love.graphics.pop()
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end