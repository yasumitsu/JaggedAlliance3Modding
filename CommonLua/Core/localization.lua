---
--- Specifies a comment that indicates the localization system should ignore the following code block.
--- This comment is used to mark code that should not be localized, such as code that generates localization keys or other metadata.
---
--- @field localization_ignore_header string The header comment that indicates a block of code should be ignored by the localization system.
---
localization_ignore_header = "-- [[localization-ignore]]"

-- command line tool shield
---
--- Provides access to the global `const.TagLookupTable` table, which is used for looking up tag information.
---
--- @type table
--- @field TagLookupTable table The global table that stores tag lookup information.
---
const.TagLookupTable = const.TagLookupTable or {}
local TagLookupTable = const.TagLookupTable
local type = type
local getmetatable = getmetatable
local setmetatable = setmetatable

---
--- Stores a table of random localization IDs.
---
RandomLocIds = {}

---
--- Specifies whether errors should be ignored when using the localization system.
---
--- @field TIgnoreErrors boolean If true, errors will be ignored when using the localization system.
---
local TIgnoreErrors = false

---
--- Converts a localization ID to a light userdata value that can be used to represent the localization ID.
---
--- @param id number The localization ID to convert.
--- @return lightuserdata The light userdata value representing the localization ID.
---
function LocIDToLightUserdata(id)
    return id and LightUserData(bor(id, locId_sig))
end
local locId_sig = shift(0xff, 56)
local locId_mask = bnot(locId_sig)
local function LocIDToLightUserdata(id)
	return id and LightUserData(bor(id, locId_sig))
end

---
--- Converts a light userdata value back to a localization ID.
---
--- @param value lightuserdata The light userdata value to convert.
--- @return number|nil The localization ID, or nil if the value is not a valid localization ID.
---
function LightUserdataToLocId(value)
    value = LightUserDataValue(value)
    if value and band(value, locId_sig) == locId_sig then
        return band(value, locId_mask)
    end
end
local function LightUserdataToLocId(value)
	value = LightUserDataValue(value)
	if value and band(value, locId_sig) == locId_sig then
		return band(value, locId_mask)
	end
end

-- checks for any object that may be used where a localized string is expected:
--  1. Ts
--  2. concatenated Ts
--  3. strings that have only tags and punctuation
---
--- Checks if a given value is compatible with the localization system.
---
--- @param T any The value to check for compatibility.
--- @return boolean True if the value is compatible, false otherwise.
---
function IsTCompatible(T)
    return true
end
local function IsTCompatible()
	return true
end
---
--- Checks if a given value is compatible with the localization system.
---
--- @param T any The value to check for compatibility.
--- @return boolean True if the value is compatible, false otherwise.
---
function IsTCompatible(T)
    return
        LightUserdataToLocId(T) or
        type(T) == "number" or
        type(T) == "function" or
        type(T) == "string" and IsTagsAndPunctuation(T) or
        type(T) == "table" and (getmetatable(T) == TMeta or getmetatable(T) == TConcatMeta)
end
if Platform.debug then
	IsTCompatible = function(T)
		return
			LightUserdataToLocId(T) or
			type(T) == "number" or
			type(T) == "function" or
			type(T) == "string" and IsTagsAndPunctuation(T) or
			type(T) == "table" and (getmetatable(T) == TMeta or getmetatable(T) == TConcatMeta)
	end
end

-- checks whether the value is a localized string produced by the T function (or a UserText, which is compatible with Ts)
---
--- Checks if a given value is compatible with the localization system.
---
--- @param T any The value to check for compatibility.
--- @return boolean True if the value is compatible, false otherwise.
---
function IsT(T)
	return
		T == "" or
		LightUserdataToLocId(T) or
		type(T) == "table" and (getmetatable(T) == TMeta or getmetatable(T) == TConcatMeta)
end

---
--- Checks if a given value is a UserText object.
---
--- @param T any The value to check.
--- @return boolean True if the value is a UserText object, false otherwise.
---
function IsUserText(T)
	return type(T) == "table" and getmetatable(T) == TMeta and T._language ~= nil
end

-- T = "" or userdata or { string,...} or { id, string,...}
---
--- Gets the ID of a localized string.
---
--- @param T any The localized string or table containing the localized string.
--- @return number|boolean The ID of the localized string, or false if the input is an empty string.
---
function TGetID(T)
	if T == "" then
		return false
	end
	local value = LightUserdataToLocId(T)
	if value then
		return value
	end
	if type(T[1]) == "number" then
		return T[1]
	elseif type(T[1]) == "table" then
		return TGetID(T[1])
	else
		return LightUserdataToLocId(T[1])
	end
end

-- T = "" or { string,...} or { id, string,...}
-- debug mode only (otherwise English texts are stripped)
-- if 'deep' handles the case when another T is used as the string
---
--- Gets the English text for a localized string, even in non-debug mode.
---
--- @param T any The localized string or table containing the localized string.
--- @param deep boolean (optional) If true, recursively gets the English text for nested localized strings.
--- @param no_assert boolean (optional) If true, skips the assertion check for the input.
--- @return string The English text for the localized string.
---
function TDevModeGetEnglishText(T, deep, no_assert)
	if T == "" then
		return ""
	end
	local no_assert = no_assert or not Platform.pc or Platform.ged
	assert(no_assert or Platform.debug and IsT(T))
	if type(T) ~= "table" --[[shield for non-debug mode]] then
		local id = LightUserdataToLocId(T)
		return id and TranslationTable[id] or "Missing text"
	end
	local ret = type(T[1]) == "number" and T[2] or T[1]
	ret = deep and type(ret) ~= "string" and TDevModeGetEnglishText(ret, true, no_assert) or ret 
	if not Platform.debug and type(ret)=="string" then
		ret = ret:gsub("%(design%)%s*", ""):gsub("%(minor%)%s*", "")
	end
	return ret
end

---
--- Sorts a table of elements by a specified field or a custom sorting function.
---
--- @param t table The table to sort.
--- @param field string|function (optional) The field to sort by, or a custom sorting function.
--- @param case_insensitive boolean (optional) If true, the sorting will be case-insensitive.
---
function TSort(t, field, case_insensitive)
	local sortkey_internal_translation
	if type(field) == "function" then
		for i = 1, #t do
			sortkey_internal_translation = _InternalTranslate(field(t[i]))
			if Platform.pc then
				t[i].__sort_key = utf8.ToUtf16(sortkey_internal_translation)
			else
				t[i].__sort_key = sortkey_internal_translation
			end
		end
	else
		for i = 1, #t do
			sortkey_internal_translation = _InternalTranslate(t[i][field])
			if Platform.pc then
				t[i].__sort_key = utf8.ToUtf16(sortkey_internal_translation)
			else
				t[i].__sort_key = sortkey_internal_translation
			end
		end
	end
	if Platform.pc then
		local lang = table.find_value(AllLanguages, "value", GetLanguage())
		local wchar_locale = utf8.ToUtf16(lang and lang.locale or "en-US")
		table.stable_sort(t, function(a,b) return LocaleCmp(a.__sort_key, b.__sort_key, wchar_locale, case_insensitive) end)
	else
		if case_insensitive then
			table.stable_sort(t, function(a,b) return CmpLower(a.__sort_key, b.__sort_key) end)
		else
			table.stable_sort(t, function(a,b) return a.__sort_key < b.__sort_key end)
		end
	end
	for i = 1, #t do
		t[i].__sort_key = nil
	end
end

---
--- Checks if a given string contains only tags and punctuation, without any word characters.
---
--- @param str string The input string to check.
--- @return boolean True if the string contains only tags and punctuation, false otherwise.
---
function IsTagsAndPunctuation(str)
	local untagged, tag, first, last = str:nexttag(1)
	while tag do
		if untagged:find("%w") then
			return false
		end
		untagged, tag, first, last = str:nexttag(last+1)
	end
	return not untagged:find("%w")
end

---
--- Checks if a given string contains only tags and punctuation, without any word characters.
---
--- @param str string The input string to check.
--- @return boolean True if the string contains only tags and punctuation, false otherwise.
---
function IsLookupTag(str)
	local untagged, tag, first, last = str:nexttag(1)
	if not tag then return false end
	while tag do
		if untagged:find("%w") then
			return false
		end
		if not TagLookupTable[tag] then return false end
		untagged, tag, first, last = str:nexttag(last+1)
	end
	return not untagged:find("%w")
end

