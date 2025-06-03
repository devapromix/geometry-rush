local sound = {}

local cache = {}

local function audio_from_cache(path)
	if cache[path] == nil then
		if not love.filesystem.getInfo(path) then 
			if config.debug then
				print("Could not find file: " .. path)
			end
			return false
		end
		cache[path] = love.audio.newSource(path, "stream")
	end
	return cache[path]:clone()
end

function sound.play(name)
	local source = audio_from_cache("assets/sounds/" .. name)
	source:setVolume(config.audio.sound.volume)
	source:play()
	return true
end

return sound