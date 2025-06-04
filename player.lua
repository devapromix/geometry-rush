local player = {
    x = 0,
    y = 0,
    width = constants.PLAYER_SIZE,
    height = constants.PLAYER_SIZE,
    speed = constants.PLAYER_SPEED,
    jumpForce = constants.PLAYER_JUMP_FORCE,
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

function player.reset()
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

function player.handleInput()
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
end

function player.shoot(bullets)
    if player.can_shoot and not player.is_stunned and not player.is_dead and #bullets == 0 then
        local direction = love.keyboard.isDown("right") and 1 or love.keyboard.isDown("left") and -1 or player.last_direction
        table.insert(bullets, {
            x = player.x + player.width / 2,
            y = player.y + player.height / 2,
            width = constants.BULLET_SIZE,
            height = constants.BULLET_SIZE,
            velocityX = direction * constants.BULLET_SPEED,
            lifetime = constants.BULLET_LIFETIME
        })
        return true
    end
    return false
end

function player.checkPlatformCollisions(platforms, prevX, prevY)
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
end

function player.checkEnemyCollisions(enemies, prevX, prevY, particles)
    local enemies_to_remove = {}
    for i, enemy in ipairs(enemies) do
        if not player.is_stunned and not player.is_dead and utils.checkCollision(player, enemy) then
            if player.velocityY > 0 and prevY + player.height <= enemy.y + constants.ENEMY_PLATFORM_DETECTION then
                table.insert(enemies_to_remove, i)
                for j = 1, constants.PARTICLE_COUNT do
                    table.insert(particles, {
                        x = enemy.x + math.random(-10, 10),
                        y = enemy.y + math.random(-10, 10),
                        size = math.random(4, 8),
                        velocityX = math.random(-100, 100),
                        velocityY = math.random(-200, -50),
                        lifetime = math.random(0.5, 1.0)
                    })
                end
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
end

function player.checkCoinCollisions(coins)
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
end

function player.checkEndPointCollisions(end_points)
    for _, end_point in ipairs(end_points) do
        if utils.checkCollision(player, end_point) then
            return true
        end
    end
    return false
end

function player.updateEffects(dt)
    if player.is_blinking then
        player.blink_timer = player.blink_timer + dt
        if player.blink_timer >= constants.BLINK_INTERVAL then
            player.blink_timer = player.blink_timer - constants.BLINK_INTERVAL
            player.blink_count = player.blink_count + 1
            if player.blink_count >= constants.BLINK_COUNT then
                player.is_blinking = false
                player.is_stunned = false
            end
        end
    end
    
    if player.is_powerup_blinking then
        player.powerup_blink_timer = player.powerup_blink_timer + dt
        if player.powerup_blink_timer >= constants.POWERUP_BLINK_TIME then
            player.is_powerup_blinking = false
        end
    end
    
    if player.is_exploding then
        player.explode_timer = player.explode_timer + dt
        if player.explode_timer >= constants.EXPLODE_TIME then
            return true
        end
    end
    
    return false
end

function player.restrictBounds(mapWidth, tileSize)
    if player.x < 0 then
        player.x = 0
        player.velocityX = 0
    elseif player.x + player.width > mapWidth * tileSize then
        player.x = mapWidth * tileSize - player.width
        player.velocityX = 0
    end
end

function player.update(dt, platforms, enemies, coins, end_points, bullets, particles, gravity, mapWidth, tileSize)
    if player.is_dead and not player.is_exploding then
        return false, false
    end
    
    local prevX, prevY = player.x, player.y
    
    player.handleInput()
    
    player.velocityY = player.velocityY + gravity * dt
    player.x = player.x + player.velocityX * dt
    player.y = player.y + player.velocityY * dt
    
    if not player.is_dead then
        player.checkPlatformCollisions(platforms, prevX, prevY)
        player.checkCoinCollisions(coins)
        
        local end_reached = player.checkEndPointCollisions(end_points)
        if end_reached then
            return false, true
        end
    end
    
    player.checkEnemyCollisions(enemies, prevX, prevY, particles)
    
    local should_reset = player.updateEffects(dt)
    if should_reset then
        return true, false
    end
    
    if player.y > constants.DEATH_Y then
        player.is_exploding = true
        player.explode_timer = 0
        for i = 1, constants.PARTICLE_COUNT do
            table.insert(particles, {
                x = player.x + math.random(-10, 10),
                y = player.y + math.random(-10, 10),
                size = math.random(4, 8),
                velocityX = math.random(-100, 100),
                velocityY = math.random(-200, -50),
                lifetime = math.random(0.5, 1.0)
            })
        end
    end
    
    player.restrictBounds(mapWidth, tileSize)
    
    return false, false
end

return player