---
--- Checks if a given table contains any arguments besides the first one (which is assumed to be the ID).
---
--- @param T table The input table to check.
--- @return boolean True if the table contains any additional arguments, false otherwise.
---
function THasArgs(T)
	if type(T) == "table" then
		local hasID = type(T[1]) == "number"
		for k,v in pairs(T) do
			if k ~= 1 and (not hasID or k ~= 2) and k ~= "untranslated" and k ~= "_steam_id" and k ~= "_language" then
				return true
			end
			if THasArgs(v) then
				return true
			end
		end
	end
	return false
end

---
--- Recursively strips any additional arguments from a localization table.
---
--- @param _T table The localization table to strip arguments from.
--- @return table The localization table with only the ID and localized text.
---
function TStripArgs(_T)
	if type(_T) == "table" then
		local hasID = type(_T[1]) == "number"
		if hasID then
			return T{_T[1], TStripArgs(_T[2])}
		else
			return T{TStripArgs(_T[1])}
		end
	end
	return _T
end

local gender_offset = {
	[false] = 0,
	["m"] = 0,
	["M"] = 0,
	["Male"] = 0,
	["f"] = 1,
	["F"] = 1,
	["Female"] = 1,
	["n"] = 2,
	["N"] = 2,
}
---
--- Changes the localization ID to a gender-specific ID based on the provided gender.
---
--- @param id number The original localization ID.
--- @param gender string|table The gender to use for the ID change. Can be a string ("m", "f", "n") or a table with a "Gender" field.
--- @return number The new gender-specific localization ID, or the original ID if the gender is invalid.
---
function GenderChangedID(id, gender)
	if type(id) ~= "number" then return id end
	if IsT(gender) then
		gender = GetTGender(gender)
	elseif type(gender) == "table" then
		gender = gender.Gender
	end
	local offset = gender_offset[gender or false]
	assert(offset)
	local new_id = id + (offset or 0)
	return TranslationTable[new_id] and new_id or id
end

-- "T=function" syntax used to avoid LocExtract scanning of T("text") syntax
---
--- Translates a localization ID or table into a localized string, handling gender-specific localization and random localization IDs.
---
--- @param T table|number The localization ID or table to translate.
--- @param Ttext string The localized text to use if `T` is a number.
--- @param gender string|table The gender to use for gender-specific localization. Can be a string ("m", "f", "n") or a table with a "Gender" field.
--- @return string The localized string.
---
T = function(T, Ttext, gender)
	if type(T) == "table" then
		if getmetatable(T[1]) == TConcatMeta then
			return T[1]
		end

		local id = T[1]
		local text = type(id) == "number" and T[2] or T[1]
		-- we can use the dev.mode function here before processing the T
		if text == "" then
			return "" -- this is here to allow checking localized strings for == "" and ~= ""
		end

		if type(id) == "number" and type(text) == "string" then
			if IsRandomLocId(id) then
				RandomLocIds[id] = true
			end
			gender = T.TGender
			if gender then
				assert(not T.__gender_updated) -- the same T should not be passed more than once to this function
				dbg(rawset(T, "__gender_updated", true)) -- mark the T so we can recognise it if we get it again
				T[1] = GenderChangedID(id, gender)
			end
			if not Platform.debug and not Platform.ged and TranslationTable[id] and not THasArgs(T) then
				return LocIDToLightUserdata(id)
			end
		end
		return setmetatable(T, TMeta)
	else
		local id = T
		local text = type(id) == "number" and Ttext or T
		if text == "" then
			return ""
		end
		if type(id) == "number" and type(text) == "string" then
			if IsRandomLocId(id) then
				RandomLocIds[id] = true
			end
			if gender then
				id = GenderChangedID(id, gender)
			end
			if not Platform.debug and not Platform.ged and TranslationTable[id] then
				return LocIDToLightUserdata(id)
			end
		end
		return setmetatable({T, Ttext}, TMeta)
	end
end

local locId_random_start = 100000000000
local locId_random_range = 899999000000

---
--- Checks if the given ID is a random localization ID.
---
--- @param id number The ID to check.
--- @return boolean True if the ID is a random localization ID, false otherwise.
---
function IsRandomLocId(id)
	if type(id) == "number" then
		id = id - locId_random_start
		return id >= 0 and id < locId_random_range
	end
end

---
--- Generates a random localization ID that has not been used before.
---
--- @return number A unique random localization ID.
---
function RandomLocId()
	for i = 1, 1000 do
		local id = locId_random_start + AsyncRand(locId_random_range)
		if not RandomLocIds[id] and not RandomLocIds[id - 1] and not RandomLocIds[id - 2] and not RandomLocIds[id + 1] and not RandomLocIds[id + 2] then
			RandomLocIds[id] = true
			return id
		end
	end
	assert(not "Failed to allocate translation ID, ID range full?") -- highly unlikely as range is huge; probably something more nefarious
end

---
--- Converts the given value to a localized string, marking it as untranslated.
---
--- @param _T any The value to convert to a localized string.
--- @return table A localized string table with the untranslated flag set.
---
function Untranslated(_T)
	if IsT(_T) then return _T end
	if type(_T) == "table" then return T(_T) end
	assert(not _T or type(_T) == "string" or type(_T) == "number")
	assert(type(_T) ~= "string" or not IsLookupTag(_T), "In this case you should use TLookupTag('<tag>') instead of Untranslated('<tag>')")
	return T{tostring(_T or ""), untranslated = true}
end

-- This exists so we can always clothe tags with T{} (even in non-debug)
---
--- Converts a lookup tag to a localized string.
---
--- @param _T string The lookup tag to convert.
--- @return table A localized string table with the lookup tag.
---
function TLookupTag(_T)
	assert(IsLookupTag(_T), "Use TLookupTag only for lookup tags")
	return T{tostring(_T)}
end

---
--- Initializes the localization system on first load.
---
--- This code sets up the metatable for localized strings (`TMeta`) and the metatable for concatenated localized strings (`TConcatMeta`). It also initializes the `TranslationTable` and `TranslationGenderTable` dictionaries, and sets the `g_ignore_translation_errors` flag to `false`.
---
--- This code is executed only on the first load of the module, and is responsible for setting up the necessary infrastructure for the localization system.
---
if FirstLoad then
	TMeta = { __name = "T" }
	TConcatMeta = { __name = "T(concat)" }
	LightUserDataSetMetatable(TMeta)
	oldTableConcat = table.concat

	TranslationTable = {}
	TranslationGenderTable = {}
	g_ignore_translation_errors = false
end

---
--- Persists the localization metatable definitions to the given permanents table.
---
--- This function is called during the game's persistence system to ensure that the
--- localization system's metatable definitions are properly serialized and restored
--- when the game is loaded.
---
--- @param permanents table The table to store the metatable definitions in.
---
function OnMsg.PersistGatherPermanents(permanents)
	permanents["T.meta"] = TMeta
	permanents["TConcat.meta"] = TConcatMeta
	permanents["func:type"] = type
end

