function OnMsg.NewMap()
	ShowMouseCursor("ingame")
end

StoryBitActivate.EditorExcludeAsNested = true
StoryBitEnableRandom.EditorExcludeAsNested = true

g_CurrentMissionParams = {}
const.HoursPerDay = 24
const.HourDuration = 30000

MapVar("g_ShowcaseUnits", {})

---
--- Places a showcase unit at the specified marker location.
---
--- @param marker_id string The ID of the marker to place the unit at.
--- @param appearance string The appearance to apply to the unit.
--- @param weapon string The weapon to attach to the unit.
--- @param weapon_spot string The spot on the unit to attach the weapon.
--- @param anim string The animation to play on the unit.
--- @return table The created unit object.
---
function PlaceShowcaseUnit(marker_id, appearance, weapon, weapon_spot, anim)
	RemoveShowcaseUnit(marker_id)
	local marker = MapGetFirstMarker("GridMarker", function(x) return x.ID == marker_id end)
	if not marker then return end
	local unit = AppearanceObject:new()
	g_ShowcaseUnits[marker_id] = g_ShowcaseUnits[marker_id] or {}
	table.insert(g_ShowcaseUnits[marker_id], unit)
	unit:SetPos(marker:GetPos())
	unit:SetAngle(marker:GetAngle())
	unit:SetGameFlags(const.gofRealTimeAnim)
	unit:ApplyAppearance(appearance)
	if weapon then
		local weapon_item = PlaceInventoryItem(weapon)
		if weapon_item then
			local visual_weapon = weapon_item:CreateVisualObj()
			if visual_weapon then
				weapon_item:UpdateVisualObj(visual_weapon)
				unit:Attach(visual_weapon, unit:GetSpotBeginIndex(weapon_spot or "Weaponr"))
			end
		end
	end
	unit:SetHierarchyGameFlags(const.gofUnitLighting)	
	if anim then
		unit:Setanim(anim)
	end
	WaitNextFrame()
	return unit
end

---
--- Removes a showcase unit from the specified marker location.
---
--- @param marker_id string The ID of the marker to remove the unit from.
---
function RemoveShowcaseUnit(marker_id)
	if g_ShowcaseUnits then
		if not marker_id then
			for marker_id in pairs(g_ShowcaseUnits) do
				RemoveShowcaseUnit(marker_id)
			end
		else
			for _, unit in ipairs(g_ShowcaseUnits[marker_id] or empty_table) do
				DoneObject(unit)
			end
			g_ShowcaseUnits[marker_id] = nil
		end
	end
end

---
--- Closes the map loading screen and sets up the initial camera.
---
--- @param map string The name of the map being loaded.
---
function CloseMapLoadingScreen(map)
	if map ~= "" then
		if not Platform.developer then
			SetupInitialCamera()
		end
		WaitResourceManagerRequests(2000)
	end
	LoadingScreenClose("idLoadingScreen", "ChangeMap")
end

DefineClass.ConstructionCost = {
	__parents = { "PropertyObject" },
}

DefineClass.ForestSoundSource = {
	__parents = {"SoundSource"},
	color_modifier = RGB(30, 100, 30),
}

DefineClass.WaterSoundSource = {
	__parents = {"SoundSource"},
	color_modifier = RGB(0, 30, 100),
}

function OnMsg.ClassesGenerate(classdefs)
	XButton.MouseCursor = "UI/Cursors/Hand.tga"
	XDragAndDropControl.MouseCursor = "UI/Cursors/Hand.tga"
	BaseLoadingScreen.MouseCursor = "UI/Cursors/Wait.tga"
end

function OnMsg.Start()
	if Platform.developer then
		MountFolder(GetPCSaveFolder(), "svnAssets/Source/TestSaves", "seethrough,readonly")
	elseif not config.RunUnpacked then
		MountFolder(GetPCSaveFolder(), "TestSaves", "seethrough,readonly")
		local err, files = AsyncListFiles("saves:/")
	end
end

---
--- Fixes the ownership of the first sector in the savegame data.
---
--- @param data table The savegame session data.
---
function SavegameSessionDataFixups.FirstSectorOwnership(data)
	local i1 = data.gvars.gv_Sectors.I1
	if i1 and i1.Side == "player1" then
		i1.ForceConflict = false
	end
