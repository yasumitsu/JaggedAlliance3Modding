DefineClass.FXObject = {
	fx_action = false,
	fx_action_base = false,
	fx_actor_class = false,
	fx_actor_base_class = false,
	play_size_fx = true,
}
--- Returns the FXObject actor.
---
--- This function returns the FXObject instance itself, as the FXObject is the actor.
---
--- @return FXObject The FXObject actor.
function FXObject:GetFXObjectActor()
	return self
end

if FirstLoad then
	s_EntitySizeCache = {}
	s_EntityFXTargetCache = {}
	s_EntityFXTargetSecondaryCache = {}
end

local function no_obj_no_edit(self)
	return self.Source ~= "Actor" and self.Source ~= "Target"
end

function OnMsg.EntitiesLoaded()
	local ae = GetAllEntities()
	for entity in pairs(ae) do
		local bbox = GetEntityBBox(entity)
		local x, y, z = bbox:sizexyz()
		local volume = x * y * z
		if volume <= const.EntityVolumeSmall then
			s_EntitySizeCache[entity] = "Small"
		elseif volume <= const.EntityVolumeMedium then
			s_EntitySizeCache[entity] = "Medium"
		else
			s_EntitySizeCache[entity] = "Large"
		end
	end
end

---
--- Plays destruction FX for the FXObject.
---
--- This function plays various FX effects when an FXObject is destroyed. It determines the appropriate FX targets based on the object's material, and plays the "Death" FX with the "start" moment for the main and secondary FX targets. If the `play_size_fx` flag is set, it also plays additional FX based on the size of the entity associated with the FXObject.
---
--- @param self FXObject The FXObject instance.
function FXObject:PlayDestructionFX()
	local fx_target, fx_target_secondary = GetObjMaterialFXTarget(self)
	local fx_type, fx_pos, _, fx_type_secondary = GetObjMaterial(false, self, fx_target, fx_target_secondary)
	PlayFX("Death", "start", self, fx_type, fx_pos)
	if fx_type_secondary then
		PlayFX("Death", "start", self, fx_type_secondary)
	end
	if self.play_size_fx then
		local entity = self:GetEntity()
		local fx_target_size = s_EntityFXTargetCache[entity]
		if not fx_target_size then
			fx_target_size = string.format("%s:%s", fx_target or "", s_EntitySizeCache[entity] or "")
			s_EntityFXTargetCache[entity] = fx_target_size
		end
		local bbox_center = self:GetPos() + self:GetEntityBBox():Center()
		PlayFX("Death", "start", self, fx_target_size, bbox_center)
		if fx_target_secondary then
			local fx_target_secondary_size = s_EntityFXTargetSecondaryCache[entity]
			if not fx_target_secondary_size then
				fx_target_secondary_size = string.format("%s:%s", fx_target_secondary or "", s_EntitySizeCache[entity] or "")
				s_EntityFXTargetSecondaryCache[entity] = fx_target_secondary_size
			end
			PlayFX("Death", "start", self, fx_target_secondary_size, bbox_center)
		end
	end
end

if FirstLoad then
	FXEnabled = true
	DisableSoundFX = false
	DebugFX = false
	DebugFXAction = false
	DebugFXMoment = false
	DebugFXActor = false
	DebugFXTarget = false
	DebugFXSound = false
	DebugFXParticles = false
	DebugFXParticlesName = false
end

local function DebugMatch(str, to_match)
	return type(to_match) ~= "string" or type(str) == "string" and string.match(string.lower(str), string.lower(to_match))
end

local function DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass)
	local actor_text = actorFXClass or ""
	if type(actor_text) ~= "string" then
		actor_text = FXInheritRules_Actors[actor_text] and table.concat(FXInheritRules_Actors[actor_text], "/") or ""
	end
	if DebugMatch(actor_text, DebugFX) or DebugFX == "UI" then
		local target_text = targetFXClass or ""
		if type(target_text) ~= "string" then
			target_text = FXInheritRules_Actors[target_text] and table.concat(FXInheritRules_Actors[target_text], "/") or ""
		end
		local str = "PlayFX %s<tab 450>%s<tab 600>%s<tab 900>%s"
		printf(str, actionFXClass, actionFXMoment or "", actor_text, target_text)
	end
end

local function DebugMatchUIActor(actor)
	if DebugFX ~= "UI" then return true end
	return IsKindOf(actor, "XWindow")
end

--[[@@@
Triggers a global event that activates various game effects. These effects are specified by FX presets. All FX presets that match the combo **action - moment - actor - target** will be activated.
Normally the FX-s are one-time events, but they can also be continuous effects. To stop continuous FX, another PlayFX call is made, with different *moment*. The ending moment is specified in the FX preset, with "end" as default.
@function void PlayFX(string action, string moment, object actor, object target, point pos, point dir)
@param string action - The name of the FX action.
@param string moment - The action's moment. Normally an FX has a *start* and an *end*, but may have various moments in-between.
@param object actor - Used to give context to the FX. Can be a string or an object. If object is provided, then it's member *fx_actor_class* is used, or its class if no such member is available. The object can be used for many purposes by the FX (e.g. attaching effects to it)
@param object target - Similar to the **actor** argument. Used to give additional context to the FX.
@param point pos - Optional FX position. Normally the position of the FX is determined by rules in the FX preset, based on the actor or the target.
@param point dir - Optional FX direction. Normally the direction of the FX is determined by rules in the FX preset, based on the actor or the target.
--]]

---
--- Triggers a global event that activates various game effects. These effects are specified by FX presets. All FX presets that match the combo **action - moment - actor - target** will be activated.
--- Normally the FX-s are one-time events, but they can also be continuous effects. To stop continuous FX, another PlayFX call is made, with different *moment*. The ending moment is specified in the FX preset, with "end" as default.
---
--- @param actionFXClass string The name of the FX action.
--- @param actionFXMoment string The action's moment. Normally an FX has a *start* and an *end*, but may have various moments in-between.
--- @param actor object Used to give context to the FX. Can be a string or an object. If object is provided, then it's member *fx_actor_class* is used, or its class if no such member is available. The object can be used for many purposes by the FX (e.g. attaching effects to it)
--- @param target object Similar to the **actor** argument. Used to give additional context to the FX.
--- @param action_pos point Optional FX position. Normally the position of the FX is determined by rules in the FX preset, based on the actor or the target.
--- @param action_dir point Optional FX direction. Normally the direction of the FX is determined by rules in the FX preset, based on the actor or the target.
--- @return boolean Whether any FX was played
function PlayFX(actionFXClass, actionFXMoment, actor, target, action_pos, action_dir)
	if not FXEnabled then return end

	actionFXMoment = actionFXMoment or false
	local actor_obj = actor and IsKindOf(actor, "FXObject") and actor
	local target_obj = target and IsKindOf(target, "FXObject") and target

	local actorFXClass = actor_obj and (actor_obj.fx_actor_class or actor_obj.class) or actor or false
	local targetFXClass = target_obj and (target_obj.fx_actor_class or target_obj.class) or target or false

	dbg(DebugFX
		and DebugMatch(actionFXClass, DebugFXAction)
		and DebugMatch(actionFXMoment, DebugFXMoment)
		and DebugMatch(actorFXClass, DebugFXActor)
		and DebugMatch(targetFXClass, DebugFXTarget)
		and DebugMatchUIActor(actor_obj)
		and DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass))

	local fxlist
	local t
	local t1 = FXCache
	if t1 then
		t = t1[actionFXClass]
		if t then
			t1 = t[actionFXMoment]
			if t1 then
				t = t1[actorFXClass]
				if t then
					fxlist = t[targetFXClass]
				else
					t = {}
					t1[actorFXClass] = t
				end
			else
				t1, t = t, {}
				t1[actionFXMoment] = { [actorFXClass] = t }
			end
		else
			t = {}
			t1[actionFXClass] = { [actionFXMoment] = { [actorFXClass] = t } }
		end
	else
		t = {}
		FXCache = { [actionFXClass] = { [actionFXMoment] = { [actorFXClass] = t } } }
	end
	if fxlist == nil then
		fxlist = GetPlayFXList(actionFXClass, actionFXMoment, actorFXClass, targetFXClass)
		t[targetFXClass] = fxlist or false
	end

	local playedAnything = false
	if fxlist then
		actor_obj = actor_obj and actor_obj:GetFXObjectActor() or actor_obj
		target_obj = target_obj and target_obj:GetFXObjectActor() or target_obj
		for i = 1, #fxlist do
			local fx = fxlist[i]
			local chance = fx.Chance
			if chance >= 100 or AsyncRand(100) < chance then
				dbg(fx.DbgPrint and DebugFXPrint(actionFXClass, actionFXMoment, actorFXClass, targetFXClass))
				dbg(fx.DbgBreak and bp())
				fx:PlayFX(actor_obj, target_obj, action_pos, action_dir)
				playedAnything = true
			end
		end
	end
	
	return playedAnything
end

if FirstLoad or ReloadForDlc then
	FXLists = {}
	FXRules = {}
	FXInheritRules_Actions = false
	FXInheritRules_Moments = false
	FXInheritRules_Actors = false
	FXInheritRules_Maps = false
	FXInheritRules_DynamicActors = setmetatable({}, weak_keys_meta)
	FXCache = false
end

---
--- Adds an ActionFX object to the FXRules table, organizing it by action, moment, actor, and target.
--- This function is used to rebuild the FXRules table when the FX system is reloaded or updated.
---
--- @param fx ActionFX The ActionFX object to add to the rules.
---
function AddInRules(fx)
	local action = fx.Action
	local moment = fx.Moment
	local actor = fx.Actor
	local target = fx.Target
	if target == "ignore" then target = "any" end
	local rules = FXRules
	rules[action] = rules[action] or {}
	rules = rules[action]
	rules[moment] = rules[moment] or {}
	rules = rules[moment]
	rules[actor] = rules[actor] or {}
	rules = rules[actor]
	rules[target] = rules[target] or {}
	rules = rules[target]
	table.insert(rules, fx)
	FXCache = false
end

---
--- Removes an ActionFX object from the FXRules table.
---
--- This function is used to remove an ActionFX object from the FXRules table when the FX system is reloaded or updated.
---
--- @param fx ActionFX The ActionFX object to remove from the rules.
---
function RemoveFromRules(fx)
	local rules = FXRules
	rules = rules[fx.Action]
	rules = rules and rules[fx.Moment]
	rules = rules and rules[fx.Actor]
	rules = rules and rules[fx.Target == "ignore" and "any" or fx.Target]
	if rules then
		table.remove_value(rules, fx)
	end
	FXCache = false
end

---
--- Rebuilds the FXRules table by iterating through all FXObject classes and adding their ActionFX objects to the rules.
--- This function is called when the FX system is reloaded or updated.
---
--- The function performs the following steps:
--- 1. Clears the FXRules table and sets FXCache to false.
--- 2. Calls RebuildFXInheritActionRules(), RebuildFXInheritMomentRules(), and RebuildFXInheritActorRules() to rebuild the inheritance rules.
--- 3. Iterates through all FXLists, which contain ActionFX objects.
--- 4. For each ActionFX object, it removes the object from the existing rules and then adds it back to the rules.
---
--- This ensures that the FXRules table is up-to-date with all the ActionFX objects in the system.
---
--- @function RebuildFXRules
function RebuildFXRules()
	FXRules = {}
	FXCache = false
	RebuildFXInheritActionRules()
	RebuildFXInheritMomentRules()
	RebuildFXInheritActorRules()
	for classname, fxlist in sorted_pairs(FXLists) do
		if g_Classes[classname]:IsKindOf("ActionFX") then
			for i = 1, #fxlist do
				fxlist[i]:RemoveFromRules()
				fxlist[i]:AddInRules()
			end
		end
	end
end

