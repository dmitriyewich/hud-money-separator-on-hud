script_name("HUD") 
script_author("imring(идея), trefa(hungry), dmitriyewich")
script_description("Regular numbers on hud + seperator of money in dots on hud.")
script_url("https://vk.com/dmitriyewichmods")
script_dependencies("ffi", "memory", "vkeys")
script_properties('work-in-pause', 'forced-reloading-only')
script_version("1.4")
script_version_number(14)

require 'lib.moonloader'
local lmemory, memory = pcall(require, 'memory') assert(lmemory, 'Library \'memory\' not found.')
local lkey, key = pcall(require, 'vkeys') assert(lkey, 'Library \'vkeys\' not found.')
local lffi, ffi = pcall(require, 'ffi') assert(lffi, 'Library \'ffi\' not found.')
local lencoding, encoding = pcall(require, 'encoding') assert(lencoding, 'Library \'encoding\' not found.')
encoding.default = 'CP1251'
u8 = encoding.UTF8
CP1251 = encoding.CP1251

local function isarray(t, emptyIsObject) -- by Phrogz
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

local function neatJSON(value, opts) -- by Phrogz
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
    return (neatJSON(config, {sort = true, wrap = 40}))
end 
local config = {}

if doesFileExist("moonloader/config/hud.json") then
    local f = io.open("moonloader/config/hud.json")
    config = decodeJson(f:read("*a"))
    f:close()
else
	config = {
		["hungry"] = {
			["id"] = 1571,
			["style"] = 3,
			["outline"] = 2,
			["x"] = 631, 
			["y"] = 54, 
			["SizeX"] = 0.32, 
			["SizeY"] = 0.78,
			["rgb"] = 'FFFFFF'},
		["hp"] = {
			["id"] = 2090,
			["style"] = 3,
			["outline"] = 2,
			["x"] = 631,
			["y"] = 66, 
			["SizeX"] = 0.32,
			["SizeY"] = 0.78,
			["rgb"] = 'FFFFFF'},
		["armour"] = {
			["id"] = 1573, 
			["style"] = 3,
			["outline"] = 2,
			["x"] = 631, 
			["y"] = 43, 
			["SizeX"] = 0.32, 
			["SizeY"] = 0.78, 
			["rgb"] = 'FFFFFF'},
		["money"] = {
			["id"] = 2091,
			["style"] = 3,
			["outline"] = 2,
			["x"] = 608, 
			["y"] = 77, 
			["SizeX"] = 0.555, 
			["SizeY"] = 2.2, 
			["rgbplus"] = '36662c', 
			["rgbminus"] = 'b4191d'};
	}
    savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
end


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
	['185.169.134.174'] = true -- Payson
}

local on_off_text = ''

