script_name("HUD")
script_author("dmitriyewich, trefa(hungry)")
script_description("numbers on hud + seperator dot  on money on hud.")
script_url("https://vk.com/dmitriyewichmods")
script_dependencies("ffi", "memory", "encoding")
script_properties('work-in-pause', 'forced-reloading-only')
script_version("2.0.1")

require 'lib.moonloader'
local lmemory, memory = pcall(require, 'memory')
assert(lmemory, 'Library \'memory\' not found.')
local lffi, ffi = pcall(require, 'ffi')
assert(lffi, 'Library \'ffi\' not found.')
local lencoding, encoding = pcall(require, 'encoding')
assert(lencoding, 'Library \'encoding\' not found.')
local lwm, wm = pcall(require, 'windows.message')
assert(lwm, 'Library \'windows.message\' not found.')

encoding.default = 'CP1251'
u8 = encoding.UTF8
CP1251 = encoding.CP1251

active = true
money_set, health_set, armour_set, hungry_set = false, false, false, false
hun = 0
chislo = nil

ffi.cdef[[
	typedef void* HANDLE;
	typedef void* LPSECURITY_ATTRIBUTES;
	typedef unsigned long DWORD;
	typedef int BOOL;
	typedef const char *LPCSTR;
	typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
	} FILETIME, *PFILETIME, *LPFILETIME;

	BOOL __stdcall GetFileTime(HANDLE hFile, LPFILETIME lpCreationTime, LPFILETIME lpLastAccessTime, LPFILETIME lpLastWriteTime);
	HANDLE __stdcall CreateFileA(LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
	BOOL __stdcall CloseHandle(HANDLE hObject);
]]

local function isarray(t, emptyIsObject) -- by Phrogz, сортировка
	if type(t)~='table' then return false end
	if not next(t) then return not emptyIsObject end
	local len = #t
	for k,_ in pairs(t) do
		if type(k)~='number' then
			return false
		else
			local _,frac = math.modf(k)
			if frac~=0 or k<1 or k>len then
				return false
			end
		end
	end
	return true
end

local function map(t,f)
	local r={}
	for i,v in ipairs(t) do r[i]=f(v) end
	return r
end