local function AddFXInheritRule(key, inherit, rules, added)
	if not key or key == "" or key == "any" or key == inherit then
		return
	end
	local list = rules[key]
	if not list then
		rules[key] = { inherit }
		added[key] = { [inherit] = true }
	else
		local t = added[key]
		if not t[inherit] then
			list[#list+1] = inherit
			t[inherit] = true
		end
	end
end

local function LinkFXInheritRules(rules, added)
	for key, list in pairs(rules) do
		local added = added[key]
		local i, count = 1, #list
		while i <= count do
			local inherit_list = rules[list[i]]
			if inherit_list then
				for i = 1, #inherit_list do
					local inherit = inherit_list[i]
					if not added[inherit] then
						count = count + 1
						list[count] = inherit
						added[inherit] = true
					end
				end
			end
			i = i + 1
		end
	end
end

---
--- Rebuilds the FX inherit rules for actions.
---
--- This function is responsible for rebuilding the FX inherit rules for actions. It does this by:
--- - Iterating through all FXObject-derived classes and adding inherit rules based on the `fx_action_base` and `fx_action` properties.
--- - Iterating through the `Presets.AnimMetadata` table and adding inherit rules based on the `FXInherits` property of each animation metadata.
--- - Adding any custom inherit rules from the `FXLists.ActionFXInherit_Action` table.
--- - Linking the inherit rules together using the `LinkFXInheritRules` function.
---
--- @return table The rebuilt FX inherit rules for actions.
function RebuildFXInheritActionRules()
	PauseInfiniteLoopDetection("RebuildFXInheritActionRules")
	local rules, added = {}, {}
	FXInheritRules_Actions = rules
	ClassDescendants("FXObject", function(classname, class)
		local key = class.fx_action_base
		if key then
			local name = class.fx_action or classname
			if name ~= key then
				AddFXInheritRule(name, key, rules, added)
			end
			local parents = key ~= "" and key ~= "any"  and class.__parents
			if parents then
				for i = 1, #parents do
					local parent_class = g_Classes[parents[i]]
					local inherit = IsKindOf(parent_class, "FXObject") and parent_class.fx_action_base
					if inherit and key ~= inherit then
						AddFXInheritRule(key, inherit, rules, added)
					end
				end
			end
		end
	end)
	
	local anim_metadatas = Presets.AnimMetadata
	for _, group in ipairs(anim_metadatas) do
		for _, anim_metadata in ipairs(group) do
			local key = anim_metadata.id
			local fx_inherits = anim_metadata.FXInherits
			for _, fx_inherit in ipairs(fx_inherits) do
				AddFXInheritRule(key, fx_inherit, rules, added)
			end
		end
	end
	
	local fxlist = FXLists.ActionFXInherit_Action
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Action, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	ResumeInfiniteLoopDetection("RebuildFXInheritActionRules")
	return rules
end

--- Rebuilds the FX inherit rules for action moments.
---
--- @return table The rebuilt FX inherit rules for action moments.
function RebuildFXInheritMomentRules()
	local rules, added = {}, {}
	FXInheritRules_Moments = rules
	local fxlist = FXLists.ActionFXInherit_Moment
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Moment, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	return rules
end

--- Rebuilds the FX inherit rules for actor classes.
---
--- This function rebuilds the FX inherit rules for actor classes. It iterates through all FXObject-derived classes and adds inheritance rules based on the `fx_actor_base_class` property of each class. It also handles custom inherit rules and rules defined in the `FXLists.ActionFXInherit_Actor` table.
---
--- @return table The rebuilt FX inherit rules for actor classes.
function RebuildFXInheritActorRules()
	PauseInfiniteLoopDetection("RebuildFXInheritActorRules")
	local rules, added = setmetatable({}, weak_keys_meta), {}
	FXInheritRules_Actors = rules
	-- class inherited
	ClassDescendants("FXObject", function(classname, class)
		local key = class.fx_actor_base_class
		if key then
			local name = class.fx_actor_class or classname
			if name and name ~= key then
				AddFXInheritRule(name, key, rules, added)
			end
			local parents = key and key ~= "" and key ~= "any" and class.__parents
			if parents then
				for i = 1, #parents do
					local parent_class = g_Classes[parents[i]]
					local inherit = IsKindOf(parent_class, "FXObject") and parent_class.fx_actor_base_class
					if inherit and key ~= inherit then
						AddFXInheritRule(key, inherit, rules, added)
					end
				end
			end
		end
	end)
	local custom_inherit = {}
	Msg("GetCustomFXInheritActorRules", custom_inherit)
	for i = 1, #custom_inherit, 2 do
		local key = custom_inherit[i]
		local inherit = custom_inherit[i+1]
		if key and inherit and key ~= inherit then
			AddFXInheritRule(key, inherit, rules, added)
		end
	end
	local fxlist = FXLists.ActionFXInherit_Actor
	if fxlist then
		for i = 1, #fxlist do
			local fx = fxlist[i]
			AddFXInheritRule(fx.Actor, fx.Inherit, rules, added)
		end
	end
	LinkFXInheritRules(rules, added)
	for obj, list in pairs(FXInheritRules_DynamicActors) do
		FXInheritRules_Actors[obj] = list
	end
	ResumeInfiniteLoopDetection("RebuildFXInheritActorRules")
	return rules
end

---
--- Adds a dynamic actor to the FX inherit rules.
---
--- @param obj table The object to add the dynamic actor to.
--- @param actor_class string The actor class to add.
function AddFXDynamicActor(obj, actor_class)
	if not actor_class or actor_class == "" then return end
	local list = FXInheritRules_DynamicActors[obj]
	if not list then
		local def_actor_class = obj.fx_actor_class or obj.class
		local def_inherit = (FXInheritRules_Actors or RebuildFXInheritActorRules() )[def_actor_class]
		list = { def_actor_class }
		table.iappend(list, def_inherit)
		if not table.find(list, actor_class) then
			table.insert(list, actor_class)
			local actor_class_inherit = FXInheritRules_Actors[actor_class]
			if actor_class_inherit then
				for i = 1, #actor_class_inherit do
					local actor = actor_class_inherit[i]
					if not table.find(list, actor) then
						table.insert(list, actor)
					end
				end
			end
		end
		FXInheritRules_DynamicActors[obj] = list
		if FXInheritRules_Actors then
			FXInheritRules_Actors[obj] = list
		end
		obj.fx_actor_class = obj
	elseif not table.find(list, actor_class) then
		table.insert(list, actor_class)
	end
end

---
--- Removes a dynamic actor from the FX inherit rules.
---
--- @param obj table The object to remove the dynamic actor from.
function ClearFXDynamicActor(obj)
	FXInheritRules_DynamicActors[obj] = nil
	if FXInheritRules_Actors then
		FXInheritRules_Actors[obj] = nil
	end
	obj.fx_actor_class = nil
end

function OnMsg.PostDoneMap()
	FXInheritRules_DynamicActors = setmetatable({}, weak_keys_meta)
	FXCache = false
end

function OnMsg.DataLoaded()
	RebuildFXRules()
end

if not FirstLoad and not ReloadForDlc then
	function OnMsg.ClassesBuilt()
		RebuildFXInheritActionRules()
		RebuildFXInheritActorRules()
	end
end

local HookActionFXCombo
local HookMomentFXCombo
local ActionFXBehaviorCombo
local ActionFXSpotCombo
local ActionFXAnimatedComboDecal = { "Normal", "PingPong" }

--============================= FX Orient =======================

local OrientationAxisCombo = {
	{ text = "X", value = 1 },
	{ text = "Y", value = 2 },
	{ text = "Z", value = 3 },
	{ text = "-X", value = -1 },
	{ text = "-Y", value = -2 },
	{ text = "-Z", value = -3 },
}
local OrientationAxes = { axis_x, axis_y, axis_z, [-1] = -axis_x, [-2] = -axis_y, [-3] = -axis_z }

local FXOrientationFunctions = {}

---
--- Orients the FX to the X axis of the source object.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @return vector The oriented vector.
function FXOrientationFunctions.SourceAxisX(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 1)
	end
end

---
--- Orients the FX to the X axis of the source object in 2D.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @return vector The oriented vector.
function FXOrientationFunctions.SourceAxisX2D(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, source_obj, 1)
	end
end

---
--- Orients the FX to the Y axis of the source object.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @return vector The oriented vector.
function FXOrientationFunctions.SourceAxisY(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 2)
	end
end

---
--- Orients the FX to the Z axis of the source object.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @return vector The oriented vector.
function FXOrientationFunctions.SourceAxisZ(orientation_axis, source_obj)
	if IsValid(source_obj) then
		return OrientAxisToObjAxisXYZ(orientation_axis, source_obj, 3)
	end
end

---
--- Orients the FX to the action direction, or to the actor's orientation if the action direction is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.ActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the action direction, or to the actor's orientation if the action direction is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.ActionDir2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, x, y, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the target object, or to the action direction if the target is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceTarget(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(target) and target:IsValidPos() then
		local tx, ty, tz = target:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty or posz ~= tz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, tz - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the target object, or to the action direction if the target is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceTarget2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(target) and target:IsValidPos() then
		local tx, ty = target:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, x, y, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the actor object, or to the action direction if the actor is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceActor(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(actor) and actor:IsValidPos() then
		local tx, ty, tz = actor:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty or posz ~= tz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, tz - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the actor object, or to the action direction if the actor is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceActor2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and IsValid(actor) and actor:IsValidPos() then
		local tx, ty = actor:GetSpotLocPosXYZ(-1)
		if posx ~= tx or posy ~= ty then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local x, y = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, posx, posy, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the action position, or to the action direction if the action position is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceActionPos(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and action_pos and action_pos:IsValid() then
		local tx, ty, tz = action_pos:xyz()
		if tx ~= posx or ty ~= posy or (tz or posz) ~= posz then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, (tz or posz) - posz)
		end
	end
	if action_dir and action_dir ~= point30 then
		return OrientAxisToVectorXYZ(orientation_axis, action_dir)
	elseif IsValid(actor) then
		return OrientAxisToObjAxisXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Orients the FX to the action position, or to the action direction if the action position is not provided.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX to.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to use.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return vector The oriented vector.
function FXOrientationFunctions.FaceActionPos2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if posx and action_pos and action_pos:IsValid() then
		local tx, ty = action_pos:xy()
		if tx ~= posx or ty ~= posy then
			return OrientAxisToVectorXYZ(orientation_axis, tx - posx, ty - posy, 0)
		end
	end
	if action_dir and not action_dir:Equal2D(point20) then
		local tx, ty = action_dir:xy()
		return OrientAxisToVectorXYZ(orientation_axis, tx, ty, 0)
	elseif IsValid(actor) then
		return OrientAxisToObjAxis2DXYZ(orientation_axis, actor:GetParent() or actor, 1)
	end
end

---
--- Generates a random 2D orientation vector.
---
--- @param orientation_axis number The orientation axis to use.
--- @return vector The randomly oriented vector.
function FXOrientationFunctions.Random2D(orientation_axis)
	return OrientAxisToVectorXYZ(orientation_axis, Rotate(axis_x, AsyncRand(360*60)))
end

---
--- Orients the FX to the X axis.
---
--- @param orientation_axis number The orientation axis to use.
--- @return vector The oriented vector.
function FXOrientationFunctions.SpotX(orientation_axis)
	if orientation_axis == 1 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_x)
end

---
--- Orients the FX to the Y axis.
---
--- @param orientation_axis number The orientation axis to use.
--- @return vector The oriented vector.
function FXOrientationFunctions.SpotY(orientation_axis)
	if orientation_axis == 2 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_y)
end

---
--- Orients the FX to the Z axis.
---
--- @param orientation_axis number The orientation axis to use.
--- @return vector The oriented vector.
function FXOrientationFunctions.SpotZ(orientation_axis)
	if orientation_axis == 3 then
		return 0, 0, 4096, 0
	end
	return OrientAxisToVectorXYZ(orientation_axis, axis_z)
end

---
--- Rotates the FX by a preset angle.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX from.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to rotate the FX by.
--- @param actor table The actor associated with the FX.
--- @param target table The target associated with the FX.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return number, number, number, number The oriented X, Y, Z axes and angle.
function FXOrientationFunctions.RotateByPresetAngle(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local axis = OrientationAxes[orientation_axis]
	local axis_x, axis_y, axis_z = axis:xyz()
	return axis_x, axis_y, axis_z, preset_angle * 60
end

local function OrientByTerrainAndAngle(fixedAngle, source_obj, posx, posy, posz)
	if source_obj and not source_obj:IsValidZ() or posz - terrain.GetHeight(posx, posy) < 250 then
		local norm = terrain.GetTerrainNormal(posx, posy)
		if not norm:Equal2D(point20) then
			local axis, angle = AxisAngleFromOrientation(norm, fixedAngle)
			local axisx, axisy, axisz = axis:xyz()
			return axisx, axisy, axisz, angle
		end
	end
	return 0, 0, 4096, fixedAngle
end

---
--- Orients the FX by a random angle on the terrain.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX from.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @return number, number, number, number The oriented X, Y, Z axes and angle.
function FXOrientationFunctions.OrientByTerrainWithRandomAngle(orientation_axis, source_obj, posx, posy, posz)
	local randomAngle = AsyncRand(-90 * 180, 90 * 180)
	return OrientByTerrainAndAngle(randomAngle, source_obj, posx, posy, posz)
end

---
--- Orients the FX to face the action position, while also aligning it to the terrain.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX from.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to rotate the FX by.
--- @param actor table The actor associated with the FX.
--- @param target table The target associated with the FX.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return number, number, number, number The oriented X, Y, Z axes and angle.
function FXOrientationFunctions.OrientByTerrainToActionPos(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local tX, tY, tZ, tA = OrientByTerrainAndAngle(0, source_obj, posx, posy, posz)
	local fX, fY, fZ, fA = FXOrientationFunctions.FaceActionPos2D(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if not fX then
		return tX, tY, tZ, tA
	end
	local axis, angle = ComposeRotation(point(fX, fY, fZ), fA, point(tX, tY, tZ), tA)
	return axis:x(), axis:y(), axis:z(), angle
end

---
--- Orients the FX to face the action direction, while also aligning it to the terrain.
---
--- @param orientation_axis number The orientation axis to use.
--- @param source_obj table The source object to orient the FX from.
--- @param posx number The X position of the FX.
--- @param posy number The Y position of the FX.
--- @param posz number The Z position of the FX.
--- @param preset_angle number The preset angle to rotate the FX by.
--- @param actor table The actor associated with the FX.
--- @param target table The target associated with the FX.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
--- @return number, number, number, number The oriented X, Y, Z axes and angle.
function FXOrientationFunctions.OrientByTerrainToActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	local tX, tY, tZ, tA = OrientByTerrainAndAngle(0, source_obj, posx, posy, posz)
	local fX, fY, fZ, fA = FXOrientationFunctions.ActionDir(orientation_axis, source_obj, posx, posy, posz, preset_angle, actor, target, action_pos, action_dir)
	if not fX then
		return tX, tY, tZ, tA
	end
	local axis, angle = ComposeRotation(point(fX, fY, fZ), fA, point(tX, tY, tZ), tA)
	return axis:x(), axis:y(), axis:z(), angle + (preset_angle * 60)
end

local ActionFXOrientationCombo = table.keys2(FXOrientationFunctions, true, "")
local ActionFXOrientationComboDecal = table.copy(ActionFXOrientationCombo, false)

local function FXCalcOrientation(orientation, ...)
	local fn = orientation and FXOrientationFunctions[orientation]
	if fn then
		return fn(...)
	end
end

local function FXOrient(fx_obj, posx, posy, posz, parent, spot, attach, axisx, axisy, axisz, angle, attach_offset)
	if attach and parent and IsValid(parent) and not IsBeingDestructed(parent) then
		if spot then
			parent:Attach(fx_obj, spot)
		else
			parent:Attach(fx_obj)
		end
		if attach_offset then
			fx_obj:SetAttachOffset(attach_offset)
		end
		if angle and angle ~= 0 then
			fx_obj:SetAttachAxis(axisx, axisy, axisz)
			fx_obj:SetAttachAngle(angle)
		end
	else
		fx_obj:Detach()
		if (not posx or not angle) and parent and IsValid(parent) and parent:IsValidPos() then
			if not posx and not angle then
				posx, posy, posz, angle, axisx, axisy, axisz = parent:GetSpotLocXYZ(spot or -1)
			elseif not posx then
				posx, posy, posz = parent:GetSpotLocPosXYZ(spot or -1)
			else
				local _x, _y, _z
				_x, _y, _z, angle, axisx, axisy, axisz = parent:GetSpotLocXYZ(spot or -1)
			end
		end
		if angle then
			fx_obj:SetAxis(axisx, axisy, axisz)
			fx_obj:SetAngle(angle)
		end
		if posx then
			if posz and fx_obj:GetGameFlags(const.gofAttachedOnGround) == 0 then
				fx_obj:SetPos(posx, posy, posz)
			else
				fx_obj:SetPos(posx, posy, const.InvalidZ)
			end
		end
	end
end

local ActionFXDetailLevel = {
	-- please keep this sorted from most important to least important particles
	-- and synced with OptionsData.Options.Effects.hr.FXDetailThreshold
	{ text = "<unspecified>", value = 101 },
	{ text = "Essential", value = 100 }, -- DON'T move from position 2 (see below)
	{ text = "Optional", value = 60 },
	{ text = "EyeCandy", value = 40 },
}
---
--- Returns the list of ActionFXDetailLevel options.
---
--- This function provides the list of ActionFXDetailLevel options, which are used to
--- configure the level of detail for action effects in the game. The list is sorted
--- from most important to least important particles, and is synced with the
--- OptionsData.Options.Effects.hr.FXDetailThreshold setting.
---
--- @return table The list of ActionFXDetailLevel options.
---
function ActionFXDetailLevelCombo()
	return ActionFXDetailLevel
end

local ParticleDetailLevelMax = ActionFXDetailLevel[2].value

local function PreciseDetachObj(obj)
	-- parent scale is lost after Detach
	-- attach offset position and orientation are not restored by Detach
	local px, py, pz = obj:GetVisualPosXYZ()
	local axis = obj:GetVisualAxis()
	local angle = obj:GetVisualAngle()
	local scale = obj:GetWorldScale()
	obj:Detach()
	obj:SetPos(px, py, pz)
	obj:SetAxis(axis)
	obj:SetAngle(angle)
	obj:SetScale(scale)
end

---
--- Dumps information about the FX cache, including the number of used tables, empty play FX, and the most used FX.
---
--- This function iterates through the FXRules and FXCache tables to gather statistics about the FX cache. It counts the number of used tables, empty play FX, and the total number of used FX. It then sorts the FX by the number of times they are used and prints the top 10 most used FX.
---
--- @return nil
function DumpFXCacheInfo()
	local FX = {}
	local used_fx = 0
	local cache_tables = 0
	local cached_lists = 0
	local cached_empty_fx = 0

	local total_fx = 0
	for action_id, actions in pairs(FXRules) do
		for moment_id, moments in pairs(actions) do
			for actor_id, actors in pairs(moments) do
				for target_id, targets in pairs(actors) do
					total_fx = total_fx + #targets
				end
			end
		end
	end

	for action_id, actions in pairs(FXCache) do
		cache_tables = cache_tables + 1
		for moment_id, moments in pairs(actions) do
			cache_tables = cache_tables + 1
			for actor_id, actors in pairs(moments) do
				cache_tables = cache_tables + 1
				for target_id, targets in pairs(actors) do
					cache_tables = cache_tables + 1
					if targets then
						cache_tables = cache_tables + 1
						cached_lists = cached_lists + 1
						used_fx = used_fx + #targets
						for _, fx in ipairs(targets) do
							local count = (FX[fx] or 0) + 1
							FX[fx] = count
							if count == 1 then
								FX[#FX + 1] = fx
							end
						end
					else
						cached_empty_fx = cached_empty_fx + 1
					end
				end
			end
		end
	end
	table.sort(FX, function(a,b) return FX[a] > FX[b] end)

	printf("Used tables in the cache = %d", cache_tables)
	printf("Empty play fx = %d%%", cached_empty_fx * 100 / (cached_lists + cached_empty_fx))
	printf("Used FX = %d (%d%%)", used_fx, used_fx * 100 / total_fx)
	print("Most used FX:")
	for i = 1, Min(10, #FX) do
		local fx = FX[i]
		printf("FX[%s] = %d", fx.class, FX[fx])
	end
end

--============================= Action FX =======================

DefineClass.ActionFXEndRule = {
	__parents = {"PropertyObject"},
	
	properties = {
		{ id = "EndAction", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookActionFXCombo(fx) end },
		{ id = "EndMoment", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookMomentFXCombo(fx) end },
	},

	EditorView = Untranslated("Action '<EndAction>' & Moment '<EndMoment>'"),
}

---
--- Callback function that is called when a property of the `ActionFXEndRule` class is set in the editor.
--- This function ensures that when a property is changed, the `ActionFX` preset that the `ActionFXEndRule` is associated with is updated accordingly.
---
--- @param self ActionFXEndRule The `ActionFXEndRule` instance that the property was set on.
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged GedAdapter The GED adapter associated with the `ActionFXEndRule` instance.
---
function ActionFXEndRule:OnEditorSetProperty(prop_id, old_value, ged)
	local preset = ged:GetParentOfKind("SelectedObject", "ActionFX")
	if preset and preset:IsKindOf("ActionFX") then
		local current_value = self[prop_id]
		self[prop_id] = old_value
		preset:RemoveFromRules()
		self[prop_id] = current_value
		preset:AddInRules()
	end
end

DefineClass.ActionFX = {
	__parents = { "FXPreset" },
	properties = {
		{ id = "Action", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Moment", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end,
			buttons = {{
				name = "View Animation",
				func = function(self) OpenAnimationMomentsEditor(self.Actor, FXActionToAnim(self.Action)) end,
				is_hidden = function(self) return self:IsKindOf("GedMultiSelectAdapter") or not AppearanceLocateByAnimation(FXActionToAnim(self.Action), self.Actor) end,
			}},
		},
		{ id = "Actor", category = "Match", default = "any", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Target", category = "Match", default = "any", editor = "combo", items = function(fx) return TargetFXClassCombo(fx) end },
		{ id = "GameStatesFilter", name = "Game State", category = "Match", editor = "set", default = set(), three_state = true,
			items = function() return GetGameStateFilter() end
		},
		{ id = "FxId", category = "Match", default = "", editor = "text", help = "Empty by default.\nFX Remove requires it to define which FX should be removed." },
		{ id = "DetailLevel", category = "Match", default = ActionFXDetailLevel[1].value, editor = "combo", items = ActionFXDetailLevel, name = "Detail level category", help = "Determines the options detail levels at which the FX triggers. Essential will trigger always, Optional at high/medium setting, and EyeCandy at high setting only.", },
		{ id = "Chance", category = "Match", editor = "number", default = 100, min = 0, max = 100, slider = true, help = "Chance the FX will be placed." },
		{ id = "Disabled", category = "Match", default = false, editor = "bool", help = "Disabled FX are not played.", color = function(o) return o.Disabled and RGB(255,0,0) or nil end },
		{ id = "Delay", name = "Delay (ms)", category = "Lifetime", default = 0, editor = "number", help = "In game time, in milliseconds.\nFX is not played when the actor is interrupted while in the delay." },
		{ id = "Time", name = "Time (ms)", category = "Lifetime", default = 0, editor = "number", help = "Duration, in milliseconds."},
		{ id = "GameTime", category = "Lifetime", editor = "bool", default = false },
		{ id = "EndRules", category = "Lifetime", default = false, editor = "nested_list", base_class = "ActionFXEndRule", inclusive = true, },
		{ id = "Behavior", category = "Lifetime", default = "", editor = "dropdownlist", items = function(fx) return ActionFXBehaviorCombo(fx) end },
		{ id = "BehaviorMoment", category = "Lifetime", default = "", editor = "combo", items = function(fx) return HookMomentFXCombo(fx) end },
		
		{ category = "Test", id = "Solo", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, if any fx's are set as solo, only they will be played."},
		{ category = "Test", id = "DbgPrint", name = "DebugFX", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, print when this FX is about to play."},
		{ category = "Test", id = "DbgBreak", name = "Break", default = false, editor = "bool", developer = true, dont_save = true, help = "Debug feature, break execution in the Lua debugger when this FX is about to play."},
		{ category = "Test", id = "AnimEntity", name = "Anim Entity", default = "", editor = "text", help = "Specifies that this FX is linked to a specific animation. Auto fills the anims and moments available. An error will be issued if the action and the moment aren't found in that entity." },
		
		{ id = "AnimRevisionEntity", default = false, editor = "text", no_edit = true },
		{ id = "AnimRevision", default = false, editor = "number", no_edit = true },
		{ id = "_reconfirm", category = "Preset", editor = "buttons", buttons = {{ name = "Confirm Changes", func = "ConfirmChanges" }},
			no_edit = function(self) return not self:GetAnimationChangedWarning() end,
		},
	},
	fx_type = "",
	behaviors = false,
	-- loc props
	Source = "Actor",
	SourceProp = "",
	Spot = "",
	SpotsPercent = -1,
	Offset = false,
	OffsetDir = "SourceAxisX",
	Orientation = "",
	PresetOrientationAngle = 0,
	OrientationAxis = 1,
	Attach = false,
	Cooldown = 0,
}

ActionFX.Documentation = [[Defines rules for playing effects in the game on certain events.

An FX event is raised from the code using the PlayFX function. It has four main arguments: action, moment, actor, and target. All ActionFX presets matching these arguments will be activated.]]

--- Generates code for the ActionFX object.
---
--- This function is responsible for generating the code for the ActionFX object. It first drops any non-property elements from the `behaviors` table, then calls the `GenerateCode` function of the `FXPreset` class with the current `ActionFX` object. Finally, it restores the `behaviors` table.
---
--- @param code table The code table to generate the code into.
function ActionFX:GenerateCode(code)
	-- drop non property elements
	local behaviors = self.behaviors
	self.behaviors = nil
	FXPreset.GenerateCode(self, code)
	self.behaviors = behaviors
end

if FirstLoad or ReloadForDlc then
	if Platform.developer then
		g_SoloFX_count = 0
		g_SoloFX_list = {} --used to turn off all solo fx at once
		function ClearAllSoloFX()
			local t = table.copy(g_SoloFX_list) --so we can iterate safely.
			for i, v in ipairs(t) do
				v:SetSolo(false)
			end
		end
	else
		function ClearAllSoloFX()
		end
	end
end

if Platform.developer then
---
--- Sets the solo state of the ActionFX object.
---
--- If the solo state is set to true, the ActionFX object is added to the global `g_SoloFX_list` table and the `g_SoloFX_count` is incremented. If the solo state is set to false, the ActionFX object is removed from the `g_SoloFX_list` table and the `g_SoloFX_count` is decremented.
---
--- The `FXCache` is set to false to ensure that the changes to the solo state are reflected in the game.
---
--- @param val boolean The new solo state of the ActionFX object.
function ActionFX:SetSolo(val)
	if self.Solo == val then return end

	if val then
		g_SoloFX_count = g_SoloFX_count + 1
		g_SoloFX_list[#g_SoloFX_list + 1] = self
	else
		g_SoloFX_count = g_SoloFX_count - 1
		table.remove(g_SoloFX_list, table.find(g_SoloFX_list, self))
	end

	self.Solo = val
	FXCache = false
end
end

---
--- Removes the ActionFX object from the game rules.
---
--- This function is called when the ActionFX object is no longer needed, such as when the game is ending or the object is being destroyed. It removes the object from the game rules, ensuring that it is no longer processed or updated.
---
--- @function ActionFX:Done
--- @return nil
function ActionFX:Done()
	self:RemoveFromRules()
end

---
--- Plays the ActionFX associated with the given actor, target, action position, and action direction.
---
--- This function is responsible for triggering the visual and audio effects associated with an action in the game. It takes the actor, target, action position, and action direction as input parameters and uses them to determine which ActionFX object to play.
---
--- @param actor table The actor performing the action.
--- @param target table The target of the action.
--- @param action_pos Vector3 The position of the action.
--- @param action_dir Vector3 The direction of the action.
--- @return nil
function ActionFX:PlayFX(actor, target, action_pos, action_dir)
end

---
--- Destroys the FX associated with the given actor and target.
---
--- This function is responsible for removing and destroying any FX (visual or audio effects) that are associated with the given actor and target. It first attempts to retrieve the FX object using the `AssignFX` function, and if successful, it checks if the FX is a valid thread and deletes it if so.
---
--- @param actor table The actor associated with the FX.
--- @param target table The target associated with the FX.
--- @return nil
function ActionFX:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	end
end

---
--- Adds the ActionFX object to the game rules and hooks its behaviors.
---
--- This function is called when the ActionFX object needs to be added to the game rules. It first adds the object to the rules using the `AddInRules` function, and then hooks any behaviors associated with the object using the `HookBehaviors` function.
---
--- @function ActionFX:AddInRules
--- @return nil
function ActionFX:AddInRules()
	AddInRules(self)
	self:HookBehaviors()
end

--- Removes the ActionFX object from the game rules and unhooks any associated behaviors.
---
--- This function is responsible for removing the ActionFX object from the game rules, ensuring that it is no longer processed or updated. It first removes the object from the rules using the `RemoveFromRules` function, and then unhooks any behaviors associated with the object using the `UnhookBehaviors` function.
---
--- @function ActionFX:RemoveFromRules
--- @return nil
function ActionFX:RemoveFromRules()
	RemoveFromRules(self)
	self:UnhookBehaviors()
end

---
--- Hooks the behaviors associated with this ActionFX object.
---
--- This function is responsible for hooking the behaviors associated with this ActionFX object. It first checks if the object is not disabled, and if so, it hooks the behavior specified by the `Behavior` and `BehaviorMoment` properties using the `HookBehaviorFX` function.
---
--- It then hooks the end action behaviors specified by the `EndRules` property, using the `HookBehaviorFX` function with the "DestroyFX" behavior. This ensures that any currently playing FX associated with this ActionFX object are properly stopped, even if the object is disabled.
---
--- @function ActionFX:HookBehaviors
--- @return nil
function ActionFX:HookBehaviors()
	if not self.Disabled then
		-- hook behavior
		if self.Behavior ~= "" and self.BehaviorMoment ~= "" and self.BehaviorMoment ~= self.Moment then
			self:HookBehaviorFX(self.Behavior, self.Action, self.BehaviorMoment, self.Actor, self.Target)
		end
	end
	
	-- hook end action (even if disabled; this will allow currently playing FXs restored from savegames to stop)
	if self.EndRules then
		for idx, fxend in ipairs(self.EndRules) do
			local end_action = fxend.EndAction ~= "" and fxend.EndAction or self.Action
			local end_moment = fxend.EndMoment
			if end_action ~= self.Action or end_moment ~= "" and end_moment ~= self.Moment then
				self:HookBehaviorFX("DestroyFX", end_action, end_moment, self.Actor, self.Target)
			end
		end
	end
end

---
--- Unhooks all behaviors associated with this ActionFX object.
---
--- This function is responsible for removing all behaviors associated with this ActionFX object from the game rules and deleting them. It first retrieves the list of behaviors from the `behaviors` property, and then iterates through them in reverse order. For each behavior, it removes the behavior from the game rules using the `RemoveFromRules` function, and then deletes the behavior object using the `delete` method.
---
--- After all behaviors have been removed and deleted, the `behaviors` property is set to `nil`.
---
--- @function ActionFX:UnhookBehaviors
--- @return nil
function ActionFX:UnhookBehaviors()
	local behaviors = self.behaviors
	if not behaviors then return end
	for i = #behaviors, 1, -1 do
		local fx = behaviors[i]
		RemoveFromRules(fx)
		fx:delete()
	end
	self.behaviors = nil
end

---
--- Hooks a behavior FX to the ActionFX object.
---
--- This function is responsible for hooking a behavior FX to the ActionFX object. It first checks if there are any existing behaviors with the same action, actor, moment, and target as the new behavior. If so, it logs an error and breaks out of the loop.
---
--- It then initializes the `behaviors` table if it doesn't exist, and creates a new `ActionFXBehavior` object with the provided parameters. The new behavior is then added to the `behaviors` table and added to the game rules using the `AddInRules` function.
---
--- @param behavior string The name of the behavior FX to hook.
--- @param action string The action associated with the behavior FX.
--- @param moment string The moment associated with the behavior FX.
--- @param actor string The actor associated with the behavior FX.
--- @param target string The target associated with the behavior FX.
--- @return nil
function ActionFX:HookBehaviorFX(behavior, action, moment, actor, target)
	for _, fx in ipairs(self.behaviors) do
		if fx.Action == action and fx.Moment == moment
		and fx.Actor == actor and fx.Target == target
		and fx.fx == self and fx.BehaviorFXMethod == behavior then
			StoreErrorSource(self, string.format("%s behaviors with the same action (%s), actor (%s), moment (%s), and target (%s) in this ActionFX", behavior, action, actor, moment, target))
			break
		end
	end
	self.behaviors = self.behaviors or {}
	local fx = ActionFXBehavior:new{ Action = action, Moment = moment, Actor = actor, Target = target, fx = self, BehaviorFXMethod = behavior }
	table.insert(self.behaviors, fx)
	AddInRules(fx)
end

local rules_props = {
	Action = true,
	Moment = true,
	Actor = true,
	Target = true,
	Disabled = true,
	Behavior = true,
	BehaviorMoment = true,
	EndRules = true,
	Cooldown = true,
}

---
--- Handles the updating of properties for an ActionFX object.
---
--- This function is called when a property of the ActionFX object is updated in the editor. It performs the following actions:
---
--- 1. If the `Action` or `Moment` property is updated, and they are not set to "any", it updates the `AnimRevisionEntity` and `AnimRevision` properties based on the animation associated with the `Action` property.
--- 2. If the updated property is a valid rule property (as defined in the `rules_props` table), it removes the ActionFX from the rules, updates the property value, and then adds the ActionFX back to the rules.
---
--- @param prop_id string The ID of the property that was updated.
--- @param old_value any The previous value of the updated property.
--- @return nil
function ActionFX:OnEditorSetProperty(prop_id, old_value)
	-- remember the animation revision when the FX rule is linked to an animation moment
	if (prop_id == "Action" or prop_id == "Moment") and self.Action ~= "any" and self.Moment ~= "any" then
		local animation = FXActionToAnim(self.Action)
		local appearance = AppearanceLocateByAnimation(animation, "__missing_appearance")
		local entity = appearance and AppearancePresets[appearance].Body or self.AnimEntity ~= "" and self.AnimEntity
		self.AnimRevisionEntity = entity or nil
		self.AnimRevision       = entity and EntitySpec:GetAnimRevision(entity, animation) or nil
	end
	
	if not rules_props[prop_id] then return end
	local value = self[prop_id]
	self[prop_id] = old_value
	self:RemoveFromRules()
	self[prop_id] = value
	self:AddInRules()
end

---
--- Checks if the ActionFX object has any associated behaviors.
---
--- @return boolean true if the ActionFX object has any behaviors, false otherwise
function ActionFX:TrackFX()
	return self.behaviors and true or false
end

---
--- Checks if the game states specified in the `GameStatesFilter` property match the provided `game_states` table.
---
--- @param game_states table A table of game states and their active/inactive status.
--- @return boolean true if the game states match, false otherwise.
function ActionFX:GameStatesMatched(game_states)
	if not self.GameStatesFilter then return true end
	
	for state, active in pairs(game_states) do
		if self.GameStatesFilter[state] ~= active then
			return
		end
	end
	
	return true
end

---
--- Selects a random variation from the provided list of properties.
---
--- @param props_list table A list of property names to check for variations.
--- @return string|nil The selected variation, or nil if no variations are found.
function ActionFX:GetVariation(props_list)
	local variations = 0
	for i, prop in ipairs(props_list) do
		if self[prop] ~= "" then
			variations = variations + 1
		end
	end
	if variations == 0 then
		return
	end
	local id = AsyncRand(variations) + 1
	for i, prop in ipairs(props_list) do
		if self[prop] ~= "" then
			id = id - 1
			if id == 0 then
				return self[prop]
			end
		end
	end
end

---
--- Creates a new thread based on the ActionFX object's properties.
---
--- If the `GameTime` property is set, the thread is created using `CreateGameTimeThread`.
--- If the `Source` property is "UI", the thread is created using `CreateRealTimeThread`.
--- Otherwise, the thread is created using `CreateMapRealTimeThread` and made persistent.
---
--- @param ... any Arguments to pass to the thread function.
--- @return thread The created thread.
function ActionFX:CreateThread(...)
	if self.GameTime then
		assert(self.Source ~= "UI")
		return CreateGameTimeThread(...)
	end
	if self.Source == "UI" then
		return CreateRealTimeThread(...)
	end
	local thread = CreateMapRealTimeThread(...)
	MakeThreadPersistable(thread)
	return thread
end

if FirstLoad then
	FX_Assigned = {}
end

local function FilterFXValues(data, f)
	if not data then return false end

	local result = {}
	for fx_preset, actor_map in pairs(data) do
		local result_actor_map = setmetatable({}, weak_keys_meta)
		for actor, target_map in pairs(actor_map) do
			if f(actor, nil) then
				local result_target_map = setmetatable({}, weak_keys_meta)

				for target, fx in pairs(target_map) do
					if f(actor, target) then
						result_target_map[target] = fx
					end
				end

				if next(result_target_map) ~= nil then
					result_actor_map[actor] = result_target_map
				end
			end
		end

		if next(result_actor_map) ~= nil then
			result[fx_preset] = result_actor_map
		end
	end
	return result
end

local IsKindOf = IsKindOf
function OnMsg.PersistSave(data)
	data["FX_Assigned"] = FilterFXValues(FX_Assigned, function(actor, target)
		if IsKindOf(actor, "XWindow") then
			return false
		end
		if IsKindOf(target, "XWindow") then
			return false
		end
		return true
	end)
end

function OnMsg.PersistLoad(data)
	FX_Assigned = data.FX_Assigned or {}
end

function OnMsg.ChangeMapDone()
	FX_Assigned = FilterFXValues(FX_Assigned, function(actor, target)
		if IsKindOf(actor, "XWindow") then
			if not target or IsKindOf(target, "XWindow") then
				return true
			end
		end
		return false
	end)
end

---
--- Assigns an FX (effect) to the specified actor and target.
---
--- @param actor table|nil The actor to assign the FX to. If `nil`, the FX will be assigned to the "ignore" target.
--- @param target table|nil The target to assign the FX to. If `nil`, the FX will be assigned to the "ignore" target.
--- @param fx table|nil The FX to assign. If `nil`, any existing FX assignment will be removed.
--- @return table|nil The previously assigned FX, if any.
function ActionFX:AssignFX(actor, target, fx)
	local t = FX_Assigned[self]
	if not t then
		if fx == nil then return end
		t = setmetatable({}, weak_keys_meta)
		FX_Assigned[self] = t
	end
	local t2 = t[actor or false]
	if not t2 then
		if fx == nil then return end
		t2 = setmetatable({}, weak_keys_meta)
		t[actor or false] = t2
	end
	local id = self.Target == "ignore" and "ignore" or target or false
	local prev_fx = t2[id]
	t2[id] = fx
	return prev_fx
end

---
--- Gets the FX (effect) assigned to the specified actor and target.
---
--- @param actor table|nil The actor to get the assigned FX for. If `nil`, the FX assigned to the "ignore" target will be returned.
--- @param target table|nil The target to get the assigned FX for. If `nil`, the FX assigned to the "ignore" target will be returned.
--- @return table|nil The FX assigned to the specified actor and target, or `nil` if no FX is assigned.
function ActionFX:GetAssignedFX(actor, target)
	local o = FX_Assigned[self]
	o = o and o[actor or false]
	o = o and o[self.Target == "ignore" and "ignore" or target or false]
	return o
end

---
--- Gets the location object for the FX (effect) based on the specified actor and target.
---
--- @param actor table|nil The actor to get the location object for.
--- @param target table|nil The target to get the location object for.
--- @return table|nil The location object for the FX, or `nil` if no valid location object is found.
function ActionFX:GetLocObj(actor, target)
	local obj
	local source = self.Source
	if source == "Actor" then
		obj = IsValid(actor) and actor
	elseif source == "ActorParent" then
		obj = IsValid(actor) and GetTopmostParent(actor)
	elseif source == "ActorOwner" then
		obj = actor and IsValid(actor.NetOwner) and actor.NetOwner
	elseif source == "Target" then
		obj = IsValid(target) and target
	elseif source == "Camera" then
		obj = IsValid(g_CameraObj) and g_CameraObj
	end
	if obj then
		if self.SourceProp ~= "" then
			local prop = obj:GetProperty(self.SourceProp)
			obj = prop and IsValid(prop) and prop
		elseif self.Spot ~= "" then
			local o = obj:GetObjectBySpot(self.Spot)
			if o ~= nil then
				obj = o
			end
		end
	end
	return obj
end

---
--- Gets the location for the FX (effect) based on the specified actor, target, action position, and action direction.
---
--- @param actor table|nil The actor to get the location for.
--- @param target table|nil The target to get the location for.
--- @param action_pos table|nil The position of the action to get the location for.
--- @param action_dir table|nil The direction of the action to get the location for.
--- @return number, table|nil, number|nil, number, number, number, number The number of locations, the location object, the spot index, the position X, Y, Z, the angle, and the axis X, Y, Z.
function ActionFX:GetLoc(actor, target, action_pos, action_dir)
	if self.Source == "ActionPos" then
		if action_pos and action_pos:IsValid() then
			local posx, posy, posz = action_pos:xyz()
			return 1, nil, nil, self:FXOrientLoc(nil, posx, posy, posz, nil, nil, nil, nil, actor, target, action_pos, action_dir)
		elseif IsValid(actor) and actor:IsValidPos() then
			-- use actor position for default
			local posx, posy, posz = GetTopmostParent(actor):GetSpotLocPosXYZ(-1)
			return 1, nil, nil, self:FXOrientLoc(nil, posx, posy, posz, nil, nil, nil, nil, actor, target, action_pos, action_dir)
		end
		return 0
	end
	-- find loc obj
	local obj = self:GetLocObj(actor, target)
	if not obj then
		return 0
	end
	local spots_count, first_spot, spots_list = self:GetLocObjSpots(obj)
	if (spots_count or 0) <= 0 then
		return 0
	elseif spots_count == 1 then
		local posx, posy, posz, angle, axisx, axisy, axisz
		if obj:IsValidPos() then
			posx, posy, posz, angle, axisx, axisy, axisz = obj:GetSpotLocXYZ(first_spot or -1)
		end
		return 1, obj, first_spot, self:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
	end
	local params = {}
	for i = 0, spots_count-1 do
		local spot = spots_list and spots_list[i+1] or first_spot + i
		local posx, posy, posz, angle, axisx, axisy, axisz
		if obj:IsValidPos() then
			posx, posy, posz, angle, axisx, axisy, axisz = obj:GetSpotLocXYZ(spot)
		end
		posx, posy, posz, angle, axisx, axisy, axisz = self:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
		params[8*i+1] = spot
		params[8*i+2] = posx
		params[8*i+3] = posy
		params[8*i+4] = posz
		params[8*i+5] = angle
		params[8*i+6] = axisx
		params[8*i+7] = axisy
		params[8*i+8] = axisz
	end
	return spots_count, obj, params
end

---
--- Orients the location of an action effect (FX) based on various parameters.
---
--- @param obj table|nil The object associated with the action effect.
--- @param posx number The X position of the action effect.
--- @param posy number The Y position of the action effect.
--- @param posz number|nil The Z position of the action effect.
--- @param angle number|nil The angle of the action effect.
--- @param axisx number|nil The X axis of the action effect.
--- @param axisy number|nil The Y axis of the action effect.
--- @param axisz number|nil The Z axis of the action effect.
--- @param actor table|nil The actor associated with the action effect.
--- @param target table|nil The target associated with the action effect.
--- @param action_pos table|nil The position of the action.
--- @param action_dir table|nil The direction of the action.
--- @return number, number, number|nil, number|nil, number|nil, number|nil The oriented X, Y, Z positions, angle, and axis X, Y, Z.
---
function ActionFX:FXOrientLoc(obj, posx, posy, posz, angle, axisx, axisy, axisz, actor, target, action_pos, action_dir)
	local orientation = self.Orientation
	if orientation == "" and self.Attach then
		orientation = "SpotX"
	end
	if posx then
		local offset = self.Offset
		if offset and offset ~= point30 then
			local o_axisx, o_axisy, o_axisz, o_angle = FXCalcOrientation(self.OffsetDir, 1, obj, posx, posy, posz, 0, actor, target, action_pos, action_dir)
			local x, y, z
			if (o_angle or 0) == 0 or o_axisx == 0 and o_axisy == 0 and offset:Equal2D(point20) then
				x, y, z = offset:xyz()
			else
				x, y, z = RotateAxisXYZ(offset, point(o_axisx, o_axisy, o_axisz), o_angle)
			end
			posx = posx + x
			posy = posy + y
			if posz and z then
				posz = posz + z
			end
		end
	end
	local o_axisx, o_axisy, o_axisz, o_angle = FXCalcOrientation(orientation, self.OrientationAxis, obj, posx, posy, posz, self.PresetOrientationAngle, actor, target, action_pos, action_dir)
	if o_angle then
		angle, axisx, axisy, axisz = o_angle, o_axisx, o_axisy, o_axisz
	end
	return posx, posy, posz, angle, axisx, axisy, axisz
end

---
--- Gets the location object spots for an action effect.
---
--- @param obj table The object associated with the action effect.
--- @return number, table|nil, table|nil The number of spots, the first spot, and a table of spots.
---
function ActionFX:GetLocObjSpots(obj)
	local percent = self.SpotsPercent
	if percent == 0 then
		return 0
	end
	local spot_name = self.Spot
	if spot_name == "" or spot_name == "Origin" or not obj:HasSpot(spot_name) then
		return 1
	elseif percent < 0 then
		return 1, obj:GetRandomSpot(spot_name)
	else
		local first_spot, last_spot = obj:GetSpotRange(spot_name)
		local spots_count = last_spot - first_spot + 1
		local count = spots_count
		if percent < 100 then
			local remainder = count * percent % 100
			local roll = remainder > 0 and AsyncRand(100) or 0
			count = count * percent / 100 + (roll < remainder and 1 or 0)
		end
		if count <= 0 then
			return
		elseif count == 1 then
			return 1, first_spot + (spots_count > 1 and AsyncRand(spots_count) or 0)
		elseif count >= spots_count then
			return spots_count, first_spot
		end
		local spots = {}
		for i = 1, count do
			local k = i + AsyncRand(spots_count-i+1)
			spots[i], spots[k] = spots[k] or first_spot + k - 1, spots[i] or first_spot + i - 1
		end
		return count, nil, spots
	end
end

---
--- Converts an animation name to an action name.
---
--- @param anim string The animation name to convert.
--- @return string The action name.
---
function FXAnimToAction(anim)
	return anim
end

---
--- Converts an action name to an animation name.
---
--- @param action string The action name to convert.
--- @return string The animation name.
---
function FXActionToAnim(action)
	return action
end

local GetEntityAnimMoments = GetEntityAnimMoments

function OnMsg.GatherFXMoments(list, fx)
	local entity = fx and rawget(fx, "AnimEntity") or ""
	if entity == "" or not IsValidEntity(entity)  then
		return
	end
	local anim = fx and fx.Action
	if not anim or anim == "any" or anim == "" or not EntityStates[anim] then
		return
	end
	for _, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		list[#list + 1] = moment.Type
	end
end

---
--- Checks for errors in the ActionFX object.
---
--- @param self ActionFX The ActionFX object to check for errors.
--- @return string|nil The error message if any errors are found, or nil if no errors are found.
---
function ActionFX:GetError()
	local entity = self.AnimEntity or ""
	if entity ~= "" then
		if not IsValidEntity(entity) then
			return "No such entity: " .. entity
		end
		local anim = self.Action or ""
		if anim ~= "" and anim ~= "any" then
			if not EntityStates[anim] then
				return "Invalid state: " .. anim
			end
			if not HasState(entity, anim) then
				return "No such anim: " .. entity .. "." .. anim
			end
			local moment = self.Moment or ""
			if moment ~= "" and moment ~= "any" then
				local moments = GetEntityAnimMoments(entity, anim)
				if not table.find(moments, "Type", moment) then
					return "No such moment: " .. entity .. "." .. anim .. "." .. moment
				end
			end
		end
	end
end

---
--- Checks for changes in the animation associated with the ActionFX object and returns a warning message if the animation has been updated.
---
--- @param self ActionFX The ActionFX object to check for animation changes.
--- @return string|nil The warning message if the animation has been updated, or nil if no changes have been detected.
---
function ActionFX:GetAnimationChangedWarning()
	local entity, anim = self.AnimRevisionEntity, FXActionToAnim(self.Action)
	if entity and not IsValidEntity(entity) then
		return string.format("Entity %s with which this FX was created no longer exists.\nPlease test/readjust it and click Confirm Changes below.", entity)
	end
	if entity and not HasState(entity, anim) then
		return string.format("Entity %s with which this FX was created no longer has animation %s.\nPlease test/readjust it and click Confirm Changes below.", entity, anim)
	end
--	return entity and EntitySpec:GetAnimRevision(entity, anim) > self.AnimRevision and
--		string.format("Animation %s was updated after this FX.\nPlease test/readjust it and click Confirm Changes below.", anim)
end

---
--- Returns a warning message if the animation associated with the ActionFX object has been updated.
---
--- @param self ActionFX The ActionFX object to check for animation changes.
--- @return string|nil The warning message if the animation has been updated, or nil if no changes have been detected.
---
function ActionFX:GetWarning()
	return self:GetAnimationChangedWarning()
end

---
--- Updates the animation revision for the ActionFX object and marks it as modified.
---
--- @param self ActionFX The ActionFX object to update.
---
function ActionFX:ConfirmChanges()
	self.AnimRevision = EntitySpec:GetAnimRevision(self.AnimRevisionEntity, FXActionToAnim(self.Action))
	ObjModified(self)
end

--============================= Test FX =======================
if FirstLoad then
	LastTestActionFXObject = false
end
function OnMsg.DoneMap()
	LastTestActionFXObject = false
end
local function TestActionFXObjectEnd(obj)
	DoneObject(obj)
	if LastTestActionFXObject == obj then
		LastTestActionFXObject = false
		return
	end
	if obj or not LastTestActionFXObject then
		return
	end
	DoneObject(LastTestActionFXObject)
	LastTestActionFXObject = false
end

--============================= Inherit FX =======================

DefineClass.ActionFXInherit = {
	__parents = { "FXPreset" },
}

DefineClass.ActionFXInherit_Action = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Action", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Action",
}

---
--- Marks the FXInheritRules_Actions and FXCache tables as needing to be rebuilt.
---
--- This function is called when the properties of an ActionFXInherit_Action object are modified,
--- to ensure that the cached inheritance rules are invalidated and will be rebuilt on the next access.
---
function ActionFXInherit_Action:Done()
	FXInheritRules_Actions = false
	FXCache = false
end

---
--- Returns a string containing a newline-separated list of all the FX that inherit from the specified action.
---
--- This function is used to populate the "All" property of the ActionFXInherit_Action class, which displays a list of all the inherited FX.
---
--- @param self ActionFXInherit_Action The instance of the ActionFXInherit_Action class.
--- @return string A newline-separated list of all the inherited FX.
---
function ActionFXInherit_Action:GetAll()
	local list = (FXInheritRules_Actions or RebuildFXInheritActionRules())[self.Action]
	return list and table.concat(list, "\n") or ""
end

---
--- Marks the FXInheritRules_Actions and FXCache tables as needing to be rebuilt.
---
--- This function is called when the properties of an ActionFXInherit_Action object are modified,
--- to ensure that the cached inheritance rules are invalidated and will be rebuilt on the next access.
---
--- @param self ActionFXInherit_Action The instance of the ActionFXInherit_Action class.
--- @param prop_id string The ID of the property that was modified.
--- @param old_value any The previous value of the modified property.
--- @param ged table The GED (Game Editor) object associated with the modified property.
---
function ActionFXInherit_Action:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Actions = false
	FXCache = false
end

DefineClass.ActionFXInherit_Moment = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Moment", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Moment",
}

---
--- Marks the FXInheritRules_Moments and FXCache tables as needing to be rebuilt.
---
--- This function is called when the properties of an ActionFXInherit_Moment object are modified,
--- to ensure that the cached inheritance rules are invalidated and will be rebuilt on the next access.
---
--- @param self ActionFXInherit_Moment The instance of the ActionFXInherit_Moment class.
---
function ActionFXInherit_Moment:Done()
	FXInheritRules_Moments = false
	FXCache = false
end

---
--- This function is used to populate the "All" property of the ActionFXInherit_Moment class, which displays a list of all the inherited FX.
---
--- @param self ActionFXInherit_Moment The instance of the ActionFXInherit_Moment class.
--- @return string A newline-separated list of all the inherited FX.
---
function ActionFXInherit_Moment:GetAll()
	local list = (FXInheritRules_Moments or RebuildFXInheritMomentRules())[self.Moment]
	return list and table.concat(list, "\n") or ""
end

---
--- Marks the FXInheritRules_Moments and FXCache tables as needing to be rebuilt.
---
--- This function is called when the properties of an ActionFXInherit_Moment object are modified,
--- to ensure that the cached inheritance rules are invalidated and will be rebuilt on the next access.
---
--- @param self ActionFXInherit_Moment The instance of the ActionFXInherit_Moment class.
--- @param prop_id string The ID of the property that was modified.
--- @param old_value any The previous value of the modified property.
--- @param ged table The GED (Game Editor) object associated with the modified property.
---
function ActionFXInherit_Moment:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Moments = false
	FXCache = false
end

DefineClass.ActionFXInherit_Actor = {
	__parents = { "ActionFXInherit" },
	properties = {
		{ id = "Actor", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Inherit", category = "Inherit", default = "", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "All", category = "Inherit", default = "", editor = "text", lines = 5, read_only = true, dont_save = true }
	},
	fx_type = "Inherit Actor",
}

---
--- Marks the FXInheritRules_Actors and FXCache tables as needing to be rebuilt.
---
--- This function is called when the properties of an ActionFXInherit_Actor object are modified,
--- to ensure that the cached inheritance rules are invalidated and will be rebuilt on the next access.
---
--- @param self ActionFXInherit_Actor The instance of the ActionFXInherit_Actor class.
---
function ActionFXInherit_Actor:Done()
	FXInheritRules_Actors = false
	FXCache = false
end

---
--- This function is used to populate the "All" property of the ActionFXInherit_Actor class, which displays a list of all the inherited FX.
---
--- @param self ActionFXInherit_Actor The instance of the ActionFXInherit_Actor class.
--- @return string A newline-separated list of all the inherited FX.
---
function ActionFXInherit_Actor:GetAll()
	local list = (FXInheritRules_Actors or RebuildFXInheritActorRules())[self.Actor]
	return list and table.concat(list, "\n") or ""
end

function ActionFXInherit_Actor:OnEditorSetProperty(prop_id, old_value, ged)
	FXInheritRules_Actors = false
	FXCache = false
end

--============================= Behavior FX =======================

DefineClass.ActionFXBehavior = {
	__parents = { "InitDone" },
	properties = {
		{ id = "Action", default = "any" },
		{ id = "Moment", default = "any" },
		{ id = "Actor", default = "any" },
		{ id = "Target", default = "any" },
	},
	fx = false,
	BehaviorFXMethod = "",
	fx_type = "Behavior",
	Disabled = false,
	Delay = 0,
	Map = "any",
	Id = "",
	DetailLevel = 100,
	Chance = 100,
}

---
--- Plays the FX associated with the ActionFXBehavior instance.
---
--- @param self ActionFXBehavior The instance of the ActionFXBehavior class.
--- @param actor table The actor object.
--- @param target table The target object.
--- @param ... any Additional arguments to pass to the FX method.
---
function ActionFXBehavior:PlayFX(actor, target, ...)
	self.fx[self.BehaviorFXMethod](self.fx, actor, target, ...)
end

--============================= Remove FX =======================

DefineClass.ActionFXRemove = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Time", editor = false },
		{ id = "EndRules", editor = false },
		{ id = "Behavior", editor = false },
		{ id = "BehaviorMoment", editor = false },
		{ id = "Delay", editor = false },
		{ id = "GameTime", editor = false },
	},
	fx_type = "FX Remove",
	Documentation = ActionFX.Documentation .. "\n\nRemoves an action fx."
}

---
--- Hooks the behaviors associated with the ActionFXRemove instance.
---
--- This method is called to set up any behaviors or event handlers that the ActionFXRemove instance needs to function properly.
---
--- @param self ActionFXRemove The instance of the ActionFXRemove class.
---
function ActionFXRemove:HookBehaviors()
end

---
--- Unhooks any behaviors or event handlers associated with the ActionFXRemove instance.
---
--- This method is called to remove any behaviors or event handlers that were set up in the `HookBehaviors()` method.
---
--- @param self ActionFXRemove The instance of the ActionFXRemove class.
---
function ActionFXRemove:UnhookBehaviors()
end

--============================= Sound FX =======================

local MarkObjSound = empty_func

function OnMsg.ChangeMap()
	if not config.AllowSoundFXOnMapChange then
		DisableSoundFX = true
	end
end

---
--- Enables sound effects after a map change.
---
--- This function is called when the map has finished changing. It sets the `DisableSoundFX` global variable to `false`, which allows sound effects to be played again.
---
function OnMsg.ChangeMapDone()
	DisableSoundFX = false
end

DefineClass.ActionFXSound = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Match", id = "Cooldown", name = "Cooldown (ms)", default = 0, editor = "number", help = "Cooldown, in real time milliseconds." },
		{ category = "Sound", id = "Sound", default = "", editor = "preset_id", preset_class = "SoundPreset", buttons = {{name = "Test", func = "TestActionFXSound"}, {name = "Stop", func = "StopActionFXSound"}}},
		{ category = "Sound", id = "DistantRadius", default = 0, editor = "number", scale = "m", help = "Defines the radius for playing DistantSound." },
		{ category = "Sound", id = "DistantSound", default = "", editor = "preset_id", preset_class = "SoundPreset",
			help = "This sound will be played if the distance from the camera is greater than DistantRadius."
		},
		{ category = "Sound", id = "FadeIn", default = 0, editor = "number", },
		{ category = "Sound", id = "FadeOut", default = 0, editor = "number", },
		{ category = "Sound", id = "Source", default = "Actor", editor = "dropdownlist", items = { "UI", "Actor", "Target", "ActionPos", "Camera" }, help = "Sound listener object or position." },
		{ category = "Sound", id = "Spot", default = "", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, no_edit = no_obj_no_edit },
		{ category = "Sound", id = "SpotsPercent", default = -1, editor = "number", no_edit = no_obj_no_edit, help = "Percent of random spots that should be used. One random spot is used when the value is negative." },
		{ category = "Sound", id = "Offset", default = point30, editor = "point", scale = "m", help = "Offset against source object" },	
		{ category = "Sound", id = "OffsetDir", default = "SourceAxisX", no_edit = function(self) return self.AttachToObj end, editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },				
		{ category = "Sound", id = "AttachToObj", name = "Attach To Source", editor = "bool", default = false, help = "Attach to the actor or target (the Source) and move with it." },
		{ category = "Sound", id = "SkipSame", name = "Skip Same Sound", editor = "bool", default = false, no_edit = PropChecker("AttachToObj", false), help = "Don't start a new sound if the object has the same sound already playing" },
		{ category = "Sound", id = "AttachToObjHelp", editor = "help", default = false,
			help = "Sounds attached to an object are played whenever the camera gets close, even if it was away when the object was created.\n\nOnly one sound can be attached to an object, and attaching a new sound removes the previous one. Use this for single sounds that are emitted permanently." },
	},
	fx_type = "Sound",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and plays sound effects when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties.",
	DocumentationLink = "Docs/ModItemActionFXSound.md.html"
}

MapVar("FXCameraSounds", {}, weak_keys_meta)

function OnMsg.DoneMap()
	for fx in pairs(FXCameraSounds) do
		FXCameraSounds[fx] = nil
		if fx.sound_handle then
			SetSoundVolume(fx.sound_handle, -1, not config.AllowSoundFXOnMapChange and fx.fade_out or 0) -- -1 means destroy
			fx.sound_handle = nil
		end
		DeleteThread(fx.thread)
	end
end

function OnMsg.PostLoadGame()
	for fx in pairs(FXCameraSounds) do
		local sound = fx.Sound or ""
		local handle = sound ~= "" and PlaySound(sound, nil, 300)
		if not handle then
			FXCameraSounds[fx] = nil
			DeleteThread(fx.thread)
		else
			fx.sound_handle = handle
		end
	end
end

---
--- Determines whether the ActionFXSound instance should track its FX.
---
--- This function checks various properties of the ActionFXSound instance to determine whether it should track its FX. If any of the following conditions are true, the function returns `true`:
---
--- - `self.behaviors` is not `nil`
--- - `self.FadeOut` is greater than 0
--- - `self.Time` is greater than 0
--- - `self.Source` is "Camera"
--- - `self.AttachToObj` is `true` and `self.Spot` is not an empty string
--- - `self.Cooldown` is greater than 0
---
--- Otherwise, the function returns `false`.
---
--- @return boolean Whether the ActionFXSound instance should track its FX
function ActionFXSound:TrackFX()
	if self.behaviors or self.FadeOut > 0 or self.Time > 0 or self.Source == "Camera" or (self.AttachToObj and self.Spot ~= "") or self.Cooldown > 0 then
		return true
	end
	return false
end

---
--- Plays an ActionFXSound for the given actor and target.
---
--- If the `Sound` or `DistandSound` properties are empty, or `DisableSoundFX` is true, the function will return without doing anything.
---
--- If the `Cooldown` property is greater than 0, the function will check if an FX has been assigned to the actor and target. If an FX has been assigned and the time since it was assigned is less than the `Cooldown` property, the function will return without doing anything.
---
--- The function will determine the location to play the sound based on the `Source` property. If the `Source` is not "UI" or "Camera", the function will call `GetLoc` to get the count, object, spot, and position to play the sound. If the count is 0, the function will return without doing anything.
---
--- If the `Delay` property is 0 or less, the function will call `PlaceFXSound` to play the sound. Otherwise, the function will create a new thread to sleep for the `Delay` time and then call `PlaceFXSound`.
---
--- If the `TrackFX` function returns true, the function will call `DestroyFX` to destroy any existing FX for the actor and target, and then assign a new FX with the created thread.
---
--- @param actor table The actor object
--- @param target table The target object
--- @param action_pos table The position of the action
--- @param action_dir table The direction of the action
function ActionFXSound:PlayFX(actor, target, action_pos, action_dir)
	if self.Sound == "" and self.DistandSound == "" or DisableSoundFX then
		return
	end
	if self.Cooldown > 0 then
		local fx = self:GetAssignedFX(actor, target)
		if fx and fx.time and RealTime() - fx.time < self.Cooldown then
			return
		end
	end
	local count, obj, posx, posy, posz, spot
	local source = self.Source
	if source ~= "UI" and source ~= "Camera" then
		count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
		if count == 0 then
			--print("FX Sound with bad position:", self.Sound, "\n\t- Actor:", actor and actor.class, "\n\t- Target:", target and target.class)
			return
		end
	end
	if self.Delay <= 0 then
		self:PlaceFXSound(actor, target, count, obj, spot, posx, posy, posz)
		return
	end
	local thread = self:CreateThread(function(self, ...)
		Sleep(self.Delay)
		self:PlaceFXSound(...)
	end, self, actor, target, count, obj, spot, posx, posy, posz)
	if self:TrackFX() then
		local fx = self:DestroyFX(actor, target)
		if not fx then
			fx = {}
			self:AssignFX(actor, target, fx)
		end
		fx.thread = thread
	end
end

local function WaitDestroyFX(self, fx, actor, target)
	Sleep(self.Time)
	if fx.thread == CurrentThread() then
		self:DestroyFX(actor, target)
	end
end

--- Plays an FX sound for the given actor and target.
---
--- @param actor table The actor object
--- @param target table The target object
--- @param count number The number of sound instances to play
--- @param obj table The object to attach the sound to
--- @param spot table The position of the sound
--- @param posx number The x-coordinate of the sound position
--- @param posy number The y-coordinate of the sound position
--- @param posz number The z-coordinate of the sound position
function ActionFXSound:PlaceFXSound(actor, target, count, obj, spot, posx, posy, posz)
	local handle, err
	local source = self.Source
	if source == "UI" or source == "Camera" then
		handle, err = PlaySound(self.Sound, nil, self.FadeIn)
	else
		if Platform.developer then
			-- Make the check for positional sounds only if we have .Sound (removed on non-dev and xbox)
			local sounds = SoundPresets
			if sounds and next(sounds) then
				local sound = self.Sound
				if sound == "" then
					sound = self.DistantSound
				end
				local snd = sounds[sound]
				if not snd then
					printf('once', 'FX sound not found "%s"', sound)
					return
				end
				local snd_type = SoundTypePresets[snd.type]
				if not snd_type then
					printf('once', 'FX sound type not found "%s"', snd.type)
					return
				end
				local positional = snd_type.positional
				if not positional then
					printf('once', 'FX non-positional sound "%s" (type "%s") played on Source position: %s', sound, snd.type, source)
					return
				end
			end
		end
		if (count or 1) == 1 then
			handle, err = self:PlaceSingleFXSound(actor, target, 1, obj, spot, posx, posy, posz)
		else
			for i = 0, count - 1 do
				local h, e = self:PlaceSingleFXSound(actor, target, i + 1, obj, unpack_params(spot, 8*i+1, 8*i+4))
				if h then
					handle = handle or {}
					table.insert(handle, h)
				else
					err = e
				end
			end
		end
	end
	if DebugFXSound and (type(DebugFXSound) ~= "string" or IsKindOf(obj or actor, DebugFXSound)) then
		printf('FX sound %s "%s",<tab 450>matching: %s - %s - %s - %s', handle and "play" or "fail", self.Sound, self.Action, self.Moment, self.Actor, self.Target)
		if not handle and err then
			print("   FX sound error:", err)
		end
	end
	if not handle then
		return
	end
	if self.Cooldown <= 0 and not self:TrackFX() then
		return
	end
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		fx = {}
		self:AssignFX(actor, target, fx)
	end
	if self.Cooldown > 0 then
		fx.time = RealTime()
	end
	if self:TrackFX() then
		fx.sound_handle = handle
		fx.fade_out = self.FadeOut
		if source == "Camera" and FXCameraSounds then
			FXCameraSounds[fx] = true
			-- "persist" camera sounds (restart them upon loading game) if they have a rule to stop them, e.g. rain sounds
			if self.EndRules and next(self.EndRules) then
				fx.Sound = self.Sound
			end
		end
		if self.Time <= 0 then
			return
		end
		fx.thread = self:CreateThread(WaitDestroyFX, self, fx, actor, target)
	end
end

---
--- Returns an error message if no sound is specified for the ActionFXSound.
---
--- @return string error message
function ActionFXSound:GetError()
	if (self.Sound or "") == "" and (self.DistantSound or "") == "" then
		return "No sound specified"
	end
end

---
--- Replaces the sound specified in the ActionFXSound with a project-specific sound.
---
--- @param sound string The original sound to be replaced.
--- @param actor table The actor associated with the ActionFXSound.
--- @return string The replaced sound, or the original sound if no replacement is specified.
---
function ActionFXSound:GetProjectReplace(sound, actor)
	return sound
end

---
--- Places a single sound effect for an ActionFXSound.
---
--- @param actor table The actor associated with the ActionFXSound.
--- @param target table The target associated with the ActionFXSound.
--- @param idx number The index of the sound effect.
--- @param obj table The object to attach the sound effect to.
--- @param spot string The attachment spot on the object.
--- @param posx number The x-coordinate of the sound effect position.
--- @param posy number The y-coordinate of the sound effect position.
--- @param posz number The z-coordinate of the sound effect position.
---
function ActionFXSound:PlaceSingleFXSound(actor, target, idx, obj, spot, posx, posy, posz)
	if obj and (not IsValid(obj) or not obj:IsValidPos()) then
		return
	end
	local sound = self.Sound or ""
	local distant_sound = self.DistantSound or ""
	local distant_radius  = self.DistantRadius 
	if distant_sound ~= "" and distant_radius > 0 then
		local x, y = posx, posy
		if obj then
			x, y = obj:GetVisualPosXYZ()
		end
		if not IsCloser2D(camera.GetPos(), x, y, distant_radius) then
			sound = distant_sound
		end
	end
	if sound == "" then return end
	
	sound = self:GetProjectReplace(sound, actor)-- give it a chance ot be replaced by project specific logic

	local handle, err
	if not obj then
		return PlaySound(sound, nil, self.FadeIn, false, point(posx, posy, posz or const.InvalidZ))
	elseif not self.AttachToObj then
		if self.Spot == "" and self.Offset == point30 then
			return PlaySound(sound, nil, self.FadeIn, false, obj)
		else
			return PlaySound(sound, nil, self.FadeIn, false, point(posx, posy, posz or const.InvalidZ))
		end
	elseif self.Spot == "" and self.Offset == point30 then
		local sname, sbank, stype, shandle, sduration, stime = obj:GetSound()
		if not self.SkipSame or sound ~= sbank then
			if sound ~= sbank or stime ~= GameTime() or self:TrackFX() then
				dbg(MarkObjSound(self, obj, sound))
				obj:SetSound(sound, 1000, self.FadeIn)
			end
		end
	else
		local sound_dummy
		if idx == 1 then
			self:DestroyFX(actor, target)
		end
		local fx = self:GetAssignedFX(actor, target)
		if fx then
			local list = fx.sound_dummies
			for i = list and #list or 0, 1, -1 do
				local o = list[i]
				if o:GetAttachSpot() == spot then
					sound_dummy = o
					break
				end
			end
		else
			fx = {}
			if self:TrackFX() then
				self:AssignFX(actor, target, fx)
			end
		end
		if not sound_dummy or not IsValid(sound_dummy) then
			sound_dummy = PlaceObject("SoundDummy")
			fx.sound_dummies = fx.sound_dummies or {}
			table.insert(fx.sound_dummies, sound_dummy)
		end
		if spot then
			obj:Attach(sound_dummy, spot)
		else
			obj:Attach(sound_dummy)
		end

		dbg(MarkObjSound(self, sound_dummy, sound))
		sound_dummy:SetAttachOffset(self.Offset)
		sound_dummy:SetSound(sound, 1000, self.FadeIn)
	end
end

---
--- Destroys the sound effects associated with the ActionFX object.
---
--- @param actor table The actor object associated with the ActionFX.
--- @param target table The target object associated with the ActionFX.
--- @return table The ActionFX object that was destroyed.
---
function ActionFXSound:DestroyFX(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if self.AttachToObj then
		if self.Spot == "" then
			local obj = self:GetLocObj(actor, target)
			if IsValid(obj) then
				obj:StopSound(self.FadeOut)
			end
		else
			if not fx then return end
			local list = fx.sound_dummies
			for i = list and #list or 0, 1, -1 do
				local o = list[i]
				if not IsValid(o) then
					table.remove(list, i)
				else
					o:StopSound(self.FadeOut)
				end
			end
		end
	else
		if not fx then return end
		if FXCameraSounds then
			FXCameraSounds[fx] = nil
		end
		local handle = fx.sound_handle
		if handle then
			if type(handle) == "table" then
				for i = 1, #handle do
					SetSoundVolume(handle[i], -1, self.FadeOut) -- -1 means destroy
				end
			else
				SetSoundVolume(handle, -1, self.FadeOut) -- -1 means destroy
			end
			fx.sound_handle = nil
		end
		if fx.thread and fx.thread ~= CurrentThread() then
			DeleteThread(fx.thread)
			fx.thread = nil
		end
	end
	return fx
end

if FirstLoad then
	l_snd_test_handle = false
end

--- Plays a sound effect for testing purposes.
---
--- @param editor_obj table The editor object associated with the ActionFXSound.
--- @param fx table The ActionFXSound object.
--- @param prop_id string The property ID of the ActionFXSound.
function TestActionFXSound(editor_obj, fx, prop_id)
	StopActionFXSound()
	l_snd_test_handle = PlaySound(fx.Sound)
end

--- Stops the sound effect that was played for testing purposes.
---
--- This function is used to stop the sound effect that was previously played by the `TestActionFXSound` function.
function StopActionFXSound()
	if l_snd_test_handle then
		StopSound(l_snd_test_handle)
		l_snd_test_handle = false
	end
end

----

--============================= Wind Mod FX =======================

local function custom_mod_no_edit(self)
	return #(self.Presets or "") > 0
end
local function no_obj_or_attach_no_edit(self)
	return self.AttachToObj or self.Source ~= "Actor" and self.Source ~= "Target"
end
local function attach_no_edit(self)
	return self.AttachToObj
end

DefineClass.ActionFXWindMod = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Wind Mod", id = "Source", default = "Actor", editor = "dropdownlist", items = { "UI", "Actor", "Target", "ActionPos", "Camera" }, help = "Sound mod object or position." },
		{ category = "Wind Mod", id = "AttachToObj", name = "Attach To Source", editor = "bool", default = false, no_edit = no_obj_no_edit, help = "Attach to the actor or target (the Source) and move with it." },
		{ category = "Wind Mod", id = "Spot", default = "", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, no_edit = no_obj_or_attach_no_edit },
		{ category = "Wind Mod", id = "Offset", default = point30, editor = "point", scale = "m", no_edit = attach_no_edit, help = "Offset against source" },	
		{ category = "Wind Mod", id = "OffsetDir", default = "SourceAxisX", no_edit = attach_no_edit, editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end, },
		{ category = "Wind Mod", id = "ModBySpeed", default = false, no_edit = no_obj_no_edit, editor = "bool", help = "Modify the wind strength by the speed of the object" },
		{ category = "Wind Mod", id = "ModBySize", default = false, no_edit = no_obj_no_edit, editor = "bool", help = "Modify the wind radius by the size of the object" },
		{ category = "Wind Mod", id = "OnTerrainOnly", default = true, editor = "bool", help = "Allow the wind mod only on terrain" },
		
		{ category = "Wind Mod", id = "Presets", default = false, editor = "string_list", items = function() return table.keys(WindModifierParams, true) end, buttons = {{name = "Test", func = "TestActionFXWindMod"}, {name = "Stop", func = "StopActionFXWindMod"}, {name = "Draw Debug", func = "DbgWindMod"}}},
		{ category = "Wind Mod", id = "AttachOffset",     name = "Offset", default = point30, editor = "point", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "HalfHeight",       name = "Capsule half height", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "Range",            name = "Capsule inner radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Min range of action (vertex deformation) 100%" },
		{ category = "Wind Mod", id = "OuterRange",       name = "Capsule outer radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Max range of action (vertex deformation)" },
		{ category = "Wind Mod", id = "Strength",         name = "Strength", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit, help = "Strength vertex deformation" },
		{ category = "Wind Mod", id = "ObjHalfHeight",    name = "Obj Capsule half height", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjRange",         name = "Obj Capsule inner radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjOuterRange",    name = "Obj Capsule outer radius", default = guim, scale = "m", editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "ObjStrength",      name = "Obj Strength", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit, help = "Patch deform" },
		{ category = "Wind Mod", id = "SizeAttenuation",  name = "Size Attenuation", default = 5000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "HarmonicConst",    name = "Frequency", default = 10000, scale = 1000, editor = "number", no_edit = custom_mod_no_edit},
		{ category = "Wind Mod", id = "HarmonicDamping",  name = "Damping ratio", default = 800, scale = 1000, editor = "number", no_edit = custom_mod_no_edit },
		{ category = "Wind Mod", id = "WindModifierMask", name = "Modifier Mask", default = -1, editor = "flags", size = function() return #(const.WindModifierMaskFlags or "") end, items = function() return const.WindModifierMaskFlags end, no_edit = custom_mod_no_edit },

	},
	fx_type = "Wind Mod",
	SpotsPercent = -1,
	GameTime = true,
}

---
--- Determines whether the ActionFXWindMod instance should track the FX.
---
--- If the instance has behaviors or a non-zero Time value, it will return true, indicating that the FX should be tracked.
--- Otherwise, it will return false, indicating that the FX does not need to be tracked.
---
--- @return boolean True if the FX should be tracked, false otherwise.
function ActionFXWindMod:TrackFX()
	if self.behaviors or self.Time > 0 then
		return true
	end
	return false
end

---
--- Toggles the debug visualization for the wind modifier.
---
--- This function is used to enable or disable the debug visualization for the wind modifier.
--- When the debug visualization is enabled, it will display visual indicators for the wind modifier's properties, such as the capsule size and strength.
---
--- @param fx ActionFXWindMod The wind modifier instance to toggle the debug visualization for.
---
function ActionFXWindMod:DbgWindMod(fx)
	hr.WindModifierDebug = 1 - hr.WindModifierDebug
end

---
--- Plays the wind modifier effect for the given actor, target, and action position/direction.
---
--- If the wind modifier has a delay, it will create a thread to play the effect after the delay.
--- If the wind modifier should be tracked, it will assign the effect to the actor and target, and store the thread in the effect.
---
--- @param actor table The actor that the wind modifier is attached to.
--- @param target table The target that the wind modifier is affecting.
--- @param action_pos table The position of the action that triggered the wind modifier.
--- @param action_dir table The direction of the action that triggered the wind modifier.
---
function ActionFXWindMod:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		return
	end
	if self.OnTerrainOnly and not posz then
		return
	end
	if self.Delay <= 0 then
		self:PlaceFXWindMod(actor, target, count, obj, spot, posx, posy, posz)
		return
	end
	local thread = self:CreateThread(function(self, ...)
		Sleep(self.Delay)
		self:PlaceFXWindMod(...)
	end, self, actor, target, count, obj, spot, posx, posy, posz)
	if self:TrackFX() then
		local fx = self:DestroyFX(actor, target)
		if not fx then
			fx = {}
			self:AssignFX(actor, target, fx)
		end
		fx.thread = thread
	end
end

local function PlaceSingleFXWindMod(params, attach_to, pos, range_mod, strength_mod, speed_mod)
	return terrain.SetWindModifier(
		(pos or point30):Add(params.AttachOffset or point30),
		params.HalfHeight,
		range_mod and params.Range * range_mod / guim or params.Range,
		range_mod and params.OuterRange * range_mod / guim or params.OuterRange,
		strength_mod and params.Strength * strength_mod / guim or params.Strength,
		params.ObjHalfHeight,
		range_mod and params.ObjRange * range_mod / guim or params.ObjRange,
		range_mod and params.ObjOuterRange * range_mod / guim or params.ObjOuterRange,
		strength_mod and params.ObjStrength * strength_mod / guim or params.ObjStrength,
		params.SizeAttenuation,
		speed_mod and params.HarmonicConst * speed_mod / 1000 or params.HarmonicConst,
		speed_mod and params.HarmonicDamping * speed_mod / 1000 or params.HarmonicDamping,
		0,
		0,
		params.WindModifierMask or -1,
		attach_to)
end
	
---
--- Places a wind modifier effect at the specified position, with optional modifiers for range, strength, and speed.
---
--- @param actor table The actor that is triggering the wind modifier effect.
--- @param target table The target that the wind modifier is affecting.
--- @param count number The number of wind modifier effects to place.
--- @param obj table The object that the wind modifier is attached to.
--- @param spot table The position of the wind modifier effect.
--- @param posx number The x-coordinate of the wind modifier effect position.
--- @param posy number The y-coordinate of the wind modifier effect position.
--- @param posz number The z-coordinate of the wind modifier effect position.
--- @param range_mod number (optional) A modifier for the range of the wind effect.
--- @param strength_mod number (optional) A modifier for the strength of the wind effect.
--- @param speed_mod number (optional) A modifier for the speed of the wind effect.
--- @return table The IDs of the placed wind modifier effects.
function ActionFXWindMod:PlaceFXWindMod(actor, target, count, obj, spot, posx, posy, posz, range_mod, strength_mod, speed_mod)
	range_mod = range_mod or self.ModBySize and obj and obj:GetRadius()
	strength_mod = strength_mod or self.ModBySpeed and obj and obj:GetSpeed()
	speed_mod = speed_mod or self.GameTime and GetTimeFactor()
	if speed_mod <= 0 then
		speed_mod = false
	end
	
	local attach_to = self.AttachToObj and obj
	local pos = point30
	if not attach_to then
		pos = point(posx, posy, posz)
	end
	
	local ids
	if #(self.Presets or "") == 0 then
		ids = PlaceSingleFXWindMod(self, attach_to, pos, range_mod, strength_mod, speed_mod)
	else
		for _, preset in ipairs(self.Presets) do
			local params = WindModifierParams[preset]
			if params then
				local id = PlaceSingleFXWindMod(params, attach_to, pos, range_mod, strength_mod, speed_mod)
				if not ids then
					ids = id
				elseif type(ids) == "table" then
					ids[#ids + 1] = id
				else
					ids = { ids, id }
				end
			end
		end
	end

	if not ids or not self:TrackFX() then
		return
	end
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		fx = {}
		self:AssignFX(actor, target, fx)
	end
	fx.wind_mod_ids = ids
	if self.Time <= 0 then
		return
	end
	fx.thread = self:CreateThread(WaitDestroyFX, self, fx, actor, target)
end

--- Destroys the wind modifier effects associated with the specified actor and target.
---
--- @param actor table The actor object.
--- @param target table The target object.
--- @return table The assigned FX table, or nil if no FX was assigned.
function ActionFXWindMod:DestroyFX(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	local wind_mod_ids = self.wind_mod_ids
	if wind_mod_ids then
		if type(wind_mod_ids) == "number" then
			terrain.RemoveWindModifier(wind_mod_ids)
		else
			for _, id in ipairs(wind_mod_ids) do
				terrain.RemoveWindModifier(id)
			end
		end
		fx.wind_mod_ids = nil
	end
	if fx.thread and fx.thread ~= CurrentThread() then
		DeleteThread(fx.thread)
		fx.thread = nil
	end
	return fx
end

if FirstLoad then
	l_windmod_test_id = false
end

---
--- Triggers a wind modifier effect for the selected object.
---
--- @param editor_obj table The editor object.
--- @param fx table The ActionFXWindMod instance.
--- @param prop_id string The property ID.
---
function TestActionFXWindMod(editor_obj, fx, prop_id)
	StopActionFXWindMod()
	local obj = selo() or SelectedObj
	if not IsValid(obj) then
		print("No object selected!")
		return
	end
	local actor, target, count, spot
	local x, y, z = obj:GetVisualPosXYZ()
	l_windmod_test_id = fx:PlaceFXWindMod(actor, target, count, obj, spot, x, y, z, nil, nil, 1000) or false
end

---
--- Stops the wind modifier effect that was triggered by the `TestActionFXWindMod` function.
---
--- This function removes the wind modifier that was previously placed using the `PlaceFXWindMod` function.
---
--- @return nil
function StopActionFXWindMod()
	if l_windmod_test_id then
		terrain.RemoveWindModifier(l_windmod_test_id)
		l_windmod_test_id = false
	end
end

----

DefineClass.ActionFXUIParticles = {
	__parents = {"ActionFX"},
	properties = {
		{ id = "Particles", category = "Particles", default = "", editor = "combo", items = UIParticlesComboItems },
		{ id = "Foreground", category = "Particles", default = false, editor = "bool" },
		{ id = "HAlign", category = "Particles", default = "middle", editor = "choice", items = function() return GetUIParticleAlignmentItems(true) end },
		{ id = "VAlign", category = "Particles", default = "middle", editor = "choice", items = function() return GetUIParticleAlignmentItems(false) end },
		{ id = "TransferToParent", category = "Lifetime", default = false, editor = "bool", help = "Should particles continue to live after the host control dies?" },
		{ id = "StopEmittersOnTransfer", category = "Lifetime", default = true, editor = "bool", no_edit = function(self) return not self.TransferToParent end },
		{ id = "GameTime", editor = false },
	},
	Time = -1,
	fx_type = "UI Particles",
}

---
--- Tracks the UI particles effect.
---
--- @return boolean true
---
function ActionFXUIParticles:TrackFX()
	return true
end

---
--- Plays a UI particles effect.
---
--- This function creates and assigns a UI particles effect to the specified actor. The particles effect is defined by the properties of the `ActionFXUIParticles` class, such as the particle system to use, alignment, and lifetime.
---
--- If a delay is specified, the particles effect will be created after the delay has elapsed, as long as the actor's window is still open.
---
--- @param actor XControl The actor to apply the particles effect to.
--- @param target any The target object for the particles effect.
--- @param action_pos vec3 The position of the action.
--- @param action_dir vec3 The direction of the action.
---
function ActionFXUIParticles:PlayFX(actor, target, action_pos, action_dir)
	assert(IsKindOf(actor, "XControl"))

	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end

	local create_particles = function(self, actor, target)
		local id = UIL.PlaceUIParticles(self.Particles)
		self:AssignFX(actor, target, function()
			actor:StopParticle(id)
		end)
		actor:AddParSystem(id, self.Particles, UIParticleInstance:new({
			foreground = self.Foreground,
			lifetime = self.Time,
			transfer_to_parent = self.TransferToParent,
			stop_on_transfer = self.StopEmittersOnTransfer,
			halign = self.HAlign,
			valign = self.VAlign,
		}))
	end

	if self.Delay > 0 then
		local delay_thread = CreateRealTimeThread(function(self, actor, target)
			Sleep(self.Delay)
			if actor.window_state == "open" then
				create_particles(self, actor, target)
			end
		end, self, actor, target)
		self:AssignFX(actor, target, function() DeleteThread(delay_thread) end)
	else
		create_particles(self, actor, target)
	end
end


---
--- Stops and removes the UI particles effect assigned to the specified actor and target.
---
--- This function retrieves the assigned particles effect for the given actor and target, and stops and removes it. It returns false to indicate that the effect has been destroyed.
---
--- @param actor XControl The actor to remove the particles effect from.
--- @param target any The target object for the particles effect.
--- @return boolean false, indicating the effect has been destroyed.
---
function ActionFXUIParticles:DestroyFX(actor, target)
	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end
	return false
end


DefineClass.ActionFXUIShaderEffect = {
	__parents = {"ActionFX"},
	properties = {
		{ id = "EffectId", category = "FX", default = "", editor = "preset_id", preset_class = "UIFxModifierPreset" },
		{ id = "GameTime", editor = false },
	},
	Time = -1,
	fx_type = "UI Effect",
}

---
--- Indicates whether the UI shader effect should be tracked.
---
--- This function returns true to indicate that the UI shader effect should be tracked.
---
--- @return boolean true, indicating the UI shader effect should be tracked.
---
function ActionFXUIShaderEffect:TrackFX()
	return true
end

---
--- Plays a UI shader effect on the specified actor and target.
---
--- This function sets the UI effect modifier ID on the actor, and optionally creates a real-time thread to destroy the effect after a specified delay. If a delay is specified, the effect is only played if the actor's window state is "open". The function also assigns a cleanup function to the actor and target, which is called when the effect is destroyed.
---
--- @param actor XFxModifier The actor to apply the UI shader effect to.
--- @param target any The target object for the UI shader effect.
--- @param action_pos Vector3 The position of the action.
--- @param action_dir Vector3 The direction of the action.
---
function ActionFXUIShaderEffect:PlayFX(actor, target, action_pos, action_dir)
	assert(IsKindOf(actor, "XFxModifier"))

	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end

	local old_fx_id = actor.EffectId
	local play_fx_impl = function(self, actor, target)
		actor:SetUIEffectModifierId(self.EffectId)
		if self.Time > 0 then
			CreateRealTimeThread(function(self, actor, target)
				Sleep(self.Time)
				self:DestroyFX(actor, target)
			end, self, actor, target)
		end
	end

	local delay_thread = false
	if self.Delay > 0 then
		delay_thread = CreateRealTimeThread(function(self, actor, target)
			Sleep(self.Delay)
			if actor.window_state == "open" then
				play_fx_impl(self, actor, target)
			end
		end, self, actor, target)
	else
		play_fx_impl(self, actor, target)
	end
	self:AssignFX(actor, target, function()
		if delay_thread then
			DeleteThread(delay_thread)
		end
		if actor.UIEffectModifierId == self.EffectId then
			actor:SetUIEffectModifierId(old_fx_id)
		end
	end)
end


--- Destroys the UI shader effect assigned to the specified actor and target.
---
--- This function retrieves the assigned cleanup function for the UI shader effect, and calls it if it exists. This effectively destroys the UI shader effect that was previously applied to the actor and target.
---
--- @param actor XFxModifier The actor to destroy the UI shader effect for.
--- @param target any The target object for the UI shader effect.
--- @return boolean Always returns false.
function ActionFXUIShaderEffect:DestroyFX(actor, target)
	local stop_fx = self:GetAssignedFX(actor, target)
	if stop_fx then
		stop_fx()
	end
	return false
end


--======================= Particles FX =======================

DefineClass.ActionFXParticles = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Particles", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles2", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles3", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Particles4", category = "Particles", default = "", editor = "combo", items = ParticlesComboItems, buttons = {{name = "Test", func = "TestActionFXParticles"}, {name = "Edit", func = "ActionEditParticles"}}},
		{ id = "Flags", category = "Particles", default = "", editor = "dropdownlist", items = { "", "OnGround", "LockedOrientation", "Mirrored", "OnGroundTiltByGround" } },
		{ id = "AlwaysVisible", category = "Particles", default = false, editor = "bool", },
		{ id = "Scale", category = "Particles", default = 100, editor = "number" },
		{ id = "ScaleMember", category = "Particles", default = "", editor = "text" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos", "Camera" }, help = "Particles source object or position" },
		{ id = "SourceProp", category = "Placement", default = "", editor = "combo", items = function(fx) return ActionFXSourcePropCombo() end, help = "Source object property object" },
		{ id = "Spot", category = "Placement", default = "Origin", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end, help = "Particles source object spot" },
		{ id = "SpotsPercent", category = "Placement", default = -1, editor = "number", help = "Percent of random spots that should be used. One random spot is used when the value is negative." },
		{ id = "Attach", category = "Placement", default = false, editor = "bool", help = "Set true if the particles should move with the source" },
		{ id = "SingleAttach", category = "Placement", default = false, editor = "bool", help = "When enabled the FX will not place a new particle on the same spot if there is already one attached there. Only valid with Attach enabled." },
		{ id = "Offset", category = "Placement", default = point30, editor = "point", scale = "m", help = "Offset against source object" },
		{ id = "OffsetDir", category = "Placement", default = "SourceAxisX", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },		
		{ id = "Orientation", category = "Placement", default = "", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "PresetOrientationAngle", category = "Placement", default = 0, editor = "number", },
		{ id = "OrientationAxis", category = "Placement", default = 1, editor = "dropdownlist", items =  function(fx) return OrientationAxisCombo end },
		{ id = "FollowTick", category = "Particles", default = 100, editor = "number" },
		{ id = "UseActorColorModifier", category = "Particles", default = false, editor = "bool", help = "If true, parsys:SetColorModifer(actor). If false, sets dynamic param 'color_modifier' to the actor's color" },
	},
	fx_type = "Particles",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and places particle systems when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties.",
	DocumentationLink = "Docs/ModItemActionFXParticles.md.html"
}

local function no_dynamic(prop, param_type)
	return function(self)
		local name = self[prop]
		if name == ""  then return true end
		local params = ParGetDynamicParams(self.Particles)
		local par_type = params[name]
		return not par_type or par_type.type ~= param_type
	end
end

local fx_particles_dynamic_params = 4
local fx_particles_dynamic_names = {}
local fx_particles_dynamic_values = {}
local fx_particles_dynamic_colors = {}
local fx_particles_dynamic_points = {}

for i = 1, fx_particles_dynamic_params do
	local prop = "DynamicName"..i
	fx_particles_dynamic_names[i] = prop
	fx_particles_dynamic_values[i] = "DynamicValue"..i
	fx_particles_dynamic_colors[i] = "DynamicColor"..i
	fx_particles_dynamic_points[i] = "DynamicPoint"..i
	table.insert(ActionFXParticles.properties, { id = prop, category = "Particles", name = "Name", editor = "text", default = "", read_only = true, no_edit = function(self) return self[prop] == "" end })
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_values[i], category = "Particles", name = "Value", editor = "number", default = 1, no_edit = no_dynamic(prop, "number")})
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_colors[i], category = "Particles", name = "Color", editor = "color", default = 0, no_edit = no_dynamic(prop, "color")})
	table.insert(ActionFXParticles.properties, { id = fx_particles_dynamic_points[i], category = "Particles", name = "Point", editor = "point", default = point(0,0), no_edit = no_dynamic(prop, "point")})
	
end

---
--- Callback function that is called when a property of the ActionFXParticles object is set in the editor.
--- This function updates the dynamic parameters of the particle system when the "Particles" property is changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor GUI object.
---
function ActionFXParticles:OnEditorSetProperty(prop_id, old_value, ged)
	ActionFX.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Particles" then
		self:UpdateDynamicParams()
	end	
end

---
--- Callback function that is called when the ActionFXParticles object is selected in the editor.
--- This function updates the dynamic parameters of the particle system when the object is selected.
---
--- @param selected boolean Whether the object was selected or deselected.
--- @param ged table The editor GUI object.
---
function ActionFXParticles:OnEditorSelect(selected, ged)
	if selected then
		self:UpdateDynamicParams()
	end
end

---
--- Updates the dynamic parameters of the particle system when the "Particles" property is changed.
---
--- This function iterates through the dynamic parameters defined in the `fx_particles_dynamic_params` variable,
--- and updates the corresponding properties of the `ActionFXParticles` object with the names and descriptions
--- of the dynamic parameters. It also removes any unused dynamic parameter properties.
---
--- @param self ActionFXParticles The `ActionFXParticles` object whose dynamic parameters are being updated.
---
function ActionFXParticles:UpdateDynamicParams()
	g_DynamicParamsDefs = {}
	local params = ParGetDynamicParams(self.Particles)
	local n = 1
	for name, desc in sorted_pairs(params) do
			self[ fx_particles_dynamic_names[n] ] = name
			n = n + 1
			if n > fx_particles_dynamic_params then
				break
			end
	end
	for i = n, fx_particles_dynamic_params do
		self[ fx_particles_dynamic_names[i] ] = nil
	end
end

---
--- Checks if the given particle system is eternal (i.e. has no defined duration).
---
--- @param par table|table[] The particle system(s) to check.
--- @return boolean True if the particle system is eternal, false otherwise.
---
function ActionFXParticles:IsEternal(par)
	if IsValid(par) then
		return IsParticleSystemEternal(par)
	elseif IsValid(par[1]) then
		return IsParticleSystemEternal(par[1])
	end
end

---
--- Gets the duration of the given particle system.
---
--- @param par table|table[] The particle system(s) to get the duration of.
--- @return number The duration of the particle system, or 0 if the particle system is invalid.
---
function ActionFXParticles:GetDuration(par)
	if IsValid(par) then
		return GetParticleSystemDuration(par)
	elseif par and IsValid(par[1]) then
		return GetParticleSystemDuration(par[1])
	end
	return 0
end

---
--- Plays the FX particles associated with the `ActionFXParticles` object.
---
--- @param actor table The actor object that the FX particles are associated with.
--- @param target table The target object that the FX particles are associated with.
--- @param action_pos table The position of the action that the FX particles are associated with.
--- @param action_dir table The direction of the action that the FX particles are associated with.
---
function ActionFXParticles:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		if self.SourceProp ~= "" then
			printf("FX Particles %s (id %s) has invalid source %s with property: %s", self.Particles, self.id, self.Source, self.SourceProp)
		else
			printf("FX Particles %s (id %s) has invalid source: %s", self.Particles, self.id, self.Source)
		end
		return
	end
	local par
	if self.Delay <= 0 then
		par = self:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
		if not par then
			return
		end
		self:TrackParticle(par, actor, target, action_pos, action_dir)
		if self.Time <= 0 and self:IsEternal(par) then
			return
		end
	end
	local thread = self:CreateThread(function(self, actor, target, action_pos, action_dir, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, par)
		if self.Delay > 0 then
			Sleep(self.Delay)
			if self.Attach then
				-- NOTE: spot here should be recalculated as the anim can change in the meanwhile
				count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
			end
			par = self:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
			if not par then
				return
			end
			self:TrackParticle(par, actor, target, action_pos, action_dir)
		end
		if par and (self.Time > 0 or not self:IsEternal(par)) then
			if self.Time > 0 then
				Sleep(self.Time)
			else
				Sleep(self:GetDuration(par))
			end
			if par == self:GetAssignedFX(actor, target) then
				self:AssignFX(actor, target, nil)
			end
			if IsValid(par) then
				StopParticles(par, true)
			else
				for _, p in ipairs(par) do
					if IsValid(p) then
						StopParticles(p, true)
					end
				end
			end
		end
	end, self, actor, target, action_pos, action_dir, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, par)
	if not par and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

---
--- Checks if the ActionFXParticles object has any dynamic parameters.
---
--- Dynamic parameters are parameters that can be set at runtime and affect the behavior of the particle effects.
---
--- @return boolean true if the object has dynamic parameters, false otherwise
---
function ActionFXParticles:HasDynamicParams()
	local params = ParGetDynamicParams(self.Particles)
	if next(params) then
		for i = 1, fx_particles_dynamic_params do
			local name = self[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			if params[name] then
				return true
			end
		end
	end
end

local function IsAttachedAtSpot(att, parent, spot)
	local att_spot = att:GetAttachSpot()
	if att_spot == (spot or -1) then
		return true
	end
	local att_spot_name = parent:GetSpotName(att_spot)
	local spot_name = spot and parent:GetSpotName(spot) or ""
	if spot_name == att_spot_name or (spot_name == "Origin" or spot_name == "") and (att_spot_name == "Origin" or att_spot_name == "") then
		return true
	end
	return false
end

---
--- Places one or more FX particle effects at the specified location.
---
--- @param count number The number of particle effects to place.
--- @param obj table The object to attach the particle effects to, if any.
--- @param spot number The attachment spot on the object to place the particle effects.
--- @param posx number The X coordinate to place the particle effects.
--- @param posy number The Y coordinate to place the particle effects.
--- @param posz number The Z coordinate to place the particle effects.
--- @param angle number The angle to rotate the particle effects.
--- @param axisx number The X axis to rotate the particle effects around.
--- @param axisy number The Y axis to rotate the particle effects around.
--- @param axisz number The Z axis to rotate the particle effects around.
--- @return table|nil The table of placed particle effects, or nil if none were placed.
---
function ActionFXParticles:PlaceFXParticles(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if self.Attach and (not obj or not IsValid(obj)) then
		return
	end
	if count == 1 then
		return self:PlaceSingleFXParticles(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	end
	local par
	for i = 0, count - 1 do
		local p = self:PlaceSingleFXParticles(obj, unpack_params(spot, 8*i+1, 8*i+8))
		if p then
			par = par or {}
			table.insert(par, p)
		end
	end
	return par
end

---
--- Places a single FX particle effect at the specified location.
---
--- @param obj table The object to attach the particle effect to, if any.
--- @param spot number The attachment spot on the object to place the particle effect.
--- @param posx number The X coordinate to place the particle effect.
--- @param posy number The Y coordinate to place the particle effect.
--- @param posz number The Z coordinate to place the particle effect.
--- @param angle number The angle to rotate the particle effect.
--- @param axisx number The X axis to rotate the particle effect around.
--- @param axisy number The Y axis to rotate the particle effect around.
--- @param axisz number The Z axis to rotate the particle effect around.
--- @return table|nil The placed particle effect, or nil if none was placed.
---
function ActionFXParticles:PlaceSingleFXParticles(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	local particles, particles2, particles3, particles4 = self.Particles, self.Particles2, self.Particles3, self.Particles4
	local parVariations = {}
	
	if (particles or "")~="" then table.insert(parVariations,particles) end
	if (particles2 or "")~="" then table.insert(parVariations,particles2) end
	if (particles3 or "")~="" then table.insert(parVariations,particles3) end
	if (particles4 or "")~="" then table.insert(parVariations,particles4) end
	
	particles = select(1,(table.rand(parVariations))) or ""
	
	if self.Attach and self.SingleAttach then
		local count = obj:CountAttaches(particles, IsAttachedAtSpot, obj, spot)
		if count > 0 then
			return
		end
	end
	if DebugFXParticles and (type(DebugFXParticles) ~= "string" or IsKindOf(obj, DebugFXParticles)) then
		printf('FX particles %s', particles)
	end
	if DebugFXParticlesName and DebugMatch(particles, DebugFXParticlesName) then
		printf('FX particles %s', particles)
	end
	local par = PlaceParticles(particles)
	if not par then return end
	if self.DetailLevel >= ParticleDetailLevelMax then
		par:SetImportant(true)
	end
	NetTempObject(par)
	local scale
	local scale_member = self.ScaleMember
	if scale_member ~= "" and obj and IsValid(obj) and obj:HasMember(scale_member) then
		scale = obj[scale_member]
		if scale and type(scale) == "function" then
			scale = scale(obj)
		end
	end
	scale = scale or self.Scale
	if scale ~= 100 then 
		par:SetScale(scale)
	end
	local flags = self.Flags
	if flags == "Mirrored" then
		par:SetMirrored(true)
	elseif flags == "LockedOrientation" then
		par:SetGameFlags(const.gofLockedOrientation)
	elseif flags == "OnGround" or flags == "OnGroundTiltByGround" then
		par:SetGameFlags(const.gofAttachedOnGround)
	end
	
	-- fill in dynamic parameters
	local dynamic_params = ParGetDynamicParams(particles)
	if next(dynamic_params) then
		for i = 1, fx_particles_dynamic_params do
			local name = self[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			local def = dynamic_params[name]
			if def then
				if def.type == "color" then
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_colors[i]))
				elseif def.type == "point" then
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_points[i]))
				else
					par:SetParamDef(def, self:GetProperty(fx_particles_dynamic_values[i]))
				end
			end
		end
	end
	
	if self.AlwaysVisible then
		local obj_iter = obj or par
		while true do
			local parent = obj_iter:GetParent()
			if not parent then
				obj_iter:SetGameFlags(const.gofAlwaysRenderable)
				break
			end
			obj_iter = parent
		end
	end

	if obj then
		if self.UseActorColorModifier then
			par:SetColorModifier(obj:GetColorModifier())
		else
			local def = dynamic_params["color_modifier"]
			if def then
				par:SetParamDef(def, obj:GetColorModifier())
			end
		end
	end
	
	FXOrient(par, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)
	return par
end

---
--- Tracks a particle and assigns it to the specified actor and target. Optionally, executes a behavior based on the particle tracking.
---
--- @param par table The particle to track.
--- @param actor table The actor associated with the particle.
--- @param target table The target associated with the particle.
--- @param action_pos table The position of the action.
--- @param action_dir table The direction of the action.
---
function ActionFXParticles:TrackParticle(par, actor, target, action_pos, action_dir)
	if self:TrackFX() then
		self:AssignFX(actor, target, par)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
end

---
--- Destroys the particle effects associated with the given actor and target.
---
--- @param actor table The actor associated with the particle effects.
--- @param target table The target associated with the particle effects.
---
function ActionFXParticles:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		StopParticles(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				StopParticles(p)
			end
		end
	end
end

---
--- Detaches the particle effects associated with the given actor and target.
---
--- @param actor table The actor associated with the particle effects.
--- @param target table The target associated with the particle effects.
---
function ActionFXParticles:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		return
	elseif IsValidThread(fx) then
		printf("FX Particles %s Detach Behavior can not be run before particle placing", self.Particles, self.Delay)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				PreciseDetachObj(p)
			end
		end
	end
end

---
--- Detaches and destroys the particle effects associated with the given actor and target.
---
--- @param actor table The actor associated with the particle effects.
--- @param target table The target associated with the particle effects.
---
function ActionFXParticles:BehaviorDetachAndDestroy(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
		StopParticles(fx)
	elseif type(fx) == "table" and not getmetatable(fx) then
		for i = 1, #fx do
			local p = fx[i]
			if IsValid(p) then
				PreciseDetachObj(p)
				StopParticles(p)
			end
		end
	end
end

---
--- Follows the given actor and target with the assigned particle effects.
---
--- @param actor table The actor associated with the particle effects.
--- @param target table The target associated with the particle effects.
--- @param action_pos table The position of the action.
--- @param action_dir table The direction of the action.
---
function ActionFXParticles:BehaviorFollow(actor, target, action_pos, action_dir)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	local obj = self:GetLocObj(actor, target)
	if not obj then
		printf("FX Particles %s uses unsupported behavior/source combination: %s/%s", self.Particles, self.Behavior, self.Source)
		return
	end
	self:CreateThread(function(self, fx, actor, target, obj, tick)
		while IsValid(obj) and IsValid(fx) and self:GetAssignedFX(actor, target) == fx do
			local x, y, z = obj:GetSpotLocPosXYZ(-1)
			fx:SetPos(x, y, z, tick)
			Sleep(tick)
		end
	end, self, fx, actor, target, obj, self.FollowTick)
end

---
--- Edits the particle system associated with the given ActionFX.
---
--- @param editor_obj table The editor object associated with the ActionFX.
--- @param fx table The ActionFX containing the particle system to edit.
--- @param prop_id number The ID of the property to edit.
---
function ActionEditParticles(editor_obj, fx, prop_id)
	EditParticleSystem(fx.Particles)
end

---
--- Tests the particle effects associated with the given ActionFX.
---
--- @param editor_obj table The editor object associated with the ActionFX.
--- @param fx table The ActionFX containing the particle system to test.
--- @param prop_id number The ID of the property to edit.
---
function TestActionFXParticles(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	local obj = PlaceParticles(fx.Particles)
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	obj:SetScale(fx.Scale)
	if fx.Flags == "Mirrored" then
		obj:SetMirrored(true)
	elseif fx.Flags == "OnGround" then
		obj:SetGameFlags(const.gofAttachedOnGround)
	end

	-- fill in dynamic parameters
	local params = ParGetDynamicParams(fx.Particles)
	if next(params) then
		for i = 1, fx_particles_dynamic_params do
			local name = fx[ fx_particles_dynamic_names[i] ]
			if name == "" then break end
			if params[name] then
				local prop = (params[name].type == "color") and "DynamicColor" or "DynamicValue"
				local value = fx:GetProperty(prop .. i)
				obj:SetParam(name, value)
			end
		end
	end
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	local posx, posy, posz = look_at:xyz()
	FXOrient(obj, posx, posy, posz)

	editor_obj:CreateThread(function(obj)
		Sleep(5000)
		StopParticles(obj, true)
		TestActionFXObjectEnd(obj)
	end, obj)
end

--============================= Camera Shake FX =======================

DefineClass.ActionFXCameraShake = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Preset", category = "Camera Shake", default = "Custom", editor = "dropdownlist",
		  items = function(self) return table.keys2(self.presets) end, buttons = {{ name = "Test", func = "TestActionFXCameraShake" }},
		},
		{ id = "Duration", category = "Camera Shake", default = 700, editor = "number", min = 100, max = 2000, slider = true, },
		{ id = "Frequency", category = "Camera Shake", default = 25, editor = "number", min = 1, max = 100, slider = true, },
		{ id = "ShakeOffset", category = "Camera Shake", default = 30*guic, editor = "number", min = 1*guic, max = 100*guic, slider = true, scale = "cm", },
		{ id = "RollAngle", category = "Camera Shake", default = 0, editor = "number", min =  0, max = 30, slider = true, },
		{ id = "Source", category = "Camera Shake", default = "Actor", editor = "dropdownlist", items = { "Actor", "Target", "ActionPos" }, help = "Shake position or object position" },
		{ id = "Spot", category = "Camera Shake", default = "Origin", editor = "combo", items =  function(fx) return ActionFXSpotCombo(fx) end, help = "Shake position object spot" },
		{ id = "Offset", category = "Camera Shake", default = point30, editor = "point", scale = "m", help = "Shake position offset" },
		{ id = "ShakeRadiusInSight", category = "Camera Shake", default = const.ShakeRadiusInSight, editor = "number", scale = "m",
			name = "Fade radius (in sight)", help = "The distance from the source at which the camera shake fades out completely, if the source is in the camera view",
		},
		{ id = "ShakeRadiusOutOfSight", category = "Camera Shake", default = const.ShakeRadiusOutOfSight, editor = "number", scale = "m",
			name = "Fade radius (out of sight)", help = "The distance from the source at which the camera shake fades out completely, if the source is out of the camera view",
		},
		{ id = "Time", editor = false },
		{ id = "Behavior", editor = false },
		{ id = "BehaviorMoment", editor = false },
	},
	presets = {
		Custom = {},
		Light =  { Duration = 380, Frequency = 25, ShakeOffset =  6*guic, RollAngle = 3 },
		Medium = { Duration = 460, Frequency = 25, ShakeOffset = 12*guic, RollAngle = 6 },
		Strong = { Duration = 950, Frequency = 25, ShakeOffset = 15*guic, RollAngle = 9 },
	},
	fx_type = "Camera Shake",
}

---
--- Plays a camera shake effect.
---
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos point The position of the action.
--- @param action_dir point The direction of the action.
---
function ActionFXCameraShake:PlayFX(actor, target, action_pos, action_dir)
	if IsEditorActive() or EngineOptions.CameraShake == "Off" then return end
	
	local count, obj, spot, posx, posy, posz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Camera Shake has invalid source: %s", self.Source)
		return
	end
	local power
	if obj then
		if NetIsRemote(obj) then
			return -- camera shake FX is not applied for remote objects
		end
		if camera3p.IsActive() and camera3p.IsAttachedToObject(obj:GetParent() or obj) then
			power = 100
		end
	end
	power = power or posx and CameraShake_GetEffectPower(point(posx, posy, posz or const.InvalidZ), self.ShakeRadiusInSight, self.ShakeRadiusOutOfSight) or 0
	if power == 0 then
		return
	end
	if self.Delay <= 0 then
		self:Shake(actor, target, power)
		return
	end
	local thread = self:CreateThread(function(self, actor, target, power)
		Sleep(self.Delay)
		self:Shake(actor, target, power)
	end, self, actor, target, power)
	if self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

---
--- Destroys the camera shake effect associated with the given actor and target.
---
--- @param actor table The actor object.
--- @param target table The target object.
---
function ActionFXCameraShake:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
		local preset = self.presets[self.Preset]
		local frequency = preset and preset.Frequency or self.Frequency
		local shake_duration = frequency > 0 and Min(frequency, 200) or 0
		camera.ShakeStop(shake_duration)
	end
end

---
--- Shakes the camera based on the specified parameters.
---
--- @param actor table The actor object.
--- @param target table The target object.
--- @param power number The power of the camera shake effect, as a percentage.
---
function ActionFXCameraShake:Shake(actor, target, power)
	local preset = self.presets[self.Preset]
	local duration = self.Duration >= 0 and (preset and preset.Duration or self.Duration) * power / 100 or -1
	local frequency = preset and preset.Frequency or self.Frequency
	if frequency <= 0 then return end
	local shake_offset = (preset and preset.ShakeOffset or self.ShakeOffset) * power / 100
	local shake_roll = (preset and preset.RollAngle or self.RollAngle) * power / 100
	camera.Shake(duration, frequency, shake_offset, shake_roll)
	if self:TrackFX() then
		self:AssignFX(actor, target, camera3p_shake_thread )
	end
end

---
--- Sets the preset for the camera shake effect.
---
--- @param value string The name of the preset to use.
---
function ActionFXCameraShake:SetPreset(value)
	self.Preset = value
	local preset = self.presets[self.Preset]
	self.Duration = preset and preset.Duration or self.Duration
	self.Frequency = preset and preset.Frequency or self.Frequency
	self.ShakeOffset = preset and preset.ShakeOffset or self.ShakeOffset
	self.RollAngle = preset and preset.RollAngle or self.RollAngle
end

---
--- Handles changes to the editor properties of an ActionFXCameraShake object.
---
--- If the Preset property is not set to "Custom", and certain properties are changed (Duration, Frequency, ShakeOffset, RollAngle), the Preset property is set to "Custom" to indicate that the object has been customized.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor object that triggered the property change.
---
function ActionFXCameraShake:OnEditorSetProperty(prop_id, old_value, ged)
	ActionFX.OnEditorSetProperty(self, prop_id, old_value, ged)
	if self.Preset ~= "Custom" and (prop_id == "Duration" or prop_id == "Frequency" or prop_id == "ShakeOffset" or prop_id == "RollAngle") then
		local preset = self.presets[self.Preset]
		if preset and preset[prop_id] and preset[prop_id] ~= self[prop_id] then
			self.Preset = "Custom"
		end
	end
end

---
--- Triggers a camera shake effect for testing purposes.
---
--- @param editor_obj table The editor object that triggered the test.
--- @param fx table The ActionFXCameraShake object to test.
--- @param prop_id string The ID of the property that was changed.
---
function TestActionFXCameraShake(editor_obj, fx, prop_id)
	local preset = fx.presets[fx.Preset]
	local duration = preset and preset.Duration or fx.Duration
	local frequency = preset and preset.Frequency or fx.Frequency
	local shake_offset = preset and preset.ShakeOffset or fx.ShakeOffset
	local shake_roll = preset and preset.RollAngle or fx.RollAngle
	camera.Shake(duration, frequency, shake_offset, shake_roll)
end

--============================= Radial Blur =======================

DefineClass.ActionFXRadialBlur = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Strength", category = "Radial Blur", default = 300, editor = "number", buttons = {{name = "Test", func = "TestActionFXRadialBlur"}}},
		{ id = "Duration", category = "Radial Blur", default = 800, editor = "number" },
		{ id = "FadeIn", category = "Radial Blur", default = 30, editor = "number" },
		{ id = "FadeOut", category = "Radial Blur", default = 350, editor = "number" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" }, help = "Radial Blur position" },
	},
	fx_type = "Radial Blur",
}

if FirstLoad then
	RadialBlurThread = false
	g_RadiualBlurIsPaused = false
	g_RadiualBlurPauseReasons = {}
end
--blatant copy paste from Pause(reason)
---
--- Pauses the radial blur effect.
---
--- @param reason string The reason for pausing the radial blur effect.
---
function PauseRadialBlur(reason)
	reason = reason or false
	if next(g_RadiualBlurPauseReasons) == nil then
		g_RadiualBlurIsPaused = true
		SetPostProcPredicate( "radial_blur", false )
		g_RadiualBlurPauseReasons[reason] = true
	else
		g_RadiualBlurPauseReasons[reason] = true
	end
end

---
--- Resumes the radial blur effect after it has been paused.
---
--- @param reason string The reason for pausing the radial blur effect, which is used to resume it.
---
function ResumeRadialBlur(reason)
	reason = reason or false
	if g_RadiualBlurPauseReasons[reason] ~= nil then
		g_RadiualBlurPauseReasons[reason] = nil
		if next(g_RadiualBlurPauseReasons) == nil then
			g_RadiualBlurIsPaused = false
		end
	end
end

function OnMsg.DoneMap()
	DeleteThread(RadialBlurThread)
	RadialBlurThread = false
	hr.RadialBlurStrength = 0
	SetPostProcPredicate( "radial_blur", false )
end

---
--- Applies a radial blur effect to the screen.
---
--- @param duration number The duration of the radial blur effect in milliseconds.
--- @param fadein number The duration of the fade-in effect in milliseconds.
--- @param fadeout number The duration of the fade-out effect in milliseconds.
--- @param strength number The strength of the radial blur effect.
---
function RadialBlur(duration, fadein, fadeout, strength)
    -- Implementation details
end
function RadialBlur( duration, fadein, fadeout, strength )
	DeleteThread(RadialBlurThread)
	RadialBlurThread = self:CreateThread( function(duration, fadein, fadeout, strength)
		SetPostProcPredicate( "radial_blur", not g_RadiualBlurIsPaused )
		local time_step = 5
		local t = 0
		while t < fadein do
			hr.RadialBlurStrength = strength * t / fadein
			Sleep(time_step)
			t = t + time_step
		end
		if t < duration - fadeout then
			hr.RadialBlurStrength = strength
			Sleep(duration - fadeout - t)
			t = duration - fadeout
		end
		while t < duration do
			hr.RadialBlurStrength = strength * (duration - t) / fadeout
			Sleep(time_step)
			t = t + time_step
		end
		hr.RadialBlurStrength = 0
		SetPostProcPredicate( "radial_blur", false )
		RadialBlurThread = false
	end, duration, fadein, fadeout, strength)
end

---
--- Determines whether the ActionFXRadialBlur should track the FX.
---
--- @return boolean True if the FX should be tracked, false otherwise.
---
function ActionFXRadialBlur:TrackFX()
	return (self.behaviors or self.Time > 0) and true or false
end

---
--- Plays a radial blur effect on the screen.
---
--- @param actor CObject The actor object that is the source of the effect.
--- @param target CObject The target object of the effect.
--- @param action_pos Vector3 The position of the action.
--- @param action_dir Vector3 The direction of the action.
---
--- The radial blur effect is applied with the specified duration, fade-in, fade-out, and strength parameters. If the effect should be tracked, it is assigned to the actor and target objects.
---
--- If the effect has a delay, it is executed after the delay.
---
function ActionFXRadialBlur:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Radial Blur has invalid source: %s", self.Source)
		return
	end
	if NetIsRemote(obj) then
		return -- radial blur FX is not applied for remote objects
	end
	if self.Delay <= 0 then
		RadialBlur(self.Duration, self.FadeIn, self.FadeOut, self.Strength)
		if self:TrackFX() then
			self:AssignFX(actor, target, RadialBlurThread)
		end
	else
		self:CreateThread(function(self, actor, target)
			Sleep(self.Delay)
			RadialBlur(self.Duration, self.FadeIn, self.FadeOut, self.Strength)
			if self:TrackFX() then
				self:AssignFX(actor, target, RadialBlurThread)
			end
		end, self, actor, target)
	end
end

---
--- Destroys the radial blur effect that is currently assigned to the specified actor and target objects.
---
--- If a radial blur effect is currently assigned, it is removed and the radial blur strength is reset to 0. The post-processing predicate for radial blur is also set to false.
---
--- @param actor CObject The actor object that the radial blur effect is assigned to.
--- @param target CObject The target object that the radial blur effect is assigned to.
---
function ActionFXRadialBlur:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx or fx ~= RadialBlurThread then
		return
	end
	DeleteThread(RadialBlurThread)
	RadialBlurThread = false
	hr.RadialBlurStrength = 0
	SetPostProcPredicate( "radial_blur", false )
end

---
--- Applies a radial blur effect with the specified duration, fade-in, fade-out, and strength parameters.
---
--- @param editor_obj table The editor object that the radial blur effect is associated with.
--- @param fx table The radial blur effect parameters, including Duration, FadeIn, FadeOut, and Strength.
--- @param prop_id string The property ID of the radial blur effect.
---
function TestActionFXRadialBlur(editor_obj, fx, prop_id)
	RadialBlur(fx.Duration, fx.FadeIn, fx.FadeOut, fx.Strength)
end

local function ActionFXObjectCombo(o)
	local list = ClassDescendantsList("CObject", function (name, class)
		return IsValidEntity(class:GetEntity()) or class.fx_spawn_enable
	end)
	table.sort(list, CmpLower)
	return list
end

local function ActionFXObjectAnimationCombo(o)
	local cls = g_Classes[o.Object]
	local entity = cls and cls:GetEntity()
	local list
	if IsValidEntity(entity) then
		list = GetStates(entity)
	else
		list = {"idle"} -- GetClassDescendantsStates("CObject")
	end
	table.sort(list, CmpLower)
	return list
end

local function ActionFXObjectAnimationHelp(o)
	local cls = g_Classes[o.Object]
	local entity = cls and cls:GetEntity()
	if IsValidEntity(entity) then
		local help = {}
		help[#help+1] = entity
		local anim = o.Animation
		if anim ~= "" and HasState(entity, anim) and not IsErrorState(entity, anim) then
			help[#help+1] = "Duration: " .. GetAnimDuration(entity, anim)
			local moments = GetStateMoments(entity, anim)
			if #moments > 0 then
				help[#help+1] = "Moments:"
				for i = 1, #moments do
					help[#help+1] = string.format("    %s = %d", moments[i].type, moments[i].time)
				end
			else
				help[#help+1] = "No Moments"
			end
		end
		return table.concat(help, "\n")
	end
	return ""
end

--============================= Object FX =======================

DefineClass.ActionFXObject = {
	__parents = { "ActionFX", "ColorizableObject" },
	properties = {
		{ id = "AnimationLoops", category = "Lifetime", default = 0, editor = "number", help = "Additional time" },
		{ id = "Object", name = "Object1", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object2", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object3", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Object4", category = "Object", default = "", editor = "combo", items = function(fx) return ActionFXObjectCombo(fx) end, buttons = {{name = "Test", func = "TestActionFXObject"}}},
		{ id = "Animation", category = "Object", default = "idle", editor = "combo", items = function(fx) return ActionFXObjectAnimationCombo(fx) end, help = ActionFXObjectAnimationHelp },
		{ id = "AnimationPhase", category = "Object", default = 0, editor = "number" },
		{ id = "FadeIn", category = "Object", default = 0, editor = "number", help = "Included in the overall time" },
		{ id = "FadeOut", category = "Object", default = 0, editor = "number", help = "Included in the overall time" },
		{ id = "Flags", category = "Object", default = "", editor = "dropdownlist", items = { "", "OnGround", "LockedOrientation", "Mirrored", "OnGroundTiltByGround", "SyncWithParent" } },
		{ id = "Scale", category = "Object", default = 100, editor = "number" },
		{ id = "ScaleMember", category = "Object", default = "", editor = "text" },
		{ id = "Opacity", category = "Object", default = 100, editor = "number", min = 0, max = 100, slider = true },
		{ id = "ColorModifier", category = "Object", editor = "color", default = RGBA(100, 100, 100, 0), buttons = {{name = "Reset", func = "ResetColorModifier"}}},
		{ id = "UseActorColorization", category = "Object", default = false, editor = "bool" },
		{ id = "Source", category = "Placement", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" } },
		{ id = "Spot", category = "Placement", default = "Origin", editor = "combo", items = function(fx) return ActionFXSpotCombo(fx) end },
		{ id = "Attach", category = "Placement", default = false, editor = "bool", help = "Set true if the object should move with the source" },
		{ id = "Offset", category = "Placement", default = point30, editor = "point", scale = "m" },
		{ id = "OffsetDir", category = "Placement", default = "SourceAxisX", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "Orientation", category = "Placement", default = "", editor = "dropdownlist", items = function(fx) return ActionFXOrientationCombo end },
		{ id = "PresetOrientationAngle", category = "Placement", default = 0, editor = "number", },
		{ id = "OrientationAxis", category = "Placement", default = 1, editor = "dropdownlist", items = function() return OrientationAxisCombo end },
		{ id = "AlwaysVisible", category = "Object", default = false, editor = "bool", },

		{ id = "anim_type", name = "Pick frame by", editor = "choice", items = function() return AnimatedTextureObjectTypes end, default = 0, help = "UV Scroll Animation playback type" },
		{ id = "anim_speed", name = "Speed Multiplier", editor = "number", max = 4095, min = 0, default = 1000, help = "UV Scroll Animation playback speed" },
		{ id = "sequence_time_remap", name = "Sequence time", editor = "curve4", max = 63, scale = 63, max_x = 15, scale_x = 15, default = MakeLine(0, 63, 15), help = "UV Scroll Animation playback time curve" },

		{ id = "SortPriority", category = "Object", default = 0, editor = "number", min = -4, max = 3, no_edit = function(o) return not IsKindOf(rawget(_G, o.Object), "Decal") end },
	},
	fx_type = "Object",
	variations_props = { "Object", "Object2", "Object3", "Object4" },
	DocumentationLink = "Docs/ModItemActionFXObject.md.html",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item creates and places an object when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

---
--- Sets the object for the ActionFXObject.
--- If the object's animation is invalid, the animation is set to "idle".
---
--- @param value string The name of the object to set.
---
function ActionFXObject:SetObject(value)
	self.Object = value
	local cls = g_Classes[self.Object]
	local entity = cls and cls:GetEntity()
	local anim = self.Animation
	if (entity or "") == "" or not IsValidEntity(entity) or not HasState(entity, anim) or IsErrorState(entity, anim) then
		anim = "idle"
	end
	self.Animation = anim
end

---
--- Plays an ActionFXObject, which creates and places an object when an FX action is triggered.
---
--- @param actor table The actor associated with the FX action.
--- @param target table The target associated with the FX action.
--- @param action_pos table The position of the FX action.
--- @param action_dir table The direction of the FX action.
---
function ActionFXObject:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Object %s has invalid source: %s", self.Object, self.Source)
		return
	end
	local fx, wait_anim, wait_time, duration
	if obj and self.Flags == "SyncWithParent" and self.AnimationPhase > obj:GetAnimPhase() then
		wait_anim = obj:GetAnim(1)
		wait_time = obj:TimeToPhase(1, self.AnimationPhase)
	end
	if self.Delay <= 0 and (wait_time or 0) <= 0 then
		fx = self:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if not fx then return end
		self:TrackObject(fx, actor, target, action_pos, action_dir)
		duration = self.Time + self.AnimationLoops * fx:GetAnimDuration()
		if duration <= 0 then
			return
		end
	end
	local thread = self:CreateThread(function(self, fx, wait_anim, wait_time, duration, actor, target, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if self.Delay > 0 then
			Sleep(self.Delay)
		end
		if wait_time and IsValid(obj) and obj:GetAnim(1) == wait_anim then
			if not obj:IsKindOf("StateObject") then
				Sleep(wait_time)
			elseif not obj:WaitPhase(self.AnimationPhase) then
				return
			end
			if not IsValid(obj) or obj:GetAnim(1) ~= wait_anim then
				return
			end
		end
		if not fx then
			fx = self:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
			if not fx then return end
			self:TrackObject(fx, actor, target, action_pos, action_dir)
			duration = self.Time + self.AnimationLoops * fx:GetAnimDuration()
			if duration <= 0 then
				return
			end
		end
		local fadeout = self.FadeOut > 0 and Min(duration, self.FadeOut) or 0
		Sleep(duration-fadeout)
		if not IsValid(fx) then return end
		if fx == self:GetAssignedFX(actor, target) then
			self:AssignFX(actor, target, nil)
		end
		if fadeout > 0 then
			if fx:GetOpacity() > 0 then
				fx:SetOpacity(0, fadeout)
			end
			Sleep(fadeout)
		end
		DoneObject(fx)
	end, self, fx, wait_anim, wait_time, duration, actor, target, count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not fx and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

---
--- Returns the maximum number of coloration materials that can be applied to an object.
---
--- @return integer The maximum number of coloration materials.
function ActionFXObject:GetMaxColorizationMaterials()
	return const.MaxColorizationMaterials
end

---
--- Places one or more FX objects based on the specified parameters.
---
--- @param count integer The number of FX objects to place.
--- @param obj table The object to attach the FX to, if any.
--- @param spot table The position and orientation of the FX.
--- @param posx number The x-coordinate of the FX position.
--- @param posy number The y-coordinate of the FX position.
--- @param posz number The z-coordinate of the FX position.
--- @param angle number The rotation angle of the FX.
--- @param axisx number The x-component of the rotation axis.
--- @param axisy number The y-component of the rotation axis.
--- @param axisz number The z-component of the rotation axis.
--- @return table|nil A list of the placed FX objects, or nil if no FX objects were placed.
---
function ActionFXObject:PlaceFXObject(count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if self.Attach and (not obj or not IsValid(obj)) then
		return
	end
	if count == 1 then
		return self:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	end
	local list
	for i = 0, count - 1 do
		local o = self:PlaceSingleFXObject(obj, unpack_params(spot, 8*i+1, 8*i+8))
		if o then
			list = list or {}
			table.insert(list, o)
		end
	end
	return list
end

---
--- Creates a single FX object with the specified components.
---
--- @param components integer The components to include in the FX object.
--- @return table|nil The created FX object, or nil if the creation failed.
function ActionFXObject:CreateSingleFXObject(components)
	local name = self:GetVariation(self.variations_props)
	return PlaceObject(name, nil, components)
end

---
--- Places a single FX object with the specified parameters.
---
--- @param obj table The object to attach the FX to, if any.
--- @param spot table The position and orientation of the FX.
--- @param posx number The x-coordinate of the FX position.
--- @param posy number The y-coordinate of the FX position.
--- @param posz number The z-coordinate of the FX position.
--- @param angle number The rotation angle of the FX.
--- @param axisx number The x-component of the rotation axis.
--- @param axisy number The y-component of the rotation axis.
--- @param axisz number The z-component of the rotation axis.
--- @return table|nil The created FX object, or nil if the creation failed.
---
function ActionFXObject:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	local components = const.cofComponentAnim | const.cofComponentColorizationMaterial
	if obj and self.Attach then
		components = components | const.cofComponentAttach
	end
	if self.FadeIn > 0 or self.FadeOut > 0 then
		components = components | const.cofComponentInterpolation
	end
	local fx = self:CreateSingleFXObject(components)
	if not fx then
		return
	end
	NetTempObject(fx)
	fx:SetColorModifier(self.ColorModifier)

	local fx_scm = fx.SetColorizationMaterial
	local color_src = self.UseActorColorization and obj and obj:GetMaxColorizationMaterials() > 0 and obj or self
	fx_scm(fx, 1, color_src:GetEditableColor1(), color_src:GetEditableRoughness1(), color_src:GetEditableMetallic1())
	fx_scm(fx, 2, color_src:GetEditableColor2(), color_src:GetEditableRoughness2(), color_src:GetEditableMetallic2())
	fx_scm(fx, 3, color_src:GetEditableColor3(), color_src:GetEditableRoughness3(), color_src:GetEditableMetallic3())

	local scale
	local scale_member = self.ScaleMember
	if scale_member ~= "" and IsValid(obj) and obj:HasMember(scale_member) then
		scale = obj[scale_member]
		if type(scale) == "function" then
			scale = scale(obj)
			if type(scale) ~= "number" then
				assert(false, "invalid return value from ScaleMember function, scale will be set to 100")
				scale = 100
			end
		end
	end
	scale = scale or self.Scale
	fx:SetScale(scale) 
	fx:SetState(self.Animation, 0, 0)
	if self.Flags == "OnGroundTiltByGround" then
		fx:SetAnim(1, self.Animation, const.eOnGround + const.eTiltByGround, 0)
	end
	fx:SetAnimPhase(1, self.AnimationPhase)
	if self.Flags == "Mirrored" then
		fx:SetMirrored(true)
	elseif self.Flags == "LockedOrientation" then
		fx:SetGameFlags(const.gofLockedOrientation)
	elseif self.Flags == "OnGround" or self.Flags == "OnGroundTiltByGround" then
		fx:SetGameFlags(const.gofAttachedOnGround)
	elseif self.Flags == "SyncWithParent" then
		fx:SetGameFlags(const.gofSyncState)
	end
	if self.AlwaysVisible then
		fx:SetGameFlags(const.gofAlwaysRenderable)
	end
	if not self.GameTime or self.Attach and obj:GetGameFlags(const.gofRealTimeAnim) ~= 0 then
		fx:SetGameFlags(const.gofRealTimeAnim)
	end
	if self.FadeIn > 0 then
		fx:SetOpacity(0)
		fx:SetOpacity(self.Opacity, self.FadeIn)
	else
		fx:SetOpacity(self.Opacity)
	end
	if self.SortPriority ~= 0 and fx:IsKindOf("Decal") then
		fx:Setsort_priority(self.SortPriority)
	end
	FXOrient(fx, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)

	if IsKindOf(fx, "AnimatedTextureObject") then
		fx:Setanim_speed(self.anim_speed)
		fx:Setanim_type(self.anim_type)
		fx:Setsequence_time_remap(self.sequence_time_remap)
	end
	return fx
end

---
--- Tracks an FX object and assigns it to the specified actor and target.
---
--- @param fx ActionFXObject The FX object to track.
--- @param actor table The actor to assign the FX to.
--- @param target table The target to assign the FX to.
--- @param action_pos Vector3 The position of the action.
--- @param action_dir Vector3 The direction of the action.
---
function ActionFXObject:TrackObject(fx, actor, target, action_pos, action_dir)
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
end

---
--- Destroys the FX object assigned to the specified actor and target.
---
--- @param actor table The actor to unassign the FX from.
--- @param target table The target to unassign the FX from.
---
function ActionFXObject:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	elseif IsValid(fx) then
		local fadeout = self.FadeOut
		if fadeout <= 0 then
			DoneObject(fx)
		else
			fx:SetOpacity(0, fadeout)
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObject(fx)
			end, self, fx)
		end
	elseif type(fx) == "table" and not getmetatable(fx) then
		local fadeout = self.FadeOut
		if fadeout <= 0 then
			DoneObjects(fx)
		else
			for _, o in ipairs(fx) do
				if IsValid(o) then
					o:SetOpacity(0, fadeout)
				end
			end
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObjects(fx)
			end, self, fx)
		end
	end
end

---
--- Detaches the FX object assigned to the specified actor and target.
---
--- @param actor table The actor to detach the FX from.
--- @param target table The target to detach the FX from.
---
function ActionFXObject:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then
		return
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	elseif IsValidThread(fx) then
		printf("FX Object %s Detach Behavior can not be run before the object is placed (Delay %d is very large)", self.Object, self.Delay)
	end
end

DefineClass.ActionFXPassTypeObject = {
	__parents = { "ActionFXObject" },
	properties = {
		{ id = "Object",  editor = false, default = "PassTypeMarker", },
		{ id = "Object2", editor = false,                             },
		{ id = "Object3", editor = false,                             },
		{ id = "Object4", editor = false,                             },
		{ id = "Chance",  editor = false,                             },
		{ category = "Pass Type", id = "pass_type_radius", name = "Pass Radius", editor = "number", default = 0,     scale = "m" },
		{ category = "Pass Type", id = "pass_type_name",   name = "Pass Type",   editor = "choice", default = false, items = function() return PassTypesCombo end, },
	},
	fx_type = "Pass Type Object",
	Chance = 100,
}

---
--- Creates a single FX object with the specified pass type properties.
---
--- @param components table The components to use when creating the FX object.
--- @return table The created FX object.
---
function ActionFXPassTypeObject:CreateSingleFXObject(components)
	return PlaceObject(self.Object, {
		PassTypeRadius = self.pass_type_radius,
		PassTypeName = self.pass_type_name,
	}, components)
end

---
--- Places a single FX object with the specified pass type properties.
---
--- @param obj table The FX object to place.
--- @param spot table The spot to place the FX object at.
--- @param posx number The X coordinate to place the FX object at.
--- @param posy number The Y coordinate to place the FX object at.
--- @param posz number The Z coordinate to place the FX object at.
--- @param angle number The angle to rotate the FX object to.
--- @param axisx number The X axis to rotate the FX object around.
--- @param axisy number The Y axis to rotate the FX object around.
--- @param axisz number The Z axis to rotate the FX object around.
--- @return table The placed FX object.
---
function ActionFXPassTypeObject:PlaceSingleFXObject(obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	assert(not IsAsyncCode() or IsEditorActive())
	local pass_type_fx = ActionFXObject.PlaceSingleFXObject(self, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz)
	if not pass_type_fx then return end
	if not pass_type_fx:IsValidPos() then
		DoneObject(pass_type_fx)
		return 
	end
	local x, y, z = pass_type_fx:GetPosXYZ()
	local max_below = guim
	local max_above = guim
	z = terrain.FindPassableZ(pass_type_fx, 0, max_below, max_above)
	pass_type_fx:MakeSync()
	pass_type_fx:SetPos(x, y, z)
	pass_type_fx:SetCostRadius()
	return pass_type_fx
end

---
--- Tests an ActionFXObject by placing it in the game world.
---
--- @param editor_obj table The editor object associated with the ActionFXObject.
--- @param fx table The ActionFXObject to test.
--- @param prop_id string The property ID of the ActionFXObject.
---
function TestActionFXObject(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	local obj = PlaceObject(fx.Object)
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	obj:SetScale(fx.Scale)
	obj:SetState(fx.Animation, 0, 0)
	if fx.Orientation == "OnGroundTiltByGround" then
		obj:SetAnim(1, fx.Animation, const.eOnGround + const.eTiltByGround, 0)
	end
	obj:SetAnimPhase(1, fx.AnimationPhase)
	if fx.Flags == "Mirrored" then
		obj:SetMirrored(true)
	elseif fx.Flags == "OnGround" or fx.Flags == "OnGroundTiltByGround" then
		obj:SetGameFlags(const.gofAttachedOnGround)
	end
	if fx.FadeIn > 0 then
		obj:SetOpacity(0)
		obj:SetOpacity(100, fx.FadeIn)
	end
	local time = fx.Time > 0 and fx.Time or 0
	if fx.AnimationLoops > 0 then
		time = time + fx.AnimationLoops * obj:GetAnimDuration()
	end
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	local posx, posy, posz = look_at:xyz()
	FXOrient(obj, posx, posy, posz)
	if time <= 0 then time = fx.FadeIn + fx.FadeOut + 2000 end
	fx:CreateThread(function(fx, obj, time)
		if fx.FadeOut > 0 then
			local t = Min(time, fx.FadeOut)
			Sleep(time-t)
			if IsValid(obj) and t > 0 then
				obj:SetOpacity(0, t)
				Sleep(t)
			end
		else
			Sleep(time)
		end
		TestActionFXObjectEnd(obj)
	end, fx, obj, time)
end

-------- Backwards compat ----------
DefineClass.ActionFXDecal = {
	__parents = { "ActionFXObject" },
	fx_type = "Decal",
	DocumentationLink = "Docs/ModItemActionFXDecal.md.html",
	Documentation = ActionFX.Documentation .. "\n\nPlaces a decal when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

--============================= FX Controller Rumble =======================

local function AddValuesInComboTexts(values)
	local list = {}
	for k, v in pairs(values) do
		list[#list+1] = k
	end
	table.sort(list, function(a,b) return values[a] < values[b] end)
	local res = {}
	for i = 1, #list do
		list[i] = { text = string.format("%s : %d", list[i], values[list[i]]), value = list[i] }
	end
	return list
end

DefineClass.ActionFXControllerRumble = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Power", category = "Vibration", default = "Medium", editor = "combo", items = function(fx) return AddValuesInComboTexts(fx.powers) end, help = "Controller left and right motors speed", buttons = {{name = "Test", func = "TestActionFXControllerRumble"}}},
		{ id = "Duration", category = "Vibration", default = "Medium", editor = "combo", items = function(fx) return AddValuesInComboTexts(fx.durations) end, help = "Vibration duration in game time" },
		{ id = "Controller", category = "Vibration", default = "Actor", editor = "dropdownlist", items = { "Actor", "Target" }, help = "Whose controller should vibrate" },
		{ id = "GameTime", editor = false },
	},
	powers = {
		Slight = 6000,
		Light  = 16000,
		Medium = 24000,
		FullSpeed = 65535,
	},
	durations = {
		Short =  125,
		Medium = 230,
	},
	fx_type = "Controller Rumble",
}

if FirstLoad then
	ControllerRumbleThreads = {}
end

local function StopControllersRumble()
	for i = #ControllerRumbleThreads, 0, -1 do
		if ControllerRumbleThreads[i] then
			DeleteThread(ControllerRumbleThreads[i])
			ControllerRumbleThreads[i] = nil
			XInput.SetRumble(i, 0, 0)
		end
	end
end

OnMsg.MsgPreControllersAssign = StopControllersRumble
OnMsg.DoneMap = StopControllersRumble
OnMsg.Pause = StopControllersRumble

---
--- Vibrates the specified controller for the given duration and power levels.
---
--- @param controller_id number The ID of the controller to vibrate.
--- @param duration number The duration of the vibration in milliseconds.
--- @param power_left number The power level for the left motor (0-65535).
--- @param power_right number The power level for the right motor (0-65535).
---
function ControllerRumble(controller_id, duration, power_left, power_right)
	if not GetAccountStorageOptionValue("ControllerRumble") or not duration or duration <= 0 then
		power_left = 0
		power_right = 0
	end
	XInput.SetRumble(controller_id, power_left, power_right)
	DeleteThread(ControllerRumbleThreads[controller_id])
	ControllerRumbleThreads[controller_id] = nil
	if power_left > 0 or power_right > 0 then
		ControllerRumbleThreads[controller_id] = CreateRealTimeThread(function(controller_id, duration)
			Sleep(duration or 230)
			XInput.SetRumble(controller_id, 0, 0)
			ControllerRumbleThreads[controller_id] = nil
		end, controller_id, duration)
	end
end

---
--- Vibrates the specified controller for the given duration and power levels.
---
--- @param actor table The actor object that triggered the FX.
--- @param target table The target object of the action.
--- @param action_pos vector3 The position of the action.
--- @param action_dir vector3 The direction of the action.
---
function ActionFXControllerRumble:PlayFX(actor, target, action_pos, action_dir)
	local obj
	if self.Controller == "Actor" then
		obj = IsValid(actor) and GetTopmostParent(actor)
	elseif self.Controller == "Target" then
		obj = IsValid(target) and target
	end
	if not obj then
		printf("FX Rumble controller invalid source %s", self.Controller)
		return
	end
	local controller_id
	for loc_player = 1, LocalPlayersCount do
		if obj == GetLocalHero(loc_player) or obj == PlayerControlObjects[loc_player] then
			controller_id = GetActiveXboxControllerId(loc_player)
			break
		end
	end
	if controller_id then
		self:VibrateController(controller_id, actor, target, action_pos, action_dir)
	end
end

---
--- Vibrates the specified controller for the given duration and power levels.
---
--- @param controller_id number The ID of the controller to vibrate.
--- @param ... any Additional arguments to pass to the behavior function, if specified.
---
function ActionFXControllerRumble:VibrateController(controller_id, ...)
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, ...)
	else
		local power = self.powers[self.Power] or tonumber(self.Power)
		local duration = self.durations[self.Duration] or tonumber(self.Duration)
		ControllerRumble(controller_id, duration, power, power)
	end
end

---
--- Tests the vibration behavior of the ActionFXControllerRumble class.
---
--- @param editor_obj table The editor object that triggered the test.
--- @param fx table The ActionFXControllerRumble instance to test.
--- @param prop_id string The ID of the property being tested.
---
function TestActionFXControllerRumble(editor_obj, fx, prop_id)
	fx:VibrateController(0, "Test")
end

--============================= FX Light =======================

DefineClass.ActionFXLight = {
	__parents = { "ActionFX" },
	properties = {
		{ category = "Light",     id = "Type",             editor = "combo",        default = "PointLight",     items = { "PointLight", "PointLightFlicker", "SpotLight", "SpotLightFlicker" } },
		{ category = "Light",     id = "CastShadows",      editor = "bool",         default = false,            },
		{ category = "Light",     id = "DetailedShadows",  editor = "bool",         default = false,            },
		{ category = "Light",     id = "Color",            editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "Intensity",        editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "Color0",           editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Intensity0",       editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Color1",           editor = "color",        default = RGB(255,255,255), buttons = {{name = "Test", func = "TestActionFXLight"}}, no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Intensity1",       editor = "number",       default = 100,              min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Period",           editor = "number",       default = 40000,            min = 0, max = 100000, scale = 1000, slider = true,      no_edit = function(self) return self.Type == "PointLight" or self.Type == "StopLight" end },
		{ category = "Light",     id = "Radius",           editor = "number",       default = 20,               min = 0, max = 500*guim, color = RGB(255,50,50), color2 = RGB(50,50,255), slider = true, scale = "m" },
		{ category = "Light",     id = "FadeIn",           editor = "number",       default = 0,                                                                         no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "StartIntensity",   editor = "number",       default = 0,                min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "StartColor",       editor = "color",        default = RGB(0,0,0),                                                                no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOut",          editor = "number",       default = 0,                                                                         no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOutIntensity", editor = "number",       default = 0,                min = 0, max = 255, slider = true,                       no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "FadeOutColor",     editor = "color",        default = RGB(0,0,0),                                                                no_edit = function(self) return self.Type ~= "PointLight" and self.Type ~= "SpotLight" end },
		{ category = "Light",     id = "ConeInnerAngle",   editor = "number",       default = 45,               min = 5, max = (180 - 5), slider = true,                 no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end },
		{ category = "Light",     id = "ConeOuterAngle",   editor = "number",       default = 45,               min = 5, max = (180 - 5), slider = true,                 no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end },
		{ category = "Light",     id = "LookAngle",        editor = "number",       default = 0,                min = 0, max = 360*60 - 1, slider = true, scale = "deg", no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end, },
		{ category = "Light",     id = "LookAxis",         editor = "point",        default = axis_z,           scale = 4096,                                             no_edit = function(self) return self.Type ~= "SpotLight" and self.Type ~= "SpotLightFlicker" end, },
		{ category = "Light",     id = "Interior",         editor = "bool",         default = true,             },
		{ category = "Light",     id = "Exterior",         editor = "bool",         default = true,             },
		{ category = "Light",     id = "InteriorAndExteriorWhenHasShadowmap", editor = "bool", default = true,  },
		{ category = "Light",     id = "Always Renderable",editor = "bool",         default = false             },
		{ category = "Light",     id = "SourceRadius", name = "Source Radius (cm)", editor = "number", min = guic, max=20*guim, default = 10*guic, scale = guic, slider = true, color = RGB(200, 200, 0), autoattach_prop = true, help = "Radius of the light source in cm." },

		{ category = "Placement", id = "Source",           editor = "dropdownlist", default = "Actor",          items = { "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos" } },
		{ category = "Placement", id = "Spot",             editor = "combo",        default = "Origin",         items = function(fx) return ActionFXSpotCombo(fx) end },
		{ category = "Placement", id = "Attach",           editor = "bool",         default = false,            help = "Set true if the decal should move with the source" },
		{ category = "Placement", id = "Offset",           editor = "point",        default = point30,          scale = "m" },
		{ category = "Placement", id = "OffsetDir",        editor = "dropdownlist", default = "SourceAxisX",    items = function(fx) return ActionFXOrientationCombo end },
		{ category = "Placement", id = "Helper",           editor = "bool",         default = false,            dont_save = true },
	},
	fx_type = "Light",
	DocumentationLink = "Docs/ModItemActionFXLight.md.html",
	Documentation = ActionFX.Documentation .. "\n\nThis mod item places light sources when an FX action is triggered. Inherits ActionFX. Read ActionFX first for the common properties."
}

---
--- Plays an ActionFXLight effect.
---
--- @param actor table The actor object that the effect is attached to.
--- @param target table The target object that the effect is attached to.
--- @param action_pos table The position where the effect is placed.
--- @param action_dir table The direction of the effect.
---
function ActionFXLight:PlayFX(actor, target, action_pos, action_dir)
	local count, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz = self:GetLoc(actor, target, action_pos, action_dir)
	if count == 0 then
		printf("FX Light has invalid source: %s", self.Source)
		return
	end
	local fx
	if self.Delay <= 0 then
		fx = self:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if not fx or self.Time <= 0 then
			return
		end
	end
	local thread = self:CreateThread(function(self, fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
		if self.Delay > 0 then
			Sleep(self.Delay)
			fx = self:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
			if not fx or self.Time <= 0 then
				return
			end
		end
		local fadeout = (self.Type ~= "PointLightFlicker" and self.Type ~= "PointLightFlicker") and self.FadeOut > 0 and Min(self.Time, self.FadeOut) or 0
		Sleep(self.Time-fadeout)
		if not IsValid(fx) then return end
		if fx == self:GetAssignedFX(actor, target) then
			self:AssignFX(actor, target, nil)
		end
		if fadeout > 0 then
			fx:Fade(self.FadeOutColor, self.FadeOutIntensity, fadeout)
			Sleep(fadeout)
		end
		DoneObject(fx)
	end, self, fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if not fx and self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

---
--- Places a light source effect at the specified position and orientation.
---
--- @param actor table The actor object that the effect is attached to.
--- @param target table The target object that the effect is attached to.
--- @param obj table The object to attach the light to, if any.
--- @param spot number The spot index to attach the light to, if any.
--- @param posx number The x-coordinate of the light position.
--- @param posy number The y-coordinate of the light position.
--- @param posz number The z-coordinate of the light position.
--- @param angle number The angle of the light.
--- @param axisx number The x-component of the light axis.
--- @param axisy number The y-component of the light axis.
--- @param axisz number The z-component of the light axis.
--- @param action_pos table The position where the effect is placed.
--- @param action_dir table The direction of the effect.
--- @return table The placed light effect object.
---
function ActionFXLight:PlaceFXLight(actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	if self.Attach and not IsValid(obj) then
		return
	end
	local fx = PlaceObject(self.Type)
	NetTempObject(fx)
	fx:SetCastShadows(self.CastShadows)
	fx:SetDetailedShadows(self.DetailedShadows)
	fx:SetAttenuationRadius(self.Radius)
	fx:SetInterior(self.Interior)
	fx:SetExterior(self.Exterior)
	fx:SetInteriorAndExteriorWhenHasShadowmap(self.InteriorAndExteriorWhenHasShadowmap)
	if self.AlwaysRenderable then
		fx:SetGameFlags(const.gofAlwaysRenderable)
	end
	local detail_level = table.find_value(ActionFXDetailLevel, "value", self.DetailLevel)
	if not detail_level then
		local max_lower, min
		for _, detail in ipairs(ActionFXDetailLevel) do
			min = (not min or detail.value < min.value) and detail or min
			if detail.value <= self.DetailLevel and (not max_lower or max_lower.value < detail.value) then
				max_lower = detail
			end
		end
		detail_level = max_lower or min
	end
	fx:SetDetailClass(detail_level.text)
	if self.Helper then
		fx:Attach(PointLight:new(), fx:GetSpotBeginIndex(self.Spot))
	end
	FXOrient(fx, posx, posy, posz, obj, spot, self.Attach, axisx, axisy, axisz, angle, self.Offset)
	if self.GameTime then
		fx:ClearGameFlags(const.gofRealTimeAnim)
	end
	if self.Type == "PointLight" or self.Type == "PointLightFlicker" then
		fx:SetSourceRadius(self.SourceRadius)
	end
	if self.Type == "SpotLight" or self.Type == "SpotLightFlicker" then
		fx:SetConeOuterAngle(self.ConeOuterAngle)
		fx:SetConeInnerAngle(self.ConeInnerAngle)
		fx:SetAxis(self.LookAxis)
		fx:SetAngle(self.LookAngle)
	end
	if self.Type == "PointLightFlicker" or self.Type == "SpotLightFlicker" then
		fx:SetColor0(self.Color0)
		fx:SetIntensity0(self.Intensity0)
		fx:SetColor1(self.Color1)
		fx:SetIntensity1(self.Intensity1)
		fx:SetPeriod(self.Period)
	elseif self.FadeIn > 0 then
		fx:SetColor(self.StartColor)
		fx:SetIntensity(self.StartIntensity)
		fx:Fade(self.Color, self.Intensity, self.FadeIn)
	else
		fx:SetColor(self.Color)
		fx:SetIntensity(self.Intensity)
	end
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if self.Behavior ~= "" and self.BehaviorMoment == "" then
		self[self.Behavior](self, actor, target, action_pos, action_dir)
	end
	self:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	return fx
end

---
--- Called when an ActionFXLight is placed in the game world.
---
--- @param fx ActionFXLight The ActionFXLight instance that was placed.
--- @param actor table The actor associated with the ActionFXLight.
--- @param target table The target associated with the ActionFXLight.
--- @param obj table The object associated with the ActionFXLight.
--- @param spot number The spot index associated with the ActionFXLight.
--- @param posx number The X position of the ActionFXLight.
--- @param posy number The Y position of the ActionFXLight.
--- @param posz number The Z position of the ActionFXLight.
--- @param angle number The angle of the ActionFXLight.
--- @param axisx number The X axis of the ActionFXLight.
--- @param axisy number The Y axis of the ActionFXLight.
--- @param axisz number The Z axis of the ActionFXLight.
--- @param action_pos table The position of the action associated with the ActionFXLight.
--- @param action_dir table The direction of the action associated with the ActionFXLight.
---
function ActionFXLight:OnLightPlaced(fx, actor, target, obj, spot, posx, posy, posz, angle, axisx, axisy, axisz, action_pos, action_dir)
	--project specific cb
end

---
--- Called when an ActionFXLight is destroyed.
---
--- @param fx ActionFXLight The ActionFXLight instance that was destroyed.
---
function ActionFXLight:OnLightDone(fx)
	--project specific cb
end

---
--- Destroys the ActionFXLight associated with the given actor and target.
---
--- @param actor table The actor associated with the ActionFXLight.
--- @param target table The target associated with the ActionFXLight.
---
function ActionFXLight:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValid(fx) then
		if (self.Type ~= "PointLightFlicker" and self.Type ~= "SpotLightFlicker") and self.FadeOut > 0 then
			fx:Fade(self.FadeOutColor, self.FadeOutIntensity, self.FadeOut)
			self:CreateThread(function(self, fx)
				Sleep(self.FadeOut)
				DoneObject(fx)
				self:OnLightDone(fx)
			end, self, fx)
		else
			DoneObject(fx)
			self:OnLightDone(fx)
		end
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	end
end

---
--- Detaches the ActionFXLight associated with the given actor and target.
---
--- This function is called to detach the ActionFXLight from the actor and target. If the light has not been placed yet (i.e. the `fx` variable is a thread), a warning message is printed. Otherwise, the light object is detached using `PreciseDetachObj`.
---
--- @param actor table The actor associated with the ActionFXLight.
--- @param target table The target associated with the ActionFXLight.
---
function ActionFXLight:BehaviorDetach(actor, target)
	local fx = self:GetAssignedFX(actor, target)
	if not fx then return end
	if IsValidThread(fx) then
		printf("FX Light Detach Behavior can not be run before the light is placed (Delay %d is very large)", self.Delay)
	elseif IsValid(fx) then
		PreciseDetachObj(fx)
	end
end

---
--- Utility function to test the placement of an ActionFXLight object.
---
--- This function is used to test the placement of an ActionFXLight object in the editor. It creates a PointLight object and positions it based on the camera or terrain cursor position. The light's properties are set according to the properties of the ActionFXLight object being tested.
---
--- @param editor_obj table The ActionFXLight object being tested.
--- @param fx table The properties of the ActionFXLight object.
--- @param prop_id string The property ID of the ActionFXLight object.
---
function TestActionFXLight(editor_obj, fx, prop_id)
	TestActionFXObjectEnd()
	if (fx[prop_id] or "") == "" then
		return
	end
	local obj = PlaceObject("PointLight")
	if not obj then
		return
	end
	LastTestActionFXObject = obj
	local eye_pos, look_at
	if camera3p.IsActive() then
		eye_pos, look_at = camera.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		eye_pos, look_at = cameraMax.GetPosLookAt()
	else
		look_at = GetTerrainGamepadCursor()
	end
	look_at = look_at:SetZ(terrain.GetHeight(look_at)+2*guim)
	local posx, posy = look_at:xy()
	local posz = terrain.GetHeight(look_at) + 2*guim
	FXOrient(obj, posx, posy, posz)
	obj:SetCastShadows(fx.CastShadows)
	obj:SetDetailedShadows(fx.DetailedShadows)
	obj:SetAttenuationRadius(fx.Radius)
	obj:SetInterior(fx.Interior)
	obj:SetExterior(fx.Exterior)
	obj:SetInteriorAndExteriorWhenHasShadowmap(fx.InteriorAndExteriorWhenHasShadowmap)
	if self.AlwaysRenderable then
		obj:SetGameFlags(const.gofAlwaysRenderable)
	end
	if fx.Type == "PointLightFlicker" or fx.Type == "SpotLightFlicker" then
		obj:SetColor0(fx.Color0)
		obj:SetIntensity0(fx.Intensity0)
		obj:SetColor1(fx.Color1)
		obj:SetIntensity1(fx.Intensity1)
		obj:SetPeriod(fx.Period)
	elseif fx.FadeIn > 0 then
		obj:SetColor(fx.StartColor)
		obj:SetIntensity(fx.StartIntensity)
		obj:Fade(fx.Color, fx.Intensity, fx.FadeIn)
	else
		obj:SetColor(fx.Color)
		obj:SetIntensity(fx.Intensity)
	end
	if fx.Time >= 0 then
		self:CreateThread(function(fx, obj)
			local time = fx.Time
			if fx.FadeOut > 0 then
				local t = Min(time, fx.FadeOut)
				Sleep(time-t)
				if IsValid(obj) then
					obj:Fade(fx.FadeOutColor, fx.FadeOutIntensity, t)
					Sleep(t)
				end
			else
				Sleep(time)
			end
			TestActionFXObjectEnd(obj)
		end, fx, obj)
	end
end

--============================= FX Colorization =======================

DefineClass.ActionFXColorization = {
	__parents = { "ActionFX" },
	properties = {
		{ id = "Color1", category = "Colorization", editor = "color", default = RGB(255,255,255) },
		{ id = "Color2_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color2", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color2_Enable end },
		{ id = "Color3_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color3", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color3_Enable end },
		{ id = "Color4_Enable", category = "Colorization", editor = "bool", default = false },
		{ id = "Color4", category = "Colorization", editor = "color", default = RGB(255,255,255), read_only = function(self) return not self.Color4_Enable end },
		{ id = "Source", category = "Colorization", default = "Actor", editor = "dropdownlist", items = { "Actor", "ActorParent", "ActorOwner", "Target" } },
	},
	fx_type = "Colorization",
}

---
--- Handles the colorization effect for an ActionFXColorization object.
---
--- @param self ActionFXColorization The ActionFXColorization object.
--- @param color_modifier table The color modifier to apply to the object.
--- @param actor table The actor associated with the effect.
--- @param target table The target associated with the effect.
--- @param obj table The object to apply the colorization effect to.
---

_ColorizationFunc = function(self, color_modifier, actor, target, obj)
	if self.Delay > 0 then
		Sleep(self.Delay)
	end
	local fx = PlaceFX_Colorization(obj, color_modifier)
	if self:TrackFX() then
		self:AssignFX(actor, target, fx)
	end
	if fx and self.Time > 0 then
		Sleep(self.Time)
		RemoveFX_Colorization(obj, fx)
	end
end

---
--- Plays the colorization effect for an ActionFXColorization object.
---
--- @param self ActionFXColorization The ActionFXColorization object.
--- @param actor table The actor associated with the effect.
--- @param target table The target associated with the effect.
---
function ActionFXColorization:PlayFX(actor, target)
	local obj = self:GetLocObj(actor, target)
	if not IsValid(obj) then
		printf("FX Colorization has invalid object: %s", self.Source)
		return
	end
	local color_modifier = self:ChooseColor()
	if self.Delay <= 0 and self.Time <= 0 then
		local fx = PlaceFX_Colorization(obj, color_modifier)
		if fx and self:TrackFX() then
			self:AssignFX(actor, target, fx)
		end
		return
	end
	local thread = self:CreateThread(_ColorizationFunc, self, color_modifier, actor, target, obj)
	if self:TrackFX() then
		self:DestroyFX(actor, target)
		self:AssignFX(actor, target, thread)
	end
end

---
--- Destroys the FX associated with the ActionFXColorization object for the given actor and target.
---
--- @param self ActionFXColorization The ActionFXColorization object.
--- @param actor table The actor associated with the effect.
--- @param target table The target associated with the effect.
---
function ActionFXColorization:DestroyFX(actor, target)
	local fx = self:AssignFX(actor, target, nil)
	if not fx then
		return
	elseif IsValidThread(fx) then
		DeleteThread(fx)
	else
		local obj = self:GetLocObj(actor, target)
		RemoveFX_Colorization(obj, fx)
	end
end

---
--- Chooses a color for the colorization effect based on the enabled color variations.
---
--- @param self ActionFXColorization The ActionFXColorization object.
--- @return RGBA The chosen color.
---
function ActionFXColorization:ChooseColor()
	local color_variations = 1
	if self.Color2_Enable then color_variations = color_variations + 1 end
	if self.Color3_Enable then color_variations = color_variations + 1 end
	if self.Color4_Enable then color_variations = color_variations + 1 end
	if color_variations == 1 then
		return self.Color1
	end
	local idx = AsyncRand(color_variations)
	if idx == 0 then
		return self.Color1
	end
	if self.Color2_Enable then
		idx = idx - 1
		if idx == 0 then
			return self.Color2
		end
	end
	if self.Color3_Enable then
		idx = idx - 1
		if idx == 0 then
			return self.Color3
		end
	end
	return self.Color4
end

DefineClass.ActionFXInitialColorization = {
	__parents = { "ActionFXColorization" },
	fx_type = "ColorizationInitial",
	properties = {
		{ id = "Target", },
		{ id = "Delay", },
		{ id = "Id", },
		{ id = "Disabled", },
		{ id = "Time", },
		{ id = "EndRules", },
		{ id = "Behavior", },
		{ id = "BehaviorMoment", },
	},
}

local default_color_modifier = RGBA(100, 100, 100, 0)

---
--- Plays the colorization effect for an ActionFXInitialColorization object.
---
--- @param actor table The actor object.
--- @param target table The target object.
--- @param action_pos vector3 The position of the action.
--- @param action_dir vector3 The direction of the action.
---
function ActionFXInitialColorization:PlayFX(actor, target, action_pos, action_dir)
	local obj = self:GetLocObj(actor, target)
	if not IsValid(obj) then
		printf("FX Colorization has invalid object: %s", self.Source)
		return
	end
	if obj:GetColorModifier() == default_color_modifier then
		local color = self:ChooseColor()
		obj:SetColorModifier(color)
	end
end

MapVar("fx_colorization", {}, weak_keys_meta)

---
--- Adds a color modification effect to the specified object.
---
--- @param obj table The object to apply the color modification to.
--- @param color_modifier table The color modifier to apply to the object.
--- @return table The created color modification effect.
---
function PlaceFX_Colorization(obj, color_modifier)
	if not IsValid(obj) then
		return
	end
	local fx = { color_modifier }
	local list = fx_colorization[obj]
	if not list then
		list = { obj:GetColorModifier() }
		fx_colorization[obj] = list
	end
	table.insert(list, fx)
	obj:SetColorModifier(color_modifier)
	return fx
end

---
--- Removes a color modification effect from the specified object.
---
--- @param obj table The object to remove the color modification from.
--- @param fx table The color modification effect to remove.
---
function RemoveFX_Colorization(obj, fx)
	local list = fx_colorization[obj]
	if not list then return end
	if not IsValid(obj) then
		fx_colorization[obj] = nil
		return
	end
	local len = #list
	if list[len] ~= fx then
		table.remove_value(list, fx)
	elseif len == 2 then
		fx_colorization[obj] = nil
		obj:SetColorModifier(list[1])
	else
		list[len] = nil
		obj:SetColorModifier(list[len-1][1])
	end
end


--=============================

DefineClass.SpawnFXObject = {
	__parents = { "Object", "ComponentAttach" },
	__hierarchy_cache = true,
	
	fx_actor_base_class = "",
}

---
--- Initializes the SpawnFXObject and plays the "Spawn" FX with the "start" moment.
---
--- This function is called when the SpawnFXObject is initialized.
---
function SpawnFXObject:GameInit()
	PlayFX("Spawn", "start", self)
end

---
--- Finalizes the SpawnFXObject and plays the "Spawn" FX with the "end" moment.
---
--- This function is called when the SpawnFXObject is done.
---
--- @param self table The SpawnFXObject instance.
---
function SpawnFXObject:Done()
	if IsValid(self) and self:IsValidPos() then
		PlayFX("Spawn", "end", self)
	end
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "Spawn")
end

--=============================

function OnMsg.OptionsApply()
	FXCache = false
end

---
--- Retrieves a list of FX actions that match the given criteria.
---
--- @param actionFXClass string The class of the action FX.
--- @param actionFXMoment string The moment of the action FX.
--- @param actorFXClass string The class of the actor FX.
--- @param targetFXClass string The class of the target FX.
--- @param list table (optional) The list to append the matching FX to.
--- @return table The list of matching FX.
---
function GetPlayFXList(actionFXClass, actionFXMoment, actorFXClass, targetFXClass, list)
	local remove_ids
	local inherit_actions = actionFXClass  and (FXInheritRules_Actions or RebuildFXInheritActionRules())[actionFXClass]
	local inherit_moments = actionFXMoment and (FXInheritRules_Moments or RebuildFXInheritMomentRules())[actionFXMoment]
	local inherit_actors  = actorFXClass   and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[actorFXClass]
	local inherit_targets = targetFXClass  and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[targetFXClass]
	local i, action = 0, actionFXClass
	while true do
		local rules = action and FXRules[action]
		if rules then
			local i, moment = 0, actionFXMoment
			while true do
				local rules = moment and rules[moment]
				if rules then
					local i, actor = 0, actorFXClass
					while true do
						local rules = actor and rules[actor]
						if rules then
							local i, target = 0, targetFXClass
							while true do
								local rules = target and rules[target]
								if rules then
									for i = 1, #rules do
										local fx = rules[i]
										if not fx.Disabled and fx.Chance > 0 and 
											fx.DetailLevel >= hr.FXDetailThreshold and
											(not IsKindOf(fx, "ActionFX") or MatchGameState(fx.GameStatesFilter))
										then
											if fx.fx_type == "FX Remove" then 
												if fx.FxId ~= "" then
													remove_ids = remove_ids or {}
													remove_ids[fx.FxId] = "remove"
												end
											elseif fx.Action == "any" and fx.Moment == "any" then
												-- invalid, probably just created FX
											else
												list = list or {}
												list[#list+1] = fx
											end
										end
									end
								end
								if target == "any" then break end
								i = i + 1
								target = inherit_targets and inherit_targets[i] or "any"
							end
						end
						if actor == "any" then break end
						i = i + 1
						actor = inherit_actors and inherit_actors[i] or "any"
					end
				end
				if moment == "any" then break end
				i = i + 1
				moment = inherit_moments and inherit_moments[i] or "any"
			end
		end
		if action == "any" then break end
		i = i + 1
		action = inherit_actions and inherit_actions[i] or "any"
	end
	if list and remove_ids then
		for i = #list, 1, -1 do
			if remove_ids[list[i].FxId] == "remove" then
				table.remove(list, i)
				if i == 1 and #list == 0 then
					list = nil
				end
			end
		end
	end
	return list
end

if Platform.developer then
local old_GetPlayFXList = GetPlayFXList
---
--- Retrieves a list of active FX (effects) that should be played, filtering out any FX that are marked as "solo".
---
--- @param ... Any additional arguments to pass to the original `GetPlayFXList` function.
--- @return table|nil A list of FX that should be played, or `nil` if there are no FX to play.
---
function GetPlayFXList(...)
	local list = old_GetPlayFXList(...)
	if g_SoloFX_count > 0 and list then
		for i = #list, 1, -1 do
			local fx = list[i]
			local solo
			if fx.class == "ActionFXBehavior" then
				solo = fx.fx.Solo
			else
				solo = fx.Solo
			end
			if solo then
				table.remove(list, i)
			end
		end
	end
	
	return list
end
end

local function ListCopyMembersOnce(list, added, source, member)
	if not source then return end
	for i = 1, #source do
		local v = source[i][member]
		if not added[v] then
			added[v] = true
			list[#list+1] = v
		end
	end
end

local function ListCopyOnce(list, added, source)
	if not source then return end
	for i = 1, #source do
		local v = source[i]
		if not added[v] then
			added[v] = true
			list[#list+1] = v
		end
	end
end

StaticFXActionsCache = false

---
--- Retrieves a cached list of static FX actions.
---
--- If the cache is not available, this function will gather the list of FX actions and cache it for future use.
---
--- @return table A list of static FX actions.
---
function GetStaticFXActionsCached()
	if StaticFXActionsCache then
		return StaticFXActionsCache
	end
	
	local list = {}
	Msg("GatherFXActions", list)
	local added = { any = true, [""] = true }
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	ListCopyMembersOnce(list, added, FXLists.ActionFXInherit_Action, "Action")
	ClassDescendants("FXObject", function(classname, class)
		if class.fx_action_base then
			local name = class.fx_action or classname
			if not added[name] then
				list[#list+1] = name
				added[name] = true
			end
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
	StaticFXActionsCache = list
	return StaticFXActionsCache
end

---
--- Retrieves a list of FX action classes that can be used in an FX combo.
---
--- The list includes default actions as well as any FX action classes that have a "Moment" member.
--- The list is sorted alphabetically and de-duplicated.
---
--- @param fx The FX object to gather the action classes for.
--- @return table A list of FX action class names.
---
function ActionFXClassCombo(fx)
	local list = {}
	local entity = fx and rawget(fx, "AnimEntity") or ""
	if IsValidEntity(entity) then
		list[#list + 1] = ""
		for _, anim in ipairs(GetStates(entity)) do
			list[#list + 1] = FXAnimToAction(anim)
		end
		list[#list + 1] = "----------"
	end
	table.iappend(list, GetStaticFXActionsCached())
	return list
end

---
--- Retrieves a list of FX moment classes that can be used in an FX combo.
---
--- The list includes a set of default moments as well as any FX moment classes that have a "Moment" member.
--- The list is sorted alphabetically and de-duplicated.
---
--- @param fx The FX object to gather the moment classes for.
--- @return table A list of FX moment class names.
---
function ActionMomentFXCombo(fx)
	local default_list = {
		"any",
		"",
		"start",
		"end",
		"hit",
		"interrupted",
		"recharge",
		"new_target",
		"target_lost",
		"channeling-start",
		"channeling-end",
	}
	local list = {}
	local added = { any = true }
	for i = 1, #default_list do
		added[default_list[i]] = true
	end
	for classname, fxlist in pairs(FXLists) do
		if g_Classes[classname]:HasMember("Moment") then
			ListCopyMembersOnce(list, added, fxlist, "Moment")
		end
	end
	local list2 = {}
	Msg("GatherFXMoments", list2, fx)
	ListCopyOnce(list, added, list2)
	for i = 1, #default_list do
		table.insert(list, i, default_list[i])
	end
	added = {}
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	table.sort(list, CmpLower)
	return list
end

local function GatherFXActors(list)
	Msg("GatherFXActors", list)
	local added = { any = true }
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	ListCopyMembersOnce(list, added, FXLists.ActionFXInherit_Actor, "Actor")
	ClassDescendants("FXObject", function(classname, class)
		if class.fx_actor_base_class then
			local name = class.fx_actor_class or classname
			if name and not added[name] then
				list[#list+1] = name
				added[name] = true
			end
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
end

StaticFXActorsCache = false

---
--- Returns a list of FX actor class names that can be used in the FX actor combo box.
---
--- If the `StaticFXActorsCache` is not initialized, this function will gather the list of FX actor
--- class names and store it in the cache. Otherwise, it will return the cached list.
---
--- @return table<string> A list of FX actor class names.
---
function ActorFXClassCombo()
	if not StaticFXActorsCache then
		local list = {}
		GatherFXActors(list)
		StaticFXActorsCache = list
	end
	return StaticFXActorsCache
end

StaticFXTargetsCache = false

---
--- Returns a list of FX target class names that can be used in the FX target combo box.
---
--- If the `StaticFXTargetsCache` is not initialized, this function will gather the list of FX target
--- class names and store it in the cache. Otherwise, it will return the cached list.
---
--- @return table<string> A list of FX target class names.
---
function TargetFXClassCombo()
	if not StaticFXTargetsCache then
		local list = {}
		Msg("GatherFXTargets", list)
		GatherFXActors(list)
		table.insert(list, 2, "ignore")
		StaticFXTargetsCache = list
	end
	return StaticFXTargetsCache
end

---
--- Hooks the action FX combo box with a list of available FX classes, excluding the "any" option.
---
--- @param fx table The FX object to get the action FX class combo options from.
--- @return table A list of action FX class names, excluding "any".
---
function HookActionFXCombo(fx)
	local actions = ActionFXClassCombo(fx)
	table.remove_value(actions, "any")
	table.insert(actions, 1, "")
	return actions
end

---
--- Hooks the moment FX combo box with a list of available FX classes, excluding the "any" option.
---
--- @param fx table The FX object to get the moment FX class combo options from.
--- @return table A list of moment FX class names, excluding "any" and with an empty string added at the beginning.
---
function HookMomentFXCombo(fx)
	local actions = ActionMomentFXCombo(fx)
	table.remove_value(actions, "any")
	table.insert(actions, 1, "")
	return actions
end

---
--- Hooks the moment FX combo box with a list of available FX classes, excluding the "any" and empty string options.
---
--- @param fx table The FX object to get the moment FX class combo options from.
--- @return table A list of moment FX class names, excluding "any" and with an empty string.
---
function ActionMomentNamesCombo(fx)
	local actions = ActionMomentFXCombo(fx)
	table.remove_value(actions, "any")
	table.remove_value(actions, "")
	return actions
end

local class_to_behavior_items

---
--- Hooks the action FX behavior combo box with a list of available FX behaviors, excluding the "Destroy" option.
---
--- @param fx table The FX object to get the action FX behavior combo options from.
--- @return table A list of action FX behavior names, excluding "Destroy" and with an empty string added at the beginning.
---
function ActionFXBehaviorCombo(fx)
	local class = fx.class
	class_to_behavior_items = class_to_behavior_items or {}
	local list = class_to_behavior_items[class]
	if not list then
		list = { { text = "Destroy", value = "DestroyFX" } }
		for name, func in fx:__enum() do
			if type(func) == "function" and type(name) == "string" then
				local text
				if string.starts_with(name, "Behavior") then
					text = string.sub(name, 9)
				end
				if text then
					list[#list + 1] = { text = text, value = name }
				end
			end
		end
		table.sort(list, function(a, b) return CmpLower(a.text, b.text) end)
		table.insert(list, 1, { text = "", value = "" })
		class_to_behavior_items[class] = list
	end
	return list
end

---
--- Hooks the FX spot combo box with a list of available FX spots, including the "Origin" and empty string options.
---
--- @return table A list of FX spot names, including "Origin" and an empty string.
---
function ActionFXSpotCombo()
	local list, added = {}, { Origin = true, [""] = true }
	Msg("GatherFXSpots", list)
	for i = #list, 1, -1 do
		if not added[list[i]] then
			added[list[i]] = true
		else
			list[i], list[#list] = list[#list], nil
		end
	end
	for _, t1 in pairs(FXRules) do
		for _, t2 in pairs(t1) do
			for _, t3 in pairs(t2) do
				for i = 1, #t3 do
					local spot = rawget(t3[i], "Spot")
					if spot and not added[spot] then
						list[#list+1] = spot
						added[spot] = true
					end
				end
			end
		end
	end
	table.sort(list, CmpLower)
	table.insert(list, 1, "Origin")
	return list
end

---
--- Gathers a list of all unique source props used in FX rules.
---
--- @return table A list of all unique source prop names used in FX rules.
---
function ActionFXSourcePropCombo()
	local list, added = {}, { [""] = true }
	for _, t1 in pairs(FXRules) do
		for _, t2 in pairs(t1) do
			for _, t3 in pairs(t2) do
				for i = 1, #t3 do
					local spot = rawget(t3[i], "SourceProp")
					if spot and not added[spot] then
						list[#list+1] = spot
						added[spot] = true
					end
				end
			end
		end
	end
	table.sort(list, CmpLower)
	return list
end

DefineClass.CameraObj = {
	__parents = { "SpawnFXObject", "CObject", "ComponentInterpolation" },
	entity = "InvisibleObject",
	flags = { gofAlwaysRenderable = true, efSelectable = false, cofComponentCollider = false },
}

MapVar("g_CameraObj", function()
	local cam = CameraObj:new()
	cam:SetSpecialOrientation(const.soUseCameraTransform)
	return cam
end)

local IsValid = IsValid
local SnapToCamera

function OnMsg.OnRender()
	local obj = g_CameraObj
	SnapToCamera = SnapToCamera or IsEditorActive() and empty_func or CObject.SnapToCamera
	if IsValid(obj) then
		SnapToCamera(obj)
	end
end

function OnMsg.GameEnterEditor()
	if IsValid(g_CameraObj) then
		g_CameraObj:ClearEnumFlags(const.efVisible)
	end
	SnapToCamera = empty_func
end

function OnMsg.GameExitEditor()
	if IsValid(g_CameraObj) then
		g_CameraObj:SetEnumFlags(const.efVisible)
	end
	SnapToCamera = CObject.SnapToCamera
end

if Platform.asserts then

if FirstLoad then
	ObjToSoundInfo = false
end
local ObjSoundErrorHash = false

function OnMsg.ChangeMap()
	ObjToSoundInfo = false
	ObjSoundErrorHash = false
end

local function GetFXInfo(fx)
	return string.format("%s-%s-%s-%s", tostring(fx.Action), tostring(fx.Moment), tostring(fx.Actor), tostring(fx.Target))
end
local function GetSoundInfo(fx, sound)
	return string.format("'%s' from [%s]", sound, GetFXInfo(fx))
end

---
--- Marks an object with a sound information.
---
--- This function is used to track the sound information associated with an object.
--- It checks if the current sound information is different from the previous one,
--- and if so, it logs an error message.
---
--- @param fx table The action FX object associated with the sound.
--- @param obj CObject The object that the sound is associated with.
--- @param sound string The name of the sound.
---
function MarkObjSound(fx, obj, sound)
end
MarkObjSound = function(fx, obj, sound)
	local time = RealTime() + GameTime()
	
	ObjToSoundInfo = ObjToSoundInfo or setmetatable({}, weak_keys_meta)
	local info = ObjToSoundInfo[obj]
	if not info then
		ObjToSoundInfo[obj] = { sound, fx, time }
		return
	end
	--print(gt, rt, GetSoundInfo(fx, sound))
	local prev_sound, prev_fx, prev_time = info[1], info[2], info[3]
	if time == prev_time then
		local sname, sbank, stype, shandle, sduration, stime = obj:GetSound()
		if sbank == prev_sound then
			local str = GetSoundInfo(fx, sound)
			local str_prev = GetSoundInfo(prev_fx, prev_sound)
			local err_hash = xxhash(str, str_prev)
			ObjSoundErrorHash = ObjSoundErrorHash or {}
			if not ObjSoundErrorHash[err_hash] then
				ObjSoundErrorHash[err_hash] = err_hash
				StoreErrorSource(obj, "Sound", str, "replaced", str_prev)
			end
		end
	end
	info[1], info[2], info[3] = sound, fx, time
end

end -- Platform.asserts