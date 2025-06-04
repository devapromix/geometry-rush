local constants = {
    TILE_SIZE = 32,
    PLAYER_SIZE = 32,
    COIN_SIZE = 16,
    BULLET_SIZE = 8,
    
    GRAVITY = 800,
    PLAYER_SPEED = 250,
    PLAYER_JUMP_FORCE = -350,
    ENEMY_SPEED = 100,
    BULLET_SPEED = 500,
    CAMERA_SPEED = 2000,
    
    BLINK_INTERVAL = 0.1,
    BLINK_COUNT = 6,
    EXPLODE_TIME = 0.5,
    BULLET_LIFETIME = 0.5,
    POWERUP_BLINK_TIME = 1.0,
    TRANSITION_TIME = 0.5,
    
    DEATH_Y = 600,
    PARTICLE_COUNT = 20,
    ENEMY_PLATFORM_DETECTION = 10,
    
    COLORS = {
        PLATFORM = {0.6, 0.4, 0.2},
        PLAYER_NORMAL = {0, 1, 0},
        PLAYER_BLINKING = {0.7, 1, 0.7},
        PLAYER_POWERUP = {0.5, 0, 1},
        ENEMY = {1, 0, 0},
        PARTICLE = {0.8, 0, 0},
        COIN = {1, 1, 0},
        POWERUP = {0.5, 0, 1},
        BULLET = {0.5, 0, 1},
        END_POINT = {1, 1, 1},
        BLACK = {0, 0, 0}
    }
}

return constants