---
--- Concatenates two localized string values.
---
--- This function is the implementation of the `__concat` metamethod for the `TMeta` metatable.
--- It handles the concatenation of two localized string values, converting them to a table of localized strings if necessary.
---
--- @param T1 table|string A localized string value or a table of localized strings to concatenate.
--- @param T2 table|string A localized string value or a table of localized strings to concatenate.
--- @return table A new table of localized strings, representing the concatenation of `T1` and `T2`.
---
TMeta.__concat = function(T1, T2)
	-- convert first parameter to a concatenated T type
	if IsTCompatible(T1) then
		if type(T1) == "table" and getmetatable(T1) == TConcatMeta then
			T1 = table.copy(T1)
		else
			T1 = { T1 }
		end
	elseif type(T1) == "string" then
		assert(false, string.format("Attempt to concatenate plain text or numbers '%s' to a localized string", T1), 1)
		T1 = { T1 }
	else
		assert(false, string.format("Attempt to concatenate invalid value '%s' to a localized string", tostring(T1)), 1)
		return T2
	end

	-- append the second parameter into the "concatenated T" table
	if IsTCompatible(T2) then
		if type(T2) == "table" and getmetatable(T2) == TConcatMeta then
			local num = #T1
			for i = 1, #T2 do
				T1[num+i] = T2[i]
			end
		else
			T1[1+#T1] = T2
		end
	elseif type(T2) == "string" then
		assert(false, string.format("Attempt to concatenate plain text or numbers '%s' to a localized string", T2), 1)
		T1[1+#T1] = T2
	else
		assert(false, string.format("Attempt to concatenate invalid value '%s' to a localized string", tostring(T2)), 1)
	end

	return setmetatable(T1, TConcatMeta)
end
---
--- Prevents modifying localized strings.
---
--- This function is the implementation of the `__newindex` metamethod for the `TMeta` metatable.
--- It asserts that modifying localized strings is forbidden, as in Gold Master they could be a userdata instead of a table.
---
TMeta.__newindex = function()
	assert(false, "Modifying localized strings is forbidden - in Gold Master they could be a userdata instead of a table", 1)
end
---
--- Provides a copy of the localized string table.
---
--- This function is the implementation of the `__copy` metamethod for the `TMeta` metatable.
--- It allows the localized string table to be copied using the `table.copy` function.
---
--- @param self table The localized string table to be copied.
--- @return table A new table that is a copy of the localized string table.
---
TMeta.__copy = function(self)
	return self -- support for table.copy - treat Ts as simple values
end
---
--- Converts the localized string table to Lua code.
---
--- This function is the implementation of the `__toluacode` metamethod for the `TConcatMeta` metatable.
--- It generates Lua code that represents the concatenated list of localized strings.
---
--- @param self table The concatenated list of localized strings to be converted to Lua code.
--- @param indent string|number The indentation level for the generated Lua code.
--- @param pstr string An optional string to which the generated Lua code will be appended.
--- @return string The generated Lua code that represents the concatenated list of localized strings.
---
TMeta.__toluacode = function(self, indent, pstr)
	return TToLuaCode(self, ContextCache[self], pstr)
end
---
--- Compares two localized strings for equality.
---
--- This function is the implementation of the `__eq` metamethod for the `TMeta` metatable.
--- It compares two localized strings for equality by checking if they are both `T` values and if their English text is the same.
---
--- @param op1 table The first localized string to compare.
--- @param op2 table The second localized string to compare.
--- @return boolean `true` if the two localized strings are equal, `false` otherwise.
---
TMeta.__eq = function(op1, op2)
	return IsT(op1) and IsT(op2) and TDevModeGetEnglishText(op1, not "deep", "no assert") == TDevModeGetEnglishText(op2, not "deep", "no assert")
end
---
--- Serializes a localized string table for transmission over the network.
---
--- This function is the implementation of the `__serialize` metamethod for the `TMeta` metatable.
--- It asserts that only `UserText` `T` values should be serialized and sent over the network, and returns a table containing the serialized data.
---
--- @param T table The localized string table to be serialized.
--- @return string, table The serialized data, which includes the metatable name and a raw copy of the table.
---
TMeta.__serialize = function(T)
	assert(IsUserText(T), "Only UserText T values should go through the network.")
	return "TMeta", table.raw_copy(T)
end
---
--- Deserializes a localized string table that was serialized for transmission over the network.
---
--- This function is the implementation of the `__unserialize` metamethod for the `TMeta` metatable.
--- It asserts that only `UserText` `T` values should be deserialized and received over the network, and returns the deserialized table.
---
--- @param serialized_data table The serialized data, which includes the metatable name and a raw copy of the table.
--- @return table The deserialized localized string table.
---
TMeta.__unserialize = function(serialized_data)
	local T = setmetatable(serialized_data, TMeta)
	assert(IsUserText(T), "Only UserText T values should go through the network.")
	return T
end


ContextCache = {}

---
--- Concatenates two localized strings.
---
--- This function is the implementation of the `__concat` metamethod for the `TConcatMeta` metatable.
--- It concatenates two localized strings, ensuring that the resulting string is also a localized string.
---
--- @param op1 table The first localized string to concatenate.
--- @param op2 table The second localized string to concatenate.
--- @return table The concatenated localized string.
---
TConcatMeta.__concat = TMeta.__concat
---
--- Prevents modifying a concatenated list of localized strings.
---
--- This function is the implementation of the `__newindex` metamethod for the `TConcatMeta` metatable.
--- It asserts that attempting to modify a concatenated list of localized strings is not allowed.
---
--- @param ... any Arguments passed to the `__newindex` metamethod.
---
TConcatMeta.__newindex = function(...)
	assert(false, "Attempt to modify a concatenated list of localized strings", 1)
end
TConcatMeta.__newindex = function()
	assert(false, "Attempt to modify a concatenated list of localized strings", 1)
end
---
--- Generates Lua code for a concatenated list of localized strings.
---
--- This function is the implementation of the `__toluacode` metamethod for the `TConcatMeta` metatable.
--- It generates Lua code that creates a `TConcat` object from the list of localized strings in the `self` table.
---
--- @param self table The concatenated list of localized strings.
--- @param indent string|number The indentation level for the generated Lua code.
--- @param pstr string An optional string to prepend to the generated Lua code.
--- @return string The generated Lua code for the concatenated list of localized strings.
---
TConcatMeta.__toluacode = function(self, indent, pstr)
	-- ...
end
TConcatMeta.__toluacode = function(self, indent, pstr) -- for T_list properties
	local lines, context = {}, ContextCache[self]
	for _, value in ipairs(self) do
		lines[#lines + 1] = TToLuaCode(value, context)
	end
	if type(indent) ~= "string" then
		indent = string.rep("\t", indent or 0)
	end
	lines = "{\n\t" .. indent .. table.concat(lines, ",\n\t" .. indent) .. "\n" .. indent .. "}"
	if pstr then
		return pstr:append("TConcat(", lines, ")")
	else
		return string.format("TConcat(%s)", lines)
	end
end

---
--- Creates a new `TConcat` object from the given table.
---
--- The `TConcat` object is a metatable-wrapped table that represents a concatenated list of localized strings. This function is used to create such objects, which can be used to safely concatenate localized strings without modifying the original strings.
---
--- @param table table The table of localized strings to be concatenated.
--- @return table A new `TConcat` object representing the concatenated localized strings.
---
function TConcat(table)
	return setmetatable(table, TConcatMeta)
end

-- supports concatenation of Ts and concatenated Ts only (can't intermix with plain strings/numbers)
---
--- Concatenates a table of localized strings, handling special cases such as concatenating `TConcat` objects and ensuring that the separator is a localized string.
---
--- @param t table The table of localized strings to concatenate.
--- @param sep string|TConcat The separator to use between the localized strings.
--- @param i number The starting index of the table to concatenate.
--- @param j number The ending index of the table to concatenate.
--- @return string The concatenated string of localized strings.
---
function table.concat(t, sep, i, j)
	if not next(t) then return "" end
	i = i or 1
	j = j or #t
	local idx, item = i, t[i]
	if i == j then return item end
	while item == "" and idx < j do
		idx = idx + 1
		item = t[idx]
	end
	if IsT(item) and item ~= "" then
		for n = i, j do
			local item = t[n]
			assert(IsT(item), "All items in table.concat must be localized strings")
		end
		assert(not sep or IsTCompatible(sep), "Separator in table.concat must be a localized string or tags&punctuation only")
		return setmetatable({ setmetatable({table = t, sep = sep, i = i, j = j}, TConcatMeta) }, TConcatMeta)
	end
	if IsT(sep) then
		sep = _InternalTranslate(sep)
	end
	return oldTableConcat(t, sep, i, j)
end

-- first look in the nested Ts, then in the T table itself
---
--- Recursively evaluates an identifier in the context of a localized string.
---
--- This function is used to resolve identifiers within localized strings, such as parameters or member access. It first looks for the identifier in the inner `T` objects, then in the direct parameters of the `T` object, then in the `context_obj`, and finally in the `TagLookupTable`.
---
--- @param T table The localized string object.
--- @param context_obj table The context object to use for resolving identifiers.
--- @param id string The identifier to evaluate.
--- @return any The value of the evaluated identifier.
---
local function evalIdentifier(T, context_obj, id)
	local value
	if type(T) == "table" then
		local format_string_index = type(T[1]) == "number" and 2 or 1
		-- 1. Recursively try the parameters of the inner T
		local innerT = T[format_string_index]
		if IsT(innerT) then
			value = evalIdentifier(innerT, context_obj, id)
		end
		
		-- 2. Try direct parameters
		value = value or T[id]

		-- 3. Try context_obj
		if not value and context_obj then
			value = ResolveValue(context_obj, id)
		end

		if not value then
			-- 4. Look into parameters passed in tables
			for j = format_string_index + 1, #T do
				local obj = T[j]
				if context_obj ~= obj then
					value = ResolveValue(obj, id)
					if value then break end
				end
			end
		end
	else
		-- 3. Try context_obj
		if not value and context_obj then
			value = ResolveValue(context_obj, id)
		end
	end

	-- 5. apply TagLookupTable
	if not value then -- carefully avoid changing 'false' to 'nil'
		local lookup = TagLookupTable[id]
		if lookup then
			value = lookup
		end
	end
	
	-- 6. call if func
	if type(value) == "function" then
		value = value(context_obj)
	end
	
	return value
end

---
--- Recursively evaluates a string of identifiers, resolving each identifier against the provided `context_obj`.
---
--- @param T table The table containing the identifiers to evaluate.
--- @param context_obj table The context object to use for resolving identifiers.
--- @param ids string The string of identifiers to evaluate.
--- @return table The final resolved context object.
---
function evalIdentifiers(T, context_obj, ids)
	-- Implementation details...
end
local function evalIdentifiers(T, context_obj, ids)
	local first = 1
	while first do
		local rest = ids:find(".", first, true)
		context_obj = evalIdentifier(T, context_obj, ids:sub(first, (rest or 0) - 1))
		first = rest and rest + 1
	end
	return context_obj
end

---
--- Evaluates a function call with the provided parameters.
---
--- @param T table The table containing the function to call.
--- @param context_obj table The context object to use for resolving identifiers in the parameters.
--- @param fn string The name of the function to call.
--- @param tag string The full tag string containing the function call and parameters.
--- @param param_start number The starting index of the parameters in the tag string.
--- @return any The result of the function call.
---
local function evalFunctionCall(T, context_obj, fn, tag, param_start)
	-- Implementation details...
end
local evalFunctionCall
---
--- Evaluates the parameters in a tag string and returns them as a list of values.
---
--- @param T table The table containing the identifiers and functions to evaluate.
--- @param context_obj table The context object to use for resolving identifiers in the parameters.
--- @param tag string The full tag string containing the parameters.
--- @param start number The starting index of the parameters in the tag string.
--- @return any, any The evaluated parameters and the remaining part of the tag string.
---
local function evalParams(T, context_obj, tag, start)
	local param, cont = tag:match("^%s*([%a_][%w_.]*)%s*[,)]()", start)
	if param == "true" or param == "false" then  -- bool
		param = param == "true"
		return param, evalParams(T, context_obj, tag, cont)
	end
	if param then  -- identifiers? normal lookup in T params, members of T objs etc.
		return evalIdentifiers(T, context_obj, param), evalParams(T, context_obj, tag, cont)
	end
	local param_start
	param, param_start, cont = tag:match("^%s*([%a_][%w_]*)()%b()%s*[,)]()", start)
	if param then  -- function call? normal lookup in T params, members of T objs etc.
		return evalFunctionCall(T, context_obj, param, tag, param_start + 1), evalParams(T, context_obj, tag, cont)
	end
	param, cont = tag:match("^%s*%'(.-)%'%s*[,)]()", start)
	if param then  -- literal string in ''s
		return param, evalParams(T, context_obj, tag, cont)
	end
	param, cont = tag:match("^%s*(%-?%d+)%s*[,)]()", start)
	if param then  -- integer
		param = tonumber(param)
		return param, evalParams(T, context_obj, tag, cont)
	end
end

---
--- Evaluates a function call with the provided parameters.
---
--- @param T table The table containing the function to call.
--- @param context_obj table The context object to use for resolving identifiers in the parameters.
--- @param fn string The name of the function to call.
--- @param tag string The full tag string containing the function call and parameters.
--- @param param_start number The starting index of the parameters in the tag string.
--- @return any The result of the function call.
---
local function evalFunctionCall(T, context_obj, fn, tag, param_start)
	local f = TFormat[fn]
	if f then
		return f(context_obj, evalParams(T, context_obj, tag, param_start))
	end
	local f, obj = ResolveFunc(context_obj, fn)
	if f then
		return f(obj or context_obj, evalParams(T, context_obj, tag, param_start))
	end
	assert(f, "unknown TFormat or context function specified in tag " .. tag)
end
evalFunctionCall = function (T, context_obj, fn, tag, param_start)
	local f = TFormat[fn]
	if f then
		return f(context_obj, evalParams(T, context_obj, tag, param_start))
	end
	local f, obj = ResolveFunc(context_obj, fn)
	if f then
		return f(obj or context_obj, evalParams(T, context_obj, tag, param_start))
	end
	assert(f, "unknown TFormat or context function specified in tag " .. tag)
end

---
--- Evaluates a tag in the localization system.
---
--- @param T table The table containing the localization data.
--- @param context_obj table The context object to use for resolving identifiers in the tag.
--- @param tag string The tag to evaluate.
--- @return any The result of evaluating the tag.
---
local function evalTag(T, context_obj, tag)
	local func, param_start = tag:match("^(/?[%a_][%w_]*)()%b()$") -- find function and parameters start
	if func then
		return evalFunctionCall(T, context_obj, func, tag, param_start + 1) -- ATTN: Multiple return values possible (2nd value is true for preventing error checking on the resulting string)
	end
	return evalIdentifiers(T, context_obj, tag)
end

---
--- Concatenates a table of translated strings, optionally with a separator.
---
--- @param T table The table containing the strings to concatenate.
--- @param context_obj table The context object to use for translating the strings.
--- @param check boolean Whether to perform error checking on the translated strings.
--- @param tags_off boolean Whether to disable tag evaluation in the translated strings.
--- @return string The concatenated string.
---
local function evalConcat(T, context_obj, check, tags_off)
	local pieces = {}

	local t = T.table
	if t then
		for i = T.i, T.j do
			table.insert(pieces, _InternalTranslate(t[i], context_obj, check, tags_off))
		end
		return oldTableConcat(pieces, T.sep and _InternalTranslate(T.sep, context_obj, check, tags_off))
	end

	for i = 1, #T do
		table.insert(pieces, _InternalTranslate(T[i], context_obj, check, tags_off))
	end
	return oldTableConcat(pieces)
end

---
--- Appends a translation function call to the provided string buffer.
---
--- @param _pstr string The string buffer to append the translation to.
--- @param T table The localization data table.
--- @param context_obj table The context object to use for resolving identifiers in the tag.
--- @param fn string The name of the translation function to call.
--- @param tag string The full tag string, including the function name and parameters.
--- @param param_start number The starting index of the parameters in the tag string.
--- @param check boolean Whether to perform error checking on the translated string.
--- @return boolean|string False on success, or an error string on failure.
---
local function appendTranslateFunctionCall(_pstr, T, context_obj, fn, tag, param_start, check)
	local append_f = TFormatPstr[fn]
	if append_f then
		local err = append_f(_pstr, context_obj, evalParams(T, context_obj, tag, param_start))
		return err
	end
	local eval_f = TFormat[fn]
	if eval_f then
		local value, ignore_check = eval_f(context_obj, evalParams(T, context_obj, tag, param_start))
		if value == nil then
			return "not_a_tag"
		end
		if not value then
			return "failed"
		end
		return AppendTTranslate(_pstr, value, context_obj, check ~= false and not ignore_check)
	end
	local eval_f, obj = ResolveFunc(context_obj, fn)
	if eval_f then
		local value, ignore_check = eval_f(obj or context_obj, evalParams(T, context_obj, tag, param_start))
		if value == nil then
			return "not_a_tag"
		end
		if not value then
			return "failed"
		end
		return AppendTTranslate(_pstr, value, context_obj, check ~= false and not ignore_check)
	end
	assert(eval_f, "unknown TFormat or context function specified in tag " .. tag)
end


---
--- Appends a translation tag to the provided string buffer.
---
--- @param _pstr string The string buffer to append the translation to.
--- @param T table The localization data table.
--- @param context_obj table The context object to use for resolving identifiers in the tag.
--- @param tag string The full tag string, including the function name and parameters.
--- @param check boolean Whether to perform error checking on the translated string.
--- @return boolean|string False on success, or an error string on failure.
---
local function appendTranslateTag(_pstr, T, context_obj, tag, check)
	local func, param_start = tag:match("^(/?[%a_][%w_]*)()%b()$") -- find function and parameters start
	if func then
		local err = appendTranslateFunctionCall(_pstr, T, context_obj, func, tag, param_start + 1, check) -- ATTN: Multiple return values possible (2nd value is true for preventing error checking on the resulting string)
		return err
	else
		local value, ignore_check = evalIdentifiers(T, context_obj, tag)
		if value == nil then
			return "not_a_tag"
		end
		if not value then
			return "failed"
		end
		local err = AppendTTranslate(_pstr, value, context_obj, check ~= false and not ignore_check)
		return err
	end
	return false
end


---
--- Appends a translated string to the provided string buffer, handling any translation tags within the string.
---
--- @param _pstr string The string buffer to append the translation to.
--- @param T userdata|table|string|number The localization data to translate.
--- @param context_obj table The context object to use for resolving identifiers in any translation tags.
--- @param check boolean Whether to perform error checking on the translated string.
--- @param tags_off boolean Whether to skip processing any translation tags in the string.
--- @return boolean False on success, or an error string on failure.
---
local function appendTranslateT(_pstr, T, context_obj, check, tags_off)
	local id = TGetID(T)
	local str = (not Platform.debug or GetLanguage() ~= "English" or type(T) == "userdata") and TranslationTable[id]
		or TDevModeGetEnglishText(T, "deep", "no_assert") or string.format("{#%d}", id)
	if tags_off then
		_pstr:append(str)
		return false
	end

	local untagged, tag, first, last = str:nexttag(1)
	context_obj = context_obj or type(T) == "table" and T[type(T[1]) == "number" and 3 or 2] or nil
	while tag do
		_pstr:append(untagged)
		
		local success, err = procall(appendTranslateTag, _pstr, T, context_obj, tag, check)
		if not success then
			print("once", "evalTag", tag, "failed for", str)
			untagged = ""
			break
		end
		if err == "not_a_tag" then
			_pstr:append_sub(str, first, last)
		elseif err then
			untagged = ""
			break
		end
		untagged, tag, first, last = str:nexttag(last + 1)
	end
	_pstr:append(untagged)
	return false
end

---
--- Appends a concatenated localized string to the provided string buffer, handling any translation tags within the strings.
---
--- @param _pstr string The string buffer to append the translation to.
--- @param T table The concatenated localization data to translate.
--- @param context_obj table The context object to use for resolving identifiers in any translation tags.
--- @param check boolean Whether to perform error checking on the translated strings.
--- @param tags_off boolean Whether to skip processing any translation tags in the strings.
--- @return boolean False on success, or an error string on failure.
---
local function appendTranslateConcat(_pstr, T, context_obj, check, tags_off)
	local AppendTTranslate = AppendTTranslate
	local t = T.table
	if t then
		local t_start = T.i
		local t_end = T.j
		if T.sep then
			for i = t_start, t_end - 1 do
				AppendTTranslate(_pstr, t[i], context_obj, check, tags_off)
				AppendTTranslate(_pstr, T.sep, context_obj, check, tags_off)
			end
			AppendTTranslate(_pstr, t[t_end], context_obj, check, tags_off)
		else
			for i = t_start, t_end do
				AppendTTranslate(_pstr, t[i], context_obj, check, tags_off)
			end
		end
		return false
	end

	for i = 1, #T do
		AppendTTranslate(_pstr, T[i], context_obj, check, tags_off)
	end
	return false
end

---
--- Appends a filtered user text string to the provided string buffer.
---
--- @param _pstr string The string buffer to append the user text to.
--- @param T table The user text to append.
--- @param check boolean Whether to perform error checking on the user text.
--- @return boolean False on success, or an error string on failure.
---
local function appendTranslateUserText(_pstr, T, check)
	local text = GetFilteredText(T)
	assert(not check or text, "Trying to use a UserText before AsyncFilterUserTexts or SetCustomFilteredUserText(s) call\n" .. TDevModeGetEnglishText(T, not "deep", "no_assert"))
	_pstr:append(text or TDevModeGetEnglishText(T, not "deep", "no_assert"))
	return false
end

---
--- Appends a localized string to the provided string buffer, handling any translation tags within the strings.
---
--- @param _pstr string The string buffer to append the translation to.
--- @param T table|string|number|userdata The localization data to translate.
--- @param context_obj table The context object to use for resolving identifiers in any translation tags.
--- @param check boolean Whether to perform error checking on the translated strings.
--- @param tags_off boolean Whether to skip processing any translation tags in the strings.
--- @return boolean False on success, or an error string on failure.
---
function AppendTTranslate(_pstr, T, context_obj, check, tags_off)
	-- TODO: assert if it's too early to translate (see locutils for a too-early translation)?
	if T == "" then
		return false
	end
	local Ttype = type(T)
	if Ttype == "userdata" then
		local err = appendTranslateT(_pstr, T, context_obj, check)
		if err then
			return err
		end
	elseif Ttype == "string" then
		assert(not Platform.debug or check == false or IsTagsAndPunctuation(T), string.format("Attempt to use plain text or numbers '%s' as a localized string", T))
		_pstr:append(T)
	elseif Ttype == "number" then
		_pstr:append(LocaleInt(T))
	elseif IsUserText(T) then
		local err = appendTranslateUserText(_pstr, T, check)
		if err then
			return err
		end
	elseif Ttype == "table" and getmetatable(T) == TMeta then
		local err = appendTranslateT(_pstr, T, context_obj, check, tags_off)
		if err then
			return err
		end
	elseif Ttype == "table" and getmetatable(T) == TConcatMeta then
		local err = appendTranslateConcat(_pstr, T, context_obj, check, tags_off)
		if err then
			return err
		end
	else
		assert(false, string.format("Attempt to translate invalid value '%s'", tostring(T)))
		return true
	end

	return false
end

---
--- A boolean flag that controls whether localized string IDs should be prepended to the translated strings.
---
--- When this flag is true, the localized string ID will be prepended to the translated string, separated by a colon.
--- This can be useful for debugging and identifying the source of translated strings.
---
--- @type boolean
---
local g_TranslatePrependIDs

---
--- Toggles whether localized string IDs should be prepended to the translated strings.
---
--- When this flag is true, the localized string ID will be prepended to the translated string, separated by a colon.
--- This can be useful for debugging and identifying the source of translated strings.
---
function ToggleTranslatePrependIDs()
	g_TranslatePrependIDs = not g_TranslatePrependIDs
	Msg("TranslationChanged")
end

---
--- A temporary cache for the TTranslate function's pstr object.
--- This allows the TTranslate function to reuse the same pstr object instead of creating a new one every time.
---
--- @type pstr
---
local TTranslatePstrCache = pstr("", 256)
---
--- Translates the given value `T` using the provided context object and options.
---
--- @param T any The value to translate.
--- @param context_obj table The context object to use for translation.
--- @param check boolean Whether to check for translation errors.
--- @param tags_off boolean Whether to disable HTML tag translation.
--- @return string The translated string.
---
function TTranslate(T, context_obj, check, tags_off)
	local _pstr = TTranslatePstrCache
	if not _pstr then
		_pstr = pstr("", 256)
	else
		TTranslatePstrCache = false
		_pstr:clear()
	end
	
	local err = AppendTTranslate(_pstr, T, context_obj, check ~= false and not TIgnoreErrors, tags_off)
	assert(not err, "translation error")
	
	TTranslatePstrCache = _pstr -- return to the cache
	
	if g_TranslatePrependIDs then
		local id = TGetID(T)
		if id then
			return id .. ":" .. _pstr:str()
		end
	end
	return _pstr:str()
end

_InternalTranslate = TTranslate

local ThousandsSeparator

---
--- Formats a number with a thousands separator.
---
--- @param x number The number to format.
--- @return string The formatted number string.
---
function LocaleInt(x)
	ThousandsSeparator = ThousandsSeparator or TTranslate(T(433967674729, --[[thousands separator]] ","))
	local ts = ThousandsSeparator
	local r = ""
	if x < 0 then
		r = "-"
		x = -x
	end

	if x < 1000 then
		r = r .. tostring(x)
	elseif x < 1000*1000 then
		r = string.format("%s%d%s%03d", r, x/1000, ts, x%1000)
	elseif x < 1000*1000*1000 then
		r = string.format("%s%d%s%03d%s%03d", r, x/1000000, ts, (x/1000)%1000, ts, x%1000)
	else
		r = string.format("%s%d%s%03d%s%03d%s%03d", r, x/1000000000, ts, (x/1000000)%1000, ts, (x/1000)%1000, ts, x%1000)
	end
	return r
end

---
--- Called when the translation system has changed.
--- Clears the thousands separator cache and marks the PreGameButtons object as modified.
---
function OnMsg.TranslationChanged()
	ThousandsSeparator = false
	ObjModified("PreGameButtons")
end

---
--- Formats a date and time string in the user's locale.
---
--- @param os_time number The Unix timestamp to format.
--- @return string The formatted date and time string.
---
function LocaleDateTime(os_time)
	return os.date(GetLanguage() == "Japanese" and "%Y.%m.%d %H:%M" or "%d %b %Y %H:%M", os_time)
end

-- Returns the order of month, day and year.
-- This handles transforming the output of the various systems into an array.
-- Don't call this on a hot path please :)
-- Example: YYYYMMDD -> { year, month, day }
-- M/d/YYYY -> { month, day, year }
-- dd mmm Y -> { day, month, year }
---
--- Returns the order of month, day and year based on the system date format.
---
--- @return table The order of month, day and year as an array of strings.
---
function GetDateTimeOrder()
	local format = GetSystemDateFormat()
	local lastC = false
	local order = {}
	for i = 1, #format do
		local c = format:sub(i, i)
		local isMonthChar = c == "m" or c == "M"
		local isYearChar = c == "Y" or c == "y"
		local isDayChar = c == "D" or c == "d"
		local isValidChar = isMonthChar or isYearChar or isDayChar
		if isValidChar then
			if c ~= lastC then
				if isMonthChar then
					order[#order + 1] = "month"
				elseif isYearChar then
					order[#order + 1] = "year"
				elseif isDayChar then
					order[#order + 1] = "day"
				end
			end
			lastC = c
		end
	end
	return order
end

---
--- Converts a localization table or ID to a Lua code string.
---
--- @param T table|number The localization table or ID to convert.
--- @param context string The context of the localization.
--- @param pstr string An optional string to append the Lua code to.
--- @return string The Lua code representation of the localization.
---
function TToLuaCode(T, context, pstr)
	if IsUserText(T) then
		return UserTextToLuaCode(T, context, pstr)
	end
	
	assert(not THasArgs(T))
	return IDTextToLuaCode(TGetID(T), TDevModeGetEnglishText(T, not "deep", "no assert"), context, pstr)
end

---
--- Converts a user text localization object to a Lua code string.
---
--- @param T table The user text localization object to convert.
--- @param context string The context of the localization.
--- @param pstr string An optional string to append the Lua code to.
--- @return string The Lua code representation of the user text localization.
---
function UserTextToLuaCode(T, context, pstr)
	local lua_str = string.format("T%s", TableToLuaCode(T))
	if pstr then
		return pstr:appendf(lua_str)
	end
	return string.format(lua_str)
end

---
--- Converts a localization ID and text to a Lua code string.
---
--- @param id number The localization ID.
--- @param text string The localization text.
--- @param context string The context of the localization.
--- @param pstr string An optional string to append the Lua code to.
--- @return string The Lua code representation of the localization.
---
function IDTextToLuaCode(id, text, context, pstr)
	-- ...
end
function IDTextToLuaCode(id, text, context, pstr)	
	local context_str = context and context ~= "" and string.format("--[[%s]] ", context) or ""
	if id then
		if text ~= "" then
			if pstr then
				return pstr:appendf("T(%d, %s%v)", id, context_str, text)
			end
			return string.format("T(%d, %s%s)", id, context_str, StringToLuaCode(text))
		else
			if pstr then
				return pstr:append('""')
			end
			return '""'
		end
	else
		if pstr then
			return pstr:appendf("T(%s%v)", context_str, text)
		end
		return string.format("T(%s%s)", context_str, StringToLuaCode(text))
	end
end

local csv_load_fields = { [1] = "id", [2] = "text", [5] = "translated", [3] = "translated_new", [7] = "gender" }

---
--- Loads translation tables from a CSV file.
---
--- @param filename string The path to the CSV file containing the translation data.
--- @return boolean Whether the translation tables were successfully loaded.
---
function LoadTranslationTableFile(filename)
	local loaded = {}
	LoadCSV(filename, loaded, csv_load_fields, "omit_captions")
	return ProcessLoadedTables(loaded, GetLanguage(), TranslationTable, TranslationGenderTable)
end

---
--- Loads translation tables from a folder containing CSV files.
---
--- @param path string The path to the folder containing the CSV files.
--- @param language string The language to load the translation tables for.
--- @param out_table table The table to store the loaded translations.
--- @param out_gendertable table The table to store the gender information for the translations.
--- @return boolean Whether the translation tables were successfully loaded.
---
function LoadTranslationTablesFolder(path, language, out_table, out_gendertable)
	local loaded = {}
	local files = io.listfiles(path, "*.csv") or {}
	table.sort(files)
	for _, filename in ipairs(files) do
		LoadCSV(filename, loaded, csv_load_fields, "omit_captions")
	end
	return ProcessLoadedTables(loaded, language, out_table, out_gendertable)
end

---
--- Processes the loaded translation tables, extracting the appropriate translation text and storing it in the output tables.
---
--- @param loaded table The table containing the loaded translation data.
--- @param language string The language to process the translations for.
--- @param out_table table The table to store the loaded translations.
--- @param out_gendertable table The table to store the gender information for the translations.
--- @return boolean Whether the translation tables were successfully loaded.
---
function ProcessLoadedTables(loaded, language, out_table, out_gendertable)
	local order = { "translated_new", "translated", "text" }
	if language == "English" then
		order = { "translated_new", "text", "translated" }
	end
	for _, entry in ipairs(loaded) do
		local translation
		if entry[order[1]] and entry[order[1]] ~= "" then
			translation = entry[order[1]]
		elseif entry[order[2]] and entry[order[2]] ~= "" then
			translation = entry[order[2]]
		else
			translation = entry[order[3]]
		end
		local id = tonumber(entry.id)
		if id then
			out_table[id] = translation
			if out_gendertable then
				out_gendertable[id] = entry.gender
			end
		end
	end
	return next(loaded) ~= nil
end

--- A table of languages that should always wrap text, regardless of the user's text wrapping settings.
---
--- This table is used to ensure that certain languages, such as Chinese, Japanese, and Korean, always wrap text properly, even if the user has disabled text wrapping in their settings.
---
--- @field Schinese boolean Whether Simplified Chinese should always wrap text.
--- @field Tchinese boolean Whether Traditional Chinese should always wrap text.
--- @field Japanese boolean Whether Japanese should always wrap text.
--- @field Koreana boolean Whether Korean should always wrap text.
local AlwaysWrapLanguages = {
	Schinese = true,
	Tchinese = true,
	Japanese = true,
	Koreana = true,
}

---
--- Loads the translation tables for the current language.
---
--- This function loads the translation tables for the current language, and stores them in the `TranslationTable` and `TranslationGenderTable` global variables. It first attempts to load the tables from the `CurrentLanguage` directory in the executable directory, and if that fails, it tries to load them from the `CurrentLanguage/` directory. If that also fails, and the game is not in debug or command-line mode, it asserts an error.
---
--- The function also sets the `config.TextWrapAnywhere` flag based on whether the current language is one of the languages that should always wrap text, as defined in the `AlwaysWrapLanguages` table.
---
--- Finally, the function sends a "TranslationChanged" message to notify other parts of the application that the translation tables have been updated.
---
function LoadTranslationTables()
	TranslationTable = {}
	collectgarbage("collect")
	local path = GetExecDirectory() .. "CurrentLanguage"
	if not LoadTranslationTablesFolder(path, GetLanguage(), TranslationTable, TranslationGenderTable) then
		if not LoadTranslationTablesFolder("CurrentLanguage/", GetLanguage(), TranslationTable, TranslationGenderTable) and 
		   not Platform.debug and not Platform.cmdline 
		then
			assert(false, "Localization table not found in non-developer mode! (For testing you could copy the game.csv from LocalizationOut/English/CurrentLanguage to Bin/CurrentLanguage. Build the table with the LocExtract build command if it's not present.)")
		end
	end
	config.TextWrapAnywhere = AlwaysWrapLanguages[GetLanguage()] or false
	if not Loading then
		Msg("TranslationChanged")
	end
	collectgarbage("collect")
end

-- used by build

g_BuildLocTables = false
g_BuildLocTablesSignal = false

---
--- Loads the localization tables for the specified project path.
---
--- This function loads the localization tables for all languages found in the `LocalizationOut` directory of the specified project path. It first checks if the tables have already been loaded, and if so, waits for the first thread to finish loading them. Otherwise, it loads the tables and stores them in the `g_BuildLocTables` global variable.
---
--- The function first lists all the language folders in the `LocalizationOut` directory, then for each language, it loads all the CSV files in the `CurrentLanguage` subdirectory. It parses the CSV files and stores the localization data in a table, with the language name as the key.
---
--- Once all the localization tables have been loaded, the function sets the `g_BuildLocTables` global variable and signals any waiting threads that the tables have been loaded.
---
--- @param project_path string The path to the project directory containing the localization files.
---
function LoadBuildLocTables(project_path)
	if g_BuildLocTables then return end
	if g_BuildLocTablesSignal then
		WaitMsg(g_BuildLocTablesSignal)  -- if several build threads try to load the table concurrently, all wait for the first to finish
		return
	end

	g_BuildLocTablesSignal = {}

	local loctables = {}

	local err, languages = AsyncListFiles(project_path .. "/LocalizationOut", "*", "folders,relative")
	if err then print("Error loading translation tables: ", err) return end

	for _, language in ipairs(languages) do
		local path = project_path .. "/LocalizationOut/" .. language .. "/CurrentLanguage"
		local err, files = AsyncListFiles(path, "*.csv")
		if not err then
			local loaded = {}
			local needed_fields = { [1] = "id", [2] = "text", [3] = "translated_new" }
			table.sort(files)
			for i = 1, #files do
				LoadCSV(files[i], loaded, needed_fields, "omit_captions")
			end
			
			local order = { "translated_new" }
			if language == "English" then
				order = { "translated_new", "text" }
			end
			local lang_result = {}
			for _, entry in ipairs(loaded) do
				if entry[order[1]] and entry[order[1]] ~= "" then
					lang_result[tonumber(entry.id)] = entry[order[1]]
				elseif order[2] and entry[order[2]] and entry[order[2]] ~= "" then
					lang_result[tonumber(entry.id)] = entry[order[2]]
				end
			end
			loctables[language] = lang_result
		end
	end

	g_BuildLocTables = loctables
	Msg(g_BuildLocTablesSignal)
	g_BuildLocTablesSignal = false
end

---
--- Returns the gender of the given translation table.
---
--- @param T table The translation table.
--- @return string|false The gender of the translation table, or `false` if no gender is defined.
---
function GetTGender(T)
	return TranslationGenderTable[TGetID(T) or false] or false
end

-- gender can be:
--   * a string (M/F/N)
--   * a T and we use GetTGender(T)
--   * a table and we use gender.Gender
-- T can be:
--   * a simple T (no parameters) in which case we return the alternative gender variant of T
--   * a T with parameters in which case we MODIFY it in-place to reflect the requestsed gender
---
--- Returns a translation table with the gender variant specified.
---
--- @param T table The translation table.
--- @param gender string The gender variant to use. Can be "M", "F", or "N".
--- @return table The translation table with the specified gender variant.
---
function GetTByGender(T, gender)
	if (T or "") == "" then return T end
	if THasArgs(T) then -- in-place modification of a T with parameters - the assumption is that the function gets called with a newly created T table
		assert(type(T) == "table" and getmetatable(T) == TMeta) -- we do not work with concatenated strings
		assert(not T.__gender_updated) -- the same T should not be passed more than once to this function
		dbg(rawset(T, "__gender_updated", true)) -- mark the T so we can recognise it if we get it again
		T[1] = GenderChangedID(T[1], gender)
		return T
	else
		local id = GenderChangedID(TGetID(T), gender)
		return TranslationTable[id or false] and LocIDToLightUserdata(id) or T
	end
end

---
--- Returns the gender-specific suffix for the given translation table ID.
---
--- @param T table The translation table.
--- @param id string The translation table ID.
--- @return string The gender-specific suffix for the given ID.
---
function IdGenderSuffix(T, id)
	local gender = TranslationGenderTable[TGetID(T) or false] or "M"
	if gender == "F" then
		return id .. "_f"
	elseif gender == "N" then
		return id .. "_n"
	else
		return id .. "_m"
	end
end

--global functions for controlling/getting windows ime state
local IME_languages = {"Koreana","Japanese","Schinese","Tchinese"}
---
--- Initializes the Windows IME (Input Method Editor) state for the current language.
---
--- This function is responsible for enabling or disabling the IME based on the current language, and controlling the visibility of the IME candidate window.
---
--- The IME is enabled for languages that have been properly implemented, and disabled for languages that have not. The IME candidate window is also disabled for the "Koreana" language, as the game's fonts do not support Hanja input.
---
--- Additionally, the function sets the `hr.HideIme` flag to `true`, which is used to hide the IME window when the user has no editable controls in focus, allowing them to control the game without the IME window interfering.
---
--- It is the responsibility of the Lua controls to enable/disable the IME as needed.
---
function InitWindowsImeState()
	--since ime has different behaviour for each language, disable it for languages that have 
	--not been properly implemented.
	local lang = GetLanguage()
	config.EnableIme = Platform.pc and table.find(IME_languages,lang)
	--print("config.EnableIme:", config.EnableIme)
	config.EnableImeCandidateWindow = lang ~= "Koreana" --we don't support hanja in fonts so kill the candidate window to avoid hanja input.
	--print("config.EnableImeCandidateWindow:", config.EnableImeCandidateWindow)
	--we want ime hidden when the user has no editable controls on focus
	--so that the user is able to control the game without the ime window poping up and eating input
	--it is the responsibility of lua controls to enable/disable as needed.
	hr.HideIme = true
end

---
--- Checks if the Input Method Editor (IME) is enabled.
---
--- @return boolean True if the IME is enabled, false otherwise.
---
function IsImeEnabled()
	return config.EnableIme
end

---
--- Sets the position of the Windows Input Method Editor (IME) window.
---
--- This function is responsible for setting the position of the IME window relative to the upper left corner of the window. It assumes that the user will only edit one editable control at a time, and subsequent calls within the same frame are okay, but the final position will be processed at the end of the frame.
---
--- @param x number The x-coordinate of the IME window position.
--- @param y number The y-coordinate of the IME window position.
--- @param fontId number The font ID to use for the IME window.
---
function SetImePosition(x, y, fontId)
end
function SetImePosition(x, y, fontId) --relative to upper left corner of window, or so msdn claims.
	if IsImeEnabled() then
		--this assumes that the user will edit only one editable control @ a time.
		--subsequent calls in the same frame are ok, but keep in mind hr. vars will get processed @ the end of the frame.
		--this means only the last call per frame would actually get processed.
		hr.WindowsImePositionX = x
		hr.WindowsImePositionY = y
		hr.WindowsImeFontId = fontId or -1
		hr.WindowsImePosChanged = hr.WindowsImePosChanged + 1
	end
end

--will temporariliy disable ime from showing up so the player can control the game
---
--- Hides the Windows Input Method Editor (IME) window.
---
--- This function is responsible for hiding the IME window so that the user can control the game without the IME window popping up and eating input. It is the responsibility of the Lua controls to enable/disable the IME as needed.
---
--- @return nil
---
function HideIme()
	if IsImeEnabled() then
		if not hr.HideIme then
			hr.HideIme = true
		end
	end
end

--reverts changes done by HideIme()
---
--- Reverts the changes made by `HideIme()`, allowing the Windows Input Method Editor (IME) window to be shown again.
---
--- This function is responsible for restoring the ability for the IME window to be displayed, after it has been hidden by the `HideIme()` function. It is the responsibility of the Lua controls to enable/disable the IME as needed.
---
--- @return nil
---
function ShowIme()
	if IsImeEnabled() then
		if hr.HideIme then
			hr.HideIme = false
		end
	end
end

---
--- Gets the width and height of the IME window based on the specified font ID.
---
--- This function is used to determine the size of the IME window, which is necessary for positioning the IME window correctly on the screen. It uses the `terminal.GetWindowsImeCompositionString()` function to retrieve the current composition string, and then measures the text using `UIL.MeasureText()` to get the width and height.
---
--- @param fontId number The font ID to use for measuring the IME window size.
--- @return number, number The width and height of the IME window.
---
function GetImeWindowWidthHeight(fontId)
	local compStr = terminal.GetWindowsImeCompositionString()
	if compStr then
		return UIL.MeasureText(compStr, fontId) --another hack because ImmGetCompositionWindow returns empty rect.
	end
	return 0,0
end

---
--- A table of localization data for various languages, including their display names, PlayStation locale codes, and other locale codes.
---
--- This table contains information about the supported localization languages, including the display name, PlayStation locale code, locale code, Paradox locale code, and Epic Games locale code for each language.
---
--- @field value string The unique identifier for the language.
--- @field text string The display name for the language.
--- @field ps_locale string The PlayStation locale code for the language.
--- @field locale string The locale code for the language.
--- @field pdx_locale string The Paradox locale code for the language.
--- @field epic_locale string The Epic Games locale code for the language.
---
AllLanguages = {
	{ value = "Brazilian", text = T(699854757080, "Brazilian Portuguese"), ps_locale = "pt-BR", locale = "pt-BR", pdx_locale = "pt", epic_locale = "pt-BR", },
	{ value = "Bulgarian", text = T(385829073168, "Bulgarian"), ps_locale = "bg-BG", locale = "bg-BG", pdx_locale = "bg", epic_locale = false, },
	{ value = "Czech", text = T(552240423015, "Czech"), ps_locale = "cs-CZ", locale = "cs-CZ", pdx_locale = "cs", epic_locale = false, },
	{ value = "Danish", text = T(782416127227, "Danish"), ps_locale = "da-DK", locale = "da-DK", pdx_locale = "da", epic_locale = "da", },
	{ value = "Dutch", text = T(675114896426, "Dutch"), ps_locale = "nl-NL", locale = "nl-NL", pdx_locale = "nl", epic_locale = "nl", },
	{ value = "English", text = T(147611982706, "English"), ps_locale = "en-US", locale = "en-US", pdx_locale = "en", epic_locale = "en-US", },
	{ value = "Finnish", text = T(283206621979, "Finnish"), ps_locale = "fi-FI", locale = "fi-FI", pdx_locale = "fi", epic_locale = "fi", },
	{ value = "French", text = T(170273676234, "French"), ps_locale = "fr-FR", locale = "fr-FR", pdx_locale = "fr", epic_locale = "fr", },
	{ value = "German", text = T(505552009073, "German"), ps_locale = "de-DE", locale = "de-DE", pdx_locale = "de", epic_locale = "de", },
	{ value = "Hungarian", text = T(646055054297, "Hungarian"), ps_locale = "hu-HU", locale = "hu-HU", pdx_locale = "hu", epic_locale = false, },
	{ value = "Indonesian", text = T(596539604344, "Indonesian"), ps_locale = "id-ID", locale = "id-ID", pdx_locale = "id", epic_locale = false, },
	{ value = "Italian", text = T(330877865785, "Italian"), ps_locale = "it-IT", locale = "it-IT", pdx_locale = "it", epic_locale = "it", },
	{ value = "Japanese", text = T(527962174587, "Japanese"), ps_locale = "ja-JP", locale = "ja-JP", pdx_locale = "ja", epic_locale = "ja", },
	{ value = "Koreana", text = T(585811408758, "Korean"), ps_locale = "ko-KR", locale = "ko-KR", pdx_locale = "ko", epic_locale = "ko", },
	{ value = "Norwegian", text = T(369233670775, "Norwegian"), ps_locale = "nb-NO", locale = "nb-NO", pdx_locale = "no", epic_locale = "no", },
	{ value = "Polish", text = T(197791212449, "Polish"), ps_locale = "pl-PL", locale = "pl-PL", pdx_locale = "pl", epic_locale = "pl", },
	{ value = "Portuguese", text = T(661132086100, "Portuguese"), ps_locale = "pt-PT", locale = "pt-PT", pdx_locale = "pt", epic_locale = false, },
	{ value = "Romanian", text = T(375694388084, "Romanian"), ps_locale = "ro-RO", locale = "ro-RO", pdx_locale = "ro", epic_locale = false, },
	{ value = "Russian", text = T(794451731349, "Russian"), ps_locale = "ru-RU", locale = "ru-RU", pdx_locale = "ru", epic_locale = "ru", },
	{ value = "Schinese", text = T(465743231919, "Chinese (Simplified)"), ps_locale = "zh-Hans", locale = "zh-CN", pdx_locale = "zh", epic_locale = "zh-Hans", },
	{ value = "Spanish", text = T(277226277909, "Spanish (Spain)"), ps_locale = "es-ES", locale = "es-ES", pdx_locale = "es", epic_locale = "es-ES", },
	{ value = "Latam", text = T(342769994919, "Spanish (Latin America)"), ps_locale = "es-MX", locale = "es-MX", pdx_locale = "es", epic_locale = "es-MX", },
	{ value = "Swedish", text = T(487752404194, "Swedish"), ps_locale = "sv-SE", locale = "sv-SE", pdx_locale = "sv", epic_locale = "sv", },
	{ value = "Tchinese", text = T(508880261610, "Chinese (Traditional)"), ps_locale = "zh-Hant", locale = "zh-TW", pdx_locale = "zh", epic_locale = "zh-Hant", },
	{ value = "Thai", text = T(681908731541, "Thai"), ps_locale = "th-TH", locale = "th-TH", pdx_locale = "th", epic_locale = "th", },
	{ value = "Turkish", text = T(218295023775, "Turkish"), ps_locale = "tr-TR", locale = "tr-TR", pdx_locale = "tr", epic_locale = "tr", },
}

--- Indicates that the language names for Traditional Chinese and Simplified Chinese start with the "Tchinese" and "Schinese" family names, respectively.
LanguagesWithNamesStartWithFamily = {
	["Tchinese"] = true,
	["Schinese"] = true,
	
}

-- TODO(mitko): Move to PlayStationRules.lua when trophies building stop depending on DataInstances
-- Copied from:
-- https://ps4.siedev.net/resources/documents/Misc/current/Live_Item_Admin_Tool-Users_Guide/0003.html#__document_toc_00000006
-- https://ps4.siedev.net/resources/documents/Misc/current/Param_File_Editor-Users_Guide/0004.html#0_Ref368663318
--- Defines a mapping between PlayStation language codes and their corresponding language names.
-- The mapping is used to convert between PlayStation language codes and language names used in the game.
-- The table contains the language name, the corresponding PlayStation language code, and the PlayStation game code.
-- This mapping is used in various parts of the game to handle localization and language-specific functionality.
PlayStationLanguageCodes = {
	-- hg pack,    sfo,		gp
	"Japanese",   "00",	-- Japanese
	"English",    "01",	-- English (United States)
	"French",     "02",	-- French
	"Spanish",    "03",	-- Spanish
	"German",     "04",	-- German
	"Italian",    "05",	-- Italian
	"",           "06",	-- Dutch
	"Portuguese", "07",	-- Portuguese (Portugal)
	"Russian",    "08",	-- Russian
	"Koreana",    "09",	-- Korean
	"Tchinese",   "10",	-- Chinese (traditional)
	"Schinese",   "11",	-- Chinese (simplified)
	"",           "12",	-- Finnish
	"",           "13",	-- Swedish
	"",           "14",	-- Danish
	"",           "15",	-- Norwegian
	"Polish",     "16",	-- Polish
	"Brazilian",  "17",	-- Portuguese (Brazil)
	"English",    "18",	-- English (United Kingdom)
	"",           "19",	-- Turkish
	"Latam",      "20",	-- Spanish (Latin America)
	"French",     "22",	-- French (Canada)
	"Czech",      "23",	-- Czech
	"Hungarian",  "24",	-- Hungarian
	"",           "25",	-- Greek
	"Romanian",   "26",	-- Romanian
	"Thai",       "27",	-- Thai
	"",           "28",	-- Vietnamese
	"Indonesian", "29",	-- Indonesian
}

--- Converts a locale string to the corresponding PlayStation locale code.
---
--- @param locale string The locale string to convert.
--- @return string The PlayStation locale code corresponding to the input locale.
function LocaleToPlayStationLocale(locale)
	return table.find_value(AllLanguages, "locale", locale).ps_locale
end

---
--- Checks if a localization language is available.
---
--- @param language string The language to check for availability.
--- @return boolean True if the localization language is available, false otherwise.
function IsLocalizationLanguageAvailable(language)
	local folder_or_pack = 
		(config.UnpackedLocalization or config.UnpackedLocalization == nil and IsFSUnpacked())
		and ("svnProject/LocalizationOut/" .. language .. "/CurrentLanguage/")
		or ("Local/" .. language .. ".hpk")
	return io.exists(folder_or_pack)
end

---
--- Initializes the localization options for the game.
---
--- This function is called on game startup and sets up the available localization options.
--- It first adds an "Auto" option, which automatically selects the system language.
--- Then, it checks if the game is running on a desktop platform and if the `OptionsData` table exists.
--- If so, it iterates through the `AllLanguages` table and adds any available localization languages to the options list.
--- Finally, it sets the `OptionsData.Options.Language` table to the resulting list of localization options.
---
--- @return nil
function OnMsg.Autorun()
	local result = {
		{ value = "Auto", text = T(388818321440, "Auto"), iso_639_1 = "en" }
	}
	if Platform.desktop and rawget(_G, "OptionsData") then
		for _, language in ipairs(AllLanguages) do
			if IsLocalizationLanguageAvailable(language.value) then
				result[#result+1] = language
			end
		end
		OptionsData.Options.Language = result
	end
end

local list_separator = T(651365107459, --[[list separator]] ", ")

---
--- Concatenates a list of values into a single string, using the provided separator.
---
--- If no separator is provided, the default list separator from the localization system is used.
---
--- @param list table The list of values to concatenate.
--- @param separator string (optional) The separator to use between the list items.
--- @return string The concatenated string.
function TList(list, separator)
	return table.concat(list, separator or _InternalTranslate(list_separator))
end

-- given "abra keyword:cad abra", "keyword" ->  returns "abra  abra", "cad"
---
--- Extracts a value from a string based on a given needle pattern.
---
--- If the needle pattern is found in the haystack string, this function will extract the value that follows the needle pattern and return the haystack string with the extracted value removed.
---
--- @param haystack string The string to search and extract from.
--- @param needle string The pattern to search for in the haystack.
--- @return string, string The haystack string with the extracted value removed, and the extracted value.
function match_and_remove(haystack, needle)
	if not haystack then return end
	local extracted = string.match(haystack, needle .. "(%g*)")
	if extracted then
		local st, nd = string.find(haystack, needle .. extracted, 1, "plain")
		return string.sub(haystack, 1, st-1) .. string.sub(haystack, nd+1), extracted
	else
		return haystack
	end
end