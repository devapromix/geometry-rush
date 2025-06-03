config = {

	debug = false,
	
	audio = {
		volume = 0.5,
	},
	
	game = {
		name = 'GeometryRush',
		version = '0.1.0',
	},
	
	map = {
        width = 200,
        height = 18,
	}
}

window = {
	--width = 1920,
	--height = 1080,
	width = 1200,
	height = 600,
	fullscreen = false,
}

for _, v in ipairs(arg) do
    if v == "-d" then
        config.debug = true
        break
    end
end

function love.conf (t)
	t.console = config.debug
	t.window.fullscreen = window.fullscreen
	t.window.msaa = 0
	t.window.fsaa = 0
	t.window.display = 1
	t.window.resizable = false
	t.window.vsync = false
	t.identity = "GeometryRush"
	t.window.title = config.game.name
	t.window.width = window.width
	t.window.height = window.height
	t.window.icon = "assets/icons/game.png"
end