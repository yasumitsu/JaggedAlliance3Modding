---------------
---- TABLE ----
---------------

--- Utility functions for working with tables.
---
--- @param find table.find
--- @param insert table.insert
--- @param remove table.remove
--- @param IsValid function that returns true if the input is valid, false otherwise
--- @param compute unknown
local find = table.find
local insert = table.insert
local remove = table.remove
local IsValid = rawget(_G, "IsValid") or function (x) return x or false end
local compute = compute

---
--- Formats a table into a string representation.
---
--- @param t table The table to format.
--- @param levels number The maximum number of levels to recurse into nested tables.
--- @param charsperline number The maximum number of characters per line in the output.
--- @param skipfns boolean If true, functions in the table will be skipped.
--- @return string The formatted table as a string.
---
function table.format(t, levels, charsperline, skipfns)
	local visited = {}
	local spaces  = "    "
	local key_output = { ["table"] = "{...}", ["function"] = "(function)", ["thread"] = "(thread)", ["userdata"] = "(userdata)"}

	local function format_internal(t, levels, tab)
		if next(t)==nil then
			return "{}"
		end
		if levels<=0 then
			return "{...}"
		end
		if visited[t] then
			return "{loop!}"
		end
		visited[t] = true

		-- Gather all keys and sort them appropriately - strings, numbers, then others (we'll output the table by key then)
		local keys = {}
		local function keysort_compare(key1, key2)
			if type(key1) == "string" then
				if type(key2) == "string" then
					return key1 < key2
				else
					return true
				end
			elseif type(key1) == "number" then
				if type(key2) == "number" then
					return key1 < key2
				elseif type(key2) == "string" then
					return false
				else
					return true
				end
			else
				if type(key2) == "number" or type(key2) == "string" then
					return false
				else
					return tostring(key1) < tostring(key2)
				end
			end
		end
		for k,v in pairs(t) do
			if not skipfns or type(v)~="function" then
				insert(keys, k)
			end
		end
		table.sort(keys, keysort_compare)

		-- Format key-value pairs in the output table
		local output = {}
		if #keys == #t then
			for i = 1, #t do
				local v = t[i]
				v = type(v) == "table" and format_internal(v, levels-1, tab..spaces) or tostring(v)
				insert(output, v)
			end
		else
			for i = 1, #keys do
				local k = keys[i]
				local v = t[k]
				k = key_output[type(k)] or tostring(k)
				v = type(v)=="table" and format_internal(v, levels-1, tab..spaces) or (IsPStr(v) and (v:flags() & const.pstrfBinary) ~= 0 and "(binary pstr)" or tostring(v))
				insert(output, k.." = "..v)
			end
		end
		-- If we can fit the table in one line, return that. Otherwise use tabs and new lines.
		local oneliner = "{ "..table.concat(output, ", ").." }"
		if charsperline and (charsperline<=0 or string.len(oneliner) <= charsperline) then
			return oneliner
		end
		return "{\n".. tab..spaces..table.concat(output, "\n"..tab..spaces).."\n" .. tab.."}"
	end

	return format_internal(t, levels or 1, "") 
end

---
--- Returns a table of values from the given table `t`.
---
--- If `field` is provided, the function will return a table of values from the `field` property of each entry in `t`.
--- If `sorted` is true, the returned table will be sorted.
---
--- @param t table The table to extract values from.
--- @param sorted boolean (optional) Whether to sort the returned table.
--- @param field string (optional) The field to extract values from.
--- @return table The table of values.
---
function table.values(t, sorted, field)
	local res = {}
	if t and next(t) ~= nil then
		if type(field) == "string" then
			for k, v in pairs(t) do
				res[#res+1] = v[field]
			end
		else
			for k, v in pairs(t) do
				res[#res+1] = v
			end
		end
		if sorted then
			table.sort(res)
		end
	end
	return res
end

---
--- Returns a table of keys from the given table `t`.
---
--- If `sorted` is true, the returned table will be sorted.
--- Additional keys can be inserted at specific positions using the `...` arguments.
---
--- @param t table The table to extract keys from.
--- @param sorted boolean (optional) Whether to sort the returned table.
--- @param ... any (optional) Additional keys to insert at specific positions.
--- @return table The table of keys.
---
function table.keys2(t, sorted, ...)
	local res = {}
	if t then
		for k,_ in pairs(t) do
			if type(k) ~= "number" then
				res[#res+1] = k
			end
		end
	end
	if sorted then
		table.sort(res)
	end
	for i = 1, select('#', ...) do
		local item = select(i, ...)
		insert(res, i, item)
	end
	return res
end

---
--- Removes the first entry from the given `array` that has the specified `field` and `value`.
---
--- @param array table The array to remove the entry from.
--- @param field string The field to match.
--- @param value any The value to match.
--- @return number, any The index of the removed entry, and the removed entry.
---
function table.remove_entry(array, field, value)
	local i = find(array, field, value)
	if i then
		return i, remove(array, i)
	end
end

---
--- Removes all entries from the given `array` that have the specified `field` and `value`.
---
--- If `value` is `nil`, it will remove all entries where the value of `field` is `true`.
---
--- @param array table The array to remove the entries from.
--- @param field string The field to match.
--- @param value any (optional) The value to match.
---
function table.remove_all_entries(array, field, value)
	if not array then
		return
	end
	if value == nil then
		for i = #array, 1, -1 do
			if array[i] == field then
				remove(array, i)
			end
		end
	else
		for i = #array, 1, -1 do
			if array[i][field] == value then
				remove(array, i)
			end
		end
	end
end

table.remove_value = table.remove_entry
table.remove_all_values = table.remove_all_entries

---
--- Removes all entries from the given `array` that match the provided `func` predicate.
---
--- @param array table The array to remove the entries from.
--- @param func function The predicate function to match entries against.
--- @param ... any Additional arguments to pass to the predicate function.
---
function table.remove_if(array, func, ...)
	for i = #(array or ""), 1, -1 do
		if compute(array[i], func, ...) then
			remove(array, i)
		end
	end
end

---
--- Reverses the order of elements in the given table.
---
--- @param t table The table to reverse.
--- @return table The reversed table.
---
function table.reverse(t)
	local l = #t + 1
	for i = 1, (l - 1) / 2 do
		t[i], t[l-i] = t[l-i], t[i]
	end
	return t
end

---
--- Creates a shallow or deep copy of the given table.
---
--- @param t table The table to copy.
--- @param deep boolean|number Whether to perform a deep copy. If a number is provided, it specifies the maximum depth of the copy.
--- @param filter function An optional function to filter the keys and values to be copied.
--- @return table A copy of the input table.
---
function table.copy(t, deep, filter)
	if not t then
		return {}
	end
	
	if type(t) ~= "table" then
		assert(false, "Attempt to table.copy a var of type " .. type(t))
		return {}
	end	

	if type(deep) == "number" then
		deep = deep > 1 and deep - 1
	end
	
	local meta = getmetatable(t)
	if meta then
		local __copy = rawget(meta, "__copy")
		if __copy then
			return __copy(t)
		elseif type(t.class) == "string" then
			assert(false, "Attempt to table.copy an object of class " .. t.class)
			return {}
		end
	end
	local copy = {}
	for k, v in pairs(t) do
		if deep then
			if type(k) == "table" then k = table.copy(k, deep) end
			if type(v) == "table" then v = table.copy(v, deep) end
		end
		if not filter or filter(k, v) then
			copy[k] = v
		end
	end
	return copy
end

---
--- Creates a shallow or deep copy of the given table.
---
--- @param t table The table to copy.
--- @param deep boolean|number Whether to perform a deep copy. If a number is provided, it specifies the maximum depth of the copy.
--- @param filter function An optional function to filter the keys and values to be copied.
--- @return table A copy of the input table.
---
function table.raw_copy(t, deep, filter)
	if not t then
		return {}
	end
	
	if type(t) ~= "table" then
		assert(false, "Attempt to table.copy a var of type " .. type(t))
		return {}
	end	

	if type(deep) == "number" then
		deep = deep > 1 and deep - 1
	end
	
	local copy = {}
	for k, v in pairs(t) do
		if deep then
			if type(k) == "table" then k = table.raw_copy(k, deep) end
			if type(v) == "table" then v = table.raw_copy(v, deep) end
		end
		if not filter or filter(k, v) then
			copy[k] = v
		end
	end
	return copy
end

---
--- Finds the index of the first element in the given array that matches the specified value or field-value pair.
---
--- @param array table The array to search.
--- @param field string|boolean The field to match against, or `false` to match the entire element.
--- @param value any The value to match against.
--- @return number|nil The index of the first matching element, or `nil` if no match is found.
---
function table.raw_find(array, field, value)
	if value == nil then
		value = field
		field = false
	end

	if field then
		for idx, arrvalue in ipairs(array) do
			if rawequal(arrvalue[field], value) then
				return idx
			end
		end
	else
		for idx, arrvalue in ipairs(array) do
			if rawequal(arrvalue, value) then
				return idx
			end
		end
	end
end

---
--- Sorts the given table in a stable manner using the provided comparison function.
---
--- @param t table The table to sort.
--- @param func function The comparison function to use for sorting. It should return `true` if the first argument should come before the second argument in the sorted order.
---
function table.stable_sort(t, func)
	local count = #(t or "")
	if count <= 1 then return end
	local idxs = createtable(0, count)
	for i, value in ipairs(t) do
		idxs[value] = i
	end
	table.sort(t, function(a, b)
		if func(a, b) then return true  end
		if func(b, a) then return false end
		return idxs[a] < idxs[b]
	end)
end

-- sortby(table, field)
-- sortby(table, func, cache)
-- sortby(table, table, default)
---
--- Sorts the given table in a stable manner using the provided comparison function.
---
--- @param table_to_sort table The table to sort.
--- @param f function|table The comparison function to use for sorting. It should return `true` if the first argument should come before the second argument in the sorted order. Alternatively, a table can be provided where the keys are the table elements and the values are the sort keys.
--- @param cache table An optional table to cache the sort keys, which can improve performance when the sort function is expensive to compute.
--- @return table The sorted table.
---
function table.sortby(table_to_sort, f, cache)
	if not table_to_sort then return end
	if type(f) == "function" then
		if cache then
			cache = {}
			for i = 1, #table_to_sort do
				local item = table_to_sort[i]
				cache[item] = f(item)
			end
			table.sort(table_to_sort, function(v1, v2)
				return cache[v1] < cache[v2]
			end)
		else
			table.sort(table_to_sort, function(v1, v2)
				return f(v1) < f(v2)
			end)
		end
	elseif type(f) == "table" then
		table.sort(table_to_sort, function(v1, v2)
			return (f[v1] or cache) < (f[v2] or cache)
		end)
	else
		table.sortby_field(table_to_sort, f)
	end
	return table_to_sort
end

---
--- Stably sorts the given table using the provided comparison function, with the given position as the reference point.
---
--- @param t table The table to sort.
--- @param pos any The reference position to use for the comparison function.
--- @param cmp function The comparison function to use for sorting. It should return `true` if the first argument should come before the second argument in the sorted order. Defaults to `IsCloser`.
--- @return table The sorted table.
---
function table.stable_dist_sort(t, pos, cmp)
	cmp = cmp or IsCloser
	return table.stable_sort(t, function(a, b)
		return cmp(pos, a, b)
	end)
end

---
--- Filters the given table based on the provided filter function or field.
---
--- @param t table The table to filter.
--- @param filter function|string The filter function or field name to use for filtering.
--- @return table A new table containing the filtered elements.
---
function table.filter(t, filter)
	local t1 = {}
	if type(filter) == "function" then
		for k, v in pairs(t) do
			if filter(k, v) then
				t1[k] = v
			end
		end
	else
		for k, v in pairs(t) do
			if v[filter] then
				t1[k] = v
			end
		end
	end
	return t1
end

---
--- Filters the given table based on the provided filter function or field.
---
--- @param t table The table to filter.
--- @param filter function|string The filter function or field name to use for filtering.
--- @param ... any Additional arguments to pass to the filter function.
--- @return table A new table containing the filtered elements.
---
function table.ifilter(t, filter, ...)
	local t1 = {}
	if type(filter) == "function" then
		for i, obj in ipairs(t) do
			if filter(i, obj, ...) then
				insert(t1, obj)
			end
		end
	else
		for i, obj in ipairs(t) do
			if obj[filter] then
				insert(t1, obj)
			end
		end
	end
	return t1
end

---
--- Splits the given table into two tables based on the provided filter function or field.
---
--- @param t table The table to split.
--- @param filter function|string The filter function or field name to use for splitting.
--- @param ... any Additional arguments to pass to the filter function.
--- @return table, table The two tables containing the filtered and unfiltered elements.
---
function table.isplit(t, filter, ...)
	local t1, t2 = {}, {} 
	if type(filter) == "function" then
		for i, obj in ipairs(t) do
			if filter(i, obj, ...) then
				insert(t1, obj)
			else
				insert(t2, obj)
			end
		end
	else
		for i, obj in ipairs(t) do
			if obj[filter] then
				insert(t1, obj)
			else
				insert(t2, obj)
			end
		end
	end
	
	return t1, t2
end

---
--- Checks if the given table `t` contains the provided value `f`.
---
--- If `f` is a function, it will be called with the key and value of each element in `t`, and the function should return `true` if the element matches the criteria.
---
--- If `f` is not a function, it will be compared directly to each value in `t`, and the first match will return `true`.
---
--- @param t table The table to search.
--- @param f function|any The value or function to search for.
--- @return boolean `true` if the value is found in the table, `false` otherwise.
---
function table.has_value(t, f)
	for key, value in next, t do
		if type(f) == "function" then
			if f(key, value) then return true end
		else
			if f == value then return true end
		end
	end
	return false
end

--- Applies a function or table mapping to each element of the given table `t`, returning a new table with the transformed elements.
---
--- If `f` is a function, it will be called with each element of `t` and any additional arguments provided, and the result will be stored in the new table.
---
--- If `f` is a table, the new table will contain the values from `f` corresponding to the elements of `t`.
---
--- If `f` is a string, the new table will contain the values of the field named `f` from each element of `t`.
---
--- @param t table The table to map over.
--- @param f function|table|string The mapping function, table, or field name to use.
--- @param ... any Additional arguments to pass to the mapping function.
--- @return table The new table with the transformed elements.
function table.imap(t, f, ...)
	local new = {}
	if type(f) == "function" then
		for i, obj in ipairs(t) do
			new[i] = f(obj, ...)
		end
	elseif type(f) == "table" then
		for i, obj in ipairs(t) do
			new[i] = f[obj]
		end
	else
		for i, obj in ipairs(t) do
			new[i] = obj[f]
		end
	end
	return new
end

--- Applies a function or table mapping to each element of the given table `t`, returning a new table with the transformed elements.
---
--- If `f` is a function, it will be called with each element of `t` and any additional arguments provided, and the result will be stored in the new table.
---
--- If `f` is a table, the new table will contain the values from `f` corresponding to the elements of `t`.
---
--- If `f` is a string, the new table will contain the values of the field named `f` from each element of `t`.
---
--- @param t table The table to map over.
--- @param f function|table|string The mapping function, table, or field name to use.
--- @param ... any Additional arguments to pass to the mapping function.
--- @return table The new table with the transformed elements.
function table.map(t, f, ...)
	local new = {}
	if type(f) == "function" then
		for k, v in pairs(t) do
			new[k] = f(v, ...)
		end
	elseif type(f) == "table" then
		for k, v in pairs(t) do
			new[k] = f[v]
		end
	else
		for k, v in pairs(t) do
			if type(v) == "table" then
				new[k] = v[f]
			end
		end
	end
	return new
end

--- Applies a function or table mapping to each element of the given table `t`, modifying the table in-place.
---
--- If `f` is a function, it will be called with each element of `t` and any additional arguments provided, and the result will be stored back in the table.
---
--- If `f` is a table, the elements of `t` will be replaced with the corresponding values from `f`.
---
--- If `f` is a string, the elements of `t` will be replaced with the values of the field named `f` from each element of `t`.
---
--- @param t table The table to map over.
--- @param f function|table|string The mapping function, table, or field name to use.
--- @param ... any Additional arguments to pass to the mapping function.
function table.imap_inplace(t, f, ...)
	if type(f) == "function" then
		for i, obj in ipairs(t) do
			t[i] = f(obj, ...)
		end
	elseif type(f) == "table" then
		for i, obj in ipairs(t) do
			t[i] = f[obj]
		end
	else
		for i, obj in ipairs(t) do
			t[i] = obj[f]
		end
	end
end

--- Applies a function or table mapping to each element of the given table `t`, modifying the table in-place.
---
--- If `f` is a function, it will be called with each element of `t` and any additional arguments provided, and the result will be stored back in the table.
---
--- If `f` is a table, the elements of `t` will be replaced with the corresponding values from `f`.
---
--- If `f` is a string, the elements of `t` will be replaced with the values of the field named `f` from each element of `t`.
---
--- @param t table The table to map over.
--- @param f function|table|string The mapping function, table, or field name to use.
--- @param ... any Additional arguments to pass to the mapping function.
function table.map_inplace(t, f, ...)
	if type(f) == "function" then
		for k, v in pairs(t) do
			t[k] = f(v, ...)
		end
	elseif type(f) == "table" then
		for k, v in pairs(t) do
			t[k] = f[v]
		end
	else
		for k, v in pairs(t) do
			if type(v) == "table" then
				new[k] = v[f]
			end
		end
	end
end

--- Maps a table `t` using the given `format` string.
---
--- @param t table The table to map.
--- @param format string The format string to apply to each element of `t`.
--- @return table A new table with the elements of `t` formatted according to `format`.
function table.mapf(t, format)
	local new = {}
	for k,v in pairs(t) do
		new[k] = string.format(format, v)
	end
	return new
end

--- Returns a new table containing only the unique elements from the given table.
---
--- @param table table The table to get unique elements from.
--- @return table A new table containing only the unique elements from the input table.
function table.get_unique(table)
	local result, seen = {}, {}
	for _, item in ipairs(table) do
		if not seen[item] then
			seen[item] = true
			result[#result + 1] = item
		end
	end
	return result
end

--- Finds the first index of a value in an array that matches a given field and value.
---
--- @param array table The array to search.
--- @param field string The field name to match.
--- @param value any The value to match.
--- @return any, number The matched value and its index, or nil if not found.
function table.find_value(array, field, value)
	local idx = find(array, field, value)
	return idx and array[idx], idx
end

--- Calls a method or function on the given `value` with the provided arguments.
---
--- If `method` is a string, it is assumed to be the name of a method on `value` and is called with `value` as the first argument, followed by the provided arguments.
--- If `method` is a function, it is called with `value` as the first argument, followed by the provided arguments.
---
--- @param value any The value to call the method or function on.
--- @param method string|function The method name or function to call.
--- @param ... any The arguments to pass to the method or function.
--- @return any The result of calling the method or function.
local function call_for(value, method, ...)
	local res
	if type(method) == "string" then
		res = value[method](value, ...)
	elseif type(method) == "function" then
		res = method(value, ...)
	end
	return res
end

--- Calls a method or function on each element of the given table.
---
--- For each element in the table, the specified `method` is called with the element as the first argument, followed by any additional arguments provided.
--- If the `method` call returns a non-nil value, the loop is terminated and that value is returned.
---
--- @param table table The table to iterate over.
--- @param method string|function The method name or function to call on each element.
--- @param ... any The additional arguments to pass to the method or function.
--- @return any The first non-nil value returned by a `method` call, or nil if no such value was returned.
function table.call_foreach(table, method, ...)
	for k, v in pairs(table) do
		local r = call_for(v, method, ...)
		if r then return r end
	end
end

--- Calls a method or function on each element of the given table.
---
--- For each element in the table, the specified `method` is called with the element as the first argument, followed by any additional arguments provided.
--- If the `method` call returns a non-nil value, the loop is terminated and that value is returned.
---
--- @param table table The table to iterate over.
--- @param method string|function The method name or function to call on each element.
--- @param ... any The additional arguments to pass to the method or function.
--- @return any The first non-nil value returned by a `method` call, or nil if no such value was returned.
function table.call_foreachi(table, method, ...)
	for _, v in ipairs(table) do
		local r = call_for(v, method, ...)
		if r then return r end
	end
end

--- Compacts a table by removing any nil values and shifting all non-nil values to the beginning of the table.
---
--- This function modifies the original table in-place. It iterates through the table, copying any non-nil values to the beginning of the table, and then removing any remaining values at the end of the table.
---
--- @param t table The table to compact.
function table.compact(t)
	if not t then return end
	local k = 1
	local count = table.maxn(t)
	for i = 1, count do
		if t[i] then
			if k < i then
				t[k] = t[i]
			end
			k = k + 1
		end
	end
	for i = k, count do
		t[i] = nil
	end
end

--- Reindexes a table based on a specified index function.
---
--- This function takes a table and an optional index function, and returns a new table where the keys are the result of applying the index function to each element of the original table. If the index function returns `nil` for an element, that element is not included in the new table.
---
--- If `multiple_record` is `true`, the new table will contain lists of indices for each unique key, rather than a single value.
---
--- @param table table The table to reindex.
--- @param index_by function|string The function or field name to use for indexing the table. If `nil`, the elements themselves are used as the keys.
--- @param multiple_record boolean If `true`, the new table will contain lists of indices for each unique key.
--- @return table The reindexed table.
function table.reindex(table, index_by, multiple_record)
	local AddIndex
	local res = {}
	if not multiple_record then
		AddIndex = function(k, v)
			res[k] = v
		end
	else
		AddIndex = function(k, v)
			local t = res[k] or {}
			if not res[k] then
				res[k] = t
			end
			t[#t + 1] = v
		end
	end
	local CalcIndex =
		type(index_by) == "function" and
			index_by or (
			index_by and
			function(e)
				return type(e) == "table" and e[index_by] or e
			end or
			function(e)
				return e
			end )

	for k, v in pairs(table) do
		local new_key = CalcIndex(v)
		if new_key ~= nil then
			AddIndex(new_key, k)
		end
	end

	return res
end

--- Slices a table, returning a new table containing the elements from the original table between the specified start and finish indices.
---
--- @param t table The table to slice.
--- @param start number The starting index for the slice (default is 1).
--- @param finish number The ending index for the slice (default is the length of the table).
--- @return table A new table containing the sliced elements.
function table.slice(t, start, finish)
	local t1 = {}
	local st = #t
	start = start or 1
	if not finish then
		finish = st
	elseif finish < 0 then
		finish = st + finish + 1
	end
	local oi = 1
	for i=start, finish do
		t1[oi] = t[i]
		oi = oi + 1
	end
	return t1
end

local __value_hash
--- Calculates a hash value for a table, recursively hashing the keys and values.
---
--- @param tbl table The table to hash.
--- @param recursions number The maximum depth of recursion when hashing nested tables (default is -1, which means no limit).
--- @param hash_map table An optional table used to cache hash values for tables.
--- @return number The hash value for the table.
local function __table_hash(tbl, recursions, hash_map)
	local hash
	if next(tbl) ~= nil then
		local key_hash, value_hash
		for key, value in sorted_pairs(tbl) do
			key_hash, hash_map = __value_hash(key, recursions, hash_map)
			value_hash, hash_map = __value_hash(value, recursions, hash_map)
			hash = xxhash(hash, key_hash, value_hash)
		end
	end
	return hash
end

--- Calculates a hash value for a given value, recursively hashing the keys and values if the value is a table.
---
--- @param value any The value to hash.
--- @param recursions number The maximum depth of recursion when hashing nested tables (default is -1, which means no limit).
--- @param hash_map table An optional table used to cache hash values for tables.
--- @return number The hash value for the value.
--- @return table The updated hash map.
__value_hash = function(value, recursions, hash_map)
	local value_type = type(value)
	local value_hash
	if value_type == "table" then
		value_hash = hash_map and hash_map[value]
		if not value_hash and recursions ~= 0 then
			hash_map = hash_map or {}
			hash_map[value] = true
			value_hash = __table_hash(value, recursions - 1, hash_map)
			hash_map[value] = value_hash
		end
	elseif value_type == "function" then
		value_hash = xxhash(tostring(value))
	elseif value_type ~= "thread" then
		value_hash = xxhash(value)
	end
	return value_hash, hash_map
end

--- Calculates a hash value for a table.
---
--- @param tbl table The table to hash.
--- @param hash number The initial hash value.
--- @param depth number The maximum depth of recursion when hashing nested tables (default is -1, which means no limit).
--- @return number The hash value for the table.
function table.hash(tbl, hash, depth)
	return xxhash(hash, __table_hash(tbl, depth or -1))
end

--- Calculates the sum of the values in a table, optionally summing the values of a specified member field.
---
--- @param tbl table The table to sum.
--- @param member string|nil The name of the member field to sum, or nil to sum the table elements directly.
--- @return number The sum of the values in the table.
function table.sum(tbl, member)
	local sum = 0
	if member == nil then
		for _, elem in ipairs(tbl) do
			sum = sum + (tonumber(elem) or 0)
		end
	else
		for _, elem in ipairs(tbl) do
			sum = sum + (tonumber(elem[member]) or 0)
		end
	end
	return sum
end

--- Counts the number of elements in an array that match a given field and value.
---
--- @param array table The array to count elements in.
--- @param field string|function The field to check, or a function to test each element.
--- @param value any The value to match, or nil to match any non-nil value.
--- @return number The count of matching elements.
function table.array_count(array, field, value)
	if not array then return end
	local c = 0
	if value == nil then
		value = field
		if type(value) == 'function' then
			for i = 1, #array do
				if value(array[i]) then c = c + 1 end
			end
		elseif value ~= nil then
			for i = 1, #array do
				if value == array[i] then c = c + 1 end
			end
		else
			return #array
		end
	else
		for i = 1, #array do
			if value == array[i][field] then c = c + 1 end
		end
	end
	return c
end

--- Finds the minimum value in a table, optionally applying a computation to each element before comparison.
---
--- @param t table The table to find the minimum value in.
--- @param instruction function|nil The function to apply to each element before comparison, or nil to use the element directly.
--- @param ... any Additional arguments to pass to the `instruction` function.
--- @return any, number, any The minimum value, its index, and the computed minimum value.
function table.min(t, instruction, ...)
	local min_value, min_i
	if instruction ~= nil then
		for i, value in ipairs(t) do
			local value = compute(value, instruction, ...)
			if value and (not min_value or value > min_value) then
				min_value, min_i = value, i
			end
		end
	else
		for i, value in ipairs(t) do
			if value and (not min_value or value > min_value) then
				min_value, min_i = value, i
			end
		end
	end
	return min_i and t[min_i], min_i, min_value
end

--- Finds the maximum value in a table, optionally applying a computation to each element before comparison.
---
--- @param t table The table to find the maximum value in.
--- @param instruction function|nil The function to apply to each element before comparison, or nil to use the element directly.
--- @param ... any Additional arguments to pass to the `instruction` function.
--- @return any, number, any The maximum value, its index, and the computed maximum value.
function table.max(t, instruction, ...)
	local max_value, max_i
	if instruction ~= nil then
		for i, value in ipairs(t) do
			local value = compute(value, instruction, ...)
			if value and (not max_value or value > max_value) then
				max_value, max_i = value, i
			end
		end
	else
		for i, value in ipairs(t) do
			if value and (not max_value or value > max_value) then
				max_value, max_i = value, i
			end
		end
	end
	return max_i and t[max_i], max_i, max_value
end

--- Shuffles the elements of the given table `tbl` in-place.
---
--- @param tbl table The table to shuffle.
--- @param func_or_seed function|string|number The random seed or a function that returns a random seed. If not provided, a default seed of "shuffle" is used.
--- @return number The number of elements shuffled.
function table.shuffle(tbl, func_or_seed)
	return table.shuffle_first(tbl, nil, func_or_seed or "shuffle")
end

-- chooses randomly the first count elements of the array t
local BraidRandom = BraidRandom
--- Shuffles the first `count` elements of the given table `t` in-place.
---
--- @param t table The table to shuffle.
--- @param count number The number of elements to shuffle. If `nil`, all elements will be shuffled.
--- @param seed function|string|number The random seed or a function that returns a random seed. If not provided, a default seed of "shuffle_first" is used.
--- @return number The number of elements shuffled.
function table.shuffle_first(t, count, seed)
	if type(seed) == "function" then
		seed = seed()
	end
	if not seed or type(seed) == "string" then
		seed = InteractionRand(nil, seed or "shuffle_first")
	end
	if type(seed) ~= "number" then
		assert(false, "Rand function or seed expected!")
		return
	end
	local elements = #t
	count = Min(elements - 1, count)
	local j
	for i = 1, count do
		j, seed = BraidRandom(seed, i, elements)
		t[i], t[j] = t[j], t[i]
	end
	return count
end

--- Calculates the average of the values in the given table `tbl`, optionally filtering by the given `field`.
---
--- If `field` is provided, the function will sum the values of the `field` property of each element in `tbl` and divide by the number of elements with a non-nil `field` value.
---
--- If `field` is not provided, the function will sum the values of each element in `tbl` and divide by the number of non-nil elements.
---
--- @param tbl table The table to calculate the average of.
--- @param field string The field to filter the table by, or nil to use the entire table.
--- @return number|nil The average of the values in the table, or nil if the table is empty.
function table.avg(tbl, field)
	if field then
		local l = #tbl
		if l > 1 then
			local sum = tbl[1][field]
			for i = 2, l do
				sum = sum + tbl[i][field]
			end
			return sum / l
		end
		return tbl[1] and tbl[1][field] or 0
	else
		local l = #tbl
		if l > 1 then
			local sum = tbl[1]
			for i = 2, l do
				sum = sum + tbl[i]
			end
			return sum / l
		end
		return tbl[1]
	end
end

-- sums over entries with available field(may return nil)
--- Calculates the average of the available values in the given table `tbl`, optionally filtering by the given `field`.
---
--- If `field` is provided, the function will sum the values of the `field` property of each element in `tbl` that has a non-nil `field` value, and divide by the number of elements with a non-nil `field` value.
---
--- If `field` is not provided, the function will sum the values of each non-nil element in `tbl` and divide by the number of non-nil elements.
---
--- @param tbl table The table to calculate the average of.
--- @param field string The field to filter the table by, or nil to use the entire table.
--- @return number|nil The average of the available values in the table, or nil if the table is empty or contains no available values.
function table.avg_avail(tbl, field)
	local len = #tbl
	local sum, cnt = 0, 0
	if field then
		for i = 1, len do
			local val = tbl[i][field]
			if val then
				sum = sum + val
				cnt = cnt + 1
			end
		end
	else
		for i = 1, len do
			local val = tbl[i]
			if val then
				sum = sum + tbl[i]
				cnt = cnt + 1
			end
		end
	end
	
	return (cnt > 0) and sum / cnt or nil
end


----

-- set table[param1][param2]..[paramN-1] = paramN
--- Sets a value in a table at the given path.
---
--- If the path does not exist, it will be created.
---
--- @param t table The table to set the value in.
--- @param param1 any The first part of the path to the value.
--- @param param2 any The value to set.
--- @param ... any Additional parts of the path to the value.
--- @return table The modified table.
function table_set(t, param1, param2, ...)
	-- Implementation details omitted for brevity
end
local function table_set(t, param1, param2, ...)
	if select("#", ...) == 0 then
		if not t then
			return { [param1] = param2 }
		end
		t[param1] = param2
	else
		if not t then
			return { [param1] = table_set(nil, param2, ...) }
		end
		t[param1] = table_set(t[param1], param2, ...)
	end
	return t
end
table.set = table_set

-- returns table[param1][param2]..[paramN]
--- Returns the value at the given path in the table.
---
--- If the path does not exist, it will return `nil`.
---
--- @param t table The table to get the value from.
--- @param key any The first part of the path to the value.
--- @param ... any Additional parts of the path to the value.
--- @return any The value at the given path, or `nil` if the path does not exist.
local function table_get(t, key, ...)
	if key == nil then return t end
	if type(t) ~= "table" then return end
	return table_get(t[key], ...)
end
table.get = table_get

--- Creates a new table and adds the given value to it.
---
--- If the input table `t` is `nil`, a new table is created with the given value `v` as the first element.
--- If the input table `t` is not `nil`, the given value `v` is appended to the end of the table.
---
--- @param t table The input table to add the value to, or `nil` to create a new table.
--- @param v any The value to add to the table.
--- @return table The modified or new table.
function table.create_add(t, v)
	if not t then return { v } end
	t[#t + 1] = v
	return t
end

--- Creates a new table and adds the given value to it, if the value is not already in the table.
---
--- If the input table `t` is `nil`, a new table is created with the given value `v` as the first element.
--- If the input table `t` is not `nil`, the given value `v` is appended to the end of the table if it does not already exist in the table.
---
--- @param t table The input table to add the value to, or `nil` to create a new table.
--- @param v any The value to add to the table.
--- @return table The modified or new table.
function table.create_add_unique(t, v)
	if not t then return { v } end
	if not find(t, v) then t[#t + 1] = v end
	return t
end

--- Creates a new table and adds the given key-value pair to it, or updates the value for the given key in an existing table.
---
--- If the input table `t` is `nil`, a new table is created with the given key `k` and value `v` as the first element.
--- If the input table `t` is not `nil`, the given key `k` and value `v` are added to the table, or the value for the given key is updated if it already exists.
---
--- @param t table The input table to add the key-value pair to, or `nil` to create a new table.
--- @param k any The key to add or update in the table.
--- @param v any The value to associate with the key.
--- @return table The modified or new table.
function table.create_add_set(t, k, v)
	v = v or true
	if not t then return { k, [k] = v } end
	local prev = t[v]
	if prev ~= v then
		if not prev then
			t[#t + 1] = k
		end
		t[k] = v
	end
	return t
end

--- Creates a new table and adds the given key-value pair to it, or updates the value for the given key in an existing table.
---
--- If the input table `t` is `nil`, a new table is created with the given key `k` and value `v` as the first element.
--- If the input table `t` is not `nil`, the given key `k` and value `v` are added to the table, or the value for the given key is updated if it already exists.
---
--- @param t table The input table to add the key-value pair to, or `nil` to create a new table.
--- @param k any The key to add or update in the table.
--- @param v any The value to associate with the key.
--- @return table The modified or new table.
function table.create_set(t, k, v)
	if not t then return { [k] = v } end
	t[k] = v
	return t
end

---
--- Removes an element from the given table `t` at index `i` and rotates the remaining elements to fill the gap.
---
--- If the table `t` is empty or the index `i` is out of bounds, the function will return without modifying the table.
---
--- @param t table The table to remove and rotate the element from.
--- @param i integer The index of the element to remove.
--- @return integer The new length of the table after the element is removed.
function table.remove_rotate(t, i)
	local n = #(t or "")
	assert(not i or i > 0 and i <= n)
	if n == 0 or not i or i <= 0 or i > n then return end
	t[i] = t[n]
	t[n] = nil
	return n - 1
end

----

--- Sets default values for the keys in the given table `t` based on the `defaults` table.
---
--- If the `defaults` table is provided, this function will iterate through the key-value pairs in `defaults` and set the corresponding key-value pair in `t` if the key does not already exist in `t`. If the value in `defaults` is a table and `bDeep` is true, the function will recursively copy the table using `table.copy()`.
---
--- @param t table The table to set the default values for.
--- @param defaults table The table containing the default values to set.
--- @param bDeep boolean If true, recursively copy any table values in `defaults`.
--- @return table The modified `t` table with the default values set.
function table.set_defaults(t, defaults, bDeep)
	if defaults then
		for k, v in pairs(defaults) do
			if nil == rawget(t, k) then
				if type(v) == "table" and not getmetatable(v) then
					t[k] = table.copy(v, bDeep)
				else
					t[k] = v
				end
			elseif type(t[k]) == "table" and type(v) == "table" and not getmetatable(v) then
				table.set_defaults(t[k], v, bDeep)
			end
		end
	end
	return t
end

---
--- Appends the elements of `t2` to the end of `t`.
---
--- If `t` or `t2` is `nil`, the function will return `t` without modifying it.
---
--- @param t table The table to append the elements to.
--- @param t2 table The table containing the elements to append.
--- @return table The modified `t` table with the elements of `t2` appended.
function table.iappend(t, t2)
	if t and t2 then
		local n, n2 = #t, #t2
		for i=1,n2 do
			t[n + i] = t2[i]
		end
	end
	return t
end

--- Checks if the two given tables `a` and `b` have any common keys.
---
--- @param a table The first table to check.
--- @param b table The second table to check.
--- @return boolean True if the tables have any common keys, false otherwise.
function table.common_keys(a, b)
	for k in pairs(a) do
		if b[k] ~= nil then
			return true
		end
	end
end

--- Checks if the table `a` is a subset of the table `b`.
---
--- @param a table The first table to check.
--- @param b table The second table to check.
--- @return boolean True if `a` is a subset of `b`, false otherwise.
function table.is_subset(a, b)
	for k in pairs(a) do
		if b[k] == nil then
			return false
		end
	end
	return true
end

---
--- Checks if the table `a` is a subset of the table `b`.
---
--- This function first inverts the tables `a` and `b` using `table.invert()`, then checks if the inverted table `a` is a subset of the inverted table `b` using `table.is_subset()`.
---
--- @param a table The first table to check.
--- @param b table The second table to check.
--- @return boolean True if `a` is a subset of `b`, false otherwise.
function table.array_isubset(a, b)
	local ainv = table.invert(a)
	local binv = table.invert(b)
	return table.is_subset(ainv, binv)
end

---
--- Inserts a new element `n` into the table `t` in a sorted order based on the `field` property of each element.
---
--- @param t table The table to insert the new element into.
--- @param n table The new element to insert.
--- @param field string The name of the field to use for sorting.
--- @return integer The index at which the new element was inserted.
function table.insert_sorted(t, n, field)
	if #t == 0 then
		t[1] = n
		return 1
	end
	local top, bottom = 1, #t+1
	local v = n[field]
	while true do
		local i = (top + bottom) / 2
		if v < t[i][field] then
			bottom = i
			if bottom == top then
				insert(t, top, n)
				return top
			end
		else
			top = i + 1
			if bottom == top then
				insert(t, top, n)
				return top
			end
		end
	end	
end

table.strlen = TableStrlen

---
--- Inserts a new element `x` into the table `t` if it does not already exist in the table.
---
--- @param t table The table to insert the new element into.
--- @param x any The new element to insert.
--- @return boolean True if the element was inserted, false otherwise.
function table.insert_unique(t, x)
	if not find(t, x) then
		insert(t, x)
		return true
	end
end

-- string.match on all elements in a table
---
--- Searches a table `t` for a string `match` and returns the first match found.
---
--- @param t table The table to search.
--- @param match string The string to search for.
--- @param bCaseSensitive boolean Whether the search should be case-sensitive.
--- @param visited table A table of visited elements to avoid circular references.
--- @return boolean, table True if a match was found, and a table containing the matched key and the type of match ("key" or "value").
---
function table.match(t, match, bCaseSensitive, visited)
	local found = false
	visited = visited or {}
	if visited[t] then return false end
	match = bCaseSensitive and match or string.lower(match)
	for k,v in pairs(t) do
		visited[v] = true
		local value
		if type(k)=="string" then
			value = bCaseSensitive and k or string.lower(k)
			if string.match(value, match) then
				return true, {k, match="key"} 
			end
		end
		if type(v) ~= "table" then
			value = tostring(v)
			value = bCaseSensitive and value or string.lower(value)
			if string.match(value, match) then
				return true, {k, match="value"} 
			end
		else --for tables
			local f, path = table.match(v, match, bCaseSensitive, visited)
			if f then
				insert(path, 1, k)
				return true, path
			end
		end
	end
end

--- Returns a random element from the given array, along with its index and an updated seed value.
---
--- @param array table The array to select a random element from.
--- @param seed number An optional seed value to use for the random number generation.
--- @return any, number, number The randomly selected element, its index, and the updated seed value.
function table.rand(array, seed)
	if #(array or "") == 0 then
		return nil, nil, seed
	end
	local idx
	if seed then
		idx, seed = BraidRandom(seed, #array)
	else
		idx = AsyncRand(#array)
	end
	idx = idx + 1
	return array[idx], idx, seed
end

--- Returns a random element from the given array, along with its index.
---
--- @param array table The array to select a random element from.
--- @param ... any Optional arguments to pass to the random number generator.
--- @return any, number The randomly selected element and its index.
function table.interaction_rand(array, ...)
	if #(array or "") > 0 then
		local idx = 1 + InteractionRand(#array, ...)
		return array[idx], idx
	end
end

-- returns a table where keys are encountered values of t[i][pr] or pr(t[i]), and values are how many times each value was encountered
--- Returns a histogram of the values in the given table, using the specified key or function.
---
--- @param t table The table to generate the histogram for.
--- @param pr string|function The key to use for the histogram, or a function to generate the key.
--- @return table The histogram, where the keys are the unique values and the values are the counts.
function table.histogram(t, pr)
	local h = {}
	if type(pr) == "string" then
		for i=1,#t do
			local o = t[i]
			local key = o[pr]
			local value = h[key]
			if value then
				h[key] = value + 1
			else
				h[key] = 1
			end
		end
	elseif type(pr) == "function" then
		for i=1,#t do
			local o = t[i]
			local key = pr(o)
			local value = h[key]
			if value then
				h[key] = value + 1
			else
				h[key] = 1
			end
		end
	end
	return h
end

--- Returns a sorted histogram of the values in the given table, using the specified key or function.
---
--- @param t table The table to generate the histogram for.
--- @param pr string|function The key to use for the histogram, or a function to generate the key.
--- @param f function An optional function to use for sorting the histogram. If not provided, the histogram will be sorted by the count in ascending order.
--- @return table The sorted histogram, where the keys are the unique values and the values are the counts.
function table.sorted_histogram(t, pr, f)
	local h = table.histogram(t, pr)
	local hs = {}
	local i = 0
	for k,v in pairs(h) do
		hs[i] = { k, v }
		i = i+1
	end
	table.sort( hs, f or function(a, b) return a[2] < b[2] end)
	return hs
end

-- Checks if a table can safely be converted to Lua code
--		(can't do it if the table references another table twice, excepting T-s)
--- Checks if a table can safely be converted to Lua code.
---
--- This function recursively checks a table to ensure that it can be safely converted to Lua code. It checks for the following conditions:
--- - The table does not reference itself (directly or indirectly)
--- - The table does not reference another table more than once, except for tables of type `T` (which are allowed to be referenced multiple times)
---
--- @param t table The table to check
--- @param reftbl table (optional) A table to keep track of referenced tables and their paths
--- @param path table (optional) The current path to the table being checked
--- @return boolean, table, table True if the table can be safely converted, the path to the table, and the path to the duplicate reference (if any)
function table.check_for_toluacode(t, reftbl, path)
	if not reftbl then reftbl = {} end
	if not path then path = {"root"} end
	
	if IsT(t) then return true end
	if reftbl[t] then 
		return false, path, reftbl[t] 
	end
	reftbl[t] = table.copy(path)
	for k,v in pairs(t) do
		path[#path + 1] = k
		if type(k) == "table" then
			local check, path1, path2 = table.check_for_toluacode(k, reftbl, path)
			if not check then 
				return false, path1, path2
			end
		end
		if type(v) == "table" then
			local check, path1, path2 = table.check_for_toluacode(v, reftbl, path)
			if not check then 
				return false, path1, path2
			end
		end
		path[#path] = nil
	end
	return true
end

--- Combines two tables into a new table, removing any duplicate elements.
---
--- This function takes two tables as input and returns a new table that contains all the unique elements from both input tables.
---
--- @param t1 table The first input table.
--- @param t2 table The second input table.
--- @return table The combined table with unique elements.
function table.union(t1, t2)
	local used = {}
	local union = {}

	for _, obj in ipairs(t1) do
		if not used[obj] then
			union[#union + 1] = obj
			used[obj] = true
		end
	end

	for _, obj in ipairs(t2) do
		if not used[obj] then
			union[#union + 1] = obj
			used[obj] = true
		end
	end

	return union
end

--- Subtracts the elements of one table from another, returning a new table with the unique elements.
---
--- This function takes two tables as input and returns a new table that contains all the elements from the first table that are not present in the second table.
---
--- @param t1 table The first input table.
--- @param t2 table The second input table.
--- @return table The new table with the unique elements from the first table.
function table.subtraction(t1, t2)
	local used = {}

	for _, obj in ipairs(t2) do
		used[obj] = true
	end

	local sub = {}
	for _, obj in ipairs(t1) do
		if not used[obj] then
			used[obj] = true			-- to avoid repeating the same element
			sub[#sub + 1] = obj
		end
	end

	return sub
end

--- Computes the intersection of two tables, returning a new table with the common elements.
---
--- This function takes two tables as input and returns a new table that contains all the elements that are present in both input tables.
---
--- @param t1 table The first input table.
--- @param t2 table The second input table.
--- @return table The new table with the common elements from the input tables.
function table.intersection(t1, t2)
	local intersection = {}
	for _, obj in ipairs(t1) do
		if find(t2, obj) then
			intersection[#intersection + 1] = obj
		end
	end
	return intersection
end

if FirstLoad then
	table_change_stack = {}
end

-- change a bunch of keys in a table, then restore them all, controlled by reasons
-- it's safe to restore in arbitrary order only if the changed parameters are different
-- e.g. when opening menu, call table.change(hr, "menu", { EnablePostprocess = 0 })
-- when closing, call table.restore(hr, "menu")

---
--- Changes the values of the specified keys in the given table, and keeps track of the changes in a stack.
---
--- This function takes a table `t`, a reason string `reason`, and a table of `values` to change. It first checks if there is an existing entry in the `table_change_stack` for the given table and reason. If so, it updates the existing entry with the new values. If not, it creates a new entry in the stack with the old and new values.
---
--- @param t table The table to change.
--- @param reason string The reason for the change.
--- @param values table The new values to set in the table.
function table.change(t, reason, values)
	local stack = table_change_stack[t] or {}
	local idx = find(stack, "reason", reason)
	if idx then
		local entry = stack[idx]
		for k,v in pairs(values) do
			if entry.old[k] == nil then
				entry.old[k] = t[k] or false
			end
			entry.new[k] = v
			t[k] = v
		end
	else
		local entry = { old = {}, new = values, reason = reason }
		for k,v in pairs(values) do
			entry.old[k] = t[k] or false
			t[k] = v
		end
		insert(stack, entry)
		table_change_stack[t] = stack
	end
end

---
--- Checks if the given table has any changes tracked for the specified reason.
---
--- @param t table The table to check for changes.
--- @param reason string The reason to check for changes.
--- @return number|nil The index of the change entry in the table_change_stack, or nil if no changes are found.
function table.changed(t, reason)
	local stack = table_change_stack[t]
	return stack and find(stack, "reason", reason)
end

---
--- Discards the restore entry for the specified table and reason.
---
--- This function removes the restore entry for the given table and reason from the `table_change_stack`. This effectively discards any changes that were tracked for that table and reason.
---
--- @param t table The table to discard the restore entry for.
--- @param reason string The reason to discard the restore entry for.
function table.discard_restore(t, reason)
	local idx = table.changed(t, reason)
	if idx then
		remove(table_change_stack[t], idx)
	end
end

---
--- Updates the base table with the provided values, preserving any existing changes tracked in the table_change_stack.
---
--- This function updates the base table `t` with the provided `values` table, while preserving any existing changes that have been tracked in the `table_change_stack` for that table. It ensures that any changes made to the table are properly reflected in the change tracking stack.
---
--- @param t table The table to update.
--- @param values table The new values to set in the table.
function table.change_base(t, values)
	local stack = table_change_stack[t] or empty_table
	if #stack ~= 0 then
		for k,v in pairs(values) do
			for idx=1,#stack do
				if stack[idx].old[k] ~= nil then
					stack[idx].old[k] = v
					break
				elseif idx == #stack then
					t[k] = v
				end
			end
		end
	else
		for k,v in pairs(values) do
			t[k] = v
		end
	end
end

---
--- Restores the table to the state it was in before the specified reason for change.
---
--- This function restores the table `t` to the state it was in before the change that was tracked with the specified `reason`. It gathers up all the changes that were made since the specified change reason and applies them to the table at once, to prevent issues with toggling boolean variables that may have C++ setters.
---
--- @param t table The table to restore.
--- @param reason string The reason to restore the table to.
--- @param ignore_error boolean If true, no assertion error will be thrown if the specified reason is not found in the change stack.
function table.restore(t, reason, ignore_error)
	local stack = table_change_stack[t]
	local idx = stack and find(stack, "reason", reason)
	assert(idx or ignore_error)
	if not idx then return end
	
	-- Gather up changes across all modifications and
	-- apply them at once to prevent toggling true/false variables
	-- which could call C++ setters
	local changes = {}
	for i=#stack,idx,-1 do
		for k,v in pairs(stack[i].old) do
			changes[k] = v
		end
	end
	for i=idx+1,#stack do
		for k,v in pairs(stack[i].new) do
			changes[k] = v
		end
	end
	for k, v in pairs(changes) do
		if t[k] ~= v then
			t[k] = v
		end
	end
	
	local entry = stack[idx]
	local next = stack[idx + 1]
	if next then
		for k, v in pairs(entry.old) do
			next.old[k] = v
		end
	end
	remove(stack, idx)
	if #stack == 0 then
		table_change_stack[t] = nil
	end
end

---
--- Saves the global names of tables that are about to be recreated during a Lua reload.
---
--- When Lua is reloaded, some tables that have had changes tracked may be recreated. This function saves the global names of those tables so that the changes can be reapplied to the new tables after the reload.
---
--- @function OnMsg.ReloadLua
--- @return nil
function OnMsg.ReloadLua()
	-- some of the stored changed tables are about to be created anew, save their names to identify them later
	local common_names = { "_G", "config", "hr" }
	for tbl, stack in pairs(table_change_stack) do
		local name
		for _, common_name in ipairs(common_names) do
			if tbl == _G[common_name] then
				name = common_name
				break
			end
		end
		name = name or GetGlobalName(tbl)
		stack.global_name = name
	end
end
---
--- Reapplies table changes after a Lua reload.
---
--- When Lua is reloaded, some tables that have had changes tracked may be recreated. This function reapplies the tracked changes to the new tables after the reload.
---
--- @function OnMsg.AutorunEnd
--- @return nil
function OnMsg.AutorunEnd()
	local replace
	for tbl, stack in pairs(table_change_stack) do
		if stack.global_name then
			local new_tbl = _G[stack.global_name]
			if new_tbl then
				replace = table.create_set(replace, tbl, new_tbl)
			end
			stack.global_name = nil
		end
	end
	for tbl, new_tbl in pairs(replace) do
		local stack = table_change_stack[tbl]
		table_change_stack[tbl] = nil
		table_change_stack[new_tbl] = stack
		-- reapply the changes on the new table
		for _, entry in ipairs(stack) do
			table.overwrite(new_tbl, entry.new)
		end
	end
end

---
--- Safely converts a value to a string.
---
--- If the value is a table, it will return a string in the format "T(id,\"name\")" where id is the table's unique identifier and name is the first 16 characters of the table's internal translation.
--- If the value is a table with a class, it will return a string in the format "class:value".
--- Otherwise, it will simply return the result of calling `tostring()` on the value.
---
--- @param x any The value to convert to a string.
--- @return string The string representation of the value.
---
function safe_tostring(x)
end
local function safe_tostring(x)
	if IsT(x) then
		return "T(" .. TGetID(x) .. ",\"" .. string.trim(_InternalTranslate(x), 16, "...") .. "\")"
	end
	if type(x) == "table" then
		local c = ObjectClass(x)
		if c then
			return c .. ":" .. tostring(x)
		end
	end
	return tostring(x)
end

---
--- Handles the start of a bug report by printing the active table changes.
---
--- When a bug report is started, this function collects all the active table changes
--- from the `table_change_stack` and prints them out using the provided `print_func`.
--- The changes are printed in a format that can be easily copied and used for debugging.
---
--- @param print_func function The function to use for printing the bug report.
---
function OnMsg.BugReportStart(print_func)
	local changes = {}
	for tbl, stack in pairs(table_change_stack) do
		local stack_name = GetGlobalName(tbl) or tostring(tbl)
		for _, entry in ipairs(stack) do
			local reason = safe_tostring(entry.reason)
			for key, value in sorted_pairs(entry.new) do
				table.set(changes, stack_name, reason, safe_tostring(key), safe_tostring(value))
			end
		end
	end
	if next(changes) then
		print_func("Active table.changes:\n" .. ValueToLuaCode(changes))
	end
end

---
--- Replaces all occurrences of a value in a table with another value.
---
--- @param tbl table The table to replace values in.
--- @param a any The value to replace.
--- @param b any The value to replace `a` with.
---
function table.replace(tbl, a, b)
	for key, val in pairs(tbl) do
		if val == a then
			tbl[key] = b
		end
	end
end

---
--- Removes invalid entries from a table.
---
--- This function iterates through the provided table `t` and removes any entries where the key is not a valid object (as determined by the `IsValid` function). The modified table is returned.
---
--- @param t table The table to validate and remove invalid entries from.
--- @return table The modified table with invalid entries removed.
---
function table.validate_map(t)
	for obj in next, t do
		if not IsValid(obj) then
			t[obj] = nil
		end
	end
	return t
end

---
--- Creates a new table containing only the valid objects from the input table.
---
--- @param t table The input table to copy valid objects from.
--- @return table A new table containing only the valid objects from the input table.
---
function table.copy_valid(t)
	local ret = {}
	for _, obj in ipairs(t) do
		if IsValid(obj) then
			ret[#ret + 1] = obj
		end
	end
	return ret
end

-------------------
---- ARRAY SET ----
-------------------

local remove_entry = table.remove_entry
---
--- Metatable for an array-like set data structure.
---
--- The `__array_set_meta` metatable provides the implementation for the `array_set` data structure, which preserves the order in which keys were inserted and allows for O(1) insertion and O(n) removal.
---
--- The metatable provides the following methods:
---
--- - `insert(array_set, obj, value)`: Inserts the `obj` key into the `array_set` with the optional `value`. If the `obj` key already exists, its value is updated.
--- - `remove(array_set, obj, index)`: Removes the `obj` key from the `array_set`. If the `index` is provided, the entry at that index is removed instead.
--- - `validate(array_set, fIsValid)`: Removes any entries from the `array_set` where the `fIsValid` function returns `false` for the key.
--- - `__toluacode(self, indent, pstr)`: Generates Lua code to recreate the `array_set` instance.
--- - `__eq(t1, t2)`: Compares two `array_set` instances for equality.
--- - `__serialize(array_set)`: Serializes the `array_set` instance for storage.
--- - `__unserialize(array_set)`: Deserializes an `array_set` instance from stored data.
--- - `__copy(value)`: Creates a shallow copy of the `array_set` instance.
---
if FirstLoad then
	__array_set_meta = {
		__name = "array_set",
		__index = {
			insert = function(array_set, obj, value)
				if array_set[obj] == nil then
					array_set[#array_set + 1] = obj
				end
				array_set[obj] = value == nil or value
			end,
			remove = function(array_set, obj, index)
				if array_set[obj] == nil then return end
				if index and array_set[index] == obj then
					remove(array_set, index)
				else
					remove_entry(array_set, obj)
				end
				array_set[obj] = nil
			end,
			validate = function (array_set, fIsValid)
				fIsValid = fIsValid or IsValid
				for i, obj in ripairs(array_set) do
					if not fIsValid(obj) then
						array_set:remove(obj, i)
					end
				end
			end,
		},
		__toluacode = function(self, indent, pstr)
			if not pstr then
				if not next(self) then
					return "array_set()"
				end
				local list = {}
				for _, v in ipairs(self) do
					list[#list + 1] = ValueToLuaCode(v, indent)
					list[#list + 1] = ValueToLuaCode(self[v], indent)
				end
				return string.format("array_set( %s )", table.concat(list, ", "))
			else
				if not next(self) then
					return pstr:append("array_set()")
				end
				pstr:append("array_set( ")
				local first = true
				for _, v in ipairs(self) do
					if first then
						first = false
					else
						pstr:append(", ")
					end
					pstr:appendv(v, indent)
					    :append(", ")
					    :appendv(self[v], indent)
				end
				return pstr:append(" )")
			end
		end,
		__eq = function(t1, t2)
			if not rawequal(getmetatable(t2), __array_set_meta)
			or #t1 ~= #t2 then
				return false
			end
			for _, obj in ipairs(t1) do
				if t1[obj] ~= t2[obj] then
					return false
				end
			end
			return true
		end,
		__serialize = function(array_set)
			local data, N = {}, #array_set
			for i, key in ipairs(array_set) do
				data[i] = key
				local v = array_set[key]
				if v ~= true then
					data[N + i] = array_set[key]
				end
			end
			data["N"] = N ~= #data and N or nil
			return "__array_set_meta", data
		end,
		__unserialize = function(array_set)
			local N = array_set.N or #array_set
			array_set.N = nil
			for i = 1, N do
				local key = array_set[i]
				local v = array_set[N + i]
				array_set[N + i] = nil
				array_set[key] = v == nil or v
			end
			return setmetatable(array_set, __array_set_meta)
		end,
		__copy = function(value)
			value = table.raw_copy(value)
			return setmetatable(value, __array_set_meta)
		end,
	}
end

--[[@@@
Recursively builds an array set by inserting the given key-value pairs.

@function array_set_composer
@param array_set The array set to build.
@param key The key to insert.
@param value The value to associate with the key.
@param ... Additional key-value pairs to insert.
@return The modified array set.
]]
local function array_set_composer(array_set, key, value, ...)
	if not key then
		return array_set
	end
	array_set:insert(key, value)
	return array_set_composer(array_set, ...)
end

--[[@@@
A set that preserves the order in which keys were inserted.
Can be iterated like an array.
Insertion is O(1).
Removal is O(n).

@function array_set array_set(...)
@param values... - key/value pairs to be inserted into the array_set

Example:
~~~~
	local set = array_set()
	set:insert("foo")
	set:insert("bar")
	set:insert("baz", "123")
	set:insert("bag", "456")
	for i, obj in ipairs(set) do
		print(i, obj, set[obj])
	end
	-- 1 foo true
	-- 2 bar true
	-- 3 baz 123
	-- 4 bag 456
	set:remove("foo") -- can remove by value
	set:remove("baz", 2) -- can specify the index for removal
	for i, obj in ipairs(set) do
		print(i, obj, set[obj])
	end
	-- 1 bar true
	-- 2 bag 45
~~~~
]]
---
--- A set that preserves the order in which keys were inserted.
--- Can be iterated like an array.
--- Insertion is O(1).
--- Removal is O(n).
---
--- @function array_set
--- @param ... values - key/value pairs to be inserted into the array_set
--- @return table The array set
---
--- Example:
--- 
---     local set = array_set()
---     set:insert("foo")
---     set:insert("bar")
---     set:insert("baz", "123")
---     set:insert("bag", "456")
---     for i, obj in ipairs(set) do
---         print(i, obj, set[obj])
---     end
---     -- 1 foo true
---     -- 2 bar true
---     -- 3 baz 123
---     -- 4 bag 456
---     set:remove("foo") -- can remove by value
---     set:remove("baz", 2) -- can specify the index for removal
---     for i, obj in ipairs(set) do
---         print(i, obj, set[obj])
---     end
---     -- 1 bar true
---     -- 2 bag 45
--- 
function array_set(...)
	return array_set_composer(setmetatable({}, __array_set_meta), ...)
end

---
--- Checks if the given value is an array set.
---
--- @param v any The value to check.
--- @return boolean True if the value is an array set, false otherwise.
---
function IsArraySet(v)
	return type(v) == "table" and getmetatable(v) == __array_set_meta
end

------------------
---- SYNC SET ----
------------------

---
--- Defines the metatable for a synchronous set data structure.
--- The synchronous set preserves the order in which elements were inserted,
--- and provides efficient insertion and removal operations.
---
--- The metatable defines the following methods:
---
--- - `insert(sync_set, obj)`: Inserts an object into the set. Insertion is O(1).
--- - `remove(sync_set, obj)`: Removes an object from the set. Removal is O(1).
--- - `shuffle(sync_set, func_or_seed)`: Shuffles the elements in the set. The optional `func_or_seed` parameter can be a random number generator function or a seed value.
--- - `shuffle_first(sync_set, count, seed)`: Shuffles the first `count` elements in the set, using the provided `seed` value.
--- - `validate(sync_set, fIsValid)`: Validates the set, removing any elements that do not pass the `fIsValid` function (which defaults to `IsValid`).
--- - `__toluacode(self, indent, pstr)`: Generates Lua code to represent the set.
--- - `__eq(t1, t2)`: Compares two sync sets for equality.
--- - `__serialize(sync_set)`: Serializes the sync set.
--- - `__unserialize(sync_set)`: Deserializes the sync set.
--- - `__copy(value)`: Creates a deep copy of the sync set.
---
if FirstLoad then
	__sync_set_meta = {
		__name = "sync_set",
		__index = {
			insert = function(sync_set, obj)
				assert(type(obj) ~= "number", "sync_set can't be used with numbers")
				if sync_set[obj] then return end
				local cnt = #sync_set + 1
				sync_set[cnt] = obj
				sync_set[obj] = cnt
			end,
			remove = function(sync_set, obj)
				local idx = sync_set[obj]
				if not idx then return end
				assert(sync_set[idx] == obj, "sync_set has mismatched object<->index mapping")
				local cnt = #sync_set
				local last_obj = sync_set[cnt]
				sync_set[idx] = last_obj
				sync_set[last_obj] = idx
				sync_set[cnt] = nil
				sync_set[obj] = nil
			end,
			shuffle = function(sync_set, func_or_seed)
				local cnt = table.shuffle(sync_set, func_or_seed)
				for i, obj in ipairs(sync_set) do
					sync_set[obj] = i
				end
				return cnt
			end,
			shuffle_first = function(sync_set, count, seed)
				local cnt = table.shuffle_first(sync_set, count, seed)
				for i, obj in ipairs(sync_set) do
					sync_set[obj] = i
				end
				return cnt
			end,
			validate = function (sync_set, fIsValid)
				fIsValid = fIsValid or IsValid
				for i, obj in ripairs(sync_set) do
					assert(sync_set[obj] == i, "sync_set has mismatched object<->index mapping")
					if not fIsValid(obj) then
						sync_set:remove(obj)
					end
				end
			end,
		},
		__toluacode = function(self, indent, pstr)
			if not pstr then
				if not next(self) then
					return "sync_set()"
				end
				local list = {}
				for _, v in ipairs(self) do
					if v then
						list[#list + 1] = ValueToLuaCode(v, indent)
					end
				end
				return string.format("sync_set( %s )", table.concat(list, ", "))
			else
				if not next(self) then
					return pstr:append("sync_set()")
				end
				pstr:append("sync_set( ")
				local first = true
				for _, v in ipairs(self) do
					if first then
						first = false
					else
						pstr:append(", ")
					end
					pstr:appendv(v, indent)
				end
				return pstr:append(" )")
			end
		end,
		__eq = function(t1, t2)
			if not rawequal(getmetatable(t2), __sync_set_meta)
			or #t1 ~= #t2 then
				return false
			end
			for _, obj in ipairs(t1) do
				if not t2[obj] then
					return false
				end
			end
			return true
		end,
		__serialize = function(sync_set)
			return "__sync_set_meta", table.icopy(sync_set)
		end,
		__unserialize = function(sync_set)
			for i, obj in ipairs(sync_set) do
				sync_set[obj] = i
			end
			return setmetatable(sync_set, __sync_set_meta)
		end,
		__copy = function(value)
			value = table.raw_copy(value)
			return setmetatable(value, __sync_set_meta)
		end,
	}
end

---
--- Recursively constructs a new `sync_set` instance by inserting the provided objects.
---
--- @param sync_set table The `sync_set` instance to insert the objects into.
--- @param obj any The object to insert into the `sync_set`.
--- @param ... any Additional objects to insert into the `sync_set`.
--- @return table The modified `sync_set` instance.
local function sync_set_composer(sync_set, obj, ...)
	if not obj then
		return sync_set
	end
	sync_set:insert(obj)
	return sync_set_composer(sync_set, ...)
end

--[[@@@
An unordered set that can be iterated like an array.
Unlike the regular set, iteration is synchronous.
Insertion is O(1).
Removal is O(1).
It is implemented by putting the last element of the array part of the set into the index of the removed element.

@function sync_set sync_set(...)
@param values... - objects to be inserted into the sync_set

Example:
~~~~
	local set = sync_set()
	set:insert("foo")
	set:insert("bar")
	set:insert("baz")
	for i, obj in ipairs(set) do
		print(i, obj)
	end
	-- 1 foo
	-- 2 bar
	-- 3 baz
	set:remove("foo")
	for i, obj in ipairs(set) do
		print(i, obj)
	end
	-- 1 baz
	-- 2 bar
~~~~
]]
---
--- Recursively constructs a new `sync_set` instance by inserting the provided objects.
---
--- @param ... any Objects to insert into the `sync_set`.
--- @return table The new `sync_set` instance.
function sync_set(...)
	return sync_set_composer(setmetatable({}, __sync_set_meta), ...)
end

--- Checks if the given value is a sync set.
---
--- @param v any The value to check.
--- @return boolean True if the value is a sync set, false otherwise.
function IsSyncSet(v)
	return type(v) == "table" and getmetatable(v) == __sync_set_meta
end

----------------
---- STRING ----
----------------

---
--- Converts a number of seconds into a formatted string representation of time.
---
--- @param seconds number The number of seconds to convert.
--- @return string The formatted time string.
function string.TimeToStr(seconds)
	local sec = seconds % 60
	local min = seconds / 60
	local hr = min / 60
	min = min % 60
	local strMinutes = min < 10 and "0"..min or tostring(min)
	local strSeconds = sec < 10 and "0"..sec or tostring(sec)
	if hr > 0 then
		return T{868478948977, --[[Hours:Minutes:Seconds]] "<arg1>:<arg2>:<arg3>", arg1 = Untranslated(tostring(hr)), arg2 = Untranslated(strMinutes), arg3 = Untranslated(strSeconds)}
	else
		return T{946378336680, --[[Minutes:Seconds]] "<arg1>:<arg2>", arg1 = Untranslated(strMinutes), arg2 = Untranslated(strSeconds)}
	end
end

---
--- Converts a string to camel case.
---
--- @param s string The string to convert.
--- @return string The string in camel case.
function string.to_camel_case(s)
	return string.lower(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

--[[
 Breaks a string 'str' into tokens, where 'sep' is the separator string
 Returns an array with the token strings
 Example: string.tokenize("a; b; c", "; ") = {"a","b","c"}
 When a second separation string is specified, the function tries to break the string into key - values pairs.
 Example: string.tokenize("a=1;b=2;c=3", ";", "=") = {["a"] = 1, ["b"] = 2, ["c"] = 3}
--]]

---
--- Tokenizes a string into an array of tokens, optionally splitting the tokens into key-value pairs.
---
--- @param str string The string to tokenize.
--- @param sep string The separator string to use for tokenizing.
--- @param sep2 string (optional) The separator string to use for splitting tokens into key-value pairs.
--- @param trim boolean (optional) Whether to trim leading and trailing whitespace from tokens.
--- @return table An array of tokens, or a table of key-value pairs if `sep2` is provided.
---
function string.tokenize(str, sep, sep2, trim)
	local tokens = {}
	local sep_len = string.len(sep)
	local str_len = string.len(str)
	local sep2_len = sep2 and string.len(sep2)
	local start = 1
	
	while start <= str_len do
		local index = string.find(str, sep, start, true)
		if not index or index > start then
			local token = string.sub(str, start, index and index - 1)
			local key, val
			if sep2 then
				local index2 = string.find(token, sep2, 1, true)
				if index2 then
					key = string.sub(token, 1, index2 - 1)
					val = string.sub(token, index2 + sep2_len)
					if trim then
						key = key:trim_spaces()
						val = val:trim_spaces()
					end
				end
			elseif trim then
				token = token:trim_spaces()
			end
			if key and val then
				tokens[ key ] = val
			else
				tokens[ #tokens + 1 ] = token
			end
			if not index then
				break
			end
		end
		start = index + sep_len
	end
	
	return tokens
end

---
--- Splits a string into an array of substrings using the provided pattern.
---
--- @param str string The string to split.
--- @param pattern string The pattern to use for splitting the string.
--- @param plain boolean (optional) Whether to use a plain string pattern instead of a Lua pattern.
--- @return table An array of substrings.
---
function string.split(str, pattern, plain)
	plain = plain or str == "\n" or str == "/" or str == "," or str == ";" or str == ":"
	local res = {}
	local i = 1
	while true do
		local istart, iend = string.find(str, pattern, i, plain)
		res[#res + 1] = str:sub(i, (istart or 0) - 1)
		if not istart then
			break
		end
		i = iend + 1
	end
	return res
end

--[[ Cut a string to desired len if needed adding ending at the end
	string.trim("123456789", 6, "...") = "123..."
]]
---
--- Trims a string to the given length, adding an ending if the string is longer than the length.
---
--- @param s string The string to trim.
--- @param len number The maximum length of the string.
--- @param ending string (optional) The ending to add if the string is longer than the length. Defaults to an empty string.
--- @return string The trimmed string.
---
function string.trim(s, len, ending)
	ending = ending or ""
	return #s > len and (string.sub(s, 1, len-#ending) .. ending) or s
end

---
--- Trims leading and trailing whitespace from the given string.
---
--- @param s string The string to trim.
--- @return string The trimmed string.
---
function string.trim_spaces(s)
	return s and s:match("^%s*(.-)%s*$")
end

---
--- Converts a string of bytes to a hexadecimal string representation.
---
--- @param s string The string of bytes to convert.
--- @return string The hexadecimal string representation of the input string.
---
function string.bytes_to_hex(s)
	return s and string.gsub(s, ".", function(c)
		return string.format("%02x", string.byte(c))
	end)
end

---
--- Converts a hexadecimal string representation to a string of bytes.
---
--- @param s string The hexadecimal string to convert.
--- @return string The string of bytes represented by the input hexadecimal string.
---
function string.hex_to_bytes(s)
	return s and string.gsub(s, "(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
end

-- finds the next tag enclosed in < and > starting at position 'start'
-- to match a tag, the < must be followed by [/a-zA-Z0-9],
-- so texts like "Use < and > to ..." won't result in any tags)
--
-- returns the portion of the string before the tag, the text inside the tag, tag start index, tag end index
-- for example, string.next_tag("<a>text<b>", 4) will return "text", "b", 8, 10
local str_find = string.find
local sub = string.sub
---
--- Finds the next tag enclosed in < and > starting at position 'start'.
--- To match a tag, the < must be followed by [/a-zA-Z0-9], so texts like "Use < and > to ..." won't result in any tags.
---
--- @param str string The input string to search for tags.
--- @param start number (optional) The starting position to search for tags. Defaults to 1.
--- @return string The portion of the string before the tag.
--- @return string The text inside the tag.
--- @return number The start index of the tag.
--- @return number The end index of the tag.
function string.nexttag(str, start)
	local opening = start or 1
	while true do 
		opening = str_find(str, "</?[%w_]", opening)
		if not opening then
			break
		end
		local tag_opening, tag_closing = str_find(str, "%b<>", opening)
		if not tag_opening then
			break
		end
		if tag_opening == opening then
			return sub(str, start, tag_opening - 1), sub(str, tag_opening + 1, tag_closing - 1), tag_opening, tag_closing
		end
		opening = tag_opening
	end
	return sub(str, start or 1, -1)
end

---
--- Strips all HTML/XML tags from the given string.
---
--- @param str string The input string to strip tags from.
--- @return string The input string with all tags removed.
---
function string.strip_tags(str)
	local untagged, tag, first, last = str:nexttag(1)
	local list = { untagged }
	while tag do
		untagged, tag, first, last = str:nexttag(last+1)
		insert(list, untagged)
	end
	return table.concat(list)
end

---
--- Parses a string into a table of key-value pairs using a regular expression.
---
--- @param str string The input string to parse.
--- @param regex string The regular expression to use for parsing the string.
--- @return table A table of key-value pairs parsed from the input string.
---
function string.parse_pairs(str, regex)
	if not str then return end
	local data
	for key, value in str:gmatch(regex) do
		data = data or {}
		data[key] = value
	end
	return data
end


---------------
---- RANGE ----
---------------

---
--- Defines a range data structure with a `from` and `to` value.
---
--- The range data structure is immutable and cannot be modified after creation.
--- It provides utility functions for working with ranges, such as converting to Lua code.
---
--- @type table
--- @field from number The starting value of the range.
--- @field to number The ending value of the range.
--- @see range
---
__range_meta = {
    __name = "range",
    __newindex = function() assert(false, "Modifying a range struct", 1) end,
    __toluacode = function(self, indent, pstr)
        if not pstr then
            return string.format("range(%d, %d)", self.from, self.to)
        else
            return pstr:appendf("range(%d, %d)", self.from, self.to)
        end
    end,
    __eq = function(r1, r2) return rawequal(getmetatable(r2), __range_meta) and r1.from == r2.from and r1.to == r2.to end,
    __serialize = function(value)
        local from, to = value.from, value.to
        return "__range_meta", { from, to ~= from and to or nil }
    end,
    __unserialize = function(value)
        local from, to = value[1], value[2]
        if from then
            value = { from = from, to = to or from }
        end
        return setmetatable(value, __range_meta)
    end,
    __add = function(l, r)
        if type(l) == "number" then
            return range(l + r.from, l + r.to)
        elseif type(r) == "number" then
            return range(l.from + r, l.to + r)
        else
            return range(l.from + r.from, l.to + r.to)
        end
    end,
    __copy = function(value)
        value = table.raw_copy(value)
        return setmetatable(value, __range_meta)
    end,
}
if FirstLoad then
	__range_meta = {
		__name = "range",
		__newindex = function() assert(false, "Modifying a range struct", 1) end,
		__toluacode = function(self, indent, pstr)
			if not pstr then
				return string.format("range(%d, %d)", self.from, self.to)
			else
				return pstr:appendf("range(%d, %d)", self.from, self.to)
			end
		end,
		__eq = function(r1, r2) return rawequal(getmetatable(r2), __range_meta) and r1.from == r2.from and r1.to == r2.to end,
		__serialize = function(value)
			local from, to = value.from, value.to
			return "__range_meta", { from, to ~= from and to or nil }
		end,
		__unserialize = function(value)
			local from, to = value[1], value[2]
			if from then
				value = { from = from, to = to or from }
			end
			return setmetatable(value, __range_meta)
		end,
		__add = function(l, r)
			if type(l) == "number" then
				return range(l + r.from, l + r.to)
			elseif type(r) == "number" then
				return range(l.from + r, l.to + r)
			else
				return range(l.from + r.from, l.to + r.to)
			end
		end,
		__copy = function(value)
			value = table.raw_copy(value)
			return setmetatable(value, __range_meta)
		end,
	}
end

---
--- Creates a new range object with the given `from` and `to` values.
---
--- @param from number The starting value of the range.
--- @param to number The ending value of the range.
--- @return table A new range object.
---
function range(from, to)
	assert(type(from) == "number" and type(to) == "number" and from <= to)
	return setmetatable({from = from or 0, to = to or 0}, __range_meta)
end
if FirstLoad then
	range00 = range(0, 0)
end

---
--- Checks if the given value is a range object.
---
--- @param v any The value to check.
--- @return boolean True if the value is a range object, false otherwise.
---
function IsRange(v)
	return type(v) == "table" and getmetatable(v) == __range_meta
end

-------------
---- SET ----
-------------

if FirstLoad then
	__set_meta = {
		__name = "set",
		__toluacode = function(self, indent, pstr)
			if not pstr then
				if not next(self) then
					return "set()"
				end
				local list = {}
				for el, v in pairs(self) do
					if v then
						list[#list + 1] = ValueToLuaCode(el, indent)
					end
					if v == false then
						return string.format("set( %s )", TableToLuaCode(self, indent))
					end
				end
				table.sort(list)
				return string.format("set( %s )", table.concat(list, ", "))
			else
				if not next(self) then
					return pstr:append("set()")
				end
				for el, v in pairs(self) do
					if v == false then
						pstr:append("set(")
						TableToLuaCode(self, nil, pstr)
						return pstr:append(")")
					end
				end
				pstr:append("set( ")
				local first = true
				for el, v in sorted_pairs(self) do
					if v then
						if first then
							first = false
						else
							pstr:append(", ")
						end
						pstr:appendv(el, indent)
					end
				end
				return pstr:append(" )")
			end
		end,
		__eq = function(t1, t2)
			if not rawequal(getmetatable(t2), __set_meta) then
				return false
			end
			local function is_equal(s1, s2)
				for el, v in pairs(s1) do
					if v ~= s2[el] then
						return false
					end
				end
				return true
			end
			
			return is_equal(t1, t2) and is_equal(t2, t1)
		end,
		__serialize = function(set)
			local data, count = {}, 0
			for key, value in sorted_pairs(set) do
				count = count + 2
				data[count - 1] = key
				data[count] = value
			end
			return "__set_meta", data
		end,
		__unserialize = function(set)
			if #set > 0 then
				local res = {}
				for i=1,#set,2 do
					res[set[i]] = set[i + 1]
				end
				set = res
			end
			return setmetatable(set, __set_meta)
		end,
		__copy = function(value)
			value = table.raw_copy(value)
			return setmetatable(value, __set_meta)
		end,
	}
end

---
--- Composes a set by recursively adding key-value pairs to the set.
---
--- @param set table The set to compose.
--- @param value boolean The value to set for the key.
--- @param arg any The key to add to the set.
--- @param ... any Additional keys to add to the set.
--- @return table The composed set.
local function set_composer(set, value, arg, ...)
	if arg == nil then
		return set
	end
	set[arg] = value
	return set_composer(set, value, ...)
end

---
--- Composes a set by adding key-value pairs to the set.
---
--- @param first table|any The first key to add to the set. If it is a table, the table is returned as the set.
--- @param ... any Additional keys to add to the set.
--- @return table The composed set.
function set(first, ...)
	if first and type(first) == "table" then
		return setmetatable(first, __set_meta)
	end
	
	return setmetatable(set_composer({}, true, first, ...), __set_meta)
end

---
--- Composes a set by recursively adding key-value pairs to the set, where the value is set to false.
---
--- @param first table|any The first key to add to the set. If it is a table, the table is returned as the set.
--- @param ... any Additional keys to add to the set.
--- @return table The composed set.
function set_neg(first, ...)
	if first and type(first) ~= "string" then
		return setmetatable(first, __set_meta)
	end
	
	return setmetatable(set_composer({}, false, first, ...), __set_meta)
end

---
--- Checks if the given value is a set.
---
--- @param v any The value to check.
--- @return boolean True if the value is a set, false otherwise.
function IsSet(v)
	return type(v) == "table" and getmetatable(v) == __set_meta
end

---
--- Converts a set to a sorted list of keys where the value is true.
---
--- @param set table The set to convert to a list.
--- @return table The sorted list of keys where the value is true.
function SetToList(set)
	local list = {}
	for name, enabled in pairs(set or empty_table) do
		if enabled then
			list[#list + 1] = name
		end
	end
	table.sort(list)
	return list
end

---
--- Converts a list of values to a set.
---
--- @param list table The list of values to convert to a set.
--- @return table The set containing the values from the list.
function ListToSet(list)
	return set(table.unpack(list or empty_table))
end

---
--- Converts a table to a set.
---
--- @param tbl table The table to convert to a set.
--- @return table The set containing the keys from the table.
function TableToSet(tbl)
	local set = {}
	for k, value in pairs(tbl) do
		set[k] = not not value
	end
	
	return setmetatable(set, __set_meta)
end

---
--- Converts a table or string to a set.
---
--- If the input is a string, it is converted to a set using the `set` function.
--- If the input is a table, it is converted to a set using the `TableToSet` function.
---
--- @param tbl table|string The table or string to convert to a set.
--- @param ... any Additional arguments to pass to the `set` function if `tbl` is a string.
--- @return table The set containing the keys from the input table or the characters from the input string.
function set3s(tbl, ...)
	return (type(tbl) == "string") and set(tbl, ...) or TableToSet(tbl)
end
