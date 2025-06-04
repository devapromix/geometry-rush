local constants = require("constants")
local utils = require("utils")

local enemy = {
    enemies = {}
}

function enemy.load(positions)
    enemy.enemies = {}
    for _, pos in ipairs(positions) do
        table.insert(enemy.enemies, {
            x = pos.x,
            y = pos.y,
            width = constants.PLAYER_SIZE,
            height = constants.PLAYER_SIZE,
            speed = constants.ENEMY_SPEED,
            direction = 1
        })
    end
end

function enemy.update(dt, platforms)
    local enemies_to_remove = {}
    for i, e in ipairs(enemy.enemies) do
        local old_x = e.x
        local old_direction = e.direction
        local next_x = e.x + e.speed * e.direction * dt
        local has_platform = false
        local hits_wall = false
        for _, platform in ipairs(platforms) do
            if utils.checkCollision({
                x = e.direction == 1 and next_x + e.width or next_x,
                y = e.y + e.height,
                width = 1,
                height = 1
            }, platform) then
                has_platform = true
            end
            if utils.checkCollision({
                x = e.direction == 1 and next_x + e.width or next_x,
                y = e.y,
                width = 1,
                height = e.height
            }, platform) then
                hits_wall = true
            end
        end
        if not has_platform or hits_wall then
            e.direction = -e.direction
            next_x = e.x
        end
        e.x = next_x
    end
    return enemies_to_remove
end

function enemy.getEnemies()
    return enemy.enemies
end

return enemy