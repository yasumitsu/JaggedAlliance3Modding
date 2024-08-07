------------------------------------------------------------
------------------- AMBIENT LIFE ---------------------------
------------------------------------------------------------

-- Ambient Life units are spawned from AmbientZoneMarker. It has an area where they operate,
-- a few SpawnDefs defining a range(min-max count) for each unit appearance to spawn
-- and some other parameters. Once spawned their routine is set to "Ambient" around their zone.

-- The ambient routine of an unit(during Idle command) looks for a visitible in its zone and 
-- goes to execute some actions there. This can be sitting on a chair, leaning a wall, paiting a wall, 
-- digging with a shovel, etc. Visitables on a map are declared as AmbientLifeMarker obecst.
-- It specifies position and orientation for the unit to take when there and also what animation to
-- play while visiting, e.g. sitting, painting, leaning. It can also specify a tool or weapon
-- to attach to the unit while there.

-- Ambient Life is spawned OnMsg.AmbientLifeSpawn and despawned OnMsg.AmbientLifeDespawn :)
-- When spawning it goes through all AmbienZoneMarker objects and calls their :Spawn() method to
-- populate the map with AL units. It also goes through all AmbineLifeMarker objects with perpetual 
-- units and steals them.

-- Some of the important properties of the AmbientLifeMarker are the Teleport, AllowAL, ChanceSpawn
-- along with the Conditions and GameStatesFilter. The later two are defining whether the marker
-- is currently available for visit or not. ChanceSpawn is rolled out and when succeeds the spawned
-- unit becomes perpetual unit for this marker(no other unit can visit it anymore). For a unit to 
-- become perpetual it also requires a Groups property to be defined so the marker to know from where
-- "to steal" its unit from(either AmbientZoneMarker or UnitMarker). Perpetual units usually go along
-- with the Teleport property which instructs the unit to teleport straight at the marker instead of 
-- walking to there. AllowAL=false means units from AmbientZoneMarker can't use this spot(only the
-- ones spawned from UnitMarker can).

-- All the visitables are stored in g_Visitable. While visiting a marker the unit reserves the spot
-- so no other units can visit it(.reserved member in g_Visitables entry). During combat covers are also
-- considered visitable spots but their reservation system is implemented in g_CoversReserved.

------------------------------------------------------------
------------------- AMBIENT LIFE REPULSORS -----------------
------------------------------------------------------------

-- There is AmbientLifeRepulsor marker which tries to not let AL units inside its area. Units are not
-- spawned there and visitable markers are not picked inside the area. The path finding
-- also should avoid such zones while walking. Hint: use Ctrl-9 and such repulsor zone will be painted green.


----------------------------------------------------------------
--------------- DESIGNING NEW AmbientLifeMarker ----------------
----------------------------------------------------------------

-- ClassDef editor is usually used to define new AL marker behavior. The simple ones are 
-- copy-pasted/duplicated from exisiting markers, e.g. AL_PlayAnimVariation. Only new properties have to
-- be changed for the new marker to work - its VisitIdle animation which says what the unit should play
-- when the marker is reached. In addition there are VisitEnter/VisitExit properties for animations to be
-- played once when entering/exiting the marker. VisitIdle can be played as long as required(indefinitely 
-- for perpetual units). All this logic is implemented in AmbientLifeMarker:Visit() method and should work
-- for most markers taking care of playing animations, spawning/despawning tools and weapons, going to
-- destination spot, etc. If some more sophistaced logic is required a new :Visit() method should be coded
-- via the ClassDef editor. The most complex marker as of now should be AL_Football which spawns a secondary
-- unit(the partner), plays some logic about passing the ball and *persisting* him in the savegame.


----------------------------------------------------------------
----------------------- EFFECTS --------------------------------
----------------------------------------------------------------

-- There are some effects which can be used from the Quests and Campaigns which operate on the AL:
--
-- * ResetAmbientLife forces all Visit commands of the AL units present on the map to be restarted and
--   a new spot to be picked up
-- * ForceResetAmbientLife resets the whole AL on the map(as if using Alt-Shift-A(to toggle it twice)
-- * ScatterAmbientLife forces scripted conflict
-- * UnitsDespawnAmbientLife does as it sounds
-- * UnitsAddToAmbientLife adds a group of units to AmbientZoneMarker as if they were spawned from it

---
--- Generates a random number between 1 and `max` using the "AmbientLife" seed.
---
--- @param self table The current object instance.
--- @param max number The maximum value for the random number.
--- @return number A random number between 1 and `max`.
---
function AmbientLife_Random(self, max)
	return InteractionRand(max, "AmbientLife")
end

MapVar("g_Visitables", {})
MapVar("g_VisitRepulsors", {})
MapVar("g_RebuildRepulsors", false)

DefineClass.AmbientLifeRepulsor = {
	__parents = {"GridMarker"},
	properties = {
		{ category = "Marker", id = "Reachable",  no_edit = true, default = false, },
	},
	apply_pass = false,
	recalc_area_on_pass_rebuild = false,
}

---
--- Initializes an AmbientLifeRepulsor object by adding it to the global `g_VisitRepulsors` table.
---
--- @param self table The current AmbientLifeRepulsor object instance.
---
function AmbientLifeRepulsor:Init()
	table.insert(g_VisitRepulsors, self)
end

---
--- Removes the AmbientLifeRepulsor from the global `g_VisitRepulsors` table and marks the repulsors for a rebuild if the repulsor was applying a pass.
---
--- @param self table The current AmbientLifeRepulsor object instance.
---
function AmbientLifeRepulsor:Done()
	table.remove_entry(g_VisitRepulsors, self)
	if self.apply_pass then
		g_RebuildRepulsors = true
	end
end

---
--- Returns the editor type text for an AmbientLifeRepulsor object.
---
--- @return string The editor type text for the AmbientLifeRepulsor object.
---
function AmbientLifeRepulsor:GetEditorTypeText()
	return Untranslated("[AL Repulsor]")
end

---
--- Checks if the given position or object is within an ambient life repulsion zone.
---
--- @param pos_or_obj table|number The position to check, either as a table with x and y fields, or as a packed position number.
--- @param is_packed_pos boolean Indicates whether the position is provided as a packed position number.
--- @return boolean True if the position is within an ambient life repulsion zone, false otherwise.
---
function IsInAmbientLifeRepulsionZone(pos_or_obj, is_packed_pos)
	for _, repulsor in ipairs(g_VisitRepulsors) do
		if repulsor.apply_pass and repulsor:IsMarkerEnabled() then
			local area = repulsor:GetAreaBox()
			if is_packed_pos then
				if area:Point2DInside(point_unpack(pos_or_obj)) then
					return true
				end
			elseif area:Point2DInside(pos_or_obj) then
				return true
			end
		end
	end
end

---
--- Recalculates the area positions for the AmbientLifeRepulsor object and updates the global `g_RebuildRepulsors` flag if the area positions have changed.
---
--- This function is called to update the area positions of the AmbientLifeRepulsor object. It first stores the previous area positions, then calls the `GridMarker.RecalcAreaPositions` function to recalculate the area positions. If the new area positions are different from the previous ones, it sets the `g_RebuildRepulsors` flag to true if the `apply_pass` flag is set, and schedules a delayed call to `UpdateRepulsorsPass` to update the repulsors.
---
--- @param self table The current AmbientLifeRepulsor object instance.
---
function AmbientLifeRepulsor:RecalcAreaPositions()
	local prev_area_positions = self:GetAreaPositions()
	GridMarker.RecalcAreaPositions(self)
	if not table.iequal(self:GetAreaPositions(), prev_area_positions) then
		if self.apply_pass then
			g_RebuildRepulsors = true
		end
		DelayedCall(0, UpdateRepulsorsPass)
	end
end

---
--- Filters a list of packed positions to remove those that are within an ambient life repulsion zone.
---
--- @param positions table A table of packed positions to filter.
--- @return table A new table containing only the packed positions that are not within an ambient life repulsion zone.
---
function FilterPackedPositionsRepulsionZone(positions)
	return table.ifilter(positions, function(_, packed_pos)
		return not IsInAmbientLifeRepulsionZone(packed_pos, true)
	end)
end

---
--- Updates the ambient life repulsor markers and rebuilds the repulsor pass if necessary.
---
--- This function is called periodically to update the state of the ambient life repulsor markers. It first checks if the area positions of each marker have changed, and if so, updates the `apply_pass` flag and sets the `g_RebuildRepulsors` flag to true. If the `g_RebuildRepulsors` flag is set, it resets the flag, updates the pass type, and calls `GridMarker.ResetRepulseAreaPositions` on all grid markers to recalculate the repulsor areas.
---
--- @
function UpdateRepulsorsPass()
	for _, marker in ipairs(g_VisitRepulsors) do
		local apply_pass = marker:GetAreaPositions() and marker:IsMarkerEnabled() or false
		if marker.apply_pass ~= apply_pass then
			marker.apply_pass = apply_pass
			g_RebuildRepulsors = true
		end
	end
	if g_RebuildRepulsors then
		g_RebuildRepulsors = false
		NetUpdateHash("UpdateRepulsorsPass:UpdatePassType")
		UpdatePassType()
		MapForEachMarker("GridMarker", nil, GridMarker.ResetRepulseAreaPositions)
	end
end

MapGameTimeRepeat("AmbientLifeRepulsor", 1000, UpdateRepulsorsPass)

-- a Visitable is a table of the form { id, ... }
-- id is one of the Visit prgs; the rest of the table is parameters needed for it to be completed
-- the parameters must be serializable via the StoreBehaviorParamTbl/RestoreBehaviorParamTbl functions, if necessary - extend them
-- in particular, any objects need to be serialized as handles

DefineClass.AmbientLifeMarker = {
	__parents = {"EditorMarker", "AppearanceObject", "GameDynamicDataObject", "EditorTextObject", 
		"EditorSelectedObject", "EditorCallbackObject"},
	
	properties = {
		{category = "Ambient Life", id = "Teleport", name = "Teleport", editor = "bool", default = true,
			help = "If true the unit teleports to the spot, otherwise it walks to there",
		},
		{category = "Ambient Life", id = "AllowAL", name = "Allow AL", editor = "bool", default = true,
			help = "If false normal AL units(from Ambient Zones) can't use this spot. However if the marker manages to steal perpetual unit this flag is ignored!",
		},
		{category = "Ambient Life", id = "VisitEnter", name = "Entering Visit", editor = "combo",
			default = "", items = function(obj) return obj:GetStatesTextTable() end,
		},
		{category = "Ambient Life", id = "VisitIdle", name = "During Visit", editor = "dropdownlist",
			default = "idle", items = function(obj) return obj:GetStatesTextTable() end,
		},
		{category = "Ambient Life", id = "VisitVariation", name = "During Visit Variation",
			editor = "bool", default = false,
		},
		{category = "Ambient Life", id = "VisitExit", name = "Exiting Visit", editor = "combo",
			default = "", items = function(obj) return obj:GetStatesTextTable() end,
		},
		{category = "Ambient Life", id = "VisitMinDuration", name = "Visit Min Duration", editor = "number",
			default = false, scale = "sec",
			help = "Spends at least that much at the marker by looping the VisitIdle animation. Can be greater if animations are longer.",
		},
		{category = "Ambient Life", id = "VisitAlternateChance", name = "Visit Alternate Chance",
			editor = "number", default = 0, min = 0, max = 100, slider = true,
		},
		{category = "Ambient Life", id = "VisitAlternate", name = "During Visit Alternate",
			editor = "dropdownlist", default = "idle", items = function(obj) return obj:GetStatesTextTable() end,
			no_edit = function(self) return self.VisitAlternateChance == 0 end,
		},
		{category = "Ambient Life", id = "VisitAlternateVariation", 
			name = "During Visit Alternate Variation", editor = "bool", default = false,
			no_edit = function(self) return self.VisitAlternateChance == 0 end,
		},
		{category = "Ambient Life", id = "EmotionChance", name = "Chance for Emotion",
			editor = "number", default = 0, min = 0, max = 100, slider = true,
			no_edit = function(self) return self.VisitAlternateChance == 0 end,
		},
		{category = "Ambient Life", id = "EmotionAnimation", name = "Emotion",
			editor = "combo", default = "civ_Ambient_Angry", items = function(obj)
				return {"civ_Ambient_Angry", "civ_Ambient_Cheering", "civ_Ambient_SadCrying"}
			end,
			no_edit = function(self) return self.EmotionChance == 0 end,
		},
		{category = "Ambient Life", id = "EmotionVariation", default = false,
			name = "During Visit Alternate Variation", editor = "bool",
			no_edit = function(self) return self.EmotionChance == 0 end,
		},
		{category = "Ambient Life", id = "Conditions", name = "Conditions", editor = "nested_list",
			base_class = "Condition", default = false, help = "Conditions to check periodically" },
		{category = "Ambient Life", id = "GameStatesFilter", name = "States Required for Activation",
			editor = "set", three_state = true,
			default = set_neg("Conflict", "DustStorm", "FireStorm", "RainHeavy"),
			items = function() return GetGameStateFilter() end,
			help = "Map states requirements for the AL marker to be active.",
		},
		{category = "Ambient Life", id = "ToolEntity", name = "Tool Entity", editor = "dropdownlist",
			items = function() return GetAllEntitiesComboItems() end, default = "",
			help = "Tool to be attached during the visit",
		},
		{category = "Ambient Life", id = "ToolAutoAttachMode", name = "Tool Auto Attach Mode", editor = "dropdownlist",
			items = function(obj) return GetEntityAutoAttachModes(nil, obj.ToolEntity) or {} end, default = false,
		},
		{category = "Ambient Life", id = "ToolSpot", name = "Tool Spot", editor = "combo",
			items = {"Weaponr", "Weaponl", "Wristr", "Wristl", "Origin"}, default = "Weaponr",
			help = "Where the tool should be attached to",
		},
		{category = "Ambient Life", id = "ToolAttachOffset", name = "Tool Attach Offset", editor = "point",
			default = false, 
			help = "An offset from the specified spot to attach the tool to.", 
		},
		{ category = "Ambient Life", id = "ToolColors", name = "Tool Colors", editor = "nested_obj",
			base_class = "ColorizationPropSet",
			inclusive = true,
			default = false,
		},
		{category = "Ambient Life", id = "Weapon", name = "Weapon", editor = "preset_id", default = "",
			preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj)
				return preset.group and preset.group:starts_with("Firearm")
			end,
		},
		{category = "Ambient Life", id = "ChanceSpawn", name = "Chance of Spawning",
			editor = "number", default = 0, min = 0, max = 100, slider = true,
		},
		{category = "Ambient Life", id = "Groups", name = "Groups", editor = "string_list", default = false,
			items = function()
				local items = table.keys2(Groups or empty_table, "sorted")
				table.insert(items, 1, "Closest AmbientZoneMarker")
				return items
			end,
		},
		{category = "Ambient Life", id = "Ephemeral", name = "Ephemeral", editor = "bool", default = true,
			no_edit = function(self) return self.ChanceSpawn == 0 end,
			help = "When the time to re-spawm the AL on the map perpetual units are kicked out if this flag is set and new ones are tried to be stolen. Otherwise the units are kept there",
		},
		{category = "Ambient Life", id = "AttractGender", name = "Attract Gender", editor = "dropdownlist",
			default = "Both", items = {"Both", "Male", "Female"},			
		},
		{category = "Ambient Life", id = "IgnoreGroupsMatch", name = "Ignore Groups Match", editor = "bool",
			default = false, help = "If checked matching AL_ prefix group match between the unit and marker is skipped",
		},
		{category = "Ambient Life", id = "VisitSupportCollection", name = "Visit Support Set",
			editor = "objects", base_class = "Object", default = false,
			help = "At least ONE Object in the set must be intact for the marker to be visitable",
		},
		
		-- editor & debug properties
		{category = "Ambient Life Editor", id = "IgnoreVisitSupportVME", name = "Ignore Visit support VME",
			editor = "bool", default = false,
			help = "If you are sure the support collection can't be destroyed and is properly position you can turn off the VME for this class",
		},
		{category = "Ambient Life Editor", id = "EditorMarkerVisitAnim", name = "Editor Marker Visit Anim", editor = "dropdownlist",
			default = false, items = function(obj) return obj:GetStatesTextTable() end,
		},
		{category = "Ambient Life Editor", id = "VisitPose", name = "Visit Pose", editor = "number",
			default = 0, slider = true, min = 0,
			max = function(obj)
				return GetAnimDuration(obj:GetEntity(), obj.EditorMarkerVisitAnim or obj.VisitIdle) - 1
			end,
			help = "This is just for edit/debug purposed only for easier distinguishing which VisitIdle animation will be played at the marker",
		},
		{category = "Ambient Life Editor", id = "ViewPerpetual", editor = "buttons", default = false,
			no_edit = function(self) return not self.perpetual_unit end,
			buttons = {
				{ name = "View Perpetual Unit", func = function(self)
					ViewObject(self.perpetual_unit)
				end},
				{ name = "Select Perpetual Unit", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.perpetual_unit)
				end},
			},
		},

	-- hidden overridden properties
		{id = "StateCategory"},
		{id = "StateText"},
		{id = "animWeight"},
		{id = "animBlendTime"},
		{id = "anim2"},
		{id = "anim2BlendTime"},
	},
	
	editor_text_offset = point(0, 0, 250 * guic),
	editor_text_style = "AmbientLifeMarker",

	tool_attached = false,
	perpetual_unit = false,
	steal_activated = false,
	destlock = false,
	
	Random = AmbientLife_Random,
	
	VisitSupportCollectionVME = false,
}

