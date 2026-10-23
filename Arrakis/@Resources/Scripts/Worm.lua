-- Sandworm: rides the dune crest across the screen; speed follows the download rate.

local W, H = 240, 64
local SCREEN_W = 1920

local function crest(x)
	local u = (x - 960) / 960
	return 845 + 62 * (1 - u * u)
end

function Initialize()
	x, dir = SCREEN_W, -1
	images = { [-1] = SKIN:GetVariable('@') .. 'Images\\worm_l.png', [1] = SKIN:GetVariable('@') .. 'Images\\worm_r.png' }
	net = SKIN:GetMeasure('mNet')
end

local function face(d)
	dir = d
	SKIN:Bang('!SetOption', 'MeterWorm', 'ImageName', images[d])
	SKIN:Bang('!UpdateMeter', 'MeterWorm')
	SKIN:Bang('!Redraw')
end

function Update()
	local rate = net:GetValue()
	local speed = 1.5 + 6 * math.min(1, rate / (8 * 1048576))
	x = x + dir * speed
	if x < -W then face(1) x = -W end
	if x > SCREEN_W then face(-1) x = SCREEN_W end
	SKIN:Bang('!Move', math.floor(x), math.floor(crest(x + W / 2) - H / 2))
	return 0
end
