constants = require("constants")
utils = require("utils")
player = require("player")
sound = require("game.sound")
music = require("game.music")
enemy = require("enemy")

function love.load()
    gravity = constants.GRAVITY
    platforms = {}
    particles = {}
    coins = {}
    bullets = {}
    end_points = {}
    tileSize = constants.TILE_SIZE
    mapWidth = config.map.width
    mapHeight = config.map.height
    camera = { x = player.startX + player.width / 2 - window.width / 2 - window.width }
    isResetting = false
    resetCameraTargetX = 0
    cameraSpeed = constants.CAMERA_SPEED
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
                    width = constants.COIN_SIZE,
                    height = constants.COIN_SIZE,
                    is_collected = false
                })
            elseif char == "+" then
                table.insert(coins, {
                    x = (x - 1) * tileSize,
                    y = y * tileSize,
                    width = constants.COIN_SIZE,
                    height = constants.COIN_SIZE,
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
            end
        end
        y = y + 1
    end
    enemy.load(enemy_positions)
end

function resetLevel()
    player.reset()
    isResetting = true
    end_points = {}
    resetCameraTargetX = math.max(0, math.min(player.startX + player.width / 2 - window.width / 2, config.map.width * tileSize - window.width))
end

function love.update(dt)
    if is_initial_scrolling then
        initial_scroll_timer = initial_scroll_timer + dt
        local target_camera_x = math.max(0, math.min(player.startX + player.width / 2 - window.width / 2, config.map.width * tileSize - window.width))
        local start_camera_x = player.startX + player.width / 2 - window.width / 2 - window.width
        local t = math.min(initial_scroll_timer / constants.TRANSITION_TIME, 1.0)
        camera.x = start_camera_x + (target_camera_x - start_camera_x) * t
        if initial_scroll_timer >= constants.TRANSITION_TIME then
            is_initial_scrolling = false
            camera.x = target_camera_x
        end
    elseif is_end_scrolling then
        end_scroll_timer = end_scroll_timer + dt
        local start_camera_x = camera.x
        local target_camera_x = start_camera_x + window.width
        local t = math.min(end_scroll_timer / constants.TRANSITION_TIME, 1.0)
        camera.x = start_camera_x + ((target_camera_x - start_camera_x) * t)
        if end_scroll_timer >= constants.TRANSITION_TIME then
            is_end_scrolling = false
            camera.x = target_camera_x
        end
    elseif isResetting then
        local distance = resetCameraTargetX - camera.x
        if math.abs(distance) < 1 then
            camera.x = resetCameraTargetX
            player.x = player.startX
            player.y = player.startY
            isResetting = false
            player.reset()
        else
            camera.x = camera.x + distance * math.min(cameraSpeed * dt / math.abs(distance), 1)
        end
    else
        local should_reset, end_reached = player.update(dt, platforms, enemy.getEnemies(), coins, end_points, bullets, particles, gravity, mapWidth, tileSize)
        
        if should_reset then
            resetLevel()
        elseif end_reached then
            is_end_scrolling = true
            end_scroll_timer = 0
        end
        
        enemy.update(dt, platforms)
        
        for i = #bullets, 1, -1 do
            local bullet = bullets[i]
            bullet.x = bullet.x + bullet.velocityX * dt
            bullet.lifetime = bullet.lifetime - dt
            if bullet.lifetime <= 0 then
                table.remove(bullets, i)
            else
                for j = #enemy.getEnemies(), 1, -1 do
                    if utils.checkCollision(bullet, enemy.getEnemies()[j]) then
                        for k = 1, constants.PARTICLE_COUNT do
                            table.insert(particles, {
                                x = enemy.getEnemies()[j].x + math.random(-10, 10),
                                y = enemy.getEnemies()[j].y + math.random(-10, 10),
                                size = math.random(4, 8),
                                velocityX = math.random(-100, 100),
                                velocityY = math.random(-200, -50),
                                lifetime = math.random(0.5, 1.0)
                            })
                        end
                        table.remove(enemy.getEnemies(), j)
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
        
        if not is_initial_scrolling and not is_end_scrolling then
            local target_camera_x = player.x + player.width / 2 - window.width / 2
            target_camera_x = math.max(0, math.min(target_camera_x, config.map.width * tileSize - window.width))
            local distance = target_camera_x - camera.x
            camera.x = camera.x + distance * math.min(cameraSpeed * dt / math.abs(distance), 1)
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        player.shoot(bullets)
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, 0)
    love.graphics.setColor(constants.COLORS.PLATFORM)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)
    end
    if not isResetting and not player.is_exploding then
        if player.is_blinking and math.floor(player.blink_count) % 2 == 1 then
            love.graphics.setColor(constants.COLORS.PLAYER_BLINKING)
        elseif player.is_powerup_blinking and math.floor(player.powerup_blink_timer / constants.BLINK_INTERVAL) % 2 == 1 then
            love.graphics.setColor(constants.COLORS.PLAYER_POWERUP)
        elseif player.can_shoot then
            love.graphics.setColor(constants.COLORS.PLAYER_POWERUP)
        else
            love.graphics.setColor(constants.COLORS.PLAYER_NORMAL)
        end
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    end
    love.graphics.setColor(constants.COLORS.ENEMY)
    for _, e in ipairs(enemy.getEnemies()) do
        love.graphics.rectangle("fill", e.x, e.y, e.width, player.height)
    end
    love.graphics.setColor(constants.COLORS.PARTICLE)
    for _, particle in ipairs(particles) do
        love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
    end
    love.graphics.setColor(constants.COLORS.COIN)
    for _, coin in ipairs(coins) do
        if not coin.is_collected and not coin.is_powerup then
            love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
        end
    end
    love.graphics.setColor(constants.COLORS.POWERUP)
    for _, coin in ipairs(coins) do
        if not coin.is_collected and coin.is_powerup then
            love.graphics.rectangle("fill", coin.x, coin.y, coin.width, coin.height)
        end
    end
    love.graphics.setColor(constants.COLORS.BULLET)
    for _, bullet in ipairs(bullets) do
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.width, bullet.height)
    end
    love.graphics.setColor(constants.COLORS.END_POINT)
    for _, end_point in ipairs(end_points) do
        love.graphics.rectangle("fill", end_point.x, end_point.y, end_point.width, end_point.height)
    end
    love.graphics.pop()
    if is_initial_scrolling then
        local alpha = 1.0 - math.min(initial_scroll_timer / constants.TRANSITION_TIME, 1.0)
        love.graphics.setColor(constants.COLORS.BLACK[1], constants.COLORS.BLACK[2], constants.COLORS.BLACK[3], alpha)
        love.graphics.rectangle("fill", 0, 0, window.width, love.graphics.getHeight())
    elseif is_end_scrolling then
        local alpha = 1.0 - math.min(end_scroll_timer / constants.TRANSITION_TIME, 1.0)
        love.graphics.setColor(constants.COLORS.BLACK[1], constants.COLORS.BLACK[2], constants.COLORS.BLACK[3], alpha)
        love.graphics.rectangle("fill", 0, 0, window.width, love.graphics.getHeight())
    end
end