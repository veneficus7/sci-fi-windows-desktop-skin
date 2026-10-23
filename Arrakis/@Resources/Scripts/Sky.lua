-- Arrakis sky: picks the wallpaper for the time of day and weather, feeds the weather line
-- to the terminal and moves the two moons that tell the time.

-- Planet centre and orbit radii (keep in sync with build/make_assets.py)
local CX, CY = 975, 368
local R_HOUR, R_MIN = 215, 268
local HOUR_SIZE, MIN_SIZE = 44, 32

local function var(name, default) return SKIN:GetVariable(name, default or '') end

function Initialize()
	prefix = var('WallPrefix', 'arrakis')
	hasStorm = var('HasStorm', '0') == '1'
	hasMoons = var('HasMoons', '0') == '1'
	stormWind = tonumber(var('StormWind', '25')) or 25
	label = var('WeatherLabel', 'SURFACE')
	dir = var('@') .. 'Images\\Wallpapers\\'
	setter = var('@') .. 'Scripts\\SetWallpaper.exe'
	sunrise, sunset = 6 * 60 + 30, 18 * 60 + 30   -- minutes; replaced by real data when available
	temp, wind = nil, nil
	current, lastMinute = nil, -1
	if var('Latitude') ~= '' and var('Longitude') ~= '' then
		SKIN:Bang('!EnableMeasure', 'mWeather')
	end
end

local function phase(m)
	if m >= sunrise - 45 and m < sunrise + 75 then return 'dawn' end
	if m >= sunrise + 75 and m < sunset - 75 then return 'day' end
	if m >= sunset - 75 and m < sunset + 45 then return 'dusk' end
	return 'night'
end

local function applyWallpaper(t)
	local p = phase(t.hour * 60 + t.min)
	if prefix ~= 'arrakis' then p = (p == 'day' or p == 'dawn') and 'day' or 'night' end
	local storm = hasStorm and wind ~= nil and wind >= stormWind
	local file = dir .. prefix .. '_' .. p .. (storm and '_storm' or '') .. '.png'
	if file ~= current then
		current = file
		SKIN:Bang('["' .. setter .. '" "' .. file .. '"]')
	end
end

local function moveMoons(t)
	if not hasMoons then return end
	local ha = ((t.hour % 12) + t.min / 60) / 12 * 2 * math.pi
	local ma = t.min / 60 * 2 * math.pi
	SKIN:Bang('!Move', math.floor(CX + R_HOUR * math.sin(ha) - HOUR_SIZE / 2 + 0.5),
		math.floor(CY - R_HOUR * math.cos(ha) - HOUR_SIZE / 2 + 0.5), 'Arrakis\\Moon1')
	SKIN:Bang('!Move', math.floor(CX + R_MIN * math.sin(ma) - MIN_SIZE / 2 + 0.5),
		math.floor(CY - R_MIN * math.cos(ma) - MIN_SIZE / 2 + 0.5), 'Arrakis\\Moon2')
end

function Update()
	local t = os.date('*t')
	local minute = t.hour * 60 + t.min
	if minute ~= lastMinute then
		lastMinute = minute
		applyWallpaper(t)
		moveMoons(t)
	end
	return 0
end

local function hhmm(s)
	if not s then return nil end
	local h, m = s:match('(%d%d):(%d%d)')
	if h then return tonumber(h) * 60 + tonumber(m) end
end

function WeatherReady()
	local json = SKIN:GetMeasure('mWeather'):GetStringValue()
	local cur = json:match('"current"%s*:%s*(%b{})')
	if cur then
		temp = tonumber(cur:match('"temperature_2m"%s*:%s*([%-%d%.]+)'))
		wind = tonumber(cur:match('"wind_speed_10m"%s*:%s*([%-%d%.]+)'))
	end
	-- Day/night follows this PC's clock, so the weather city's sunrise and sunset are only
	-- used when that city is in (roughly) the same time zone as the PC.
	local now = os.time()
	local pcOffset = os.difftime(now, os.time(os.date('!*t', now)))
	local cityOffset = tonumber(json:match('"utc_offset_seconds"%s*:%s*(%-?%d+)'))
	if cityOffset and math.abs(cityOffset - pcOffset) <= 5400 then
		sunrise = hhmm(json:match('"sunrise"%s*:%s*%[%s*"([^"]+)"')) or sunrise
		sunset = hhmm(json:match('"sunset"%s*:%s*%[%s*"([^"]+)"')) or sunset
	end

	if temp and wind then
		local line = string.format('%s %dC  WIND %d KM/H', label, math.floor(temp + 0.5), math.floor(wind + 0.5))
		if hasStorm then
			local risk = wind >= stormWind and 'HIGH' or (wind >= stormWind * 0.6 and 'MODERATE' or 'LOW')
			line = line .. '|STORM RISK ' .. risk
		end
		SKIN:Bang('!CommandMeasure', 'mScript', "SetWeather('" .. line .. "')", 'Arrakis\\Terminal')
	end
	lastMinute = -1   -- re-check the wallpaper with the new sun and wind data
	Update()
end

-- Called by a moon skin when it (re)loads.
function Reposition()
	moveMoons(os.date('*t'))
end
