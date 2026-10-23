-- Arrakis terminal: boot typewriter, record list with [ACTIVE] tags, clock, weather,
-- focus timer, Mentat command line, hidden-record discoveries and theme switching.
-- Keep this file ASCII-only; names and theme text come in through skin variables.

local STEP = 3        -- characters revealed per boot tick
local DELAY = 16      -- ms between boot ticks
local MAXLINES = 18   -- Line1..Line18 in Terminal.ini

local SEARCH = {
	g = 'https://www.google.com/search?q=',
	yt = 'https://www.youtube.com/results?search_query=',
	w = 'https://en.wikipedia.org/w/index.php?search=',
}

local function var(name, default) return SKIN:GetVariable(name, default or '') end

function Initialize()
	top = tonumber(var('Top', '18'))
	lineHeight = tonumber(var('LineHeight', '18'))
	colText, colSpice = var('ColText'), var('ColSpice')
	res = var('@')
	stateFile = res .. 'State.inc'
	soundDir = res .. 'Sounds\\' .. var('Sounds', '1') .. '\\'
	bootLine = var('BootLine', 'LOADING... COMPLETE.')
	unlockLine = var('UnlockLine', '')
	hasFocusRing = var('HasFocusRing', '0') == '1'
	hasKH = var('HasKH', '0') == '1'
	focusMinutes = tonumber(var('FocusMinutes', '25')) or 25

	rec = {}
	for i = 1, 6 do
		rec[i] = {
			name = var('Rec' .. i .. 'Name', 'RECORD ' .. i),
			cmd = var('Rec' .. i .. 'Cmd'),
			found = i <= 3 or var('Found' .. i, '0') == '1',
			active = false,
		}
	end
	nav = {}
	for i = 1, 6 do nav[i] = { name = var('Nav' .. i .. 'Name'):lower(), cmd = var('Nav' .. i .. 'Cmd') } end
	kh = var('KH', '0') == '1'

	selected, hoverLine = 0, 0
	status, statusUntil = nil, 0
	weather = nil
	focusEnd = tonumber(var('FocusEnd', '0')) or 0
	focusTotal = tonumber(var('FocusTotal', '0')) or 0
	focusResume = focusEnd > 0
	lastPush = 0

	typed, booting, blink = 0, true, true
	inTick, noDelay = false, false
	bootStarted = os.time()
	-- The cursor blinks for a while after any activity, then holds still so the
	-- terminal only redraws when the minute changes.
	activeUntil = os.time() + 30
	layout, shown = {}, {}
end

-- ------------------------------------------------------------------ helpers

local function persist(key, value)
	SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), stateFile)
end

local function play(name) SKIN:Bang('[Play "' .. soundDir .. name .. '.wav"]') end

local function run(cmd) if cmd and cmd ~= '' then SKIN:Bang('[' .. cmd .. ']') end end

local function wake() activeUntil = os.time() + 20 end

local function setStatus(lines, seconds)
	status = type(lines) == 'table' and lines or { lines }
	statusUntil = os.time() + seconds
	wake()
end

local function hiddenLeft()
	local n = 0
	for i = 4, 6 do if not rec[i].found then n = n + 1 end end
	return n
end

