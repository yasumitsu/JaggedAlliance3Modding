---
--- Gets the terrain image path for the given texture.
---
--- If the texture path does not exist, it will try to find the DDS version of the texture.
---
--- @param texture string The texture path to get the image for.
--- @return string The terrain image path.
function GetTerrainImage(texture)
	local img = texture or "" --"UI/Editor/" .. texture
	if img ~= "" and not io.exists(img) then
		if string.ends_with(img, "tga", true) then
			img = string.sub(img, 1, string.len(img) - 3) .. "dds"
		end
	end
	return img
end

local save_order_cache = {}
local save_order_class = {}
local save_objects_order = config.SaveObjectsOrder or {}

local function FindSaveOrderByClass(obj)
	local obj_class = obj.class
	local save_order_idx = save_order_cache[obj_class]
	if save_order_idx then
		return save_order_idx, save_order_class[obj_class]
	end
	for i=1,#save_objects_order do
		local classes = save_objects_order[i]
		for j=1,#classes do
			if IsKindOf(obj, classes[j]) then
				save_order_cache[obj_class] = i
				save_order_class[obj_class] = classes[j]
				return i
			end
		end
	end
	save_order_cache[obj_class] = max_int
	save_order_class[obj_class] = ""
	return max_int
end

---
--- Compares two objects for the purpose of saving them in a specific order.
---
--- The comparison is done in the following order:
--- 1. Compare the save order class index of the objects.
--- 2. If the class indices are the same, compare the Morton XY position of the objects.
--- 3. If the positions are the same, compare the handles of the objects.
---
--- @param o1 table The first object to compare.
--- @param o2 table The second object to compare.
--- @return boolean True if o1 should be saved before o2, false otherwise.
function CompareObjectsForSave(o1, o2)
	local class1 = FindSaveOrderByClass(o1)
	local class2 = FindSaveOrderByClass(o2)
	if class1 ~= class2 then
		return class1 < class2
	end
	
	local pos_cmp = MortonXYPosCompare(o1, o2)
	if pos_cmp ~= 0 then
		return pos_cmp < 0
	end
	
	return lessthan(rawget(o1, "handle"), rawget(o2, "handle"))
end

