-- Arrakis title: recycle bin size for the footer and cinema mode.

local CONFIGS = { 'Terminal', 'Controls', 'Record1', 'Record2', 'Record3', 'Record4', 'Record5', 'Record6', 'Stats' }

function Initialize()
	cinema = false
	bin = SKIN:GetMeasure('mBin')
end

-- The return value fills %1 of the recycle bin link.
function Update()
	local b = bin:GetValue()
	if b <= 0 then return 'EMPTY' end
	if b >= 1073741824 then return string.format('%.1f GB', b / 1073741824) end
	if b >= 1048576 then return string.format('%d MB', math.floor(b / 1048576)) end
	return string.format('%d KB', math.max(1, math.floor(b / 1024)))
end

-- Cinema mode: everything fades except the title, the date and the moons.
function ToggleCinema()
	cinema = not cinema
	local bang = cinema and '!HideFade' or '!ShowFade'
	for _, c in ipairs(CONFIGS) do SKIN:Bang(bang, 'Arrakis\\' .. c) end
	SKIN:Bang(cinema and '!HideMeterGroup' or '!ShowMeterGroup', 'Chrome')
	SKIN:Bang('!Redraw')
end
