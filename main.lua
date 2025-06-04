utils = require("utils")
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
        explode_timer = 0,
        can_shoot = false,
        last_direction = 1,
        is_powerup_blinking = false,
        powerup_blink_timer = 0
    }
    gravity = 800
    platforms = {}
    enemies = {}
    particles = {}
    coins = {}
    bullets = {}
    end_points = {}
    tileSize = 32
    mapWidth = config.map.width
    mapHeight = config.map.height
    camera = { x = player.startX + player.width / 2 - window.width / 2 - window.width }
    isResetting = false
    resetCameraTargetX = 0
    cameraSpeed = 2000
    is_initial_scrolling = true
    initial_scroll_timer = 0
    is_end_scrolling = false
    end_scroll_timer = 0
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
                camera.x = player.startX + player.width / 2 - window.width / 2 - window.width
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
            elseif char == "+" then
                table.insert(coins, {
                    x = (x - 1) * tileSize,
                    y = y * tileSize,
                    width = 16,
                    height = 16,
                    is_collected = false,
                    is_powerup = true
                })
            elseif char == "*" then
                table.insert(end_points, {
                    x = (x - 1) * tileSize,
                    y = y * tileSize,
                    width = tileSize,
                    height = tileSize
                })
                print("End point added at x=" .. (x - 1) * tileSize .. ", y=" .. y * tileSize) -- Дебаг-вивід
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
    player.can_shoot = false
    player.is_powerup_blinking = false
    player.powerup_blink_timer = 0
end

function resetLevel()
    resetPlayerState()
    isResetting = true
    end_points = {}
    resetCameraTargetX = math.max(0, math.min(player.startX + player.width / 2 - window.width / 2, config.map.width * tileSize - window.width))
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
    if is_initial_scrolling then
        initial_scroll_timer = initial_scroll_timer + dt
        local target_camera_x = math.max(0, math.min(player.startX + player.width / 2 - window.width / 2, config.map.width * tileSize - window.width))
        local start_camera_x = player.startX + player.width / 2 - window.width / 2 - window.width
        local t = math.min(initial_scroll_timer / 0.5, 1.0)
        camera.x = start_camera_x + (target_camera_x - start_camera_x) * t
        if initial_scroll_timer >= 0.5 then
            is_initial_scrolling = false
            camera.x = target_camera_x
        end
    elseif is_end_scrolling then
        end_scroll_timer = end_scroll_timer + dt
        local start_camera_x = camera.x
        local target_camera_x = start_camera_x + window.width
        local t = math.min(end_scroll_timer / 0.5, 1.0)
        camera.x = start_camera_x + ((target_camera_x - start_camera_x) * t)
        if end_scroll_timer >= 0.5 then
            is_end_scrolling = false
			camera.x = target_camera_x
            --resetLevel()
        end
    elseif isResetting then
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
                player.last_direction = -1
            elseif love.keyboard.isDown("right") then
                player.velocityX = player.speed
                player.last_direction = 1
            else
                player.velocityX = 0
            end
        end
        if love.keyboard.isDown("up") and not player.is_jumping and not player.is_stunned then
            player.velocityY = player.jumpForce
            player.is_jumping = true
        end
        player.velocityY = player.velocityY + gravity * dt
        player.x = player.x + player.velocityX * dt
        player.y = player.y + player.velocityY * dt
        if not player.is_dead then
            for _, platform in ipairs(platforms) do
                if utils.checkCollision(player, platform) then
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
                if not coin.is_collected and utils.checkCollision(player, coin) then
                    coin.is_collected = true
                    if coin.is_powerup then
                        player.can_shoot = true
                        player.is_powerup_blinking = true
                        player.powerup_blink_timer = 0
                    end
                end
            end
            for _, end_point in ipairs(end_points) do
                if utils.checkCollision(player, end_point) then
                    is_end_scrolling = true
                    end_scroll_timer = 0
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
                if utils.checkCollision({
                    x = enemy.direction == 1 and next_x + enemy.width or next_x,
                    y = enemy.y + enemy.height,
                    width = 1,
                    height = 1
                }, platform) then
                    has_platform = true
                end
                if utils.checkCollision({
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
            if not player.is_stunned and not player.is_dead and utils.checkCollision(player, enemy) then
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
        for i = #bullets, 1, -1 do
            local bullet = bullets[i]
            bullet.x = bullet.x + bullet.velocityX * dt
            bullet.lifetime = bullet.lifetime - dt
            if bullet.lifetime <= 0 then
                table.remove(bullets, i)
            else
                for j = #enemies, 1, -1 do
                    if utils.checkCollision(bullet, enemies[j]) then
                        createParticles(enemies[j].x, enemies[j].y)
                        table.remove(enemies, j)
                        table.remove(bullets, i)
                        break
                    end
                end
            end
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
        if player.is_powerup_blinking then
            player.powerup_blink_timer = player.powerup_blink_timer + dt
            if player.powerup_blink_timer >= 1.0 then
                player.is_powerup_blinking = false
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
        if not is_initial_scrolling and not is_end_scrolling then
            local target_camera_x = player.x + player.width / 2 - window.width / 2
            target_camera_x = math.max(0, math.min(target_camera_x, config.map.width * tileSize - window.width))
            local distance = target_camera_x - camera.x
            camera.x = camera.x + distance * math.min(cameraSpeed * dt / math.abs(distance), 1)
        end
    end
end

function love.keypressed(key)
    if key == "space" and player.can_shoot and not player.is_stunned and not player.is_dead and #bullets == 0 then
        local direction = love.keyboard.isDown("right") and 1 or love.keyboard.isDown("left") and -1 or player.last_direction
        table.insert(bullets, {
            x = player.x + player.width / 2,
            y = player.y + player.height / 2,
            width = 8,
            height = 8,
            velocityX = direction * 500,
            lifetime = 0.5
        })
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
        elseif player.is_powerup_blinking and math.floor(player.powerup_blink_timer / 0.1) % 2 == 1 then
            love.graphics.setColor(0.5, 0, 1)
        elseif player.can_shoot then
            love.graphics.setColor(0.5, 0, 1)
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
        if not coin.is_collected and not coin.is_powerup then
            love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
        end
    end
    love.graphics.setColor(0.5, 0, 1)
    for _, coin in ipairs(coins) do
        if not coin.is_collected and coin.is_powerup then
            love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
        end
    end
    love.graphics.setColor(0.5, 0, 1)
    for _, bullet in ipairs(bullets) do
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.width, bullet.height)
    end
    love.graphics.setColor(1, 1, 1)
    for _, end_point in ipairs(end_points) do
        love.graphics.rectangle("fill", end_point.x, end_point.y, end_point.width, end_point.height)
    end
    love.graphics.pop()
    if is_initial_scrolling then
        local alpha = 1.0 - math.min(initial_scroll_timer / 0.5, 1.0)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, window.width, love.graphics.getHeight())
    elseif is_end_scrolling then
        local alpha = 1.0 - math.min(end_scroll_timer / 0.5, 1.0)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, window.width, love.graphics.getHeight())
    end
end