local function recordBang(i, ...)
	local args = { ... }
	args[#args + 1] = 'Arrakis\\Record' .. i
	SKIN:Bang(unpack(args))
end

local function setHot(i, v)
	recordBang(i, '!SetVariable', 'Hot', v)
	recordBang(i, '!UpdateMeter', '*')
	recordBang(i, '!Redraw')
end

local function fmt(v)
	if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', v) end
	return string.format('%.6g', v)
end

local function urlencode(s)
	return (s:gsub('[^%w%-_%.~]', function(c) return string.format('%%%02X', string.byte(c)) end))
end

-- ------------------------------------------------------------------ drawing

local function buildLines()
	local L = {}
	local function add(text, x, ref) L[#L + 1] = { text = text, x = x or 10, ref = ref } end
	add(bootLine)
	local left = hiddenLeft()
	add(left > 0 and string.format('6 RECORDS FOUND (%d HIDDEN).', left) or '6 RECORDS FOUND. NONE HIDDEN.')
	add('')
	for i = 1, 6 do
		if rec[i].found or selected == i then
			add(string.format('00%d : %s%s', i, rec[i].name, rec[i].active and '  [ACTIVE]' or ''), 30, { kind = 'record', index = i })
		end
	end
	add('')
	add('SYSTEM TIME ' .. os.date('%H:%M'))
	if weather then for _, w in ipairs(weather) do add(w) end end
	if focusEnd > 0 then
		local r = math.max(0, focusEnd - os.time())
		add(string.format('FOCUS %02d:%02d REMAINING  [STOP]', math.floor(r / 60), r % 60), 10, { kind = 'focus' })
	end
	if status then
		for _, s in ipairs(status) do add(s) end
	else
		add('END OF FILE. ' .. (blink and '_' or ''))
	end
	return L
end

local function totalChars()
	local n = 0
	for _, l in ipairs(buildLines()) do n = n + #l.text end
	return n
end

-- Pushes the current state to the meters, touching only lines that changed.
-- The skin's own update cycle never redraws (DefaultUpdateDivider=-1).
local function render()
	local L = buildLines()
	local budget = booting and typed or math.huge
	local dirty = false
	local markerY = -1
	layout = {}

	for i = 1, MAXLINES do
		local l = L[i]
		local text, x, color, click = '', 10, colText, false
		if l then
			text, x = l.text, l.x
			if budget >= #text then
				budget = budget - #text
			elseif budget > 0 then
				text = text:sub(1, budget) .. '_'
				budget = -1
			else
				text = ''
			end
			if l.ref and not booting then
				layout[i], click = l.ref, true
				if l.ref.kind == 'focus' or (l.ref.kind == 'record' and l.ref.index == selected) then color = colSpice end
				if l.ref.kind == 'record' and l.ref.index == selected then markerY = top + (i - 1) * lineHeight end
			end
		end
		local key = table.concat({ text, x, color, tostring(click), tostring(l ~= nil) }, '|')
		if shown[i] ~= key then
			local m = 'Line' .. i
			SKIN:Bang('!SetOption', m, 'Hidden', l and '0' or '1')
			SKIN:Bang('!SetOption', m, 'Text', text)
			SKIN:Bang('!SetOption', m, 'X', x)
			SKIN:Bang('!SetOption', m, 'FontColor', color)
			SKIN:Bang('!SetOption', m, 'SolidColor', click and '0,0,0,1' or '0,0,0,0')
			SKIN:Bang('!SetOption', m, 'MouseActionCursor', click and '1' or '0')
			SKIN:Bang('!UpdateMeter', m)
			shown[i], dirty = key, true
		end
	end

	if markerY ~= shown.marker then
		if markerY >= 0 then
			SKIN:Bang('!SetOption', 'Marker', 'Y', markerY)
			SKIN:Bang('!ShowMeter', 'Marker')
		else
			SKIN:Bang('!HideMeter', 'Marker')
		end
		SKIN:Bang('!UpdateMeter', 'Marker')
		shown.marker, dirty = markerY, true
	end
	if dirty then SKIN:Bang('!Redraw') end
end

-- ------------------------------------------------------------------ boot

function Boot()
	typed, booting = 0, true
	bootStarted = os.time()
	Tick()
end

function Tick()
	if not booting then return end
	-- If !Delay is unsupported the chained bang runs synchronously and lands here;
	-- fall back to typing on the regular skin update instead.
	if inTick then noDelay = true return end
	inTick = true
	typed = typed + STEP
	if typed >= totalChars() then booting = false end
	render()
	if booting and not noDelay then
		SKIN:Bang('[!Delay ' .. DELAY .. '][!CommandMeasure mScript "Tick()"]')
	end
	inTick = false
end

-- ------------------------------------------------------------------ focus timer

local function focusBang(...)
	local args = { ... }
	args[#args + 1] = 'Arrakis\\Focus'
	SKIN:Bang(unpack(args))
end

local function pushProgress(now)
	if not hasFocusRing or focusTotal <= 0 then return end
	local p = 1 - (focusEnd - now) / focusTotal
	focusBang('!SetVariable', 'Progress', string.format('%.4f', math.max(0.002, math.min(0.999, p))))
	focusBang('!UpdateMeter', '*')
	focusBang('!Redraw')
	lastPush = now
end

function StartFocus(minutes)
	minutes = math.max(1, math.min(240, math.floor(minutes or focusMinutes)))
	focusTotal = minutes * 60
	focusEnd = os.time() + focusTotal
	persist('FocusTotal', focusTotal)
	persist('FocusEnd', focusEnd)
	if hasFocusRing then SKIN:Bang('!ActivateConfig', 'Arrakis\\Focus', 'Focus.ini') end
	lastPush = 0
	play('open')
	setStatus(string.format('FOCUS SESSION STARTED: %d MIN.', minutes), 4)
	render()
end

local function endFocus()
	focusEnd = 0
	persist('FocusEnd', 0)
	if hasFocusRing then SKIN:Bang('!DeactivateConfig', 'Arrakis\\Focus') end
end

function StopFocus()
	if focusEnd == 0 then return end
	endFocus()
	setStatus('FOCUS SESSION ABORTED.', 4)
	render()
end

function ToggleFocus()
	if focusEnd > 0 then StopFocus() else StartFocus(focusMinutes) end
end

-- ------------------------------------------------------------------ records

function Launch(i)
	if not rec[i] then return end
	run(rec[i].cmd)
	play('click')
	setStatus('ACCESSING 00' .. i .. ' : ' .. rec[i].name .. '...', 3)
	booting = false
	render()
end

local function discover(i)
	rec[i].found = true
	persist('Found' .. i, 1)
	play('discover')
	if hiddenLeft() > 0 then
		setStatus('RECORD 00' .. i .. ' DISCOVERED.', 5)
		return
	end
	setStatus({ 'ALL RECORDS FOUND.', unlockLine }, 8)
	if hasKH and not kh then
		kh = true
		persist('KH', 1)
		SKIN:Bang('[!Delay 3500][!RefreshGroup Arrakis]')
	end
end

function Select(i)
	selected = i
	wake()
	if i >= 4 and not rec[i].found then discover(i) end
	if not booting then render() end
end

function Deselect(i)
	if selected == i then selected = 0 end
	if not booting then render() end
end

-- Line meters call these with their own line number.
function Hover(line)
	local ref = layout[line]
	hoverLine = line
	if ref and ref.kind == 'record' then
		Select(ref.index)
		setHot(ref.index, 1)
	end
end

function Leave(line)
	local ref = layout[line]
	if hoverLine == line then hoverLine = 0 end
	if ref and ref.kind == 'record' then
		Deselect(ref.index)
		setHot(ref.index, 0)
	end
end

function Click(line)
	local ref = layout[line]
	if not ref then return end
	if ref.kind == 'record' then Launch(ref.index) elseif ref.kind == 'focus' then StopFocus() end
end

-- ------------------------------------------------------------------ modes

function SwitchTheme(name)
	name = (name or ''):lower()
	if name == '' then name = var('OtherTheme'):lower() end
	local file = res .. 'Images\\Wallpapers\\' .. name .. '_day.png'
	local f = io.open(file, 'rb')
	if not f then
		setStatus('ARCHIVE ' .. name:upper() .. ' NOT FOUND.', 5)
		render()
		return
	end
	f:close()
	local proper = name:sub(1, 1):upper() .. name:sub(2)
	persist('Theme', proper)
	SKIN:Bang('!LoadLayout', proper)
end

function ToggleKH()
	if not hasKH then
		setStatus('NOT AVAILABLE ON THIS VESSEL.', 4)
	elseif hiddenLeft() > 0 then
		setStatus({ 'LOCKED.', 'FIND THE HIDDEN RECORDS.' }, 5)
	else
		kh = not kh
		persist('KH', kh and 1 or 0)
		SKIN:Bang('!RefreshGroup', 'Arrakis')
		return
	end
	render()
end

function ResetSecrets()
	for i = 4, 6 do persist('Found' .. i, 0) end
	persist('KH', 0)
	SKIN:Bang('!RefreshGroup', 'Arrakis')
end

function SetWeather(text)
	if text == nil or text == '' then
		weather = nil
	else
		weather = {}
		for part in text:gmatch('[^|]+') do weather[#weather + 1] = part end
	end
	if not booting then render() end
end

-- ------------------------------------------------------------------ Mentat

-- The input box is Mentat.exe, a separate short-lived process placed over the terminal line,
-- so no input plugin has to stay loaded inside Rainmeter.
function OpenMentat()
	booting = false
	wake()
	local y = top + #buildLines() * lineHeight
	SKIN:Bang('!SetOption', 'MeterMentat', 'Y', y)
	SKIN:Bang('!ShowMeter', 'MeterMentat')
	SKIN:Bang('!UpdateMeter', 'MeterMentat')
	render()
	SKIN:Bang('!Redraw')
	local x0 = tonumber(var('CURRENTCONFIGX', '14')) or 14
	local y0 = tonumber(var('CURRENTCONFIGY', '18')) or 18
	local args = string.format('"%s" "%s" %d %d 330 24 %s 24,10,3 "Bahnschrift" 14',
		var('PROGRAMPATH') .. 'Rainmeter.exe', res .. 'mentat.txt', x0 + 104, y0 + y - 12, colText)
	play('open')
	run('"' .. res .. 'Scripts\\Mentat.exe" ' .. args)
end

function CloseMentat()
	SKIN:Bang('!HideMeter', 'MeterMentat')
	SKIN:Bang('!UpdateMeter', 'MeterMentat')
	SKIN:Bang('!Redraw')
end

-- Called by Mentat.exe after Enter.
function MentatFile()
	local path = res .. 'mentat.txt'
	local f = io.open(path, 'rb')
	if not f then CloseMentat() return end
	local text = f:read('*a')
	f:close()
	os.remove(path)
	Mentat(text)
end

function Mentat(text)
	CloseMentat()
	local raw = (text or var('MentatInput')):match('^%s*(.-)%s*$') or ''
	if raw == '' then render() return end
	local s = raw:lower()
	local cmd, rest = s:match('^(%S+)%s*(.*)$')

	if s == '?' or s == 'help' then
		setStatus({ 'TYPE AN APP OR FOLDER NAME', 'G / YT / W <SEARCH>   12*48', 'FOCUS [MIN]  THEME  CINEMA  KH', 'GUARD ON / OFF' }, 14)
	elseif cmd == 'focus' then
		if rest == 'stop' or rest == 'off' then StopFocus() else StartFocus(tonumber(rest) or focusMinutes) end
		return
	elseif cmd == 'theme' then
		SwitchTheme(rest)
		return
	elseif s == 'cinema' then
		SKIN:Bang('!CommandMeasure', 'mTitle', 'ToggleCinema()', 'Arrakis\\Title')
	elseif s == 'kh' then
		ToggleKH()
		return
	elseif cmd == 'guard' then
		-- The guard (Task Scheduler) restarts Rainmeter unless this flag file exists.
		local flag = os.getenv('APPDATA') .. '\\Rainmeter\\Arrakis-guard-off'   -- same path Guard.exe checks
		if rest == 'off' then
			local f = io.open(flag, 'w')
			if f then f:write('Arrakis guard paused from Mentat.') f:close() end
			setStatus({ 'GUARD OFF.', 'RAINMETER CAN BE CLOSED NOW.' }, 6)
		elseif rest == 'on' then
			os.remove(flag)
			setStatus('GUARD ON. AUTO-RESTART ARMED.', 5)
		else
			local f = io.open(flag, 'r')
			if f then f:close() end
			setStatus(f and 'GUARD IS OFF.  TYPE: GUARD ON' or 'GUARD IS ON.  TYPE: GUARD OFF', 6)
		end
	elseif s == 'terminal' or s == 'wt' or s == 'cmd' or s == 'prompt' then
		run(var('PromptCmd'))
		setStatus('OPENING TERMINAL...', 3)
	elseif SEARCH[cmd] and rest ~= '' then
		local query = raw:match('^%S+%s+(.*)$')
		run('"' .. SEARCH[cmd] .. urlencode(query) .. '"')
		setStatus('SEARCHING: ' .. rest:upper():sub(1, 24), 4)
	elseif s:match('^[%d%s%+%-%*/%%%^%.%(%)]+$') and s:match('%d') and s:match('[%+%-%*/%%%^]') then
		local f = loadstring('return ' .. s)
		local ok, v = false, nil
		if f then ok, v = pcall(f) end
		if ok and type(v) == 'number' and v == v then
			setStatus(raw .. ' = ' .. fmt(v), 12)
		else
			setStatus('MENTAT: CANNOT COMPUTE.', 4)
		end
	else
		for i = 1, 6 do
			if rec[i].found and rec[i].name:lower():find(s, 1, true) == 1 then Launch(i) return end
		end
		for i = 1, 6 do
			if nav[i].name ~= '' and nav[i].name:find(s, 1, true) == 1 then
				run(nav[i].cmd)
				setStatus('OPENING ' .. nav[i].name:upper() .. '...', 3)
				render()
				return
			end
		end
		if raw:match('^%a:[\\/]') then
			run('"' .. raw .. '"')
			setStatus('OPENING PATH...', 3)
		elseif not raw:find('%s') and raw:find('%.') and not raw:find('\\') then
			run('"' .. (raw:match('^%a+://') and raw or ('https://' .. raw)) .. '"')
			setStatus('OPENING ' .. s:upper():sub(1, 28), 3)
		else
			run(raw)
			setStatus('EXECUTING: ' .. raw:upper():sub(1, 25), 3)
		end
		play('click')
	end
	render()
end

-- ------------------------------------------------------------------ update

function Update()
	local now = os.time()
	if now < activeUntil then blink = not blink else blink = true end
	if status and now >= statusUntil then status = nil end

	-- live records: the Process measures refresh every 5 seconds
	for i = 1, 6 do
		local m = SKIN:GetMeasure('mProc' .. i)
		local a = m ~= nil and m:GetValue() == 1
		if a ~= rec[i].active then
			rec[i].active = a
			recordBang(i, '!SetVariable', 'Active', a and '1' or '0')
			recordBang(i, '!UpdateMeter', '*')
			recordBang(i, '!Redraw')
		end
	end

	if focusEnd > 0 then
		if now >= focusEnd then
			endFocus()
			if focusResume then
				focusResume = false       -- finished while Rainmeter was closed
			else
				play('chime')
				setStatus({ 'FOCUS COMPLETE.', 'THE SPICE MUST FLOW.' }, 20)
			end
		else
			if focusResume then
				focusResume = false
				if hasFocusRing then SKIN:Bang('!ActivateConfig', 'Arrakis\\Focus', 'Focus.ini') end
				lastPush = 0
			end
			if now - lastPush >= 10 then pushProgress(now) end
		end
	end

	if booting then
		if noDelay then typed = typed + 40 end
		if typed >= totalChars() or now - bootStarted > 10 then booting = false end
		if noDelay or not booting then render() end
	else
		render()
	end
	return 0
end