local active=true
hun = 54.5
hungry = false
posHUN = false
posHP = false
posARMOUR = false
posMONEY = false

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
	files = {}
	local time = get_file_modify_time(string.format("%s/config/hud.json",getWorkingDirectory()))
	if time ~= nil then
	  files[string.format("%s/config/hud.json",getWorkingDirectory())] = time
	end
	while not sampIsLocalPlayerSpawned() do wait(0) end
	local ip = sampGetCurrentServerAddress()
	if servers[ip] ~= true then hungry = false else hungry = true end	

	font = renderCreateFont('Tahoma', 13, 5)
	resX, resY = getScreenResolution()
	if active then
		editMoneyBarSize(0.0, 0.0)
	end

    sampRegisterChatCommand("hudmenu", function()
		lua_thread.create(function()
			wait(74)
			click_true = not click_true
		end)
    end)
	sampSetClientCommandDescription("hudmenu", string.format(u8:decode"Открывает настройки %s, Файл: %s", thisScript().name, thisScript().filename))
    sampRegisterChatCommand("hudhp", function(arg)
		local rgb_hudhp, style_hudhp, outline_hudhp = string.match(arg, "(.+) (.+) (.+)")
		if rgb_hudhp == nil and style_hudhp == nil and outline_hudhp == nil then 
			msg_rso()
			lua_thread.create(function()
			wait(74)
			sampSetChatInputText('/hudhp '..config.hp.rgb..' '..config.hp.style..' '..config.hp.outline)
			sampSetChatInputEnabled(true)
			end)
		elseif rgb_hudhp ~= nil and style_hudhp ~= nil and outline_hudhp ~= nil then 
			config.hp.rgb = rgb_hudhp
			config.hp.style = style_hudhp
			config.hp.outline = outline_hudhp
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
    end)
    sampRegisterChatCommand("hudar", function(arg)
		local rgb_hudar, style_hudar, outline_hudar = string.match(arg, "(.+) (.+) (.+)")
		if rgb_hudar == nil and style_hudar == nil and outline_hudar == nil then 
			msg_rso()
			lua_thread.create(function()
			wait(74)
			sampSetChatInputText('/hudar '..config.armour.rgb..' '..config.armour.style..' '..config.armour.outline)
			sampSetChatInputEnabled(true)
			end)
		elseif rgb_hudar ~= nil and style_hudar ~= nil and outline_hudar ~= nil then 
			config.armour.rgb = rgb_hudar
			config.armour.style = style_hudar
			config.armour.outline = outline_hudar
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
    end)
    sampRegisterChatCommand("hudmoney", function(arg)
		local rgb_hudmoney, style_hudmoney, outline_hudmoney = string.match(arg, "(.+) (.+) (.+)")
		if rgb_hudmoney == nil and style_hudmoney == nil and outline_hudmoney == nil then 
			msg_rso()
			lua_thread.create(function()
			wait(74)
			sampSetChatInputText('/hudhp '..config.money.rgbplus..' '..config.money.style..' '..config.money.outline)
			sampSetChatInputEnabled(true)
			end)
		elseif rgb_hudmoney ~= nil and style_hudmoney ~= nil and outline_hudmoney ~= nil then 
			config.money.rgbplus = rgb_hudmoney
			config.money.style = style_hudmoney
			config.money.outline = outline_hudmoney
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
    end)
    sampRegisterChatCommand("hudhun", function(arg)
		local rgb_hudhun, style_hudhun, outline_hudhun = string.match(arg, "(.+) (.+) (.+)")
		if rgb_hudhun == nil and style_hudhun == nil and outline_hudhun == nil then 
			msg_rso()
			lua_thread.create(function()
			wait(74)
			sampSetChatInputText('/hudhp '..config.hungry.rgb..' '..config.hungry.style..' '..config.hungry.outline)
			sampSetChatInputEnabled(true)
			end)
		elseif rgb_hudhun ~= nil and style_hudhun ~= nil and outline_hudhun ~= nil then 
			config.hungry.rgb = rgb_hudhun
			config.hungry.style = style_hudhun
			config.hungry.outline = outline_hudhun
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
    end)

	while true do wait(0)
		if active then
		hud = memory.getint8(0xBA6769)
		Textdraw_posX_money, Textdraw_posY_money = sampTextdrawGetPos(config.money.id)
		if sampTextdrawIsExists(config.money.id) and math.round(Textdraw_posY_money, 3) ~= config.money.y and math.round(Textdraw_posX_money, 3) ~= config.money.x and not posHUN and not posHP and not posARMOUR and not posMONEY then 
			math.randomseed(os.clock())
			config.money.id = math.random(1, 500)	
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
		Textdraw_posX_hp, Textdraw_posY_hp = sampTextdrawGetPos(config.hp.id)
		if sampTextdrawIsExists(config.hp.id) and math.round(Textdraw_posX_hp, 3) ~= config.hp.x and math.round(Textdraw_posY_hp, 3) ~= config.hp.y and not posHUN and not posHP and not posARMOUR and not posMONEY then 
			math.randomseed(os.clock())
			config.hp.id = math.random(501, 1000)
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
		Textdraw_posX_armour, Textdraw_posY_armour = sampTextdrawGetPos(config.armour.id)
		if sampTextdrawIsExists(config.armour.id) and math.round(Textdraw_posX_armour, 3) ~= config.armour.x and math.round(Textdraw_posY_armour, 3) ~= config.armour.y and not posHUN and not posHP and not posARMOUR and not posMONEY then 
			math.randomseed(os.clock())
			config.armour.id = math.random(1001, 1500)
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
		Textdraw_posX_hungry, Textdraw_posY_hungry = sampTextdrawGetPos(config.hungry.id)
		if sampTextdrawIsExists(config.hungry.id) and math.round(Textdraw_posX_hungry, 3) ~= config.hungry.x and math.round(Textdraw_posY_hungry, 3) ~= config.hungry.y and not posHUN and not posHP and not posARMOUR and not posMONEY then 
			math.randomseed(os.clock())
			config.hungry.id = math.random(1501, 2304)
			savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
		end
		gamestate = sampGetGamestate()
		if hud == 1 and gamestate == 3 then
				
				while not isPlayerPlaying(PLAYER_HANDLE) do wait(0) end
					sampTextdrawCreate(config.hp.id, '', config.hp.x, config.hp.y)
					sampTextdrawSetString(config.hp.id, getCharHealth(PLAYER_PED))
					sampTextdrawSetLetterSizeAndColor(config.hp.id, config.hp.SizeX, config.hp.SizeY, '0xFF'..config.hp.rgb)
					sampTextdrawSetOutlineColor(config.hp.id, config.hp.outline, 0xFF000000)
					sampTextdrawSetAlign(config.hp.id, 3)
					sampTextdrawSetStyle(config.hp.id, config.hp.style)
				if hungry == true then
					sampTextdrawCreate(config.hungry.id, '', config.hungry.x, config.hungry.y)
					sampTextdrawSetString(config.hp.id, math.floor((hun / 54.5) * 100))
					sampTextdrawSetLetterSizeAndColor(config.hungry.id, config.hungry.SizeX, config.hungry.SizeY, '0xFF'..config.hungry.rgb)
					sampTextdrawSetOutlineColor(config.hungry.id, config.hungry.outline, 0xFF000000)
					sampTextdrawSetAlign(config.hungry.id, 3)
					sampTextdrawSetStyle(config.hungry.id, config.hungry.style)
				end
				if getCharArmour(PLAYER_PED) > 0 then
					sampTextdrawCreate(config.armour.id, '', config.armour.x, config.armour.y)
					sampTextdrawSetString(config.armour.id, getCharArmour(PLAYER_PED))
					sampTextdrawSetLetterSizeAndColor(config.armour.id, config.armour.SizeX, config.armour.SizeY, '0xFF'..config.armour.rgb)
					sampTextdrawSetOutlineColor(config.armour.id, config.armour.outline, 0xFF000000)
					sampTextdrawSetAlign(config.armour.id, 3)
					sampTextdrawSetStyle(config.armour.id, config.armour.style)
				else
					sampTextdrawDelete(config.armour.id)
				end
				if separator(getPlayerMoney(PLAYER_HANDLE)):find('%-') then
					sampTextdrawCreate(config.money.id, '', config.money.x, config.money.y)
					sampTextdrawSetString(config.money.id, '$'..separator(getPlayerMoney(PLAYER_HANDLE)))
					sampTextdrawSetLetterSizeAndColor(config.money.id, config.money.SizeX, config.money.SizeY, '0xFF'..config.money.rgbminus)
					sampTextdrawSetOutlineColor(config.money.id, config.money.outline, 0xFF000000)
					sampTextdrawSetAlign(config.money.id, 3)
					sampTextdrawSetStyle(config.money.id, config.money.style)
				else
					sampTextdrawCreate(config.money.id, '', config.money.x, config.money.y)
					sampTextdrawSetString(config.money.id, '$'..separator(getPlayerMoney(PLAYER_HANDLE)))
					sampTextdrawSetLetterSizeAndColor(config.money.id, config.money.SizeX, config.money.SizeY, '0xFF'..config.money.rgbplus)
					sampTextdrawSetOutlineColor(config.money.id, config.money.outline, 0xFF000000)
					sampTextdrawSetAlign(config.money.id, 3)
					sampTextdrawSetStyle(config.money.id, config.money.style)
				end
			else --if hud ~= 1 and 
				sampTextdrawDelete(config.money.id)
				sampTextdrawDelete(config.hp.id)
				sampTextdrawDelete(config.armour.id)
				sampTextdrawDelete(config.hungry.id)
			end

			if posHUN then
				local int_posX, int_posY = getCursorPos()
				local gposX, gposY = convertWindowScreenCoordsToGameScreenCoords(int_posX, int_posY)
				config.hungry.x,config.hungry.y = gposX, gposY
				local delta = getMousewheelDelta()
				config.hungry.SizeX, config.hungry.SizeY = (config.hungry.SizeX + (delta / 100)), (config.hungry.SizeY + (delta / 100))
				renderFontDrawText(font, 'Size X:'..config.hungry.SizeX..' Size Y:'..config.hungry.SizeY, int_posX - renderGetFontDrawTextLength(font, 'Size X:'..config.hungry.SizeX..' Size Y:'..config.hungry.SizeY), int_posY + 25, '0xFFAAAAAA')
				renderFontDrawText(font, 'Pos X:'..math.ceil(config.hungry.x)..' Pos Y:'..math.ceil(config.hungry.y), int_posX - renderGetFontDrawTextLength(font, 'Size X:'..math.ceil(config.hungry.x)..' Size Y:'..math.ceil(config.hungry.y)), int_posY + 50, '0xFFAAAAAA')
				if wasKeyPressed(key.VK_LEFT) then
					config.hungry.SizeX = config.hungry.SizeX - 0.01
				end
				if wasKeyPressed(key.VK_UP) then
					config.hungry.SizeY = config.hungry.SizeY + 0.01
				end
				if wasKeyPressed(key.VK_RIGHT) then
					config.hungry.SizeX = config.hungry.SizeX + 0.01
				end
				if wasKeyPressed(key.VK_DOWN) then
					config.hungry.SizeY = config.hungry.SizeY - 0.01
				end
				if wasKeyPressed(key.VK_RETURN) then
					sampSetCursorMode(0)
					sampAddChatMessage(u8:decode"Сохранено.", -1)
					posHUN = false
					lockPlayerControl(false)
					savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
				end
			end
			if posHP then
				local int_posX, int_posY = getCursorPos()
				local gposX, gposY = convertWindowScreenCoordsToGameScreenCoords(int_posX, int_posY)
				config.hp.x,config.hp.y = gposX, gposY
				local delta = getMousewheelDelta()
				config.hp.SizeX, config.hp.SizeY = (config.hp.SizeX + (delta / 100)), (config.hp.SizeY + (delta / 100))
				renderFontDrawText(font, 'Size X:'..config.hp.SizeX..' Size Y:'..config.hp.SizeY, int_posX - renderGetFontDrawTextLength(font, 'Size X:'..config.hp.SizeX..' Size Y:'..config.hp.SizeY), int_posY + 25, '0xFFAAAAAA')
				renderFontDrawText(font, 'Pos X:'..math.ceil(config.hp.x)..' Pos Y:'..math.ceil(config.hp.y), int_posX - renderGetFontDrawTextLength(font, 'Size X:'..math.ceil(config.hp.x)..' Size Y:'..math.ceil(config.hp.y)), int_posY + 50, '0xFFAAAAAA')
				if wasKeyPressed(key.VK_LEFT) then
					config.hp.SizeX = config.hp.SizeX - 0.01
				end
				if wasKeyPressed(key.VK_UP) then
					config.hp.SizeY = config.hp.SizeY + 0.01
				end
				if wasKeyPressed(key.VK_RIGHT) then
					config.hp.SizeX = config.hp.SizeX + 0.01
				end
				if wasKeyPressed(key.VK_DOWN) then
					config.hp.SizeY = config.hp.SizeY - 0.01
				end
				if wasKeyPressed(key.VK_RETURN) then
					sampSetCursorMode(0)
					sampAddChatMessage(u8:decode"Сохранено.", -1)
					posHP = false
					lockPlayerControl(false)
					savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
				end
			end
			if posARMOUR then
				local int_posX, int_posY = getCursorPos()
				local gposX, gposY = convertWindowScreenCoordsToGameScreenCoords(int_posX, int_posY)
				config.armour.x,config.armour.y = gposX, gposY
				local delta = getMousewheelDelta()
				config.armour.SizeX, config.armour.SizeY = (config.armour.SizeX + (delta / 100)), (config.armour.SizeY + (delta / 100))
				renderFontDrawText(font, 'Size X:'..config.armour.SizeX..' Size Y:'..config.armour.SizeY, int_posX - renderGetFontDrawTextLength(font, 'Size X:'..config.armour.SizeX..' Size Y:'..config.armour.SizeY), int_posY + 25, '0xFFAAAAAA')
				renderFontDrawText(font, 'Pos X:'..math.ceil(config.armour.x)..' Pos Y:'..math.ceil(config.armour.y), int_posX - renderGetFontDrawTextLength(font, 'Size X:'..math.ceil(config.armour.x)..' Size Y:'..math.ceil(config.armour.y)), int_posY + 50, '0xFFAAAAAA')
				if wasKeyPressed(key.VK_LEFT) then
					config.armour.SizeX = config.armour.SizeX - 0.01
				end
				if wasKeyPressed(key.VK_UP) then
					config.armour.SizeY = config.armour.SizeY + 0.01
				end
				if wasKeyPressed(key.VK_RIGHT) then
					config.armour.SizeX = config.armour.SizeX + 0.01
				end
				if wasKeyPressed(key.VK_DOWN) then
					config.armour.SizeY = config.armour.SizeY - 0.01
				end
				if wasKeyPressed(key.VK_RETURN) then
					sampSetCursorMode(0)
					sampAddChatMessage(u8:decode"Сохранено.", -1)
					posARMOUR = false
					lockPlayerControl(false)
					savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
				end
			end
			if posMONEY then
				local int_posX, int_posY = getCursorPos()
				local gposX, gposY = convertWindowScreenCoordsToGameScreenCoords(int_posX, int_posY)
				config.money.x,config.money.y = gposX, gposY
				local delta = getMousewheelDelta()
				config.money.SizeX, config.money.SizeY = (config.money.SizeX + (delta / 100)), (config.money.SizeY + (delta / 100))
				renderFontDrawText(font, 'Size X:'..config.money.SizeX..' Size Y:'..config.money.SizeY, int_posX - renderGetFontDrawTextLength(font, 'Size X:'..config.money.SizeX..' Size Y:'..config.money.SizeY), int_posY + 25, '0xFFAAAAAA')
				renderFontDrawText(font, 'Pos X:'..math.ceil(config.money.x)..' Pos Y:'..math.ceil(config.money.y), int_posX - renderGetFontDrawTextLength(font, 'Size X:'..math.ceil(config.money.x)..' Size Y:'..math.ceil(config.money.y)), int_posY + 50, '0xFFAAAAAA')
				if wasKeyPressed(key.VK_LEFT) then
					config.money.SizeX = config.money.SizeX - 0.01
				end
				if wasKeyPressed(key.VK_UP) then
					config.money.SizeY = config.money.SizeY + 0.01
				end
				if wasKeyPressed(key.VK_RIGHT) then
					config.money.SizeX = config.money.SizeX + 0.01
				end
				if wasKeyPressed(key.VK_DOWN) then
					config.money.SizeY = config.money.SizeY - 0.01
				end
				if wasKeyPressed(key.VK_RETURN) then
					sampSetCursorMode(0)
					sampAddChatMessage(u8:decode"Сохранено.", -1)
					posMONEY = false
					lockPlayerControl(false)
					savejson(convertTableToJsonString(config), "moonloader/config/hud.json")
				end
			end
		end
		if click_true then
			sampSetCursorMode(3)
			control = true
			local HP_pos = click(font, u8:decode'Изменить позицию/размер ХП', (resX - renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП')) / 2, resY / 2 + 25, '0xFFAAAAAA')
			if HP_pos == 2 then
				lua_thread.create(function()
					click_true = false
					msg_settings()
					wait(74)
					lockPlayerControl(true)
					sampSetCursorMode(3)
					posHP = true
				end)
			end
			local HP_color = click(font, u8:decode'[Цвет]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Цвет]')) / 2 + (renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП') / 2.4), resY / 2 + 25, '0xAA'..config.hp.rgb)
			if HP_color == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhp '..config.hp.rgb..' '..config.hp.style..' '..config.hp.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(7, 13)
				end)
			end
			local HP_style = click(font, u8:decode'[Стиль]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]'))) / 1.99), resY / 2 + 25, '0xAA'..config.hp.rgb)
			if HP_style == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhp '..config.hp.rgb..' '..config.hp.style..' '..config.hp.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(14, 15)
				end)
			end
			local HP_outline = click(font, u8:decode'[Обводка]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]') + (renderGetFontDrawTextLength(font, u8:decode'[Стиль]')))) / 1.7), resY / 2 + 25, '0xAA'..config.hp.rgb)
			if HP_outline == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhp '..config.hp.rgb..' '..config.hp.style..' '..config.hp.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(16, string.len(sampGetChatInputText()))
				end)
			end
			local ARMOUR_pos = click(font, u8:decode'Изменить позицию/размер брони', (resX - renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер брони')) / 2, resY / 2, '0xFFAAAAAA')
			if ARMOUR_pos == 2 then
				lua_thread.create(function()
					click_true = false
					msg_settings()
					wait(74)
					sampSetCursorMode(3)
					lockPlayerControl(true)
					posARMOUR = true
				end)
			end
			local ARMOUR_color = click(font, u8:decode'[Цвет]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Цвет]')) / 2 + (renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер брони') / 2.4), resY / 2, '0xAA'..config.armour.rgb)
			if ARMOUR_color == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudar '..config.armour.rgb..' '..config.armour.style..' '..config.armour.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(7, 13)
				end)
			end
			local ARMOUR_style = click(font, u8:decode'[Стиль]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]'))) / 1.85), resY / 2, '0xAA'..config.armour.rgb)
			if ARMOUR_style == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudar '..config.armour.rgb..' '..config.armour.style..' '..config.armour.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(14, 15)
				end)
			end
			local ARMOUR_outline = click(font, u8:decode'[Обводка]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер ХП') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]') + (renderGetFontDrawTextLength(font, u8:decode'[Стиль]')))) / 1.62), resY / 2, '0xAA'..config.armour.rgb)
			if ARMOUR_outline == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudar '..config.armour.rgb..' '..config.armour.style..' '..config.armour.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(16, string.len(sampGetChatInputText()))
				end)
			end
			local MONEY_pos = click(font, u8:decode'Изменить позицию/размер денег', (resX - renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер денег')) / 2, resY / 2 - 25, '0xFFAAAAAA')
			if MONEY_pos == 2 then
				lua_thread.create(function()
					click_true = false
					msg_settings()
					wait(74)
					lockPlayerControl(true)
					sampSetCursorMode(3)
					posMONEY = true
				end)
			end
			local MONEY_color = click(font, u8:decode'[Цвет]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Цвет]')) / 2 + (renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер денег') / 2.4), resY / 2 - 25, '0xAA'..config.money.rgbplus)
			if MONEY_color == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudmoney '..config.money.rgbplus..' '..config.money.style..' '..config.money.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(10, 16)
				end)
			end
			local MONEY_style = click(font, u8:decode'[Стиль]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер денег') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]'))) / 1.99), resY / 2 - 25, '0xAA'..config.money.rgbplus)
			if MONEY_style == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudmoney '..config.money.rgbplus..' '..config.money.style..' '..config.money.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(14, 15)
				end)
			end
			local MONEY_outline = click(font, u8:decode'[Обводка]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер денег') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]') + (renderGetFontDrawTextLength(font, u8:decode'[Стиль]')))) / 1.71), resY / 2 - 25, '0xAA'..config.money.rgbplus)
			if MONEY_outline == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudmoney '..config.money.rgbplus..' '..config.money.style..' '..config.money.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(16, string.len(sampGetChatInputText()))
				end)
			end
			if hungry then
			local HUN_pos = click(font, u8:decode'Изменить позицию/размер сытости', (resX - renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер сытости')) / 2, resY / 2 - 50, '0xFFAAAAAA')
			if HUN_pos == 2 then
				lua_thread.create(function()
					click_true = false
					msg_settings()
					wait(74)
					lockPlayerControl(true)
					sampSetCursorMode(3)
					posHUN = true
				end)
			end
			local HUN_color = click(font, u8:decode'[Цвет]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Цвет]')) / 2 + (renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер сытости') / 2.4), resY / 2 - 50, '0xAA'..config.hungry.rgb)
			if HUN_color == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhun '..config.hungry.rgb..' '..config.hungry.style..' '..config.hungry.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(8, 14)
				end)
			end
			local HUN_style = click(font, u8:decode'[Стиль]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер сытости') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]'))) / 1.99), resY / 2 - 50, '0xAA'..config.hungry.rgb)
			if HUN_style == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhun '..config.hungry.rgb..' '..config.hungry.style..' '..config.hungry.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(14, 15)
				end)
			end
			local HUN_outline = click(font, u8:decode'[Обводка]', (resX + renderGetFontDrawTextLength(font, u8:decode'[Стиль]')) / 2 + ((renderGetFontDrawTextLength(font, u8:decode'Изменить позицию/размер сытости') + (renderGetFontDrawTextLength(font, u8:decode'[Цвет]') + (renderGetFontDrawTextLength(font, u8:decode'[Стиль]')))) / 1.71), resY / 2 - 50, '0xAA'..config.hungry.rgb)
			if HUN_outline == 2 then
				lua_thread.create(function()
					click_true = false
					msg_rso()
					sampSetChatInputText('/hudhun '..config.hungry.rgb..' '..config.hungry.style..' '..config.hungry.outline)
					sampSetChatInputEnabled(true)
					sampSetChatInputCursor(16, string.len(sampGetChatInputText()))
				end)
			end
			end
			local reload_this = click(font, u8:decode'Перезапустить скрипт', (resX - renderGetFontDrawTextLength(font, u8:decode'Перезапустить скрипт')) / 2, resY / 2 - 75, '0xFFAAAAAA')
			if reload_this == 2 then
				thisScript():reload()
			end
			if active then
				on_off_text = u8:decode'Выключить HUD'
			else
				on_off_text = u8:decode'Включить HUD'
			end	
			local on_off = click(font, on_off_text, (resX - renderGetFontDrawTextLength(font, on_off_text)) / 2, resY / 2 - 100, '0xFFAAAAAA')
			if on_off == 2 then
				active = not active
				if active then
					editMoneyBarSize(0.0, 0.0)
				else
					editMoneyBarSize(0.55, 1.1)
					sampTextdrawDelete(config.money.id)
					sampTextdrawDelete(config.hp.id)
					sampTextdrawDelete(config.armour.id)
					sampTextdrawDelete(config.hungry.id)
				end
			end
		end
		if control and wasKeyPressed(key.VK_ESCAPE) then
			control = false
			click_true = false
			sampSetCursorMode(0)
		end
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
end