--- Initializes the AmbientLifeMarker object.
---
--- If the marker has a Weapon specified, it cannot also have a ToolEntity specified. An error will be logged in this case.
---
--- The marker's appearance is set to the specified Appearance, or "Legion_Jose" if no Appearance is specified.
---
--- The marker's animation pose is set to the specified EditorMarkerVisitAnim or VisitIdle animation, at the specified VisitPose frame.
function AmbientLifeMarker:Init()
	if self.Weapon ~= "" and self.ToolEntity ~= ""  then
		StoreErrorSource(self, "AmbientLifeMarker can't specify both Tool and Weapon to attach!")
	end
	local appearance = self.Appearance ~= "" and self.Appearance or "Legion_Jose"
	self:ApplyAppearance(appearance)
	self:SetAnimPose(self.EditorMarkerVisitAnim or self.VisitIdle, self.VisitPose)
end

--- Gets the comma-separated string representation of the Groups property of the AmbientLifeMarker.
---
--- @return string The comma-separated string representation of the Groups property.
function AmbientLifeMarker:GetGroupsText()
	if not self.Groups then return "" end
	return table.concat(self.Groups, ",")
end

--- Gets the editor text for the AmbientLifeMarker.
---
--- The editor text includes the class name, the comma-separated list of groups, and any additional information about the marker, such as whether it has a teleport or visit support collection.
---
--- @return string The editor text for the AmbientLifeMarker.
function AmbientLifeMarker:GetEditorText()
	local text = T{Untranslated("<style GedName><class></style> <GroupsText>"), self}
	if self.Teleport then
		text = text .. Untranslated("\n\tTeleport")
	end
	if self.VisitSupportCollection then
		local count = #self.VisitSupportCollection
		if count == 1 then
			text = text .. Untranslated("\n\t1 CombatObject in Visit Support Collection")
		else
			text = text .. T{Untranslated("\n\t<count> CombatObjects in Visit Support Collection"), count = count}
		end
	end
	
	return text
end

--- Gets the visitable object and its index in the g_Visitables table.
---
--- @return table|nil visitable The visitable object, or nil if not found.
--- @return integer|nil idx The index of the visitable object in the g_Visitables table, or nil if not found.
function AmbientLifeMarker:GetVisitable()
	local visitable, idx = table.find_value(g_Visitables, 1, self)

	return visitable, idx
end

--- Adds the AmbientLifeMarker to the g_Visitables table, generating a visitable object for it.
---
--- This function is called when the AmbientLifeMarker is placed in the editor.
---
--- @return void
function AmbientLifeMarker:EditorCallbackPlace()
	table.insert(g_Visitables, self:GenerateVisitable())
end

--- Removes the AmbientLifeMarker from the g_Visitables table and releases any reserved units.
---
--- This function is called when the AmbientLifeMarker is deleted from the editor.
---
--- @return void
function AmbientLifeMarker:EditorCallbackDelete()
	local visitable, idx = self:GetVisitable()
	if visitable then
		table.remove(g_Visitables, idx)
		if visitable.reserved then
			local unit = HandleToObject[visitable.reserved]
			if IsValid(unit) and not unit:IsDead() then
				unit:SetCommand(false)
			end
		end
	end
end

AmbientLifeMarker.EditorCallbackMove = AmbientLifeMarker.RebuildVisitable
AmbientLifeMarker.EditorCallbackRotate = AmbientLifeMarker.RebuildVisitable
AmbientLifeMarker.EditorCallbackScale = AmbientLifeMarker.RebuildVisitable

--- Handles changes to the editor properties of the AmbientLifeMarker object.
---
--- This function is called when the editor properties of the AmbientLifeMarker object are changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged table The GED object associated with the property.
--- @return void
function AmbientLifeMarker:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "VisitPose" or prop_id == "VisitIdle" or prop_id == "EditorMarkerVisitAnim" then
		self:SetAnimPose(self.EditorMarkerVisitAnim or self.VisitIdle, self.VisitPose)
	elseif prop_id == "ChanceSpawn" then
		if self.ChanceSpawn == 100 then
			self:SetProperty("AllowAL", false)
		end
	elseif prop_id == "VisitAlternateChance" then
		if self.VisitAlternateChance == 0 then
			local prop_meta = self:GetPropertyMetadata("VisitAlternate")
			self:SetProperty("VisitAlternate", prop_meta.default)
		end
	elseif prop_id == "EmotionChance" then
		if self.EmotionChance == 0 then
			local prop_meta = self:GetPropertyMetadata("EmotionAnimation")
			self:SetProperty("EmotionAnimation", prop_meta.default)
		end
	else
		AppearanceObject.OnEditorSetProperty(self, prop_id)
	end
end

--- This function is called when the AmbientLifeMarker enters the editor.
---
--- It sets the animation pose of the marker to the EditorMarkerVisitAnim or VisitIdle pose.
---
--- @return void
function AmbientLifeMarker:EditorEnter()
	EditorMarker.EditorEnter(self)
	self:SetAnimPose(self.EditorMarkerVisitAnim or self.VisitIdle, self.VisitPose)
end

--- Handles the selection of the AmbientLifeMarker object in the editor.
---
--- When the marker is selected, it sets the animation speed to 1000 and validates the VisitSupportCollection.
--- If the VisitSupportCollection is valid, it is added to the editor selection.
--- When the marker is deselected, it sets the animation pose to the EditorMarkerVisitAnim or VisitIdle pose.
---
--- @param selected boolean Whether the marker is selected or not.
--- @return void
function AmbientLifeMarker:EditorSelect(selected)
	if selected then
		self.anim_speed = 1000
		self:ValidateVisitSupportCollection()
		if self.VisitSupportCollection then
			editor.AddToSel(self.VisitSupportCollection, "dont_notify")
		end
	else
		if IsValid(self) then
			self:SetAnimPose(self.EditorMarkerVisitAnim or self.VisitIdle, self.VisitPose)
		end
	end
end

--- Spawns a tool attached to the given unit.
---
--- This function is responsible for attaching a tool or weapon to a unit. It handles the positioning and orientation of the attached object, as well as creating the object if it doesn't already exist.
---
--- @param unit Unit The unit to attach the tool to.
--- @param tool_orient_time number The time in seconds to orient the tool.
--- @return void
function AmbientLifeMarker:SpawnTool(unit, tool_orient_time)
	if not unit:HasSpot(self.ToolSpot) then return end
	
	local spot = unit:GetSpotBeginIndex(self.ToolSpot)
	local attach_angle = 0
	if (tool_orient_time or 0) > 0 then
		if IsValid(self.tool_attached) then
			local spot_pos, spot_angle, spot_axis = unit:GetSpotLoc(unit:GetState(), unit:GetAnimPhase(1) + tool_orient_time, spot)
			-- this is a solution for the only carry object we have.
			-- a general solution could select from object Carry spots and align with it (choose closest spot angle)
			if self.tool_attached:AngleToObject(unit) < 0 then
				attach_angle = 180*60
			end
			self.tool_attached:SetAxis(spot_axis, tool_orient_time)
			self.tool_attached:SetAngle(spot_angle + attach_angle, tool_orient_time)
		end
		Sleep(tool_orient_time)
	end
	if not IsValid(self.tool_attached) then 
		self.tool_attached = false
		if self.ToolEntity == "" and self.Weapon == "" then return end
		
		if self.ToolEntity ~= "" then
			self.tool_attached = PlaceObject(self.ToolEntity)
			if IsKindOf(self.tool_attached, "CombatObject") then
				self.tool_attached:InitFromMaterial()	-- otherwise .HitPoints=-1 and tool is considered dead
			end
			if self.ToolColors then
				self.tool_attached:SetColorization(self.ToolColors)
			end
			if self.ToolAutoAttachMode then
				self.tool_attached:SetAutoAttachMode(self.ToolAutoAttachMode)
			end
		else
			local weapon_item = PlaceInventoryItem(self.Weapon)
			if weapon_item then
				self.tool_attached = weapon_item:CreateVisualObj()
			end
		end
	end
	self.tool_attached:SetApplyToGrids(false)
	self.tool_attached:ClearEnumFlags(const.efCollision)
	unit:Attach(self.tool_attached, spot)
	self.tool_attached:SetAttachAngle(attach_angle)
	if self.ToolAttachOffset then
		self.tool_attached:SetAttachOffset(self.ToolAttachOffset)
	end
end

--- Detaches the tool attached to the AmbientLifeMarker and either sets its position and orientation or destroys it, depending on the type of marker.
---
--- If the marker is an `AL_Carry` type, the tool is set to the marker's position with a 0 degree rotation around the Z axis, its object marking is cleared, and its hierarchy game flags are cleared.
---
--- If the marker is not an `AL_Carry` type, the tool is destroyed using `DoneObject()` and the `tool_attached` reference is set to `false`.
function AmbientLifeMarker:DespawnTool()
	if not IsValid(self.tool_attached) then return end
	
	self.tool_attached:Detach()
	self.tool_attached:SetApplyToGrids(true)
	if self:IsKindOf("AL_Carry") then
		self.tool_attached:SetPos(self:GetPos())
		self.tool_attached:SetAxisAngle(axis_z, 0)
		self.tool_attached:SetObjectMarking(-1)
		self.tool_attached:ClearHierarchyGameFlags(const.gofObjectMarking)
	else
		DoneObject(self.tool_attached)
		self.tool_attached = false
	end
end

--- Generates a table containing the current AmbientLifeMarker instance.
---
--- This function is used to return the current AmbientLifeMarker instance as a table, which can be used for various purposes, such as visiting the marker or checking its properties.
---
--- @return table The current AmbientLifeMarker instance.
function AmbientLifeMarker:GenerateVisitable()
	return {self}
end

--- Checks if the current AmbientLifeMarker instance matches the specified conditions and game states.
---
--- This function evaluates the `Conditions` list and checks if the current game state matches the `GameStatesFilter` of the AmbientLifeMarker instance.
---
--- @return boolean true if the conditions and game states match, false otherwise
function AmbientLifeMarker:MatchConditionsAndGameStates()
	return EvalConditionList(self.Conditions) and MatchGameState(self.GameStatesFilter)
end

--- Checks if the current AmbientLifeMarker instance can be visited by the specified unit.
---
--- This function performs various checks to determine if the unit can visit the AmbientLifeMarker instance. The checks include:
--- - Ensuring the objects required for the visit are still alive
--- - Checking the gender of the unit against the AttractGender of the marker
--- - Checking if the marker's position is not already occupied by another unit
--- - Checking if the marker is allowed to be visited based on the AllowAL and perpetual_unit properties
--- - Checking if the marker's conditions and game states match
--- - Checking if the unit is within the VisitIgnoreRange of the marker
--- - Checking if the unit's groups match the marker's IgnoreGroupsMatch property
--- - Checking if the unit has a valid VisitIdle animation
---
--- @param unit the unit to check for visiting the marker
--- @param for_perpetual whether the check is for a perpetual unit
--- @param dont_check_dist whether to skip checking the distance to the marker
--- @return boolean true if the unit can visit the marker, false otherwise
function AmbientLifeMarker:CanVisit(unit, for_perpetual, dont_check_dist)
	if not self:IsVisitSupportCollectionAlive() then
		return false	-- any of the objects we care about is destroyed
	end
	if self.AttractGender ~= "Both" then
		if unit.gender ~= self.AttractGender then
			return false
		end
	end
	if not g_Combat and IsOccupiedExploration(unit, self:GetPosXYZ()) then
		local occupied_by = MapGetFirst(self, 0, "Unit", function(u, unit)
			return u ~= unit and select(3, u:GetPosXYZ()) == select(3, unit:GetPosXYZ())
		end, unit)
		if occupied_by then
			return false
		end
	end

	for_perpetual = for_perpetual or self.perpetual_unit == unit
	if for_perpetual or self.AllowAL or (not self.AllowAL and not unit:IsAmbientUnit()) then
		if not self:MatchConditionsAndGameStates() then
			return false
		end
		if not for_perpetual then
			local check_ignore_dist = not dont_check_dist and (not unit.zone or unit.zone.MinRoamDist >= 0)
			if check_ignore_dist and IsCloser2D(self, unit, const.AmbientLife.VisitIgnoreRange) then
				return false
			end
		end
		if not unit.visit_test and not (self.IgnoreGroupsMatch or unit:GroupsMatch(self)) then
			return false
		end
		if not IsValidAnim(unit, self.VisitIdle) or unit:GetAnimDuration(self.VisitIdle) == 0 then
			return false
		end
		return true
	end