end

local function make_debris_sane(debris)
	debris.pos = debris.pos and MakeDebrisPosSane(debris.pos) or nil
	debris.vpos = debris.vpos and MakeDebrisPosSane(debris.vpos) or nil
end

---
--- Fixes the sanity of debris objects in the savegame data.
---
--- This function iterates through the dynamic data and spawn data in the sector data,
--- and ensures that the position and velocity position of any debris objects are sane.
---
--- @param sector_data table The savegame sector data.
--- @param lua_revision number The current Lua revision.
--- @param handle_data table The handle data for the savegame.
---
function SavegameSectorDataFixups.DebrisMakeSane(sector_data, lua_revision, handle_data)
	for idx, data in ipairs(sector_data.dynamic_data) do
		local handle = data.handle
		local obj = HandleToObject[handle]
		if IsValid(obj) and IsKindOf(obj, "Debris") then
			make_debris_sane(obj)
		end
	end
	local spawn_data = sector_data.spawn
	local length = #(spawn_data or "")
	for i = 1, length, 2 do
		local class = g_Classes[spawn_data[i]]
		if IsKindOf(class, "Debris") then
			local handle = spawn_data[i + 1]
			make_debris_sane(handle_data[handle])
		end
	end
end

config.DefaultAppearanceBody = "Male"

---
--- Provides a context function for satellite sector names.
---
--- The returned function takes an object, property metadata, and parent object,
--- and returns a string representing the sector name for the given object.
---
--- @param obj table The object to get the sector name for.
--- @param prop_meta table The property metadata for the object.
--- @param parent table The parent object of the object.
--- @return string The sector name for the object.
---
function SatelliteSectorLocContext()
	return function(obj, prop_meta, parent)
		return "Sector name for " .. obj.Id
	end
end

---
--- Lays out the children of the XWindow.
---
--- This function iterates through all the child windows of the XWindow and calls the UpdateLayout() method on each one. It then returns false to indicate that the layout has been updated.
---
--- @param self XWindow The XWindow instance whose children are being laid out.
--- @return boolean Always returns false.
---
function XWindow:LayoutChildren()
	for _, win in ipairs(self) do
		win:UpdateLayout()
	end
	return false
end

function OnMsg.ClassesPostprocess()
	local prop = RoofTypes:GetPropertyMetadata("display_name")
	prop.translate = nil -- roof names are untranslated - prevent validation errors
end

---
--- Prompts the user to confirm quitting the game, and if confirmed, quits the game.
---
--- @param parent table The parent object for the confirmation dialog.
---
function QuitGame(parent)
	parent = parent or terminal.desktop
	CreateRealTimeThread(function(parent)
		if WaitQuestion(parent, T(1000859, "Quit game?"), T(1000860, "Are you sure you want to exit the game?"), T(147627288183, "Yes"), T(1139, "No")) == "ok" then
			Msg("QuitGame")
			if Platform.demo then
				WaitHotDiamondsDemoUpsellDlg()
			end
			quit()
		end
	end, parent)
end

-- generate __eval functions as Lua code for QuestIsVariableBool
function OnMsg.OnPreSavePreset(preset)
	if not IsKindOf(preset, "SetpiecePrg") then
		preset:ForEachSubObject("QuestIsVariableBool", function(obj)
			obj:OnPreSave()
		end)
	end
end

AppendClass.EntitySpecProperties = {	
	properties = {
		{ id = "SunShadowOptional", help = "Sun shadow can be disabled on low settings", editor = "bool", category = "Misc", default = false, entitydata = true, }
	}
}

g_SunShadowCastersOptionalClasses = {}