---
--- Converts a table of game objects to Lua code that can be saved to a file.
---
--- The objects are sorted in a specific order before being converted to Lua code.
--- The order is determined by the `CompareObjectsForSave` function, which compares
--- the objects based on their save order class, Morton XY position, and handle.
---
--- @param objects table A table of game objects to be converted to Lua code.
--- @param result string|table The output where the Lua code will be written. Can be a string or a table.
--- @param GetPropFunc function An optional function to get the properties of an object.
--- @return string|table The output with the Lua code for the game objects.
---
function ObjectsToLuaCode(objects, result, GetPropFunc)
	table.sort(objects, CompareObjectsForSave)
	if not IsPStr(result) then
		result = result or {}
		for _, obj in ipairs(objects) do
			result[#result + 1] = obj:__toluacode("", nil, GetPropFunc)
			result[#result + 1] = "\n"
		end
	else
		local class = ""
		for _, obj in ipairs(objects) do
			local _, new_class = FindSaveOrderByClass(obj)
			if new_class ~= class then
				if class ~= "" then
					result:appendf("-- end of objects of class %s\n", class)
				end
				class = new_class
			end
			obj:__toluacode("", result, GetPropFunc)
			result:append("\n")
		end
		if class and class ~= "" then
			result:appendf("-- end of objects of class %s\n", class)
		end
	end
	return result
end

---
--- Remaps the indices of all valid collections in the game.
---
--- This function is used to ensure that the collection indices are contiguous and within the valid range.
--- It creates a mapping between the current collection indices and new, contiguous indices, and then updates
--- all collections to use the new indices.
---
--- This function is typically called when a new map is loaded, to ensure that the collection indices are
--- properly set up for the new map.
---
--- @function RemapCollections
--- @return nil
function RemapCollections()
	local collection_map = {}
	local new_col_index = 1
	local max_index_value = const.GameObjectMaxCollectionIndex
	local current_collections = Collections
	for _ , col in pairs(Collections) do
		local col_index = col.Index
		if col_index > 0 and col_index < max_index_value then 
			collection_map[col_index] = col_index
		end
	end
	for _ , col in pairs(Collections) do
		local col_index = col.Index
		if not collection_map[col_index] then 
			while collection_map[new_col_index] do
				new_col_index = new_col_index + 1
			end
			collection_map[col_index] = new_col_index
			new_col_index = new_col_index + 1
		end
	end
	local all_collections = MapGet(true, "Collection")
	for _ , col in ipairs(all_collections) do
		local col_index = col.Index
		col:SetIndex(collection_map[col_index])
	end
end

local ReloadCollectionIndexes = false
function OnMsg.NewMapLoaded()
	if ReloadCollectionIndexes and MapCount(true, "Collection") > 0  then
		RemapCollections()
	end
end

---
--- Returns a table of all map objects that should be saved.
---
--- This function filters the map objects to only include those that are permanent and have a Lua object associated with them.
--- It excludes any objects that are of type "Collection".
---
--- @return table The table of map objects to be saved.
---
function GetMapObjectsForSaving()
	return MapGet(true, "attached", false, nil, nil,	const.gofPermanent, nil, const.cfLuaObject,
		function(o)
			return not IsKindOf(o, "Collection") 
		end) or empty_table
end

---
--- Saves the map objects to a file.
---
--- This function serializes all valid object Collections and map objects that are permanent and have a Lua object associated with them. It excludes any objects that are of type "Collection". The function also sets the next sync handle to be used for new objects.
---
--- @param filename string The name of the file to save the objects to.
---
function SaveObjects(filename)
	local code = pstr("", 64*1024)
	
	-- All valid object Collections.
	-- They get serialized first, so that objects being loaded will be able to set their "CollectionIndex" property... properly.
	local ol = Collection.GetValid()
	ObjectsToLuaCode(ol, code)
	
	ol = GetMapObjectsForSaving()
	
	local max_handle = const.HandlesSyncStart or 2000000000
	for _, obj in ipairs(ol) do
		if obj:IsSyncObject() then
			max_handle = Max(max_handle, obj.handle)
		end
	end

	code:appendf("SetNextSyncHandle(%d)\n", max_handle + 1)
	ObjectsToLuaCode(ol, code)
	mapdata.ObjectsHash = xxhash(code)
	code:append("\n\n-- objects without Lua object\n")
	__DumpObjPropsForSave(code)
	code:append("\n")

	local err = AsyncStringToFile(filename, code)
	if err then
		printf("Failed to save \"%s\": %s", filename, err)
	end
end

---
--- Makes a backup of the current map.
---
--- This function creates a backup of the current map by copying all the map files (excluding .hpk and .be files) to a backup directory. The backup directory is named with the current date and time, and is located in the "EditorBackup/" directory. If the number of backup directories exceeds the maximum allowed (100), the oldest backup directory is removed to make room for the new one.
---
--- @return nil
---
function MakeMapBackup()
	local max_backup_files = 100
	local fldMap  = GetMap()
	local fldBackup = "EditorBackup/"

	local tFolders = {}
	if not io.exists(fldBackup) then
		io.createpath(fldBackup)
	else
		tFolders = io.listfiles(fldBackup, "*", "folders") or {}
	end

	if #tFolders>=max_backup_files then --Find and remove the oldest
		local str = tFolders[1] -- find
		for i, v in ipairs(tFolders) do
			if v<str then str = v end
		end
		local tFiles = io.listfiles(str) --remove
		for i, v in ipairs(tFiles) do
			os.remove(v)
		end
		os.remove(str)
	end

	local fldBackupName = fldMap:sub(1,-2) -- Remove last'/'
	local i,j = fldBackupName:find("/(%w+)$")
	fldBackupName = fldBackupName:sub((i or 0)+1, -1) --the map name only
	local strData = os.date("%y%m%d%H%M%S")-- curent date and time <year><month><day>-<hour><min><sec>
	fldBackupName = fldBackup..fldBackupName.."-"..strData.."/"

	if not io.exists(fldBackupName) then
		io.createpath(fldBackupName)
	end

	--copy files
	local tMapFiles = io.listfiles(fldMap) or {}
	for _, v in ipairs(tMapFiles) do
		if not string.match(v, "%.hpk") and not string.match(v, "%.be") then
			local f, err = io.open(v,"rb")
			local strFile = ""
			if f then
				local i,j = v:find("/[- _%.%w]+$")
				--print ( v:sub((i or 0)+1,-1) )
				local backup_name = fldBackupName..v:sub((i or 0)+1,-1)
				local f1, err = io.open(backup_name, "wb")
				if f1 then
					while strFile do
						strFile = f:read(2048*1024)
						if strFile then
							f1:write(strFile)
						end
					end
					f1:close()
				else
					print("Cannot open backup file " .. backup_name .. " : " .. err)
				end
				f:close()
			else
				print("Cannot open map file " .. v .. " : " .. err)
			end
		end
	end
end

if FirstLoad then
	EditorSavingThread = false
end

---
--- Checks if the editor is currently saving.
---
--- @return boolean true if the editor is currently saving, false otherwise
function IsEditorSaving()
	return IsValidThread(EditorSavingThread)
end

---
--- Creates a compatibility map copy of the current map.
---
--- If the current map has an assets revision greater than 0, and the map is not an old map, a compatibility map copy is created. The compatibility map copy is named with the original map name plus "_old" and the assets revision number.
---
--- The compatibility map copy is created in the "svnAssets/Source/Maps/" directory, and the files are copied from the original map directory. The mapdata.lua file is updated to include the CreateRevisionOld and ForcePackOld fields.
---
--- @return nil
function CreateCompatibilityMapCopy()
	local rev = mapdata and mapdata.AssetsRevision or 0
	if rev == 0 then
		return
	end
	local map = GetMapName()
	if IsOldMap(map) then
		return
	end
	-- if the map has been marked as 'published' and its revision dates before the last official build, the compatibility map should be included in future builds
	local force_pack = mapdata.PublishRevision > 0 and rev <= const.LastPublishedAssetsRevision or false
	local default_path = "svnAssets/Source/Maps/" ..  map .. "/"
	local new_map_name = map .. "_old" .. rev
	local new_path = "svnAssets/Source/Maps/" .. new_map_name .. "/"
	io.createpath(new_path)
	SVNAddFile(new_path)
	for _,file_path in ipairs(io.listfiles(default_path)) do
		local file_new_path = string.gsub(file_path, map, new_map_name)
		local err
		if file_path:ends_with("/mapdata.lua", true) then
			local err, str = AsyncFileToString(file_path)
			if not err then
				local idx = str:find("\tid = ", 1, true)
				if idx then
					local insert = "\tCreateRevisionOld = " .. tostring(AssetsRevision) .. ",\n\tForcePackOld = " .. tostring(force_pack) .. ",\n"
					str = str:sub(1, idx - 1) .. insert .. str:sub(idx)
					err = AsyncStringToFile(file_new_path, str)
				end
			end
		else
			err = CopyFile(file_path, file_new_path)
		end
		if err then
			print("Copying " .. file_new_path .. " failed due to: " .. err .. "<newline>Try to do it manually.")
		else
			SVNAddFile(file_new_path)
		end
	end
end

--[[
	options = {
		validate_properties = true/false, -- default false, run property validation for every Object - VERY SLOW
		validate_CObject = true/false, -- default true, validate CObjects
		validate_Object = true/false, -- default true, validate Objects -- just for consistency, ignored, Objects are always validated ;-)
	}
]]

---
--- Checks if a CObject is non-essential and has collision surfaces, and if so, stores an error source for it.
---
--- @param obj CObject
--- @return nil
function CheckEssentialWarning(obj)
	if IsKindOf(obj, "CObject") and obj:GetDetailClass() ~= "Essential" and not ObjEssentialCheck(obj) then
		StoreErrorSource(obj, "Non-Essential(with collision surfaces) should have BOTH efCollision AND efApplyToGrids turned off!")
	end
end

---
--- Validates the map objects in the current game session.
---
--- This function iterates through all map objects and performs various validation checks on them.
--- It can optionally validate object properties, CObjects, and regular Objects.
--- The validation results are stored as error and warning sources, which can be accessed later.
---
--- @param options table|nil Options for the validation process.
---   - validate_properties boolean|nil Whether to validate object properties. Default is false.
---   - validate_CObject boolean|nil Whether to validate CObjects. Default is true.
---   - validate_Object boolean|nil Whether to validate regular Objects. Default is true.
---
--- @return nil
function ValidateMapObjects(options)
	DebugPrint("Validating map objects...\n")
	local st = GetPreciseTicks()
	
	SuspendThreadDebugHook("ValidateMapObjects")
	local silentVMEStack = config.SilentVMEStack
	config.SilentVMEStack = true
			
	Msg("ValidateMap")
	local procall = procall 
	
	local options = options or {}
	local validate_properties = options.validate_properties or false
	local validate_CObject = options.validate_CObject or true
	local validate_Object = options.validate_Object or true
	if validate_CObject and not validate_Object then
		assert(not "supported combination - Objects are always validated")
	end
	local gofFlagsAll = const.gofPermanent
	local cfFlagsAll = not validate_CObject and const.cfLuaObject or nil

	local count
	if validate_properties then
		count = MapForEach(true, nil, nil, gofFlagsAll, nil, cfFlagsAll, nil,
			function(obj)
				local msg = obj:GetDiagnosticMessage("verbose")
				if not msg then
					--
				elseif msg[#msg] == "warning" then
					StoreWarningSource(obj, msg[1])
				else
					StoreErrorSource(obj, msg[1])
				end
				CheckEssentialWarning(obj)
			end)
	else
		count = MapForEach(true, nil, nil, gofFlagsAll, nil, cfFlagsAll, nil,
			function(obj)
				local _, err_msg, err_param = procall(obj.GetError, obj)
				local _, warn_msg, warn_param = procall(obj.GetWarning, obj)	

				if err_msg then
					StoreErrorSource(err_param or obj, err_msg)
				end
				if warn_msg then
					StoreWarningSource(warn_param or obj, warn_msg)
				end
				CheckEssentialWarning(obj)
			end)
	end

	ResumeThreadDebugHook("ValidateMapObjects")
	config.SilentVMEStack = silentVMEStack
	
	DebugPrint("Validated", count, "objects in",  GetPreciseTicks() - st, "ms\n")
end

local function save_map(skipBackup, folder, silent)
	folder = folder or GetMap()
	AsyncCreatePath(folder)
	
	local backup_folder
	if Platform.developer and not skipBackup then
		-- do not back up new maps
		if io.exists(folder .. "objects.lua") then
			backup_folder = MakeMapBackup()
		end
	end
	
	Msg("PreSaveMap")
	
	if not silent then
		ValidateMapObjects()
	end
	
	Msg("SaveMap", folder, backup_folder)
	
	local new_terrain_hash = terrain.HashGrids(config.IgnorePassGridInTerrainHash)
	if config.StorePrevTerrainMapVersionOnSave
		and mapdata.GameLogic and mapdata.IsRandomMap
		and mapdata.TerrainHash ~= new_terrain_hash
		and (mapdata.AssetsRevision or 0) > 0
	then
		-- Save compatibility map only if this map is under subversion.
		local _, info = GetSvnInfo(folder)
		if next(info) then
			CreateCompatibilityMapCopy()
		end
	end
	
	local t = GetPreciseTicks()
	SaveObjects(folder .. "objects.lua")
	DebugPrint(string.format("Saved objects in %d ms\n", GetPreciseTicks() - t))
	
	mapdata.TerrainHash = new_terrain_hash
	terrain.Save(folder)
	
	WaitMinimapSaving()
	
	if Platform.developer and (config.SaveEntityList or mapdata.SaveEntityList) then
		SaveMapEntityList(folder .. "entlist.txt")
	end
	
	UpdateMapMaxObjRadius()
	UpdateTerrainStats()
	
	local old_net_hash = mapdata.NetHash
	mapdata.NetHash = xxhash(mapdata.TerrainHash, mapdata.ObjectsHash)
	if old_net_hash ~= mapdata.NetHash then
		mapdata.LuaRevision = LuaRevision
		mapdata.OrgLuaRevision = OrgLuaRevision
		mapdata.AssetsRevision = AssetsRevision
	end
	if folder == GetMap() then
		mapdata:Save()
	end
	
	Msg("PostSaveMap")
	
	EditorSavingThread = false
	Msg("SaveMapDone")
	
	SVNAddFile(io.listfiles(folder))
end

---
--- Saves the current map, optionally creating a backup and/or a map variation patch.
---
--- @param skipBackup boolean (optional) If true, skips creating a backup of the map.
--- @param force boolean (optional) If true, forces the map to be saved even if the editor is not active or a map change is in progress.
--- @param folder string (optional) The folder to save the map in. If not provided, the current map folder is used.
--- @param silent boolean (optional) If true, suppresses any output during the save process.
---
function SaveMap(skipBackup, force, folder, silent)
	if (IsEditorSaving() or not IsEditorActive() or IsChangingMap()) and not force then
		return
	end
	
	PauseInfiniteLoopDetection("SaveMap")
	
	EditorSavingThread = CurrentThread()
	if not silent then print("Saving...") end
	WaitNextFrame(4)
	local start_time = GetPreciseTicks()
	
	if EditedMapVariation then
		XEditorCreateMapPatch(EditedMapVariation:GetMapPatchPath(), "add_to_svn")
	else
		save_map(skipBackup, folder, silent)
	end
	
	if not silent then
		print(EditedMapVariation and "Map variation patch saved in" or "Map saved in", GetPreciseTicks() - start_time, "ms")
	end
	ResumeInfiniteLoopDetection("SaveMap")
end

local function check_radius(obj, radius, surf)
	local max_radius = obj.max_allowed_radius
	if Max(radius, surf) > max_radius then
		StoreErrorSource(obj, string.format("Object too large: %.3f / %.3f m", Max(radius, surf) * 1.0 / guim, max_radius * 1.0 / guim))
		radius = Min(max_radius, radius)
		surf = Min(max_radius, surf)
	end
	return radius, surf
end

---
--- Calculates the maximum object radius and maximum surface radius for objects in the map.
---
--- @param enum_flags_all number (optional) Bitfield of flags to filter objects by. Only objects with all these flags set will be considered.
--- @param enum_flags_any number (optional) Bitfield of flags to filter objects by. Objects with at least one of these flags set will be considered.
--- @param game_flags_all number (optional) Bitfield of game flags to filter objects by. Only objects with all these flags set will be considered.
--- @return number max_radius The maximum object radius in the map.
--- @return number max_surf The maximum surface radius of objects in the map.
--- @return table max_radius_obj The object with the maximum radius.
--- @return table max_surf_obj The object with the maximum surface radius.
---
function CalcMapMaxObjRadius(enum_flags_all, enum_flags_any, game_flags_all)
	local max_radius_obj, max_surf_obj
	local max_radius, max_surf = 0, 0
	local playbox = GetPlayBox()
	game_flags_all = game_flags_all or const.gofPermanent
	MapForEach("map", enum_flags_all, enum_flags_any, game_flags_all, function(obj, playbox)
		local radius = obj:GetRadius()
		local surf = radius
		if max_surf < radius then
			surf = obj:GetMaxSurfacesRadius2D()
		end
		radius, surf = check_radius(obj, radius, surf)
		if max_radius < radius then
			max_radius, max_radius_obj = radius, obj
		end
		if max_surf < surf and playbox:Dist2D2(obj) <= surf * surf then
			max_surf, max_surf_obj = surf, obj
		end
	end, playbox)
	return max_radius, max_surf, max_radius_obj, max_surf_obj
end

local function max_obj_radius(obj)
	local radius = obj:GetRadius()
	local surf = obj:GetMaxSurfacesRadius2D()
	radius, surf = check_radius(obj, radius, surf)
	for _, attach in ipairs(obj:GetAttaches() or empty_table) do
		local radius_i, surf_i = max_obj_radius(attach)
		radius = Max(radius, radius_i)
		surf = Max(surf, surf_i)
	end
	return radius, surf
end

---
--- Updates the maximum object radius and maximum surface radius for objects in the map.
---
--- If an `obj` is provided, it calculates the maximum radius and surface radius for that object and its attached objects.
--- If no `obj` is provided, it calculates the overall maximum radius and surface radius for all objects in the map.
---
--- The calculated maximum radius and surface radius are stored in the `mapdata` table, and the `SetMapMaxObjRadius` function is called to update the map data.
---
--- @param obj table (optional) The object to calculate the maximum radius and surface radius for.
---
function UpdateMapMaxObjRadius(obj)
	local radius, surf
	if obj then
		radius, surf = max_obj_radius(obj)
		radius = Max(mapdata.MaxObjRadius, radius)
		if GetPlayBox():Dist2D2(obj) > surf * surf then
			surf = 0
		end
		surf = Max(mapdata.MaxSurfRadius2D, surf)
	else
		radius, surf = CalcMapMaxObjRadius()
	end
	mapdata.MaxObjRadius = radius
	mapdata.MaxSurfRadius2D = surf
	SetMapMaxObjRadius(radius, surf)
end

---
--- Updates the terrain statistics in the `mapdata` table.
---
--- This function calculates the average, minimum, and maximum height values for the terrain in the current map, and stores these values in the `mapdata` table.
---
--- @function UpdateTerrainStats
--- @return nil
function UpdateTerrainStats()
	local tavg, tmin, tmax = terrain.GetAreaHeight()
	mapdata.HeightMapAvg = tavg
	mapdata.HeightMapMin = tmin
	mapdata.HeightMapMax = tmax
end

---
--- Shows the map object with the maximum surface radius.
---
--- This function calculates the maximum object radius and surface radius for all objects in the map, and then uses the `EditorViewMapObject` function to focus the editor view on the object with the maximum surface radius.
---
--- @function ShowMapMaxSurfObj
--- @return nil
function ShowMapMaxRadiusObj()
	local radius, surf, radius_obj, surf_obj = CalcMapMaxObjRadius()
	EditorViewMapObject(radius_obj, nil, true)
end

---
--- Shows the map object with the maximum surface radius.
---
--- This function calculates the maximum object radius and surface radius for all objects in the map, and then uses the `EditorViewMapObject` function to focus the editor view on the object with the maximum surface radius.
---
--- @function ShowMapMaxSurfObj
--- @return nil
function ShowMapMaxSurfObj()
	local radius, surf, radius_obj, surf_obj = CalcMapMaxObjRadius()
	EditorViewMapObject(surf_obj, nil, true)
end

function OnMsg.EditorObjectOperation(op_finished, objs)
	if op_finished then
		for _, obj in ipairs(objs) do
			UpdateMapMaxObjRadius(obj)
		end
	end
end

if Platform.developer then
	ValidateAllMapsThread = false
	
	-- see ValidateMapObjects for documentation of options
	---
 --- Validates all maps in the game.
 ---
 --- This function suspends the thread debug hook and file system changes, disables map validation, and then iterates through all maps in the game, validating the map objects for each one.
 ---
 --- @function WaitValidateAllMaps
 --- @param options table Optional table of options for the map validation, including `validate_properties`, `validate_Object`, and `validate_CObject`.
 --- @param filter function Optional filter function to apply to the map data before validating.
 --- @return nil
 function WaitValidateAllMaps(options, filter)
		ValidateAllMapsThread = CurrentThread()
		local old = LocalStorage.DisableDLC
		SetAllDevDlcs(true)
		
		SuspendThreadDebugHook("ValidateAllMaps")
		
		filter = filter or GameMapFilter
	
		local mapdata = table.filter(MapData, filter)
		local maps = table.keys(mapdata, true)
		GameTestsPrintf("Validating %d maps %s...", #maps, ValueToLuaCode(options))
		for i, map in ipairs(maps) do
			GameTestsPrintf("\n[%d/%d] Validating map \"%s\"", i, #maps, map)
			ChangeMap(map)
			ValidateMapObjects(options)
			WaitGameTimeStart()
		end
		
		LocalStorage.DisableDLC = old
		SaveLocalStorage()
		
		ResumeThreadDebugHook("ValidateAllMaps")
		ValidateAllMapsThread = false
	end
	
	function OnMsg.PostNewMapLoaded(silent)
		if IsValidThread(ValidateAllMapsThread) or config.NoMapValidation then
			return
		end
		if not silent and Platform.desktop then
			ValidateMapObjects()
		end
		UpdateCollectionsEditor()
	end
	function GameTestsNightly.ValidateAllMaps()
		WaitValidateAllMaps{ validate_properties = true, validate_Object = true, validate_CObject = false }
	end
	
	-- example usage: *r WaitResaveAllMapdata(UpdateTerrainStats)
	---
  --- Waits for all map data to be resaved, optionally applying a filter.
  ---
  --- This function suspends the thread debug hook and file system changes, disables map validation, and then iterates through all maps in the game, resaving the map data for each one.
  ---
  --- @function WaitResaveAllMapdata
  --- @param callback function Optional callback function to execute for each map.
  --- @param filter function Optional filter function to apply to the map data before resaving.
  --- @return nil
 ---
 --- Waits for all map data to be resaved, optionally applying a filter.
 ---
 --- This function suspends the thread debug hook and file system changes, disables map validation, and then iterates through all maps in the game, resaving the map data for each one.
 ---
 --- @function WaitResaveAllMapdata
 --- @param callback function Optional callback function to execute for each map.
 --- @param filter function Optional filter function to apply to the map data before resaving.
 --- @return nil
 function WaitResaveAllMapdata(callback, filter)
		if not callback then return end
		
		PauseGame(8)
		SuspendThreadDebugHook("WaitUpdateAllMapdata")
		SuspendFileSystemChanged("WaitUpdateAllMapdata")
		table.change(config, "WaitUpdateAllMapdata", {
			NoMapValidation = true
		})
		
		filter = filter or GameMapFilter
		local datas = table.filter(MapData, filter)
		local i, count = 0, table.count(datas)
		for map, mapdata in sorted_pairs(datas) do
			i = i + 1
			GameTestsPrintf("\n[%d/%d] Updating map \"%s\"", i, count, map)
			local game_logic = mapdata.GameLogic
			mapdata.GameLogic = false
			ChangeMap(map)
			mapdata.GameLogic = game_logic
			if not procall(callback) then
				break
			end
			mapdata:Save()
			DoneMap()
		end
		
		ChangeMap("")
		table.restore(config, "WaitUpdateAllMapdata")
		ResumeFileSystemChanged("WaitUpdateAllMapdata")
		ResumeThreadDebugHook("WaitUpdateAllMapdata")
		ResumeGame(8)
	end
end

--- Enters the editor, waits for any map changes or saving to complete, activates the editor if needed, and then saves the current map.
---
--- This function is used to ensure that the editor is in a consistent state before saving the map. It waits for any ongoing map changes or saving operations to complete, activates the editor if it is not already active, and then saves the current map.
---
--- @function EnterEditorSaveMap
--- @return nil
function EnterEditorSaveMap()
	CreateRealTimeThread( function()
		while IsChangingMap() or IsEditorSaving() do
			WaitChangeMapDone()
			if IsEditorSaving() then
				WaitMsg("SaveMapDone")
			end
		end
		if not IsEditorActive() then
			EditorActivate()
		end
		SaveMap()
	end)
end

-- rotating objects feature
if FirstLoad then
	rotation_thread = false
	editor.RotatingObjects = {}
end

function OnMsg.GameEnterEditor()
	DeleteThread(rotation_thread)
	rotation_thread = CreateRealTimeThread(function()
		while true do
			for i=1, #editor.RotatingObjects do
				local item = editor.RotatingObjects[i]
				if IsValid(item.obj) then
					item.obj:SetAngle( item.obj:GetVisualAngle() + 60, 100 )
				end
			end
			Sleep(100)
		end
	end)
end

function OnMsg.GameExitEditor()
	DeleteThread(rotation_thread)
	for i = 1, #editor.RotatingObjects do
		local item = editor.RotatingObjects[i]
		if IsValid(item.obj) then
			item.obj:SetAngle(60 * item.angle)
		end
	end
	editor.RotatingObjects = {}
end

if Platform.developer then
	--- Dumps the surfaces (collision and occlusion) of all entities in the game.
 ---
 --- This function iterates through all entities in the game, and for each entity, it checks the number of collision and occlusion surfaces. If the entity has at least one collision or occlusion surface, it adds a string describing the entity and the number of surfaces to a table. Finally, it sorts the table and writes the contents to a file named 'surfs.txt'.
 ---
 --- @function DumpEntitiesSurfaces
 --- @return nil
 function DumpEntitiesSurfaces()
		local out = {}
		local visited = {}

		ClassDescendants("CObject", function(class_name, class, out, visited)
			local entity = class:GetEntity()

			if visited[entity] then	return end
			visited[entity] = 1

			local num_col, num_occ = GetEntityNumSurfaces(entity, EntitySurfaces.Collision), GetEntityNumSurfaces(entity, EntitySurfaces.Occluder)
			if num_col ~= 0 or num_occ ~= 0 then
				local s = entity .. '\t\thas ' .. num_col .. ' collision and ' .. num_occ .. ' occlusion surfs'
				out[#out + 1] = s
			end
		end, out, visited)

		table.sort(out)
		local f = io.open('surfs.txt', 'w')
		for _, l in ipairs(out) do
			f:write(l .. '\r\n')
		end
		f:close()
	end

	--- Removes all occluders from the game map.
 ---
 --- This function iterates through all `CObject` entities in the game map and sets their `occludes` property to `false`, effectively removing them as occluders.
 ---
 --- @function RemoveAllOccluders
 --- @return nil
 function RemoveAllOccluders()
		for _, obj in ipairs(MapGet("map", "CObject")) do
			obj:SetOccludes(false)
		end
	end
end

--------------------------------------------------------------------------------------------

function SelectSameFloorObjects(sel)
	local objs = MapGet("map", "attached", false, "collection", editor.GetLockedCollectionIdx(), true)
	local same_floor = {}
	local oztop, ozbottom = -1, 9999*guim
	if IsValid(sel) then
		sel = { sel }
	end
	
	for i=1,#sel do
		local o = sel[i]
		local ocenter, oradius = o:GetBSphere()
		local oz = o:GetVisualPos():z()
		local obbox = GetEntityBoundingBox(o:GetEntity())
		oztop = Max(oztop, oz + obbox:max():z() + 50 * guic)
		ozbottom = Min(ozbottom, oz  + obbox:min():z()- 50 * guic)
	end
	
	for i=1,#objs do
		local p = objs[i]
		local pz = p:GetVisualPos():z()
		local pbbox = GetEntityBoundingBox(p:GetEntity())

		local pztop = pz + pbbox:max():z()
		local pzbottom = pz  + pbbox:min():z()
		
		if pztop < oztop and pzbottom > ozbottom then
			same_floor[1+#same_floor] = objs[i]
		end
	end
	
	editor.ClearSel()
	editor.AddToSel(same_floor)
--- Closes the file.
---
--- This function is used to close the file that was previously opened.
end