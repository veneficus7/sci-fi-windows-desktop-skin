-- Arrakis stats: formats the billing-block lines.
-- Line1 is set directly; the return value feeds Line2 (followed by the Motto variable).

local GB = 1024 ^ 3
local SEP = '     '

function Initialize()
	m = {}
	for _, n in ipairs({ 'mCPU', 'mRAM', 'mRAMTotal', 'mDiskFree', 'mNetIn', 'mNetOut',
	                     'mUptime', 'mBattery', 'mAC', 'mUser', 'mHost' }) do
		m[n] = SKIN:GetMeasure(n)
	end
	-- Sandworm: loaded only while something is downloading.
	hasWorm = SKIN:GetVariable('HasWorm', '0') == '1'
	wormThreshold = tonumber(SKIN:GetVariable('WormThreshold', '200000')) or 200000
	wormOn, busy, calm = false, 0, 0
end

local function updateWorm(rate)
	if not hasWorm then return end
	if rate >= wormThreshold then
		busy, calm = busy + 1, 0
		if not wormOn and busy >= 2 then
			wormOn = true
			SKIN:Bang('!ActivateConfig', 'Arrakis\\Worm', 'Worm.ini')
		end
	else
		busy, calm = 0, calm + 1
		if wormOn and calm >= 6 then
			wormOn = false
			SKIN:Bang('!DeactivateConfig', 'Arrakis\\Worm')
		end
	end
end

local function rate(b)
	if b >= 1048576 then return string.format('%.1f MB/S', b / 1048576) end
	if b >= 1024 then return string.format('%d KB/S', math.floor(b / 1024)) end
	return string.format('%d B/S', math.floor(b))
end

local function uptime(s)
	local d = math.floor(s / 86400)
	local h = math.floor(s % 86400 / 3600)
	local mi = math.floor(s % 3600 / 60)
	if d > 0 then return string.format('%dD %dH %dM', d, h, mi) end
	return string.format('%dH %dM', h, mi)
end

function Update()
	updateWorm(m.mNetIn:GetValue())
	local ac = m.mAC:GetValue() == 1 and ' AC' or ''
	local line1 = table.concat({
		string.format('CPU %d%%', math.floor(m.mCPU:GetValue())),
		string.format('MEMORY %.1f / %.1f GB', m.mRAM:GetValue() / GB, m.mRAMTotal:GetValue() / GB),
		string.format('DISK C: %d GB FREE', math.floor(m.mDiskFree:GetValue() / GB)),
		'NETWORK IN ' .. rate(m.mNetIn:GetValue()) .. '  OUT ' .. rate(m.mNetOut:GetValue()),
		string.format('BATTERY %d%%%s', math.floor(m.mBattery:GetValue()), ac),
	}, SEP)
	SKIN:Bang('!SetOption', 'Line1', 'Text', line1)

	return table.concat({
		'UPTIME ' .. uptime(m.mUptime:GetValue()),
		'OPERATOR ' .. string.upper(m.mUser:GetStringValue()),
		'HOST ' .. string.upper(m.mHost:GetStringValue()),
	}, SEP)
end