math.round = function(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function editMoneyBarSize(sizeX, sizeY)
    local X = memory.getuint32(0x58F564, true)
    local Y = memory.getuint32(0x58F54E, true)
    memory.setfloat(X, sizeX)
    memory.setfloat(Y, sizeY)
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

function explode_argb(argb)
  local a = bit.band(bit.rshift(argb, 24), 0xFF)
  local r = bit.band(bit.rshift(argb, 16), 0xFF)
  local g = bit.band(bit.rshift(argb, 8), 0xFF)
  local b = bit.band(argb, 0xFF)
  return a, r, g, b
end

function msg_settings()
	sampAddChatMessage(u8:decode"Общий размер {ff6666}Колесико мыши{ffffff}, Частный размер {ff6666}Стрелки клавитуры{ffffff}.", -1)
	sampAddChatMessage(u8:decode"Позиция {ff6666}Мышь{ffffff}.", -1)
	sampAddChatMessage(u8:decode"Для сохранения настроек нажмите {ff6666}Enter{ffffff}.", -1)
end
function msg_rso()
sampAddChatMessage(u8:decode'Введите цвет в формате {ff0000}R{00ff00}G{0000ff}B{FFFFFF}, Стиль(1-3), Размер обводки', -1)
end
function click(font, text, posX, posY, color)
	renderFontDrawText(font, text, posX, posY, color)
	local textLenght = renderGetFontDrawTextLength(font, text)
	local textHeight = renderGetFontDrawHeight(font)
	local curX, curY = getCursorPos()
	if curX >= posX and curX <= posX + textLenght and curY >= posY and curY <= posY + textHeight then
		renderFontDrawText(font, text, posX, posY, '0xFFFFFFFF')
		if isKeyJustPressed(1) then
			return 2
		else
			return 1
		end
	else
		return 0
	end
end

local point = '.'
function comma_value(n)
	local num = string.match(n,'(%d+)')
	local result = num:reverse():gsub('%d%d%d','%1'..point):reverse()
	if string.char(result:byte(1)) == point then result = result:sub(2) end
	return result
end

function separator(text)
		for S in string.gmatch(text, "%d+") do
			S = string.sub(S, 0, #S)
	    	local replace = comma_value(S)
	    	text = string.gsub(text, S, replace)
	    end
	return text
end

function sampSetChatInputCursor(start, finish) -- https://www.blast.hk/threads/13380/post-198637
    local finish = finish or start
    local start, finish = tonumber(start), tonumber(finish)
    local mem = require 'memory'
    local chatInfoPtr = sampGetInputInfoPtr()
    local chatBoxInfo = getStructElement(chatInfoPtr, 0x8, 4)
    mem.setint8(chatBoxInfo + 0x11E, start)
    mem.setint8(chatBoxInfo + 0x119, finish)
    return true
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
            hun = huns
        end
    end
end

function onScriptTerminate(s, quitGame)
	if s == thisScript() and not quitGame then
		if active then
			editMoneyBarSize(0.0, 0.0)
			sampTextdrawDelete(config.money.id)
			sampTextdrawDelete(config.hp.id)
			sampTextdrawDelete(config.armour.id)
			sampTextdrawDelete(config.hungry.id)
			else
			editMoneyBarSize(0.55, 1.1)
		end
		sampSetCursorMode(0)
    end
end