end

---
--- Moves the unit to the enter spot of the ambient life marker and spawns any associated tools.
--- If the unit is allowed to teleport, it will be teleported directly to the enter spot.
--- Otherwise, the unit will pathfind to the enter spot.
---
--- @param unit the unit to move to the enter spot
--- @param dest the destination position for the unit to move to
--- @return boolean true if the unit was able to reach the enter spot, false otherwise
---
function AmbientLifeMarker:GotoEnterSpot(unit, dest)
	local distance = 0
	if self:IsKindOf("AL_Carry") then
		local phase = unit:GetAnimMoment(self.VisitEnter, "hit")
		if (phase or 0) > 0 then
			distance = unit:GetVisualDist2D(unit:GetSpotLocPosXYZ(self.VisitEnter, phase, unit:GetSpotBeginIndex(self.ToolSpot)))
		end
	end
	if unit.teleport_allowed_once then
		unit.teleport_allowed_once = false
		local angle = self:GetAngle()
		unit:SetPos(RotateRadius(distance, angle, dest, true))
		unit:SetAngle(angle)
		self:SpawnTool(unit)
	else
		local remove_pfflags = unit:GetPathFlags(const.pfmVoxelAligned | const.pfmDestlock | const.pfmDestlockSmart)
		unit:ChangePathFlags(0, remove_pfflags)
		unit:PushDestructor(function(self)
			if IsValid(self) then
				self:ChangePathFlags(remove_pfflags)
			end
		end)
		local finished
		if distance == 0 then
			finished = unit:GotoSlab(dest)
		else
			finished = unit:GotoSlab(dest, distance)
		end
		unit:PopAndCallDestructor()
		if not finished then
			return
		end
	end
	
	return unit.visit_test or self:MatchConditionsAndGameStates()
end

---
--- Applies the step vector and angle for the unit when entering an ambient life marker.
---
--- @param unit the unit entering the ambient life marker
--- @param dest the destination position for the unit to enter
--- @param lookat the position the unit should look at
--- @param angle the angle the unit should face
---
function AmbientLifeMarker:ApplyVisitEnterStepVectorAngle(unit, dest, lookat, angle)
	if (self.VisitEnter or "") == "" then return end
	
	angle = angle or (lookat and CalcOrientation(unit, lookat) or self:GetAngle())
	unit:SetPos(dest + unit:GetStepVector(self.VisitEnter, angle))
	unit:SetAngle(angle + unit:GetStepAngle(self.VisitEnter))
end

---
--- Enters the ambient life marker and applies the appropriate step vector and angle for the unit.
---
--- @param unit the unit entering the ambient life marker
--- @param dest the destination position for the unit to enter
--- @param lookat the position the unit should look at
---
function AmbientLifeMarker:Enter(unit, dest, lookat)
	local angle = lookat and CalcOrientation(unit, lookat) or self:GetAngle()
	if (self.VisitEnter or "") == "" then
		unit:SetPos(dest)
		if not IsKindOf(self, "AL_Roam") or not self.DontReorient then
			local adiff = AngleDiff(unit:GetVisualAngle(), angle)
			if abs(adiff) > 5 * 60 then
				unit:AnimatedRotation(angle)
			end
		end
		return
	end
	if unit.perpetual_marker and unit.teleport_allowed_once then
		unit.teleport_allowed_once = false
		self:ApplyVisitEnterStepVectorAngle(unit, dest, lookat, angle)
		return
	end
	self.destlock = PlaceObject("Destlock")
	self.destlock:SetPos(self:IsKindOf("AL_Carry") and self.CarryDestination or dest)
	pf.SetDestlockRadius(self.destlock, unit:GetDestlockRadius())
	unit:SetState(self.VisitEnter)
	PlayFX(string.format("Anim:%s", self:GetStateText()), "start", unit)
	if self:IsKindOf("AL_Carry") then
		local time = unit:TimeToMoment(1, "hit") or 0
		unit:SetAngle(angle, Min(200, time))
		local tool_orient_time = Min(200, time)
		Sleep(time - tool_orient_time)
		self:SpawnTool(unit, tool_orient_time)
		Sleep(unit:TimeToAnimEnd())
		return
	end
	self:SpawnTool(unit)

	unit:AnimatedRotation(angle)
	unit:SetState(self.VisitEnter)
	unit:SetTargetDummyFromPos()

	local step_angle = unit:GetStepAngle()
	local duration = unit:TimeToAnimEnd()
	unit:SetPos(dest + unit:GetStepVector(self.VisitEnter, angle), duration)

	local steps = 2
	for i = 1, steps do
		local t = duration * i / steps - duration * (i - 1) / steps
		local a = angle + step_angle * i / steps
		unit:SetAngle(a, t)
		Sleep(t)
	end
end

--- Called when the visit animation has ended.
---
--- This hook can be used to perform additional actions after the visit animation has completed, such as stealing items from a corpse's inventory.
---
--- @param unit The unit that has finished the visit animation.
function AmbientLifeMarker:OnVisitAnimEnded(unit)
	-- you can hook here to do some stuff, e.g. steal items from corpse's inventory - see AL_Maraud
end

---
--- Starts a visit animation for the given unit and performs additional actions during and after the visit animation.
---
--- @param unit The unit that will perform the visit animation.
--- @param visit_duration The duration of the visit animation, in seconds.
---
function AmbientLifeMarker:StartVisit(unit, visit_duration)
	local randomize_phase = unit.perpetual_marker and "randomize phase"
	repeat
		local start_time = GameTime()
		self:SetVisitAnimation(unit, randomize_phase)
		randomize_phase = false	
		self:SpawnTool(unit)
		Sleep(unit:TimeToAnimEnd())
		self:OnVisitAnimEnded(unit)
		visit_duration = visit_duration + GameTime() - start_time
		local visit_finished = not self.VisitMinDuration or visit_duration >= self.VisitMinDuration
	until (not self.perpetual_unit) and visit_finished or (not self:CanVisit(unit, nil, "don't check dist"))
end

---
--- Exits the visit animation for the given unit.
---
--- This function is responsible for handling the exit logic when a unit has finished its visit animation. It sets the unit's command parameter, plays the exit animation, and performs any necessary cleanup or additional actions.
---
--- @param unit The unit that is exiting the visit animation.
---
function AmbientLifeMarker:ExitVisit(unit)
	if IsValid(unit) then
		unit:SetCommandParamValue(unit.command, "move_style", nil)
		if (self.VisitExit or "") ~= "" and IsValidAnim(unit, self.VisitExit) then
			unit:SetState(self.VisitExit)
			local combat_anim_speed = 2000
			if unit.command == "EnterCombat" then
				unit:SetAnimSpeed(1, combat_anim_speed)
			end
			local time = unit:TimeToAnimEnd(1)
			unit:SetPos(unit:GetPos() + unit:GetStepVector(), time)
			unit:SetAngle(unit:GetAngle() + unit:GetStepAngle(), time)
			local wait_time = IsMerc(unit) and (unit:TimeToMoment(1, "end") or Max(0, time - 300)) or time
			if unit.command == "EnterCombat" then
				Sleep(wait_time)
			elseif WaitMsg("CombatStarting", wait_time) or unit.command == "EnterCombat" then
				if IsValid(unit)	then	-- WaitMsg above
					unit:SetAnimSpeed(1, combat_anim_speed)
					time = unit:TimeToAnimEnd(1)
					wait_time = IsMerc(unit) and (unit:TimeToMoment(1, "end") or Max(0, time - 300)) or time
					unit:SetPos(unit:GetPos(), time)
					unit:SetAngle(unit:GetAngle(), time)
					Sleep(wait_time)
				end
			end
			if self.tool_attached then
				self:DespawnTool()
			end
			if wait_time < time then
				Sleep(unit:TimeToAnimEnd())
			end
		end
	end
	if self.tool_attached then
		self:DespawnTool()
	end
	if self.destlock then
		if IsValid(unit) then
			if (GameState.Combat or GameState.Conflict) and not self:IsKindOf("AL_Carry") then
				unit:SetPos(self.destlock:GetPos())
			end
		end
		DoneObject(self.destlock)
		self.destlock = false
	end
end

---
--- Visits the ambient life marker with the given unit, handling the enter and exit logic.
---
--- @param unit The unit that is visiting the marker.
--- @param dest The destination position for the unit to visit.
--- @param lookat The position the unit should look at during the visit.
--- @param already_in_perpetual Whether the unit is already in a perpetual visit state.
---
function AmbientLifeMarker:Visit(unit, dest, lookat, already_in_perpetual)
	dest = dest or self:GetPos()
	
	-- going to the marker spot
	unit.visit_reached = false
	unit:ReserveVisitable(self:GetVisitable())
	local start_time = GameTime()
	unit:PushDestructor(function()
		self.perpetual_unit = false
		unit:FreeVisitable()
	end)
	unit:SetCommandParamValue("Visit", "move_style", nil)

	if not already_in_perpetual and not self:GotoEnterSpot(unit, dest) then
		if start_time == GameTime() then
			unit:IdleRoutine_StandStill(3000)
		end
		unit:PopAndCallDestructor()
		return
	end
	if not self:CanVisit(unit, nil, "don't check dist") then
		-- meanwhile can become not visitable, e.g. support collection destroyed
		unit:PopAndCallDestructor()
		return
	end
	unit:PopDestructor()
	
	-- prepare the unbreakable exit from the marker
	local is_carry_marker = self:IsKindOf("AL_Carry")
	unit:PushDestructor(function()
		unit:SetTargetDummy(false)
		self.perpetual_unit = false
		PlayFX(string.format("Anim:%s", self:GetStateText()), "end", unit)
		if IsValid(unit) and not unit:IsDead() then
			self:ExitVisit(unit)
		end
		unit:FreeVisitable()
		if is_carry_marker then
			unit:SetCommandParamValue("Visit", "move_style", nil)
		end
	end)
	
	start_time = GameTime()
	unit.visit_reached = not is_carry_marker
	if already_in_perpetual then
		if not is_carry_marker then
			self:ApplyVisitEnterStepVectorAngle(unit, dest, lookat, not IsKindOf(self, "AL_SitChair") and self:GetAngle() or nil)
		end
	else
		self:Enter(unit, dest, lookat)
	end
	if not self:CanVisit(unit, nil, "don't check dist") then
		-- meanwhile can become not visitable, e.g. support collection destroyed
		unit:PopAndCallDestructor()
		return
	end
	
	-- actual visit
	if is_carry_marker then
		local move_style = GetAnimationStyle(unit, self.MoveStyle) or GetAnimationStyle(unit, "Walk_Carry")
		if move_style then
			unit:SetCommandParamValue(unit.command, "move_style", move_style.Name)
		end
	else
		if not already_in_perpetual then
			self:StartVisit(unit, GameTime() - start_time)
		end
	end
	if unit.perpetual_marker then
		if is_carry_marker then
			-- carry only once and forget about being perpetual
			unit:GotoSlab(self.CarryDestination)
			unit.perpetual_marker = false
			self.perpetual_unit = false
		else
			while unit.perpetual_marker == self and self:CanVisit(unit) do
				self:SetVisitAnimation(unit)
				Sleep(unit:TimeToAnimEnd())
				self:OnVisitAnimEnded(unit)
			end
		end
	else
		if is_carry_marker then
			unit:GotoSlab(self.CarryDestination)
		end
	end
	if start_time == GameTime() then
		unit:IdleRoutine_StandStill(3000)
	end
	
	-- unbreakable exit from the marker
	unit:PopAndCallDestructor()
end

---
--- Checks if a random chance is successful.
---
--- @param chance number The chance of success, as a percentage (0-100).
--- @return boolean True if the random chance is successful, false otherwise.
function AmbientLifeMarker:IsLucky(chance)
	return (chance > 0) and self:Random(100) < chance
end

---
--- Gets the base animation and variation for an ambient life marker.
---
--- @param self AmbientLifeMarker The ambient life marker instance.
--- @return string base_anim The base animation to use.
--- @return string variation The variation of the base animation to use.
function AmbientLifeMarker:GetBaseAnimVariation()
	local original = not self:IsLucky(self.VisitAlternateChance)
	local emotion = not original and self:IsLucky(self.EmotionChance)
	local base_anim = original and self.VisitIdle or 
		(emotion and self.EmotionAnimation or self.VisitAlternate)
	local variation = original and self.VisitVariation or 
		(emotion and self.EmotionVariation or self.VisitAlternateVariation)
		
	return base_anim, variation
end

---
--- Sets the visit animation for a unit.
---
--- @param unit table The unit to set the animation for.
--- @param randomize_phase boolean Whether to randomize the animation phase.
---
function AmbientLifeMarker:SetVisitAnimation(unit, randomize_phase)
	local base_anim, variation = self:GetBaseAnimVariation()
	local anim, phase
	if variation then
		anim, phase = unit:GetNearbyUniqueRandomAnim(base_anim)
		if not randomize_phase then
			phase = 0
		end
	else
		anim, phase = base_anim, 0
	end
	local same_anim = unit:GetStateText() == anim
	local crossfade = IsKindOf(self, "AL_Roam") and -1 or 0
	unit:SetState(anim, 0, crossfade)
	if same_anim then
		if unit:GetAnimMomentsCount(anim, "start") > 0 then
			unit:OnAnimMoment("start", anim)
		end
	end
	if phase > 0 then
		unit:SetAnimPhase(1, phase)
	end
	unit:SetTargetDummyFromPos()
end

---
--- Determines if the ambient life marker can spawn.
---
--- @return boolean true if the marker can spawn, false otherwise
function AmbientLifeMarker:CanSpawn()
	return self:IsPerpetual() and self:MatchConditionsAndGameStates()
end