local keywords = {["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["false"]=1,["for"]=1,["function"]=1,["goto"]=1,["if"]=1,["in"]=1,["local"]=1,["nil"]=1,["not"]=1,["or"]=1,["repeat"]=1,["return"]=1,["then"]=1,["true"]=1,["until"]=1,["while"]=1}

local function neatJSON(value, opts) -- by Phrogz, сортировка
	opts = opts or {}
	if opts.wrap==nil  then opts.wrap = 80 end
	if opts.wrap==true then opts.wrap = -1 end
	opts.indent         = opts.indent         or "  "
	opts.arrayPadding  = opts.arrayPadding  or opts.padding      or 0
	opts.objectPadding = opts.objectPadding or opts.padding      or 0
	opts.afterComma    = opts.afterComma    or opts.aroundComma  or 0
	opts.beforeComma   = opts.beforeComma   or opts.aroundComma  or 0
	opts.beforeColon   = opts.beforeColon   or opts.aroundColon  or 0
	opts.afterColon    = opts.afterColon    or opts.aroundColon  or 0
	opts.beforeColon1  = opts.beforeColon1  or opts.aroundColon1 or opts.beforeColon or 0
	opts.afterColon1   = opts.afterColon1   or opts.aroundColon1 or opts.afterColon  or 0
	opts.beforeColonN  = opts.beforeColonN  or opts.aroundColonN or opts.beforeColon or 0
	opts.afterColonN   = opts.afterColonN   or opts.aroundColonN or opts.afterColon  or 0

	local colon  = opts.lua and '=' or ':'
	local array  = opts.lua and {'{','}'} or {'[',']'}
	local apad   = string.rep(' ', opts.arrayPadding)
	local opad   = string.rep(' ', opts.objectPadding)
	local comma  = string.rep(' ',opts.beforeComma)..','..string.rep(' ',opts.afterComma)
	local colon1 = string.rep(' ',opts.beforeColon1)..colon..string.rep(' ',opts.afterColon1)
	local colonN = string.rep(' ',opts.beforeColonN)..colon..string.rep(' ',opts.afterColonN)

	local build
	local function rawBuild(o,indent)
		if o==nil then
			return indent..'null'
		else
			local kind = type(o)
			if kind=='number' then
				local _,frac = math.modf(o)
				return indent .. string.format( frac~=0 and opts.decimals and ('%.'..opts.decimals..'f') or '%g', o)
			elseif kind=='boolean' or kind=='nil' then
				return indent..tostring(o)
			elseif kind=='string' then
				return indent..string.format('%q', o):gsub('\\\n','\\n')
			elseif isarray(o, opts.emptyTablesAreObjects) then
				if #o==0 then return indent..array[1]..array[2] end
				local pieces = map(o, function(v) return build(v,'') end)
				local oneLine = indent..array[1]..apad..table.concat(pieces,comma)..apad..array[2]
				if opts.wrap==false or #oneLine<=opts.wrap then return oneLine end
				if opts.short then
					local indent2 = indent..' '..apad;
					pieces = map(o, function(v) return build(v,indent2) end)
					pieces[1] = pieces[1]:gsub(indent2,indent..array[1]..apad, 1)
					pieces[#pieces] = pieces[#pieces]..apad..array[2]
					return table.concat(pieces, ',\n')
				else
					local indent2 = indent..opts.indent
					return indent..array[1]..'\n'..table.concat(map(o, function(v) return build(v,indent2) end), ',\n')..'\n'..(opts.indentLast and indent2 or indent)..array[2]
				end
			elseif kind=='table' then
				if not next(o) then return indent..'{}' end

				local sortedKV = {}
				local sort = opts.sort or opts.sorted
				for k,v in pairs(o) do
					local kind = type(k)
					if kind=='string' or kind=='number' then
						sortedKV[#sortedKV+1] = {k,v}
						if sort==true then
							sortedKV[#sortedKV][3] = tostring(k)
						elseif type(sort)=='function' then
							sortedKV[#sortedKV][3] = sort(k,v,o)
						end
					end
				end
				if sort then table.sort(sortedKV, function(a,b) return a[3]<b[3] end) end
				local keyvals
				if opts.lua then
					keyvals=map(sortedKV, function(kv)
						if type(kv[1])=='string' and not keywords[kv[1]] and string.match(kv[1],'^[%a_][%w_]*$') then
							return string.format('%s%s%s',kv[1],colon1,build(kv[2],''))
						else
							return string.format('[%q]%s%s',kv[1],colon1,build(kv[2],''))
						end
					end)
				else
					keyvals=map(sortedKV, function(kv) return string.format('%q%s%s',kv[1],colon1,build(kv[2],'')) end)
				end
				keyvals=table.concat(keyvals, comma)
				local oneLine = indent.."{"..opad..keyvals..opad.."}"
				if opts.wrap==false or #oneLine<opts.wrap then return oneLine end
				if opts.short then
					keyvals = map(sortedKV, function(kv) return {indent..' '..opad..string.format('%q',kv[1]), kv[2]} end)
					keyvals[1][1] = keyvals[1][1]:gsub(indent..' ', indent..'{', 1)
					if opts.aligned then
						local longest = math.max(table.unpack(map(keyvals, function(kv) return #kv[1] end)))
						local padrt   = '%-'..longest..'s'
						for _,kv in ipairs(keyvals) do kv[1] = padrt:format(kv[1]) end
					end
					for i,kv in ipairs(keyvals) do
						local k,v = kv[1], kv[2]
						local indent2 = string.rep(' ',#(k..colonN))
						local oneLine = k..colonN..build(v,'')
						if opts.wrap==false or #oneLine<=opts.wrap or not v or type(v)~='table' then
							keyvals[i] = oneLine
						else
							keyvals[i] = k..colonN..build(v,indent2):gsub('^%s+','',1)
						end
					end
					return table.concat(keyvals, ',\n')..opad..'}'
				else
					local keyvals
					if opts.lua then
						keyvals=map(sortedKV, function(kv)
							if type(kv[1])=='string' and not keywords[kv[1]] and string.match(kv[1],'^[%a_][%w_]*$') then
								return {table.concat{indent,opts.indent,kv[1]}, kv[2]}
							else
								return {string.format('%s%s[%q]',indent,opts.indent,kv[1]), kv[2]}
							end
						end)
					else
						keyvals = {}
						for i,kv in ipairs(sortedKV) do
							keyvals[i] = {indent..opts.indent..string.format('%q',kv[1]), kv[2]}
						end
					end
					if opts.aligned then
						local longest = math.max(table.unpack(map(keyvals, function(kv) return #kv[1] end)))
						local padrt   = '%-'..longest..'s'
						for _,kv in ipairs(keyvals) do kv[1] = padrt:format(kv[1]) end
					end
					local indent2 = indent..opts.indent
					for i,kv in ipairs(keyvals) do
						local k,v = kv[1], kv[2]
						local oneLine = k..colonN..build(v,'')
						if opts.wrap==false or #oneLine<=opts.wrap or not v or type(v)~='table' then
							keyvals[i] = oneLine
						else
							keyvals[i] = k..colonN..build(v,indent2):gsub('^%s+','',1)
						end
					end
					return indent..'{\n'..table.concat(keyvals, ',\n')..'\n'..(opts.indentLast and indent2 or indent)..'}'
				end
			end
		end
	end

	local function memoize()
		local memo = setmetatable({},{_mode='k'})
		return function(o,indent)
			if o==nil then
				return indent..(opts.lua and 'nil' or 'null')
			elseif o~=o then
				return indent..(opts.lua and '0/0' or '"NaN"')
			elseif o==math.huge then
				return indent..(opts.lua and '1/0' or '9e9999')
			elseif o==-math.huge then
				return indent..(opts.lua and '-1/0' or '-9e9999')
			end
			local byIndent = memo[o]
			if not byIndent then
				byIndent = setmetatable({},{_mode='k'})
				memo[o] = byIndent
			end
			if not byIndent[indent] then
				byIndent[indent] = rawBuild(o,indent)
			end
			return byIndent[indent]
		end
	end

	build = memoize()
	return build(value,'')
end

function savejson(table, path)
    local f = io.open(path, "w")
    f:write(table)
    f:close()
end

function convertTableToJsonString(config)
	return (neatJSON(config, { wrap = 40, short = true, sort = true, aligned = true, arrayPadding = 1, afterComma = 1, beforeColon1 = 1 }))
end

local config = {}

function defalut_config()
	config = {
		['money'] = {['symbol'] = "$", ['sizeX'] = 0.55, ['sizeY'] = 2.15 ,['posX'] = 489, ['posY'] = 77.5, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color_plus'] = "0xFF36662c", ['color_minus'] = "0xFFb4191d"},
		['hp'] = {['sizeX'] = 0.3, ['sizeY'] = 1.0 ,['posX'] = 612, ['posY'] = 66, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color'] = "0xFFb4191d"},
		['armour'] = {['sizeX'] = 0.3, ['sizeY'] = 1.0 ,['posX'] = 612, ['posY'] = 44, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color'] = "0xFFe1e1e1"},
		['hungry'] = {['active'] = true, ['sizeX'] = 0.3, ['sizeY'] = 1.0 ,['posX'] = 612, ['posY'] = 55, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color'] = "0xFF608453"},
		['oxygen'] = {['active'] = true, ['sizeX'] = 0.3, ['sizeY'] = 1.0 ,['posX'] = 612, ['posY'] = 55, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color'] = "0xFFabcdef"},
		['sprint'] = {['active'] = true, ['sizeX'] = 0.3, ['sizeY'] = 1.0 ,['posX'] = 612, ['posY'] = 55, ['style'] = 3, ['outline'] = 2, ['align'] = 0, ['color'] = "0xFFdcb413"}
	}
    savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
end

if doesFileExist("moonloader/config/hud.json") then
    local f = io.open("moonloader/config/hud.json")
    config = decodeJson(f:read("*a"))
    f:close()
else
	defalut_config()
end

local servers = { -- список серверов, где работает
	['185.169.134.45'] = true, -- Brainburg
	['185.169.134.166'] = true, -- Prescott
	['185.169.134.172'] = true, -- Kingman
	['185.169.134.44'] = true, -- Chandler
	['185.169.134.171'] = true, -- Glendale
	['185.169.134.109'] = true, -- Surprise
	['185.169.134.61'] = true, -- Red-Rock
	['185.169.134.3'] = true, -- Phoenix
	['185.169.134.5'] = true, -- Saint-Rose
	['185.169.134.107'] = true, -- Yuma
	['185.169.134.4'] = true, -- Tucson
	['185.169.134.43'] = true, -- Scottdale
	['185.169.134.59'] = true, -- Mesa
	['185.169.134.173'] = true, -- Winslow
	['185.169.134.174'] = true, -- Payson
	['80.66.82.191'] = true, -- Gilbert
	['80.66.82.190'] = true -- Show Low
}

function main()

	samp, hud_test = 0, true

	if isSampLoaded() then samp = 1 end
	if isSampLoaded() and isSampfuncsLoaded() then samp = 2 end
	if samp == 2 then
		while not isSampAvailable() do wait(1000) end
		sampRegisterChatCommand('hud', function(arg)
			if arg == nil or arg == "" then
				on = not on
			else
				if arg == "0" then
					active = false
				elseif arg == "1" then
					active = true
				end
			end
		end)
		sampSetClientCommandDescription("hud", string.format(u8:decode"Открывает настройки %s, Файл: %s", thisScript().name, thisScript().filename))

		local ip = sampGetCurrentServerAddress()
		if servers[ip] ~= true then hungry = false else hungry = true end

	end


	files = {}
	local time = get_file_modify_time(string.format("%s/config/hud.json",getWorkingDirectory()))
	if time ~= nil then
	  files[string.format("%s/config/hud.json",getWorkingDirectory())] = time
	end
	lua_thread.create(function() -- отдельный поток для проверки изменений конфига
		while true do wait(274)
			if files ~= nil then  -- by FYP
				for fpath, saved_time in pairs(files) do
					local file_time = get_file_modify_time(fpath)
					if file_time ~= nil and (file_time[1] ~= saved_time[1] or file_time[2] ~= saved_time[2]) then
						print('Reloading "' .. thisScript().name .. '"...')
						thisScript():reload()
						files[fpath] = file_time -- update time
					end
				end
			end
		end
	end)

	mouse = renderLoadTextureFromFileInMemory(memory.strptr(_mouse), #_mouse)

	test = {}
	for i = 1, 6 do
		test[i] = getFreeGxtKey()
	end

	x_mouse, y_mouse = 325.0, 225.0

	while true do

		if samp == 0 or samp == 1 then
			if testCheat("HUD") then on = not on end
			if samp == 1 then hud_test = samp_connect_test() end -- test
		end

		if samp == 2 then
			-- if sampGetGamestate() == 3 then active = true else active = false end
			hud_test = samp_connect_test()
		end

		if active then
			local hud = memory.getint8(0xBA6769)
			local radar = memory.getint8(0xBA6769)
			local radar2 = memory.getint8(0xBAA3FB)
			if hud == 1 and hud == 1 and radar == 1 and not isPauseMenuActive() and hud_test and not hasCutsceneLoaded() and radar2 == 0 then
				if memory.tohex(0x58F47D, 2, false) ~= "90E9" then
					memory.hex2bin('90E9', 0x58F47D, 2) -- OFF MONEY
				end
				if on then
					setPlayerControl(PLAYER_HANDLE, false)
					x_mouse_Pc, y_mouse_PC = getPcMouseMovement()
					x_mouse = x_mouse + x_mouse_Pc
					y_mouse = y_mouse + -y_mouse_PC
					if x_mouse > 640.0 then	x_mouse= 640.0 end
					if 0.0 > x_mouse then x_mouse = 0.0 end
					if y_mouse > 448.0 then y_mouse = 448.0 end
					if 0.0 > y_mouse then y_mouse = 0.0 end
					renderDrawTexture(mouse, convert(x_mouse)[1], convert(y_mouse)[2], 32, 32, 0, -1)
				end

				-----------------POSITION---------------------
				if pos then
					if health_bool then
						config.hp.x, config.hp.y = x_mouse, y_mouse
					end
					if money_bool then
						config.money.x, config.money.y = x_mouse, y_mouse
					end
					if hungry_bool then
						config.hungry.x, config.hungry.y = x_mouse, y_mouse
					end
					if armour_bool then
						config.armour.x, config.armour.y = x_mouse, y_mouse
					end
					if isKeyJustPressed(1) then
						x_mouse, y_mouse = 325.0, 225.0
						printStringNow(RusToGame(u8:decode"Положение сохранено."), 1000)
						savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
						pos, on = false, false
						health_bool, armour_bool, hungry_bool, money_bool = false, false, false, false
					end
				end
				-----------------POSITION---------------------

				-----------------MONEY---------------------
				local cash_real = readMemory(0xB7CE50, 4, false)
				local cash_hud = readMemory(0xB7CE54, 4, false)
				local f = string.find(tostring(cash_hud), "%-")
				local awdaw = f and string.format("%09d", tostring(cash_hud)) or string.format("%08d", tostring(cash_hud))
				local ff = f and '-'..config.money.symbol..separator(awdaw):gsub('%-', '') or ''..config.money.symbol..separator(awdaw):gsub('%-', '')
				if draw_text_test("CLICK", test[1], ff, f and config.money.posX - 8.5 or config.money.posX, config.money.posY, config.money.sizeX, config.money.sizeY, 15, 25, config.money.style, config.money.align, f and config.money.color_minus or config.money.color_plus, 0xFFFFFFFF, config.money.outline, 0xFF000000, 255, 500, false, true, true) then
						money_bool, pos = true, true
				end
				-----------------MONEY---------------------

				-----------------health---------------------
				local health = memory.getfloat(getCharPointer(PLAYER_PED) + 0x540)
				if draw_text_test("CLICK", test[2], ''..math.round(health, 0), config.hp.posX, config.hp.posY, config.hp.sizeX, config.hp.sizeY, 5, 10, config.hp.style, config.hp.align, config.hp.color, 0xFFFFFFFF, config.hp.outline, 0xFF000000, 255, 500, false, true, true) then
					health_bool, pos = true, true
				end

				-----------------health---------------------

				-----------------hungry---------------------
				if hungry and config.hungry.active then
					if draw_text_test("CLICK", test[3], ''..hun, config.hungry.posX, config.hungry.posY, config.hungry.sizeX, config.hungry.sizeY, 10, 10, config.hungry.style, config.hungry.align, config.hungry.color, 0xFFFFFFFF, config.hungry.outline, 0xFF000000, 255, 500, false, true, true) then
						hungry_bool, pos = true, true
					end
				end
				-----------------hungry---------------------

				-----------------armour---------------------
				if getCharArmour(PLAYER_PED) >= 1 then

					local armour = memory.getfloat(getCharPointer(PLAYER_PED) + 0x548)
					if draw_text_test("CLICK", test[4], ''..math.round(armour, 0), config.armour.posX, config.armour.posY, config.armour.sizeX, config.armour.sizeY, 10, 10, config.armour.style, config.armour.align, config.armour.color, 0xFFFFFFFF, config.armour.outline, 0xFF000000, 255, 500, false, true, true) then
						armour_bool, pos = true, true
					end
				end
				-----------------armour---------------------

				-----------------oxygen---------------------
				if config.oxygen.active and isCharInWater(PLAYER_PED) and isCharSwimming(PLAYER_PED) then
					local oxygen = math.floor(memory.getfloat(0xB7CDE0) / 39.97000244)
					if draw_text_test("CLICK", test[5], ''..oxygen, config.oxygen.posX, config.oxygen.posY, config.oxygen.sizeX, config.oxygen.sizeY, 10, 10, config.oxygen.style, config.armour.align, config.oxygen.color, 0xFFFFFFFF, config.oxygen.outline, 0xFF000000, 255, 500, false, true, true) then
						oxygen_bool, pos = true, true
					end
				end
				-----------------oxygen---------------------

				-----------------sprint---------------------
				if config.sprint.active then
					local sprint = math.floor(memory.getfloat(0xB7CDB4) / 31.47000244)
					renderDrawBoxWithBorder(convert(546)[1], isCharSwimming(PLAYER_PED) and convert(56)[2] - 52.5 or convert(56)[2], 185, 20, 0xFF4c3e07, 4, 0xFF000000)
					renderDrawBox(convert(547.2)[1], isCharSwimming(PLAYER_PED) and convert(57.5)[2] - 52.5 or convert(57.5)[2], (177 * sprint) / 100, 11.5, 0xFFdcb413)
					if draw_text_test("CLICK", test[6], ''..sprint, config.sprint.posX, isCharSwimming(PLAYER_PED) and config.sprint.posY - 22 or config.sprint.posY, config.sprint.sizeX, config.sprint.sizeY, 10, 10, config.sprint.style, config.armour.align, config.sprint.color, 0xFFFFFFFF, config.sprint.outline, 0xFF000000, 255, 500, false, true, true) then
						sprint_bool, pos = true, true
					end
				end
				-----------------sprint---------------------
			end
		else
			if memory.tohex(0x58F47D, 2, false) ~= "0F84" then
				memory.hex2bin('0F84', 0x58F47D, 2) -- ON MONEY
			end
		end
		wait(0)
	end
end

function get_file_modify_time(path) -- by FYP
	local handle = ffi.C.CreateFileA(path,
		0x80000000, -- GENERIC_READ
		0x00000001 + 0x00000002, -- FILE_SHARE_READ | FILE_SHARE_WRITE
		nil,
		3, -- OPEN_EXISTING
		0x00000080, -- FILE_ATTRIBUTE_NORMAL
		nil)
	local filetime = ffi.new('FILETIME[3]')
	if handle ~= -1 then
		local result = ffi.C.GetFileTime(handle, filetime, filetime + 1, filetime + 2)
		ffi.C.CloseHandle(handle)
		if result ~= 0 then
			return {tonumber(filetime[2].dwLowDateTime), tonumber(filetime[2].dwHighDateTime)}
		end
	end
	return nil
end

function RusToGame(text)
    local convtbl = {[230]=155,[231]=159,[247]=164,[234]=107,[250]=144,[251]=168,[254]=171,[253]=170,[255]=172,[224]=97,[240]=112,[241]=99,[226]=162,[228]=154,[225]=151,[227]=153,[248]=165,[243]=121,[184]=101,[235]=158,[238]=111,[245]=120,[233]=157,[242]=166,[239]=163,[244]=63,[237]=174,[229]=101,[246]=160,[236]=175,[232]=156,[249]=161,[252]=169,[215]=141,[202]=75,[204]=77,[220]=146,[221]=147,[222]=148,[192]=65,[193]=128,[209]=67,[194]=139,[195]=130,[197]=69,[206]=79,[213]=88,[168]=69,[223]=149,[207]=140,[203]=135,[201]=133,[199]=136,[196]=131,[208]=80,[200]=133,[198]=132,[210]=143,[211]=89,[216]=142,[212]=129,[214]=137,[205]=72,[217]=138,[218]=167,[219]=145}
    local result = {}
    for i = 1, #text do
        local c = text:byte(i)
        result[i] = string.char(convtbl[c] or c)
    end
    return table.concat(result)
end

function draw_text_test(mode, key, str, x, y, sX, sY, offsetX, offsetY, font, align, ARGB, ARGBclick, sO, sARGB, wrapx, centresize, background, proportional, drawbeforefade)
	setGxtEntry(key, str) -- string key, string text
	if mode == "DRAW" then
		setText(sX, sY, font, align, ARGB, sO, sARGB, wrapx, centresize, background, proportional, drawbeforefade)
		displayText(x, y, key)
	end

	if mode == "CLICK" then
		if x_mouse >= x - offsetX and x_mouse <= x + offsetX and y_mouse >= y and y_mouse <= y + offsetY then
			setText(sX, sY, font, align, ARGBclick, sO, sARGB, wrapx, centresize, background, proportional, drawbeforefade)
			displayText(x, y, key)
			if isKeyJustPressed(1) then
				return true
			end
		else
			setText(sX, sY, font, align, ARGB, sO, sARGB, wrapx, centresize, background, proportional, drawbeforefade)
			displayText(x, y, key)
		end
	end
end

function setText(sX, sY, font, align, ARGB, sO, sARGB, wrapx, centresize, background, proportional, drawbeforefade)
	local a, sA = bit.band(bit.rshift(ARGB, 24), 0xFF), bit.band(bit.rshift(sARGB, 24), 0xFF)
	local r, sR = bit.band(bit.rshift(ARGB, 16), 0xFF), bit.band(bit.rshift(sARGB, 16), 0xFF)
	local g, sG = bit.band(bit.rshift(ARGB, 8), 0xFF), bit.band(bit.rshift(sARGB, 8), 0xFF)
	local b, sB = bit.band(ARGB, 0xFF), bit.band(sARGB, 0xFF)
	useRenderCommands(true)
	setTextScale(sX, sY) -- float
	setTextColour(r, g, b, a) -- int
	setTextEdge(sO, sR, sG, sB, sA) -- int
	setTextDropshadow(sO, sR, sG, sB, sA)
	setTextFont(font) -- int
	if align == 3 then
		setTextRightJustify(true) -- bool
	elseif align == 2 then
		setTextCentre(true) -- bool
	elseif align == 1 then
		setTextJustify(true) -- bool
	elseif align == 0 then
		setTextJustify(false)
		setTextCentre(false)
		setTextCentre(false)
	end
	setTextWrapx(wrapx) -- float
	setTextCentreSize(centresize) -- float
	setTextBackground(background) -- bool
	setTextProportional(proportional) -- bool
	setTextDrawBeforeFade(drawbeforefade) -- bool
end

function samp_connect_test()
	local gta_sa = getModuleHandle('gta_sa.exe')
	local hud1 = memory.read(gta_sa + 0x76F053, 1, false)
	if hud1 >= 1 then
		return true
	end
end

function onReceiveRpc(id,bs) -- trefa
    if id == 134 then
        local id_t = raknetBitStreamReadInt16(bs)
        raknetBitStreamIgnoreBits(bs, 104)
        local huns = raknetBitStreamReadFloat(bs) - 549.5
        raknetBitStreamIgnoreBits(bs, 32)
        local color = raknetBitStreamReadInt32(bs)
        raknetBitStreamIgnoreBits(bs, 64)
        local x = raknetBitStreamReadFloat(bs)
        local y = raknetBitStreamReadFloat(bs)
        if x == 549.5 and y == 60 and color == -1436898180 then
            hun = math.floor((huns / 54.5) * 100)
        end
    end
end

function math.round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function convert(xy)
	local gposX, gposY = convertGameScreenCoordsToWindowScreenCoords(xy, xy)
	return {gposX, gposY}
end

function comma_value(n) -- by vrld
	return n:reverse():gsub("(%d%d%d)", "%1%."):reverse():gsub("^%.?", "")
end

function separator(text)
    for S in string.gmatch(text, "%d+") do
		S = string.sub(S, 1, #S)
        text = text.gsub(text, S, comma_value(S))
    end
    return text
end

function onWindowMessage(msg, wparam, lparam)
	if msg == wm.WM_KEYDOWN and wparam == 0x1B and on then
		on, pos = false, false
		consumeWindowMessage(true, false)
	end
end

function onScriptTerminate(s, quitGame)
	if s == thisScript() and not quitGame then
		memory.hex2bin('0F84', 0x58F47D, 2) -- ON MONEY
		setPlayerControl(PLAYER_HANDLE, true)
    end
end


_mouse ="\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x20\x00\x00\x00\x20\x08\x06\x00\x00\x00\x73\x7A\x7A\xF4\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x0B\x12\x00\x00\x0B\x12\x01\xD2\xDD\x7E\xFC\x00\x00\x06\x93\x49\x44\x41\x54\x58\x85\xAD\x97\x5D\x6C\x54\xC7\x15\xC7\xFF\x73\xCE\xDC\xDD\x15\xB6\x77\x37\xAE\xCA\x4B\xDB\x00\x2E\x0F\x3C\x90\x44\x25\x52\xA8\xE4\x42\x1C\x45\x6A\xD2\x58\xD0\x4A\x4D\x53\x70\x85\xFA\xA1\xA4\x0A\x34\x52\x53\x25\xE0\xD2\x86\x36\x90\x26\x34\x21\xC1\x20\xAA\x26\x46\xAA\x21\x28\x01\xA5\x69\x48\xE4\xE0\x04\x48\xC0\x90\x58\x6D\x51\x4B\xD5\x9A\x90\x54\x0A\x14\xF9\x03\x7B\x77\x6D\xEC\xF5\xDA\xFB\xE1\xBD\x77\xE6\xF4\x61\xEF\xDD\x18\xEA\x2F\x5C\x8E\x34\x0F\x3B\x77\x76\xE6\x77\xCF\x9C\xFF\x7F\xE6\xAA\x96\x3F\xB4\x60\x7F\xCB\xCB\x0F\x57\x55\x55\xDE\x0D\xA5\x9E\xB5\xC6\xFE\x1D\x0A\x1A\x80\x87\x39\x06\x11\x21\x97\xCB\xA1\x69\x77\x13\x6E\xBB\xED\x56\x58\x6B\x41\x44\x93\x8E\xD5\xDD\x5D\xDD\xDF\x3E\x73\xE6\xCC\x8B\xD1\x68\x15\xB2\xD9\xDC\x3D\x15\x15\x95\x6B\x8D\xE7\xB5\xF9\x10\x06\x80\xCC\x05\x60\x74\x74\x14\x99\x91\x0C\x00\x40\x64\xEA\x29\xB4\xE3\x38\x0B\x22\x91\x08\x0E\xBC\x72\x60\x7C\xFB\xF6\xDF\x56\x9E\xFD\xDB\xD9\xB7\xE7\xCF\x9F\xBF\xC1\x75\xDD\x97\x80\xB9\x41\x10\x11\xAC\xB5\x60\x9E\xFC\xAD\xAF\x1A\xCB\xCC\x9F\x8E\x8C\xA5\x51\x51\x51\x11\x3A\x71\xF2\x7D\x59\x71\xE7\x0A\xDB\xDF\xDF\xFF\x22\x33\x3F\x65\xAD\xF5\xAC\xB5\xE4\x37\x5C\x6F\x9B\x0D\x35\x29\xA5\x2E\x03\xF0\x2E\x5E\xBC\xA8\xB4\xD6\xF4\xC6\xE1\x3F\xD1\xDA\x86\x35\x5E\x22\x91\x78\x42\x6B\xBD\x5F\x29\xA5\xFC\x0C\xF0\xF5\x64\x61\xB6\x41\x00\xFA\x00\x64\xFA\x2E\xF7\x01\x80\x68\xAD\x55\xCB\xFE\x16\xDD\xB8\xB9\xD1\x4D\x26\x12\xDF\x57\x50\x6D\x44\x14\x45\x69\x2B\x6E\x38\x04\x09\x30\x04\x60\xA0\xBB\xA7\x07\x00\x84\x88\x60\x8C\xC1\xD6\x6D\x4F\x3A\x4D\x7B\x9A\xBC\x74\x26\xFD\x75\xE3\x99\x0F\x99\x79\xA1\x0F\xA1\x6F\x2C\x80\x48\x91\xC0\x89\xFE\xBE\x52\x06\x98\x19\x44\x04\xCF\xF3\xB0\x7E\xFD\x7A\x7D\xF0\xD0\xAB\x5E\xD1\x2B\xDE\x92\xCF\x17\x3A\xB4\xD6\xB7\xA3\x24\xCF\x1B\x06\x41\x22\x02\xCD\xBA\x27\x99\x4C\xA1\x58\x2C\x4A\x69\xCB\x01\xAD\x35\x3C\xCF\xC3\xAA\xD5\xAB\xF4\x3B\xEF\xB6\x99\x58\x3C\xFA\x85\x4C\x26\x73\x5A\x3B\xBA\x7E\x02\x84\xBA\x31\x00\x5A\x77\x0F\x5D\x19\x42\x3A\x9D\xBE\xEA\x61\x00\x71\xC7\xF2\x3B\xF8\xF8\xFB\xC7\x6C\xCD\x97\x6B\xE6\x5D\x19\x1C\x6A\x75\x1C\xE7\xC7\x3E\x04\xFF\xBF\x10\x84\x52\x06\xBA\x46\x47\x47\x91\x4A\xA5\x00\x5C\x6D\x1C\x5A\x6B\x18\x63\x50\x53\x53\x43\xEF\x9D\x38\x2E\x77\xD6\xAD\x94\x64\x32\xD9\xEC\x38\xCE\x36\x1F\x82\xFC\x36\x47\x00\x00\xC4\xD4\x9D\xCF\xE7\xD1\xDF\x9F\x50\xD7\x02\x00\x00\x33\xC3\x18\x83\xEA\xEA\x6A\x3A\xFC\xD6\x61\x5A\xD3\xB0\xC6\x4B\x24\xFA\xB7\x68\xAD\xF7\xF9\x5B\x36\x67\x99\x12\x00\x28\xA8\x7E\x63\x0C\x7A\x7B\x7A\x78\x32\x80\x00\xC2\x5A\x0B\xC7\xD1\x6A\xDF\xFE\x16\xBD\xE9\xE7\x9B\xBC\x64\x32\xF1\x03\xA5\x54\x1B\x11\x55\x62\x8E\x32\x2D\xA5\x4E\x21\x21\x22\x63\xBD\xBD\x97\x83\xB7\x99\x7C\x30\x11\x94\x52\x30\xC6\x60\xDB\x53\xDB\xF4\xCE\xDD\x3B\xBD\xF4\x48\xFA\x1E\x63\x4C\x07\x33\x2F\xC0\x1C\x64\x4A\x00\x20\x22\xC3\xCC\x3C\xD0\xE3\x7B\x41\xA0\x84\xC9\x42\x29\x55\x96\xE9\x86\x0D\x1B\xF4\xAB\x07\x5F\xF1\x8A\x6E\xF1\x56\x5F\xA6\xCB\x70\x9D\x32\x25\x00\x4A\x44\x8A\xCC\xDC\x1F\xB8\xE1\x54\x47\xE7\x44\x88\x40\x21\xAB\xBF\xB9\x5A\xB7\xBD\x73\xC4\xC4\x62\x55\x5F\xCC\x64\x32\xA7\x1D\xC7\x99\x28\xD3\x59\x01\x90\x88\xC0\x71\x9C\x9E\x54\x2A\x09\xD7\x75\x45\x29\x35\xED\x11\x0A\x00\xC6\x18\x90\x22\x14\x8B\x45\x2C\xFF\xEA\x72\x3E\xFA\xDE\x51\xBB\x68\xD1\xC2\x8A\xC1\xC1\xC1\x56\xC7\x71\x1E\x12\x91\x40\x21\x33\x67\x00\x00\xB4\xD6\x5D\x57\x26\xF1\x82\xA9\x82\x99\x41\x4C\x08\x85\x42\x10\x11\x2C\x5E\xBC\x98\x4E\x9C\x3A\x21\x77\xDD\x7D\x97\x0C\x0C\x0C\xEC\x65\xD6\xBF\x82\x88\x9D\x09\x22\xA8\x81\xB2\x17\x24\x93\x49\x04\x7D\xFF\x13\x7E\x57\x76\x2C\x8B\xF6\x93\xED\x38\x7B\xF6\x1F\x38\xFF\xD1\x79\xB9\x74\xE9\x92\xD7\xD3\xD3\xEB\x45\x22\x11\xFB\xC7\xD7\x5F\xB3\xAB\xBF\xB5\xCA\x1D\x1B\x1B\xDD\xCA\xCC\x5F\x01\x30\x2D\x84\x0E\xA6\x25\xA6\xAE\x7C\xAE\x80\x64\x22\xA9\x96\x2E\x5D\x7A\x15\x80\xB5\x16\x41\x61\x2A\x28\x84\x23\x61\x6C\xDA\xD4\x88\x73\x9D\xE7\x10\x8F\xC7\x15\x11\xE9\x70\x28\x0C\xED\x38\x88\xC7\xA3\xC2\xAC\x55\x38\x14\x2E\x5A\x6B\xF3\x33\x65\xB2\x5C\x28\x4A\xA9\xCB\xC6\x78\xE8\xB9\xC6\x0B\x44\xA4\x7C\xA7\x0B\x4E\x4A\xAD\x35\x9E\xDC\xFA\x6B\xBB\xF6\x81\x06\x0A\x87\xC2\x47\x5D\xD7\x3D\x5C\x28\x14\x16\xD8\x5C\xAE\x62\x78\x68\xA8\x92\x99\x63\xAC\xF9\x90\x88\xFC\x1B\xA5\x2D\xB6\x33\x66\x00\x40\x42\x44\x46\x7B\x7B\x7B\xAB\xFC\x3E\x15\x2C\xFC\xC8\x4F\x1E\xC1\xBA\x75\xEB\x50\xFB\xB5\x5A\x04\x05\x5A\x5F\x5F\x8F\x95\x75\x2B\xD1\x71\xBA\x63\x49\x34\x16\x7D\xDD\x5A\x9B\x66\x66\xE5\x38\x8E\x10\x11\x8A\xE3\x45\xE0\xB3\xCB\xCC\x94\x41\xC1\x80\xB2\x17\x74\x97\xBC\x20\x58\xFC\xF8\xB1\xE3\x68\xDE\xDB\x6C\x9B\x5F\x6A\x2E\x4F\x64\xAD\x05\x00\x7A\x7C\xE3\x63\x06\x4A\x16\x02\x68\x14\x11\x88\x48\x58\x44\x58\x44\x18\x0A\x3C\xD3\xE2\x13\x01\x14\x80\x71\x66\x4E\xF4\xF9\xF7\x82\x50\x28\x84\x5C\x2E\x87\x2D\x4F\x6C\x91\xCF\xDF\x34\x5F\x8E\x1C\x69\x93\x0F\x4E\x7F\x50\xBE\x5E\x5B\x6B\x51\x57\x57\x47\xF7\xD5\xD7\x63\x78\x78\x78\x3D\x33\x2F\x02\x50\xF0\xE7\x33\x7E\x9B\x31\x82\xEA\x2C\x7B\x41\x32\x99\x42\x3E\x9F\x17\x00\xD8\xD5\xB4\x5B\x3A\xFF\x79\x4E\x55\x45\x2B\x1F\x35\xAE\xB9\xB8\x63\xC7\xF3\x00\x20\x4A\x95\x8B\x5A\x3D\xBE\xF1\x31\x13\x8E\x84\x63\xD6\xDA\x8D\x41\xDF\x6C\x16\xBE\x16\x40\xF9\xF7\x82\xAE\xC1\x81\x41\xB8\xAE\x8B\x0B\x17\x2E\x98\x3D\xBB\xF7\xA8\xEA\xCF\x55\xB7\x15\x0A\xE3\xBF\x8B\xC5\x63\xFB\xDB\x4F\xB6\xA3\xAD\xAD\xCD\x10\x95\xEA\xC0\x18\x83\x65\xB7\x2F\xA3\xFB\xBF\x73\x3F\x86\x87\x87\x7F\xA4\xB5\xBE\xC5\x7F\xF3\x59\x1F\xCF\xE5\x81\x22\x02\x66\xEE\x1A\x1D\x1B\x45\x2A\x95\x92\xA7\x7F\xF3\x0C\x67\x32\x99\xAC\xD6\xBA\xD1\x7F\xFE\x7B\x47\x3B\xFF\x79\x61\xC7\x0B\xDA\x5A\x6B\x99\x39\x90\xA6\x7A\xF4\x67\x3F\x35\xD1\x58\x34\xEC\xBA\xEE\xE6\xE9\xCE\x91\xE9\x00\x82\x62\xE9\x76\xB4\x83\x67\x9E\xDE\x6E\x8F\xBD\x7B\x0C\xF1\xF8\x4D\xCF\x79\x9E\x77\x1E\x40\xD8\x5A\x9B\x8E\x46\xA3\xCF\xFD\xF5\x2F\x67\x70\xE8\xE0\x21\x01\x00\xCF\xF3\xE0\xBA\x2E\x96\x2C\x59\xC2\x0F\x3E\xF4\xA0\x1D\x19\x19\x79\x80\x99\x97\x62\x06\xF3\x99\x0C\x20\xD0\xE9\x87\x4A\xA9\xCE\x37\xDF\x78\x33\x4C\x44\x7F\x06\xE4\x79\xBF\xBF\x08\x00\xD6\xDA\x7D\xF3\xE6\xCD\xFB\xD7\xAE\xA6\x5D\x9C\xCF\xE7\x6D\x28\x14\x02\x33\xDB\xD6\xD6\x56\xEF\x54\xFB\x29\xAA\xAC\xA8\x74\x8D\x31\xE3\xD7\x95\x01\xFF\x78\x15\x22\x52\x44\x34\x42\x44\x75\xD1\x68\x74\x85\x52\xEA\x5E\x22\xCA\xF9\xFD\x42\x44\x0C\xA0\x58\x55\x55\xB5\xFD\xFC\x47\x1F\xE3\xC0\xCB\x07\x4C\x67\x67\xA7\xF9\xC6\xBD\xF7\xA9\x86\xEF\x7E\x4F\x7F\xF2\xF1\x27\x5D\xE1\x48\xB8\x41\x29\xF5\x29\x95\xC2\xCE\x66\x33\x74\xD1\x75\x91\xCD\x66\x11\x0A\x85\xC4\x18\xA3\x00\xA4\x01\x74\xA0\x54\xCD\x13\x8D\xC4\xF8\xBF\x5F\x8B\x44\x22\x0F\xFF\x62\xF3\x2F\xEB\x0A\x85\x02\x3C\xD7\xEB\x8F\xC7\xE2\xCF\x1A\x6B\xF6\x66\xB3\xD9\x3C\x00\x45\x44\x36\x9B\xCD\xC2\x98\x29\x0D\xF0\x33\x80\x9B\x6F\xFE\x12\x6A\x6B\x6B\x51\x59\x55\x09\x6B\x6D\xE0\x09\x8C\xD2\xB6\x4C\x6A\x24\x0A\xF8\xA1\x15\xD9\x4A\x44\xBD\x44\xB4\xD3\x78\xE6\x0A\x14\xC8\xFF\x9F\x09\x3E\xCF\xA3\xB1\x68\x69\xFC\x34\x85\xF9\x5F\x33\x11\x75\x53\x4F\xAF\xB5\x25\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"
