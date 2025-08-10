local M = {
	stringFuncs = {},
}
--------------------------------------------------------------------------------

local originalLuaStringFuncs = {
	reverse = string.reverse,
	find = string.find,
	gmatch = string.gmatch,
	len = string.len,
	sub = string.sub,
	posOffset = function(_, col)
		return col + 1
	end,
}

local luaUtf8Installed, utf8 = pcall(require, "lua-utf8")
if not luaUtf8Installed then
	M.stringFuncs = originalLuaStringFuncs
else
	for name, _ in pairs(originalLuaStringFuncs) do
		if utf8[name] then M.stringFuncs[name] = utf8[name] end
	end
	M.stringFuncs.posOffset = function(s, col)
		local offset = 1
		for p, _ in utf8.codes(s) do
			if p > col then break end
			offset = offset + 1
		end
		return offset
	end
end

--------------------------------------------------------------------------------
return M