---
--- Gets the closest object from a group that matches the specified classes.
---
--- @param classes table A table of class names to check against.
--- @param group string The name of the group to search.
--- @return table|nil The closest object from the group that matches the specified classes, or nil if none found.
---
function AmbientLifeMarker:GetClosestClassFromGroup(classes, group)
	local objects = Groups[group]
	local closest, closest_dist
	for _, obj in ipairs(objects) do
		if IsKindOfClasses(obj, classes) then
			local is_zone = IsKindOf(obj, "AmbientZoneMarker")
			if (not is_zone and not obj.perpetual_marker and not obj:IsDead() and not obj:IsDefeatedVillain() and self:CanVisit(obj, "for perpetual") and not IsSetpieceActor(obj)) or (is_zone and obj:CanSpawn()) then
				if not closest then
					closest, closest_dist = obj, obj:GetDist(self)
				else
					local dist = obj:GetDist(self)
					if dist < closest_dist then
						closest, closest_dist = obj, dist
					end
				end
			end
		end
	end
	
	return closest
end

local function filter_can_spawn_zone(zone)
	return zone:CanSpawn()
end

---
--- Gets the unit that was spawned by this ambient life marker.
---
--- @return Unit|AmbientZoneMarker|nil The spawned unit or zone marker, or nil if none found.
function AmbientLifeMarker:GetSpawnedUnit()
	local group
	for _, grp in ipairs(self.Groups) do
		if not grp:starts_with("AL_") then
			group = grp
			break
		end
	end
	
	local zone
	if group == "Closest AmbientZoneMarker" then
		local pos = self:GetPos()
		local x, y = terrain.GetMapSize()
		local radius = (x > y) and x or y
		zone = MapFindNearest(pos, pos, radius, "AmbientZoneMarker", filter_can_spawn_zone)
		if not zone then
			StoreErrorSource(self, "Can't find AmbientZoneMarker around which can spawn to steal from")
		end
	else
		local obj = self:GetClosestClassFromGroup({"Unit", "AmbientZoneMarker"}, group or self.Groups[1])
		if IsKindOf(obj, "Unit") then
			return obj
		end
		zone = obj
	end
	
	return zone and zone:GetUnitForMarker(self)
end

---
--- Steals the spawned unit from this ambient life marker.
---
--- If this marker has a perpetual unit already, this function does nothing.
--- Otherwise, it tries to get the spawned unit from the marker and assigns it
--- to the `perpetual_unit` field. It also sets the `teleport_allowed_once`
--- field of the perpetual unit to the `Teleport` field of the marker, and
--- sets the `perpetual_marker` field of the perpetual unit to this marker.
---
--- If the perpetual unit has a different visitable object than this marker,
--- it will free the old visitable and reserve the new one. If the old
--- visitable was reserved by another unit, that unit will be freed as well.
---
--- Finally, the perpetual unit will be set to visit the new visitable object.
--- If there is an ongoing combat, the unit will only have its behavior set
--- to "Visit" instead of a full command.
---
--- @return void
function AmbientLifeMarker:StealSpawnedUnit()
	if self.perpetual_unit then return end
	
	self.steal_activated = true
	self.perpetual_unit = self:GetSpawnedUnit() or false
	if not self.perpetual_unit then return end
	
	self.perpetual_unit.teleport_allowed_once = self.Teleport
	self.perpetual_unit.perpetual_marker = self
	local visitable = self:GetVisitable()
	local old_visitable = self.perpetual_unit:GetVisitable()
	if old_visitable == visitable then
		return
	end
	if old_visitable then
		self.perpetual_unit:FreeVisitable(old_visitable)
	end
	if visitable.reserved then
		local unit = HandleToObject[visitable.reserved]
		if unit then
			unit:FreeVisitable(visitable)
			unit:SetBehavior()
			unit:SetCommand(false)
		end
	end
	self.perpetual_unit:ReserveVisitable(visitable)
	if g_Combat then
		-- only set the behavior, the unit is currently busy being afraid from the ongoing combat
		self.perpetual_unit:SetBehavior("Visit", {visitable})
	else
		self.perpetual_unit:SetCommand("Visit", visitable)
	end
end

---
--- Spawns the perpetual unit associated with this ambient life marker.
---
--- If the marker is ephemeral, the existing perpetual unit is first freed by
--- setting its behavior to nothing and clearing its command.
---
--- The function then calls `StealSpawnedUnit()` to attempt to get the spawned
--- unit from the marker and assign it to the `perpetual_unit` field.
---
--- @return void
function AmbientLifeMarker:Spawn()
	if self.Ephemeral then
		if self.perpetual_unit then
			self.perpetual_unit:SetBehavior()
			self.perpetual_unit:SetCommand(false)
			self.perpetual_unit = false
		end
	end
	self:StealSpawnedUnit()
end

---
--- Despawns the perpetual unit associated with this ambient life marker.
---
--- If the perpetual unit is valid and not being destructed, it is freed from its
--- visitable, its behavior is set to nothing, and its command is set to "Idle".
--- The perpetual unit's reference to this ambient life marker is then cleared,
--- and the perpetual unit field is set to false.
---
--- @return void
function AmbientLifeMarker:Despawn()
	if self.perpetual_unit then
		if IsValid(self.perpetual_unit) and not IsBeingDestructed(self.perpetual_unit) then
			self.perpetual_unit:FreeVisitable()
			self.perpetual_unit:SetBehavior()
			self.perpetual_unit:SetCommand("Idle")
		end
		self.perpetual_unit.perpetual_marker = false
		self.perpetual_unit = false
	end
end

---
--- Serializes the dynamic data of the AmbientLifeMarker into a table.
---
--- The dynamic data includes the perpetual unit handle, whether the steal
--- functionality is activated, and whether a tool is attached.
---
--- @param data table The table to serialize the dynamic data into.
--- @return void
function AmbientLifeMarker:GetDynamicData(data)
	data.perpetual_unit = self.perpetual_unit and self.perpetual_unit.handle or nil
	data.steal_activated = self.steal_activated or nil
	data.tool_attached = self.tool_attached and true or nil	-- NOTE: not permament object so needs respawning
end

---
--- Sets the dynamic data of the AmbientLifeMarker.
---
--- The dynamic data includes the perpetual unit handle, whether the steal
--- functionality is activated, and whether a tool is attached.
---
--- @param data table The table containing the dynamic data to set.
--- @return void
function AmbientLifeMarker:SetDynamicData(data)
	self.perpetual_unit = data.perpetual_unit and HandleToObject[data.perpetual_unit] or false
	self.steal_activated = data.steal_activated or false
	self.tool_attached = data.tool_attached or false	-- NOTE: not permament object so needs respawning
end

---
--- Checks if the AmbientLifeMarker is perpetual.
---
--- An AmbientLifeMarker is considered perpetual if it has one or more groups
--- defined and a chance to spawn greater than 0.
---
--- @return boolean true if the AmbientLifeMarker is perpetual, false otherwise
function AmbientLifeMarker:IsPerpetual()
	return self.Groups and self.ChanceSpawn > 0
end

---
--- Checks if the tool attached to the AmbientLifeMarker is destroyed.
---
--- @return boolean true if the tool is destroyed, false otherwise
function AmbientLifeMarker:IsToolDestroyed()
	if self.ToolEntity == "" then return end
	
	local tool = self.tool_attached	
	
	return IsValid(tool) and IsKindOf(tool, "CombatObject") and tool:IsDead()
end

---
--- Generates the editor text for an AmbientLifeMarker.
---
--- The editor text includes information about the state of the marker, such as
--- whether the associated combat objects are destroyed, whether the marker's
--- conditions are met, and whether the marker is in a repulsion zone.
--- If the marker is perpetual, the editor text also includes information about
--- the spawned unit.
---
--- @return string The editor text for the AmbientLifeMarker
function AmbientLifeMarker:EditorGetText()
	local sup_col_dead
	if not self:IsVisitSupportCollectionAlive("all") then
		sup_col_dead = string.format("All associated combat object(s) are destroyed!")
	end
	if not self:IsVisitSupportCollectionAlive() then
		sup_col_dead = string.format("Some associated combat object(s) are destroyed!")
	end
	
	local cond_text
	local context = {}
	for i, condition in ipairs(self.Conditions) do
		if not condition:Evaluate(self, context) then
			cond_text = string.format("%s: false", TDevModeGetEnglishText(condition:GetEditorView()))
		end
	end
	
	local avoid_text = IsInAmbientLifeRepulsionZone(self) and "In Repulsion Zone"

	if sup_col_dead or cond_text or avoid_text then
		local pre_conditions = {}
		if sup_col_dead then
			table.insert(pre_conditions, sup_col_dead)
		end
		if cond_text then
			table.insert(pre_conditions, cond_text)
		end
		if avoid_text then
			table.insert(pre_conditions, avoid_text)
		end
		
		return table.concat(pre_conditions, "\n")
	end

	local perpetual = self:IsPerpetual() and string.format("(Perpetual: %d%%)", self.ChanceSpawn) or ""
	local text = string.format("AL %s Visit%s", self.AllowAL and "CAN" or "CAN'T", perpetual)
	local game_states = MatchGameState(self.GameStatesFilter)
	local conditions = EvalConditionList(self.Conditions)
	if not game_states or not conditions then
		if not game_states then
			local mismatch_states = {"Mismatch States:"}
			for state, active in pairs(self.GameStatesFilter) do
				local game_state_active = not not GameState[state]
				if active ~= game_state_active then
					table.insert(mismatch_states, state) 
				end
			end
			text = string.format("%s\n%s", text, table.concat(mismatch_states, " "))
		end
		if not conditions then
			local mismatch_conditions = {"Mismatch Conditions:"}
			for _, condition in ipairs(self.Conditions) do
				local ok, result = procall(condition.__eval, condition)
				if not ok then
					table.insert(mismatch_conditions, condition:GetEditorView())
				end
				if condition.Negate then
					result = not result
				end
				if not result then
					table.insert(mismatch_conditions, "NOT " .. condition:GetEditorView())
				end
			end
			text = string.format("%s\n%s", text, table.concat(mismatch_conditions, " "))
		end
	else
		if self:IsPerpetual() then
			local action_text = self.perpetual_unit and "Stolen from:" or "No Free Units to Steal From:"
			local unit = self:GetSpawnedUnit()
			text = string.format("%s\n%s %s[%s](for %s anim)", text, action_text, self.Groups[1], unit and unit.class or "???", self.VisitIdle)
		end
	end
	
	return text
end

---
--- Determines the editor text color for the AmbientLifeMarker based on various conditions.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @return number The editor text color, either const.clrGreen or const.clrRed.
---
function AmbientLifeMarker:EditorGetTextColor()
	local pre_conditions_ok = 
		self:IsVisitSupportCollectionAlive() and 
		not IsInAmbientLifeRepulsionZone(self)
	if pre_conditions_ok then
		local context = {}
		for i, condition in ipairs(self.Conditions) do
			if not condition:Evaluate(self, context) then
				pre_conditions_ok = false
				break
			end
		end
	end
	local perpetual_ok = self:IsPerpetual() == not not self.perpetual_unit
	local match = self:MatchConditionsAndGameStates()
	
	return (pre_conditions_ok and self.AllowAL and match and perpetual_ok) and const.clrGreen or const.clrRed
end

---
--- Gets the root collection index for the AmbientLifeMarker.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @return number The root collection index, or 0 if the marker is not part of a collection.
---
function AmbientLifeMarker:GetRootColIndex()
	local root_collection = self:GetRootCollection()
	
	return root_collection and root_collection.Index or 0
end

---
--- Gets the collection leader for the AmbientLifeMarker.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @return AmbientLifeMarker The collection leader, or the marker itself if it is not part of a collection.
---
function AmbientLifeMarker:GetCollectionLeader()
	local col_idx = self:GetRootColIndex()
	if col_idx == 0 then return self end
	
	local leader = self
	MapForEach("map", "collection", col_idx, true, "AmbientLifeMarker", function(marker)
		leader = (marker.handle < leader.handle) and marker or leader
	end)
	
	return leader
end

---
--- Checks if the AmbientLifeMarker is the collection leader.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @return boolean True if the marker is the collection leader, false otherwise.
---
function AmbientLifeMarker:IsCollectionLeader()
	return self:GetCollectionLeader() == self
end

---
--- Spawns the AmbientLifeMarker and its collection if the marker's ChanceSpawn condition is met.
---
--- If the marker is part of a collection, it will spawn all other markers in the collection as well, ensuring they have the same ChanceSpawn value. If the marker is perpetual, the other markers in the collection will also be spawned as perpetual.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
---
function AmbientLifeMarker:SpawnCollection()
	if self:Random(100) >= self.ChanceSpawn then return end		-- one chance for the whole collection

	self:Spawn()
	local col_idx = self:GetRootColIndex()
	if col_idx == 0 then
		return
	end

	local markers = MapGet("map", "collection", col_idx, true, "AmbientLifeMarker", function(marker)
		return marker ~= self
	end)
	for _, marker in ipairs(markers) do
		marker.steal_activated = self.steal_activated
		if marker.ChanceSpawn ~= self.ChanceSpawn then
			StoreErrorSource(self, "AL markers in collection should have the same ChanceSpawn!")
		end
	end
	if not self.perpetual_unit then return end		-- the rest of the collection don't get unit too
	
	for _, marker in ipairs(markers) do
		marker:Spawn()
	end
end

---
--- Creates a collection of objects that can be visited by the AmbientLifeMarker.
---
--- The collection is stored in the `VisitSupportCollection` field of the AmbientLifeMarker instance.
--- The collection is populated with all valid objects in the current editor selection, excluding other AmbientLifeMarkers.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
---
function AmbientLifeMarker:CreateVisitSupportCollection()
	self.VisitSupportCollection = {}
	for _, obj in ipairs(editor.GetSel() or empty_table) do
		if IsKindOf(obj, "Object") and IsValid(obj) and not IsKindOf(obj, "AmbientLifeMarker") then
			table.insert(self.VisitSupportCollection, obj)
		end
	end
end

---
--- Removes the VisitSupportCollection from the editor selection and sets the VisitSupportCollection field to false.
---
--- This function is used to clean up the VisitSupportCollection when it is no longer needed.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
---
function AmbientLifeMarker:RemoveVisitSupportCollection()
	if self.VisitSupportCollection then
		editor.RemoveFromSel(self.VisitSupportCollection)
		self.VisitSupportCollection = false
	end
end

---
--- Validates the VisitSupportCollection of the AmbientLifeMarker instance.
---
--- This function removes any invalid or AmbientLifeMarker objects from the VisitSupportCollection.
--- If the VisitSupportCollection becomes empty, the VisitSupportCollection field is set to false.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
---
function AmbientLifeMarker:ValidateVisitSupportCollection()
	local collection = self.VisitSupportCollection
	if not collection then return end

	for i = #collection, 1, -1 do
		local obj = collection[i]
		if not IsValid(obj) or IsKindOf(obj, "AmbientLifeMarker") then
			table.remove(collection, i)
		end
	end
	if #collection == 0 then
		self.VisitSupportCollection = false
	end