function OnMsg.ClassesBuilt()
	for name, cl in pairs(g_Classes) do
		if IsKindOf(cl, "CObject") and table.get(EntityData, cl:GetEntity(), "entity", "SunShadowOptional") then
			g_SunShadowCastersOptionalClasses[#g_SunShadowCastersOptionalClasses + 1] = name
		end
	end
end

---
--- Sets the sun shadow casters in the map.
---
--- @param set boolean Whether to set or clear the sun shadow flag on the objects.
---
function SetSunShadowCasters(set)
	local t = GetPreciseTicks()
	local c = 0
	local f = set and CObject.SetEnumFlags or CObject.ClearEnumFlags
	local efSunShadow = const.efSunShadow
	MapForEach("map", "CObject", function(o)
		if o:IsKindOf("Slab") then return end
		local v = EnumVolumes(o)
		if v and v[1] and not v[1].dont_use_interior_lighting then
			f(o, efSunShadow)
			c = c + 1
		end
	end)
	c = c + MapForEach("map", g_SunShadowCastersOptionalClasses, function(o)
		local z = o:GetAxis():z()
		if z > 3000 or z < -3000 then
			f(o, efSunShadow)
		end
	end)
	if Platform.developer and Platform.console then
		printf("SetSunShadowCasters: removed %d objects in %d ms", c, GetPreciseTicks() - t)
	end
end

function OnMsg.NewMapLoaded()
	if Platform.xbox_one or Platform.ps4 or (not Platform.developer and not IsEditorActive() and EngineOptions.Shadows == "Low") then
		SetSunShadowCasters(false)
	end
end

PlayStationDefaultBackgroundExecutionHandler = empty_func

---
--- Disables the upscaling option in the engine options if the requested upscaling type is not available.
---
--- @param engine_options table The engine options table to update.
--- @param last_applied_fixup_revision number The revision of the last applied fixup.
---
function EngineOptionFixups.DisableUpscalingIfNotAvailable(engine_options, last_applied_fixup_revision)
	local upscaling = engine_options.Upscaling
	if not upscaling then return end
	local idx = table.find(OptionsData.Options.Antialiasing, "value", upscaling)
	local hr_upscale = OptionsData.Options.Antialiasing[idx] and OptionsData.Options.Antialiasing[idx].hr and OptionsData.Options.Antialiasing[idx].hr.ResolutionUpscale
	if hr_upscale then
		if not hr.TemporalIsTypeSupported(hr_upscale) then
			engine_options.Upscaling = "Off"
		end
	end
end

---
--- Returns a string representation of the logical AND of the conditions in this CheckAND object.
---
--- @param self CheckAND The CheckAND object to get the editor view for.
--- @return string The string representation of the logical AND of the conditions.
---
function CheckAND:GetEditorView()
	local conditions =  self.Conditions
	if not conditions then return Untranslated(" AND ") end
	local txt = {}
	for _, cond in ipairs(conditions) do
		txt[#txt+1] = Untranslated("( ".._InternalTranslate(cond:GetEditorView(), cond).." )")
	end
	return table.concat(txt, Untranslated(" AND "))
end

---
--- Returns the UI text for the logical AND of the conditions in this CheckAND object.
---
--- @param self CheckAND The CheckAND object to get the UI text for.
--- @param context table The context to use when generating the UI text.
--- @param template table The template to use when generating the UI text.
--- @param game table The game to use when generating the UI text.
--- @return string The UI text for the logical AND of the conditions.
---
function CheckAND:GetUIText(context, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetUIText") and cond:GetUIText(context, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return  table.concat(texts,"\n")
end

---
--- Returns a string representation of the logical OR of the conditions in this CheckOR object.
---
--- @param self CheckOR The CheckOR object to get the top rollover text for.
--- @param negative boolean Whether to get the negative rollover text.
--- @param template table The template to use when generating the rollover text.
--- @param game table The game to use when generating the rollover text.
--- @return string The string representation of the logical OR of the conditions.
---
function CheckANDGetPhraseTopRolloverText(negative, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetPhraseTopRolloverText") and cond:GetPhraseTopRolloverText(negative, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return  table.concat(texts,"\n")
end

---
--- Returns the phrase effect (FX) for the logical AND of the conditions in this CheckAND object.
---
--- @param self CheckAND The CheckAND object to get the phrase effect for.
--- @return string|nil The phrase effect, or nil if no condition has a phrase effect.
---
function CheckAND:GetPhraseFX()
	for _, cond in ipairs(self.Conditions) do
		local fx = cond:HasMember("GetPhraseFX") and cond:GetPhraseFX()
		if fx then
			return fx
		end
	end
end

---
--- Returns a string representation of the logical OR of the conditions in this CheckOR object.
---
--- @param self CheckOR The CheckOR object to get the editor view for.
--- @return string The string representation of the logical OR of the conditions.
---
function CheckOR:GetEditorView()
	local conditions =  self.Conditions
	if not conditions then return Untranslated(" OR ") end
	local txt = {}
	for _, cond in ipairs(conditions) do
		txt[#txt+1] = Untranslated("( ".._InternalTranslate(cond:GetEditorView(), cond).." )")
	end
	return table.concat(txt, Untranslated(" OR "))
end

---
--- Returns a string representation of the logical OR of the conditions in this CheckOR object.
---
--- @param self CheckOR The CheckOR object to get the UI text for.
--- @param context table The context to use when generating the UI text.
--- @param template table The template to use when generating the UI text.
--- @param game table The game to use when generating the UI text.
--- @return string The string representation of the logical OR of the conditions.
---
function CheckOR:GetUIText(context, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetUIText") and cond:GetUIText(context, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	
	return  table.concat(texts,"\n")
end

---
--- Returns a string representation of the logical OR of the top rollover text of the conditions in this CheckOR object.
---
--- @param self CheckOR The CheckOR object to get the top rollover text for.
--- @param negative boolean Whether to get the negative top rollover text.
--- @param template table The template to use when generating the top rollover text.
--- @param game table The game to use when generating the top rollover text.
--- @return string The string representation of the logical OR of the top rollover text of the conditions.
---
function CheckOR:GetPhraseTopRolloverText(negative, template, game)
	local texts = {}
	for _, cond in ipairs(self.Conditions) do
		local text = cond:HasMember("GetPhraseTopRolloverText") and cond:GetPhraseTopRolloverText(negative, template, game)
		if text and text~="" then
		 	texts[#texts + 1] = text	
		end
	end
	local count = #texts
	if count <1 then return end
	if count == 1 then return texts[1] end
	return texts[AsyncRand(count) +1]
end

---
--- Returns the phrase FX for the first condition in this CheckOR object that has a GetPhraseFX method.
---
--- @param self CheckOR The CheckOR object to get the phrase FX for.
--- @return string|nil The phrase FX, or nil if no conditions have a GetPhraseFX method.
---
function CheckOR:GetPhraseFX()
	for _, cond in ipairs(self.Conditions) do
		local fx = cond:HasMember("GetPhraseFX") and cond:GetPhraseFX()
		if fx then
			return fx
		end
	end
end

DefineClass.AND = {__parents = {"CheckAND"}}
DefineClass.OR = {__parents = {"CheckOR"}}

CascadesDropOnHighestFloor = {
	Low = true,
	["Medium (PS4,XboxOne)"] = true,
	["High (PS4Pro)"] = true,
	Medium = true,
}

function OnMsg.TacCamFloorChanged()
	local cascades = hr.ShadowCSMCascades
	if CascadesDropOnHighestFloor[EngineOptions.Shadows or "none"] then
		if cameraTac.GetFloor() > 0 and cascades > 2 then
			cascades = cascades - 1
		end
	end
	hr.ShadowCSMActiveCascades = cascades
end

-- as of Nov 2023, the game runs almost perfectly under Apple's Game Porting Toolkit,
-- with the exception of the heat haze effect, for which we keep getting bug reports
-- e.g. http://mantis.haemimontgames.com/view.php?id=239277
-- detect these machines by CPU name and disable heat haze effect

if FirstLoad then
	engineSetPostProcPredicate = SetPostProcPredicate
	function IsAppleGamePortingToolkit()
		local hw_info = GetHardwareInfo("", 0)
		return hw_info and hw_info.cpuName and hw_info.cpuName:find("VirtualApple")
	end
	function appleSetPostProcPredicate(predicate, value)
		if predicate == "heat_haze" then
			value = false
		end
		return engineSetPostProcPredicate(predicate, value)
	end
	SetPostProcPredicate = function(predicate, value)
		if IsAppleGamePortingToolkit() then
			SetPostProcPredicate = appleSetPostProcPredicate
		else
			SetPostProcPredicate = engineSetPostProcPredicate
		end
		return SetPostProcPredicate(predicate, value)
	end
end
