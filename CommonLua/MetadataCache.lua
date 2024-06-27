--- Defines a metadata cache that is used to store and retrieve metadata for various entities.
---
--- The metadata cache is stored in a file named "saves:/save_metadata_cache.lua" in the "saves:/" folder.
--- The cache will only include files matching the "*.sav" mask.
---
--- @class DefineClass.MetadataCache
--- @field cache_filename string The filename of the metadata cache.
--- @field folder string The folder where the metadata cache is stored.
--- @field mask string The file mask used to filter the files included in the metadata cache.
DefineClass.MetadataCache = {
	__parents = {"InitDone"},
	cache_filename = "saves:/save_metadata_cache.lua",
	folder = "saves:/",
	mask = "*.sav",
}

---
--- Saves the metadata cache to a file.
---
--- The metadata cache is stored in a file named "saves:/save_metadata_cache.lua" in the "saves:/" folder.
--- The cache will only include files matching the "*.sav" mask.
---
--- @function MetadataCache:Save
--- @return string|nil An error message if an error occurred, or nil if the save was successful.
function MetadataCache:Save()
	local data_to_save = {}
	for _, data in ipairs(self) do
		data_to_save[#data_to_save + 1] = data
	end
	local err = AsyncStringToFile(self.cache_filename, ValueToLuaCode(data_to_save, nil, pstr("", 1024)))
	return err
end

---
--- Loads the metadata cache from a file.
---
--- The metadata cache is loaded from a file named "saves:/save_metadata_cache.lua" in the "saves:/" folder.
--- The cache will only include files matching the "*.sav" mask.
---
--- @function MetadataCache:Load
--- @return string|nil An error message if an error occurred, or nil if the load was successful.
function MetadataCache:Load()
	self:Clear()
	local err, data_to_load = FileToLuaValue(self.cache_filename)
	if err then return err end
	if not data_to_load then return end
	for _, data in ipairs(data_to_load) do
		self[#self + 1] = data
	end
end

---
--- Refreshes the metadata cache by enumerating the files in the cache folder, comparing the cached metadata to the new enumeration, and updating the cache accordingly.
---
--- The function first enumerates the files in the cache folder using the specified mask, and stores the results in a new table `new_entries`. It then creates a dictionary `cached_dict` to map the cached filenames to their corresponding cache entries.
---
--- Next, the function iterates through the new entries and compares them to the cached entries. If a cached entry exists, it checks if any of the metadata fields have changed, and updates the cache entry if so. If a new entry is found, it adds the new entry to the cache and loads the metadata for that file.
---
--- Finally, the function removes any cache entries that no longer exist in the new enumeration.
---
--- @function MetadataCache:Refresh
--- @return string|nil An error message if an error occurred, or nil if the refresh was successful.
function MetadataCache:Refresh()
	assert(CurrentThread())
	local err, new_entries = self:Enumerate()
	if err then return err end
	local cached_dict = {}
	for idx, cached in ipairs(self) do
		cached_dict[cached[1]] = cached
		cached_dict[cached[1]]["idx"] = idx
	end
	local new_entries_dict = {}
	for _, entry in ipairs(new_entries) do
		new_entries_dict[entry[1]] = entry
	end
	
	for key, entry in pairs(new_entries_dict) do
		local cached = cached_dict[key]
		if cached then --refresh existing
			for i = 3, #cached do
				if cached[i] ~= entry[i] then
					self[cached.idx] = entry
					err, meta = self:GetMetadata(entry[1])
					if err then
						return err
					end
					self[cached.idx][2] = meta
					break
				end
			end
		else --add new
			self[#self + 1] = entry
			local err, meta = self:GetMetadata(entry[1])
			if err then
				return err
			end
			self[#self][2] = meta
		end
		
	end
	
	for i = #self, 1, -1 do
		if not new_entries_dict[self[i][1]] then --remove inexistent
			table.remove(self, i)
		end
	end
end

--- Enumerates the files in the specified folder that match the given mask, and returns a list of file information.
---
--- @function MetadataCache:Enumerate
--- @return string|nil An error message if an error occurred, or nil if the enumeration was successful.
--- @return table A table of file information, where each entry is a table with the following fields:
---   - [1]: The relative file path
---   - [2]: A boolean indicating whether the file has metadata
---   - [3]: The size of the file
---   - [4]: The modification time of the file
function MetadataCache:Enumerate()
	local err, files = AsyncListFiles(self.folder, self.mask, "relative,size,modified")
	local result = {}
	if err then
		return err
	end
	for idx, file in ipairs(files) do
		result[#result + 1] = { file, false, files.size[idx], files.modified[idx] }
	end
	return err, result
end

--- Loads the metadata for the specified file.
---
--- @param filename string The file to load the metadata for.
--- @return string|nil An error message if an error occurred, or nil if the metadata was loaded successfully.
--- @return table The loaded metadata.
function MetadataCache:GetMetadata(filename)
	local loaded_meta, load_err
	local err = Savegame.Load(filename, function(folder)
		load_err, loaded_meta = LoadMetadata(folder)
	end)
	return load_err, loaded_meta
end

--- Clears the contents of the MetadataCache.
function MetadataCache:Clear()
	table.iclear(self)
end