end

-- if any/all of objects is dead then is not visitable
---
--- Checks if the objects in the VisitSupportCollection are alive.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param bAll boolean If true, returns true if all objects are alive, false otherwise. If false, returns true if any object is dead, false otherwise.
--- @return boolean True if the VisitSupportCollection is empty or all/any objects are alive, false otherwise.
---
function AmbientLifeMarker:IsVisitSupportCollectionAlive(bAll)
	self:ValidateVisitSupportCollection()
	if not self.VisitSupportCollection then
		return true
	end
	
	for _, obj in ipairs(self.VisitSupportCollection) do
		local is_dead = IsKindOf(obj, "CombatObject") and obj:IsDead()
		if bAll and not is_dead then
			return true
		end
		if not bAll and is_dead then
			return false
		end
	end
	
	return not bAll
end

---
--- Checks if the given object is in the VisitSupportCollection of the AmbientLifeMarker instance.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param obj any The object to check.
--- @return boolean True if the object is in the VisitSupportCollection, false otherwise.
---
function AmbientLifeMarker:IsInVisitSupportCollection(obj)
	if self.VisitSupportCollection then
		return not not table.find(self.VisitSupportCollection, obj)
	end
end

---
--- Checks if the given position is on an impassable surface.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param pt table|nil The position to check. If nil, the position of the AmbientLifeMarker is used.
--- @return nil This function does not return a value.
---
function AmbientLifeMarker:VME_CheckImpassable(pt)
	if self:IsPerpetual() or self.Teleport or GetPassSlab(pt or self) then
		return
	end
	StoreErrorSource(self, "AmbientLifeMarker Goto position is on impassable!")
end

---
--- Checks if the given position is below the walkable Z height.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param pt table|nil The position to check. If nil, the position of the AmbientLifeMarker is used.
--- @return nil This function does not return a value.
---
function AmbientLifeMarker:VME_CheckWalkableZ(pt)
	if self:IsPerpetual() or self.Teleport then
		return
	end
	local z = pt and pt:z() or not pt and select(3, self:GetPosXYZ())
	if z and z < terrain.GetHeight(pt or self) then
		StoreErrorSource(self, "AmbientLifeMarker Goto position is below walkable Z!")
	end
end

---
--- Checks the properties of the AmbientLifeMarker instance.
---
--- If the `ChanceSpawn` property is greater than 0 and the `Groups` property is not specified or is empty, it will store an error source indicating that the `Groups` property needs to be specified for a perpetual AmbientLifeMarker.
---
--- If the `ToolEntity` property is specified and the entity does not inherit from `ComponentCustomData`, it will store a warning source indicating that the entity should have `ComponentCustomData` as its parent class.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
---
function AmbientLifeMarker:VME_CheckProperties()
	if self.ChanceSpawn > 0 and (not self.Groups or not next(self.Groups) or not self.Groups[1] or self.Groups[1] == "") then
		StoreErrorSource(self, "AmbientLifeMarker is perpetual but property 'Groups' to steal from is not specified!")
	end
	local entity_name = self:GetProperty("ToolEntity")
	local entity = g_Classes[entity_name]
	if entity and not IsKindOf(entity, "ComponentCustomData") then
		StoreWarningSource(self, string.format("AmbientLifeMarker has an attachable entity %s which does not inherit ComponentCustomData. Add ComponentCustomData as its parent class in the ArtSpecEditor.", entity_name))
	end
end

---
--- Performs various checks on the AmbientLifeMarker instance.
---
--- Checks if the marker's position is on an impassable surface, below the walkable Z height, and if the marker's properties are valid.
--- If the marker has a `VisitSupportCollectionVME` property and `IgnoreVisitSupportVME` is false, it also checks if the `VisitSupportCollection` is non-empty.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param pt table|nil The position to check. If nil, the position of the AmbientLifeMarker is used.
---
function AmbientLifeMarker:VME_Checks(pt)
	self:VME_CheckImpassable(pt)
	self:VME_CheckWalkableZ(pt)
	self:VME_CheckProperties()
	if self.VisitSupportCollectionVME and not self.IgnoreVisitSupportVME then
		if #(self.VisitSupportCollection or empty_table) == 0 then
			StoreErrorSource(self, "This marker needs non-empty Visit Support Set!")
		end
	end
end

---
--- Returns an error message if there are any issues with the AmbientLifeMarker instance.
---
--- If the marker is perpetual, it first gets the spawned unit. Then, it checks if the `ChanceSpawn` property is the same for all markers in the same collection. If not, it returns an error message indicating that all markers in the same collection should have the same `ChanceSpawn` value.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @return string|nil The error message, or nil if there are no errors.
---
function AmbientLifeMarker:GetError()	
	if self:IsPerpetual() then
		self:GetSpawnedUnit()
	end

	local collection_error
	local col_idx = self:GetRootColIndex()
	if col_idx ~= 0 then
		MapForEach("map", "collection", col_idx, true, "AmbientLifeMarker", function(other)
			if self.ChanceSpawn ~= other.ChanceSpawn then
				collection_error = "AL markers in the same collection should have the same ChanceSpawn!"
				return "break"
			end
		end)
	end

	if collection_error then
		return collection_error
	end
end

OnMsg.ValidateMap = ValidateGameObjectProperties("AmbientLifeMarker")

local function GetClosestVisitable(pos, ignore_reserved)
	local closest_visitable, closest_dist
	for _, visitable in ipairs(g_Visitables) do
		if ignore_reserved or not visitable.reserved then
			local dist = visitable[1]:GetDist(pos)
			if not closest_visitable or dist < closest_dist then
				closest_visitable, closest_dist = visitable, dist
			end
		end
	end
	if not closest_visitable then
		StoreErrorSource(pos, "DbgTestClosestALMarker: No visitable around! Try RebuildVisitables() from the console.")
	end
	
	return closest_visitable
end

---
--- Spawns a test unit at a random passable position around the AmbientLifeMarker and sets it to visit the closest visitable object.
---
--- This function is used for debugging purposes to test the behavior of the AmbientLifeMarker.
---
--- @param self AmbientLifeMarker The AmbientLifeMarker instance.
--- @param unit_pos point The position to spawn the test unit at. If not provided, a random passable position around the marker will be used.
--- @param closest_visitable table The closest visitable object to the marker. If not provided, the closest visitable object will be found.
---
function AmbientLifeMarker:DbgTest(unit_pos, closest_visitable)
	closest_visitable = closest_visitable or GetClosestVisitable(self:GetPos(), "ignore reserved")
	assert(closest_visitable[1] == self)
	
	if not unit_pos then
		local radius = 10 * guim
		for try = 1, 100 do
			local dist = radius / 2 + self:Random(radius / 2)
			unit_pos = GetPassSlab(self:GetPos() + Rotate(point(dist, 0), self:Random(360 * 60)))
			if unit_pos then
				break
			end
		end
		if not unit_pos then
			local cx, cy = self:GetPos():xy()
			for y = cy - radius, cy + radius, const.SlabSizeY do
				for x = cx - radius, cx + radius, const.SlabSizeX do
					unit_pos = GetPassSlab(point(x, y))
					if unit_pos then
						break
					end
				end
				if unit_pos then
					break
				end
			end
		end
		if not unit_pos then
			StoreErrorSource(self, "Can't find passable point around to test!")
			return
		end
	end
	
	NetSyncEvents.CheatEnable("FullVisibility", true)
	local unit_defs = Presets.UnitDataCompositeDef.Civilians
	if self.AttractGender ~= "Both" then
		unit_defs = table.ifilter(unit_defs, function(_, unit_def)
			return unit_def.gender == self.AttractGender
		end)
	end
	local unit_def = table.rand(unit_defs)
	local session_id = GenerateUniqueUnitDataId("AmbientLifeMarker:DbgTest", gv_CurrentSectorId or "A1", unit_def.id)
	local unit = SpawnUnit(unit_def.id, session_id, unit_pos)
	unit.visit_test = true
	CheckUniqueSessionId(unit)
	unit:SetSide("neutral")
	local visitor = HandleToObject[closest_visitable.reserved]
	if visitor then
		visitor:SetCommand(false)
	end
	closest_visitable.reserved = unit.handle
	unit:SetCommand("Visit", closest_visitable)
end

function OnMsg.ValidateMap()
	MapForEach("map", "AmbientLifeMarker", function(marker)
		marker:ValidateVisitSupportCollection()
		marker:VME_Checks()
	end)
	
	MapForEach("map", "AmbientZoneMarker", function(zone)
		zone:VME_Checks()
	end)
	
	RebuildVisitables()
	for _, visitable in ipairs(g_Visitables) do
		local marker = visitable[1]
		marker:VME_Checks(visitable[2])
	end
end

DefineClass.ChairSittable = {__parents = {"Object"}}

---
--- Rebuilds the list of visitable objects in the game world.
---
--- This function iterates over all `AmbientLifeMarker` objects in the specified bounding box (or the entire map if no bbox is provided),
--- and generates a list of visitable objects (`g_Visitables`) based on the markers. It ensures that each marker has a corresponding
--- visitable object in the list, and removes any visitable objects that no longer have a corresponding marker.
---
--- @param bbox table|nil The bounding box to search for markers, or nil to search the entire map.
---
function RebuildVisitables(bbox)
	if not bbox then
		local sizex, sizey = terrain.GetMapSize()
		bbox = box(0, 0, 0, sizex, sizey, 100000)
	end
	
	local used = {}
	for _, visitable in ipairs(g_Visitables) do
		local marker = visitable[1]
		used[marker.handle] = true
	end
	
	MapForEach(bbox, "AmbientLifeMarker", function(marker)
		local visitable = marker:GenerateVisitable()
		local marker = visitable[1]
		if not used[marker.handle] then
			table.insert(g_Visitables, visitable)
			used[marker.handle] = true
		end
	end)
end

---
--- Gets a random visitable object for the given marker, optionally filtering the results.
---
--- @param unit table The unit that is trying to find a visitable object.
--- @param marker table The marker that represents the visitable object.
--- @param filter function|nil An optional function to filter the visitable objects.
--- @param ... any Additional arguments to pass to the filter function.
--- @return table|nil The selected visitable object, or nil if no suitable visitable object was found.
--- @return number The total number of valid visitable objects found.
---
function GetRandomVisitableForMarker(unit, marker, filter, ...)
	if not IsValid(marker) or not g_Visitables or #g_Visitables == 0 then return end

	local area = marker:GetAreaBox()
	local CheckInside = area.Point2DInside
	local unit_zone = unit.zone
	local CheckZTolerance = unit_zone and unit_zone.CheckZTolerance
	local selected_visitable
	local total = 0
	for _, visitable in random_ipairs(g_Visitables, "AmbientLife") do
		local visit_marker, pt = visitable[1], visitable[2]
		local pos_or_marker = pt or visit_marker
		if not visitable.reserved
			and CheckInside(area, pos_or_marker)
			and (not filter or filter(unit, visitable, ...))
			and (not unit_zone or CheckZTolerance(unit_zone, pos_or_marker))
			and not IsInAmbientLifeRepulsionZone(pos_or_marker)
			and visit_marker:CanVisit(unit)
		then
			visit_marker:VME_CheckImpassable(pos_or_marker)
			total = total + 1
			if not selected_visitable then
				local pfflags = const.pfmDestlock + const.pfmImpassableSource
				local has_path, closest_pos = pf.HasPosPath(unit, pos_or_marker, nil, 0, 0, unit, 0, nil, pfflags)
				if has_path then
					if pt and closest_pos == pt or not pt and closest_pos:Equal(visit_marker:GetPosXYZ()) then
						selected_visitable = visitable
					end
				end
			end
		end
	end
	return selected_visitable, total
end


function OnMsg.PostNewMapLoaded()
	-- When in dev mode the rebuild is done in OnMsg.ValidateMap
	if not Platform.developer then
		RebuildVisitables()
	end
end

local function RebuildVisitablesResetUnitVisits(obj, bbox)
	RebuildVisitables(bbox)
	for _, unit in ipairs(g_Units) do
		if unit.behavior == "Visit" then
			local visitable = unit.behavior_params[1]
			local marker = visitable[1]
			if marker:IsInVisitSupportCollection(obj) then
				if not marker:IsVisitSupportCollectionAlive() then
					unit:ResetAmbientLife()
				end
			end
		end
	end
end

OnMsg.CombatObjectDied = RebuildVisitablesResetUnitVisits

DefineClass.AmbientSpawnDef = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "UnitDef", name = "Unit Definition", editor = "preset_id", default = false,
			preset_class = "UnitDataCompositeDef",
		},
		{ id = "Appearance", name = "Appearance", help = "Force the spawned unit to use this appearance instead of randomly choosing from its own list of appearances", 
			editor = "preset_id", default = false, preset_class = "AppearancePreset", },
		{ id = "Name", name = "Name", help = "Name for the spawned unit that will replace the one from template.", 
			editor = "text", default = false, translate = true, lines = 1, max_lines = 1, },
		{id = "Ephemeral", name = "Ephemeral", editor = "bool", default = true,
			help = "Permanent or Ephemeral",
		},
		{id = "CountMin", name = "Count Min", editor = "number", default = 5},
		{id = "CountMax", name = "Count Max", editor = "number", default = 20},
	},
	
	EditorView = Untranslated("<UnitDef> : <CountMin>-<CountMax>"),
}

--- Generates a unique session ID for an AmbientSpawnDef object.
---
--- The session ID is generated using the `GenerateUniqueUnitDataId` function, which takes the following parameters:
--- - "AmbientSpawnDef": The class name of the object
--- - `gv_CurrentSectorId` or "A1": The current sector ID, or "A1" if the sector ID is not available
--- - `self.UnitDef`: The unit definition associated with the AmbientSpawnDef object
---
--- @return string The generated session ID
function AmbientSpawnDef:GenSessionId()
	return GenerateUniqueUnitDataId("AmbientSpawnDef", gv_CurrentSectorId or "A1", self.UnitDef)
end

