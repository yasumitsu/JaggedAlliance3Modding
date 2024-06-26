exported_files_header_warning = "-- ====== HACKED BY SIR NI THIS IS AN AUTOMATICALLY GENERATED FILE! ========\n\n"

---
--- Returns a list of classes that have a valid entity.
---
--- @param ... Any additional arguments to pass to `ClassDescendantsList`.
--- @return table A list of class names that have a valid entity.
function GetClassesWithEntities(...)
	return ClassDescendantsList("CObject", function(name, class, parent1, ...)
		return IsValidEntity(class:GetEntity()) and
			(not parent1 or class:IsKindOfClasses(parent1, ...))
	end, ...)
end

---
--- Returns a list of deprecated particle system names.
---
--- If `config.UseDeprecatedParticles` is false, this function returns the list of names in `config.DeprecatedParticleNames`. Otherwise, it returns an empty table.
---
--- @return table A list of deprecated particle system names.
function GetDeprecatedParticleNames()
	return not config.UseDeprecatedParticles and config.DeprecatedParticleNames or empty_table
end 

---
--- Returns a list of particle system names that are not deprecated.
---
--- @param filter function|nil An optional function to filter the list of particle system names.
--- @param ui boolean Whether to return the list of particle system names for the UI.
--- @return table A list of particle system names that are not deprecated.
function GetParticleSystemNames(filter, ui)
	local to_ignore = GetDeprecatedParticleNames()
	local list = {}
	local parsys = GetParticleSystemNameList(ui)
	for i = 1, #parsys do
		local name = parsys[i]
		if not filter or filter(name) then
			for j = 1, #to_ignore do
				if string.find_lower(name, to_ignore[j]) then
					name = false
					break 
				end
			end
			if name then
				list[#list + 1] = name
			end
		end
	end
	table.sort(list)
	return list
end

---
--- Returns a list of particle system names that are not deprecated.
---
--- @param filter function|nil An optional function to filter the list of particle system names.
--- @param ui boolean Whether to return the list of particle system names for the UI.
--- @return table A list of particle system names that are not deprecated.
function ParticlesComboItems()
	local t = GetParticleSystemNames(nil, false) 
	table.insert(t, 1, "") 
	return t
end

---
--- Returns a list of particle system names that are not deprecated, for use in the UI.
---
--- This function calls `GetParticleSystemNames` with the `true` flag to indicate that the list should be for the UI.
---
--- @return table A list of particle system names that are not deprecated, with an empty string as the first item.
function UIParticlesComboItems()
	local t = GetParticleSystemNames(nil, true) 
	table.insert(t, 1, "") 
	return t
end

---
--- Returns a list of all entities in the game.
---
--- This function is a convenience wrapper around `GetAllEntities()` that returns a sorted list of all entity names.
---
--- @return table A sorted list of all entity names.
function GetAllEntitiesCombo()
	return table.keys(GetAllEntities(), true)
end

---
--- Gathers a list of items from a message sent to an object.
---
--- @param msg string The message to send to the object.
--- @param obj table The object to send the message to.
--- @param def any An optional default value to prepend to the list of items.
--- @return table A sorted list of items gathered from the message.
function GatherMsgItems(msg, obj, def)
	local items = {}
	Msg(msg, items, obj)
	items = table.keys(items, true)
	if def ~= nil then
		table.insert(items, 1, def)
	end
	return items
end

---
--- Generates a function that gathers a list of items from a message sent to an object.
---
--- @param msg string The message to send to the object.
--- @param def any An optional default value to prepend to the list of items.
--- @return function A function that, when called with an object, returns a sorted list of items gathered from the message.
function GatherComboItems(msg, def)
	return function(self)
		return GatherMsgItems(msg, self, def)
	end
end

---
--- Calculates the weighted average position of a list of objects.
---
--- If the list is empty, returns the point `point20`. If the list has only one object, returns the visual position of that object. Otherwise, calculates the average of the visual positions of all objects in the list.
---
--- If the average position has a valid Z coordinate, the function returns a 3D point. Otherwise, it returns a 2D point.
---
--- @param objects table A list of objects
--- @return point The weighted average position of the objects
function GetWeightPos(objects)
end
GetWeightPos = function(objects)
	if not objects or #objects == 0 then
		return point20
	elseif #objects == 1 then
		return objects[1]:GetPos()
	end
	local pos = objects[1]:GetVisualPos()
	for i = 2, #objects do
		pos = pos + objects[i]:GetVisualPos()
	end
	if pos:IsValidZ() then
		return point(pos:x() / #objects, pos:y() / #objects, pos:z() / #objects)
	end
	return point(pos:x() / #objects, pos:y() / #objects)
end

---
--- Finds the nearest object from a list of objects to a given position.
---
--- @param pos point The position to find the nearest object to.
--- @param objects table A list of objects to search.
--- @param max_distance number (optional) The maximum distance to consider an object as the nearest.
--- @return object, number The nearest object and its distance from the given position.
---
NearestObject = function(pos, objects, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		local d = obj:GetDist(pos)
		if (not max_distance or d < max_distance) and (not best or d < best_distance) then
			best_distance = d
			best = obj
		end
	end
	return best, best_distance
end

---
--- Finds the nearest object from a list of objects to a given position, using a custom distance function.
---
--- @param pos point The position to find the nearest object to.
--- @param objects table A list of objects to search.
--- @param fDist function A custom distance function that takes a position and an object, and returns the distance between them.
--- @param max_distance number (optional) The maximum distance to consider an object as the nearest.
--- @return object, number The nearest object and its distance from the given position.
---
NearestObjectDistFunc = function(pos, objects, fDist, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		local d = fDist(pos, obj)
		if (not max_distance or d < max_distance) and (not best or d < best_distance) then
			best_distance = d
			best = obj
		end
	end
	return best, best_distance
end

---
--- Finds the nearest object from a list of objects to a given position, that satisfies a given condition.
---
--- @param pos point The position to find the nearest object to.
--- @param objects table A list of objects to search.
--- @param f function A condition function that takes an object and returns a boolean indicating whether it should be considered.
--- @param max_distance number (optional) The maximum distance to consider an object as the nearest.
--- @return object, number The nearest object and its distance from the given position.
---
NearestObjectCond = function(pos, objects, f, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		if f(obj) then
			local d = obj:GetDist(pos)
			if (not max_distance or d < max_distance) and (not best or d < best_distance) then
				best_distance = d
				best = obj
			end
		end
	end
	return best, best_distance
end

local AttachToSpot = function(to, obj, spot_type)
	local idx = -1
	if spot_type then
		idx = to:GetSpotBeginIndex(spot_type)
		if idx == -1 then
			local name = to:GetEntity() ~= "" and to:GetEntity() or to.class
			printf("Missing spot '%s' in '%s' state '%s'",
				type(spot_type) == "number" and string.sub(GetSpotNameByType(spot_type),3) or tostring(spot_type),
				to.class, GetStateName(to:GetState()))
			idx = to:GetSpotBeginIndex("Origin")
		end
	end
	to:Attach(obj, idx)
	return obj
end

---
--- Attaches a new object of the given class to the specified object at the given spot type.
---
--- @param to object The object to attach the new object to.
--- @param childclass string The class name of the object to be attached.
--- @param spot_type string|number (optional) The type of spot to attach the object to. If not provided, the object will be attached to the first available spot.
--- @return object The attached object.
---
AttachToObject = function(to, childclass, spot_type)
	return AttachToSpot(to, PlaceObject(childclass, nil, const.cofComponentAttach), spot_type)
end
---
--- Attaches a new particle effect of the given class to the specified object at the given spot type.
---
--- @param to object The object to attach the new particle effect to.
--- @param part string The class name of the particle effect to be attached.
--- @param spot_type string|number (optional) The type of spot to attach the particle effect to. If not provided, the particle effect will be attached to the first available spot.
--- @return object The attached particle effect.
---

AttachPartToObject = function(to, part, spot_type)
	return AttachToSpot(to, PlaceParticles(part, nil, const.cofComponentAttach), spot_type)
end

local AttachToSpotIdx = function(to, obj, spot_idx)
	if spot_idx == -1 then
		local name = to:GetEntity() ~= "" and to:GetEntity() or to.class
		local spot_type = to:GetSpotsType(spot_idx)
		printf("Missing spot '%s' in '%s' state '%s'",
			type(spot_type) == "number" and string.sub(GetSpotNameByType(spot_type),3) or tostring(spot_type),
			to.class, GetStateName(to:GetState()))
		spot_idx = to:GetSpotBeginIndex("Origin")
	end
	to:Attach(obj, spot_idx)
	return obj
end

---
--- Attaches a new object of the given class to the specified object at the given spot index.
---
--- @param to object The object to attach the new object to.
--- @param childclass string The class name of the object to be attached.
--- @param spot_idx number The index of the spot to attach the object to.
--- @return object The attached object.
---
AttachToObjectSpotIdx = function(to, childclass, spot_idx)
	return AttachToSpotIdx(to, PlaceObject(childclass, nil, const.cofComponentAttach), spot_idx)
end

---
--- Gets an array of free spots on the given object that match the given spot name and are within the given facing tolerance.
---
--- @param obj object The object to get the free spots from.
--- @param spot_name string The name of the spots to get.
--- @param zdir vector The facing direction to check against.
--- @param tolerance number The maximum angle tolerance in radians between the spot direction and the given facing direction.
--- @return table An array of spot indices that match the criteria.
---
GetFacingSpots = function(obj, spot_name, zdir, tolerance)
	local t = GetFreeSpotArray(obj, spot_name)
	for i = #t, 1, -1 do
		local spot = t[i]
		local angle, axis = obj:GetSpotVisualRotation(spot)
		local spot_zdir = RotateAxis(axis_x, axis, angle)
		if GetAngle(zdir, spot_zdir) > tolerance then
			table.remove(t, i)
		end
	end
	return t
end

---
--- Gets an array of free spots on the given object that match the given spot name and are not currently occupied by attached objects.
---
--- @param obj object The object to get the free spots from.
--- @param spot_name string The name of the spots to get.
--- @return table An array of spot indices that are free.
---
GetFreeSpotArray = function(obj, spot_name)
	local spot_w_attaches = {}
	for i = 1, obj:GetNumAttaches() do
		local a = obj:GetAttach(i)
		spot_w_attaches[a:GetAttachSpot()] = true
	end
	local first, last = obj:GetSpotRange(spot_name)
	local t = {}
	for i = first, last do
		local spot = obj:GetSpotPos(i)
		if spot_w_attaches[spot] then
			t[#t+1] = obj:GetSpotPos(spot)
		end
	end
	if #t <= 1 then
		local i = 1
		while true do
			local spot_name = spot_name .. i
			if not obj:HasSpot(spot_name) then
				break
			end
			local spot = obj:GetSpotBeginIndex(spot_name)
			if spot == -1 then
				break
			end
			if not spot_w_attaches[spot] then
				t[#t+1] = spot
			end
			i = i + 1
		end
	end
	
	return t
end

---
--- Calculates a color gradient between two colors based on a given value within a range.
---
--- @param value number The value to calculate the gradient for.
--- @param min number The minimum value of the range.
--- @param max number The maximum value of the range.
--- @param colormin table The color at the minimum value.
--- @param colormax table The color at the maximum value.
--- @param mid number (optional) The midpoint value of the range.
--- @param colormid table (optional) The color at the midpoint value.
--- @return table The calculated color gradient.
---
function CalcColorGradient(value, min, max, colormin, colormax, mid, colormid)
	if value<=min then
		return colormin
	elseif value>=max then
		return colormax
	elseif not mid then
		return InterpolateRGB(colormin,colormax,value-min,max-min)
	elseif value < mid then
		return InterpolateRGB(colormin,colormid,value-min,mid-min)
	else
		return InterpolateRGB(colormid,colormax,value-mid,max-mid)
	end
end

-- animation
if Platform.developer then
	-- debug
	ShowAnimDebug = function(obj, color1, color2)
		if not obj then return end
		
		local text = PlaceObject("Text")
		text:SetDepthTest(true)
		text:SetColor1(color1 or text.color1)
		text:SetColor2(color2 or text.color2)
				
		obj:Attach(text)
		
		CreateRealTimeThread(function()
			while IsValid(text) do
				local infos = {}
				local channel = 1
				while true do
					local info = obj:GetAnimDebug(channel)
					if not info then break end
					infos[ channel ] = string.format("%d. %s\n", channel, info)
					channel = channel + 1
				end
				text:SetText(table.concat(infos))
				WaitNextFrame()
			end
		end)
	end
	
	CycleAnim = function(obj, anim_name)
		if type(anim_name) ~= "string" or string.len(anim_name) < 2 then
			return
		end
		local state = EntityStates[anim_name]
		if not state then
			print("Unknown animation: "..anim_name)
		else
			obj:SetCommand(false)
			obj:SetState(state)
		end
	end

	CycleCurAnim = function(obj)
		local state = obj:GetState()
		obj:SetCommand(false)
		obj:SetState(state)
	end
end

ScreenshotMapName = GetMapName

---
--- Generates a filename metadata string to be appended to screenshot filenames.
--- This function can be overridden in the project to provide custom filename metadata.
---
--- @return string The filename metadata string.
---
function ScreenshotFilenameMeta()
	return ""
end
function ScreenshotFilenameMeta() -- override in project
	return ""
end

---
--- Generates a screenshot filename with an incrementing index and optional metadata.
---
--- @param prefix string The prefix to use for the filename.
--- @param folder string The folder to save the screenshot in. If not provided, the filename will not include a folder.
--- @return string The generated filename.
---
function GenerateScreenshotFilename(prefix, folder)
	folder = folder or ""
	if not string.match(folder, "/$") and #folder > 0 then
		folder = folder .. "/"
	end
	local existing_files = io.listfiles(folder, prefix .. "*.png")
	local index = 0
	for i=1,#existing_files do
		index = Max(index, tonumber(string.match(existing_files[i], prefix .. "(%d+)") or 0))
	end
	local filename_meta = ScreenshotFilenameMeta() or ""
	return string.format("%s%s%04d%s.png", folder, prefix, index+1, filename_meta)
end

---
--- Gets the visible position on the terrain, taking into account the current camera.
---
--- If the terrain cursor is valid and within the terrain bounds, it is returned.
--- Otherwise, the position is calculated based on the current camera type:
--- - RTS camera: Returns the camera position plus a vector pointing 10 units in front of the camera.
--- - 3rd person camera: Returns the camera eye position plus a vector pointing 10 units in front of the camera.
--- - Max camera: Returns the camera position plus a vector pointing 10 units in front of the camera.
--- - Default camera: Returns the camera eye position plus a vector pointing 10 units in front of the camera.
---
--- @return Vector3 The visible position on the terrain.
---
function GetVisiblePos()
	local pt = GetTerrainGamepadCursor()
	if pt ~= InvalidPos() and terrain.IsPointInBounds(pt) then return pt end
	local pos, look_at
	if cameraRTS.IsActive() then
		pos, look_at = cameraRTS.GetPos(), cameraRTS.GetLookAt()
	elseif camera3p.IsActive() then
		pos, look_at = camera3p.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		pos, look_at = cameraMax.GetPosLookAt()
	elseif camera.GetLookAt then
		pos, look_at = camera.GetEye(), camera.GetLookAt()
	else
		return pt
	end
	local v = look_at - pos
	return (pos + SetLen(v, 10 * guim)):SetInvalidZ()
end

---
--- Gets a list of all entities that are instances of the given class or any of its descendants.
---
--- @param class string The class to get the entities for.
--- @return table The list of entities.
---
function GetClassAndDescendantsEntities(class)
	local processed = {}
	local entities = {}
	ClassDescendantsListInclusive(class, function(name, classdef, processed, entities)
		local entity = classdef:GetEntity()
		if entity and not processed[entity] then
			processed[entity] = true
			if IsValidEntity(entity) then
				entities[#entities + 1] = entity
			end
		end
	end, processed, entities)
	return entities
end

---
--- Gets a list of all states from the given category for the class and its descendants.
---
--- @param class string The class to get the states for.
--- @param category string The category of states to get.
--- @return table The list of states.
---
function GetClassDescendantsStates(class, category)
	local entities = GetClassAndDescendantsEntities(class)
	local animations = {}
	local processed = {}
	for i = 1, #entities do
		local entity = entities[i]
		local ent_anims = GetStatesFromCategory(entity, category)
		for j = 1, #ent_anims do
			local anim = ent_anims[j]
			if not processed[anim] then
				processed[anim] = true
				animations[#animations + 1] = anim
			end
		end
	end
	table.sort(animations, CmpLower)
	return animations
end

---
--- Stores the source of an error.
---
--- @return string The error source.
---
function StoreErrorSource()
	return ""
end

function StoreWarningSource()
	return ""
end

local esCollision = EntitySurfaces.Collision
local cmPassability = const.cmPassability

---
--- Checks if the given object or entity has any collision surfaces.
---
--- @param obj_or_ent table The object or entity to check for collisions.
--- @return boolean True if the object or entity has any collision surfaces, false otherwise.
---
function HasCollisions(obj_or_ent)
	return HasAnySurfaces(obj_or_ent, esCollision) or HasMeshWithCollisionMask(obj_or_ent, cmPassability)
end

-- Helper functions for heuristic calculation
--- Calculates a heuristic evaluation value based on the difference between the current value `v` and the maximum value `maxv`.
---
--- @param v number The current value to evaluate.
--- @param maxv number The maximum value to compare against.
--- @param deltaPlus number The multiplier to use when the current value is greater than the maximum value.
--- @param deltaMinus number The multiplier to use when the current value is less than the maximum value.
--- @return number The heuristic evaluation value.
function HeuristicEval(v, maxv, deltaPlus, deltaMinus)
	deltaMinus = deltaMinus or deltaPlus
	if maxv > v then
		return (maxv - v) * deltaMinus
	else
		return (v - maxv) * deltaPlus
	end
end

if Platform.developer then
	g_ProfileStats = rawget(_G, "g_ProfileStats") or {}
	g_Sections =  rawget(_G, "g_Sections") or 1
	local statsInterval = 3000
	function __SectionStart(s)
		PerformanceMarker(g_Sections)
		g_Sections = g_Sections + 1
	end

	function __SectionEnd(s)
		g_Sections = g_Sections - 1
		local time = GetPerformanceMarkerElapsedTime(g_Sections)
		local t = g_ProfileStats[s] or {}
		local now = GameTime()
		for gt in pairs(t) do
			if now - gt > statsInterval then
				t[gt] = nil
			end
		end
		t[now] = (t[now] or 0) + time
		g_ProfileStats[s] = t
	end
	
	function __SectionStats(s)	
		local total = 0
		local t = g_ProfileStats[s] or {}
		local now = GameTime()
		local samples = 0
		for gt, time in pairs(t) do
			if now - gt > statsInterval then
				t[gt] = nil
			end
			total = total + time
			samples = samples + 1
		end
		return total, samples
	end
	local thread
	function __PrintStats(s)
		if thread then
			DeleteThread(thread)
		end
		thread = CreateRealTimeThread(function()
			while true do
				local total, samples = __SectionStats(s)
				printf("time: %d / %d", total, samples)
				Sleep(500)
			end
		end)
	end
	
else
	function __SectionStart(s)
	end

	function __SectionEnd(s)
	end
end

--- Saves the current game state.
---
--- This function is responsible for persisting the current state of the game, such as player progress, inventory, and other relevant data, so that it can be restored later.
function SaveGameState()
end

--- Loads the current game state.
---
--- This function is responsible for restoring the previous state of the game, such as player progress, inventory, and other relevant data, so that the player can continue from where they left off.
function LoadGameState()
end

--- Gets the scaling percentage for the current screen size.
---
--- This function calculates the scaling percentage required to fit the game's original
--- resolution (1280x720 or 1024x768) within the current screen size, while maintaining
--- the aspect ratio. The scaling percentage is the minimum of the horizontal and vertical
--- scaling percentages.
---
--- @return number The scaling percentage, as a value between 0 and 100.
function GetScalingPerc()
	local screen_sz = UIL.GetScreenSize()
	local res16to9 = screen_sz:x() * 10 / screen_sz:y() > 15
	local org_size = res16to9 and point(1280, 720) or point(1024, 768)
	local percX = screen_sz:x() * 100 / org_size:x()
	local percY = screen_sz:y() * 100 / org_size:y()
	return Min(percX, percY)
end

--- Waits for a screenshot to be captured and written to a file.
---
--- This function captures a screenshot of the current screen and writes it to a file. It can optionally include or exclude the user interface elements from the screenshot, and adjust the size and quality of the output image.
---
--- @param filename string The path and filename to write the screenshot to.
--- @param options table An optional table of options to configure the screenshot capture:
---   - interface boolean Whether to include the user interface elements in the screenshot (default: true).
---   - width number The width of the screenshot in pixels (default: screen width).
---   - height number The height of the screenshot in pixels (default: screen height).
---   - src box The area of the screen to capture (default: the entire screen).
---   - quality number The quality of the output image, from 0 (worst) to 100 (best) (default: 100).
---   - alpha boolean Whether to include the alpha channel in the output image (default: false).
---   - timeout number The maximum time to wait for the screenshot to be written, in milliseconds (default: 3000).
--- @return string An error message if the screenshot could not be captured, or nil if the capture was successful.
function WaitCaptureScreenshot(filename, options)
	local options = options or {}
	local interface = options.interface or (options.interface == nil and true)
	local width = options.width or UIL.GetScreenSize():x()
	local height = options.height or UIL.GetScreenSize():y()
	local src = options.src or box(point20, UIL.GetScreenSize())
	local quality = options.quality or 100
	local alpha = options.alpha or (options.alpha == nil and false)
	
	local oldInterfaceInScreenshot = hr.InterfaceInScreenshot
	hr.InterfaceInScreenshot = interface and 1 or 0
	
	local done, err = false, false
	if not WriteScreenshot(filename, width, height, src, quality, alpha) then
		err = "could not start writing screenshot"
	end
	local timeout = options.timeout or 3000
	local st = now()
	while not(done or err) do
		done, err = ScreenshotWritten()
		Sleep(5)
		if now() - st > timeout then
			assert(false, "WriteScreenshot timeout!")
			err = "timeout"
			break
		end
	end
	hr.InterfaceInScreenshot = oldInterfaceInScreenshot
	if not err and not io.exists(filename) then
		err = "no file written"
	end
	return err
end

---
--- Changes the gamepad UI style for one or more players.
---
--- This function updates the `GamepadUIStyle` table with the new style values provided in the `new_style_table` argument. If any of the style values change, it will trigger a `GamepadUIStyleChanged` message.
---
--- @param new_style_table table A table containing the new gamepad UI style values, where the keys are the player indices and the values are the new styles.
---
function ChangeGamepadUIStyle(new_style_table)
	local change
	for k, v in pairs(new_style_table) do
		local prev_v = GamepadUIStyle[k]
		if prev_v ~= v then
			GamepadUIStyle[k] = v
			change = true
		end
	end
	if change then
		Msg("GamepadUIStyleChanged")
	end
end

---
--- Handles the event when the gamepad UI style is changed.
---
--- This function is called when the `GamepadUIStyleChanged` message is received. It forces a scale recalculation of the desktop to ensure the additional controller UI scale is taken into account.
---
function OnMsg.GamepadUIStyleChanged()
	-- force scale recalc of the desktop so that the additional controller UI scale is taken into account
	if terminal.desktop then
		terminal.desktop:OnSystemSize(UIL.GetScreenSize())
	end
end

---
--- Returns the gamepad UI style for the specified player.
---
--- @param player number The player index. If not provided, defaults to 1.
--- @return table The gamepad UI style for the specified player.
---
function GetUIStyleGamepad(player)
	return GamepadUIStyle[player or 1]
end

---
--- Returns the safe area box for the current screen.
---
--- The safe area box is the region of the screen that is guaranteed to be visible on all displays, taking into account any display overscan or other display-specific adjustments.
---
--- On PlayStation platforms, this simply returns the safe area as reported by the platform. On other platforms, it calculates the safe area based on the engine's display area margin setting.
---
--- @return number, number, number, number The x, y, width, and height of the safe area box.
---
function GetSafeAreaBox()
	if Platform.playstation then
		return UIL.GetSafeArea()
	else
		local margin = Max(0, EngineOptions and EngineOptions.DisplayAreaMargin)
		local percent = 100 - margin*2 or 0
		
		local screen_size = UIL.GetScreenSize()
		local screen_w, screen_h = screen_size:xy()
		
		local safe_size = MulDivRound(screen_size, percent, 100)
		local safe_w, safe_h = safe_size:xy()
		local x_margin, y_margin = (screen_w - safe_w)/2, (screen_h - safe_h)/2
		
		return x_margin, y_margin, x_margin + safe_w, y_margin + safe_h
	end
end

--- Converts one single value to an easy to read string.
-- @cstyle string format_value(value).
---
--- Converts a single value to an easy to read string.
---
--- @param v any The value to convert to a string.
--- @param levmax number The maximum level of recursion for table formatting.
--- @param lev number The current level of recursion for table formatting.
--- @return string The formatted string representation of the value.
---
function format_value(v, levmax, lev)
	lev = lev and (lev + 1) or 1
	if type(v) == "table" then
		if v.class then
			if not IsValid(v) then
				return v.class .. " invalid"
			elseif v:HasMember("handle") then
				return v.class .. " [" .. v.handle .. "]"
			else
				return v.class .. " " .. tostring(v:GetVisualPos())
			end
		end
		if lev and levmax and levmax <= lev then
			return "{...}"
		end
		local tab = "    "
		local indent = string.rep(tab, lev - 1)
		local r = {}
		for a,b in sorted_pairs(v) do
			r[#r + 1] = format_value(a, lev, lev) .. " = " .. format_value(b, levmax, lev)
		end
		return string.format("{\n%s%s%s\n%s}", tab, indent, table.concat(r, ",\n" .. tab .. indent), indent)
	elseif type(v) == "thread" then
		return tostring(v)
	elseif type(v) == "function" then
		local info = debug.getinfo(v)
		if info and info.short_src and info.linedefined then
			return string.format("%s(%d)", info.short_src, info.linedefined)
		end
	end
	return tostring(v)
end

--- Cuts a path at a given distance.
---
--- Modifies the given path by removing the portion of the path that exceeds the given distance.
---
--- @param path table A table of 2D points representing the path.
--- @param dist number The maximum distance to keep in the path.
--- @return number The actual distance of the modified path.
function CutPath(path, dist)
	local total_dist = 0
	local pt = path[1]
	
	for i = 2, #path do
		local seg_len = pt:Dist2D(path[i])
		if total_dist + seg_len > dist then
			local d = dist - total_dist
			local v = SetLen(path[i] - pt, d)
			path[i] = pt + v
			for j = i+1, #path do
				path[j] = nil
			end
			return dist
		end
		total_dist = total_dist + seg_len
		pt = path[i]
	end
	return total_dist
end

--- Checks if the given object has the specified animation state and that the state is not an error state.
---
--- @param obj table The object to check.
--- @param anim string The animation state to check.
--- @return boolean True if the object has the specified animation state and it is not an error state, false otherwise.
function IsValidAnim(obj, anim)
	return obj:HasState(anim) and not obj:IsErrorState(anim)
end

--- Checks if the given object is visible.
---
--- @param obj table The object to check.
--- @return boolean True if the object is visible, false otherwise.
function IsVisible(obj)
	return IsValid(obj) and obj:GetEnumFlags( const.efVisible ) ~= 0
end

--- Waits for the render mode to change to the specified mode.
---
--- This function will block until the render mode has changed to the specified mode. It will also call the provided callback function while waiting for the render mode to change.
---
--- @param new_mode string The new render mode to wait for.
--- @param call_while_waiting function (optional) A callback function to call while waiting for the render mode to change.
--- @param ... any (optional) Arguments to pass to the callback function.
--- @return boolean True if the render mode changed to the specified mode, false otherwise.
function WaitRenderMode(new_mode, call_while_waiting, ...)
	while IsRenderModeChanging() do
		Sleep(1) -- yield
	end
	SetRenderMode(new_mode)
	if call_while_waiting then call_while_waiting(...) end
	while IsRenderModeChanging() and GetRenderMode() ~= new_mode do
		Sleep(1) -- yield
	end
	return GetRenderMode() == new_mode
end

local IsValid = IsValid
--- Gets the topmost selection node for the given object.
---
--- This function recursively traverses the parent hierarchy of the given object until it finds the topmost node that has the `gofSelectionHierarchyNode` game flag set. This is useful for finding the root node of a selection hierarchy.
---
--- @param obj table The object to get the topmost selection node for.
--- @return table The topmost selection node, or the original object if it is not a selection node.
function GetTopmostSelectionNode(obj)
	if not IsValid(obj) then return obj end
	while true do
		local parent = obj:GetParent()
		if not parent or not IsValid(parent) then return obj end
		if obj:GetGameFlags(const.gofSelectionHierarchyNode) ~= 0 then return obj end
		obj = parent
	end
end

--- Validates the specified member of the given object.
---
--- If the member value is not valid, it is set to `nil`.
---
--- @param obj table The object to validate the member for.
--- @param member string The name of the member to validate.
function ValidateMember(obj, member)
	local value = obj and obj[member]
	if not value then return end
	if not IsValid(value) then
		obj[member] = nil
	end
end

---
--- Checks if cheats are available in the current game.
---
--- @return boolean true if cheats are available, false otherwise
function AreCheatsAvailable()
	return true
end

--- Gets a table of combo items from the given table `t`.
---
--- If `text` and `value` are provided, the function will create a table of combo items where each item is a table with keys `text` and `value`, populated from the corresponding keys in `t`.
---
--- If `text` and `value` are not provided, the function will create a table of combo items where each item is a table with keys `text` and `value`, where `text` is the value in `t` and `value` is the key in `t`.
---
--- @param t table The table to get the combo items from.
--- @param text string (optional) The key in `t` to use for the `text` field of the combo items.
--- @param value string (optional) The key in `t` to use for the `value` field of the combo items.
--- @return table A table of combo items.
function GetComboItems(t, text, value)
	local r = {}
	if text then
		for i = 1, #t do
			r[#r+1] = { text = t[i][text], value = t[i][value], }
		end
	else
		for k, v in pairs(t) do
			r[#r+1] = { text = v, value = k }
		end
	end
	
	return r
end

--- Validates the specified position `pt` and sets its Z coordinate to the terrain height plus an optional offset.
---
--- If `pt` is a valid position, its Z coordinate is returned. Otherwise, a new position is created with the terrain height plus the optional `terrain_offset` parameter.
---
--- @param pt table The position to validate and set the Z coordinate for.
--- @param terrain_offset number (optional) The offset to add to the terrain height.
--- @return table The validated position with the correct Z coordinate.
function ValidateZ(pt, terrain_offset)
	if IsValid(pt) then
		pt = pt:GetPos()
	end
	return pt:z() and pt or pt:SetZ(terrain.GetHeight(pt) + (terrain_offset or 0))
end
function ValidateZ( pt, terrain_offset )
	if IsValid(pt) then
		pt = pt:GetPos()
	end
	return pt:z() and pt or pt:SetZ( terrain.GetHeight( pt ) + (terrain_offset or 0) )
end

--- Resolves the Z coordinate of the given position.
---
--- This function takes the X, Y, and Z coordinates of a position and resolves the Z coordinate using the `ResolveVisualPosXYZ` function.
---
--- @param x number The X coordinate of the position.
--- @param y number The Y coordinate of the position.
--- @param z number The Z coordinate of the position.
--- @return number The resolved Z coordinate.
function ResolveZ(x, y, z)
	x, y, z = ResolveVisualPosXYZ(x, y, z)
	return z
end

-- prints the delay of a specific player input which originated at action_time (in PreciseTicks)
-- and whose consequences have happened in game_time (optional)
-- the delay is calculated in PreciseTicks between the time the action originated and its effect is shown on-screen
-- the time reported could be more than the actual delay if the lua code could not wakeup within a frame
--- Prints the delay between when a player input action originated and when its consequences were shown on-screen.
---
--- This function is used to measure the delay between when a player input action occurred (e.g. a mouse click) and when the visual effects of that action were presented to the player on-screen. It calculates the delay in milliseconds between the time the action originated (`action_time`) and the time its effects were shown (`game_time`).
---
--- @param action_time number The time the player input action originated, in PreciseTicks.
--- @param message string A message to be printed along with the delay information.
--- @param game_time number (optional) The time the visual effects of the action were presented, in GameTime. If not provided, the current GameTime is used.
function PrintDelayToScreen(action_time, message, game_time)
	game_time = game_time or GameTime()
	local rt = GetPreciseTicks(1000)
	CreateRealTimeThread(function()
		while hr.GameTimePresented - game_time < 0 do
			WaitMsg("OnRender")
		end
		printf("Action %s (display %dms) (delay %dms)", message, hr.PreciseTicksPresented - rt, hr.PreciseTicksPresented - action_time)
	end)
end

local use_console_out = Platform.developer or Platform.cmdline
printl = CreatePrint{"", output = use_console_out and ConsolePrint or DebugPrint, append_new_line = not use_console_out }
printfl = CreatePrint{"", output = use_console_out and ConsolePrint or DebugPrint, append_new_line = not use_console_out, format = string.format }

--[[ PrintDelayToScreen sample code
CreateRealTimeThread(function()
	local mouse_down_time
	local mouse_input_delay
	local draw_box_until
	
	local oldMouseEvent = Desktop.MouseEvent
	function Desktop:MouseEvent(event, pt, button, time)
		if event == "OnMouseButtonDown" and button = "L" then
			mouse_down_time = time
			mouse_input_delay = GetPreciseTicks(1000) - time
			self:Invalidate()
		end
		return oldMouseEvent(self, event, pt, button, time)
	end

	function Desktop:DrawAfterChildren()
		if mouse_down_time then
			PrintDelayToScreen(mouse_down_time, string.format("Mouse click white box (input delay %d)", mouse_input_delay))
			mouse_down_time = nil
			draw_box_until = RealTime() + 200
			--self:Invalidate()
		end
		if draw_box_until then
			if draw_box_until - RealTime() > 0 then
				UIL.DrawSolidRect(box(0, 0, 120, 120), RGB(255,255,255))
			else
				draw_box_until = nil
			end
		end
	end
end)
--]]

--- Checks if the application can quit.
---
--- This function checks if the application can quit by checking the `can_quit` field of the `result` table returned by the `Msg("CanApplicationQuit", result)` message. If the `GetIgnoreDebugErrors()` function returns true, the function will always return true, indicating that the application can quit.
---
--- @return boolean true if the application can quit, false otherwise
function CanApplicationQuit()
	local result = {can_quit = true}
	Msg("CanApplicationQuit", result)
	return GetIgnoreDebugErrors() or result.can_quit
end

--- Converts a table or a string representing a global table into a combo box list.
---
--- This function takes a table or a string representing a global table, and returns a function that can be used to generate a combo box list from the table. The function will sort the keys of the table and insert an optional first item at the beginning of the list.
---
--- @param tbl table|string The table or the name of the global table to convert to a combo box list.
--- @param first string (optional) The first item to insert in the combo box list.
--- @return function A function that generates a combo box list from the provided table.
function ToCombo(tbl, first)
	return function(...)
		tbl = type(tbl) ~= "string" and tbl or _G[tbl]
		tbl = type(tbl) == "function" and tbl(...) or tbl
		local items = #tbl == 0 and table.keys(tbl) or table.icopy(tbl)
		table.sort(items)
		if first == nil then first = "" end
		table.insert(items, 1, first)
		return items
	end
end

---

--- Places an object of the specified class at the current terrain cursor position.
---
--- @param class string The class of the object to place.
--- @return table The placed object.
function PlaceAtCursor(class)
	local obj = PlaceObject(class)
	obj:SetPos(GetTerrainCursor())
	return obj
end

if Platform.developer then

--- Prints information about any attach points that are out of range for the specified object.
---
--- This function iterates through all the attach points of the specified object and checks if the attach point index is within the valid range for the object's current state. If an attach point is out of range, it prints a message with information about the object, the attach point, and the valid range.
---
--- @param obj table The object to check for out-of-range attach points.
function PrintWrongSpotAttaches(obj)
	local entity = obj:GetEntity()
	local count = obj:GetNumAttaches()
	for i = 1, count do
		local attach = obj:GetAttach(i)
		local spot = attach:GetAttachSpot()
		local spot_name = obj:GetSpotName(spot)
		local spot_begin, spot_end = obj:GetSpotRange(obj:GetState(), spot_name)
		if spot < spot_begin or spot > spot_end then
			print(string.format("Entity: %s:%s, Class:[%s:%s] attach out of range for spot %s: %d[%d, %d]", entity, attach:GetEntity(), obj.class, attach.class, spot_name, spot, spot_begin, spot_end))
		end
	end
end

end

--- Sets the clip plane of the specified object based on the given progress value.
---
--- The clip plane is set to a plane that intersects the object's bounding box at a height determined by the progress value. This effectively "cuts off" the top portion of the object above the clip plane.
---
--- @param object table The object to set the clip plane for.
--- @param progress number The progress value, between 0 and 100, that determines the height of the clip plane.
function SetClipPlaneByProgress(object, progress)
	if progress == 100 then
		object:SetClipPlane(0)
		return
	end
	
	local total_box = object:GetObjectBBox()
	local function recursive_extend_box(obj)
		if obj:GetEntity() and obj:GetEntity() ~= "" then
			total_box = obj:GetObjectBBox(total_box)
		end
		for key, value in ipairs(obj:GetAttaches() or empty_table) do
			recursive_extend_box(value)
		end
	end
	recursive_extend_box(object)
	
	total_box = box(total_box:min():SetZ(object:GetVisualPos():z()), total_box:max())
	
	local z = total_box:minz() + MulDivRound(total_box:sizez(), progress, 100)
	local p1 = point(total_box:minx(), total_box:miny(), z)
	local p2 = point(total_box:minx(), total_box:maxy(), z)
	local p3 = point(total_box:maxx(), total_box:miny(), z)
	object:SetClipPlane(PlaneFromPoints(p1, p2, p3))
end

----

-- Similar to ValueToLuaCode, but representing the objects by class and handle only. Useful for prints.

--- Converts an object to a string representation.
---
--- The string representation includes the object's class, ID, handle, and position (if available).
---
--- @param value table The object to convert to a string.
--- @return string The string representation of the object.
function ObjToStr(value)
	local class = type(value) == "table" and value.class
	if not class then return "" end
	local handle = rawget(value, "handle")
	local handle_str = handle and string.format(" [%d]", handle) or ""
	local id = rawget(value, "id")
	local id_str = id and string.format(" \"%s\"", id) or ""
	local pos = IsValid(value) and value:GetPos()
	local pos_str = pos and string.format(" at %s", tostring(pos)) or ""
	return string.format("%s%s%s%s", class, id_str, handle_str, pos_str)
end

--- Converts a Lua value to a string representation.
---
--- This function handles various types of Lua values, including tables, objects, and functions.
--- For tables, it recursively converts the table contents to a string representation.
--- For objects, it uses the `ObjToStr` function to get a string representation of the object.
--- For functions, it attempts to get the global name of the function or falls back to a string representation.
---
--- @param value any The Lua value to convert to a string.
--- @param indent string (optional) The indentation to use for nested tables.
--- @param visited table (optional) A table to keep track of visited tables to avoid infinite recursion.
--- @return string The string representation of the Lua value.
function ValueToStr(value, indent, visited)
	local vtype = type(value)
	if vtype == "function" then
		return GetGlobalName(value) or tostring(value)
	end
	if IsT(value) then
		return TTranslate(value)
	end
	if vtype ~= "table" then
		return ValueToLuaCode(value)
	end
	if value == _G then
		return "_G"
	end
	local class = value.class
	if class then
		return ObjToStr(value)
	end
	if next(value) == nil then
		return "{}"
	end
	local name = GetGlobalName(value)
	if name then
		return name
	end
	visited = visited or {}
	if visited == true or visited[value] then
		return "{...}"
	end
	visited[value] = true
	local n
	for k, v in pairs(value) do
		if type(k) ~= "number" or k < 1 then
			n = false
			break
		end
		n = Max(n or 0, k)
	end
	if n then
		for i=1,n do
			if value[i] == nil then
				n = false
				break
			end
		end
	end
	if n then
		assert(n > 0)
		local values = {"{ "}
		for i=1,n-1 do
			values[#values + 1] = ValueToStr(value[i], indent, visited)
			values[#values + 1] = ", "
		end
		values[#values + 1] = ValueToStr(value[n], indent, visited)
		values[#values + 1] = " }"
		return table.concat(values)
	end
	indent = indent or ""
	local indent2 = indent .. "\t"
	local lines = {}
	for k, v in pairs(value) do
		if type(k) == "string" and IsIdentifierName(k) then
			lines[#lines + 1] = string.format("%s%s = %s,", indent2, k, ValueToStr(v, indent2, visited))
		else
			lines[#lines + 1] = string.format("%s[%s] = %s,", indent2, ValueToStr(k, indent2, visited), ValueToStr(v, indent2, visited))
		end
	end
	table.sort(lines)
	table.insert(lines, 1, "{")
	lines[#lines + 1] = indent .. "}"
	return table.concat(lines, "\n")
end

---
--- Returns a string representation of the object reference for the given object.
---
--- If the object has a valid handle, the function returns a string in the format `"HandleToObject[<handle>]"`.
--- If the object has a valid position, the function returns a string in the format `"MapGet(point<pos>, 0, '<class>')[<index>]"`,
--- where `<pos>` is the string representation of the object's position, `<class>` is the object's class, and `<index>` is the index of the object in the map at that position.
---
--- @param obj table The object to get the reference code for.
--- @return string The string representation of the object reference.
function GetObjRefCode(obj)
	if obj and obj.handle then
		return string.format("HandleToObject[%d]", obj.handle)
	elseif obj and IsValidPos(obj) then
		local pos, class = obj:GetPos(), obj.class
		local objs = MapGet(pos, 0, class)
		local idx = table.find(objs, obj)
		if idx then
			return string.format("MapGet(point%s, 0, '%s')[%d]", tostring(pos), class, idx)
		end
	end
end

----

---
--- Returns the index of the class in the `classes` table that contains the item with the given `prop_id` and `slot` value.
---
--- This function uses a binary search algorithm to efficiently find the index of the class that contains the item with the given `prop_id` and `slot` value.
---
--- @param classes table The table of classes to search.
--- @param slot number The slot value of the item to find.
--- @param prop_id string The property ID of the item to find.
--- @return number The index of the class that contains the item with the given `prop_id` and `slot` value.
function GetRandomItemByWeight(classes, slot, prop_id)
	local lo, hi = 1, #classes
	while lo <= hi do
		local mid = (lo + hi) / 2
		local check = prop_id and classes[mid][prop_id] or classes[mid]
		if slot < check then
			hi = mid - 1
		elseif slot > check then
			lo = mid + 1
		else
			return mid
		end
	end
	
	return lo
end

----

local default_repetitions = { 1, -1, -2, -3, -4, -6, -8, -10 }
---
--- Generates a string representation of the chances for different repetitions of a list of items, where each item has a corresponding weight.
---
--- @param items table The list of items to generate chances for.
--- @param weights table|string|function The weights for each item, or a function to calculate the weight for each item.
--- @param total_weight number The total weight of all items. If not provided, it will be calculated.
--- @param additional_text string Additional text to include in the output.
--- @param repetitions table The list of repetition values to calculate chances for. Defaults to `{ 1, -1, -2, -3, -4, -6, -8, -10 }`.
--- @return string The string representation of the chances for the different repetitions.
function ListChances(items, weights, total_weight, additional_text, repetitions)
	if type(weights) == "string" or type(weights) == "function" then
		weights = table.map(items, weights)
	end
	if not total_weight then
		total_weight = 0
		for i in ipairs(items) do
			local weight = weights and weights[i] or 100
			total_weight = total_weight + weight
		end
	end
	if total_weight == 0 then return end
	repetitions = repetitions or default_repetitions
	local tab_width = 40
	local text = pstr(additional_text or "", 4096)
	text:append(additional_text and "\n" or "", "Chances for repetitions in %\n")
	for n, rep in ipairs(repetitions) do
		if rep < 0 then
			text:append("'-X' is the chance of something not happening X times\n")
			break
		end
	end
	for n, rep in ipairs(repetitions) do
		text:appendf("<tab %d right>%d", n * tab_width, rep)
	end
	text:appendf("<tab %d>  Event\n", #repetitions * tab_width)
	for i, item in ipairs(items) do
		local chance = (weights and weights[i] or 100) * 1.0 / total_weight
		for n, rep in ipairs(repetitions) do
			local percent = rep > 0 and (chance ^ rep) or (1 - chance) ^ -rep
			text:appendf("<tab %d right>%d%%", n * tab_width, 100.0 * percent + 0.5)
		end
		if type(item) == "table" then
			if item.EditorView then
				item = _InternalTranslate(item.EditorView, item, false)
			else
				item = item.id or item.item or item.value
			end
		end
		if IsT(item) then item = _InternalTranslate(item, nil, false) end
		text:appendf("<tab %d>  %s\n", #repetitions * tab_width, tostring(item))
	end
	return tostring(text)
end

-----

if FirstLoad then
	GameSpeedLock_OrigSpeed = false
	GameSpeedLock_ForcedSpeed = false
end

---
--- Toggles the game speed lock, which forces the game to run at a specific speed regardless of user interaction.
---
--- If the game speed is currently locked, this function will unlock it and restore the original game speed.
--- If the game speed is not locked, this function will lock it to the specified speed or the current speed if no speed is provided.
---
--- When the game speed is locked, the following changes are made:
--- - All pause reasons are resumed, and the game is resumed.
--- - The time factor is set to the locked speed.
--- - The `LockGameSpeedNoUserInteraction` table is modified to override certain functions and return the locked speed.
--- - The `config.LockGameSpeedNoUserInteraction` table is modified to set certain flags.
---
--- @param speed number|nil The speed to lock the game to, or nil to use the current speed.
function ToggleLockGameSpeedNoUserInteraction(speed)
	assert(not netInGame)
	table.restore(_G, "LockGameSpeedNoUserInteraction", true)
	table.restore(config, "LockGameSpeedNoUserInteraction", true)
	if GameSpeedLock_ForcedSpeed then
		SetTimeFactor(GameSpeedLock_OrigSpeed)
		GameSpeedLock_ForcedSpeed = false
		GameSpeedLock_OrigSpeed = false
		print("Game Speed Unlocked")
	else
		speed = speed or GetTimeFactor()
		GameSpeedLock_ForcedSpeed = speed
		GameSpeedLock_OrigSpeed = GameSpeedLock_OrigSpeed or GetTimeFactor()
		for reason in pairs(PauseReasons) do
			Resume(reason)
		end
		ResumeGame(GetGamePause())
		__SetTimeFactor(speed)
		table.change(_G, "LockGameSpeedNoUserInteraction", {
			Pause = empty_func,
			PauseGame = empty_func,
			__SetTimeFactor = empty_func,
			GetTimeFactor = function() return GameSpeedLock_ForcedSpeed end,
		})
		table.change(config, "LockGameSpeedNoUserInteraction", {
			NoUserInteraction = true,
			LuaErrorMessage = false,
			AssertMessage = false,
		})
		print("Game Speed Locked to Factor", speed)
	end
	UpdateGameSpeed()
end

function UpdateGameSpeed()
end

----

---
--- Checks if cheats are enabled for the current platform.
---
--- @return boolean True if cheats are enabled, false otherwise.
function AreCheatsEnabled()
	return Platform.cheats or AreModdingToolsActive()
end

----

if FirstLoad then
	DbgLastIdx = 0
end

---
--- Returns the next color from the global color list, cycling through the list.
---
--- @param idx number The index of the color to return. If not provided, the next color in the list is returned.
--- @return color The next color from the global color list.
function DbgNextColor(idx)
	idx = idx or (DbgLastIdx + 1)
	DbgLastIdx = idx
	local colors = const.ColorList
	return colors and #colors > 0 and colors[1 + (idx - 1) % #colors] or RandColor(idx)
end

function OnMsg.DbgClear()
	DbgLastIdx = 0
end

----

if FirstLoad then
	SpecialLuaErrorHandlingReasons = {}
end

---
--- Sets the special Lua error handling behavior.
---
--- @param reason string|boolean The reason for the special Lua error handling, or false to disable.
--- @param enable boolean Whether to enable or disable the special Lua error handling for the given reason.
function SetSpecialLuaErrorHandling(reason, enable)
	SpecialLuaErrorHandlingReasons[reason or false] = enable and true or nil
	config.SpecialLuaErrorHandling = not not next(SpecialLuaErrorHandlingReasons)
end

SetSpecialLuaErrorHandling("Pause", config.PauseGameOnLuaError)

if FirstLoad then
	LastErrorGameTime = false -- not a map var in order to persist it when loading an earlier save
end

---
--- Handles Lua errors that occur during game execution.
---
--- When a Lua error occurs, this function is called to handle the error. It records the game time when the error occurred, and optionally pauses the game depending on the value of the `config.PauseGameOnLuaError` setting.
---
--- @param err string The error message.
---
function DbgOnLuaError(err)
	LastErrorGameTime = GameTime()
	if config.PauseGameOnLuaError and SetGameSpeed and Pause then
		if config.PauseGameOnLuaError == "stop" then
			SetGameSpeed("pause")
		else
			Pause("UI")
		end
		print("[PauseGameOnLuaError] GameTime:", GameTime(), "RealPause:", GetGamePause(), "TimeFactor:", GetTimeFactor())
	end
end

OnMsg.OnLuaError = DbgOnLuaError

----

ReportZeroAnimDuration = empty_func

if Platform.asserts then

---
--- Reports a zero animation duration error.
---
--- This function is called when an animation has a duration of 0 seconds. It checks if the animation exists on the object, and logs an error message accordingly.
---
--- @param obj table The object that the animation is attached to.
--- @param anim string|number The name or index of the animation.
--- @param dt number The duration of the animation, or nil to use the value returned by `obj:GetAnimDuration(anim)`.
---
function ReportZeroAnimDuration(obj, anim, dt)
	dt = dt or obj:GetAnimDuration(anim)
	if dt ~= 0 then return end
	if type(anim) == "number" then anim = GetStateName(anim) end
	if not obj:HasState(anim) then
		GameTestsErrorf("once", "Missing anim %s.%s", obj:GetEntity(), anim)
	else
		GameTestsErrorf("once", "Zero length anim %s.%s", obj:GetEntity(), anim)
	end
end

end

----

-- merges axis-aligned bounding boxes from the list to create a shorter, less accurate list
-- 'accuracy' is the largest allowed distance from a input bounding box that can be present in the output list
-- 'optimize_boxes' makes a second pass to shrink the resulting boxes as much as possible
---
--- Compacts a list of axis-aligned bounding boxes (AABBs) by merging overlapping boxes to create a shorter, less accurate list.
---
--- @param box_list table A list of AABBs to compact.
--- @param accuracy number The largest allowed distance from an input bounding box that can be present in the output list.
--- @param optimize_boxes boolean If true, the resulting boxes will be shrunk as much as possible.
--- @return table A compacted list of AABBs.
---
function CompactAABBList(box_list, accuracy, optimize_boxes)
	local slot_size = accuracy / 2
	local map_box = box(0, 0, terrain.GetMapSize())
	local grid_size = point(terrain.GetMapSize()) / slot_size + point(1, 1)
	PauseInfiniteLoopDetection("CompactAABBList")
	
	-- rasterize all boxes into a grid
	local grid = NewComputeGrid(grid_size:x(), grid_size:y(), "u", 8)
	for _, bx in ipairs(box_list) do
		bx = IntersectRects(bx, map_box)
		GridDrawBox(grid, bx:Align(slot_size) / slot_size, 1)
	end
	
	-- build an "extended" grid, 1 tile in each direction
	local ext_grid = NewComputeGrid(grid_size:x(), grid_size:y(), "u", 8)
	for y = 0, grid_size:y() do
		for x = 0, grid_size:x() do
			if grid:get(x, y) + grid:get(x - 1, y) + grid:get(x + 1, y) + grid:get(x, y - 1) + grid:get(x, y + 1) > 0 then
				ext_grid:set(x, y, 1)
			end
		end
	end
	
	-- build rectangles in 'ext_grid' in a greedy manner:
	--  * after finding the top of the rectangle, shrink it from left & right, omitting tiles not in 'grid'
	--  * as a last step, try expanding the entire rectangle left & right, if this would cover more tiles from 'grid'
	-- mark the rectangle with 0 in 'grid' to mark them are "covered"
	local ret = {}
	for y = 0, grid_size:y() do
		for x = 0, grid_size:x() do
			-- start building a new rectangle if we encounter a full tile
			if ext_grid:get(x, y) == 1 then
				-- extend to the right
				local x1, x2 = x, x + 1
				while x2 < grid_size:x() and ext_grid:get(x2, y) == 1 do
					x2 = x2 + 1
				end
				
				-- delete tiles not present in 'grid' from the right
				while x2 > x1 and grid:get(x2 - 1, y) == 0 do
					x2 = x2 - 1
				end
				
				-- delete tiles not present in 'grid' from the left
				while x1 < x2 and grid:get(x1, y) == 0 do
					x1 = x1 + 1
				end
				
				if x2 > x1 then
					-- extend downwards
					local bx = box(x1, y + 1, x2, y + 2)
					while bx:maxy() <= grid_size:y() and GridBoxEquals(ext_grid, bx, 1) do
						bx = Offset(bx, 0, 1)
					end
					bx = Offset(bx, 0, -1)
					bx:InplaceExtend(x1, y)
					
					-- try extending once left
					if GridBoxEquals(ext_grid, Extend(bx, x1 - 1, y), 1) then
						bx:InplaceExtend(x1 - 1, y)
					end
					
					-- try extending once right
					if GridBoxEquals(ext_grid, Extend(bx, x2 + 1, y), 1) then
						bx:InplaceExtend(x2 + 1, y)
					end
					
					-- mark as "covered" and add it to the output
					-- NOTE: marking in 'grid' produces 10% less boxes (by allowing box overlap), but has 2x worse performance
					GridDrawBox(ext_grid, bx, 0)
					table.insert(ret, bx * slot_size)
				end
			end
		end
	end
	
	if optimize_boxes then
		-- shrink the output rectangles to the original bounding boxes edges where possible
		-- (using a locality-access structure for good performance)
		local slot_size = slot_size * 2
		local slot_to_boxes = {}
		for _, orig_bx in ipairs(box_list) do
			local bx = IntersectRects(orig_bx, map_box):Align(slot_size) / slot_size
			for x = bx:minx(), bx:maxx() - 1 do
				for y = bx:miny(), bx:maxy() - 1 do
					local key = point_pack(x, y)
					local slot = slot_to_boxes[key] or {}
					table.insert(slot, orig_bx)
					slot_to_boxes[key] = slot
				end
			end
		end
		for idx, orig_bx in ipairs(ret) do
			local final_bx = box()
			local bx = IntersectRects(orig_bx, map_box):Align(slot_size) / slot_size
			for x = bx:minx(), bx:maxx() - 1 do
				for y = bx:miny(), bx:maxy() - 1 do
					for _, input_bx in ipairs(slot_to_boxes[point_pack(x, y)]) do
						final_bx:InplaceExtend(IntersectRects(orig_bx, input_bx))
					end
				end
			end
			ret[idx] = final_bx
		end
	end
	
	ResumeInfiniteLoopDetection("CompactAABBList")
	grid:free()
	ext_grid:free()
	return ret
end