DefineClass.AmbientZoneMarker = {
	__parents = {"GridMarker", "GameDynamicDataObject", "EditorTextObject", "EditorMarker"},
	
	properties = {
		{category = "Ambient Zone", id = "ConflictIgnore",  name = "Conflict Ignore",
			editor = "bool", default = false,
			help = "Set this so units during conflict won't run, get reduced and won't repopulate the map when over"
		},
		{category = "Ambient Zone", id = "AreaWidth",  name = "Area Width", editor = "number",
			default = 20, help = "Defining a voxel-aligned rectangle with North-South and East-West axis"
		},
		{category = "Ambient Zone", id = "AreaHeight", name = "Area Height", editor = "number",
			default = 20, help = "Defining a voxel-aligned rectangle with North-South and East-West axis"
		},
		{category = "Ambient Zone", id = "AreaLevelZ", name = "Area Level Z", editor = "number",
			default = 0, help = "+/- that Z level of floors"
		},
		{category = "Ambient Zone", id = "MinRoamDist", name = "Minimum Roaming Distance",
			editor = "number", default = 4 * const.SlabSizeX, scale = const.SlabSizeX, 
			help = "Does not pick roaming markers closer than this. If negative const.AmbientLife.VisitIgnoreRange will not be checked!",
		},
		{category = "Ambient Zone", id = "SpawnDefs", name = "Spawn Definitions", editor = "nested_list",
			base_class = "AmbientSpawnDef", default = false
		},
		{ category = "Ambient Zone", id = "SpecificBanters", name = "SpecificBanters", help = "SpecificBanters to play when interacted with.", 
			editor = "preset_id_list", default = {}, preset_class = "BanterDef", item_default = "", },
		{category = "Ambient Zone", id = "BanterGroups", name = "BanterGroups", help = "Banters to play when interacted with.", 
			editor = "string_list", default = false,  items = PresetGroupsCombo("BanterDef"),
		},
		{category = "Ambient Zone", id = "ApproachBanters", name = "Approach Banters",
			help = "Approach Banters to play when interacted with.", 
			editor = "dropdownlist", default = false,  items = PresetGroupsCombo("BanterDef"),
		},
		{category = "Ambient Zone", id = "EnabledConditions", name = "Enabled Conditions", default = false, 
			editor = "nested_list", base_class = "Condition",
			help = "Conditions that enable or disable the marker",
		},
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "string", default = "AmbientZone", read_only = true },
		
	},
	
	editor_text_offset = point(0, 0, 250 * guic),
	editor_text_style = "AmbientLifeMarker",

	units = false,
	persist_units = true,
	area_outside_repulse = true,

	Random = AmbientLife_Random,
}

--- Saves the dynamic data of the AmbientZoneMarker, including the units currently present in the zone.
---
--- This function is called to serialize the state of the AmbientZoneMarker, so that it can be restored later.
--- It iterates through the `self.units` table, which contains the units currently present in the zone, and
--- stores their handles in the `data.units` table. This allows the marker to be restored with the same
--- units present when it was saved.
---
--- @param data table The table to store the dynamic data in.
function AmbientZoneMarker:GetDynamicData(data)
	if not self.persist_units or not self.units then return end
	
	data.units = {}
	for idx, units in ipairs(self.units) do
		local data_units = {}
		for k, unit in ipairs(units) do
			assert(IsKindOfClasses(unit, "Unit"))
			data_units[k] = unit.handle
		end
		data.units[idx] = data_units
	end
end

---
--- Restores the dynamic data of the AmbientZoneMarker, including the units currently present in the zone.
---
--- This function is called to deserialize the state of the AmbientZoneMarker, so that it can be restored to the same state as when it was saved.
--- It iterates through the `data.units` table, which contains the handles of the units that were present in the zone when it was saved,
--- and recreates those units in the zone. This allows the marker to be restored with the same units present when it was saved.
---
--- @param data table The table containing the dynamic data to restore.
---
function AmbientZoneMarker:SetDynamicData(data)
	if not self.persist_units or not data.units then return end
	
	self.units = {}
	for idx, units in ipairs(data.units) do
		local real_units = {}
		for _, unit_handle in ipairs(units) do
			if unit_handle then
				local unit = HandleToObject[unit_handle]
				if unit then
					if IsKindOfClasses(unit, "Unit") then
						table.insert(real_units, unit)
					end
				end
			end
		end
		self.units[idx] = real_units
	end
end

---
--- Checks if the AmbientZoneMarker is enabled and can spawn units.
---
--- @return boolean true if the marker is enabled and can spawn units, false otherwise
function AmbientZoneMarker:CanSpawn()
	return self:IsMarkerEnabled()
end

---
--- Generates a list of spawn definitions for the AmbientZoneMarker.
---
--- This function iterates through the `SpawnDefs` table of the AmbientZoneMarker and generates a list of spawn definitions. Each spawn definition includes the index of the definition in the `SpawnDefs` table, a reference to the AmbientZoneMarker instance, the count of units to spawn, and the unit definition to use.
---
--- If the game is in a conflict state, the count of units to spawn is reduced by the `const.AmbientLife.ConflictReduction` percentage.
---
--- @return table A list of spawn definitions, where each definition is a table with the following fields:
---   - `def_idx`: the index of the spawn definition in the `SpawnDefs` table
---   - `zone`: the AmbientZoneMarker instance
---   - `count`: the number of units to spawn
---   - `unit_def`: the unit definition to use for spawning
function AmbientZoneMarker:GetSpawnDefinitions()
	local spawn_defs = {}
	for idx, def in ipairs(self.SpawnDefs) do
		local count = def.CountMin + self:Random(def.CountMax - def.CountMin + 1)
		if GameState.Conflict or GameState.ConflictScripted then
			count = MulDivTrunc(count, const.AmbientLife.ConflictReduction, 100)
		end
		table.insert(spawn_defs, {def_idx = idx, zone = self, count = count, unit_def = def})
	end
	
	return spawn_defs
end

---
--- Gets a random valid unit from the list of units associated with this AmbientZoneMarker.
---
--- The function iterates through the list of units associated with the AmbientZoneMarker and returns the first valid unit it finds. A valid unit is one that is not defeated, is not a perpetual marker, and can be visited by the marker.
---
--- @param marker AmbientZoneMarker The marker to get a valid unit for.
--- @return Unit|nil The first valid unit found, or nil if no valid units are found.
function AmbientZoneMarker:GetUnitForMarker(marker)
	local units = {}
	for _, def_units in ipairs(self.units) do
		for _, unit in ipairs(def_units) do
			local not_defeated = IsValid(unit) and not unit:IsDead() and (IsKindOf(unit, "AmbientLifeAnimal") or not unit:IsDefeatedVillain())
			if not_defeated and not unit.perpetual_marker and marker:CanVisit(unit, "for perpetual") then
				table.insert(units, unit)
			end
		end
	end
	return (#units > 0) and units[1 + self:Random(#units)]
end

---
--- Initializes a unit associated with an AmbientZoneMarker.
---
--- This function sets various properties on the unit to configure it for use in an ambient zone. The unit is set to the "neutral" side, its routine is set to "Ambient", and it is associated with the AmbientZoneMarker instance that spawned it. The unit's approach banters are set based on the ApproachBanters property of the AmbientZoneMarker, and the unit is added to any groups defined for the AmbientZoneMarker. Finally, the unit's conflict_ignore property is set based on the ConflictIgnore property of the AmbientZoneMarker.
---
--- @param unit Unit The unit to initialize.
function AmbientZoneMarker:InitUnit(unit)
	unit:SetSide("neutral")
	unit.routine = "Ambient"
	unit.routine_spawner = self
	unit.approach_banters = table.keys2(Presets.BanterDef[self.ApproachBanters] or empty_table, "sorted")
	unit.approach_banters_distance = 8
	unit.approach_banters_cooldown_id = self.Groups and next(self.Groups) and self.Groups[1]
	for _, gr in ipairs(self.Groups) do
		table.insert_unique(unit.Groups, gr)
	end
	unit.conflict_ignore = self.ConflictIgnore
end

---
--- Places a spawned unit in the ambient zone.
---
--- This function spawns a unit in the ambient zone based on the provided unit definition and position. It sets various properties on the unit to configure it for use in the ambient zone, such as setting it to the "neutral" side, setting its routine to "Ambient", and associating it with the AmbientZoneMarker instance that spawned it. The function also applies any specified appearance and name to the unit, and if the game is in a conflict state, it will teleport the unit to a cowering position if the unit can cower.
---
--- @param unit_def UnitDef The unit definition to use for spawning the unit.
--- @param pos Point The position to spawn the unit at.
--- @return Unit The spawned unit.
function AmbientZoneMarker:PlaceSpawnDef(unit_def, pos)
	local unit = SpawnUnit(unit_def.UnitDef, unit_def:GenSessionId(), pos)
	unit.ephemeral = unit_def.Ephemeral
	CheckUniqueSessionId(unit)
	unit.zone = self
	self:InitUnit(unit)
	if unit_def.Name and unit_def.Name ~= "" then
		unit.Name = unit_def.Name
	end
	if unit_def.Appearance then
		unit:ApplyAppearance(unit_def.Appearance)
	end
	if GameState.Conflict or GameState.ConflictScripted then
		if unit:CanCower() then
			unit:TeleportToCower()
		end
	end
	unit.fx_actor_class = "AmbientUnit"
	
	return unit
end

function OnMsg.GetCustomFXInheritActorRules(rules)
	rules[#rules + 1] = "AmbientUnit"
	rules[#rules + 1] = "Unit"
end

local GetHeight = terrain.GetHeight
local insert = table.insert

---
--- Filters a list of positions to only include those within the specified Z-tolerance level of the AmbientZoneMarker.
---
--- @param positions table A list of packed positions to filter.
--- @return table A filtered list of packed positions that are within the Z-tolerance level.
function AmbientZoneMarker:FilterZTolerance(positions)
	if not self.AreaLevelZ then return positions end

	local mx, my, mz = self:GetPosXYZ()
	local level_z = mz or GetHeight(mx, my)
	local z_tolerance = self.AreaLevelZ * const.SlabSizeZ

	local filtered = {}
	for _, packed_pos in ipairs(positions) do
		local px, py, pz = point_unpack(packed_pos)
		if abs(level_z - (pz or GetHeight(px, py))) <= z_tolerance then
			insert(filtered, packed_pos)
		end
	end

	return filtered
end

---
--- Checks if a position or object is within the Z-tolerance level of the AmbientZoneMarker.
---
--- @param pos_or_obj table|Point A position or object to check the Z-tolerance for.
--- @return boolean True if the position or object is within the Z-tolerance level, false otherwise.
function AmbientZoneMarker:CheckZTolerance(pos_or_obj)
	if not self.AreaLevelZ then return true end

	local level_z = select(3, self:GetPosXYZ()) or GetHeight(self)
	local check_z
	if IsPoint(pos_or_obj) then
		check_z = pos_or_obj:z()
	else
		check_z = select(3, pos_or_obj:GetPosXYZ())
	end
	check_z = check_z or GetHeight(pos_or_obj)

	return abs(level_z - check_z) <= self.AreaLevelZ * const.SlabSizeZ
end

---
--- Spawns units defined in the AmbientZoneMarker's spawn definitions, and handles repopulation of the zone after conflicts.
---
--- @param refill boolean If true, the function will only spawn new units to fill up the zone, without despawning any existing units.
function AmbientZoneMarker:Spawn(refill)
	NetUpdateHash("AmbientZoneMarker:Spawn", self.handle)
	local spawn_defs = self:GetSpawnDefinitions()
	self.units = self.units or {}
	local to_enter_map = {}
	for _, def in ipairs(spawn_defs) do
		self.units[def.def_idx] = self.units[def.def_idx] or {}
		local spawned = self.units[def.def_idx]
		for idx = #spawned, 1, -1 do
			local unit = spawned[idx]
			if not IsValid(unit) or unit:IsDead() then
				table.remove(spawned, idx)
			end
		end
		while #spawned > def.count do
			-- despawn some units
			local idx = 1 + self:Random(#spawned)
			local unit = spawned[idx]
			table.remove(spawned, idx)
			unit:Despawn()
		end
		if #spawned < def.count then
			-- spawn some units to fill it up
			local area_positions = self:GetAreaPositions()
			local available_positions = self:FilterZTolerance(area_positions)
			local positions_required = Min(def.count - #spawned, #available_positions)
			local positions = self:GetRandomPositions(positions_required, nil, available_positions, nil, "avoid close pos")
			local spawn = not refill or self:IsKindOf("AmbientZone_Animal")
			for _, pos in ipairs(positions) do
				local unit = self:PlaceSpawnDef(def.unit_def, spawn and pos)
				insert(spawned, unit)
				if not spawn then
					insert(to_enter_map, {unit = unit, pos = pos})
				end
			end
		end
	end
	if #to_enter_map > 0 then
		table.shuffle(to_enter_map, self:Random(#to_enter_map))
		local refill = 100 - const.AmbientLife.ConflictReduction
		local wave1 = #to_enter_map * const.AmbientLife.ConflictAftermathRepopulateWave1 / refill
		local wave2 = #to_enter_map * const.AmbientLife.ConflictAftermathRepopulateWave2 / refill
		local wave_interval = const.AmbientLife.ConflictAftermathWavesInterval
		local wave_duration = const.AmbientLife.ConflictAftermathRepopulateWaveDuration
		local wait_time = wave_interval + self:Random(wave_duration)
		--printf("Repop %d/%d, Wave1: %d, Wave2: %d", #to_enter_map, #self.units, wave1, wave2)
		local wave = 1
		for idx, entry in ipairs(to_enter_map) do
			if idx > wave1 and wave < 2 then
				-- increase wait time for the 2nd wave
				wait_time = wait_time + wave_duration + wave_interval
				wave = 2
				--printf("wave 2 at %d/%d", idx, #to_enter_map)
			elseif idx > wave1 + wave2 and wave < 3 then
				-- increase wait time for the 3rd wave
				wait_time = wait_time + wave_duration + wave_interval
				wave = 3
				--printf("wave 3 at %d/%d", idx, #to_enter_map)
			end
			local unit_wait_time = wait_time + self:Random(wave_duration)
			entry.unit:SetCommand("EnterMap", self, entry.pos, unit_wait_time)
		end
	end
end

---
--- Despawns all units associated with this AmbientZoneMarker instance.
---
--- This function iterates through the `self.units` table, which contains a list of units
--- that were spawned by this AmbientZoneMarker. For each valid unit, it calls the `Despawn()`
--- method to remove the unit from the game world.
---
--- After all units have been despawned, the `self.units` table is set to `false`.
---
--- @function AmbientZoneMarker:Despawn
--- @return nil
function AmbientZoneMarker:Despawn()
	for idx, units_def in ipairs(self.units) do
		for _, unit in ipairs(units_def) do
			if IsValid(unit) then
				unit:Despawn()
			end
		end
	end
	self.units = false
end

---
--- Registers a list of units with the AmbientZoneMarker instance.
---
--- This function takes a table of units and appends them to the `self.units` table, which
--- is a list of all units associated with this AmbientZoneMarker instance.
---
--- @param units table A table of units to register with this AmbientZoneMarker.
--- @return nil
function AmbientZoneMarker:RegisterUnits(units)
	if self.units and #units > 0 then
		insert(self.units, units)
	end
end

---
--- Retrieves a list of all ExitZoneInteractable markers on the map, and determines which ones are reachable from the given position.
---
--- This function iterates through all ExitZoneInteractable markers on the map, and for each marker, it checks if there is a valid path from the given position to the marker's position. The markers that are reachable are added to the `markers_reachable` table.
---
--- @param pos table The position from which to check for reachable markers.
--- @return integer, table The total number of ExitZoneInteractable markers, and a table of the reachable markers.
function AmbientZoneMarker:GetExitZones(pos)
	local markers, markers_reachable = 0, {}
	local pfclass = CalcPFClass("player1")
	MapForEachMarker("ExitZoneInteractable", nil, function(marker)
		markers = markers + 1
		local check_pos = GetPassSlab(marker) or marker:GetPos()
		local pfflags = const.pfmImpassableSource
		local has_path, closest_pos = pf.HasPosPath(pos, check_pos, pfclass, 0, 0, nil, 0, nil, pfflags)
		if has_path and closest_pos == check_pos then
			insert(markers_reachable, marker)
		end
	end)
	return markers, markers_reachable
end

---
--- Retrieves the closest ExitZoneInteractable marker that is reachable from the given unit's position.
---
--- This function first retrieves a list of all ExitZoneInteractable markers on the map, and then determines which ones are reachable from the given unit's position. It then chooses the closest reachable marker and returns it.
---
--- If no reachable markers are found, the function will log an error message indicating that the ambient life zone is unreachable by any ExitZoneInteractable marker.
---
--- @param unit table The unit for which to find the closest reachable ExitZoneInteractable marker.
--- @return table|nil The closest reachable ExitZoneInteractable marker, or nil if no reachable markers are found.
function AmbientZoneMarker:GetEntranceMarker(unit)
	local obj = unit and (IsVisitingUnit(unit) and unit.last_visit or (unit:IsValidPos() and unit or nil)) or self
	local pass_slab = GetPassSlab(obj)
	local pos = pass_slab or obj:GetPos()
	local markers, markers_reachable = self:GetExitZones(pos)
	if #markers_reachable == 0 then
		local visitable = unit and unit.behavior == "Visit" and unit.behavior_params and unit.behavior_params[1]
		local AL_marker = visitable and visitable[1]
		local suppress_VMEs = IsKindOf(AL_marker, "AmbientLifeMarker") and AL_marker.Teleport
		if not suppress_VMEs then
			local info = (markers == 0) and "(No ExitZoneInteractable Markers)" or ""
			StoreErrorSource(self, string.format("AL zone unreachable by any ExitZoneInteractable marker%s", info))
			if unit then
				StoreErrorSource(unit, string.format("Unit can't reach AL zone from ExitZoneInteractable marker(%s)", info, GetMapName()))
			else
				StoreErrorSource(self, string.format("Test Dummy Unit can't reach AL zone from ExitZoneInteractable marker(%s)", info, GetMapName()))
			end
		end
	end
	local closest = ChooseClosestObject(markers_reachable, pos)
	return closest
end

---
--- Reduces the number of units in the ambient life zone by the specified percentage.
---
--- This function first collects all the valid units in the ambient life zone into a table. It then removes any units that are not valid, have the "EnterMap" command, or are not in a valid position. Finally, it randomly removes units from the table until the number of units is reduced by the specified percentage.
---
--- If the `exit_map` parameter is true, the function will set the command of the removed units to "ExitMap" and move them to the closest reachable `ExitZoneInteractable` marker. If the `exit_map` parameter is false, the function will simply despawn the removed units.
---
--- @param reduction_percents number The percentage of units to remove from the ambient life zone.
--- @param exit_map boolean If true, units will be moved to the closest reachable `ExitZoneInteractable` marker before being removed. If false, units will be despawned.
function AmbientZoneMarker:ReduceUnits(reduction_percents, exit_map)
	local units = {}
	for idx, units_def in ipairs(self.units) do
		for _, unit in ipairs(units_def) do
			if IsValid(unit) and not unit:IsDead() then
				insert(units, {unit = unit, idx = idx})
			end
		end
	end
	
	local count = reduction_percents * #units / 100
	for i = #units, 1, -1 do
		local entry = units[i]
		local unit = entry.unit
		local valid = IsValid(unit)
		if not valid or unit.command == "EnterMap" or not unit:IsValidPos() then
			if valid then
				unit:Despawn()
			end
			table.remove(units, i)
			table.remove_entry(self.units[entry.idx], unit)
		end
	end
	while #units > count do
		local k = 1 + InteractionRand(#units, "AmbientLifeReduction")
		local entry = units[k]
		local unit = entry.unit
		table.remove(units, k)
		table.remove_entry(self.units[entry.idx], unit)
		if exit_map then
			if unit.command ~= "Die" then
				local marker = self:GetEntranceMarker(unit)
				if marker then
					unit:SetCommand("ExitMap", marker)
					unit:SetCommandParamValue("ExitMap", "move_anim", "Run")
				else
					unit:Despawn()
				end
			end
		else
			if unit.command ~= "Die" and unit.command ~= "ExitMap" then
				unit:Despawn()
			end
		end
	end
end

---
--- Gets a list of roam markers within the area of this ambient zone marker.
---
--- @param unit table|nil The unit to check if it can visit the roam markers.
--- @return table The list of roam markers within the area.
function AmbientZoneMarker:GetRoamMarkers(unit)
	local roam_markers = {}
	local area = self:GetAreaBox()
	local CheckInside = area.Point2DInside
	for _, visitable in ipairs(g_Visitables) do
		local marker = visitable[1]
		local pos_or_marker = visitable[2] or marker
		if CheckInside(area, pos_or_marker) then
			if IsKindOf(marker, "AL_Roam") and not visitable.reserved and (not unit or marker:CanVisit(unit)) then
				if not IsInAmbientLifeRepulsionZone(pos_or_marker) then
					insert(roam_markers, visitable)
				end
			end
		end
	end
	return roam_markers
end

---
--- Gets the number of roam markers within the area of this ambient zone marker.
---
--- @return string A string representing the number of roam markers.
function AmbientZoneMarker:EditorGetText()
	local count = #(self:GetRoamMarkers() or empty_table)
	if count > 0 then
		return string.format("Roam Markers: %d", count)
	end
end

---
--- Returns the color to use for the editor text of this ambient zone marker.
---
--- @return table The color to use for the editor text.
function AmbientZoneMarker:EditorGetTextColor()
	return const.clrGreen
end

---
--- Updates the text display for this ambient zone marker.
---
--- @param marker_type_item table The marker type item associated with this ambient zone marker.
---
function AmbientZoneMarker:UpdateText(marker_type_item)
end

---
--- Recreates the text display for this ambient zone marker.
---
--- This function is called when the ambient zone marker is moved or rotated in the editor.
---
function AmbientZoneMarker:RecreateText()
	EditorTextObject.EditorTextUpdate(self, "recreate")
end

---
--- Callback function called when the ambient zone marker is moved in the editor.
---
--- This function updates the text display for the ambient zone marker after it has been moved.
---
function AmbientZoneMarker:EditorCallbackMove()
	GridMarker.EditorCallbackMove(self)
	self:RecreateText()
end

---
--- Callback function called when the ambient zone marker is rotated in the editor.
---
--- This function updates the text display for the ambient zone marker after it has been rotated.
---
function AmbientZoneMarker:EditorCallbackRotate()
	GridMarker.EditorCallbackRotate(self)
	self:RecreateText()
end

---
--- Checks the area positions of the ambient zone marker to ensure there are reachable exit zones.
---
--- This function iterates through the area positions of the ambient zone marker and checks that there are
--- reachable ExitZoneInteractable markers from each position. If no markers are found, or none are reachable,
--- an error is stored for that position.
---
--- @param positions table A table of packed position values representing the area positions of the ambient zone marker.
---
function AmbientZoneMarker:VME_CheckAreaPositionsExits(positions)
	for _, packed_pos in ipairs(positions) do
		local pos = point(point_unpack(packed_pos))
		local markers, markers_reachable = self:GetExitZones(pos)
		if markers == 0 then
			StoreErrorSource(pos, string.format("No ExitZoneInteractable markers to reach map exit from on Combat start!(%s)",GetMapName()), self)
			return
		end
		if #markers_reachable == 0 then
			StoreErrorSource(pos, string.format("No reachable ExitZoneInteractable markers from Area point on Combat start!(%s)", GetMapName()), self)
		end
	end
end

---
--- Checks the area positions of the ambient zone marker to ensure there are reachable exit zones.
---
--- This function iterates through the area positions of the ambient zone marker and checks that there are
--- reachable ExitZoneInteractable markers from each position. If no markers are found, or none are reachable,
--- an error is stored for that position.
---
--- @param positions table A table of packed position values representing the area positions of the ambient zone marker.
---
function AmbientZoneMarker:VME_Checks(check_unreachables)
	self:GetEntranceMarker()
	local positions = self:GetAreaPositions()
	if #positions == 0 then
		StoreErrorSource(self, "AmbientZoneMarker without valid area positions. Check Width and Height!")
	else
		if check_unreachables then
			self:VME_CheckAreaPositionsExits(positions)
		end
	end
end

OnMsg.ValidateMap = ValidateGameObjectProperties("AmbientZoneMarker")

DefineClass.PropertyHelper_AppearanceObjectAbsolutePos = {
	__parents = {"PropertyHelper_AbsolutePos", "AppearanceObject"}
}

---
--- Initializes the game state for the PropertyHelper_AppearanceObjectAbsolutePos object.
---
--- This function sets the animation pose of the object to match the parent object's visit pose,
--- and then faces the object towards the parent object.
---
function PropertyHelper_AppearanceObjectAbsolutePos:GameInit()
	self:SetAnimPose(self.parent:GetAnim(), self.parent.VisitPose)
	self:Face(self.parent)
	self.parent:Face(self)
end

---
--- Callback function for the PropertyHelper_AppearanceObjectAbsolutePos object when an editor action is performed.
---
--- This function first calls the EditorCallback function of the parent PropertyHelper_AbsolutePos object, then faces the object towards its parent object and faces the parent object towards the object.
---
--- @param self PropertyHelper_AppearanceObjectAbsolutePos The object instance.
--- @param action_id string The ID of the editor action that was performed.
---
function PropertyHelper_AppearanceObjectAbsolutePos:EditorCallback(action_id)
	PropertyHelper_AbsolutePos.EditorCallback(self, action_id)
	self:Face(self.parent)
	self.parent:Face(self)
end

local function GatherUnits()
	local neutral, neutral_dead, military_dead = {}, {}, {}
	for _, unit in ipairs(g_Units) do
		if not unit.team or unit.team.side == "neutral" then
			local behavior = g_Combat and unit.combat_behavior or unit.behavior
			if not unit.conflict_ignore then
				local dead = unit:IsDead() or unit.command == "Die"
				insert(dead and neutral_dead or neutral, unit)
			end
		else
			if unit:IsDead() or unit.command == "Die" then
				insert(military_dead, unit)
			end
		end
	end
	
	return neutral, neutral_dead, military_dead
end

---
--- Makes units cower in fear.
---
--- This function gathers all neutral units and checks if they are not already cowering or exiting the map. If the unit is visiting an AmbientLifeMarker, it stores the visit command and marker. Then, if the unit can cower, it sets the unit's command to "Cower" with the "find cower spot" parameter and sets the move animation to "Run".
---
--- @param command_required string The command that the unit must have in order to be made to cower.
---
function MakeCowards(command_required)
	local neutral = GatherUnits()
	NetUpdateHash("MakeCowards", #neutral)
	for _, unit in ipairs(neutral) do
		if unit.command == command_required or (unit.command ~= "Cower" and unit.command ~= "ExitMap") then
			if unit:IsVisiting() then
				local marker = unit.behavior_params[1]
				if marker and IsKindOf(marker[1], "AmbientLifeMarker") then
					unit.visit_command = unit.behavior
					unit.visit_marker = marker
				end
			end
			if unit:IsValidPos() then
				if unit:CanCower() then
					unit:SetCommand("Cower", "find cower spot")
					unit:SetCommandParamValue("Cower", "move_anim", "Run")
				end
				unit:UpdateMoveAnim()
			end
		end
	end
end

-- Unmake cowards
function OnMsg.GroupChangeSide(group, toSide, units)
	if toSide ~= "enemy1" and toSide ~= "enemy2" then return end
	for i, u in ipairs(units) do
		if u.combat_behavior == "Cower" then
			u:SetCombatBehavior()
			u:SetCommand("Idle")
		end
	end
end

function OnMsg.UnitSideChanged(unit, newTeam)
	local newSide = newTeam and newTeam.side
	if not newSide or (newSide ~= "enemy1" and newSide ~= "enemy2") then return end
	if unit.combat_behavior == "Cower" then
		unit:SetCombatBehavior()
		unit:SetCommand("Idle")
	end
end

---
--- Calms down units that are currently cowering.
---
--- This function iterates through all units and checks if they are currently in the "Cower" command. If so, it sets their behavior back to the default, and if they were visiting an AmbientLifeMarker, it restores their previous command and marker. If they were not visiting a marker, it sets their command to "Idle".
---
function CalmDownCowards()
	for _, unit in ipairs(g_Units) do
		if unit.command == "Cower" then
			unit:SetBehavior()
			if unit.visit_command then
				local command, marker = unit.visit_command, unit.visit_marker
				unit.visit_command, unit.visit_marker = false, false
				if marker and IsValid(marker[1]) then
					marker.reserved = unit.handle
					unit:SetCommand(command, marker)
				else
					unit:SetCommand("Idle")
				end
			else
				unit:SetCommand("Idle")
			end
		end
	end
end

MapVar("g_AmbientLifeSpawn", false)

---
--- Toggles the ambient life spawning on and off.
---
--- When called, this function will first clear any existing ambient life that has been spawned. It then toggles the `g_AmbientLifeSpawn` global variable, which controls whether ambient life should be spawned or not. If `g_AmbientLifeSpawn` is set to `true`, the function will send the "AmbientLifeSpawn" message, otherwise it will send the "AmbientLifeDespawn" message.
---
--- @function AmbientLifeToggle
--- @return nil
function AmbientLifeToggle()
	Msg("AmbientLifeDespawn")		-- clears if something is already spawned on first cheat use
	g_AmbientLifeSpawn = not g_AmbientLifeSpawn
	if g_AmbientLifeSpawn then
		Msg("AmbientLifeSpawn")
	else
		Msg("AmbientLifeDespawn")
	end
end

---
--- Steals ambient life spawns from available AmbientLifeMarkers.
---
--- This function first finds all AmbientLifeMarkers that are not currently occupied by a perpetual unit. It then shuffles the list of available markers and calls `SpawnCollection()` on each one to spawn a new ambient life unit.
---
--- @function AmbientLifePerpetualMarkersSteal
--- @return nil
function AmbientLifePerpetualMarkersSteal()
	local spawn_markers = {}
	MapForEach("map", "AmbientLifeMarker", function(marker)
		if not marker.perpetual_unit then
			marker.steal_activated = false
			if marker:IsCollectionLeader() and marker:CanSpawn() then
				insert(spawn_markers, marker)
			end
		end
	end)
	table.shuffle(spawn_markers, InteractionRand(nil, "AmbientLifeSpawn"))
	for _, marker in ipairs(spawn_markers) do
		marker:SpawnCollection()
	end
end

function OnMsg.AmbientLifeSpawn()
	FireNetSyncEventOnHostOnce("AmbientLifeSpawn")
end

---
--- Handles the spawning of ambient life units and zones when the "AmbientLifeSpawn" message is received.
---
--- This function first frees any perpetual units that are associated with disabled perpetual markers. It then suppresses team updates, spawns any ambient zones that can be spawned, and unsuppresses team updates. Finally, it calls the `AmbientLifePerpetualMarkersSteal()` function to spawn new ambient life units.
---
--- @function NetSyncEvents.AmbientLifeSpawn
--- @return nil
function NetSyncEvents.AmbientLifeSpawn()
	-- free perpetual units from disabled perpetual markers
	MapForEach("map", "AmbientLifeMarker", function(marker)
		if marker.perpetual_unit and not marker:CanSpawn() then
			marker.steal_activated = false
			marker.perpetual_unit.perpetual_marker = false
			marker.perpetual_unit = false
		end
	end)

	SuppressTeamUpdate = true
	MapForEach("map", "AmbientZoneMarker", function(zone)
		if zone:CanSpawn() then
			zone:Spawn()
		end
	end)
	SuppressTeamUpdate = false
	Msg("TeamsUpdated")
	AmbientLifePerpetualMarkersSteal()
	Msg("AmbientLifeSpawned")
end

function OnMsg.AmbientLifeDespawn()
	FireNetSyncEventOnHostOnce("AmbientLifeDespawn")
end

---
--- Handles the despawning of all ambient life units and zones when the "AmbientLifeDespawn" message is received.
---
--- This function iterates through all "AmbientLifeMarker" and "AmbientZoneMarker" objects on the map and calls their respective `Despawn()` functions to remove them from the game. Finally, it sends the "AmbientLifeDespawned" message to notify other systems.
---
--- @function NetSyncEvents.AmbientLifeDespawn
--- @return nil
function NetSyncEvents.AmbientLifeDespawn()
	MapForEach("map", "AmbientLifeMarker", function(marker)
		marker:Despawn()
	end)
	MapForEach("map", "AmbientZoneMarker", function(zone)
		zone:Despawn()
	end)
	Msg("AmbientLifeDespawned")
end

MapVar("s_SpawnALForbidden", false)

function OnMsg.NewGameSessionStart()
	s_SpawnALForbidden = true
end

function OnMsg.InitSessionCampaignObjects()
	s_SpawnALForbidden = false
end

local interestingStates = {
	RainHeavy = true,
	RainLight = true,
	Conflict = true,
	ConflictScripted = true,
	Combat = true,
}

function OnMsg.GameStateChanged(changed)
	if netInGame and IsChangingMap() then return end
	for k, v in sorted_pairs(changed) do
		if interestingStates[k] then
			FireNetSyncEventOnHostOnce("AmbientLifeOnGameStateChanged", changed)
			return
		end
	end
end

---
--- Kicks out all units from ambient zones that are not marked as "ConflictIgnore" and makes the remaining units cowards.
---
--- This function is called when the game state changes to "Conflict" or "ConflictScripted". It iterates through all "AmbientZoneMarker" objects on the map and reduces the number of units in each zone that is not marked as "ConflictIgnore". It then calls the "MakeCowards()" function to make the remaining units cowards.
---
--- @function KickOutUnits
--- @return nil
function KickOutUnits()
	MapForEach("map", "AmbientZoneMarker", function(zone)
		if not zone.ConflictIgnore then
			zone:ReduceUnits(const.AmbientLife.ConflictReduction, "exit map")
		end
	end)
	MakeCowards()
end

---
--- Handles changes to the game state and updates the ambient life accordingly.
---
--- This function is called when the game state changes, such as when it transitions to or from a conflict state, or when the weather changes. It performs various actions to update the ambient life on the map, such as:
---
--- - Resetting the move style of all units when the weather changes
--- - Kicking out units from ambient zones that are not marked as "ConflictIgnore" and making the remaining units cowards when a conflict state is entered
--- - Calming down cowards and respawning units in ambient zones when a conflict state is exited
--- - Despawning or setting idle command for neutral units when the combat state is entered
---
--- @param changed table The table of game state changes
--- @return nil
---
function NetSyncEvents.AmbientLifeOnGameStateChanged(changed)
	local didWork = false
	SuppressTeamUpdate = true
	if changed.RainHeavy or changed.RainLight then
		for _, unit in ipairs(g_Units) do
			unit:ResetMoveStyle()
		end
		didWork = true
	end
	
	if not ChangingMap and GetMapName() ~= "" then
		if changed.Conflict or changed.ConflictScripted then
			if not (g_Combat or g_StartingCombat) then
				KickOutUnits()
				didWork = true
			end
		elseif (changed.Conflict == false or changed.ConflictScripted == false) and not s_SpawnALForbidden then
			if not (GameState.Conflict or GameState.ConflictScripted) then
				CalmDownCowards()
				MapForEach("map", "AmbientZoneMarker", function(zone)
					if zone:CanSpawn() then
						if not (zone.ConflictIgnore or zone:IsKindOf("AmbientZone_Animal"))then
							zone:Spawn("refill")
						end
					end
				end)
				didWork = true
			end
		end
		if changed.Combat and not (GameState.Conflict or GameState.ConflictScripted) then
			-- straight to turn based mode
			local neutral = GatherUnits()
			for _, unit in ipairs(neutral) do
				local cmd = unit.command
				if cmd == "EnterMap" or not unit:IsValidPos() then
					unit:Despawn()
				elseif cmd ~= "Idle" and not unit:IsDead() and not unit:IsDefeatedVillain() then
					unit:SetCommand("Idle")
				end
			end
			didWork = true
		end
	end
	SuppressTeamUpdate = false
	if didWork then
		Msg("TeamsUpdated")
	end
end

function OnMsg.UnitAwarenessChanged(unit)
	if g_Combat then
		CreateGameTimeThread(MakeCowards, "Idle")
	end
end

---
--- Checks the visibility distance of units in the ambient life system.
--- This function is called when the exploration computed visibility changes.
--- It iterates through all units and checks if any units with the "Cower" command
--- are within a certain distance of a threat. If so, it sets the cower_from and
--- cower_angle properties on the unit.
---
--- @function AmbientLifeVisibilityDistanceCheck
--- @return nil
function AmbientLifeVisibilityDistanceCheck()
	for _, unit in ipairs(g_Units) do
		if unit.command == "Cower" and GameTime() > (unit.cower_cooldown or 0) then
			local visibility = g_Visibility[unit]
			for _, threat in ipairs(visibility) do
				if threat.team and threat.team.side ~= "neutral" then
					if unit:GetDist2D(threat) < const.AmbientLife.CowerRunDist then
						unit.cower_from, unit.cower_angle = threat:GetVisualPos(), threat:GetAngle()
						Msg(unit)
						break
					end
				end
			end
		end
	end
end

OnMsg.ExplorationComputedVisibility = AmbientLifeVisibilityDistanceCheck

local tff = table.findfirst

function OnMsg.EnterSector(_, load_game)
	local marker_units = {}
	local no_marker_kicks = {}
	for _, unit in ipairs(g_Units) do
		local visitable = unit.behavior == "Visit" and unit.behavior_params[1]
		if visitable then
			local marker = visitable[1]
			if marker then
				marker_units[marker] = marker_units[marker] or {}
				table.insert(marker_units[marker], unit)
			else
				unit:SetBehavior()
				unit:SetCommand(false)
				table.insert(no_marker_kicks, unit)
			end
		end
	end
	--print(string.format("Kicked-out units do to deleted marker: %d", #no_marker_kicks))
	
	local kicked = {}
	for marker, units in pairs(marker_units) do
		local unit = units[1]
		local marker = unit.behavior == "Visit" and unit.behavior_params[1] and unit.behavior_params[1][1]
		if #units > 1 then
			local idx = tff(units, function(_, u) return marker:CanVisit(u, "for perpetual") end) or 1
			unit = units[idx]
			table.remove(units, idx)
			local visitable = marker:GetVisitable()
			for _, u in ipairs(units) do
				if IsValid(u) and not u:IsDead() then
					u:FreeVisitable(visitable)
					u:SetBehavior()
					u:SetCommand(false)
					table.insert(kicked, u)
				end
			end
			unit:ReserveVisitable(visitable)
		end
	end
	--print(string.format("Kicked out pre-occupied AL marker units: %d", #kicked))
end

function OnMsg.SetpieceEnded(setpiece)
	local neutral = GatherUnits()
	for _, unit in ipairs(neutral) do
		if unit.command == "ExitMap" then
			unit:Despawn()
		elseif unit.command == "Cower" then
			unit:TeleportToCower()
		end
	end
end

---
--- Fixes up the `g_Visitables` table by removing any duplicate entries.
--- Duplicate entries are identified by checking the `marker` field of each `visitable` object.
--- The number of removed duplicates is printed to the console.
---
function SavegameSectorDataFixups.AmbientLifeVisitables()
	local used = {}
	local duplicates = 0
	for i = #g_Visitables, 1, -1 do
		local visitable = g_Visitables[i]
		local marker = visitable[1]
		if used[marker] then
			table.remove(g_Visitables, i)
			duplicates = duplicates + 1
		else
			used[marker] = true
		end
	end
	--print(string.format("Removed duplicated visitables: %d", duplicates))
end

---
--- Returns a list of all the unique group IDs that contain an `AmbientLifeMarker` object.
---
--- @return table<string> A table of group IDs that contain an `AmbientLifeMarker`.
---
function GetALMarkersGroups()
	local marker_groups = {}
	for id, group in sorted_pairs(Groups) do
		for _, o in ipairs(group) do
			if IsKindOf(o, "AmbientLifeMarker") then
				marker_groups[#marker_groups + 1] = id
				break
			end
		end
	end
	
	return marker_groups
end

---
--- Checks if the given `unit` is currently visiting a specific type of visitable object.
---
--- @param unit Unit The unit to check.
--- @param AL_class string (optional) The class name of the visitable object to check for.
--- @return boolean True if the unit is visiting the specified visitable object, false otherwise.
---
function IsVisitingUnit(unit, AL_class)
	return IsKindOf(unit, "Unit") and unit.behavior == "Visit" and (not AL_class or IsKindOf(unit.last_visit, AL_class))
end

---
--- Checks if the given `unit` is currently visiting a specific type of visitable object, in this case an `AL_SitChair`.
---
--- @param unit Unit The unit to check.
--- @return boolean True if the unit is visiting an `AL_SitChair` and has reached the visit location, false otherwise.
---
function IsSittingUnit(unit)
	return IsVisitingUnit(unit, "AL_SitChair") and unit.visit_reached
end

---
--- Checks if the given `unit` is currently visiting a specific type of visitable object, in this case an `AL_WallLean`.
---
--- @param unit Unit The unit to check.
--- @return boolean True if the unit is visiting an `AL_WallLean` and has reached the visit location, false otherwise.
---
function IsWallLeaningUnit(unit)
	return IsVisitingUnit(unit, "AL_WallLean") and unit.visit_reached
end

---
--- Returns a list of all the unique group IDs that contain an `AmbientLifeMarker` object.
---
--- @return table<string> A table of group IDs that contain an `AmbientLifeMarker`.
---
function GetALMarkerGroups()
	local groups = {}
	MapForEach("map", "AmbientLifeMarker", function(marker)
		if not IsKindOf(marker, "AmbientLifeMarker") then return end
		
		for _, group in ipairs(marker.Groups) do
			if not groups[group] then
				groups[group] = true
				table.insert(groups, group)
			end
		end
	end)
	
	return groups
end

---
--- Finds and tests the closest `AmbientLifeMarker` object to the terrain cursor position.
---
--- If the terrain cursor is on a passable terrain, this function will find the closest `AmbientLifeMarker` object and call its `DbgTest` method, passing the cursor position and the marker object as arguments.
---
--- If no `AmbientLifeMarker` object is found nearby, a message is printed to the console.
---
function DbgTestClosestALMarker()
	local pos = GetPassSlab(GetTerrainCursor())
	if not pos then
		StoreErrorSource(GetTerrainCursor(), "DbgTestClosestALMarker: Mouse cursor should be on passable!")
	end
	
	local closest_visitable = GetClosestVisitable(pos)
	if closest_visitable then
		closest_visitable[1]:DbgTest(pos, closest_visitable)
	else
		print("No AL marker found nearby")
	end
end

local function RegAppearanceEntities(preset, entities)
	local appearance = FindPreset("AppearancePreset", preset)
	if appearance then
		AppearanceMarkEntities(appearance, entities)
	end
end

function OnMsg.GatherMapEntities(entities, objs)
	for _, obj in ipairs(objs) do
		if IsKindOfClasses(obj, "UnitMarker", "DummyUnit", "CheeringDummy") then
			RegAppearanceEntities(obj.Appearance, entities)
		elseif IsKindOf(obj, "AmbientZoneMarker") then
			for _, def in ipairs(obj.SpawnDefs) do
				if def.Appearance then
					RegAppearanceEntities(obj.Appearance, entities)
				else
					for _, group in ipairs(Presets.UnitDataCompositeDef) do
						local unit_def = table.find_value(group, "id", def.UnitDef)
						if unit_def then
							local list = unit_def.AppearancesList or empty_table
							for _, ap_weight in ipairs(list) do
								RegAppearanceEntities(ap_weight.Preset, entities)
							end
							break
						end
					end
				end
			end
		elseif IsKindOf(obj, "AmbientLifeMarker") then
			entities[obj.ToolEntity] = true
			if obj.Weapon and obj.Weapon ~= "" then
				local preset = FindPreset("InventoryItemCompositeDef", obj.Weapon)
				assert(preset)
				GatherWeaponPresetEntities(preset, entities)
			end
		end
	end
end