const.AnimChannel_RightHandGrip = 2
const.AnimChannel_Pain = 3
const.PathTurnAnimChnl = 4
--const.AnimChannel_VerticalGrip

const.PainAnimWeight = 1000
const.PainAnimGrazingWeight = 300
const.PainAnimWeightMoment = 100
local PainEasing = GetEasingIndex("Sin in/out")

const.StopAnimCrossfadeTime = 400

DefineConstInt("Camera", "BufferSizeNoCameraMov", 30, 1, "Defines how much buffer (100% - the_value % from each side) of the screen will NOT be taken into account when deciding if camera should snap from one point to another.")

if FirstLoad then
	g_LocPollyActors = {
		{ value = "Nicole", text = "Nicole (female)", },
		{ value = "Amy", text = "Amy (female)", },
		{ value = "Emma", text = "Emma (female)", },
		{ value = "Aditi", text = "Aditi (female)", },
		{ value = "Raveena", text = "Raveena (female)", },
		{ value = "Joanna", text = "Joanna (female)", },
		{ value = "Kendra", text = "Kendra (female)", },
		{ value = "Kimberly", text = "Kimberly (female)", },
		{ value = "Salli", text = "Salli (female)", },
		-- { value = "Tatyana", text = "Tatyana (female)", }, -- disabled because other Russian-accent voice, Maxim below, produces garbled voice, don't use without checking it it's fixed by Amazon
		{ value = "Russell", text = "Russell (male)", },
		{ value = "Brian", text = "Brian (male)", },
		{ value = "Joey", text = "Joey (male)", },
		{ value = "Matthew", text = "Matthew (male)", },
		{ value = "Geraint", text = "Geraint (male)", },
		-- { value = "Maxim", text = "Maxim (male)" }, -- produces garbled voice, don't use without checking it it's fixed by Amazon
		{ value = "Ivy", text = "Ivy (child)", },
		{ value = "Justin", text = "Justin (child)", },
	}
	g_LocPollyActorsMatchTable = {}
	g_StanceActionDefault = "do not change"
end

local RandomWalkAnimBehaviors = {
	["Visit"] = true,
	["Roam"] = true,
	["RoamSingle"] = true,
	["Ambient"] = true,
}

HpToText = {
	Hidden = T{""},
	Dead = T(541985975283, "Dead"),
	Dying = T(179713645915, "Almost dead"),
	Critical = T(127741862032, "Severely Wounded"),
	Wounded = T(811971736433, "Wounded"),
	Poor = T(121790238609, "Weak"),
	Healthy = T(150774995803, "Healthy"),
	Strong = T(830864531146, "Strong"),
	Excellent = T(341748793018, "Very strong"),
	Uninjured = T(586026778443, "Uninjured"),
}

DieChanceToText = {
	None = T(971598159331, --[[chance to die]] "None"),
	Low = T(283826279782, --[[chance to die]] "Low"),
	Moderate = T(904355103349, --[[chance to die]] "Moderate"),
	High = T(295409078209, --[[chance to die]] "High"),
	VeryHigh = T(426026245987, --[[chance to die]] "Very High"),
}

local KeepAimIKCommands = {
	Idle = true,
	AimIdle = true,
	OpportunityAttack = true,
	PreparedAttackIdle = true,
	ExecFirearmAttacks = true,
	HeavyWeaponAttack = true,
	FirearmAttack = true,
}

DefineClass.UnitBase = {
	__parents = {"UnitProperties", "UnitInventory", "StatusEffectObject", "ReactionObject" },
}
DefineReactionsPreset("Unit", "UnitBase", "unit_reactions", "MsgReactionsPreset") -- DefineClass.UnitReactionsPreset

--- Unregisters all reactions associated with the unit and its equipped items.
--- This function is called when the unit is removed from the game or when its reactions need to be updated.
--- It iterates through the unit's status effects and removes the reactions associated with each effect.
--- It also iterates through the unit's equipped items and removes the reactions associated with each item.
--- The `SetpieceWeapon` slot is skipped, as it is a special case and does not have associated reactions.
function UnitBase:UnregisterReactions()
	for _, effect in ipairs(self.StatusEffects) do
		self:RemoveReactions(effect)
	end
	
	self:ForEachItem(false, function(item, slot, left, top, self)
		if slot ~= "SetpieceWeapon" then
			item:UnregisterReactions(self)
		end
	end, self)
end

--- Registers all reactions associated with the unit and its equipped items.
--- This function is called when the unit is added to the game or when its reactions need to be updated.
--- It iterates through the unit's status effects and adds the reactions associated with each effect.
--- It also iterates through the unit's equipped items and adds the reactions associated with each item.
--- The `SetpieceWeapon` slot is skipped, as it is a special case and does not have associated reactions.
function UnitBase:RegisterReactions()
	for _, effect in ipairs(self.StatusEffects) do
		self:AddReactions(effect, effect.unit_reactions)
	end
	
	self:ForEachItem(false, function(item, slot, left, top, self)
		if slot ~= "SetpieceWeapon" then
			item:RegisterReactions(self) -- will add reactions from item and components (in case of firearm with components)
		end
	end, self)
end

function OnMsg.MercHired(merc_id, price, days, alreadyHired)
	if not alreadyHired then
		gv_UnitData[merc_id]:RegisterReactions()
	end
end

---
--- Calculates the personal morale of the unit based on various factors, such as team morale, disliked and liked mercenaries, and the unit's own health status.
---
--- @param self UnitBase The unit object.
--- @return number The personal morale of the unit, clamped between -3 and 3.
---
function UnitBase:GetPersonalMorale()
	local teamMorale = self.team and self.team.morale or 0
	local personalMorale = 0
	
	--reduce morale for at least one disliked merc in team
	local isDisliking = false
	for _, dislikedMerc in ipairs(self.Dislikes) do
		local dislikedIndex = table.find(self.team.units, "session_id", dislikedMerc)
		if dislikedIndex and not self.team.units[dislikedIndex]:IsDead() then
			personalMorale = personalMorale - 1
			isDisliking = true
			break
		end
	end
	--increase morale for no disliked and at least one liked merc
	if not isDisliking then
		for _, likedMerc in ipairs(self.Likes) do
			local likedIndex = table.find(self.team.units, "session_id", likedMerc)
			if likedIndex and not self.team.units[likedIndex]:IsDead()  then
				personalMorale = personalMorale + 1
				break
			end
		end
	end
	--lower morale if below 50% or 3+ wounds (REVERT for psycho perk)
	local isWounded = false
	local idx = self:HasStatusEffect("Wounded")
	if idx and self.StatusEffects[idx].stacks >= 3 then
		isWounded = true
	end
	if self.HitPoints < MulDivRound(self.MaxHitPoints, 50, 100) or isWounded then
		if HasPerk(self, "Psycho") then
			personalMorale = personalMorale + 1
		else
			personalMorale = personalMorale - 1
		end
	end
	--lower morale if liked merc has died recently
	for _, likedMerc in ipairs(self.Likes) do
		local ud = gv_UnitData[likedMerc]
		if ud and ud.HireStatus == "Dead" then
			local deathDay = ud.HiredUntil
			if deathDay + 7 * const.Scale.day > Game.CampaignTime then
				personalMorale = personalMorale - 1
				break
			end
		end
	end
	
	personalMorale = self:CallReactions_Modify("OnCalcPersonalMorale", personalMorale)
	
	return Clamp(personalMorale + teamMorale, -3, 3)
end

DefineClass.Unit = {
	__parents = { "Movable", "CombatObject", "UnitBase",
		"GameDynamicSpawnObject", "AppearanceObject", "Interactable", "StepObject", "SyncObject", "ComponentSound",
		"SpawnFXObject", "HittableObject", "ComponentCustomData", "CombatTaskOwner", "AmbientLifeZoneUnit",
	},
	
	properties = {
		{category = "Ambient Life", id = "ViewPerpetual", editor = "buttons", default = false,
			no_edit = function(self) return not self.perpetual_marker end,
			buttons = {
				{ name = "View Perpetual Marker", func = function(self)
					ViewObject(self.perpetual_marker)
				end},
				{ name = "Select Perpetual Marker", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.perpetual_marker)
				end},
			},
		},
		{category = "Ambient Life", id = "ViewSpawner", editor = "buttons", default = false,
			no_edit = function(self) return not self.spawner end,
			buttons = {
				{ name = "View Spawner", func = function(self)
					ViewObject(self.spawner)
				end},
				{ name = "Select  Spawner", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.spawner)
				end},
			},
		},
		{category = "Ambient Life", id = "ViewRoutineSpawner", editor = "buttons", default = false,
			no_edit = function(self) return not self.routine_spawner end,
			buttons = {
				{ name = "View Routine Spawner", func = function(self)
					ViewObject(self.routine_spawner)
				end},
				{ name = "Select Routine Spawner", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.routine_spawner)
				end},
			},
		},
		-- hidden overridden properties
		{id = "animWeight"},
		{id = "animBlendTime"},
		{id = "anim2"},
		{id = "anim2BlendTime"},
	},
	
	flags = { efUnit = true, cofComponentColorizationMaterial = true, gofUnitLighting = true, gofOnRoof = false, gofAdjustZ = true },
	pfclass = 3,
	pfflags = const.pfmDestlockSmart + const.pfmCollisionAvoidance + const.pfmImpassableSource + const.pfmVoxelAligned + const.pfmOrient,
	pfclass_overwritten = false,
	ground_orient = false,
	anim_moments_single_thread = true,
	material_type = "Flesh",
	species = "Human",
	body_type = "Human",
	default_move_style = false,
	cur_move_style = false,
	cur_idle_style = false,
	move_step_fx = false,
	move_stop_anim_len = 0,
	move_stop_foot_left_anim = false,
	move_stop_foot_right_anim = false,

	-- Do not forget to add new class members to Get/SetDynamicData function to save in Game state (see GetCurrentGameVarValues)

	Appearance = false,
	-- reference to the corresponding UnitData in gv_UnitData[unit.session_id], all units (except setpiece testing clones) have this
	session_id = false,
	team = false,

	collision_radius = const.SlabSizeX/3,
	radius = const.SlabSizeX/4,

	stance = "Standing",
	unitdatadef_id = false, -- id in UnitDataDefs
	group = false, -- from UnitDataDefs[self.unitdatadef_id]
	target_dummy = false,
	cover_last_face_time = false,
	last_attack_session_id = false,
	current_weapon = "Handheld A",
	modify_animations_ar = false,

	aim_action_id = false,
	aim_action_params = false,
	aim_results = false,
	aim_attack_args = false,
	aim_fx_target = false,
	aim_fx_thread = false,
	aim_rotate_last_angle = false,
	aim_rotate_cooldown_time = false,
	action_visual_weapon = false,
	weapon_light_fx = false,

	return_pos = false,
	play_sequential_actions = false,
	command_specific_params = false,
	prepared_attack_obj = false,
	melee_threat_contour = false,
	prepared_bombard_zone = false,
	bombard_weapon = false,
	queued_action_id = false,
	queued_action_visual = false,
	queued_action_pos = false,

	is_melee_aim_last_turn = false,
	downing_action_start_time = false,

	last_turn_movement = false,
	last_turn_damaged = false,
	start_turn_pos = false,
	reposition_dest = false,
	reposition_path = false,
	reposition_marker = false,
	last_orientation_angle = false,
	last_attack_pos = false,

	god_mode = false,
	infinite_ammo = false,
	infinite_ap = false,
	infinite_dmg = false,
	infinite_condition = false,

	action_command = false,
	actions_nettravel = 0,  -- sent but not received yet
	ui_reserved_ap = 0,
	ui_override_ap = false, -- when set to something GetUIActionPoints will return this value to hide underlying AP shenanigans
	free_move_ap = 0,
	start_move_total_ap = 0,
	start_move_cost_ap = 0,
	start_move_free_ap = 0,

	combat_path = false,
	combat_path_obj = false,
	using_cumbersome = false, -- has any equipped Cumbersome items (cached, no need to save/load)
	attacked_this_turn = false,
	hit_this_turn = false,
	performed_action_this_turn = false,
	wounded_this_turn = false,
	downed_check_penalty = 0,

	ai_context = false,

	interruptable = true,
	interrupted = false,
	goto_interrupted = false,
	interrupt_callback = false,
	action_interrupt_callback = false,

	is_moving = false,
	goto_target = false,
	goto_stance = false,
	goto_hide = false,
	in_combat_movement = false,
	visibility_override = false,
	traverse_tunnel = false,
	tunnel_blockers = false,
	fallback_walk_speed = 3*guim, -- when the walk anim has no step
	perks_activated = false,
	attack_reason = false, -- additional prefix text to attack log entry (e.g. retaliation, overwatch, etc)
	opportunity_attack = false,
	effect_values = false, -- storage for status effect data/state
	enemy_visual_contact = false, -- does any enemy has visual contact with this unit
	alerted_by_enemy = false,
	last_known_enemy_pos = false, -- last location an enemy unit was seen
	marked_target_attack_args = false,
	
	pending_aware_state = false,
	pending_awareness_role = false,	 -- used for awareness visualization; not persisted
	suspicion = false,
	suspicious_body_seen = false,
	aware_reason = false,
	auto_face = true, -- the unit look at the nearest enemy
	reorientation_thread = false,
	setik_thread = false,

	spawner = false,  --NPC

	synced_anim = false,
	synced_anim_time = 0,
	synced_angle = 0,
	die_anim_prefix = false,
	on_die_attacker = false,
	on_die_hit_descr = false,
	death_explosion_played = false,
	death_fx_object = false,
	interacting_unit = false,
	killed_stance = false,

	combat_badge = false,
	ui_badge = false,
	ui_actions = false,
	combat_cache = false,
	villain_defeated = false,
	retreating = false,
	angle_before_interaction = false,
	highlight_reasons = false,

	banters = false,
	banters_played_lines = false,
	sequential_banter = false,
	approach_banters = false,
	approach_banters_distance = false,
	approach_banters_cooldown_id = false,
	last_played_banter_id = false, -- No need to serialize this
	
	visible = true,
	interactable_highlight_ctr = false,
	highlight_collection = false,
	
	-- general (out-of-combat) behaviors
	behavior = false, -- command to set
	behavior_params = false, -- parameters to set

	-- in-combat behaviors
	combat_behavior = false, -- command to set
	combat_behavior_params = false, -- parameters to set

	entrance_marker = false,

	neutral_ai_dont_move = false,
	neutral_retal_attacked = false,

	pain_thread = false,
	update_attached_weapons_thread = false,

	routine = "StandStill",
	routine_area = "self",
	routine_spawner = false,
	ephemeral = false,
	perpetual_marker = false,
	teleport_allowed_once = false,
	conflict_ignore = false,
	visit_command = false,
	visit_marker = false,
	visit_reached = false,
	cower_forbidden = false,
	cower_from = false,
	cower_angle = false,
	cower_cooldown = false,
	last_roam = false,
	last_visit = false,
	dead_markers_tried = false,
	mourn = false,
	maraud = false,
	enter_map_wait_time = false,
	enter_map_pos = false,
	seen_bodies = false,
	visit_test = false,
	carry_flare = false,
	infected = false,
	innerInfoRevealed = false, --used to mark the unit when revealed from the perk innerinfo

	fx_in_water = false,
	indoors = false,
	unarmed_weapon = false,
	warned_traps_pos = false,
	move_follow_target = false,
	move_follow_dest = false,
	move_attack_target = false,
	move_attack_action_id = false,
	move_attack_in_progress = false,
	waiting_attack = false,

	last_idle_aiming_time = false,

	place_wind_mod_trails = false,
	stain_update_times = false, -- async, visual, not saved

	__toluacode = empty_func,
	PrePlay = empty_func,
	PostPlay = empty_func,
	
	throw_died_message = false,
	is_despawned = false, -- Set briefly in Unit:Despawn before it is destroyed but after the sync with unitdata.
}

local function StoreBehaviorParamTbl(tbl)
	if not tbl then return end
	local stored, stored_handles
	for k, v in pairs(tbl) do
		if IsKindOf(v, "Object") then
			if not stored_handles then
				stored_handles = {}
				stored = stored or {}
				stored.__stored_obj_value = stored_handles
			end
			stored[k] = v.handle
			stored_handles[k] = true
		elseif type(v) == "table" then
			local new_value = StoreBehaviorParamTbl(v)
			if new_value ~= v then
				if not stored then
					stored = {}
				end
				stored[k] = new_value
			end
		end
	end
	if not stored then
		return tbl
	end
	-- copy the skipped values
	for k, v in pairs(tbl) do
		if stored[k] == nil then
			stored[k] = v
		end
	end
	return stored
end

local function RestoreBehaviorParamTbl(stored)
	if not stored then return end
	local stored_handles = stored.__stored_obj_value
	if stored_handles then
		stored.__stored_obj_value = nil
	end
	for k, v in pairs(stored) do
		if type(v) == "table" then
			RestoreBehaviorParamTbl(v)
		end
	end
	for k in pairs(stored_handles) do
		stored[k] = HandleToObject[ stored[k] ]
	end
end

--- Retrieves the dynamic data of a unit, including its session ID, unit data definition ID, groups, behaviors, and other runtime state.
---
--- @param data table A table to store the retrieved dynamic data
function Unit:GetDynamicData(data)
	local class = g_Classes[self.class]
	data.session_id = self.session_id or nil
	data.unitdatadef_id = self.unitdatadef_id or nil
	data.ground_orient = self.ground_orient or nil
	data.stance  = self.stance ~= class.stance and self.stance or nil
	data.return_pos = self.return_pos or nil
	data.current_weapon = self.current_weapon ~= class.current_weapon and self.current_weapon or nil
	data.perks_activated = next(self.perks_activated) and self.perks_activated or nil
	data.Groups = #(self.Groups or "") > 0 and self.Groups or nil
	data.villain_defeated = self.villain_defeated or nil
	data.retreating = self.retreating or nil
	if self.command == "BanterIdle" then
		data.command = "Idle"
	end
	data.command_specific_params = next(self.command_specific_params) and self.command_specific_params or nil
	data.last_attack_session_id = self.last_attack_session_id or nil
	data.banters_played_lines = self.banters_played_lines or nil
	data.free_move_ap = self.free_move_ap ~= 0 and self.free_move_ap or nil
	data.neutral_ai_dont_move = self.neutral_ai_dont_move or nil
	data.enemy_visual_contact = self.enemy_visual_contact or nil
	if next(self.effect_values) then
		local effect_values = {}
		for k, v in pairs(self.effect_values) do
			effect_values[k] = v or nil
		end
		data.effect_values = next(effect_values) and effect_values or nil
	end
	data.is_melee_aim_last_turn = self.is_melee_aim_last_turn or nil
	data.performed_action_this_turn = self.performed_action_this_turn or nil
	data.carry_flare = self.carry_flare or nil

	for i, unit in ipairs(self.attacked_this_turn) do
		data.attacked_this_turn = data.attacked_this_turn or {}
		data.attacked_this_turn[i] = unit.handle
	end
	for i, unit in ipairs(self.hit_this_turn) do
		data.hit_this_turn = data.hit_this_turn or {}
		data.hit_this_turn[i] = unit.handle
	end
	for unit, _ in pairs(self.seen_bodies) do
		data.seen_bodies = data.seen_bodies or {}
		data.seen_bodies[unit:GetHandle()] = true
	end
	data.visit_test = self.visit_test or nil
	data.wounded_this_turn = self.wounded_this_turn or nil
	data.downed_check_penalty = self.downed_check_penalty ~= 0 and self.downed_check_penalty or nil
	data.last_known_enemy_pos = self.last_known_enemy_pos or nil
	data.last_turn_damaged = self.last_turn_damaged or nil

	if self.target_dummy then
		data.pos = self.target_dummy:GetPos()
		data.vpos = nil
		data.vpos_time = nil
	elseif self.traverse_tunnel then
		data.pos = self.traverse_tunnel.end_point
		data.vpos = nil
		data.vpos_time = nil
	end
	if self.behavior then
		data.behavior = self.behavior
		data.behavior_params = StoreBehaviorParamTbl(self.behavior_params)
		if data.behavior == "ExitMap" and data.behavior_params[2] then
			data.behavior_params[2] = Max(0, data.behavior_params[2] - GameTime())
		end
	end
	if self.combat_behavior then
		data.combat_behavior = self.combat_behavior
		data.combat_behavior_params = StoreBehaviorParamTbl(self.combat_behavior_params)
	end
	if self.marked_target_attack_args then
		data.marked_target_attack_args = StoreBehaviorParamTbl(self.marked_target_attack_args)
	end
	if self.spawner then
		data.spawner = self.spawner.handle
	end
	if IsValid(self.prepared_bombard_zone) then
		data.prepared_bombard_zone = self.prepared_bombard_zone.handle
	end

	if next(self.banters) then
		data.banters = self.banters
		data.sequential_banter = self.sequential_banter or nil
	end
	if next(self.approach_banters) then
		data.approach_banters = self.approach_banters
		data.approach_banters_distance = self.approach_banters_distance or nil
		data.approach_banters_cooldown_id = self.approach_banters_cooldown_id or nil
	end
	data.die_anim_prefix = self.die_anim_prefix or nil

	data.aware = self:IsAware() or nil
	data.pending_aware_state = self.pending_aware_state or nil
	data.suspicion = (self.suspicion or 0) > 0 and self.suspicion or nil
	data.suspicious_body_seen = self.suspicious_body_seen or nil
	if IsValid(self.alerted_by_enemy) then
		data.alerted_by_enemy = self.alerted_by_enemy.handle
	end

	data.routine = (self.routine ~= class.routine) and self.routine or nil
	data.routine_area = (self.routine_area ~= class.routine_area) and self.routine_area or nil
	data.routine_spawner = self.routine_spawner and self.routine_spawner.handle or nil
	data.zone = self.zone and self.zone.handle or nil
	data.ephemeral = self.ephemeral or nil
	data.perpetual_marker = self.perpetual_marker and self.perpetual_marker.handle or nil
	data.teleport_allowed_once = self.teleport_allowed_once or nil
	data.conflict_ignore =self.conflict_ignore or nil
	data.visit_command = self.visit_command or nil
	data.visit_reached = self.visit_reached or nil
	data.max_dead_slot_tiles = self.max_dead_slot_tiles or nil
	if self.visit_marker then
		data.visit_marker = self.visit_marker.handle
	end
	data.cower_forbidden = self.cower_forbidden or nil
	if self.cower_from then
		data.cower_from = self.cower_from
		data.cower_angle = self.cower_angle or nil
	end
	data.cower_cooldown = self.cower_cooldown or nil
	data.last_roam = self.last_roam and self.last_roam.handle or nil
	data.last_visit = self.last_visit and self.last_visit.handle or nil
	data.dead_markers_tried = self.dead_markers_tried or nil
	data.mourn = self.mourn and self.mourn.handle or nil
	data.maraud = self.maraud and self.maraud.handle or nil
	data.enter_map_wait_time = self.enter_map_wait_time and (self.enter_map_wait_time - GameTime()) or nil
	data.enter_map_pos = self.enter_map_pos or nil
	data.last_attack_pos = self.last_attack_pos or nil

	local unit_data = UnitDataDefs[self.unitdatadef_id]
	if self.Name ~= (unit_data and unit_data.Name) then
		data.Name = self.Name
	end
	data.default_move_style = self.default_move_style or nil
	data.cur_move_style = self.cur_move_style or nil
	data.cur_idle_style = self.cur_idle_style or nil
	data.on_die_hit_descr = self.on_die_hit_descr or nil
	data.death_explosion_played = self.death_explosion_played or nil
	data.infected = self.infected or nil
	data.innerInfoRevealed = self.innerInfoRevealed or nil
	data.throw_died_message = self.throw_died_message or nil
	data.lastFiringMode = self.lastFiringMode or nil
	data.queued_action_id = self.queued_action_id or nil
end

---
--- Sets the dynamic data for a unit.
---
--- @param data table The data to set for the unit.
--- @field data.session_id number The session ID of the unit.
--- @field data.unitdatadef_id string The ID of the unit data definition.
--- @field data.spawner Unit The spawner of the unit.
--- @field data.target_dummy Unit The target dummy of the unit.
--- @field data.zone Zone The zone the unit is in.
--- @field data.Groups string[] The groups the unit belongs to.
--- @field data.enter_map_wait_time number The time the unit has to wait before entering the map.
--- @field data.enter_map_pos Vector The position the unit will enter the map at.
--- @field data.last_attack_pos Vector The last position the unit attacked from.
--- @field data.combat_behavior string The combat behavior of the unit.
--- @field data.combat_behavior_params table The parameters for the combat behavior.
--- @field data.behavior string The behavior of the unit.
--- @field data.behavior_params table The parameters for the behavior.
--- @field data.marked_target_attack_args table The arguments for the marked target attack.
--- @field data.last_roam Object The last roam object of the unit.
--- @field data.last_visit Object The last visit object of the unit.
--- @field data.perpetual_marker Object The perpetual marker of the unit.
--- @field data.visit_reached boolean Whether the unit has reached the visit.
--- @field data.stance string The stance of the unit.
--- @field data.return_pos Vector The return position of the unit.
--- @field data.current_weapon string The current weapon of the unit.
--- @field data.perks_activated table The perks activated for the unit.
--- @field data.villain_defeated boolean Whether the unit is a defeated villain.
--- @field data.retreating boolean Whether the unit is retreating.
--- @field data.command_specific_params table The command-specific parameters for the unit.
--- @field data.last_attack_session_id number The session ID of the last attack.
--- @field data.free_move_ap number The free move AP of the unit.
--- @field data.neutral_ai_dont_move boolean Whether the neutral AI should not move the unit.
--- @field data.effect_values table The effect values for the unit.
--- @field data.is_melee_aim_last_turn boolean Whether the unit was in melee aim last turn.
--- @field data.enemy_visual_contact boolean Whether the unit has visual contact with an enemy.
--- @field data.suspicion number The suspicion level of the unit.
--- @field data.suspicious_body_seen boolean Whether the unit has seen a suspicious body.
--- @field data.pending_aware_state string The pending aware state of the unit.
--- @field data.max_dead_slot_tiles number The maximum number of dead slot tiles for the unit.
--- @field data.alerted_by_enemy Unit The enemy that alerted the unit.
--- @field data.last_known_enemy_pos Vector The last known position of an enemy.
--- @field data.last_turn_damaged number The last turn the unit was damaged.
--- @field data.performed_action_this_turn boolean Whether the unit performed an action this turn.
--- @field data.carry_flare boolean Whether the unit is carrying a flare.
--- @field data.attacked_this_turn Unit[] The units the unit attacked this turn.
--- @field data.hit_this_turn Unit[] The units that hit the unit this turn.
--- @field data.seen_bodies table The bodies the unit has seen.
--- @field data.visit_test boolean Whether the unit is performing a visit test.
--- @field data.wounded_this_turn boolean Whether the unit was wounded this turn.
--- @field data.downed_check_penalty number The downed check penalty for the unit.
--- @field data.prepared_bombard_zone Object The prepared bombard zone for the unit.
--- @field data.die_anim_prefix string The death animation prefix for the unit.
--- @field data.banters table The banters for the unit.
--- @field data.sequential_banter boolean Whether the unit has sequential banters.
--- @field data.banters_played_lines boolean Whether the unit has played its banters.
--- @field data.approach_banters table The approach banters for the unit.
--- @field data.approach_banters_distance number The distance for the approach banters.
--- @field data.approach_banters_cooldown_id number The cooldown ID for the approach banters.
--- @field data.routine string The routine for the unit.
--- @field data.routine_area string The routine area for the unit.
--- @field data.routine_spawner Unit The routine spawner for the unit.
--- @field data.ephemeral boolean Whether the unit is ephemeral.
--- @field data.teleport_allowed_once boolean Whether the unit is allowed to teleport once.
--- @field data.conflict_ignore boolean Whether the unit ignores conflicts.
--- @field data.visit_command boolean Whether the unit has a visit command.
--- @field data.visit_marker Object The visit marker for the unit.
--- @field data.cower_forbidden boolean Whether the unit is forbidden from cowering.
--- @field data.cower_from Unit The unit the unit is cowering from.
--- @field data.cower_angle number The angle the unit is cowering at.
--- @field data.cower_cooldown number The cooldown for the unit's cowering.
--- @field data.dead_markers_tried boolean Whether the unit has tried dead markers.
--- @field data.mourn Object The mourn object for the unit.
--- @field data.maraud Object The maraud object for the unit.
--- @field data.Name string The name of the unit.
--- @field data.ground_orient boolean Whether the unit is ground oriented.
--- @field data.default_move_style boolean The default move style for the unit.
--- @field data.cur_move_style boolean The current move style for the unit.
--- @field data.cur_idle_style boolean The current idle style for the unit.
--- @field data.on_die_hit_descr boolean The on-die hit description for the unit.
--- @field data.death_explosion_played boolean Whether the death explosion has been played for the unit.
--- @field data.infected boolean Whether the unit is infected.
--- @field data.innerInfoRevealed boolean Whether the unit's inner information has been revealed.
--- @field data.throw_died_message boolean Whether the unit should throw a died message.
--- @field data.lastFiringMode boolean The last firing mode for the unit.
--- @field data.queued_action_id boolean The queued action ID for the unit.
function Unit:SetDynamicData(data)
	self.session_id = data.session_id
	self.unitdatadef_id = data.unitdatadef_id or data.template_name
	self:UpdateFXClass()		-- IsMerc() depends on .unitdatadef_id, e.g. ImportantUnit

	self.spawner = HandleToObject[data.spawner]
	self.target_dummy = HandleToObject[data.target_dummy]

	-- these are needed to be restored before calling EnterMap command of AL
	self.zone = HandleToObject[data.zone] or false
	for _, group_name in ipairs(data.Groups) do
		self:AddToGroup(group_name)
	end
	self.enter_map_wait_time = data.enter_map_wait_time or false
	self.enter_map_pos = data.enter_map_pos or false
	self.last_attack_pos = data.last_attack_pos or false
	if data.combat_behavior then
		RestoreBehaviorParamTbl(data.combat_behavior_params)
		self:SetCombatBehavior(data.combat_behavior, data.combat_behavior_params)
	end
	if data.behavior then
		RestoreBehaviorParamTbl(data.behavior_params)
		if data.behavior == "OverwatchAction" or data.behavior == "PinDown" then
			self:SetCombatBehavior(data.behavior, data.behavior_params)
			self:SetBehavior(data.behavior, data.behavior_params)
		elseif data.behavior == "Dead" or data.behavior == "VillainDefeat" or data.behavior == "Hang" then
			self:SetCombatBehavior(data.behavior, data.behavior_params)
			self:SetBehavior(data.behavior, data.behavior_params)
		elseif data.behavior == "ExitMap" then
			if data.behavior_params[2] then
				data.behavior_params[2] = GameTime() + data.behavior_params[2]
			end
			self:SetBehavior(data.behavior, data.behavior_params)
		else
			self:SetBehavior(data.behavior, data.behavior_params)
		end
	end
	if data.marked_target_attack_args then
		self.marked_target_attack_args = RestoreBehaviorParamTbl(data.marked_target_attack_args)
	end
	 -- this needs to be after restoring self.spawner - long chain of invocations that ultimately results in a neutral unit
	if self.enter_map_wait_time and not IsKindOf(self.zone, "AmbientZoneMarker") then
		-- NOTE: old save with new map source for which unit's spawner zone has been deleted from the map
		DoneObject(self)
		return
	end
	self.last_roam = HandleToObject[data.last_roam] or false
	self.last_visit = HandleToObject[data.last_visit] or false
	self.perpetual_marker = HandleToObject[data.perpetual_marker] or false	-- needed to restore Visit cmd
	self.visit_reached = data.visit_reached or false
	self:FillMerc()

	self.stance = self.species ~= "Human" and "" or data.stance
	
	-- Weird save game compat
	if self.stance and type(self.stance) == "boolean" then
		self.stance = self.species ~= "Human" and "" or "Standing"
	end
	
	self.return_pos = data.return_pos
	self.current_weapon = data.current_weapon
	self.perks_activated = data.perks_activated or {}
	self.villain_defeated = data.villain_defeated
	self.retreating = data.retreating
	self.command_specific_params = data.command_specific_params
	self.last_attack_session_id = data.last_attack_session_id
	self.free_move_ap = data.free_move_ap
	self.neutral_ai_dont_move = data.neutral_ai_dont_move
	self.effect_values = table.copy(data.effect_values or data.effect_expirations) -- savegame compat support (effect_expirations)
	self.is_melee_aim_last_turn = data.is_melee_aim_last_turn or false
	self.enemy_visual_contact = data.enemy_visual_contact
	self.suspicion = data.suspicion
	self.suspicious_body_seen = data.suspicious_body_seen
	self.pending_aware_state = data.pending_aware_state
	if self.pending_aware_state == "reposition" then
		self.pending_aware_state = nil
	end
	self.max_dead_slot_tiles = data.max_dead_slot_tiles or false
	if data.aware then
		self:RemoveStatusEffect("Unaware")
		self:RemoveStatusEffect("Suspicious")
	end
	self.alerted_by_enemy = HandleToObject[data.alerted_by_enemy]
	self.last_known_enemy_pos = data.last_known_enemy_pos
	self.last_turn_damaged = data.last_turn_damaged
	self.performed_action_this_turn = data.performed_action_this_turn
	if data.carry_flare then
		self:RoamAttachFlare()
	end

	self.attacked_this_turn = {}
	for i, handle in ipairs(data.attacked_this_turn) do
		self.attacked_this_turn[i] = HandleToObject[handle]
	end
	self.hit_this_turn = {}
	for i, handle in ipairs(data.hit_this_turn) do
		self.hit_this_turn[i] = HandleToObject[handle]
	end
	self.seen_bodies = {}
	for handle, _ in pairs(data.seen_bodies) do
		local unit = HandleToObject[handle] or false
		self.seen_bodies[unit] = true
	end
	self.visit_test = data.visit_test or false
	self.wounded_this_turn = data.wounded_this_turn
	self.downed_check_penalty = data.downed_check_penalty	
	
	if data.prepared_bombard_zone then
		self.prepared_bombard_zone = HandleToObject[data.prepared_bombard_zone]
	end

	self.die_anim_prefix = data.die_anim_prefix
	self:UpdateMoveAnim()
	self:OnGearChanged("isLoad")

	-- shuffle looping animations
	if self:IsAnimLooping(1) then
		local phase = self:Random(GetAnimDuration(self:GetEntity(), self:GetAnim(1)))
		self:SetAnimPhase(1, phase)
	end

	self.banters = data.banters
	self.sequential_banter = data.sequential_banter or false
	self.banters_played_lines = data.banters_played_lines or false
	self.approach_banters = data.approach_banters
	self.approach_banters_distance = data.approach_banters_distance
	self.approach_banters_cooldown_id = data.approach_banters_cooldown_id

	self.routine = data.routine or "StandStill"
	self.routine_area = data.routine_area or "self"
	self.routine_spawner = HandleToObject[data.routine_spawner] or false
	self.ephemeral = data.ephemeral or false
	self.teleport_allowed_once = data.teleport_allowed_once or false
	self.conflict_ignore = data.conflict_ignore or false
	self.visit_command = data.visit_command or false
	self.visit_marker = HandleToObject[data.visit_marker] or false
	self.cower_forbidden = data.cower_forbidden or false
	self.cower_from = data.cower_from or false
	self.cower_angle = data.cower_angle or false
	self.cower_cooldown = data.cower_cooldown or false
	self.dead_markers_tried = data.dead_markers_tried or false
	self.mourn = HandleToObject[data.mourn] or false
	self.maraud = HandleToObject[data.maraud] or false

	if data.Name then
		self.Name = data.Name
	end
	if data.ground_orient then
		self:SetFootPlant(true, 0)
	else
		self:SetAxis(axis_z)
	end
	self.default_move_style = data.default_move_style or false
	self.cur_move_style = data.cur_move_style or false
	self.cur_idle_style = data.cur_idle_style or false
	self.on_die_hit_descr = data.on_die_hit_descr or false
	if data.death_explosion_played then
		self.death_explosion_played = data.death_explosion_played
		self:PlaceDeathFXObject(true)
	end
	self.infected = data.infected or false
	self.innerInfoRevealed = data.innerInfoRevealed or false
	if self.command == "Idle" and self:IsValidPos() then
		local x, y, z = GetPassSlabXYZ(self)
		if not x or not CanDestlock(self, x, y, z) then
			local has_path, pos = pf.HasPosPath(self, self)
			if pos then
				self:SetPos(GetPassSlab(pos))
			end
		end
	end
	
	self.throw_died_message = data.throw_died_message or false
	self.lastFiringMode = data.lastFiringMode or false
	self.queued_action_id = data.queued_action_id or false

	if data.spawner and not self.spawner then
		self:SetCommand("Despawn") -- the spawner is not present in the new map version
	end
end

function OnMsg.UnitCreated(self)
	if self.unitdatadef_id and next(UnitDataDefs[self.unitdatadef_id].AdditionalGroups) then
		self:AddAdditionalGroups()
	end
end

---
--- Sets the queued action for the unit.
---
--- @param id number|boolean The ID of the queued action, or `false` to clear the queued action.
---
function Unit:SetQueuedAction(id)
	self.queued_action_id = id or false
	if self.ui_badge then
		self.ui_badge:UpdateEnemyVisibility()
	end
	if not self.queued_action_id then
		if IsValid(self.queued_action_visual) then
			DoneObject(self.queued_action_visual)
			self.queued_action_visual = false
		end
		self.queued_action_pos = false
	end	
end

---
--- Adds additional groups to the unit based on the unit's material definition.
---
--- If the unit has any exclusive additional groups, one of them is randomly selected and added.
--- For non-exclusive additional groups, a random roll is performed for each group and the group is added if the roll is successful.
---
--- @param self Unit The unit object.
---
function Unit:AddAdditionalGroups()
	if next(self.additional_groups) then 
		for _, group in ipairs(self.additional_groups) do
			self:AddToGroup(group)
		end
	else
		self.additional_groups = {}
		local exclusiveTable = {}
		for _, group in ipairs(UnitDataDefs[self.unitdatadef_id].AdditionalGroups) do
			if group.Exclusive then
				table.insert(exclusiveTable, {Name = group.Name, Weight = group.Weight})
			else
				local roll = InteractionRand(100, "BanterGroup")
				if roll < group.Weight then
					self:AddToGroup(group.Name) 
					table.insert(self.additional_groups, group.Name)
				end
			end
		end
		
		if next(exclusiveTable) then
			local exclusiveGroup = table.weighted_rand(exclusiveTable, "Weight", InteractionRand(1000000, "BanterGroup"))
			self:AddToGroup(exclusiveGroup.Name)
			table.insert(self.additional_groups, exclusiveGroup.Name)
		end
	end
end

---
--- Initializes a unit object.
---
--- This function is called when a unit is created. It sets up various properties and state for the unit, such as:
--- - Adding the unit to its unit data definition group
--- - Setting up command-specific parameters for the unit's behavior (e.g. idle stance, idle action)
--- - Initializing the unit as a mercenary if it has a session ID
--- - Updating the unit's outfit
--- - Resetting the unit's retreating status
--- - Adding the unit to the "Villains" group if it is a villain
--- - Initializing various unit-specific properties and state
---
--- @param self Unit The unit object.
---
function Unit:Init()
	-- copy base values from material def
	if self.unitdatadef_id then
		self:AddToGroup(self.unitdatadef_id)
	end
	if not self.command_specific_params then
		self.command_specific_params = {}
		if self.spawner then
			local params = {
				weapon_anim_prefix = not self.spawner.use_weapons and "civ_" or nil,
			}
			params.idle_stance = self.spawner.idle_stance ~= g_StanceActionDefault and self.spawner.idle_stance or nil
			params.idle_action = self.spawner.idle_action ~= g_StanceActionDefault and self.spawner.idle_action or nil
			self:SetCommandParams("Idle", params)
			self:SetCommandParams("Visit", params)
			self:SetCommandParams("Roam", params)
			self:SetCommandParams("RoamSingle", params)
		end
	end
	if self.session_id then
		self:InitMerc()
		self:UpdateOutfit()
		self.retreating = nil -- spawning anew resets this status
		if self.villain then
			self:AddToGroup("Villains")
		end
	end
	self.perks_activated = {}
	self.seen_bodies = {}
	self.stain_update_times = {}
	self.AIKeywords = table.copy(self.AIKeywords)
	if IsMerc(self) then
		self.fx_actor_class = "ImportantUnit"
	end
	Msg("UnitCreated", self)
end

--- Initializes a unit object from a material preset.
---
--- This function is called to initialize a unit object from a material preset. It sets up various properties and state for the unit based on the preset.
---
--- @param self Unit The unit object.
--- @param preset table The material preset to initialize the unit from.
function Unit:InitFromMaterialPreset(preset)
end

--- Cleans up and removes the unit from the game state.
---
--- This function is called when a unit is being removed from the game. It performs various cleanup tasks such as:
--- - Unblocking any tunnels the unit was blocking
--- - Removing any dead markers associated with the unit
--- - Removing the unit from its team's unit list
--- - Removing the unit from the global list of units
--- - Clearing any unarmed or bombard weapons the unit had
--- - Removing the unit from the selection
--- - Clearing any combat action state
--- - Deleting any attached threads
--- - Notifying that the unit has despawned
--- - Freeing any visitable state
--- - Clearing any perpetual marker
--- - Clearing the unit as a target dummy
--- - Invalidating the unit's line of sight
--- - Removing the unit from any AI group it was following
---
--- @param self Unit The unit object.
function Unit:Done()
	self:TunnelsUnblock()
	self:RemoveALDeadMarkers()
	if self.team then
		table.remove_value(self.team.units, self)
		if not self.team.neutral then
			for team, list in pairs(g_RevealedUnits) do
				table.remove_value(list, self)
			end
		end
	end
	table.remove_value(g_Units, self)
	if self.session_id and g_Units[self.session_id] == self then
		g_Units[self.session_id] = nil
	end
	if self.unarmed_weapon then
		self.unarmed_weapon = nil
	end
	if self.bombard_weapon then
		DoneObject(self.bombard_weapon)
	end
	SelectionRemove(self)
	SetCombatActionState(self, nil)
	DeleteBadgesFromTarget(self)
	DeleteThread(self.pain_thread)
	DeleteThread(self.update_attached_weapons_thread)
	DeleteThread(self.setik_thread)
	if self:IsSyncObject() then
		Msg("UnitDespawned", self)
	end
	self:FreeVisitable()
	if self.perpetual_marker then
		self.perpetual_marker.perpetual_unit = false
	end
	self:SetTargetDummy(false)
	InvalidateUnitLOS(self)
	local idx = g_AIExecutionController and next(g_AIExecutionController.group_to_follow) and table.find(g_AIExecutionController.group_to_follow, "session_id", self.session_id)
	if idx then
		table.remove(g_AIExecutionController.group_to_follow, idx)
	end
end

--- Sets the behavior of the unit.
---
--- @param self Unit The unit object.
--- @param behavior string The behavior to set for the unit.
--- @param params table Optional parameters for the behavior.
function Unit:SetBehavior(behavior, params)
	self.behavior = behavior
	self.behavior_params = params
	
	if self.carry_flare and behavior and behavior ~= "Roam" and behavior ~= "RoamSingle" then
		self:RoamDropFlare()
	end
end

--- Sets the combat behavior of the unit.
---
--- @param self Unit The unit object.
--- @param behavior string The combat behavior to set for the unit.
--- @param params table Optional parameters for the combat behavior.
function Unit:SetCombatBehavior(behavior, params)
	self.combat_behavior = behavior
	self.combat_behavior_params = params
end

--- Clears the behavior and combat behavior of the unit.
---
--- @param self Unit The unit object.
--- @param behavior string The behavior to clear.
function Unit:ClearBehaviors(behavior)
	if self.behavior == behavior then
		self:SetBehavior()
	end
	if self.combat_behavior == behavior then
		self:SetCombatBehavior()
	end
end

--- Copies properties from one modifiable object to another.
---
--- @param to Modifiable The object to copy properties to.
--- @param source Modifiable The object to copy properties from.
--- @param properties table A table of property definitions to copy.
--- @param copy_values boolean If true, copy the values of table properties instead of just the reference.
function CopyPropertiesShallow(to, source, properties, copy_values)
end
function CopyPropertiesShallow(to,source, properties, copy_values)
	assert(IsKindOf(to, "Modifiable") and IsKindOf(source, "Modifiable"))
	local mods = source.modifications or empty_table
	for i = 1, #properties do
		local prop = properties[i]
		if prop_eval(prop.dont_save, source, prop) then goto continue end
		
			local prop_id = prop.id
			if prop.modifiable then
				to:SetBase(prop_id, source["base_" .. prop_id])
			else
				local value = source:GetProperty(prop_id)
				local source_value_is_dest_default = value == nil or value == to:GetDefaultPropertyValue(prop_id, prop)
				local to_value = to:GetProperty(prop_id)
				local dest_value_is_default = to_value == nil or to_value == value
				local is_default = source_value_is_dest_default and dest_value_is_default
				if is_default then goto continue end
				
				if copy_values and type(to_value) == "table" then
					table.clear(to_value)
					local copy = table.copy(value)
					for key, val in pairs(copy) do
						if IsKindOf(val, "PropertyObject") then
							to_value[key] = val:Clone()
						else
							to_value[key] = val
						end
					end
				else
					to:SetProperty(prop_id, value)
				end
			end
		
		::continue::
	end
end

--- Initializes a mercenary unit.
---
--- This function sets up the initial state of a mercenary unit, including:
--- - Assigning the default unarmed weapon
--- - Setting the unit's stance and fallback body based on its species and gender
--- - Synchronizing the unit with its session data
--- - Initializing the unit's weapons and actions
--- - Triggering the OnGearChanged event
--- - Marking the unit as modified
---
--- @param self Unit The unit object being initialized.
function Unit:InitMerc()
	g_UnarmedWeapon = g_UnarmedWeapon or PlaceInventoryItem("Unarmed")
	local unitData = gv_UnitData[self.session_id]
	
	if unitData.species ~= "Human" then
		self.stance = ""
	end
	self.fallback_body = unitData.gender or self.fallback_body

	self:SyncWithSession("session")

	self:InitMercWeaponsAndActions()
	self:OnGearChanged()

	ObjModified(self)
end

--- Initializes the weapons and actions for a mercenary unit.
---
--- This function performs the following tasks:
--- - Reloads all equipped weapons for the unit
--- - Recalculates the UI actions for the unit
--- - Sets the unit's command to "Idle"
---
--- @param self Unit The unit object being initialized.
function Unit:InitMercWeaponsAndActions()
	self:ReloadAllEquipedWeapons()
	self:RecalcUIActions()
self:SetCommand("Idle")
end

--- Gets the side of the unit.
---
--- This function determines the side of the unit based on the following criteria:
--- - If the unit is part of a team, the team's side is returned.
--- - If the unit is not part of a team, the side is determined from the unit's campaign data.
--- - If the unit has a spawner, the spawner's side is used.
--- - If no side can be determined, the unit is considered "neutral".
---
--- @param self Unit The unit object.
--- @param reset_teams boolean (optional) If true, the team information is ignored and the side is determined solely from the campaign data.
--- @return string The side of the unit.
function Unit:GetSide(reset_teams)
	local side = not reset_teams and self.team and self.team.side or false
	
	-- If the unit is not a part of any team, decide his team based on his campaign side.
	assert(self.session_id) -- all units should be represented in gv_UnitData
	local unit_data = self.session_id and gv_UnitData[self.session_id]

	if unit_data then 
		if unit_data.Squad and gv_Squads[unit_data.Squad] then
			side = side or gv_Squads[unit_data.Squad].Side
		elseif unit_data.CurrentSide ~= "" then 
			-- The unit could've changed sides
			side = side or unit_data.CurrentSide
		end
	end
		
	if not side and self.spawner then
		side = self.spawner.Side
	end

	-- Ephemeral units
	side = side or "neutral"
	
	return side
end

---
--- Fills the unit with the necessary data and sets its initial state.
---
--- This function performs the following tasks:
--- - Cleans up the unit's status effects
--- - Synchronizes the unit's properties with the session data
--- - Updates the unit's outfit and gear
--- - Resets the unit's combat path
--- - Updates the unit's status effect index and signature recharges
--- - Sets the unit's command based on its behavior (EnterMap, Hang, Visit, or Idle)
--- - Marks the unit as modified
---
--- @param self Unit The unit object being filled.
function Unit:FillMerc()
	local ud = gv_UnitData[self.session_id]
	if ud then ud:StatusEffectsCleanUp() end
	self:SyncWithSession("session")
	
	self:UpdateOutfit()
	self:OnGearChanged("isLoad")
	CombatPathReset(self)
	self:UpdateStatusEffectIndex()
	self:UpdateSignatureRecharges()
	
	if self.enter_map_wait_time then
		self.zone:InitUnit(self)
		self:SetCommand("EnterMap", self.zone, self.enter_map_pos, self.enter_map_wait_time)
	elseif self.behavior == "Hang" then
		self:SetCommand("Hang")
	elseif self.behavior == "Visit" then
		local marker = self.behavior_params[1] and self.behavior_params[1][1]
		if marker then
			local new_visitable = marker:GetVisitable()
			new_visitable.reserved = self.handle
			self.behavior_params[1] = new_visitable
			if marker.tool_attached then
				-- Tool is not a permanent object so it needs to be respawned
				if IsKindOf(marker, "AL_Carry") then
					self:SetState(marker.VisitIdle)
				end
				marker:SpawnTool(self)
			end
			if not (marker and marker:CanVisit(self, "for perpetual")) then
				self:ResetAmbientLife()
			elseif self.visit_reached then	-- walking to the marker can fail do to PF issues
				self:SetCommand("Visit", new_visitable, self.perpetual_marker)
			elseif IsKindOf(marker, "AL_Carry") then
				self:SetCommand("Visit", new_visitable, marker, "already in perpetual")
			else
				self:SetBehavior()
				self:SetCommand("Idle")
			end
		else
			-- persisted marker is deleted from the map
			self:SetBehavior()
			self:SetCommand("Idle")
		end
	else
		assert(self:IsValidPos())
		if self:IsValidPos() then
			self:SetCommand("Idle")
		end
	end
	ObjModified(self)
end

---
--- Synchronizes the properties of a unit with the session data.
---
--- @param source string The source of the synchronization, either "map" or "session".
---
function Unit:SyncWithSession(source) -- sync map objects with session data
	if not self.session_id then -- early out for setpiece testing, done with Unit clones with no session_id
		return
	end
	local unit_data = self.session_id and gv_UnitData[self.session_id]
	if not unit_data then
		assert(false, string.format("All units should have corresponding unit data: session_id (%s), template name (%s)", self.session_id or "", self.unitdatadef_id or ""))
		return
	end
	
	local from, to
	if source == "map" then
		from = self
		to = unit_data
	elseif source == "session" then
		from = unit_data
		to = self
	end
	 -- we need to remove reaction handlers and then apply them anew, as this can potentially change the list of status effect in the target object
	to:UnregisterReactions()
	CopyPropertiesShallow(to, from, UnitProperties:GetProperties())
	CopyPropertiesShallow(to, from, UnitInventory:GetProperties())
	 
	 -- StatusEffects table reference shouldn't be changed as it is observed by various UI at any given point.	 
	CopyPropertiesShallow(to, from, StatusEffectObject:GetProperties(), "copy_values")
	to:RegisterReactions()
	
	to:ApplyModifiersList(self.applied_modifiers)
	if source == "session" then
		to:OnSetActiveWeapon()
		to.AIKeywords = table.copy(to.AIKeywords)
	end	
	if (not g_Combat and self.behavior == "Dead") or (g_Combat and self.combat_behavior == "Dead") then
		self.HitPoints = 0
	end
	
	ObjModified(from)
	ObjModified(to)
	ObjModified(to.StatusEffects)
	ObjModified(from.StatusEffects)
end

---
--- Synchronizes the unit properties with the session data.
---
--- @param source string The source of the synchronization, either "map" or "session".
---
function NetSyncEvents.SyncUnitProperties(source)
	SyncUnitProperties(source)
end

---
--- Synchronizes the unit properties with the session data.
---
--- @param source string The source of the synchronization, either "map" or "session".
---
function SyncUnitProperties(source)
	if not GameState.entered_sector then return end
	
	for _, unit in ipairs(g_Units) do
		unit:SyncWithSession(source)
	end
	Msg("UnitPropertiesSynced")
end

function OnMsg.LoadSessionData()
	SyncUnitProperties("session")
	-- apply modifiers on load for units that are not on current map and have no g_Unit 
	--(syncwith session apply the modifiers for g_Units)
	for session_id, unit in pairs(gv_UnitData) do
		if not g_Units[session_id] then
			unit:ApplyModifiersList(unit.applied_modifiers)
			if unit.HireStatus and unit.HireStatus == "Hired" then
				unit:RegisterReactions()
			end
		end	
	end	
end

function OnMsg.GatherSessionData()
	if not gv_SatelliteView then -- in satellite view units session data is updated
		SyncUnitProperties("map")
	end
end

local function restore_default_props(unit, data, properties)
	for id, prop in ipairs(properties) do
		local id = prop.id
		local editor = prop_eval(prop.editor, unit, prop)
		if editor and not prop_eval(prop.dont_save, unit, prop) then
			local value, default = unit:GetProperty(id), data:GetProperty(id)
			if value ~= default and (type(value) == "function" or type(value) == "table" and data:IsDefaultPropertyValue(id, prop, value)) then
				unit:SetProperty(id, default)
			end
		end
	end
end

-- On Lua reload, put the defaults from UnitData classes back into Unit instances
-- (important for function values, so they don't get saved)
function OnMsg.Autorun()
	for _, unit in ipairs(g_Units) do
		local unit_data = unit.session_id and gv_UnitData[unit.session_id]
		if unit_data then
			restore_default_props(unit, unit_data, UnitProperties:GetProperties())
		end
	end
end

--- Returns the squad that the unit belongs to.
---
--- If the unit is dead, the squad is retrieved from the unit's `Squad` field.
--- Otherwise, the squad is retrieved from the `unitData.Squad` field.
---
--- @param self Unit
--- @return Squad|false The squad that the unit belongs to, or `false` if the unit does not belong to a squad.
function Unit:GetSatelliteSquad()
	local squad
	if self:IsDead() then
		squad = self.Squad
	else
		local unitData = gv_UnitData[self.session_id]
		squad = unitData and unitData.Squad
	end
	return gv_Squads and gv_Squads[squad] or false
end

--- Initializes the unit's game state.
---
--- This function is called when the unit is first created or loaded into the game.
--- It sets up various game-related properties and behaviors for the unit, such as:
---
--- - Enabling god mode or infinite AP if the corresponding cheats are enabled
--- - Setting the unit's HP to 1 if the "OneHpEnemies" cheat is enabled and the unit is an enemy
--- - Entering an emplacement if the unit has the "ManningEmplacement" status effect
--- - Updating the unit's bandage consistency
--- - Setting the unit's contour outer occlude recursive property
--- - Updating the unit's ground orientation parameters
--- - Setting the unit's target dummy from its position if the unit is not dead
---
--- @param self Unit The unit object.
function Unit:GameInit()
	local side = self.team and self.team.side	
	if CheatEnabled("GodMode", side) then
		self:GodMode("god_mode", true)
	end
	if CheatEnabled("InfiniteAP", side) then
		self:GodMode("infinite_ap", true)
	end
	if CheatEnabled("OneHpEnemies") and (side == "enemy1" or side == "enemy2") then
		self.HitPoints = 1
	end
	if self:HasStatusEffect("ManningEmplacement") then
		local handle = self:GetEffectValue("hmg_emplacement")
		local obj = HandleToObject[handle]
		if obj then
			self:EnterEmplacement(obj, true) -- instant take the right position
		end
	end
	self:UpdateBandageConsistency()
	
	self:SetContourOuterOccludeRecursive(true)
	self:UpdateGroundOrientParams()
	if not self:IsDead() then
		self:SetTargetDummyFromPos()
	end
end

--- Returns the synced animation state of the unit.
---
--- If the unit has a synced animation, this function returns the synced animation name and the time elapsed since the animation was synced.
--- Otherwise, it returns the current state text and animation phase of the unit.
---
--- @return string animName The name of the synced animation, or the current state text.
--- @return number animTime The time elapsed since the animation was synced, or the current animation phase.
function Unit:GetSyncedAnim()
	if self.synced_anim then
		return self.synced_anim, GameTime() - self.synced_anim_time
	end
	return self:GetStateText(), self:GetAnimPhase()
end

--- Returns the position of a specified spot on the unit's animation.
---
--- @param self Unit The unit object.
--- @param spot number|string The spot index or name to get the position for.
--- @return table The position of the specified spot in world coordinates.
function Unit:GetStaticSpotPos(spot)
	local obj = self.target_dummy or self
	if type(spot) == "string" then
		local first, last = obj:GetSpotRange(obj:GetAnim(), spot)
		if first < 0 or last < 0 then
			return obj:GetRelativePoint(0, 0, guim)
		end
		spot = first
	end
	return obj:GetSpotLocPos(obj:GetAnim(), obj:GetAnimPhase(), spot)
end

--- Queues a command to be executed by the unit.
---
--- @param self Unit The unit object.
--- @param cmd string The command to be executed.
--- @param ... any Additional arguments for the command.
function Unit:TriggerAction(cmd, ...)
	--[[if not g_Combat and cmd == "ChangeStance" then
		return self:InterruptCommand(cmd, ...)
	end--]]
	self:QueueCommand(cmd, ...)
end

--- Revives the unit and sets its health to the specified value.
---
--- If no health value is provided, the unit's maximum health is used.
--- This function also removes the "Bleeding" status effect, clears the unit's hierarchy game flags, and updates the unit's behavior and combat behavior if necessary.
--- It also invalidates diplomacy, flushes the combat cache, and marks the unit as modified.
---
--- @param self Unit The unit object.
--- @param hp number|nil The health value to set the unit to. If nil, the unit's maximum health is used.
function Unit:ReviveOnHealth(hp)
	self.HitPoints = hp or self.MaxHitPoints
	self:RemoveStatusEffect("Bleeding")
	self:NetUpdateHash("Revive", self.HitPoints)
	self:ClearHierarchyGameFlags(const.gofOnRoof)
	if self.behavior == "Dead" or self.behavior == "VillainDefeat" then
		self:SetBehavior()
		self:SetCombatBehavior()
	end
	InvalidateDiplomacy()
	self:FlushCombatCache()
	ObjModified(self)
end

--- Drops all items the unit is carrying into a container.
---
--- @param self Unit The unit object.
--- @param container table|nil The container to drop the items into. If nil, a new container will be created.
--- @return table The container the items were dropped into.
function Unit:DropLoot(container)
	local is_npc = self:IsNPC() -- not a merc
	
	local debugText =  _InternalTranslate(self.Name) .. " dropping loot: (roll must be lower)"
	
	-- Locked items never drop.
	-- Go over the equipped items, drop them to "Inventory" based on their drop chance,
	-- Equipped items from Mercs always drop(except locked items). Otherwise check the drop chance.
	local droped_items = 0
	self:ForEachItem(function(item, slot_name, left, top, self, container, is_npc)
		if slot_name == "InventoryDead" then return end
		self:RemoveItem(slot_name, item)	
		
		local dropped
		local roll = self:Random(100)
		local slot = container and "Inventory" or "InventoryDead"
		
		debugText = debugText .. "\n " ..  _InternalTranslate(item.DisplayName) .. ": roll " .. roll .. "/" .. item.drop_chance .. "% chance" 

		if not item.locked and (not is_npc or roll < item.drop_chance) then
			if IsGameRuleActive("AmmoScarcity") and is_npc and IsKindOf(item, "InventoryStack") and IsKindOfClasses(item,{"Ammo", "Ordnance", "Grenade", "ThrowableTrapItem", "Flare"}) then
				local percent = GameRuleDefs.AmmoScarcity:ResolveValue("LootDecrease")
				item.Amount =  Max(1,item.Amount - MulDivRound(item.Amount, percent, 100))
			end	
			
			local addTo = container or self
			
			local pos, err = addTo:CanAddItem(slot, item)
			assert(pos, "Couldn't FIND pos in Inventory to place dropped item. Err: '" .. err .. "'")
			if pos then
				dropped, err = addTo:AddItem(slot, item, point_unpack(pos))
				assert(dropped, "Couldn't PLACE dropped item in Inventory. Err: '" .. err .. "'")
			end			
		end
		
		if not dropped then
			DoneObject(item)
		elseif slot == "InventoryDead" then
			droped_items = droped_items + (item:IsLargeItem() and 2 or 1)
		end
	end, self, container, is_npc)

	if droped_items > 0 then
		self.max_dead_slot_tiles = droped_items
	end

	CombatLog("debug", debugText)
end

---
--- Called when a unit dies on a sector.
---
--- @param unit Unit The unit that died.
--- @param sector_id number The ID of the sector where the unit died.
---
function OnMsg.UnitDiedOnSector(unit, sector_id)
	local sector = gv_Sectors[sector_id]
	sector.dead_units = sector.dead_units or {}
	table.insert(sector.dead_units, unit.session_id)  
end

---
--- Drops all items in the unit's inventory into a container at the specified position.
---
--- @param fall_pos table The position where the items should be dropped.
--- @return table The container where the items were dropped.
---
function Unit:DropAllItemsInAContainer(fall_pos)
	if not self:GetItem() then return end
	local container = GetDropContainer(self,fall_pos)
	self:ForEachItem(function(item, slot)
		self:RemoveItem(slot, item)
		
		if not container:AddItem("Inventory", item) then
			-- Fallback for too many items
			container = PlaceObject("ItemDropContainer")
			local drop_pos = terrain.FindPassable(container, 0, const.SlabSizeX/2)
			container:SetPos(drop_pos or self:GetPos())
			container:SetAngle(container:Random(360*60))
			container:AddItem("Inventory", item)
		end
	end)
		
	return container
end

---
--- Determines whether a unit should get downed when taking damage.
---
--- @param hit_descr table The hit description containing information about the damage taken.
--- @return boolean Whether the unit should get downed.
---
function Unit:ShouldGetDowned(hit_descr)
	if not self:IsMerc() or not self.team or not self.team.player_team or (hit_descr and hit_descr.was_downed) then 
		return false 
	end
	if self.team and self.team:IsDefeated() then
		return false
	end
	if IsGameRuleActive("LethalWeapons") then
		return false
	end
	if IsGameRuleActive("ForgivingMode") then
		return true
	end
	if hit_descr then
		local value = GameDifficulties[Game.game_difficulty]:ResolveValue("InstantDeathHp") or -50
		if hit_descr.prev_hit_points - hit_descr.raw_damage <= value then
			return false
		end
	end
	if g_Combat then
		return not self:IsDowned()
	end
	return hit_descr and hit_descr.prev_hit_points > 1
end

---
--- Handles the death of a unit, including determining if the unit should get downed instead of dying.
---
--- @param attacker Unit|Trap The attacker that caused the unit's death.
--- @param hit_descr table The hit description containing information about the damage that caused the death.
---
function Unit:OnDie(attacker, hit_descr)
	CombatActionInterruped(self)
	RemoveFloatingTextsFrom(self, "DamageFloatingText")
	self.on_die_attacker = IsKindOf(attacker, "Trap") and attacker.attacker or attacker
	self.on_die_hit_descr = table.copy(hit_descr)
	self.on_die_hit_descr.armor_decay = nil
	self.on_die_hit_descr.armor_pen = nil
	
	if self:ShouldGetDowned(hit_descr) then
		hit_descr.explosion_fly = nil -- never do this when downing
		self.HitPoints = 1 -- make sure the unit is not considered dead and evicted from the UI
		local value = GameDifficulties[Game.game_difficulty]:ResolveValue("DownedTempHp") or 30
		if g_Combat then self:ApplyTempHitPoints(value) end
		--count downed units for tacticalsituation vr
		if attacker and IsKindOf(attacker, "Unit") and attacker.team.side ~= self.team.side then
			self.team.tactical_situations_vr.downedUnits = self.team.tactical_situations_vr.downedUnits and self.team.tactical_situations_vr.downedUnits 
			attacker.team.tactical_situations_vr.downedUnitsByTeam = attacker.team.tactical_situations_vr.downedUnitsByTeam and attacker.team.tactical_situations_vr.downedUnitsByTeam + 1 or 1
			PlayVoiceResponseTacticalSituation(table.find(g_Teams, attacker.team), "now")
		end
		self:SetCommand("GetDowned")
	else
		--printf("%s dies", _InternalTranslate(self.Name or ""))
		self.on_die_hit_descr = self.on_die_hit_descr or {}
		 -- Roam is considered visiting but doesn't have a last_visit
		 if self:IsVisiting() and self.last_visit and self.visit_reached then
			self.on_die_hit_descr.die_pos = self.last_visit:GetPos()
		end
		if string.match(self.session_id, "ClonedFootballPartner") then
			self.SetCommand = Unit.SetCommand
			self.zone.player_killed = true
		end
		if IsKindOf(self.last_visit, "AL_Football") then
			self.last_visit.player_killed = true
		end
		self:SetCommand("Die")
	end
end

---
--- Sets the unit's tired state and potentially downs the unit if the tired state is 3.
---
--- @param value number The new tired state value, where 3 indicates the unit is exhausted.
---
function Unit:SetTired(value)
	UnitProperties.SetTired(self, value)
	
	if value==3 then
		self:SetCommand("GetDowned", "tired")	
	end
end

---
--- Checks if the unit is currently in the process of getting downed.
---
--- @return boolean true if the unit is getting downed, false otherwise
---
function Unit:IsGettingDowned()
	return self.command == "GetDowned"
end

---
--- Checks if the unit is currently in the downed state.
---
--- @return boolean true if the unit is downed, false otherwise
---
function Unit:IsDowned()
	return self.command == "Downed" or self.combat_behavior == "Downed"
end

---
--- Checks if the unit is incapacitated, which includes being dead, downed, getting downed, or in the "Die" command state.
---
--- @return boolean true if the unit is incapacitated, false otherwise
---
function Unit:IsIncapacitated()
	return self:IsDead() or self:IsDowned() or self:IsGettingDowned() or self.command == "Die"
end

---
--- Checks if the unit can pass through an area in combat.
---
--- @return boolean true if the unit can pass through the area, false otherwise
---
function Unit:CanPassThroughInCombat()
	return self:GetEnumFlags(const.efResting) == 0 or self:IsDowned()
end

---
--- Checks if the unit can continue combat.
---
--- @return boolean true if the unit can continue combat, false otherwise
---
function Unit:CanContinueCombat()
	local isDead = self.command == "Die" or self:IsDead()
	local isDowned = self:IsDowned()
	local isTempUncontrollable = (self:HasStatusEffect("Unconscious") or self:HasStatusEffect("Stabilized")) and (not self:HasStatusEffect("Downed") or not self:HasStatusEffect("BleedingOut"))
	return not isDead and (not isDowned or isTempUncontrollable)
end

MapVar("g_NextUnitThread", false)
MapVar("g_LastUnitToShoot", false)

---
--- Gets the unit downed. This function handles the logic for downing a unit, including:
--- - Restoring the unit's hit points to 1 if not already downed
--- - Setting the unit's action points to 0
--- - Setting the unit's stance to prone
--- - Interrupting any prepared attacks
--- - Removing various status effects
--- - Adding wounds to the unit
--- - Clearing the unit's path
--- - Setting the unit's target dummy
--- - Playing a voice response if the unit is not already downed
--- - Handling special logic for mercenary units
--- - Checking for game over conditions
--- - Setting the unit's combat behavior to "GetDowned"
--- - Handling the unit's animation and positioning when downed
--- - Adding the "Downed" or "Unconscious" status effect to the unit
---
--- @param tired boolean Whether the unit is tired when downed
--- @param skip_anim boolean Whether to skip the downed animation
--- @return void
---
function Unit:GetDowned(tired, skip_anim)
	if not tired then
		self.HitPoints = 1 -- restore hp so Downed can be applied
		--printf("%s is downed", _InternalTranslate(self.Name or ""))
	end
	self.ActionPoints = 0
	self.stance = self:GetValidStance("Prone")
	self:InterruptPreparedAttack()
	self:RemovePreparedAttackVisuals()
	self:RemoveEnemyPindown()
	self:AlignOnDeath()
	self:RemoveStatusEffect("FreeMove")
	self:RemoveStatusEffect("Bleeding")
	self:RemoveStatusEffect("BandageInCombat")
	self:RemoveStatusEffect("StationedMachineGun")
	self:AddWounds(1)
	
	CombatActionInterruped(self)
	ObjModified(self)
	self:ClearPath()
	self:SetTargetDummyFromPos()
	if not tired then
		PlayVoiceResponse(self, "Downed")
	end
	SetCombatActionState(self, nil)

	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") and Selection and table.find(Selection, self) then
		dlg:NextUnit()
	end

	if IsMerc(self) then
		PlayFX("MercDowned", "start")
	end

	self.combat_behavior = "GetDowned"
	CheckGameOver()
	local base_idle = self:TryGetActionAnim("Idle", "Downed")
	if not (base_idle and IsAnimVariant(self:GetStateText(), base_idle)) then
		local pos = self:GetPos()
		if ShouldDoDestructionPass() then
			WaitMsg("DestructionPassDone", 1000) --wait for destro if slabs beneath us get destroyed, so we can get a falldown point
		end
		local x, y, z = FindFallDownPos(pos)
		if x and not pos:Equal(x, y, z) then
			self:FallDown(point(x, y, z))
			pos = self:GetPos()
		end
		local angle = self:GetOrientationAngle()
		self:SetPos(pos)
		if not skip_anim then
			local base_anim = self:GetActionBaseAnim("Downed", self.stance)
			local anim = self:GetStateText()
			if IsAnimVariant(anim, base_anim) then
				Sleep(self:TimeToAnimEnd())
			else
				anim = self:GetNearbyUniqueRandomAnim(base_anim)
				self:MovePlayAnim(anim, pos, pos, 0, nil, true, angle)
			end
		end
		if base_idle then
			if not IsAnimVariant(self:GetStateText(), base_idle) then
				local anim = self:GetNearbyUniqueRandomAnim(base_idle)
				self:SetState(anim)
			end
		else
			-- missing downed idle animation support
			local base_anim = self:GetActionBaseAnim("Downed", self.stance)
			local anim = self:GetStateText()
			if not IsAnimVariant(anim, base_anim) then
				anim = self:GetNearbyUniqueRandomAnim(base_anim)
			end
			local duration = GetAnimDuration(self:GetEntity(), anim)
			self:SetState(anim, 0, 0)
			self:SetAnimPhase(1, duration - 1)
		end
		self:SetGroundOrientation(angle, 0)
	end
	self.combat_behavior = false

	if not g_Combat and not self:IsDead() then
		Sleep(5000)
		self:SetCommand("DownedRally")
		return
	end
	if g_Combat and self == SelectedObj and not IsValidThread(g_NextUnitThread) then
		g_NextUnitThread = CreateMapRealTimeThread(function()
			-- Somebody could be panicking, during which units cannot be controlled.
			while g_AIExecutionController do
				WaitMsg("ExecutionControllerDeactivate", 50)
			end
			-- If the last unit is killed combat will be ended.
			if g_Combat then g_Combat:NextUnit(nil, "force") end
		end)
	end
	self.return_pos = nil

	if tired then
		self:AddStatusEffect("Unconscious")
	else
		MoraleModifierEvent("UnitDowned", self)
		self:AddStatusEffect("Downed")
	end
end

---
--- Handles the behavior of a unit when it is downed.
--- This function is responsible for setting the appropriate animation state, combat behavior, and target dummy for a downed unit.
---
--- @param self Unit The unit object.
---
function Unit:Downed()
	Msg("UnitDowned", self)
	local base_idle = self:TryGetActionAnim("Idle", "Downed")
	if base_idle then
		if not IsAnimVariant(self:GetStateText(), base_idle) then
			local anim = self:GetNearbyUniqueRandomAnim(base_idle)
			self:SetState(anim)
			if GameState.sync_loading then
				self:SetAnimPhase(1, GetAnimDuration(self:GetEntity(), anim) - 1)
			end
		end
	else
		-- missing downed idle animation support
		local base_anim = self:GetActionBaseAnim("Downed", self.stance)
		local anim = self:GetStateText()
		if not IsAnimVariant(anim, base_anim) then
			anim = self:GetNearbyUniqueRandomAnim(base_anim)
		end
		local duration = GetAnimDuration(self:GetEntity(), anim)
		self:SetState(anim, 0, 0)
		self:SetAnimPhase(1, duration - 1)
	end
	self:SetFootPlant(true, 0)
	self:SetCombatBehavior("Downed")
	local target_dummy_phase = GetAnimDuration(self:GetEntity(), self:GetState())
	self:SetTargetDummy(nil, nil, nil, target_dummy_phase) -- current position, animation phase 0
	Halt()
end

local HeadshotHideParts = { "Head", "Hat", "Hat2", "Hair" }

---
--- Sets the headshot state of the unit and updates the visibility of the head-related parts accordingly.
---
--- @param value boolean Whether the unit is in a headshot state or not.
---
function Unit:SetHeadshot(value)
	self.Headshot = value
	if not self.parts or self.species ~= "Human" then
		return
	end
	for i, name in ipairs(HeadshotHideParts) do
		local part = self.parts[name]
		if part then
			if value then
				part:ClearEnumFlags(const.efVisible)
			else
				part:SetEnumFlags(const.efVisible)
			end
		end
	end
	if value then
		local headshot_entity
		if self.gender == "Male" then
			headshot_entity = "FX_HeadMale_Headshot"
		elseif self.gender == "Female" then
			headshot_entity = "FX_HeadFemale_Headshot"
		end
		if headshot_entity then
			local part = PlaceObject("AppearanceObjectPart")
			if self:GetGameFlags(const.gofRealTimeAnim) ~= 0 then
				part:SetGameFlags(const.gofRealTimeAnim)
			end
			part:ChangeEntity(headshot_entity)
			self:Attach(part, self.parts.Head:GetAttachSpot())
			self.parts.Headshot = part
		end
	else
		DoneObject(self.parts.Headshot)
		self.parts.Headshot = nil
	end
end

---
--- Aligns the unit's position on death, snapping to the nearest voxel position if necessary.
---
--- @param dont_snap boolean If true, the unit's position will not be snapped to the nearest voxel.
---
function Unit:AlignOnDeath(dont_snap)
	local pos = self:GetVoxelSnapPos()
	if pos and self:GetDist(pos) > 0 and (not (self.on_die_hit_descr and self.on_die_hit_descr.die_pos)) then
		if not dont_snap then
			self:SetPos(pos)
		end
		-- make sure the unit dies on place in this case
		self.on_die_attacker = nil
		self.on_die_hit_descr = nil
	end
end

---
--- Handles the death of a unit, including playing death animations, handling special cases like reincarnation or immortality, and triggering various events and effects.
---
--- @param skip_anim boolean If true, the death animation will be skipped.
---
function Unit:Die(skip_anim)
	local attacker = self.on_die_attacker
	local hit_descr = self.on_die_hit_descr or {}
	local target_spot_group = hit_descr.spot_group
	local headshot = target_spot_group == "Head"
	local attack_action_id = attacker and CombatActions_LastStartedAction and CombatActions_LastStartedAction.unit == attacker and CombatActions_LastStartedAction.action_id
	local zoom_in = (self:IsLocalPlayerControlled() or headshot or attack_action_id == "KnifeThrow") and attacker and CurrentActionCamera and CurrentActionCamera[1] ~= self and CurrentActionCamera[2] == self and not self.villain
	local results = {}

	self:AlignOnDeath("don't snap in voxel")
	self:RoamDropFlare()

	if not skip_anim then
		if zoom_in then
			ZoomActionCamera()
		end

		-- Action camera should wait for this to be over before closing.
		if CurrentActionCamera then
			CurrentActionCamera.wait_signal = true
		end
	end
	
	if self.reincarnate then
		self:PlayDying()
		self:ReviveOnHealth()
		self:SetBehavior()
		self:SetCombatBehavior()
		self:SetCommand("Idle")
		return
	elseif self.immortal then
		self:ReviveOnHealth()
		self:AddStatusEffect("Unconscious")
		return
	end
	
	self.throw_died_message = "all"
	self.HitPoints = 0 -- needs to be before RemoveAllStatusEffects so that Wounded can detect the death and leave any blood stains on
	self:RemoveAllStatusEffects("death")
	if self.villain then
		local attackerMerc = attacker and IsMerc(attacker)
		
		if self.DefeatBehavior == "Defeated" then
			self:SetBehavior("VillainDefeat")
			self:SetCombatBehavior("VillainDefeat")
			self.villain_defeated = true
			self:SetCommand("VillainDefeat")
		elseif self.DefeatBehavior == "Dead" then
			if attackerMerc and SideIsEnemy(self.team.side, attacker.team.side) then
				PlayVoiceResponse(self, "DramaticDeath")
			end
			Msg("VillainDefeated", self, attacker)
			self.villain_defeated = true
		end
	end
	self.HitPoints = 0 -- in case statuses do some shenanigans I guess
	self.time_of_death = Game.CampaignTime
	self.pending_aware_state = nil
	self.killed_stance = self.stance

	Msg("UnitDieStart", self, attacker)
	Msg("UnitDiedOnSector", self, gv_CurrentSectorId)
	self.throw_died_message = "pre-sync"
	
	self:InterruptPreparedAttack()
	self:EndInterruptableMovement()
	CombatActionInterruped(self)
	for _, unit in ipairs(g_Units) do
		if unit:GetBandageTarget() == self then
			unit:SetCommand("EndCombatBandage")
		end
	end	
	local stealth_kill = hit_descr.stealth_kill
	if not attacker then
		CombatLog("debug", T{Untranslated("  <em><name></em> was <em>killed</em>"), name = self:GetLogName()})
	end

	results.glory_kill = not self.immortal and not hit_descr.grazing and self:Random(100) < const.Combat.GloryKillChance
	
	local death_explosion = hit_descr.death_explosion
	if self:GetItemInSlot("Inventory", "Valuables") or self:GetItemInSlot("Inventory", "QuestItem") then
		death_explosion = false
		hit_descr.death_explosion = false
	end

	if death_explosion then
		PlayFX("DeathExplosion", "start", self, target_spot_group)
	elseif results.glory_kill and IsKindOf(hit_descr.weapon, "Firearm") and not self.immortal and headshot and self.species == "Human" and self.parts.Head then
		self:SetHeadshot(true)
		PlayFX("Death", "start", self, "Headshot")
	else
		PlayFX("Death", "start", self, target_spot_group)
	end
	
	if IsMerc(self) then
		PlayFX("MercDeath", "start", self)
	end

	self:SetPos(self:GetVisualPos())
	self:SetHierarchyGameFlags(const.gofOnRoof) --hide with roofs and walls if too close to one
	self:ClearPath()
	self:ClearEnumFlags(const.efResting)
	self:SetTargetDummy(false)
	SetCombatActionState(self, nil)
	-- Remember the anim prefix when the unit died as it will drop its items
	self.die_anim_prefix = self:GetWeaponAnimPrefix()

	local container
	if not self.immortal then
		if death_explosion then
			container = GetDropContainer(self)
			container:SetVisible(false)
		end
		self:DropLoot(container)
		if container and not container:HasItem() then
			DoneObject(container)
			container = false
		end
	end
	self:SyncWithSession("map")
	self.throw_died_message = "after-start"

	if self.villain and self.DefeatBehavior == "Dead" then
		MoraleModifierEvent("LieutenantDefeated", self)
	else
		MoraleModifierEvent("UnitDied", self)
		if attacker and self.team.side ~= "neutral" and self.team.side ~= "player1" and self.team.side ~= "player2" and results.glory_kill then
			MoraleModifierEvent("SpectacularKill", attacker)
		end
	end

	-- alerts: noise (non-stealth only) and killed (always)
	local alerted, suspicious = PushUnitAlert("death", self)
	if not stealth_kill then
		local noise_alerted, noise_suspicious = PushUnitAlert("noise", self, const.Combat.DeathNoiseRange, Presets.NoiseTypes.Default.Pain.display_name)
		alerted, suspicious = alerted + noise_alerted, suspicious + noise_suspicious
	end
	if g_Combat and IsKindOf(attacker, "Unit") and not g_Combat:ShouldEndCombat() then
		if stealth_kill and alerted == 0 then
			PlayVoiceResponse(attacker, "OpponentKilledStealth")
		end
	end

	-- skip end combat check if the death made someone suspicious or alert
	-- note: a stealth kill attack wouldn't alert/raise suspicion in other units except through the "death" trigger
	local end_combat_check = g_Combat and suspicious + alerted == 0 and not g_AIExecutionController

	self:PushDestructor(function(self)
		self:RemovePreparedAttackVisuals()
		Msg("ActionCameraWaitSignalEnd")
		if container then
			container:SetVisible(true)
		end
	end)
	self:PushDestructor(function(self)
		assert(not self.command and not self:IsValid(), "Die command should not be interrupted (new command: " .. tostring(self.command) .. ").")
	end)
	-- wait a bit for possible destruction around or below the unit (bullets and explosions might destroy stuff after the unit)
	if not skip_anim then
		Sleep(100)
		self:StopPain()
	end
	self:PlayDying(skip_anim, end_combat_check)
	self:PopDestructor()
	self:PopAndCallDestructor()

	ObjModified(self)
	Msg("UnitDied", self, attacker, results)
	self.throw_died_message = false
	
	if IsValid(self) then
		self:BeginInterruptableMovement()
		self:SetCommand("Dead")
	end
end

local FX_Explosion_Variants = {
	"FX_Explosion_Human_01",
	"FX_Explosion_Human_02",
	"FX_Explosion_Human_03",
}

--- Places a death FX object at the specified position and orientation.
---
--- @param quick_play boolean Whether to quickly play the death FX animation.
--- @param pos table|nil The position to place the FX object. If nil, the unit's position is used.
--- @param angle number|nil The orientation angle for the FX object. If nil, the unit's orientation is used.
function Unit:PlaceDeathFXObject(quick_play, pos, angle)
	local x, y, z = FindFallDownPos(pos or self)
	if not x then
		if pos then
			x, y, z = pos:xyz()
		else
			x, y, z = self:GetPosXYZ()
		end
	end
	angle = angle or self:GetOrientationAngle()
	self:SetOpacity(0)
	local o = self.death_fx_object
	if not IsValid(o) then
		if not FX_Explosion_Variants[self.death_explosion_played] then
			self.death_explosion_played = 1 + self:Random(#FX_Explosion_Variants)
		end
		o = PlaceObject(FX_Explosion_Variants[self.death_explosion_played])
		o:SetStateText("idle")
		self.death_fx_object = o
	end
	if quick_play then
		o:SetAnimPhase(1, GetAnimDuration(o:GetEntity(), o:GetAnim(1)) - 1)
	end
	local orient_time = (quick_play or not o:IsValidPos()) and 0 or 500
	o:SetPos(x, y, z or const.InvalidZ, orient_time) -- fall down when destruction
	o:SetGroundOrientation(angle, orient_time, const.SlabSizeX * 40 / 100) -- one tile inclination
end

--- Plays the dying animation for a unit.
---
--- @param quick_play boolean Whether to quickly play the death animation.
--- @param end_combat_check boolean Whether to end the combat check after the death animation.
--- @param anim string The animation to play for the death.
--- @param pos table|nil The position to play the death animation at. If nil, the unit's position is used.
--- @param angle number|nil The orientation angle for the death animation. If nil, the unit's orientation is used.
--- @param break_obj Object|nil An object to break when the unit dies.
function Unit:PlayDying(quick_play, end_combat_check, anim, pos, angle, break_obj)
	local in_dead_anim
	local hit_descr = self.on_die_hit_descr
	local death_explosion = hit_descr and hit_descr.death_explosion or self.species == "Hen"
	local falldown_callback = hit_descr and hit_descr.falldown_callback and _G[hit_descr.falldown_callback]
	if death_explosion or string.match(self:GetStateText(), "Death") then
		in_dead_anim = true
		anim = self:GetStateText()
	end
	if not in_dead_anim and ShouldDoDestructionPass() then
		WaitMsg("DestructionPassDone", 1000)
	end
	if (not anim or not self:HasAnim(anim)) and not death_explosion then
		anim, pos, angle, break_obj = GetRandomDeathAnim(self, { attacker = self.on_die_attacker, hit_descr = hit_descr } )
	end
	local x, y, z = FindFallDownPos(pos or self)
	if not pos or x and not pos:Equal(x, y, z) then
		pos = x and point(x, y, z) or self:GetPos()
	end
	angle = angle or self:GetOrientationAngle()
	local orient_time = quick_play and 0 or 500
	self:DestroyAttaches("WeaponVisual")

	local behavior_params = { anim, angle }
	self:SetBehavior("Dead", behavior_params)
	self:SetCombatBehavior("Dead", behavior_params)

	if death_explosion then
		if self.death_explosion_played then
			quick_play = true
		end
		if not quick_play then
			Sleep(const.Combat.DeathExplosion_AnimationDelay)
		end
		self:SetBehavior("Despawn", behavior_params)
		self:SetCombatBehavior("Despawn", behavior_params)
		if self.species == "Hen" then
			local dlg = GetInGameInterfaceModeDlg()
			if IsKindOf(dlg, "IModeCombatAttackBase") and dlg:GetAttackTarget() == self then
				if g_Combat or g_StartingCombat then
					SetInGameInterfaceMode("IModeCombatMovement")
				else
					SetInGameInterfaceMode("IModeExploration")
				end
			end
			self:QueueCommand("Despawn")
			return
		end
		if IsValid(self.death_fx_object) then
			self:PlaceDeathFXObject(true, pos, angle)
			return
		end
		self:PlaceDeathFXObject(quick_play, pos, angle)
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		if not quick_play and IsValid(self.death_fx_object) then
			Sleep(self.death_fx_object:TimeToAnimEnd())
		end
		return
	end

	if in_dead_anim then
		-- unconscious
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		if quick_play then
			self:SetAnimPhase(1, GetAnimDuration(self:GetEntity(), anim) - 1)
		else
			Sleep(self:TimeToAnimEnd())
		end
		return
	end

	if quick_play then
		self:SetState(anim, 0, 0)
		local duration = GetAnimDuration(self:GetEntity(), anim)
		self:SetAnimPhase(1, duration - 1)
		self:SetPos(pos)
		self:SetFootPlant(true, 0)
		self:SetOrientationAngle(angle)
		if falldown_callback then
			falldown_callback(self.on_die_attacker, self, pos)
		end
		if IsValid(break_obj) and break_obj.pass_through_state == "intact" then
			break_obj:SetWindowState("broken")
		end
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		return
	end
	local thread1, thread2
	self:PushDestructor(function(self)
		DeleteThread(thread1)
		DeleteThread(thread2)
		if IsValid(self) then
			self:PlayDying(true, false, anim, pos, angle, break_obj)
		end
	end)
	if falldown_callback then
		local delay = self:GetAnimMoment(anim, "hit") or self:GetAnimMoment(anim, "end") or self:GetAnimDuration(anim) - 1
		thread1 = CreateGameTimeThread(function(self, delay, pos, end_combat_check)
			Sleep(delay)
			local hit_descr = self.on_die_hit_descr
			local falldown_callback = hit_descr.falldown_callback and _G[hit_descr.falldown_callback]
			if falldown_callback then
				falldown_callback(self.on_die_attacker, self, pos)
			end
			if end_combat_check and g_Combat then
				g_Combat:EndCombatCheck()
			end
		end, self, delay, pos, end_combat_check)
	end
	if break_obj then
		local delay = self:GetAnimMoment(anim, "explosion") or 0
		thread2 = CreateGameTimeThread(function(delay, obj, end_combat_check)
			Sleep(delay)
			if IsValid(obj) and obj.pass_through_state == "intact" then
				obj:SetWindowState("broken")
			end
			if end_combat_check and g_Combat then
				g_Combat:EndCombatCheck()
			end
		end, delay, break_obj, end_combat_check)
	else
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
	end
	self:MovePlayAnim(anim, self:GetPos(), pos, 0, nil, true, angle)
	self:PopDestructor()
end

Unit.IsDead = UnitProperties.IsDead

--- Checks if the unit is a defeated villain.
---
--- @return boolean true if the unit is a villain and has been defeated, false otherwise
function Unit:IsDefeatedVillain()
	return self.villain and self.villain_defeated
end

--- Removes any enemy pindown effects on this unit.
---
--- If there is an active combat, this function will interrupt any prepared attacks
--- that have this unit as the target.
function Unit:RemoveEnemyPindown()
	if g_Combat then
		for attacker, descr in pairs(g_Pindown) do
			if descr.target == self then
				attacker:InterruptPreparedAttack()
			end
		end
	end
end

DefineClass.DecFXBlood_01 = {__parents = {"Object"}}

--- Places a blood decal on the ground at the unit's position.
---
--- This function checks if the unit has passed the time after death defined by
--- `const.Satellite.RemoveBloodAfter`. If this time has passed, the function
--- will not place any blood.
---
--- The blood decal is placed at the unit's visual position, with a random
--- rotation angle. The decal's opacity is set to 0 initially, and then faded
--- in over 4000-6000 milliseconds.
function Unit:PlaceBlood()
	if self:HasPassedTimeAfterDeath(const.Satellite.RemoveBloodAfter) then
		--do not place blood if const.Satellite.RemoveBloodAfter has passed
		return
	end
	local blood_pos = self:GetSpotVisualPos(self:GetSpotBeginIndex("Blood"))
	blood_pos = blood_pos:SetZ(self:GetVisualPos():z())
	local blood = PlaceObject("DecFXBlood_01")
	blood:SetGameFlags(const.gofDecalOpacityAlphaTest)
	blood:SetPos(blood_pos)
	blood:SetAngle(self:Random(360 * 60))
	blood:SetOpacity(0)
	blood:SetOpacity(95, 4000 + self:Random(2000))
end

--- Handles the death of a unit.
---
--- This function is responsible for the various actions that occur when a unit dies, such as:
--- - Dropping the unit's loot
--- - Sending messages about the unit's death
--- - Removing the unit from the game world
--- - Playing the unit's dying animation
---
--- @param anim string (optional) The animation to play for the unit's death
--- @param angle number (optional) The angle at which to play the dying animation
function Unit:Dead(anim, angle)
	local behavior = g_Combat and self.combat_behavior or self.behavior
	if behavior == "Despawn" then
		return
	end
	
	-- Savegame fixup for 241898
	-- Errored/save-load during death before loot is dropped
	if self:CountItemsInSlot("Inventory") ~= 0 and self:CountItemsInSlot("InventoryDead") == 0 then
		self.throw_died_message = "pre-sync"
	end
	
	-- Savegame fixup for 238866
	-- Errored in RemoveStatusEffect BandageInCombat prior to moving throw_died_message above that call.
	if not self.time_of_death then
		self.throw_died_message = "all"
	end
	
	-- This can happen when a save is made while the unit was running the "Die" command.
	-- Upon load the unit will be dead (go straight here) without having thrown the message,
	-- which could mean that the conflict isn't resolved.
	if self.throw_died_message then
		if self.throw_died_message == true then -- legacy
			self.throw_died_message = "all"
		end
	
		local killer = self.on_die_attacker
		if self.throw_died_message == "all" then
			if self.villain then
				Msg("VillainDefeated", self, killer)
			end
			
			self.time_of_death = Game.CampaignTime
			Msg("UnitDieStart", self, killer)
			Msg("UnitDiedOnSector", self, gv_CurrentSectorId)
			self.throw_died_message = "pre-sync"
		end
		
		if self.throw_died_message == "pre-sync" then
			local container = GetDropContainer(self)
			if not self.immortal then
				self:DropLoot(container)
			end
			if container and not container:HasItem() then
				DoneObject(container)
				container = false
			end
			self:SyncWithSession("map")
			self.throw_died_message = "after-start"
		end

		Msg("UnitDied", self, killer, empty_table)
		self.throw_died_message = false
	end
	
	-- some Die command code is repeated here for the cases when the Die command was skipped (load a game)
	self:SetHierarchyGameFlags(const.gofOnRoof) --hide with roofs and walls if too close to one
	self:ClearPath()
	self:ClearEnumFlags(const.efResting)
	self:SetTargetDummy(false)
	SetCombatActionState(self, nil)
	self:RemoveEnemyPindown()
	if self.species == "Human" then
		self.stance = "Prone"
	end

	if not anim and self.behavior == "Dead" then
		anim, angle = table.unpack(self.behavior_params or empty_table)
	end
	self:PlayDying(true, false, anim, nil, angle)
	self:PlaceALDeadMarkers()

	Halt()
end

---
--- Handles the logic for when a unit is "hung" or suspended in the game world.
--- This function is responsible for setting the appropriate behavior and combat behavior,
--- attaching the unit to a hanging rope, and updating the unit's state and properties to
--- reflect the "hung" state.
---
--- @param self Unit The unit object that is being hung.
---
function Unit:Hang()
	SetCombatActionState(self, nil)
	self:SetBehavior("Hang")
	self:SetCombatBehavior("Hang")
	
	local ropes = MapGet("map", "World_HangingRope") or empty_table
	if #ropes ~= 1 then
		StoreErrorSource(point30, "There should be one rope on the map.")
		return
	end
	local rope = ropes[1]
	local hanging_spot_idx = rope:GetSpotBeginIndex("Hanging")
	if hanging_spot_idx == -1 then
		StoreErrorSource(rope, "Rope missing Hanging spot")
		return
	end
	rope.SetAutoAttachMode = empty_func
	self:ClearEnumFlags(const.efApplyToGrids)
	self:ClearEnumFlags(const.efCollision)
	--this unit is goind to be attached to a bone anim;
	--in order to not net check its saved position/axis/angle on enter sector which could be a little different per client
	--we clear the sync flag and switch its class to a class with gofSyncObject = false
	self:MakeNotSync()
	rope:Attach(self, hanging_spot_idx)
	self:SetState("nw_Hanging", 0, 0)
	self.HitPoints = 0
	self.immortal = false
	InvalidateDiplomacy()
	Msg("UnitDieStart", self)
	Halt()
end

DefineClass.NonSyncUnit = {
	__parents = { "Unit" },
	flags = { gofSyncObject = false },
}

---
--- Makes the unit not synchronized with other clients.
--- This function clears the sync object flag from the unit and changes its class to a non-sync class.
---
--- @param self Unit The unit object to make not synchronized.
---
function Unit:MakeNotSync()
	if not self:IsSyncObject() then return end
	self:ClearGameFlags(const.gofSyncObject)
	--self:SetHandle(self:GenerateHandle()) --its probably fine to leave the old handle in case someone is refering to this
	setmetatable(self, g_Classes.NonSyncUnit)
end

---
--- Checks if the unit is in a "Hang" state.
---
--- @param self Unit The unit object to check.
--- @return boolean True if the unit is in a "Hang" state, false otherwise.
---
function Unit:IsPersistentDead()
	return self.command == "Hang"
end

---
--- Handles the defeat of a villain unit.
---
--- When a villain unit is defeated, this function sets the unit's behavior and combat behavior to "VillainDefeat", makes the unit invulnerable and neutral, and performs other actions to indicate the unit's defeated state.
---
--- @param self Unit The unit object.
---
function Unit:VillainDefeat()
	if not self.villain or not self.villain_defeated then
		if self.behavior == "VillainDefeat" then
			self:SetBehavior()
		end
		if self.combat_behavior == "VillainDefeat" then
			self:SetCombatBehavior()
		end
		return
	end
	
	SetCombatActionState(self, nil)
	if SideIsEnemy(self.team.side, "player1") then
		PlayVoiceResponse(self, "VillainDefeated")
	end
	
	self:SetBehavior("VillainDefeat")
	self:SetCombatBehavior("VillainDefeat")
	
	self.invulnerable = true
	self.conflict_ignore = true -- prevent ambient life from messing around with this unit
	self.neutral_retaliate = false
	self.HitPoints = 1
	self:DoChangeStance("Crouch")
	self.ActionPoints = 0
	self.villain_defeated = true
	self:ClearPath()

	self:InterruptPreparedAttack()
	self:RemoveAllStatusEffects()
	
	local squad = gv_Squads[self.Squad]
	if squad then
		local newSquadId = SplitSquad(squad, {self.session_id})
		assert(self.Squad == newSquadId)
		SetSatelliteSquadSide(self.Squad, "neutral")
	end
	self:SetSide("neutral")
	
	MoraleModifierEvent("LieutenantDefeated", self)

	if g_Combat and not g_AIExecutionController then
		g_Combat:EndCombatCheck()
	end

	self:RemoveEnemyPindown()

	-- temporary anim
	self.command_specific_params = self.command_specific_params or {}
	self.command_specific_params.VillainDefeat = { weapon_anim_prefix = "civ_" }
	self:SetRandomAnim(self:GetIdleBaseAnim("Crouch"), const.eKeepComponentTargets, 0)
	self:SyncWithSession("map")
	Msg("VillainDefeated", self, self.on_die_attacker)
	Halt()
end

--- Despawns the unit, removing it from the game world and cleaning up any associated state.
-- This function is responsible for:
-- - Removing any combat effects or prepared attacks associated with the unit
-- - Removing the unit's crosshair from the UI if it was the target
-- - Synchronizing the unit's state with the game session
-- - Removing the unit from any squads it was a part of
-- - Cleaning up any references to the unit, such as the camera's follow target
-- - Notifying the combat system that the unit has been despawned
-- - Destroying the unit object
function Unit:Despawn()
	self:AutoRemoveCombatEffects()
	self:InterruptPreparedAttack()
	self:RemoveEnemyPindown()
	
	--remove crosshair on despawned unit
	local dlg = GetInGameInterfaceModeDlg()
	local crosshair = dlg and dlg.crosshair
	if crosshair and crosshair.context.target == self then
		dlg:RemoveCrosshair("Despawn")
		if g_Combat then
			if g_Combat:ShouldEndCombat() then
				g_Combat:EndCombatCheck(true)
			else
				SetInGameInterfaceMode("IModeCombatMovement")
			end
		else
			SetInGameInterfaceMode("IModeExploration", {suppress_camera_init = true})
		end
	end
	
	if not self:IsAmbientUnit() then self:SyncWithSession("map") end
	self.is_despawned = true
	--self:RemoveAllStatusEffects()
	if SelectedObj == self then
		SelectObj()
	end
	local cameraFollowTarget = cameraTac.GetFollowTarget()
	if cameraFollowTarget == self then
		cameraTac.SetFollowTarget(false)
	end
	if self.Squad then
		local squad = gv_Squads[self.Squad]
		if squad and (squad.Side == "enemy1" or squad.Side == "enemy2") then
			RemoveUnitFromSquad(gv_UnitData[self.session_id])
		end
	elseif not IsMerc(self) and not self.PersistentSessionId then
		gv_UnitData[self.session_id] = nil
	end
	
	if g_Combat and  not self:IsLocalPlayerControlled() and CountAnyEnemies()==1 then
		g_Combat.retreat_enemies = true
	end
	DoneObject(self)
	
	if g_Combat and not g_AIExecutionController then
		g_Combat:EndCombatCheck("force")
	end
end

---
--- Checks if the unit can activate the specified perk.
---
--- @param id number The ID of the perk to check.
--- @return boolean True if the unit can activate the perk, false otherwise.
---
function Unit:CanActivatePerk(id)
	return HasPerk(self, id) and not self.perks_activated[id] and not self:IsDead()
end

---
--- Activates the specified perk for the unit.
---
--- @param id number The ID of the perk to activate.
---
function Unit:ActivatePerk(id)
	if self.perks_activated then
		self.perks_activated[id] = true
	end
end

---
--- Returns the UI-adjusted action points for the unit.
---
--- The UI-adjusted action points are the maximum available action points minus any reserved or free move action points.
---
--- @return number The UI-adjusted action points for the unit.
---
function Unit:GetUIActionPoints()
	return self.ui_override_ap or Max(0, (self.ActionPoints or 0) - self.ui_reserved_ap - self.free_move_ap)
end

---
--- Calculates the UI-adjusted action cost for a unit.
---
--- The UI-adjusted action cost is the cost of an action in action points, taking into account the unit's current UI-adjusted action points and whether free move action points can be used.
---
--- @param ap number The base action point cost of the action.
--- @param movement boolean Whether the action involves movement.
--- @param use_free_move boolean Whether to use free move action points.
--- @return number, number, boolean The adjusted action point cost, the unit's current UI-adjusted action points, and whether free move action points were used.
---
function Unit:GetUIAdjustedActionCost(ap, movement, use_free_move)
	local ap_scale = const.Scale.AP
	local ap_now = self:GetUIActionPoints() / ap_scale
	local free
	if movement then
		local unit_ap = self.ActionPoints
		if not use_free_move then
			unit_ap = Max(0, unit_ap - SelectedObj.free_move_ap)
		end
		local ap_after = Max(0, unit_ap - ap) / ap_scale
		if ap_after >= ap_now then
			ap = 0
			if use_free_move and ap <= self.free_move_ap then
				free = true
			end
		else
			ap = ap_now - ap_after
		end
	else
		ap = ap / const.Scale.AP
	end
	
	return ap, ap_now, free
end

---
--- Checks if the unit has the required action points (AP) to perform an action.
---
--- This function takes into account the unit's UI-reserved AP and calls the `Unit:HasAP` function to determine if the unit has enough AP for the given action.
---
--- @param ap number The base action point cost of the action.
--- @param action_id string The ID of the action.
--- @param args table Optional arguments related to the action.
--- @return boolean Whether the unit has enough AP for the action.
---
function Unit:UIHasAP(ap, action_id, args)
	return self:HasAP((ap or 0) + self.ui_reserved_ap, action_id, args)
end

---
--- Checks if the unit has the required action points (AP) to perform an action.
---
--- This function takes into account the unit's free move AP and the AP cost of the action to determine if the unit has enough AP for the given action.
---
--- @param ap number The base action point cost of the action.
--- @param action_id string The ID of the action.
--- @param args table Optional arguments related to the action.
--- @return boolean Whether the unit has enough AP for the action.
--- @return number The remaining AP required for the action.
---
function Unit:HasAP(ap, action_id, args)
	if not g_Combat and not g_StartingCombat and not g_TestingSaveLoadSystem then
		return true
		--self.ActionPoints = self:GetMaxActionPoints()
	end
	local move_ap = 0
	local action = CombatActions[action_id]
	if action and action.UseFreeMove then
		if args and args.ap_cost_breakdown then
			move_ap = args.ap_cost_breakdown.move_cost or ap
		else
			move_ap = ap
		end
	else
		move_ap = args and args.goto_ap or 0
	end
	-- available ap for the action are the base AP + free move ap up to move_ap (when 0, that's the base AP only)
	local available = Max(0, (self.ActionPoints or 0) - self.free_move_ap) + Min(move_ap, self.free_move_ap)	
	return (available or 0) >= (ap or 0), (ap or 0) - (available or 0)
end

---
--- Increases the action points (AP) of the unit.
---
--- This function checks various conditions before increasing the unit's AP, such as whether the unit is in combat, pinned down, in overwatch, downed, panicked, berserk, or protected. It also checks if the unit has reached the maximum AP limit due to the "SpentAP" status effect.
---
--- If the conditions are met, the function increases the unit's AP by the specified amount, resets the combat path, and sends a "UnitAPChanged" message.
---
--- @param ap number The amount of AP to gain.
---
function Unit:GainAP(ap)
	if not g_Combat or (ap or 0) <= 0 then
		return
	end
	if g_Pindown[self] or (g_Overwatch[self] and not g_Overwatch[self].permanent) or self:IsDowned() then
		return
	end
	if self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk") or self:HasStatusEffect("Protected") then
		return
	end
	local spentAp = self:GetStatusEffect("SpentAP")
	if spentAp and spentAp.stacks >= self:GetMaxActionPoints() then
		return
	end

	self.ActionPoints = self.ActionPoints + ap
	CombatPathReset(self)
	Msg("UnitAPChanged", self)
	ObjModified(self)
end

---
--- Consumes the specified amount of action points (AP) for the unit, performing any necessary status effect updates.
---
--- This function is responsible for managing the unit's AP consumption during combat actions. It performs the following tasks:
---
--- - Removes the "Focused" status effect if the action is not a ranged or melee attack.
--- - Removes the "Mobile" and "FreeMove" status effects if the action is a ranged or melee attack.
--- - Sets the `performed_action_this_turn` property to the action ID, except for the "ChangeWeapon" action.
--- - Calculates the amount of free move AP consumed and updates the `start_move_total_ap`, `start_move_cost_ap`, and `start_move_free_ap` properties accordingly.
--- - Reduces the unit's AP by the specified amount, unless the unit is in combat and has infinite AP.
--- - Sends a "UnitAPChanged" message with the action ID and the amount of AP consumed.
---
--- @param ap number The amount of AP to consume.
--- @param action_id string The ID of the combat action being performed.
--- @param args table Optional arguments related to the combat action.
---
function Unit:ConsumeAP(ap, action_id, args)
	ap = ap or 0
	
	local action = action_id and CombatActions[action_id]
	if action and ap > 0 then
		if action.ActionType ~= "Ranged Attack" and action.ActionType ~= "Melee Attack" then
			self:RemoveStatusEffect("Focused")
		end
		if action.ActionType == "Ranged Attack" or action.ActionType ==  "Melee Attack" then
			self:RemoveStatusEffect("Mobile")
			self:RemoveStatusEffect("FreeMove")
		end
	end
	
	if action then
		if action_id ~= "ChangeWeapon" then
			self.performed_action_this_turn = action_id
		end
	end
	
	local move_ap = 0
	if action and action.UseFreeMove then
		move_ap = ap
	else
		move_ap = args and args.goto_ap or 0
	end
	if move_ap > 0 then
		self.start_move_total_ap = self.ActionPoints
		self.start_move_cost_ap = move_ap
		self.start_move_free_ap = self.free_move_ap
	
		local reduce = Min(move_ap, self.free_move_ap)
		self.free_move_ap = self.free_move_ap - reduce
	end
	
	if not g_Combat or ap <= 0 or self.infinite_ap then
		return
	end
	self.ActionPoints = Max(0, self.ActionPoints - ap)
	Msg("UnitAPChanged", self, action_id, -ap)
	ObjModified(self)
end

function OnMsg.UnitAPChanged()
	if not GetDialog("PDADialogSatellite") then
		ObjModified("combat_bar")
	end
end

function OnMsg.CombatActionEnd(unit)
	unit.start_move_total_ap = nil
	unit.start_move_cost_ap = nil
	unit.start_move_free_ap = nil
end

---
--- Adds a status effect to the unit.
---
--- @param effect string The name of the status effect to add.
--- @param ... any Additional arguments to pass to the status effect object.
--- @return boolean True if the status effect was added successfully, false otherwise.
---
function Unit:AddStatusEffect(effect, ...)
	NetUpdateHash("AddStatusEffect", self, effect)
	if self:IsDead() then return end
	if effect == "Bleeding" and self:IsDead() then
		return
	end
	if (effect == "Tired" or effect == "Exhausted") and not g_Combat then
		PlayVoiceResponse(self, effect)
	end
	return StatusEffectObject.AddStatusEffect(self, effect, ...)
end

---
--- Removes a status effect from the unit.
---
--- @param effect string The name of the status effect to remove.
--- @param ... any Additional arguments to pass to the status effect object.
--- @return boolean True if the status effect was removed successfully, false otherwise.
---
function Unit:RemoveStatusEffect(effect, ...)
	if self.StatusEffects[effect] then
		NetUpdateHash("RemoveStatusEffect", self, effect)
	end
	return StatusEffectObject.RemoveStatusEffect(self, effect, ...)
end

---
--- Adds a status effect to a unit.
---
--- @param session_id number The session ID of the unit to add the status effect to.
--- @param perk_id string The name of the status effect to add.
---
function NetEvents.UnitAddPerk(session_id, perk_id)
	local unit = g_Units[session_id]
	if unit then
		unit:AddStatusEffect(perk_id)
	end
	local unit = gv_UnitData[session_id]
	if unit then
		unit:AddStatusEffect(perk_id)
	end
end

---
--- Handles taking damage for a unit.
---
--- @param dmg number The amount of damage to take.
--- @param attacker Unit|nil The unit that is attacking this unit.
--- @param hit_descr table A table containing information about the hit.
--- @param ... any Additional arguments to pass to the base `TakeDamage` function.
--- @return any The result of the base `TakeDamage` function.
---
function Unit:TakeDamage(dmg, attacker, hit_descr, ...)
	if g_Combat then
		g_Combat:OnUnitDamaged(self, attacker)
	end

	-- lose Hidden and alert units around visually and vocally (unless killed from stealth)
	self:RemoveStatusEffect("Hidden")
	if not hit_descr.stealth_kill and not hit_descr.melee_attack and not hit_descr.setpiece then
		TriggerUnitAlert("noise", self, const.Combat.PainNoiseRangeStealthKill, Presets.NoiseTypes.Default.Gunshot.display_name, attacker)
	end
	
	if IsKindOf(attacker, "Unit") then
		self.hit_this_turn = self.hit_this_turn or {}
		table.insert(self.hit_this_turn, attacker)
	end

	if self:IsInvulnerable() and not hit_descr.setpiece then
		CreateFloatingText(self:GetVisualPos(), T(759740141426, "Invulnerable"))
		CombatLog("debug", T{Untranslated("<name> has ignored <num> damage (invulnerable)"), name = self:GetLogName(), num = dmg})
		return
	end

	return CombatObject.TakeDamage(self, dmg, attacker, hit_descr, ...)
end

---
--- Handles taking direct damage for a unit.
---
--- @param dmg number The amount of damage to take.
--- @param floating boolean Whether to show floating damage text.
--- @param log_type string The type of log message to create.
--- @param log_msg string The log message to create.
--- @param attacker Unit|nil The unit that is attacking this unit.
--- @param hit_descr table A table containing information about the hit.
---
--- @return none
---
function Unit:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	hit_descr = hit_descr or {}
	-- ignore damage from the same action that downed us
	if self:IsDowned() and self.downing_action_start_time == CombatActions_LastStartedAction.start_time then
		return
	end

	local data = { dmg = dmg, hit_descr = hit_descr }
	Msg("PreUnitDamaged", attacker, self, data)
	dmg = data.dmg
	dmg = self:CallReactions_Modify("PreUnitTakeDamage", dmg, attacker, self, hit_descr)
	if IsKindOf(attacker, "Unit") then
		dmg = attacker:CallReactions_Modify("PreUnitTakeDamage", dmg, attacker, self, hit_descr)
	end
	if dmg <= 0 then return end
	
	local hp = self.HitPoints
	local tempHp = self.TempHitPoints
	hit_descr.was_downed = self:IsDowned()
	CombatObject.TakeDirectDamage(self, dmg, floating, log_type, log_msg, attacker, hit_descr)
	self.last_turn_damaged = true

	if not self:IsDead() then
		local healthDamageTaken = self.HitPoints < hp or (dmg > 0 and (self.invulnerable or CheatEnabled("WeakDamage")))
		local gritDamageTaken = self.TempHitPoints < tempHp or (dmg > 0 and (self.invulnerable or CheatEnabled("WeakDamage")))
		if healthDamageTaken then
			MoraleModifierEvent("UnitDamaged", self, hp - self.HitPoints)
			if not (hit_descr and hit_descr.grazing) then
				self:AccumulateDamageTaken(hp - self.HitPoints)
			end
		end
		if healthDamageTaken or gritDamageTaken or hit_descr.setpiece then
			if not hit_descr.grazing then
				self:Pain(hit_descr, attacker)
			end
			self:RemoveStatusEffect("Hidden")
		end
	end

	if hit_descr and hit_descr.explosion_fly and not self:IsMerc() then
		if not self:IsDead() then
			self:Interrupt()
		end
		self:InterruptCommand("ExplosionFly", hp)
	end

	ObjModified(self)
end

---
--- Callback function called when the unit's hit points are reduced.
---
--- @param hp number The amount of hit points lost.
--- @param attacker Unit|nil The unit that caused the damage, if any.
function Unit:OnHPLoss(hp, attacker)
	if g_Combat and g_Combat.hp_loss then
		g_Combat.hp_loss[self.session_id] = (g_Combat.hp_loss[self.session_id] or 0) + hp
	end
end

---
--- Stops the pain animation and thread for the unit.
---
--- This function is used to clear the pain animation and stop the pain thread for a unit. It is typically called when the unit is no longer in pain or when the unit is being destroyed.
---
--- @param self Unit The unit object.
---
function Unit:StopPain()
	if self.pain_thread then
		self:ClearAnim(const.AnimChannel_Pain)
		DeleteThread(self.pain_thread)
		self.pain_thread = false
	end
end

---
--- Waits for the pain animation and thread to complete for the unit.
---
--- This function is used to wait for the pain animation and thread to complete before continuing execution. It is typically called after the unit has been set to play a pain animation.
---
--- @param self Unit The unit object.
---
function Unit:WaitPain()
	while IsValidThread(self.pain_thread) do
		WaitMsg(self.pain_thread, 1000)
	end
end

---
--- Plays a random pain animation for the unit and alerts any pending units.
---
--- This function is used to play a random pain animation for the unit and alert any pending units that the unit is in pain. It sets the unit's position and angle to its visual position and angle, plays a random "pain" animation, waits for the animation to complete, and then sets the unit back to its idle base animation. If the `alert_units` parameter is true, it also triggers an alert for any pending units.
---
--- @param self Unit The unit object.
--- @param alert_units boolean If true, alerts any pending units that the unit is in pain.
---
function Unit:PlayPainAnim(alert_units)
	self:SetPos(self:GetVisualPos())
	self:SetAngle(self:GetVisualAngle())
	local anim = self:GetRandomAnim("pain")
	self:SetState(anim)
	repeat until not WaitWakeup(self:TimeToAnimEnd())
	self:SetState(self:GetIdleBaseAnim())
	if alert_units then
		AlertPendingUnits()
	end
end

local function GetPainAnim(unit, prefix, stance, variant)
	local anim = string.format("%s_%s_Pain%s", prefix, stance, variant == 1 and "" or variant)
	if IsValidAnim(unit, anim) then
		return anim
	end
	if variant > 1 then
		anim = string.format("%s_%s_Pain", prefix, stance)
		if IsValidAnim(unit, anim) then
			return anim
		end
	end
end

---
--- Plays a random pain animation for the unit and alerts any pending units.
---
--- This function is used to play a random pain animation for the unit and alert any pending units that the unit is in pain. It sets the unit's position and angle to its visual position and angle, plays a random "pain" animation, waits for the animation to complete, and then sets the unit back to its idle base animation. If the `alert_units` parameter is true, it also triggers an alert for any pending units.
---
--- @param self Unit The unit object.
--- @param alert_units boolean If true, alerts any pending units that the unit is in pain.
---
function Unit:Pain(hit_descr, attacker)
	local setpiece = hit_descr and hit_descr.setpiece
	local alert_units = not setpiece
	if alert_units then
		TriggerUnitAlert("noise", self, const.Combat.PainNoiseRange, Presets.NoiseTypes.Default.Pain.display_name, attacker) -- dead units do not play pain
	end

	if self.species ~= "Human" then
		DeleteThread(self.pain_thread)
		self.pain_thread = nil
		if self:HasStatusEffect("Unconscious") then
			return
		end
		if self.interrupted then
			self.pain_thread = CreateGameTimeThread(function(self, alert_units)
				self:PlayPainAnim(alert_units)
				self.pain_thread = false
				Msg(CurrentThread())
			end, self, alert_units)
		elseif self:IsInterruptable() and CurrentThread() ~= self.command_thread then
			self:SetCommand("PlayPainAnim", alert_units)
		elseif alert_units then
			AlertPendingUnits()
		end
		return
	end

	local anim
	if self:HasAnimMask("PainMask") then   --"UpperBodyMask"
		local prefix = string.match(self:GetStateText(), "^(%a+)_%a+_.*") 
		if not prefix and setpiece then
			prefix = string.match(self:GetWeaponAnimPrefix(), "^(%a+)_")
		end
		local target_spot_group = hit_descr and hit_descr.spot_group
		local variant = target_spot_group == "Head" and 3 or 1 + self:Random(2)
		local stance = self.infected and "Standing" or self.stance
		anim = GetPainAnim(self, prefix, stance, variant)
		if not anim and prefix == "arg" then
			anim = GetPainAnim(self, "ar", stance, variant)
		end
		if not anim and prefix == "inf" then
			anim = GetPainAnim(self, "nw", stance, variant)
		end
	end
	if not (anim and IsValidAnim(self, anim)) then
		if alert_units then
			AlertPendingUnits()
		end
		return
	end

	local channel = const.AnimChannel_Pain
	local pain_anim_weight = hit_descr and hit_descr.grazing and const.PainAnimGrazingWeight or const.PainAnimWeight
	self:SetAnimMask(channel, "PainMask") --"UpperBodyMask"
	self:SetAnim(channel, anim, 0, -1, 1000, 0)
	self:SetAnimWeight(channel, pain_anim_weight, const.PainAnimWeightMoment, PainEasing)
	self:SetAnimBlendComponents(channel, false, true, false)
	DeleteThread(self.pain_thread)
	self.pain_thread = CreateGameTimeThread(function(self, anim, alert_units)
		Sleep(const.PainAnimWeightMoment)
		local channel = const.AnimChannel_Pain
		repeat
			local t = self:TimeToAnimEnd(channel)
			self:SetAnimWeight(channel, 0, t, 1, PainEasing)
		until not WaitWakeup(t)
		self:ClearAnim(channel)
		self.pain_thread = false
		if alert_units then
			AlertPendingUnits()
		end
		Msg(CurrentThread())
	end, self, anim, alert_units)
end

---
--- Knocks down the unit if it is a human and not already dead.
--- If the unit is already in a "Downed" state, a random variation of the "Downed" animation is played.
--- The unit's stance is set to "Prone", and the unit is removed from any target dummy.
--- If the unit has the "Unconscious" status effect, the unit's command is set to "Downed".
---
--- @param self Unit
--- @return nil
---
function Unit:KnockDown()
	if self.species ~= "Human" or self:IsDead() then
		return
	end
	local base_anim = self:GetActionBaseAnim("Downed", self.stance)
	local anim = self:GetStateText()
	if not IsAnimVariant(anim, base_anim) then
		anim = self:GetNearbyUniqueRandomAnim(base_anim)
	end
	--self:PushDestructor(function(self)
		self.return_pos = nil
		self:InterruptPreparedAttack() -- force interrupt when the unit gets knocked down
		if self:GetStateText() ~= anim then
			local x, y, z = FindFallDownPos(self)
			local pos = x and point(x, y, z) or self:GetPos()
			local angle = self:GetOrientationAngle()
			self:SetOrientationAngle(angle, 300)
			self:MovePlayAnim(anim, pos, pos, 0, nil, true, angle)
		end
		local variation_suffix = string.match(anim, "(%d+)$") -- there are no variations for now
		local idle_anim = self:TryGetActionAnim("Idle", "Downed", variation_suffix)
		if idle_anim then
			self:SetState(idle_anim, 0, 0)
		end
		self.stance = self:GetValidStance("Prone")
		self:SetFootPlant(true)
		self:SetTargetDummy(nil, nil, nil, 0) -- current position, animation phase 0
		--self:DoChangeStance("Prone")
		self:RemoveStatusEffect("KnockDown")
		self:RemoveStatusEffect("Protected") -- lose cover
	--end)
	--self:PopAndCallDestructor()
	if self:HasStatusEffect("Unconscious") then
		self:SetCommand("Downed")
	end
end

---
--- Plays a random "Dodge" animation for the unit based on its current stance.
--- The unit's foot is planted during the animation.
---
--- @param self Unit
--- @return nil
---
function Unit:Dodge()
	self:SetFootPlant(true)
	local anim = self:GetActionRandomAnim("Dodge", self.stance)
	self:SetState(anim, const.eKeepComponentTargets)
	Sleep(self:TimeToAnimEnd())
end

---
--- Begins a new turn for the unit.
---
--- This function is called at the start of a unit's turn. It performs various actions and checks to prepare the unit for its turn, such as:
--- - Interrupting any prepared attacks if the unit's turn is starting
--- - Updating the unit's visual state and melee training
--- - Calculating the unit's action points for the turn
--- - Handling overwatch and pindown effects
--- - Applying any status effects like burning damage
--- - Resetting turn-based flags like attacked_this_turn
--- - Applying any morale-based AP gains or losses
--- - Handling special cases like the unit dying or executing a pindown attack
---
--- @param self Unit The unit object.
--- @param new_turn boolean Whether this is the start of a new turn for the unit.
--- @return nil
---
function Unit:BeginTurn(new_turn)
	NetUpdateHash("BeginTurn_Start")
	self:SetAttackReason()
	local should_interrupt = true
	local pindown = g_Pindown[self]
	local overwatch = g_Overwatch[self]
	if pindown and IsValidTarget(pindown.target) and self:HasPindownLine(pindown.target, pindown.target_spot_group) then
		-- pindown will be handled differently when the attack is executed
		should_interrupt = false
	elseif overwatch and (overwatch.permanent or not g_Combat or overwatch.expiration_turn > g_Combat.current_turn) then
		should_interrupt = false
	elseif self.prepared_bombard_zone then
		should_interrupt = false
	end	
	if new_turn and should_interrupt then 
		self:InterruptPreparedAttack("begin turn")
		pindown = false
	end
	self:UpdateMeleeTrainingVisual()
	self:IsThreatened() -- update the is_melee_aim_last_turn flag for the vr
	
	if self.is_melee_aim_last_turn and IsMerc(self) then		
		PlayVoiceResponse(self, "MeleeEnemiesClosing")
		self.is_melee_aim_last_turn = false
	end

	self.perks_activated = {}
	NetUpdateHash("BeginTurn_Progress")
	if new_turn then
		self:RemoveStatusEffect("FreeMove")
		if g_Overwatch[self] and not g_Overwatch[self].permanent then
			self.ActionPoints = 0 -- special-case for carrying an overwatch from exploration mode
		else
			local ap = self:GetMaxActionPoints()
			ap = self:CallReactions_Modify("OnCalcStartTurnAP", ap)
			self.ActionPoints = Max(0, ap)
			
--			if g_Combat.current_turn == 1 and self:IsMerc() then --use this to test lower AP during the first turn
--				self.ActionPoints = MulDivRound(self.ActionPoints, 75, 100)
--			end
		end
		if g_Overwatch[self] then
			table.clear(g_Overwatch[self].triggered_by) -- reset triggers in case somebody already triggered in our turn
			if self:HasStatusEffect("ManningEmplacement") or self:HasStatusEffect("StationedMachineGun") then
				g_Overwatch[self].num_attacks = self:GetNumMGInterruptAttacks()
				self:UpdateOverwatchVisual()
			end
		end
		g_Pindown[self] = nil -- clear from the global table to stop the prepared attack blocking any AP gains
		self.ui_reserved_ap = 0
		
		if self:GetEffectValue("missed_by_kill_shot") and not self:IsDead() and not self:IsDowned() then
			PlayVoiceResponse(self, "MissedByKillShot")
			self:SetEffectValue("missed_by_kill_shot", nil)
		end
		
		self:UpdateHidden()
		
		local voxels = self:GetVisualVoxels()
		local fire, dist = AreVoxelsInFireRange(voxels)
		if fire then
			local min, max = const.BurnDamageMin, const.BurnDamageMax
			local damage = self:RandRange(min, max)
			self:TakeDirectDamage(damage)
			if not self:IsIncapacitated() and not self:HasStatusEffect("Unconscious") and not RollSkillCheck(self, "Health") then
				self:ChangeTired(1)
			end
			if dist < const.SlabSizeX then
				self:AddStatusEffect("Burning")
			end
		end
		
		self.attacked_this_turn = false
		self.hit_this_turn = false
		self.wounded_this_turn = false
		NetUpdateHash("BeginTurn", self, self.using_cumbersome, HasPerk(self, "KillingWind"),
								HasPerk(self, "Ironclad"))
		if not self.using_cumbersome or HasPerk(self, "KillingWind") then
			self:AddStatusEffect("FreeMove")
		elseif self:CanUseIroncladPerk() then
			self:AddStatusEffect("FreeMove")
			self:ConsumeAP(DivRound(self.free_move_ap, 2), "Move")
		end
		
		-- ConsumeAP will flag this only when an action is given, so it is safe to mark this a bit earlier to allow OnBeginTurn effects to alter it
		self.performed_action_this_turn = false
		
		Msg("UnitBeginTurn", self)
		self:CallReactions("OnBeginTurn")
		
		local morale = self:GetPersonalMorale()
		if morale > 0 then
			self:GainAP(morale * const.Scale.AP)
		elseif morale < 0 then
			self:ConsumeAP(Min(self.ActionPoints, -morale * const.Scale.AP))
		end
		
		if self:GetItemInSlot("Head", "GasMaskBase") then
			self:ConsumeAP(const.Scale.AP)
		end

		-- special-case: if the unit dies as a result of a status effect, show them and wait the command to end
		-- doing this here makes sure the camera will not immediately jump to another unit (dying or selected)
		-- similarly, executing the pindown attack has to be waited until it finishes
		if self.command == "Die" then
			SnapCameraToObj(self)
			while self.command == "Die" do
				WaitMsg("UnitDied", 20) -- can also go in VillainDefeat instead, so wait with timeout
			end
		elseif pindown then
			pindown.target:ProvokeOpportunityAttack_Pindown(self, pindown)
		elseif self.prepared_bombard_zone then
			self:StartBombard()
		end
	end
	
	if self.dummy or self:IsDowned() then
		self.ActionPoints = 0
	end

	self.start_turn_pos = self:GetVisualPos()
		
	NetUpdateHash("BeginTurn", self, self:GetPos())
	
	Msg("UnitAPChanged", self)
end

---
--- Adjusts the number of Wounded status effect stacks on an object to match its current maximum HP.
--- This function ensures that the object's maximum HP is not reduced below a minimum value.
---
--- @param obj Object The object to adjust the Wounded status effect for.
--- @param [stacks] number The number of Wounded status effect stacks to add or remove.
--- @return number The number of Wounded status effect stacks added or removed.
---
function AdjustWoundsToHP(obj,stacks)
	local effect = obj:GetStatusEffect("Wounded")
	local maxhp = obj:GetInitialMaxHitPoints()
	local value = Wounded:ResolveValue("MaxHpReductionPerStack")
	local maxreduce = Wounded:ResolveValue("MinMaxHp")
	local min = MulDivRound(maxhp, maxreduce, 100)
	local cur_stacks = effect and effect.stacks or 0
	local count = stacks and (cur_stacks + stacks) or cur_stacks
	while count>=0 do
		if maxhp - count * value >= min then
			if stacks then
				return count - cur_stacks
			end
			return count
		end
		count = count - 1
	end
	if stacks then
		return count - cur_stacks
	end
	return count
end

---
--- Recalculates the maximum hit points of a unit and adjusts the Wounded status effect accordingly.
---
--- @param unit Unit|UnitData The unit or unit data to recalculate the maximum hit points for.
--- @return number The number of Wounded status effect stacks removed.
---
function RecalcMaxHitPoints(unit) -- unit can be Unit or UnitData
	local count = AdjustWoundsToHP(unit)
	if count and count>0 then
		local effect = unit:GetStatusEffect("Wounded")
		local to_remove = effect.stacks - count
		if to_remove>0 then
			unit:RemoveStatusEffect("Wounded", to_remove)
		end
	end
	local maxhp = unit:GetModifiedMaxHitPoints()
	local prev_maxhp = unit.MaxHitPoints
	unit.MaxHitPoints = maxhp
	if maxhp > prev_maxhp then
		unit.HitPoints = unit.HitPoints + maxhp - prev_maxhp
	end
	unit.HitPoints = Min(unit.HitPoints, unit.MaxHitPoints)
	ObjModified(unit)
end

---
--- Retrieves a list of medkits and their owners from the given units, including the healer and healed units.
---
--- @param units table A list of units to search for medkits.
--- @param healer Unit|nil The unit providing the healing.
--- @param healed Unit|nil The unit receiving the healing.
--- @return number The total amount of medkit charges.
--- @return table A list of medkits and their owners.
--- @return table A table mapping unit IDs to the total amount of medkit charges they have.
---
function GetMedsAndOwners(units, healer, healed)
	local total_amount = 0
	local list, meds_list = {}, {}

	local function add_meds(unit, list)
		local meds = unit:GetItem("Meds")
		if meds then
			total_amount = total_amount + meds.Amount
			list[#list + 1] = meds
			list[#list + 1] = unit
			meds_list[unit.session_id] = (meds_list[unit.session_id] or 0) + meds.Amount
		end
	end

	if healer then
		add_meds(healer, list)
	end
	if healed and healed ~= healer then
		add_meds(healed, list)
	end

	for _, unit in ipairs(units) do
		if unit ~= healer and unit ~= healed then
			add_meds(unit, list)
		end
	end
	local squad_id = units and units[1] and units[1].Squad
	if squad_id then
		for _, meds in ipairs(GetSquadBag(squad_id)) do
			if meds.class == "Meds" then
				total_amount = total_amount + meds.Amount
				list[#list + 1] = meds
				list[#list + 1] = squad_id
				meds_list[squad_id] = (meds_list[squad_id] or 0) + meds.Amount
			end
		end
	end
	
	return total_amount, list, meds_list
end

---
--- Calculates the amount of healing that a medkit can provide to a target unit.
---
--- @param medkit Meds The medkit to use for healing.
--- @param target Unit The unit to heal.
--- @return number The amount of healing that can be provided.
--- @return number The percentage of the target's maximum health that the healing represents.
---
function Unit:CalcHealAmount(medkit, target)
	if not medkit then return 0 end
	local base_heal = CombatActions.Bandage:ResolveValue("base_heal")
	local medical_heal = CombatActions.Bandage:ResolveValue("medical_max_heal")
	local selfheal = CombatActions.Bandage:ResolveValue("selfheal")

	local heal_percent = base_heal + MulDivRound(self.Medical, medical_heal, 100)
	local data = {
		heal_amount = 0,
		heal_percent = heal_percent,
		self_heal_percent = 50,
		heal_modifier = 100,
	}
	self:CallReactions("OnCalcHealAmount", target, self, medkit, data)
	if target ~= self and IsKindOf(target, "UnitBase") then
		target:CallReactions("OnCalcHealAmount", target, self, medkit, data)
	end
	
	local heal_percent = data.heal_percent
	if target == self then
		heal_percent = MulDivRound(heal_percent, data.self_heal_percent, 100)
	end
	local heal_mod = MulDivRound(heal_percent, data.heal_modifier, 100)
		
	-- convert to raw hp
	local max = IsValid(target) and target.MaxHitPoints or self.MaxHitPoints
	return data.heal_amount + MulDivRound(max, heal_mod, 100), MulDivRound(heal_percent, 100, heal_mod)
end

---
--- Called at the end of a unit's turn.
---
--- This function performs various cleanup and bookkeeping tasks at the end of a unit's turn, such as:
--- - Removing the "FreeMove" status effect
--- - Tracking the unit's last turn movement
--- - Resetting the "last_turn_damaged" flag
--- - Updating the unit's overwatch attacks
--- - Calling the "OnEndTurn" reaction on the unit
--- - Removing expired status effects
--- - Handling the special case where a unit dies as a result of a status effect
---
--- @function Unit:OnEndTurn
--- @return nil
function Unit:OnEndTurn()
	self:RemoveStatusEffect("FreeMove") -- cleanup unused free move ap
	if self.start_turn_pos then -- Units hired during this turn don't have start_turn_pos
		self.last_turn_movement = self:GetVisualPos() - self.start_turn_pos
	else
		self.last_turn_movement = nil
	end
	self.last_turn_damaged = nil -- reset here, we're tracking damage done between the end of our turn and the start of our next one
	SetCombatActionState(self, false)
	
	-- add attacks from remaining AP to permanent overwatch
	self:UpdateNumOverwatchAttacks()
	
	Msg("UnitEndTurn", self)
	self:CallReactions("OnEndTurn")
	for i = #self.StatusEffects, 1, -1 do
		local effect = self.StatusEffects[i]
		if effect.lifetime ~= "Indefinite" then
			local expiration = self:GetEffectExpirationTurn(effect.class, "expiration")
			if g_Combat and g_Combat.current_turn >= expiration then
				self:RemoveStatusEffect(effect.class, "all")
			end
		end
	end
		
	-- special-case: if the unit dies as a result of a status effect, show them and wait the command to end
	-- doing this here makes sure the camera will not immediately jump to another unit (dying or selected)
	if self.command == "Die" then
		SnapCameraToObj(self)
		while self.command == "Die" do
			WaitMsg("UnitDied", 20) -- can also go in VillainDefeat instead, so wait with timeout
		end
	end
end

---
--- Called at the start of a unit's command.
--- This function performs various setup and initialization tasks at the start of a unit's command, such as:
--- - Interrupting the current command if the unit was previously interrupted
--- - Resetting various state variables related to the unit's movement and visual styles
--- - Unblocking any tunnels the unit may have been traversing
--- - Setting the unit's gravity to 0 and stopping any current movement
--- - Clearing the unit's path and adjusting its position if it was traversing a tunnel
--- - Disabling weapon light effects and aim IK if the current command does not require them
--- - Setting the unit's foot plant state and beginning interruptable movement if the command is interruptable
--- - Setting the unit's aim FX and combat action state
---
--- @function Unit:OnCommandStart
--- @return nil
function Unit:OnCommandStart()
	if self.interrupted then
		self:InterruptEnd()
	end
	self.cur_idle_style = false
	self.cur_move_style = false
	self.goto_target = false
	self.goto_stance = false
	self.goto_hide = false
	self.visibility_override = false
	self.passed_interrupts = nil
	self:TunnelsUnblock()
	self.action_visual_weapon = false
	if IsValid(self) then
		self:SetGravity(0)
		self:StopMoving()
		self.interrupted = false
		if not self:IsDead() and not IsActivePaused() and not IsSetpieceActor(self) then
			self:ClearPath()
			if self.traverse_tunnel then
				local tpos = self.traverse_tunnel:GetExit()
				if tpos then
					local pos = GetPassSlab(tpos) or FindPassable(tpos, 0, -1, -1, const.pfmVoxelAligned) or tpos
					self:SetPos(pos)
				end
			end
		end
		if not KeepAimIKCommands[self.command] then
			self:SetWeaponLightFx(false)
			self:SetIK("AimIK", false)
		end
		self:SetIK("LookAtIK", false)
		if not self.interruptable and self.command then
			self:BeginInterruptableMovement()
		end
		self:SetFootPlant(true)
	end
	self.traverse_tunnel = false
	self:SetAimFX(false, self.command and "delayed")
	if self.action_command then
		SetCombatActionState(self, self.command == self.action_command and "start" or nil)
	end
end

---
--- Sets the action command for the unit.
---
--- @param command string The action command to set.
--- @param combatActionId string The ID of the combat action.
--- @param ... any Additional arguments to pass to the action command.
---
--- @return nil
function Unit:SetActionCommand(command, combatActionId, ...)
	-- the interface should clear the visualisations
	DbgClearVectors()
	DbgClearTexts()

	if IsActivePaused() then
		if CombatActions_RunningState[self] then
			SetCombatActionState(self)
		else
			self:SetQueuedAction()
		end
	end

	self.action_command = command
	SetCombatActionState(self, "wait")

	self:InterruptCommand(command, combatActionId, ...)
end

---
--- Checks if the unit is controlled by the local player.
---
--- @param player_control_mask number The control mask to check against.
--- @return boolean True if the unit is controlled by the local player, false otherwise.
---
function Unit:IsLocalPlayerControlled(player_control_mask)
	return IsControlledByLocalPlayer(self.team and self.team.side, player_control_mask or self.ControlledBy)
end

---
--- Checks if the unit's team is controlled by the local player.
---
--- @param self Unit The unit to check.
--- @return boolean True if the unit's team is controlled by the local player, false otherwise.
---
function Unit:IsLocalPlayerTeam()
	if not netInGame then
		return self:IsLocalPlayerControlled()
	else
		local squad = self.team
		if not squad then return true end
		return squad.side == NetPlayerSide(netUniqueId)
	end
end

---
--- Checks if the unit is controlled by the specified control mask.
---
--- @param mask number The control mask to check against.
--- @return boolean True if the unit is controlled by the specified mask, false otherwise.
---
function Unit:IsControlledBy(mask)
	return self.ControlledBy & mask ~= 0
end

---
--- Checks if the unit is in an uncontrollable state, such as being incapacitated, panicked, or berserk.
---
--- @param self Unit The unit to check.
--- @return boolean True if the unit is in an uncontrollable state, false otherwise.
---
function Unit:IsDisabled()
	--the unit is in an uncontrollable state
	return self:IsIncapacitated() or self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk")
end

--CanBeControlled() without args returns whether unit can be controlled by local player
--CanBeControlled("sync_code") returns whether unit can be controlled by any player in general omiting async reasons for control loss
---
--- Checks if the unit can be controlled by the local player.
---
--- @param sync_code boolean Whether the check is for synchronous control.
--- @return boolean True if the unit can be controlled, false otherwise.
--- @return string|nil Reason for control failure, if any.
---
function Unit:CanBeControlled(sync_code)
	if not IsValid(self) then return false end
	if GetDialog("ConversationDialog") then return false end

	--disabled units cannot be controlled
	if self:IsIncapacitated() then return false end
	--is it an AI team?
	if not self.team or self.team.control ~= "UI" then return false end
	
	--can it be controlled by the local player network wise?
	if not self:IsLocalPlayerControlled(sync_code and -1 or nil) then -- -1 is any net player
		return false 
	end
	
	-- Don't do further checks in deployment mode.
	if gv_DeploymentStarted then return true end
	
	if g_AIExecutionController or g_UnitAwarenessPending == "alert" then -- AI units taking actions
		return false
	end

	if g_Combat then
		if not g_Combat.combat_started then
			return false
		end
		-- Not current team in combat
		if not g_Combat:HasTeamTurnStarted(self.team) then
			return false
		end
		if not sync_code and g_Combat:IsLocalPlayerEndTurn() or --this is async
			sync_code and not IsNetPlayerTurn() then --this is sync
			return false, "not_local_turn"
		end
	end

	return true
end

---
--- Blocks a tunnel for the unit.
---
--- @param tunnel_entrance Vector3 The position of the tunnel entrance.
--- @param tunnel_exit Vector3 The position of the tunnel exit.
---
function Unit:TunnelBlock(tunnel_entrance, tunnel_exit)
	for i, o in ipairs(self.tunnel_blockers) do
		if o.tunnel_end_point == tunnel_exit and tunnel_entrance:Equal(o:GetPosXYZ()) then
			return
		end
	end
	local o = PlaceObject("TunnelBlocker")
	o.owner = self
	o.tunnel_end_point = tunnel_exit
	pf.SetCollisionRadius(o, self:GetCollisionRadius())
	o:SetPos(tunnel_entrance)
	if not self.tunnel_blockers then
		self.tunnel_blockers = {}
	end
	table.insert(self.tunnel_blockers, o)
	if not (g_Combat and self:IsAware()) then
		MapForEach(tunnel_exit, 0, "Unit", function(o, self)
			if o:GetEnumFlags(const.efResting) == 0 or o:IsDead() then
				return
			end
			if o.command == "Idle" and o ~= self then
				o:SetCommand("GotoSlab", tunnel_exit)
			end
		end, self)
	end
end

---
--- Unblocks a tunnel for the unit.
---
--- @param tunnel_entrance Vector3 The position of the tunnel entrance.
--- @param tunnel_exit Vector3 The position of the tunnel exit.
---
function Unit:TunnelUnblock(tunnel_entrance, tunnel_exit)
	for i, o in ipairs(self.tunnel_blockers) do
		if o.tunnel_end_point == tunnel_exit and tunnel_entrance:Equal(o:GetPosXYZ()) then
			table.remove(self.tunnel_blockers, i)
			DoneObject(o)
			break
		end
	end
end

---
--- Unblocks all tunnels that were previously blocked by this unit.
---
function Unit:TunnelsUnblock()
	local list = self.tunnel_blockers
	if not list or #list == 0 then
		return
	end
	for i, o in ipairs(list) do
		DoneObject(o)
	end
	table.iclear(list)
end

local function CheckInterruptCombatGotoPos(x, y, z, unit, ignore_pos)
	if not CanOccupy(unit, x, y, z) then
		return false
	end
	if ignore_pos and ignore_pos:Equal(x, y, z) then
		return false
	end
	local cost = unit.combat_path_obj:GetAP(point_pack(x, y, z))
	if not cost or cost >= (unit.combat_path_obj:GetAP(unit.combat_path[1]) or 0) then
		return false
	end
	return true
end

---
--- Gets the interrupt combat path for the unit.
---
--- This function checks the current combat path of the unit and determines if there is a better path that the unit can take to interrupt its current combat action. It does this by iterating through the combat path and checking if there are any positions along the path that the unit can move to more efficiently.
---
--- If an interrupt path is found, this function returns a new path that the unit can take to interrupt its current combat action. If no interrupt path is found, this function returns `nil`.
---
--- @return table|nil The interrupt combat path, or `nil` if no interrupt path is found.
function Unit:GetInterruptCombatPath()
	local path = self.combat_path
	if not path or #path == 0 then
		return
	end
	local idx = #path
	local cur_pos
	if self.traverse_tunnel then
		cur_pos = point(point_unpack(path[idx]))
		idx = idx - 1
	else
		cur_pos = self:GetVisualPos()
		if not self:IsValidZ() then
			cur_pos = cur_pos:SetInvalidZ()
		end
	end
	for i = idx, 1, -1 do
		local x, y, z = point_unpack(path[i])
		local next_pos = point(x, y, z)
		local back_pos
		if i == idx and not self.traverse_tunnel then
			local pass_pos = GetPassSlab(self)
			if pass_pos and pass_pos ~= cur_pos then
				local a1 = CalcOrientation(cur_pos, next_pos)
				local a2 = CalcOrientation(cur_pos, pass_pos)
				if abs(AngleDiff(a1, a2)) > 90 * 60 then
					back_pos = pass_pos
				end
			end
		end
		local interrupt_pos
		if cur_pos ~= next_pos and not pf.GetTunnel(cur_pos, next_pos) then
			interrupt_pos = RasterizeSegmentPassSlabs(cur_pos, next_pos, CheckInterruptCombatGotoPos, self, back_pos)
		elseif SnapToVoxel(next_pos) == next_pos and CheckInterruptCombatGotoPos(x, y, z, self, back_pos) then
			interrupt_pos = next_pos
		end
		if interrupt_pos then
			if i == 1 and interrupt_pos == next_pos then
				return
			end
			local new_path = { point_pack(interrupt_pos) }
			for j = i + 1, #path do
				table.insert(new_path, path[j])
			end
			return new_path
		end
		cur_pos = next_pos
	end
end

---
--- Interrupts the current combat movement of the unit and updates the combat path.
---
--- @param new_pos table|nil The new position to move to, or nil to calculate a new interrupt path.
--- @param restore_ap_only boolean If true, only restores the AP cost difference and does not execute the new movement.
--- @return nil
function Unit:CombatGotoInterrupt(new_pos, restore_ap_only)
	if not self.combat_path or not self.combat_path_obj or self:IsDead() then
		return
	end
	local prev_pos = self.combat_path[1]
	local prev_cost = self.combat_path_obj:GetAP(prev_pos) or 0

	local interrupt_path
	if new_pos then
		if IsPoint(new_pos) then
			new_pos = point_pack(new_pos)
		end
		interrupt_path = { new_pos }
	else
		interrupt_path = self:GetInterruptCombatPath()
		if not interrupt_path then
			return
		end
		new_pos = interrupt_path[1]
	end
	local new_cost = self.combat_path_obj:GetAP(new_pos) or 0
	self.combat_path_obj = false
	self.combat_path = false
	if new_cost < prev_cost then
		self:GainAP(prev_cost - new_cost)
		if self.start_move_free_ap > 0 then
			-- restore ap -> free move ap
			local start_ui_ap = self.start_move_total_ap - self.start_move_free_ap
			self.free_move_ap = Max(0, self.ActionPoints - start_ui_ap)
			ObjModified(self)
		end
	end
	if restore_ap_only then
		return
	end
	SetCombatActionState(self, false)
	RunCombatAction("Move", self, new_cost, { goto_pos = point(point_unpack(new_pos)), path = interrupt_path })
end

local function ForEachWalkStep(p0, p1, f, ...)
	local step = const.SlabSizeX
	local x0, y0, z0 = p0:xyz()
	local x1, y1, z1 = p1:xyz()
	local dx = x1 - x0
	local dy = y1 - y0
	if abs(dx) >= abs(dy) then
		local step = step * (x1 >= x0 and 1 or -1)
		for x = x0 + step, x1, step do
			local y = y0 + MulDivRound(x - x0, dy, dx)
			f(point(x, y, z0), ...)
		end
	else
		local step = step * (y1 >= y0 and 1 or -1)
		for y = y0 + step, y1, step do
			local x = x0 + MulDivRound(y - y0, dx, dy)
			f(point(x, y, z0), ...)
		end
	end
end

--- Determines if the unit can perform a quick play action in combat.
---
--- @param noQuickPlay boolean Whether to disable quick play actions.
--- @return boolean True if the unit can perform a quick play action in combat, false otherwise.
function Unit:CanQuickPlayInCombat(noQuickPlay)
	return g_Combat and not noQuickPlay and not self.visible and self.team and not self.team.player_team
end

local function IsSamePos(p1, p2)
	if not p1 ~= not p2 then return false end
	local x1, y1, z1 = p1:xyz()
	local x2, y2, z2 = p2:xyz()
	z1 = z1 or terrain.GetHeight(x1, y1)
	z2 = z2 or terrain.GetHeight(x2, y2)
	return (x1 == x2) and (y1 == y2) and (z1 == z2)
end

---
--- Moves the unit to the specified position during combat.
---
--- @param action_id string The ID of the combat action being performed.
--- @param cost_ap number The action points cost of the movement.
--- @param pos point The target position to move to.
--- @param interrupt_path table A table of points representing an interrupt path.
--- @param forced_run boolean Whether the unit should run during the movement.
--- @param stanceAtStart string The stance the unit should be in at the start of the movement.
--- @param stanceAtEnd string The stance the unit should be in at the end of the movement.
--- @param fallbackMoveTracking boolean Whether to use fallback move tracking.
--- @param visibleMovement boolean Whether the movement should be visible.
--- @return boolean True if the movement was successful, false otherwise.
---
function Unit:CombatGoto(action_id, cost_ap, pos, interrupt_path, forced_run, stanceAtStart, stanceAtEnd, fallbackMoveTracking, visibleMovement)
	Msg("UnitAnyMovementStart", self, pos, stanceAtStart, stanceAtEnd)
	
	self:RemovePreparedAttackVisuals()
	if interrupt_path then
		self.combat_path = interrupt_path
		pos = point(point_unpack(interrupt_path[1]))
	else
		self.combat_path_obj = GetCombatPath(self, stanceAtStart, cost_ap, stanceAtEnd)
		self.combat_path = self.combat_path_obj:GetCombatPathFromPos(pos)
		
		if not stanceAtStart and self.combat_path and self.combat_path_obj.destination_stances and pos then
			stanceAtStart = self.combat_path_obj.destination_stances[point_pack(pos)]
		end
		
		local new_cost = self.combat_path_obj:GetAP(pos)
		if not new_cost or new_cost > cost_ap then
			self:GainAP(cost_ap)
			CombatActionInterruped(self)
			return false
		end
		if new_cost < cost_ap then
			self:GainAP(cost_ap - new_cost)
			cost_ap = new_cost
		end
	end
	if not self.combat_path then
		self:GainAP(cost_ap)
		return true
	end
	if self.combat_path_obj then
		self:SetActionInterruptCallback("CombatGotoInterrupt")
	end
	local thread_RunStop
	self:PushDestructor(function(self)
		DeleteThread(thread_RunStop)
		if IsValid(self) then
			if self.combat_path then
				self:CombatGotoInterrupt(nil, "restore_ap_only")
			end
			self:SetActionInterruptCallback()
		end
		self.combat_path_obj = false
		self.combat_path = false
		self.in_combat_movement = false
	end)
	self.in_combat_movement = true

	if stanceAtStart and self.stance ~= stanceAtStart then
		self:ChangeStance("Stance" .. stanceAtStart, 0, stanceAtStart)
	end

	-- update move anim
	local path = self.combat_path
	local pfclass = self:GetPfClass() + 1
	local tunnel_mask = pathfind[pfclass].tunnel_mask
	local GetTunnel = pf.GetTunnel
	local run_dist = 0
	local px, py, pz = self:GetPosXYZ()
	for i = #path, 1, -1 do
		if terrain.GetPassType(px, py, pz) == pathfind_water_pass_type_idx then
			break
		end
		local px2, py2, pz2 = point_unpack(path[i])
		local tunnel = GetTunnel(px, py, pz, px2, py2, pz2, tunnel_mask)
		if tunnel and not tunnel:CanSprintThrough() then
			break
		end
		run_dist = run_dist + GetLen(px - px2, py - py2, pz and pz2 and pz - pz2 or 0)
		px, py, pz = px2, py2, pz2
	end

	local move_anim_type
	if self.species == "Human" then
		if self.stance == "Standing" and (forced_run or run_dist >= 5 * const.SlabSizeX) then
			move_anim_type = "Run"
		end
	end

	local has_closed_door = false
	local px, py, pz = self:GetPosXYZ()
	local closed_door_mask = const.TunnelMaskClosedDoor
	for i = #path, 1, -1 do
		local px2, py2, pz2 = point_unpack(path[i])
		local tunnel = GetTunnel(px, py, pz, px2, py2, pz2, closed_door_mask)
		if tunnel then
			has_closed_door = true
			break
		end
		px, py, pz = px2, py2, pz2
	end

	self:SetIK("AimIK", false)
	self:SetFootPlant(true)
	local base_idle = self:GetIdleBaseAnim()
	local goto_dummies = self:GenerateTargetDummiesFromPath(self.combat_path)
	for _, dummy in ipairs(goto_dummies) do
		if dummy.insert_idx then
			dummy.insert_before_pos = self.combat_path[dummy.insert_idx] or "limit"
		end
	end

	local known_traps
	local all_move_interrupts = self:CheckProvokeOpportunityAttacks(CombatActions.Move, "move", goto_dummies, true, "all")
	for i, t in ipairs(all_move_interrupts) do
		if t[1] == "trap" then
			known_traps = known_traps or {}
			table.insert(known_traps, t[2])
		end
	end

	local provoke_idx, provoke_pos, interrupts
	local UpdateProvokePos = function(init)
		if provoke_idx then
			for i = 1, provoke_idx do
				table.remove(goto_dummies, 1)
			end
		elseif not init then
			return
		end
		interrupts, provoke_idx = self:CheckProvokeOpportunityAttacks(CombatActions.Move, "move", goto_dummies, nil, nil, nil, known_traps)
		provoke_pos = provoke_idx and goto_dummies[provoke_idx].pos
		if provoke_pos then
			-- add the provoke point in the path if not present
			local insert_idx
			local insert_marker = goto_dummies[provoke_idx].insert_before_pos
			if insert_marker == "limit" then
				insert_idx = #path + 1
			else
				local pp = point_pack(provoke_pos)
				local provoke_dist = self:GetDist(provoke_pos)
				for i, ppos in ipairs(path) do
					if ppos == pp then
						insert_idx = false
						break
					elseif insert_marker == ppos or (self:GetDist(point_unpack(ppos)) < provoke_dist) then
						insert_idx = i
						break
					end
				end
			end
			
			if insert_idx then
				table.insert(path, insert_idx, point_pack(provoke_pos))
			end
			return
		end
		local goto_pos, angle
		if not next(self.combat_path)  then
			goto_pos = self:GetPos()
		else
			goto_pos = point(point_unpack(self.combat_path[1]))
			if self.combat_path[2] then
				angle = CalcOrientation(point(point_unpack(self.combat_path[2])), goto_pos)
			end
		end
		angle = angle or self:GetOrientationAngle()
		self:SetTargetDummy(goto_pos, angle, base_idle, 0)
		self.target_dummy:SetEnumFlags(const.efResting)
		-- update occupy in advance to allow parallel unit movements
		if action_id and not has_closed_door and CombatActions[action_id].SimultaneousPlay and not fallbackMoveTracking then
			SetCombatActionState(self, "PostAction")
		end
	end
	UpdateProvokePos(true)
	if provoke_pos then
		self:SetTargetDummy(false)
		if self.command ~= "Reposition" then
			WaitOtherCombatActionsEnd(self)
		end
	end

	-- If was visible at the start of movement, should be visible throughout
	local povTeam = GetPoVTeam()
	if povTeam then
		if HasVisibilityTo(povTeam, self) then
			self.visibility_override = goto_dummies[1]
		end
	end

	-- If will enter overwatch, show me as if there.
	if not self.visibility_override then
		for i, int in ipairs(interrupts) do
			if int[1] == "overwatch" then
				self.visibility_override = goto_dummies[provoke_idx]
			end
		end
	end

	-- Update visibility as if at final pos otherwise.
	if not self.visibility_override then
		self.visibility_override = goto_dummies[#goto_dummies]
	end

	if self.command == "CombatGoto" and self:IsLocalPlayerControlled() then
		if not self:HasStatusEffect("Panicked") and not self:HasStatusEffect("Berserk") then
			local distanceMove = GetCombatPathLen(path, self)
			if distanceMove >= const.SlabSizeX * 3 then
				if self:HasStatusEffect("Hidden") then
					PlayVoiceResponse(self, "CombatMovementStealth")
				else
					PlayVoiceResponse(self, "CombatMovement")
				end
			end
		end
	end

	local cur_pos = GetPassSlab(self) or self:GetVisualPos()
	if provoke_pos then
		self:SetTargetDummy(false) -- the target used for opportunity attacks
		if IsSamePos(provoke_pos, cur_pos) then
			self:ProvokeOpportunityAttacksFromList(interrupts)
			UpdateProvokePos()
		end
	end

	local next_pos_idx = #path
	if self:GetDist2D(point_unpack(path[next_pos_idx])) == 0 then
		next_pos_idx = next_pos_idx - 1
		if next_pos_idx > 0 and not IsValidPos(point_unpack(path[next_pos_idx])) then
			next_pos_idx = next_pos_idx - 1 -- skip tunnel marker
		end
	end
	local next_pt = next_pos_idx > 0 and point(point_unpack(path[next_pos_idx]))
	self:ClearEnumFlags(const.efResting)
	self:UpdateMoveAnim(action_id, move_anim_type, next_pt)
	local start_angle = next_pt and CalcOrientation(self, next_pt)
	local move_anim = GetStateName(self:GetMoveAnim())
	self:ReturnToCover(nil, false) -- do not touch the target dummy
	self:PlayTransitionAnims(move_anim, start_angle)
	self:GotoTurnOnPlace(next_pt)

	VisibilityUpdate()
	self:StartMoving()

	-- follow path
	local prev_pos = cur_pos
	Msg("UnitMovementStart", self, cur_pos)
	local stop_anim_pos = self:CombatGoto_GetStopAnimPos()
	local play_stop_dist
	while true do
		self:UpdateMoveSpeed()
		self:UpdateInWaterFX()
		if IsSamePos(provoke_pos, cur_pos) then
			self:ProvokeOpportunityAttacksFromList(interrupts)
			UpdateProvokePos()
		end
		local next_pos = point(point_unpack(path[#path]))
		if next_pos == cur_pos then
			path[#path] = nil
			if #path == 0 then
				break
			end
			next_pos = point(point_unpack(path[#path]))
		end
		local quick_play = self:CanQuickPlayInCombat(visibleMovement)
		if cur_pos == stop_anim_pos and not provoke_pos and not quick_play then
			play_stop_dist = self:StartPlayRunStop(path)
		end
		if play_stop_dist then
			local anim = self:GetStateText()
			local has_end_phase, end_phase = self:IterateMoments(anim, 0, 1, "end")
			if not has_end_phase then
				end_phase = GetAnimDuration(self:GetEntity(), anim) - 1
			end
			if not thread_RunStop then
				thread_RunStop = CreateGameTimeThread(function(self, pos, end_phase)
					local has_hit_phase, hit_phase = self:IterateMoments(anim, 0, 1, "hit")
					if not has_hit_phase then
						hit_phase = end_phase
					end
					local next_hit_time = self:TimeToPhase(1, hit_phase)
					if next_hit_time then
						Sleep(next_hit_time)
					end
					local surface_fx_type, surface_pos = GetObjMaterial(pos:IsValidZ() and pos or pos:SetTerrainZ())
					PlayFX("RunStop", "hit", self, surface_fx_type, surface_pos)
				end, self, next_pos, end_phase)
			end
			local next_pos_time
			if #path == 1 then
				next_pos_time = self:TimeToPhase(1, end_phase)
			else
				local phase = self:GetAnimPhase(1)
				local next_step_dist = self:GetStepVector(anim, 0, phase, end_phase - phase):Len2D() * self:GetVisualDist2D(next_pos) / play_stop_dist
				local min = phase
				local max = end_phase
				while max - min > 10 do
					local m = min + (max - min) / 2
					local len = self:GetStepVector(anim, 0, phase, m - phase):Len2D()
					if len < next_step_dist then
						min = m
					else
						max = m
					end
				end
				next_pos_time = self:TimeToPhase(1, min)
			end
			self:SetPos(next_pos, next_pos_time or 0)
			if next_pos_time then
				Sleep(next_pos_time)
			end
			if #path == 1 then
				local surface_fx_type, surface_pos = GetObjMaterial(next_pos:IsValidZ() and next_pos or next_pos:SetTerrainZ())
				PlayFX("RunStop", "end", self, surface_fx_type, surface_pos)
			end
		else
			local tunnel = GetTunnel(cur_pos, next_pos, tunnel_mask)
			if tunnel then
				local can_use_tunnel
				can_use_tunnel, quick_play = self:InteractTunnel(tunnel, quick_play)
				if not can_use_tunnel then
					self:Interrupt(nil, cur_pos) -- locked door
					break
				end
				if not IsValid(tunnel) then
					-- the open door erased the tunnel
					tunnel = GetTunnel(cur_pos, next_pos, tunnel_mask)
				end
				if tunnel then
					self:TraverseTunnel(tunnel, cur_pos, next_pos, false, quick_play)
					if quick_play and self:GetStateText() ~= move_anim then
						self:SetState(move_anim, const.eKeepComponentTargets, 0)
					end
				elseif IsPassSlabStep(cur_pos, next_pos, 0, self:GetPfClass()) then
					next_pos = cur_pos
				else
					self:Interrupt() -- the path is no more valid
					break
				end
			else
				if self:GetStateText() ~= move_anim then
					self:SetState(move_anim, const.eKeepComponentTargets, quick_play and 0 or -1)
					self:SetFootPlant(true)
				end
				local angle = CalcOrientation(cur_pos, next_pos)
				local max_step_len = 5 * const.SlabSizeX
				local step_dist = cur_pos:Dist2D(next_pos)
				if step_dist > max_step_len then
					table.insert(path, point_pack(next_pos))
					next_pos = RotateRadius(max_step_len, angle, cur_pos)
					step_dist = cur_pos:Dist2D(next_pos)
				end
				if quick_play then
					self:SetPos(next_pos)
					self:SetOrientationAngle(angle)
				else
					while step_dist > 0 do
						local time = MulDivRound(step_dist, 1000, Max(1, self:GetSpeed()))
						self:SetPos(next_pos, time)
						if self.ground_orient then
							local steps = 1 + step_dist / (const.SlabSizeX / 2)
							for i = 1, steps do
								local t = time * i / steps - time * (i-1) / steps
								self:SetOrientationAngle(angle, t)
								if WaitWakeup(t) then
									break
								end
							end
						else
							self:SetOrientationAngle(angle, 300)
							WaitWakeup(time)
						end
						step_dist = self:GetVisualDist2D(next_pos)
					end
				end
			end
		end
		cur_pos = next_pos
		Msg("CombatGotoStep", self)
	end
	
	if stanceAtEnd and self.stance ~= stanceAtEnd then
		self:ChangeStance("Stance" .. stanceAtEnd, 0, stanceAtEnd)
	end

	self.combat_path_obj = false
	self.combat_path = false
	self:PopAndCallDestructor()
	Msg("UnitMovementDone", self, action_id, prev_pos)
	return true
end

---
--- Calculates the position where the unit should stop its movement animation.
--- This function is used to determine the appropriate position to start the stop animation
--- when the unit is moving in combat mode.
---
--- @param self Unit The unit object.
--- @return Vector3 The position where the unit should start the stop animation.
---
function Unit:CombatGoto_GetStopAnimPos()
	if self.species ~= "Human" or self.stance == "Prone" or self.infected then
		return
	end
	local path = self.combat_path
	local pfclass = self:GetPfClass() + 1
	local tunnel_mask = pathfind[pfclass].tunnel_mask
	if path[#path] ~= point_pack(self:GetPosXYZ()) then
		table.insert(path, point_pack(self:GetPos()))
	end
	if #path < 2 then
		return
	end
	local p1 = point(point_unpack(path[1]))
	local p2 = point(point_unpack(path[2]))
	local tunnel = pf.GetTunnel(p2, p1, tunnel_mask)
	if tunnel then
		local tunnel_type = pf.GetTunnelType(tunnel)
		if tunnel_type ~= (tunnel_type & const.TunnelMaskWalk) then
			return
		end
	end
	local dir_pos = RotateRadius(const.SlabSizeX, CalcOrientation(p2, p1), p1)
	if GetCoverFrom(p1, dir_pos) == 0 then
		return -- there should be a cover ahead of us
	end

	local move_anim = GetStateName(self:GetMoveAnim())
	local is_running = string.match(move_anim, ".*_CombatRun.*") and true or false
	local stop_distance, min_stop_distance
	if is_running then
		stop_distance = 5*guim
		min_stop_distance = stop_distance
	else
		stop_distance = 2*guim
		min_stop_distance = stop_distance
	end

	local start_stop_anim_pos = p1
	local start_stop_anim_idx = 1
	for i = 2, #path do
		local prev = point(point_unpack(path[i]))
		local tunnel = pf.GetTunnel(prev, start_stop_anim_pos, tunnel_mask)
		if tunnel then
			local tunnel_type = pf.GetTunnelType(tunnel)
			if tunnel_type ~= (tunnel_type & const.TunnelMaskWalk) then
				break
			end
		end
		if i > 2 and DistSegmentToPt2D(p1, p2, prev) >= 2 then
			break
		end
		start_stop_anim_pos = prev
		start_stop_anim_idx = i
		if not IsCloser2D(p1, start_stop_anim_pos, stop_distance) then
			break
		end
	end
	if IsCloser2D(p1, start_stop_anim_pos, min_stop_distance) then
		return
	end
	if not IsCloser2D(p1, start_stop_anim_pos, stop_distance) then
		if p1:IsValidZ() or start_stop_anim_pos:IsValidZ() then
			if not p1:IsValidZ() then p1 = p1:SetTerrainZ() end
			if not start_stop_anim_pos:IsValidZ() then start_stop_anim_pos = start_stop_anim_pos:SetTerrainZ() end
		end
		start_stop_anim_pos = p1 + SetLen(start_stop_anim_pos - p1, stop_distance)
		table.insert(path, start_stop_anim_idx, point_pack(start_stop_anim_pos))
	end
	return start_stop_anim_pos
end

---
--- Plays the stop animation for the unit's current movement animation.
--- Calculates the appropriate phase of the stop animation to match the unit's current position in the path.
---
--- @param path table The path the unit is following.
--- @return number The distance to the stop position.
---
function Unit:StartPlayRunStop(path)
	local move_anim = GetStateName(self:GetMoveAnim())
	local stop_anim = string.match(move_anim, "(.*_Combat%a*).*")
	if stop_anim then
		stop_anim = self:GetRandomAnim(stop_anim .. "Stop")
	end
	if not stop_anim or not IsValidAnim(self, stop_anim) then
		return false
	end

	local moments = self:GetAnimMoments(stop_anim)
	moments = table.ifilter(moments, function(_, m) return m.Type == "FootLeft" or m.Type == "FootRight" end)
	if #moments == 0 then
		print("once", string.format('missing "FootLeft" and "FootRight" moments in anim %s for %s (%s)', stop_anim, self.unitdatadef_id, self:GetEntity()))
	end

	local cur_anim = GetStateName(self:GetAnim(1))
	local cur_phase = self:GetAnimPhase(1)
	local has_moment1, t1 = self:IterateMoments(cur_anim, cur_phase, 1, "FootLeft", false, true)
	local has_moment2, t2 = self:IterateMoments(cur_anim, cur_phase, 1, "FootRight", false, true)
	if not has_moment1 or not has_moment2 then
		t1 = false
		t2 = false
	end

	local next_moment_type, prc
	if not t1 or not t2 or t1 == t2 or #moments < 2 then
		prc = 0
	elseif t1 < t2 then
		next_moment_type = "FootLeft"
		prc = MulDivRound(t1, 1000, t2 - t1)
	else
		next_moment_type = "FootRight"
		prc = MulDivRound(t2, 1000, t1 - t2)
	end

	local dist_to_stop = 0
	local stop_pos = self:GetPos()
	for i = #path, 1, -1 do
		local p2 = point(point_unpack(path[i]))
		dist_to_stop = dist_to_stop + stop_pos:Dist2D(p2)
		stop_pos = p2
	end
	local duration = GetAnimDuration(self:GetEntity(), stop_anim)
	local start_idx = (not next_moment_type or moments[1].Type == next_moment_type) and 1 or 2
	local step = next_moment_type and 2 or 1
	local best_phase, best_value
	for i = start_idx, #moments, step do
		local phase = moments[i].Time
		if prc > 0 then
			local d = i == 1 and moments[2].Time - phase or phase - moments[i-1].Time
			phase = phase - MulDivRound(d, prc, 1000)
		end
		if phase >= 0 then
			local len = self:GetStepVector(stop_anim, 0, phase, duration - phase):Len2D()
			local value = abs(len - dist_to_stop)
			if not best_value or value < best_value then
				best_phase = phase
				best_value = value
			end
		end
	end
	self:SetAnimChannel(1, stop_anim, 0, -1, 100, const.StopAnimCrossfadeTime)
	self:SetAnimPhase(1, best_phase or 0)
	self:Face(stop_pos, 200)
	return dist_to_stop
end

---
--- Teleports the unit to the specified position and orientation.
---
--- @param pos table|nil The position to teleport the unit to. If `nil`, the unit will be teleported to the nearest passable slab or snapped to the nearest voxel.
--- @param angle number|nil The orientation angle to set the unit to. If `nil`, the orientation will be calculated based on the new position.
---
--- @return nil
function Unit:Teleport(pos, angle)
	self:LeaveEmplacement(true)
	self:HolsterBombardWeapon()
	self.return_pos = false
	if not pos then
		pos = pos or GetPassSlab(self) or SnapToVoxel(self:GetPos())
	end
	self:SetPos(pos)
	if self:IsDead() then
		self:SetFootPlant(true, 0)
	else
		Msg("UnitAnyMovementStart", self)
		local orientation_angle = self:GetPosOrientation(pos, angle, self.stance, true, true)
		local base_idle = self:GetIdleBaseAnim()
		self:SetRandomAnim(base_idle, 0, 0, true)
		self:SetOrientationAngle(orientation_angle, 0)
		self:SetFootPlant(true, 0)
		self:SetTargetDummy(pos, orientation_angle, base_idle, 0)
		CombatPathReset(self)
		self:ProvokeOpportunityAttacks(CombatActions.Move, "move")
		Msg("UnitMovementDone", self)
		RedeploymentCheckDelayed()
	end
end

---
--- Updates the move animation for the unit based on the specified move style.
---
--- @param move_style_id string|nil The ID of the move style to use. If `nil`, the current move style will be used.
--- @param next_pt table|nil The next waypoint in the unit's path.
---
--- @return boolean `true` if the move animation was successfully updated, `false` otherwise.
---
function Unit:UpdateMoveAnimFromStyle(move_style_id, next_pt)
	move_style_id = move_style_id or self.cur_move_style
	local move_style = GetAnimationStyle(self, move_style_id)
	if not move_style then
		return false
	end
	local anim, rotation_time
	if self:GetStepLength() == 0 then
		if next_pt and (move_style.MoveStart_Left or "") ~= "" and (move_style.MoveStart_Right or "") ~= "" then
			local start_angle = self:GetVisualOrientationAngle()
			local angle = CalcOrientation(self, next_pt)
			local angle_diff = AngleDiff(angle, start_angle)
			if abs(angle_diff) >= 30*60 then
				local rotate_anim = angle_diff < 0 and move_style.MoveStart_Left or move_style.MoveStart_Right
				if rotate_anim and IsValidAnim(self, rotate_anim) then
					anim = rotate_anim
					rotation_time = GetAnimDuration(self:GetEntity(), anim)
				end
			end
		end
		if not anim and move_style.MoveStart and IsValidAnim(self, move_style.MoveStart) then
			anim = move_style.MoveStart
		end
	end
	if not anim then
		anim = self:GetStateText()
		if self:GetAnimPhase() == 0 or self:IsAnimEnd() or not move_style:HasMoveAnim(anim) then
			anim = move_style:GetRandomMoveAnim(self)
			if not anim or not IsValidAnim(self, anim) then
				local msg = string.format('Missing animation style "%s - %s" animation "%s". Gender: "%s". Entity: "%s". Appearance: %s', move_style.group, move_style.Name, anim or "", self.gender, self:GetEntity(), self.Appearance or "false")
				StoreErrorSource(self, msg)
				return false
			end
		end
	end
	if self:GetStepLength(anim) == 0 then
		local msg = string.format('Animation step is ziro! animation "%s". Entity: "%s"', anim or "", self:GetEntity())
		StoreErrorSource(self, msg)
		return false
	end
	self:SetMoveAnim(anim)
	self:SetRotationTime(rotation_time or 0)
	self:SetMoveTurnAnim(nil, nil)
	self:ChangePathFlags(const.pfAnimEnd)
	if (move_style.StepFX or "") ~= "" then
		self.move_step_fx = move_style.StepFX
	else
		if string.match(move_style.VariationGroup, "Run") then
			self.move_step_fx = "StepRun"
		else
			self.move_step_fx = "StepWalk"
		end
	end
	self.move_stop_anim_len = 0
	self.move_stop_foot_left_anim = false
	self.move_stop_foot_right_anim = false
	if (move_style.MoveStop_FootLeft or "") ~= "" and IsValidAnim(self, move_style.MoveStop_FootLeft) then
		self.move_stop_anim_len = self:GetStepLength(move_style.MoveStop_FootLeft)
		self.move_stop_foot_left_anim = move_style.MoveStop_FootLeft
		if (move_style.MoveStop_FootRight or "") ~= "" and IsValidAnim(self, move_style.MoveStop_FootRight) then
			self.move_stop_foot_right_anim = move_style.MoveStop_FootRight
		else
			self.move_stop_foot_right_anim = self.move_stop_foot_left_anim
		end
	end
	return true
end

--- Updates the move animation for the unit.
---
--- This function is responsible for determining the appropriate move animation for the unit based on various factors such as the unit's species, stance, and whether it is in combat. It also sets the move speed and other related properties.
---
--- @param action_id string The action ID that triggered the move animation update.
--- @param anim_type string The type of animation to use (e.g. "Run", "Walk", "WalkSlow").
--- @param next_pt table The next path point the unit is moving towards.
--- @return boolean True if the move animation was successfully updated, false otherwise.
function Unit:UpdateMoveAnim(action_id, anim_type, next_pt)
	if IsRealTimeThread() then
		--this func does interact rands
		--it is called in a rt when loading session data due to cascade onsetwhatevers
		--seems safe to ignore such calls, in fact it also asserts when called like that ->
		--turn_l and turn_r remain nil when move_anim doesn't
		return
	end
	NetUpdateHash("Unit:UpdateMoveAnim", action_id, anim_type, next_pt)
	local use_combat_anims
	self.cur_move_style = false
	if g_Combat and self:IsAware() then
		use_combat_anims = true
	elseif self.species == "Human" then
		local move_style = self:GetCommandParam("move_style")
		if not move_style then
			if self:IsVisiting() then
				move_style = self:GetDefaultMoveStyle()
			elseif not move_style and const.MercWalkStyle and self:IsMerc() then
				move_style = const.MercWalkStyle
				if type(move_style) ~= "string" or not GetAnimationStyle(self, move_style) then
					move_style = self:GetDefaultMoveStyle()
				end
			end
		end
		if move_style and self:UpdateMoveAnimFromStyle(move_style, next_pt) then
			self.cur_move_style = move_style
		end
	end
	NetUpdateHash("Unit:UpdateMoveAnim01", self.cur_move_style)
	if not self.cur_move_style or self.carry_flare then
		self:ChangePathFlags(0, const.pfAnimEnd)
		-- anim_type can be: Run, Walk, WalkSlow
		anim_type = anim_type or self:GetCommandParam("move_anim")
		local move_anim, turn_l, turn_r
		if self.species ~= "Human" then
			if anim_type ~= "Run" and use_combat_anims and g_Combat then
				anim_type = "Run"
			end
			move_anim = anim_type == "Run" and "run" or "walk"
			if IsValidAnim(self, move_anim) then
				NetUpdateHash("Unit:UpdateMoveAnim0", move_anim)
				move_anim = self:GetRandomAnim(move_anim)
			end
			if self.species == "Crocodile" or self.species == "Hyena" then
				if anim_type == "Run" then
					turn_l, turn_r = "run_Turn_L", "run_Turn_R"
				else
					turn_l, turn_r = "walk_Turn_L", "walk_Turn_R"
				end
			end
		elseif self.carry_flare then
			move_anim = "nw_Standing_Patrol_Flare"
			anim_type = "Walk"
		elseif use_combat_anims then
			local prefix = self:GetWeaponAnimPrefix()
			if action_id == "Charge" and prefix == "mk_" then
				local weapon, weapon2 = self:GetActiveWeapons()
				if IsKindOf(weapon, "MacheteWeapon") then
					move_anim = "mk_Standing_Machete_Run"
					anim_type = "Run"
				end
			end
			if not move_anim or not IsValidAnim(self, move_anim) then
				if self.stance == "Standing" then
					if anim_type == "Run" then
						move_anim = string.format("%sStanding_CombatRun", prefix)
					elseif anim_type == "Walk" or anim_type == "WalkSlow" then
						move_anim = string.format("%sStanding_CombatWalk", prefix)
					end
				elseif self.stance == "Crouch" then
					move_anim = string.format("%sStanding_CombatWalk", prefix)
					anim_type = "Walk"
				end
			end
			if move_anim and IsValidAnim(self, move_anim) then
				local cur_anim = self:GetStateText()
				NetUpdateHash("Unit:UpdateMoveAnim1", cur_anim, move_anim, IsAnimVariant(cur_anim, move_anim))
				move_anim = IsAnimVariant(cur_anim, move_anim) and cur_anim or self:GetRandomAnim(move_anim)
			end
		end
		if not move_anim or not IsValidAnim(self, move_anim) then
			local default_walk_style = (use_combat_anims or IsMerc(self) or self.stance ~= "Standing") and "Run" or "Walk"
			if not anim_type or (anim_type == "Walk" or anim_type == "WalkSlow") and self.stance ~= "Standing" then
				anim_type = default_walk_style
			end
			move_anim = self:GetActionBaseAnim(anim_type or default_walk_style, self.stance)
			if not move_anim and anim_type ~= default_walk_style then
				move_anim = self:GetActionBaseAnim(default_walk_style, "Standing")
			end
			if move_anim and (not self.behavior or RandomWalkAnimBehaviors[self.behavior]) then
				local cur_anim = self:GetStateText()
				NetUpdateHash("Unit:UpdateMoveAnim1", cur_anim, move_anim, IsAnimVariant(cur_anim, move_anim))
				move_anim = IsAnimVariant(cur_anim, move_anim) and cur_anim or self:GetRandomAnim(move_anim)
			end
		end
		self.move_step_fx =
			self.stance == "Prone" and "StepRunProne" or
			self.stance == "Crouch" and "StepRunCrouch" or
			anim_type == "Run" and "StepRun" or "StepWalk"
		local base_idle = self:GetIdleBaseAnim()
		self:SetMoveAnim(move_anim or self:GetIdleBaseAnim())
		self:SetRotationTime(0)
		self:SetMoveTurnAnim(turn_l, turn_r)
	end
	self:SetWaitAnim(self:GetIdleBaseAnim())
	self:UpdateMoveSpeed()
	self:UpdatePFClass()
end

--- Returns the default move style for the unit.
---
--- If the unit is carrying a flare, a random flare animation style is returned.
--- Otherwise, if the unit doesn't have a default move style set, a random move style is selected and stored as the default.
---
--- @return string The default move style for the unit.
function Unit:GetDefaultMoveStyle()
	if self.carry_flare then
		return GetRandomAnimationStyle(self, "Flare")
	end
	if not self.default_move_style then
		local style = self:GetRandomMoveStyle()
		if style then
			self.default_move_style = style.Name
		end
	end
	return self.default_move_style
end

---
--- Calculates the move speed modifier for the unit based on various factors such as water terrain, hidden status, and command parameters.
---
--- @return number The move speed modifier for the unit.
function Unit:CalcMoveSpeedModifier()
	local modifier = 1000
	if terrain.GetPassType(self:GetVisualPosXYZ()) == pathfind_water_pass_type_idx then
		modifier = modifier + 10 * Presets.ConstDef["Action Point Costs"].WaterMoveSpeedModifier.value
	end
	if self:HasStatusEffect("Hidden") then 
		modifier = MulDivRound(modifier, 700, 1000)
	end
	local command_move_speed_modifier = self:GetCommandParam("move_speed_modifier")
	if command_move_speed_modifier then
		modifier = MulDivRound(modifier, command_move_speed_modifier, 1000)
	end
	return modifier
end

---
--- Updates the move speed of the unit based on various factors such as water terrain, hidden status, and command parameters.
---
--- @param self Unit The unit object.
--- @return nil
function Unit:UpdateMoveSpeed()
	local modifier = self:CalcMoveSpeedModifier()
	local speed
	if not g_Combat and self:IsMerc() then
		local move_anim = GetStateName(self:GetMoveAnim())
		local is_running = string.match(move_anim, ".*Run.*") and true or false
		if is_running then
			-- fixed speed for mercs
			if self.stance == "Standing" then
				speed = const.UnitMoveSpeed.MercStandingStance
			elseif self.stance == "Crouch" then
				speed = const.UnitMoveSpeed.MercCrouchStance
			elseif self.stance == "Prone" then
				speed = const.UnitMoveSpeed.MercProneStance
			end
		else
			if self.stance == "Standing" then
				speed = const.UnitMoveSpeed.MercWalk
			end
		end
	end
	if speed then
		local mod = MulDivRound(modifier, self:GetAnimSpeedModifier(), 1000)
		speed = MulDivRound(speed, mod, 1000)
		self:SetSpeed(speed)
	else
		self:SetMoveSpeed(modifier)
	end
	-- debug set speed on zero speed animations
	if self:GetSpeed() == 0 then
		self:SetSpeed(self.fallback_walk_speed)
	end
end

---
--- Updates the visual effect for the unit when it is in water terrain.
---
--- If the unit is not dead and the terrain under the unit's visual position is water, the "UnitInWater" FX is played. Otherwise, the "UnitInWater" FX is stopped.
---
--- @param self Unit The unit object.
--- @return nil
function Unit:UpdateInWaterFX()
	local fx_in_water = not self:IsDead() and terrain.GetPassType(self:GetVisualPosXYZ()) == pathfind_water_pass_type_idx
	if self.fx_in_water ~= fx_in_water then
		if fx_in_water then
			PlayFX("UnitInWater", "start", self)
		else
			PlayFX("UnitInWater", "end", self)
		end
		self.fx_in_water = fx_in_water
	end
end

---
--- Starts the movement of the unit.
---
--- Sets the `is_moving` flag to `true` and places a wind modifier trail for the unit, unless the unit's team is neutral and the engine options are set to "Low" object detail.
---
--- @param self Unit The unit object.
--- @return nil
function Unit:StartMoving()
	self.is_moving = true
	local team = self.team
	if not (team and team.neutral and EngineOptions.ObjectDetail == "Low") then
		PlaceUnitWindModifierTrail(self)
	end
end

---
--- Stops the movement of the unit.
---
--- Sets the `is_moving` flag to `false` and removes the wind modifier trail for the unit, unless the unit's team is neutral and the engine options are set to "Low" object detail.
---
--- @param self Unit The unit object.
--- @return nil
function Unit:StopMoving()
	self.is_moving = false
	RemoveUnitWindModifierTrail(self)
end

---
--- Returns the movement noise value for the unit based on its stance.
---
--- If the unit's species is "Human", the noise value is retrieved from the "Presets.CombatStance.Default[stance].Noise" table, where "stance" is the unit's current stance. Otherwise, the noise value is retrieved for the "Standing" stance.
---
--- @param self Unit The unit object.
--- @return number The movement noise value for the unit.
function Unit:GetMovementNoise()
	local stance = self.species == "Human" and self.stance or "Standing"
	return Presets.CombatStance.Default[stance].Noise
end

---
--- Interacts with the given tunnel for the unit.
---
--- @param self Unit The unit object.
--- @param tunnel Tunnel The tunnel to interact with.
--- @param quick_play boolean Whether to play the interaction animation quickly.
--- @return boolean Whether the interaction was successful.
function Unit:InteractTunnel(tunnel, quick_play)
	return tunnel:InteractTunnel(self, quick_play)
end

-- collision avoidance. offset pos2 to the right pass cell corner
---
--- Calculates a collision-avoidance position for the tunnel exit.
---
--- Given the start and end positions of a tunnel traversal, this function adjusts the end position to avoid collisions with the tunnel walls. It does this by offsetting the end position to the right, along the cell corner.
---
--- @param pos1 point The start position of the tunnel traversal.
--- @param pos2 point The end position of the tunnel traversal.
--- @return point The adjusted end position to avoid collisions.
function GetTunnelExitCollisionAvoidPos(pos1, pos2)
	local x1, y1, z1 = SnapToVoxel(pos1:xyz())
	local x2, y2, z2 = SnapToVoxel(pos2:xyz())
	if x1 == x2 and y1 == y2 then
		return pos2
	end
	local offset = const.SlabSizeX / 4
	if x1 == x2 then
		if y1 < y2 then
			x2 = x2 - offset
			--y2 = y2 - offset
		elseif y1 > y2 then
			x2 = x2 + offset - 1
			--y2 = y2 + offset - 1
		end
	elseif y1 == y2 then
		if x1 < x2 then
			--x2 = x2 - offset
			y2 = y2 + offset - 1
		elseif x1 > x2 then
			--x2 = x2 + offset - 1
			y2 = y2 - offset
		end
	elseif x1 < x2 then
		if y1 < y2 then
			x2 = x2 - offset
		elseif y1 > y2 then
			y2 = y2 + offset - 1
		end
	elseif x1 > x2 then
		if y1 > y2 then
			x2 = x2 + offset - 1
		elseif y1 < y2 then	
			y2 = y2 - offset
		end
	end
	if z2 then
		z2 = GetVoxelStepZ(x2, y2, z2)
	end
	return point(x2, y2, z2)
end

MapVar("__unit_step_target_dummies", {{phase = 0}})

---
--- Traverses a tunnel between two positions, with optional collision avoidance and quick play mode.
---
--- @param tunnel table The tunnel to traverse.
--- @param pos1 point The start position of the tunnel traversal.
--- @param pos2 point The end position of the tunnel traversal.
--- @param collision_avoidance boolean Whether to enable collision avoidance.
--- @param quick_play boolean Whether to use quick play mode.
--- @param use_stop_anim boolean Whether to use the stop animation.
--- @return boolean Whether the traversal was successful.
function Unit:TraverseTunnel(tunnel, pos1, pos2, collision_avoidance, quick_play, use_stop_anim)
	local tunnel_entrance = tunnel:GetEntrance()
	local tunnel_exit = tunnel:GetExit()
	if not pos1 then
		pos1 = tunnel_entrance
	end
	if not pos2 then
		pos2 = tunnel_exit
	end
	-- check for a dead end way
	local dead_end
	if not g_Combat and (tunnel.tunnel_type & const.TunnelMaskWalk) == 0 then
		local side = self.team and self.team.side
		if side == "player1" or side == "player2" then
			local tunnel_mask = pathfind[self:GetPfClass() + 1].tunnel_mask
			local reverse_tunnel = pf.GetTunnel(tunnel_exit, tunnel_entrance, tunnel_mask)
			if not reverse_tunnel then
				if IsStuckedMercPos(self, pos2) then
					dead_end = true
					if self:IsInterruptable() then
						self:Interrupt()
						return
					end
				end
			end
		end
	end
	if collision_avoidance ~= false and self:GetPathFlags(const.pfmCollisionAvoidance) ~= 0 and terrain.IsPassable(pos2) then
		local pcount = self:GetPathPointCount()
		local next_pos = pcount > 1 and self:GetPathPoint(pcount - 1)
		if next_pos and next_pos:IsValid() and (tunnel.tunnel_type & const.TunnelTypeLadder) == 0 and not CanDestlock(pos2, 300) then
			pos2 = GetTunnelExitCollisionAvoidPos(pos1, pos2) -- offset pos2 to the right pass cell corner
			pf.SetPathPoint(self, -1, pos2) -- the path execution expects the unit to be at the last position of the path
		end
	end
	local interrupts
	if not self.combat_path and self.team and self.team.side ~= "neutral" then
		local target_dummy = __unit_step_target_dummies[1]
		target_dummy.obj = self
		target_dummy.anim = self:GetWaitAnim()
		interrupts = self:CheckProvokeOpportunityAttacks(CombatActions.Move, "move", __unit_step_target_dummies)
		if interrupts then
			self:ProvokeOpportunityAttacksWarning("move", interrupts)
		end
	end
		local wasInterruptable = self.interruptable
		if wasInterruptable then
			self:EndInterruptableMovement()
		end
	if not quick_play and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0 then
		self:TunnelBlock(tunnel_entrance, tunnel_exit)
		self:TunnelBlock(tunnel_exit, tunnel_entrance)
	end
	self.traverse_tunnel = tunnel
	tunnel:TraverseTunnel(self, pos1, pos2, quick_play, use_stop_anim)
	self.traverse_tunnel = false
	if not quick_play and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0 then
		self:TunnelUnblock(tunnel_exit, tunnel_entrance)
		self:TunnelUnblock(tunnel_entrance, tunnel_exit)
	end
	self:SetFootPlant(true)
	if dead_end then
		RedeploymentCheckDelayed()
	end
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
	if interrupts then
		self:ProvokeOpportunityAttacksFromList(interrupts)
	end
end

---
--- Checks if the unit should play the move stop animation based on the remaining path length.
--- If the remaining path length is less than the move stop animation length, the unit will play the stop animation and wait for the remaining time before reaching the destination.
---
--- @param stop_anim_tunnel_idx number|nil The index of the tunnel where the stop animation should be played. If not provided, the function will try to find the appropriate tunnel index.
--- @return boolean true if the stop animation was played, false otherwise.
---
function Unit:GotoStopCheck(stop_anim_tunnel_idx)
	if self.move_stop_anim_len == 0 then
		return false
	end
	if not stop_anim_tunnel_idx then
		stop_anim_tunnel_idx = pf.GetPathNextTunnelIdx(self, const.TunnelMaskWalkStopAnim) or 1
	end
	local pcount = self:GetPathPointCount()
	if pcount <= stop_anim_tunnel_idx + 4 then
		local pathlen = self:GetPathLen(stop_anim_tunnel_idx)
		local step_dist = self:GetVisualDist2D(self:GetPosXYZ()) 
		if pathlen - step_dist < self.move_stop_anim_len then
			local dest = self:GetPathPoint(stop_anim_tunnel_idx)
			if dest and not dest:IsValid() then
				stop_anim_tunnel_idx = stop_anim_tunnel_idx - 1
				dest = self:GetPathPoint(stop_anim_tunnel_idx)
			end
			if not dest or not dest:IsValid() then
				return false
			end
			-- clear path points before dest
			for i = self:GetPathPointCount(), stop_anim_tunnel_idx + 1, -1 do
				pf.SetPathPoint(self, i)
			end
			local wait_time = pathlen > self.move_stop_anim_len and pf.GetMoveTime(self, pathlen - self.move_stop_anim_len) or 0
			if wait_time > 0 then
				Sleep(wait_time)
			end
			self:GotoStop(dest)
			return true
		end
	end
	return false
end

---
--- Moves the unit to the specified destination and plays the appropriate stop animation.
---
--- @param dest Vector3|nil The destination position. If not provided, the unit will stop at its current position.
---
function Unit:GotoStop(dest)
	local l1 = self:TimeToMoment(1, "FootLeft", -1)
	local l2 = self:TimeToMoment(1, "FootLeft", 1)
	local r1 = self:TimeToMoment(1, "FootRight", -1)
	local r2 = self:TimeToMoment(1, "FootRight", 1)
	local t1, t2, anim, anim1, anim2
	if l1 and (not r1 or l1 < r1) then
		t1, anim1 = l1, self.move_stop_foot_left_anim
	else
		t1, anim1 = r1, self.move_stop_foot_right_anim
	end
	if l2 and (not r2 or l2 < r2) then
		t2, anim2 = l2, self.move_stop_foot_left_anim
	else
		t2, anim2 = r2, self.move_stop_foot_right_anim
	end
	if t1 and t2 then
		local t = t1 + t2
		local perc = t > 0 and t1 * 100 / t or 0
		if perc < const.AmbientLife.WalkStopMomentProximity then
			anim = anim1
		else
			anim = anim2
		end
	elseif t1 then
		anim = anim1
	else
		anim = anim2
	end
	anim = anim or self.move_stop_foot_left_anim or self.move_stop_foot_right_anim
	self:SetState(anim)
	repeat
		self:SetAnimSpeed(1, self:GetMoveSpeed())
		local t = self:TimeToAnimEnd()
		self:SetPos(dest or self:GetPos(), t)
	until not WaitWakeup(t)
end

---
--- Puts the unit to sleep for the specified time, waiting until the end of the animation or the path is dirty.
---
--- @param time number The time in seconds to sleep.
---
function Unit:MoveSleep(time)
	local end_time = now() + time
	repeat until not WaitWakeup(end_time - now()) or self:GetPathFlags(const.pfDirty) ~= 0
	if self.cur_move_style and (self:GetAnimPhase() == 0 or self:IsAnimEnd()) then
		self:UpdateMoveAnimFromStyle()
	end
end

---
--- Rotates the unit to face the next position, if necessary.
---
--- If the unit has a move style that includes a turn animation, the turn animation will be played instead of a direct rotation.
--- If the unit is visiting a location, no rotation is performed.
--- If the unit is in a prone stance, the rotation will only occur if the angle difference is greater than the specified minimum turn angle.
---
--- @param next_pos table The next position the unit should face.
---
function Unit:GotoTurnOnPlace(next_pos)
	if not next_pos then
		return
	end
	local move_style = GetAnimationStyle(self, self.cur_move_style)
	if move_style then
		if move_style.MoveStart_Left or move_style.MoveStart_Right then
			return -- move turn animations will be played if necessary
		end
		local angle = CalcOrientation(self, next_pos)
		self:AnimatedRotation(angle)
		return
	end
	if self:IsVisiting() then
		return -- move style support civilian
	end
	if self.stance ~= "Prone" then
		return
	end
	local angle = CalcOrientation(self, next_pos)
	local angle_diff = AngleDiff(angle, self:GetVisualOrientationAngle())
	local min_turn_angle
	if self:GetState() == self:GetMoveAnim() then
		min_turn_angle = const.GotoTurnOnPlaceMovingAngle
	else
		min_turn_angle = const.GotoTurnOnPlaceAngle
	end
	if abs(angle_diff) > min_turn_angle then
		self:AnimatedRotation(angle)
	end
end

DefineConstInt("AmbientLife", "ForbidVisitEnemyDist", 2, "m", "If player around this distance the enemy AL won't use chairs to sit(coming close will also interrupt this behavior normally)")

---
--- Determines if the unit should be idle based on the distance to another unit.
---
--- If the unit is waiting to attack, it should be idle.
--- If the unit is sitting in a chair and the other unit is within a certain distance, it should be idle.
--- If the unit is wall leaning and the other unit is within a certain distance, it should be idle.
--- If the unit is in "Ambient" or "Patrol" routine and the other unit is within a certain distance, it should be idle.
---
--- @param other Unit The other unit to check the distance against.
--- @return boolean Whether the unit should be idle.
---
function Unit:IdleForcingDist(other)
	if self.waiting_attack then return true end
	
	local dist = self:GetDist(other)
	if dist <= const.AmbientLife.ForbidSitChairEnemyDist and IsSittingUnit(self) then
		return true
	end
	if dist <= const.AmbientLife.ForbidWallLeanEnemyDist and IsWallLeaningUnit(self) then
		return true
	end
	if dist <= const.AmbientLife.ForbidVisitEnemyDist and (self.routine == "Ambient" or self.routine == "Patrol") then
		return true
	end
end

---
--- Determines if the unit should be idle based on the distance to another unit.
---
--- If the unit is waiting to attack, it should be idle.
--- If the unit is sitting in a chair and the other unit is within a certain distance, it should be idle.
--- If the unit is wall leaning and the other unit is within a certain distance, it should be idle.
--- If the unit is in "Ambient" or "Patrol" routine and the other unit is within a certain distance, it should be idle.
---
--- @param other Unit The other unit to check the distance against.
--- @return boolean Whether the unit should be idle.
---
function Unit:ShouldBeIdle(other)
	if self.command == "Die" or self.command == "Dead" then return false end
	
	if g_Combat or GameState.sync_loading or self.team and self.team.player_team then
		return true
	end
	if not g_Combat and (self.neutral_retal_attacked) then
		return true
	end
	if not IsValid(other) then
		local enemies = GetAllEnemyUnits(self)
		for _, unit in ipairs(enemies) do
			if self:ShouldBeIdle(unit) then
				return true
			end
		end
	else
		if self:IdleForcingDist(other) then
			return true
		end
	end
end

---
--- Handles the logic for the unit's "GotoAction" behavior.
---
--- This function performs the following tasks:
--- - Resets the voxel stealth parameters cache if the unit is carrying a flare.
--- - Invalidates the pindown lines cache.
--- - If the unit has the "Suspicious" status effect and is not in combat, it sets the unit's command to "Idle".
--- - If the unit has a "goto_stance", it calls the "GotoChangeStance" function to change the unit's stance.
--- - If the unit has a "goto_hide" flag, it hides the unit.
--- - For each enemy unit, it checks if the enemy unit should be idle based on the distance to the current unit. If so, it sets the enemy unit's command to "Idle".
--- - For each enemy unit, it checks if the current unit should be idle based on the distance to the enemy unit. If so, it sets the current unit's command to "Idle".
--- - If the current unit and an enemy unit have marked each other as targets for a melee attack, it attempts to start the attack action.
---
function Unit:GotoAction()
	if self.carry_flare then
		ResetVoxelStealthParamsCache() -- todo: partial invalidate would be cool (prev pos + current pos)
	end
	
	self:InvalidatePindownLinesCache()
	
	if not g_Combat and self:HasStatusEffect("Suspicious") then
		self:SetCommand("Idle")
		return
	end
	
	if self.goto_stance then
		self:GotoChangeStance(self.goto_stance)
		self.goto_stance = false
		if self:IsInterruptable() then
			self:BeginInterruptableMovement()
		end
	end
	if self.goto_hide then
		self.goto_hide = false
		self:Hide()
		if self:IsInterruptable() then
			self:BeginInterruptableMovement()
		end
	end	

	if self.team then
		local enemies = GetAllEnemyUnits(self)
		if self.team.player_team then	
			for _, unit in ipairs(enemies) do
				if unit:ShouldBeIdle(self) then
					unit:SetCommandParamValue("Idle", "idle_forcing_dist", self)
					unit:SetCommand("Idle")
				end
			end
		end
		if self.team.player_enemy then
			for _, unit in ipairs(enemies) do
				if self:ShouldBeIdle(unit) then
					self:SetCommandParamValue("Idle", "idle_forcing_dist", unit)
					self:SetCommand("Idle")
				end
			end
		end
		for _, enemy in ipairs(enemies) do
			local attacker, target
			if self.marked_target_attack_args and self.marked_target_attack_args.target == enemy then
				attacker, target = self, enemy
			elseif enemy.marked_target_attack_args and enemy.marked_target_attack_args.target == self then
				attacker, target = enemy, self
			end
			if attacker and target then
				local action = attacker:GetDefaultAttackAction()
				local weapon = action:GetAttackWeapons(attacker)
				if not IsKindOfClasses(weapon, "MeleeWeapon", "UnarmedWeapon") then
					attacker.marked_target_attack_args = nil
				elseif attacker:CanAttack(target, weapon, action) and IsMeleeRangeTarget(attacker, nil, nil, target) then
					local args = attacker.marked_target_attack_args
					TutorialHintsState.SneakMode = not not args
					TutorialHintsState.SneakApproach = not not args
					NetStartCombatAction(action.id, attacker, 0, args)
					break
				end
			end
		end
	end	
end

---
--- Waits for the game to be resumed before executing the queued action visual.
--- If a queued action visual exists, it is destroyed. If the unit has a prepared attack
--- and the game is paused, the prepared attack is interrupted.
---
--- @param self Unit
--- @return nil
---
function Unit:WaitResumeOnCommandStart()
	if not GameTimeAdvanced then return end
	if IsValid(self.queued_action_visual) then
		DoneObject(self.queued_action_visual)
		self.queued_action_visual = false
	end
	if not g_Combat and IsActivePaused() and self:HasPreparedAttack() then
		self:InterruptPreparedAttack()
	end
	while not g_Combat and IsActivePaused() do
		WaitMsg("Resume", 500)
	end	
end

local pfFinished = const.pfFinished
local pfFailed = const.pfFailed
local pfDestLocked = const.pfDestLocked
local pfTunnel = const.pfTunnel
local gofRealTimeAnimMask = const.gofRealTimeAnim | const.gofEditorSelection

---
--- Moves the unit to the specified position, handling various scenarios like tunnels, following targets, and interruptions.
---
--- @param pos table|point The destination position or a table of positions to follow.
--- @param distance number The maximum distance to the destination.
--- @param min_distance number The minimum distance to the destination.
--- @param move_anim_type string The type of move animation to use.
--- @param follow_target Unit The target to follow.
--- @param use_stop_anim boolean Whether to use the stop animation.
--- @param interrupted boolean Whether the movement was interrupted.
--- @return boolean True if the movement was successful, false otherwise.
---
function Unit:GotoSlab(pos, distance, min_distance, move_anim_type, follow_target, use_stop_anim, interrupted)
	self:WaitResumeOnCommandStart()
	assert(self:GetGameFlags(gofRealTimeAnimMask) == 0)
	Msg("UnitAnyMovementStart", self)
	if use_stop_anim == nil then
		use_stop_anim = true
	end
	if use_stop_anim ~= false and self.move_stop_anim_len == 0 then
		use_stop_anim = false
	end

	self:SetTargetDummy(false)
	if self:TimeToPosInterpolationEnd() > 0 then
		local cur_pos = self:GetVisualPos()
		if not self:IsValidZ() then
			cur_pos = cur_pos:SetInvalidZ()
		end
		self:SetPos(cur_pos)
	end
	local dest, follow_pos
	if not pos and IsValid(follow_target) then
		dest = self:GetClosestMeleeRangePos(follow_target)
		follow_pos = follow_target:GetPos()
	elseif not pos then
		local tunnel_param = {
			unit = self,
			player_controlled = self.team and self.team:IsPlayerControlled(),
		}
		dest = GetCombatPathDestinations(self, nil, nil, nil, tunnel_param, nil, 2 * const.SlabSizeX, false, false, true)
		for i, packed_pos in ipairs(dest) do
			dest[i] = point(point_unpack(packed_pos))
		end
	elseif IsPoint(pos) then
		if self:GetPathFlags(const.pfmVoxelAligned) ~= 0 then
			dest = self:GetVoxelSnapPos(pos)
		end
	elseif self:GetPathFlags(const.pfmVoxelAligned) ~= 0 then
		for i = 1, #pos do
			local pt = self:GetVoxelSnapPos(pos[i])
			if pt then
				dest = dest or {}
				table.insert_unique(dest, pt)
			end
		end
	end
	dest = dest or pos

	local status = self:FindPath(dest, distance, min_distance)
	if self:GetPathPointCount() == 0 then
		if status == 0 then
			return true
		end
		return
	end

	-- cleanup stuff that prevents moving
	if self:HasStatusEffect("StationedMachineGun") then
		self:MGPack()
	elseif self:HasStatusEffect("ManningEmplacement") then
		self:LeaveEmplacement()
	elseif self:HasPreparedAttack() then
		self:InterruptPreparedAttack()
	end

	-- the target used for opportunity attacks
	self:SetTargetDummy(false)
	self:SetActionInterruptCallback(function(self)
		if not IsActivePaused() then
			self:SetCommand("GotoSlab")
		else
			self:SetQueuedAction()
			self:SetCommand("Idle")
		end
	end)
	self.goto_interrupted = interrupted
	self:PushDestructor(function(self)
		self:SetActionInterruptCallback()
		self.move_follow_target = nil
		self.move_follow_dest = nil
		self.goto_interrupted = nil
	end)
	self.move_follow_target = follow_target
	self.move_follow_dest = dest

	self:SetFootPlant(true)

	self.goto_target = pos

	local pfStep = self.Step
	local pfSleep = self.MoveSleep

	local target, target_time
	local is_moving = false

	Msg("UnitGoToStart", self)
	while true do
		self:TunnelsUnblock()
		if follow_pos and IsValid(follow_target) then
			if IsKindOf(follow_target.traverse_tunnel, "SlabTunnelLadder") then
				follow_target = false
				break
			end
			if follow_target:GetDist(follow_pos) > 0 then
				dest = self:GetClosestMeleeRangePos(follow_target)
				target = false
				follow_pos = follow_target:GetPos()
				self.move_follow_dest = dest
			end
		end
		if not target or self:GetPathPointCount() == 0 then
			status = self:FindPath(dest, distance, min_distance)
			if self:GetPathPointCount() == 0 then
				if status == 0 then
					status = pfFinished
				end
				break
			end
			local tunnel_start_idx = pf.GetPathNextTunnelIdx(self, const.TunnelMaskTraverseWait)
			if tunnel_start_idx then
				local tunnel_entrance = pf.GetPathPoint(self, tunnel_start_idx)
				local tunnel_exit = pf.GetPathPoint(self, tunnel_start_idx - 2)
				local last_target = target or self:GetPos()
				target = nil
				if last_target == tunnel_entrance or type(last_target) == "table" and table.find(last_target, tunnel_entrance) then
					if CanUseTunnel(tunnel_entrance, tunnel_exit, self) then
						self:TunnelBlock(tunnel_entrance, tunnel_exit)
						self:TunnelBlock(tunnel_exit, tunnel_entrance)
						local tunnel_start_idx2 = pf.GetPathNextTunnelIdx(self, const.TunnelMaskTraverseWait, tunnel_start_idx - 2)
						if tunnel_start_idx2 then
							local tunnel_entrance2 = pf.GetPathPoint(self, tunnel_start_idx2)
							local tunnel_exit2 = pf.GetPathPoint(self, tunnel_start_idx2 - 2)
							target = GetAlternateRoutesStartPoints(self, tunnel_entrance2, tunnel_exit2, const.TunnelMaskTraverseWait)
						else
							target = dest
						end
					end
				end
				if not target then
					target = GetAlternateRoutesStartPoints(self, tunnel_entrance, tunnel_exit, const.TunnelMaskTraverseWait)
				end
			elseif target ~= dest then
				target = dest
			end
			target_time = now()
			if target ~= dest then
				self:FindPath(target)
			end
			local pcount = self:GetPathPointCount()
			local next_pt = pcount > 1 and pf.GetPathPoint(self, pcount - 1) or nil
			if next_pt and not next_pt:IsValid() then
				next_pt = pcount > 2 and pf.GetPathPoint(self, pcount - 2) or nil
			end
			local angle = next_pt and CalcOrientation(self.target_dummy or self, next_pt)
			self:UpdateMoveAnim(nil, move_anim_type, next_pt)
			local move_anim = GetStateName(self:GetMoveAnim())
			if not GameTimeAdvanced then
				if next_pt then
					self:Face(next_pt)
				end
				if self:GetStateText() ~= move_anim then
					self:SetState(move_anim, 0, 0)
					self:RandomizeAnimPhase()
				end
			else
				self:PlayTransitionAnims(move_anim, angle)
				self:GotoTurnOnPlace(next_pt) -- face next target point
			end
		end
		local target_distance, target_min_distance
		if target == dest then
			target_distance = distance
			target_min_distance = min_distance
		else
			-- approaching tunnel. the tunnel can be destlocked, so the unit should destlock and wait
		end
		local wait
		status = pfStep(self, target, target_distance, target_min_distance)
		if status > 0 then
			if not is_moving then
				is_moving = true
				self:StartMoving()
			end
			while status > 0 do
				if not use_stop_anim or not self:GotoStopCheck() then
					pfSleep(self, status)
				end
				self:GotoAction()
				if follow_pos and IsValid(follow_target) and not follow_target:IsEqualPos(follow_pos) then
					if IsKindOf(follow_target.traverse_tunnel, "SlabTunnelLadder") then
						status = pfFinished
						dest = self:GetPos()
						target = dest
						break
					end
					local newdest = self:GetClosestMeleeRangePos(follow_target)
					if newdest ~= dest then
						dest = newdest
						target = newdest
					end
				end
				status = pfStep(self, target, target_distance, target_min_distance)
			end
		end
		if status == pfFinished and target == dest then
			break
		elseif status == pfFinished and target_time ~= now() then
			target = nil
		elseif status == pfTunnel then
			if IsActivePaused() then
				Sleep(1)
			end
			self:ClearEnumFlags(const.efResting) -- resting flag block the later ClearPath()
			local tunnel = pf.GetTunnel(self)
			if not tunnel then
				status = pfFailed
				break
			end
			if not self:InteractTunnel(tunnel) then
				status = pfFailed
				break
			end
			if not IsValid(tunnel) then
				tunnel = pf.GetTunnel(self)
			end
			local tunnel_in_use = IsValid(tunnel) and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0
				and not CanUseTunnel(tunnel:GetEntrance(), tunnel:GetExit(), self)
			if IsValid(tunnel) and not tunnel_in_use then
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				local use_stop_anim = self.move_stop_anim_len > 0 and (pf.GetPathNextTunnelIdx(self, const.TunnelMaskWalkStopAnim) or 1) == self:GetPathPointCount()
				self:TraverseTunnel(tunnel, nil, nil, true, false, use_stop_anim)
				self:GotoAction()
			else
				target = nil -- the path is invalid, a new one should be cast
				wait = tunnel_in_use
			end
		elseif target ~= dest then
			wait = true
		else
			break
		end
		if wait then
			local anim = self:GetWaitAnim()
			if self:GetState() ~= anim then
				self:SetState(anim, const.eKeepComponentTargets)
			end
			local target_pos
			if IsPoint(target) then
				target_pos = target
			elseif IsValid(target) then
				target_pos = target:GetPos()
			else
				for i, p in ipairs(target) do
					if i == 1 or IsCloser(self, p, target_pos) then
						target_pos = p
					end
				end
			end
			if target_pos and not self:IsEqualPos2D(target_pos) then
				self:Face(target_pos)
			end
			if is_moving then
				is_moving = false
				self:StopMoving()
			end
			self:ClearPath()
			pfSleep(self, 200)
			self:GotoAction()
		end
	end

	self:PopAndCallDestructor()
	self.goto_target = false
	if is_moving then
		self:StopMoving()
	end
	Msg("UnitMovementDone", self)
	Msg("UnitGoTo", self)
	ObjModified(self)
	return status == pfFinished
end

---
--- Performs an uninterruptable goto movement for the unit.
---
--- @param pos Vector3 The target position for the unit to move to.
--- @param straight_line boolean If true, the unit will move in a straight line to the target position.
---
function Unit:UninterruptableGoto(pos, straight_line)
	self:WaitResumeOnCommandStart()
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	pos = self:GetVoxelSnapPos(pos) or pos
	assert(not self.goto_target) -- should be a top level Goto
	self.goto_target = pos
	self:UpdateMoveAnim()
	if straight_line then
		self:Goto(pos, "sl")
	else
		self:Goto(pos)
	end
	self.goto_target = false
	Msg("UnitMovementDone", self)
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

---
--- Performs a single step of the unit's movement.
---
--- @param ... Any additional arguments to pass to the underlying movement function.
--- @return number The status of the movement step.
---
function Unit:Step(...)
	self:UpdateMoveSpeed()
	local status = AnimMomentHook.Step(self, ...)
	if status > 0 then
		if not self.combat_path and self.team and not self.team.neutral then
			local target_dummy = __unit_step_target_dummies[1]
			target_dummy.obj = self
			target_dummy.anim = self:GetWaitAnim()
			local interrupts = self:CheckProvokeOpportunityAttacks(CombatActions.Move, "move", __unit_step_target_dummies)
			self:ProvokeOpportunityAttacksWarning("move", interrupts)
			self:ProvokeOpportunityAttacks(CombatActions.Move, "move", target_dummy) -- traps
		end
		self:UpdateInWaterFX()
	end
	return status
end

---
--- Performs a goto movement for the unit.
---
--- @param ... Any additional arguments to pass to the underlying movement function.
--- @return boolean True if the movement was successful, false otherwise.
---
function Unit:Goto(...)
	local pfStep = self.Step
	self:SetTargetDummy(false)
	self:UpdateMoveAnim()
	local status = pfStep(self, ...)
	if status >= 0 or status == pfTunnel then
		local topmost_goto, is_moving
		if not self.goto_target then
			topmost_goto = true
			self.goto_target = ...
		end
		local pfSleep = self.MoveSleep
		while true do
			if status > 0 then
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				pfSleep(self, status)
			elseif status == pfTunnel then
				local tunnel = pf.GetTunnel(self)
				if not tunnel then
					status = pfFailed
					break
				end
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				if not self:InteractTunnel(tunnel) then
					status = pfFailed
					break
				end
				if IsValid(tunnel) then
					self:TraverseTunnel(tunnel)
				end
			else
				break
			end
			status = pfStep(self, ...)
		end
		if is_moving then
			self:StopMoving()
		end
		if topmost_goto then
			self.goto_target = false
		end
		CombatPathReset(self)
		ObjModified(self)
	end

	local res = status == pfFinished
	Msg("UnitGoTo", self)
	return res
end

---
--- Determines if the unit is interruptable.
---
--- @param self Unit
--- @return boolean
---
function Unit:IsInterruptable()
	if self.interruptable then
		if not self.goto_stance and not self.goto_hide then
			return true
		end
	end
	if self:IsIdleCommand() or self:HasQueuedAction() then
		return true
	end
	return false
end

---
--- Determines if the unit's movement is interruptable.
---
--- @param self Unit
--- @return boolean
---
function Unit:IsInterruptableMovement()
	return self.interruptable and (self.goto_target or self.move_attack_in_progress)
end

---
--- Interrupts the current command of the unit.
---
--- @param self Unit
--- @param ... any
---
function Unit:InterruptCommand(...)
	self:Interrupt("SetCommand", ...)
end

---
--- Interrupts the current command of the specified unit.
---
--- @param unit Unit The unit to interrupt.
--- @param ... any Additional arguments to pass to the interrupt function.
---
function NetSyncEvents.InterruptCommand(unit, ...)
	unit:InterruptCommand(...)
end

---
--- Sets the action interrupt callback for the unit.
---
--- @param self Unit
--- @param func function The callback function to be called when the unit's action is interrupted.
---
function Unit:SetActionInterruptCallback(func)
	self.action_interrupt_callback = func
end

---
--- Interrupts the current command of the unit.
---
--- @param self Unit
--- @param func function|string The function to call when interrupting the command, or the name of the function to call.
--- @param ... any Additional arguments to pass to the interrupt function.
---
function Unit:Interrupt(func, ...)
	if self:IsInterruptable() then
		if not func and self.action_interrupt_callback then
			func = self.action_interrupt_callback
			self.action_interrupt_callback = false
		end
		if not func then
			return
		end
		if type(func) ~= "function" then
			func = self[func]
		end
		assert(func)
		if func then
			func(self, ...)
		end
		return
	end
	self.interrupt_callback = pack_params(func or false, ...)
end

---
--- Begins an interruptable movement for the unit.
--- This sets the `interruptable` flag to `true` and checks if there is a pending interrupt callback.
--- If there is a pending interrupt callback, it is executed.
---
--- @param self Unit The unit that is beginning the interruptable movement.
---
function Unit:BeginInterruptableMovement()
	self.interruptable = true
	local callback = self.interrupt_callback
	if callback then
		self.interrupt_callback = false
		self:Interrupt(unpack_params(callback))
	end
end

---
--- Ends the interruptable movement for the unit.
--- This sets the `interruptable` flag to `false`.
---
--- @param self Unit The unit that is ending the interruptable movement.
---
function Unit:EndInterruptableMovement()
	self.interruptable = false
end

---
--- Checks if there are any enemies present in the game.
---
--- @return boolean true if there are any enemies present, false otherwise
---
function Unit:IsEnemyPresent()
	if g_Combat then
		return true
	end
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:HasMember("teams") then
		for i, t in ipairs(dlg.teams) do
			if not t.player_ally then
				return true
			end
		end
	end
	return false
end

---
--- Gets the voxel snap position for a unit.
---
--- @param pos table|nil The position to snap to. If nil, the unit's current position is used.
--- @param angle number|nil The orientation angle to use. If nil, the unit's current orientation angle is used.
--- @param stance string|nil The stance to use. If nil, the unit's current stance is used.
--- @return table|nil The snapped position and angle, or nil if the position is invalid.
---
function Unit:GetVoxelSnapPos(pos, angle, stance)
	if pos then
		if not pos:IsValid() then
			return
		end
	elseif not self:IsValidPos() then
		return
	end
	if not angle then
		angle = self:GetOrientationAngle()
	end
	local face_posx, face_posy, face_posz = RotateRadius(const.SlabSizeX, angle, pos or self, true)
	local pos = SnapToPassSlabSegment(pos or self, face_posx, face_posy, face_posz, const.TunnelMaskWalk)
	if not pos then
		return
	end
	if (stance or self.stance) == "Prone" then
		angle = FindProneAngle(self, pos, angle)
	end
	return pos, angle
end

---
--- Gets the grid coordinates for the unit's current position.
---
--- @return number, number, number The grid coordinates (x, y, z) for the unit's current position.
---
function Unit:GetGridCoords()
	local x, y, z = self:GetPosXYZ()
	return PosToGridCoords(x, y, z)
end

---
--- Converts a world position to grid coordinates.
---
--- @param x number The x-coordinate of the world position.
--- @param y number The y-coordinate of the world position.
--- @param z number The z-coordinate of the world position.
--- @return number, number, number The grid coordinates (x, y, z) for the given world position.
---
function PosToGridCoords(x, y, z)
	z = z or terrain.GetHeight(x, y)
	local gx, gy, gz = WorldToVoxel(x, y, z)
	
	while true do
		local wx, wy, wz = VoxelToWorld(gx, gy, gz)
		if wz < z then
			gz = gz + 1
		else
			break
		end
	end	
	return gx, gy, gz
end

---
--- Handles the logic for a unit entering combat.
---
--- This function is called when a unit enters combat. It performs the following actions:
---
--- - Ends any interruptable movement the unit was performing.
--- - Moves the unit to the nearest free slab, unless the unit is manning an emplacement.
--- - Sets the unit's target dummy from its current position.
--- - Updates the unit's attached weapons.
--- - Applies the "Sharp Instincts" perk effect if the unit has it.
--- - Flushes the unit's combat cache and recalculates its UI actions if the unit is manning an emplacement and is the selected object.
--- - Sends a "UnitEnterCombat" message.
--- - Resumes any interruptable movement the unit was performing.
---
--- @param self Unit The unit that is entering combat.
---
function Unit:EnterCombat()
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	if not self:HasStatusEffect("ManningEmplacement") then
		self:UninterruptableGoto(self:GetVisualPos()) -- stop on the nearest free slab
		self:SetTargetDummyFromPos()
	end
	self:UpdateAttachedWeapons()

	if HasPerk(self, "SharpInstincts") then
		if self.stance == "Standing" then self:DoChangeStance("Crouch") end
		self:ApplyTempHitPoints(CharacterEffectDefs.SharpInstincts:ResolveValue("tempHP"))
	end

	if self:HasStatusEffect("ManningEmplacement") and self == SelectedObj then
		self:FlushCombatCache()
		self:RecalcUIActions(true)
		ObjModified("combat_bar")
	end
	Msg("UnitEnterCombat", self)
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

---
--- Automatically reloads the unit's active firearm weapon if it has less than a full magazine.
---
--- This function checks the unit's equipped firearm weapons and their subweapons to find the one with the lowest ammo. If a weapon is found with less than a full magazine, the function will have the unit reload that weapon after a short delay.
---
--- If the unit has no ammo for the weapon, a "NoAmmo" voice response is played. If the unit has low ammo, an "AmmoLow" voice response is played.
---
--- @param self Unit The unit that is reloading its weapon.
---
function Unit:AutoReload()
	local weapon = self:GetActiveWeapons("Firearm")
	local weapons = self:GetEquippedWeapons(self.current_weapon, "Firearm")
	local needs_reload
	local i = 1
	while not needs_reload and (i <= #weapons) do
		local w = weapons[i]
		if w and (w.ammo and w.ammo.Amount or 0) < w.MagazineSize then
			weapon = w
			needs_reload = true
			break
		end
		for slot, sub in sorted_pairs(weapons[i].subweapons) do
			if IsKindOf(sub, "Firearm") then
				weapons[#weapons + 1] = sub
			end
		end
		i = i + 1
	end
	
	--if weapon and (weapon.ammo and weapon.ammo.Amount or 0) < weapon.MagazineSize then
	if needs_reload then
		Sleep(self:Random(1000))
		local _, err = CombatActions.Reload:GetUIState({self})
		if err == AttackDisableReasons.NoAmmo then
			if not weapon.ammo or weapon.ammo.Amount == 0 then
				PlayVoiceResponse(self, "NoAmmo")
			else
				PlayVoiceResponse(self, "AmmoLow")
			end
		else
			RunCombatAction("ReloadMultiSelection", self, 0, {reload_all = true})
		end
	end
end

---
--- Exits the combat state for the unit.
---
--- This function is responsible for handling the various actions and state changes that occur when a unit exits combat. It resets the unit's action points, clears any "performed action this turn" flag, and handles any special behaviors or actions based on the unit's current state.
---
--- If the unit is retreating, it will set a command to exit the map by moving to the nearest entrance marker. If the unit is downed, it will set a "DownedRally" command. If the unit is not dead, it will automatically reload any equipped firearms, leave any emplacement it was using, and potentially change its stance or behavior based on its current state.
---
--- The function also handles some special cases, such as resetting the unit's angle to match its spawner if it is an NPC, and handling any "Bandage" behaviors or "Pindown" states the unit may have been in.
---
--- @param self Unit The unit that is exiting combat.
---
function Unit:ExitCombat()
	if self:IsNPC() and not self.dummy and (not self:IsDead() or self.immortal) then
		if self.retreating then
			local markers = MapGetMarkers("Entrance")
			local nearest, dist
			for _, marker in ipairs(markers) do
				local d = self:GetDist(marker)
				if not nearest or d < dist then
					nearest, dist = marker, d
				end
			end
			assert(nearest)
			self:SetCommand("ExitMap", nearest)
		end
	end
	
	self.ActionPoints = self:GetMaxActionPoints() -- reset AP so the units has all their actions available to initiate combat
	self.performed_action_this_turn = false
	
	if self:IsDowned() then
		self:SetCommand("DownedRally")
	elseif not self:IsDead() then
		self:PushDestructor(function()
			self:AutoReload()
		end)
		
		self:LeaveEmplacement(false, "exit combat")

		if self.combat_behavior == "Bandage" then
			self:EndCombatBandage(nil, "instant")
		elseif self.behavior == "Bandage" then
			self:SetBehavior()
		end
		
		if g_Pindown[self] then
			self:InterruptPreparedAttack()
		end

		if self:IsNPC() then
			if self.spawner then
				local x, y, z = self:GetGridCoords()
				local sx, sy, sz = PosToGridCoords(self.spawner:GetPosXYZ())
				if x == sx and y == sy and z == sz then
					local spawner_angle = self.spawner:GetAngle()
					self:SetAngle(spawner_angle)
				end
			end
		end
		
		if self:IsMerc() then 
			local allEnemies = GetAllEnemyUnits(self)
			local aliveEnemies = 0
			for _, enemy in ipairs(allEnemies) do 
				if not enemy:IsDead() and not enemy:IsDefeatedVillain() then
					aliveEnemies = aliveEnemies + 1
				end
			end
			if aliveEnemies == 0 then 
				self:DoChangeStance("Standing")
			end
		elseif self.species == "Human" and self.stance ~= "Standing" then
			self:DoChangeStance("Standing")
		end
		
		self:PopAndCallDestructor()
		
		if self:IsIdleCommand() then
			self:SetCommand("Idle") -- force restart to reevaluate the use of combat/civilian anims
		end
		self:UpdateAttachedWeapons()
	elseif self.immortal then
		self:ReviveOnHealth()
		self:ChangeStance(false, 0, "Standing")
		self:SetCommand("Idle")
	end
end

---
--- Returns the appropriate step action FX based on the unit's movement state.
---
--- @return string The name of the step action FX to play
function Unit:GetStepActionFX()
	return self.is_moving and (self.move_step_fx or "StepRun") or "StepWalk"
end

---
--- Called when an animation moment occurs.
---
--- @param moment string The name of the animation moment that occurred.
--- @param anim string The name of the animation that is playing.
---
function Unit:OnAnimMoment(moment, anim)
	anim = anim or GetStateName(self)
	local animFxName = FXAnimToAction(anim)
	PlayFX(animFxName, moment, self, self.anim_moment_fx_target)

	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

-- behaviors
---
--- Returns the value of the specified command parameter.
---
--- @param name string The name of the command parameter to retrieve.
--- @param command string The name of the command to get the parameter from. Defaults to the current command.
--- @return any The value of the specified command parameter, or nil if it doesn't exist.
function Unit:GetCommandParam(name, command)
	command = command or self.command
	return self.command_specific_params and self.command_specific_params[command] and self.command_specific_params[command][name]
end

---
--- Returns a table containing the command-specific parameters for the specified command.
---
--- If no command is specified, the current command's parameters are returned.
--- If the command-specific parameters table does not exist for the specified command, a new empty table is created and returned.
---
--- @param command string The name of the command to get the parameters for. Defaults to the current command.
--- @return table The table of command-specific parameters.
function Unit:GetCommandParamsTbl(command)
	command = command or self.command
	self.command_specific_params = self.command_specific_params or {}
	self.command_specific_params[command] = self.command_specific_params[command] or {}
	return self.command_specific_params[command]
end

---
--- Sets the value of a specific command parameter for this unit.
---
--- @param command string The name of the command to set the parameter for.
--- @param param string The name of the parameter to set.
--- @param value any The value to set the parameter to.
function Unit:SetCommandParamValue(command, param, value)
	local param_tbl = self:GetCommandParamsTbl(command)
	param_tbl[param] = value
end

---
--- Sets the command-specific parameters for the specified command.
---
--- If no command is specified, the parameters are set for the current command.
--- If the `params` table is provided, it will be used to set the command-specific parameters.
--- If the `params` table contains a `weapon_anim_prefix` field, the `UpdateAttachedWeapons` method will be called to update the attached weapons.
---
--- @param command string The name of the command to set the parameters for. Defaults to the current command.
--- @param params table The table of command-specific parameters to set.
function Unit:SetCommandParams(command, params)
	command = command or self.command
	self.command_specific_params = self.command_specific_params or {}
	if params then
		self.command_specific_params[command] = params
		if params.weapon_anim_prefix then
			self:UpdateAttachedWeapons()
		end
	end
end

if FirstLoad then
	UnitIdleCommands = {
		[false] = true,
		["Idle"] = true,
		["IdleSuspicious"] = true,
		["AimIdle"] = true,
		["PreparedAttackIdle"] = true,
		["PreparedBombardIdle"] = true,
		["Dead"] = true,
		["VillainDefeat"] = true,
		["Hang"] = true,
		["Downed"] = true,
		["Cower"] = true,
		["CombatBandage"] = true,
		["ExitMap"] = true,
		["OverheardConversation"] = true,
		["OverheardConversationHeadTo"] = true,
	}

	UnitPreparedAttackBehaviors = {
		OverwatchAction = true,
		PinDown = true,
	}
	
	UnitIgnoreEnterCombatCommands = {
		["VillainDefeat"] = true,
	}
end

---
--- Checks if the unit is using a prepared attack behavior.
---
--- @return boolean true if the unit's combat behavior is a prepared attack behavior, false otherwise
function Unit:IsUsingPreparedAttack()
	return UnitPreparedAttackBehaviors[self.combat_behavior]
end

---
--- Checks if the unit's current command is an idle command.
---
--- @param check_pending boolean (optional) If true, also checks if the unit has a pending aware state or a combat action in progress.
--- @return boolean true if the unit's current command is an idle command, false otherwise
---
function Unit:IsIdleCommand(check_pending)
	return UnitIdleCommands[self.command or false] and (not check_pending or (not self.pending_aware_state and not HasCombatActionInProgress(self)))
end

---
--- Checks if the unit has a queued action that is currently paused.
---
--- @return boolean true if the unit has a queued action that is currently paused, false otherwise
function Unit:HasQueuedAction()
	local action = CombatActions[self.queued_action_id]
	return action and (action.ActivePauseBehavior == "queue") and IsActivePaused()
end

---
--- Checks if the unit is in an idle state or running a behavior.
---
--- @param self Unit The unit to check.
--- @return boolean true if the unit is in an idle state or running a behavior, false otherwise.
function Unit:IsIdleOrRunningBehavior()
	if self:IsIdleCommand() then
		return true
	end
	if g_Combat then
		return self.command == self.combat_behavior
	end
	return self.command == self.behavior
end

---
--- Handles the idle state of a unit. This function is responsible for setting the unit's command to "Idle" and performing various checks and actions related to the unit's current state, such as checking for death, cower behavior, and queued actions. It also sets up a target dummy for the unit's idle animation and orientation.
---
--- @param self Unit The unit object.
function Unit:Idle()
	self:WaitResumeOnCommandStart()
	assert(self:IsValidPos())
	SetCombatActionState(self, nil)
	self.being_interacted_with = false
	if not self.move_attack_in_progress then
		self.move_attack_target = nil
	end	
	self:SetQueuedAction()
	ExplorationClearExclusiveAction(self)

	if self:IsDead() then
		if self.behavior == "Despawn" then
			self:SetCommand("Despawn")
		elseif self.behavior ~= "Hang" and self.behavior ~= "Dead" then
			self:SetBehavior("Dead")
			self:SetCombatBehavior("Dead")
		end
	else
		if self.stance == "Prone" and self:GetValidStance("Prone") ~= "Prone" then
			self:DoChangeStance("Crouch")
		end
		if g_Combat and self:CanCower() and (self.team.side == "neutral" or self:HasStatusEffect("ForceCower")) and not g_Combat:ShouldEndCombat() then
			self:SetCommand("Cower")
		end
	end
	self:UpdateInWaterFX()

	if self:IsDead() then
		if self.behavior == "Hang" then
			self:SetCommand("Hang")
		else
			assert(not self.Squad or IsMerc(self))
			self:SetCommand("Dead")
		end
	end
	FallDownCheck(self)
	if self:HasStatusEffect("Unconscious") then
		self:SetCommand("Downed")
	elseif IsSetpieceActor(self) then
		self:SetCommand("SetpieceIdle", true)
	elseif self:HasStatusEffect("Suspicious") then
		if g_Combat then
			self:RemoveStatusEffect("Suspicious")
		else
			return self:SuspiciousRoutine()
		end
	elseif self:HasCommandsInQueue() then
		return
	elseif g_Combat and self.combat_behavior then
		self:SetCommand(self.combat_behavior, table.unpack(self.combat_behavior_params or empty_table))
	elseif not g_Combat and self.behavior and not self:HasStatusEffect("Suspicious") then
		local enemy = self:GetCommandParam("idle_forcing_dist")
		if not IsValid(enemy) or not self:IdleForcingDist(enemy) then
			self:SetCommandParamValue(self.command, "idle_forcing_dist", nil)
			self:SetCommand(self.behavior, table.unpack(self.behavior_params or empty_table))
		end
	end

	-- setup target dummy
	local anim_style = self:GetIdleStyle()
	local base_idle = anim_style and anim_style:GetMainAnim() or self:GetIdleBaseAnim()
	local can_reposition = not (g_Combat and self:IsAware()) -- if large units can change angle (occupied tiles)
	local pos, orientation_angle
	if self.return_pos and not self.play_sequential_actions then
		pos = self.return_pos
		local voxel = SnapToVoxel(self)
		if not pos:Equal2D(voxel) then
			orientation_angle = CalcOrientation(pos, voxel)
		end
	else
		pos = GetPassSlab(self) or self:GetPos()
	end
	local dummy_orientation_angle = self:GetPosOrientation(pos, nil, self.stance, true, can_reposition)
	if not orientation_angle then
		orientation_angle = self.auto_face and dummy_orientation_angle or self:GetPosOrientation(pos, nil, self.stance, false, can_reposition)
	end
	self:SetTargetDummy(pos, dummy_orientation_angle, base_idle, 0)

	if g_Combat and (not self:IsNPC() or self:IsAware()) then
		Msg("Idle", self)
	end
	if self.aim_action_id and not HasCombatActionInProgress(self) then
		self:SetCommand("AimIdle")
	end
	self:SetWeaponLightFx(false)
	self:SetIK("AimIK", false)
	if self.play_sequential_actions then
		self:SetCommand("SequentialActionsIdle")
	end

	-- orient
	if not GameTimeAdvanced then
		self:SetOrientationAngle(orientation_angle)
	else
		self:EndInterruptableMovement()
		self:PlayTransitionAnims(base_idle, orientation_angle)
		self:AnimatedRotation(orientation_angle, base_idle)
		self:BeginInterruptableMovement()
	end

	self:SetCommandParamValue("Idle", "move_anim", "WalkSlow")
	if self:ShouldBeIdle() then
		-- one animation cycle
		-- play current style end animation
		self.cur_idle_style = anim_style and anim_style.Name or nil
		if anim_style then
			local anim = self:GetStateText()
			if anim_style:HasAnimation(anim) then
				if self:GetAnimPhase() ~= 0 and not self:IsAnimEnd() then
					Sleep(self:TimeToAnimEnd())
				end
			elseif anim == anim_style.Start then
				Sleep(self:TimeToAnimEnd())
			elseif (anim_style.Start or "") ~= "" and IsValidAnim(self, anim_style.Start) then
				self:SetState(anim_style.Start, const.eKeepComponentTargets)
				Sleep(self:TimeToAnimEnd())
			end
			self:SetState(anim_style:GetRandomAnim(self), const.eKeepComponentTargets)
			if not GameTimeAdvanced then
				self:RandomizeAnimPhase()
			end
		else
			if self:GetAnimPhase(1) == 0 or self:IsAnimEnd() or not IsAnimVariant(self:GetStateText(), base_idle) then
				self:SetRandomAnim(base_idle, const.eKeepComponentTargets, nil, true)
			end
		end
		Sleep(self:TimeToAnimEnd())
	else
		self:IdleRoutine()
	end
end

--- Puts the unit in an "idle suspicious" state, where the unit will perform a passive idle animation based on their gender and equipped weapon.
---
--- If the unit is standing and is a human, this function will:
--- - Determine the appropriate idle animation based on the unit's gender and equipped weapon
--- - Set the unit's state to the determined animation
--- - Sleep until the animation ends
---
--- After the animation, the unit's command is set to "Idle".
function Unit:IdleSuspicious()
	if self.stance == "Standing" and self.species == "Human" then
		local anim
		if self.gender == "Male" then
			anim = self:TryGetActionAnim("IdlePassive2", self.stance)
		else
			local weapon = self:GetWeaponAnimPrefix()
			if weapon == "nw" or self.carry_flare then
				anim = self:TryGetActionAnim("IdlePassive", self.stance)				
			elseif weapon == "mk" then
				anim = self:TryGetActionAnim("IdlePassive6", self.stance)
			else
				anim = self:TryGetActionAnim("IdlePassive2", self.stance)
			end
		end
		if self.carry_flare then
			anim = string.gsub(anim, "^%a*_", "nw_")
		end
		anim = self:ModifyWeaponAnim(anim)
		self:SetState(anim)
		Sleep(self:TimeToAnimEnd())
	end
	self:SetCommand("Idle")
end

--- Moves the unit to a voxel-snapped position and sets its orientation.
---
--- If the unit's current position is not voxel-snapped, the unit will be moved to the nearest voxel-snapped position.
--- The unit's orientation will be set to the angle of the voxel-snapped position.
---
--- This function is used to ensure the unit is positioned and oriented correctly, typically after a movement or action.
function Unit:TakeSlabExploration()
	local pos, angle = self:GetVoxelSnapPos()
	if not pos then
		return
	end
	if GameTimeAdvanced then
		local vx, vy = SnapToVoxel(self:GetVisualPosXYZ())
		if not pos:Equal2D(vx, vy) then
			self:Goto(pos, "sl")
			pos, angle = self:GetVoxelSnapPos()
		end
	end
	self:SetPos(pos)
	self:SetOrientationAngle(angle)
end

function OnMsg.GatherFXMoments(list)
	table.insert_unique(list, "start")
	table.insert_unique(list, "end")
	table.insert(list, "action_start")
	table.insert(list, "action_end")
	table.insert(list, "WeaponGripStart")
	table.insert(list, "WeaponGripEnd")
	table.insert(list, "OrientationStart")
	table.insert(list, "OrientationEnd")
end

--- Handles the start of the weapon grip animation.
---
--- This function is called when the "WeaponGripStart" FX moment is triggered. It sets the weapon grip state of the unit to true.
function Unit:OnMomentWeaponGripStart()
	self:SetWeaponGrip(true)
end

--- Handles the end of the weapon grip animation.
---
--- This function is called when the "WeaponGripEnd" FX moment is triggered. It sets the weapon grip state of the unit to false.
function Unit:OnMomentWeaponGripEnd()
	self:SetWeaponGrip(false)
end

--- Starts the sequential actions for the unit.
---
--- This function sets the `play_sequential_actions` flag to `true`, indicating that the unit should execute a sequence of actions.
function Unit:SequentialActionsStart()
	self.play_sequential_actions = true
end

--- Ends the sequential actions for the unit.
---
--- This function sets the `play_sequential_actions` flag to `false`, indicating that the unit has finished executing a sequence of actions. If the current command is "SequentialActionsIdle", it sets the command to "Idle".
function Unit:SequentialActionsEnd()
	if not self.play_sequential_actions then
		return
	end
	self.play_sequential_actions = false
	if self.command == "SequentialActionsIdle" then
		self:SetCommand("Idle")
	end
end

--- Halts the unit's sequential actions.
---
--- This function is called when the unit is in the "SequentialActionsIdle" state. It calls the `Halt()` function to stop the unit's current actions and transition it to the "Idle" state.
function Unit:SequentialActionsIdle()
	Halt()
end

--- Returns the unit to its cover position.
---
--- This function moves the unit back to its previously stored cover position, if it is valid and the unit can occupy it. It sets the target dummy position and orientation based on the cover position, and plays an appropriate weapon aim end animation.
---
--- @param prefix (string) The prefix to use for the weapon animation. If not provided, it will be determined from the unit's current state text or weapon animation prefix.
--- @param update_target_dummy (boolean) Whether to update the target dummy position and orientation. Defaults to true.
--- @return (boolean) True if the unit was successfully returned to cover, false otherwise.
function Unit:ReturnToCover(prefix, update_target_dummy)
	local pos = self.return_pos
	if not pos then
		return false
	end
	if not IsCloser(self, pos, const.SlabSizeX/2) and CanOccupy(self, pos) and IsPassSlabStep(self, pos) then
		local voxel_x, voxel_y = SnapToVoxel(self:GetPosXYZ())
		local angle = pos:Equal2D(voxel_x, voxel_y, 0) and self:GetAngle() or CalcOrientation(pos, voxel_x, voxel_y, 0)
		if update_target_dummy ~= false then
			self:SetTargetDummyFromPos(pos, angle)
		end
		local side = AngleDiff(self:GetVisualOrientationAngle(), angle) < 0 and "Left" or "Right"
		prefix = prefix or string.match(self:GetStateText(), "^(%a+_).*") or self:GetWeaponAnimPrefix()
		local anim = string.format("%s%s_Aim_End", prefix, side)
		self:SetIK("AimIK", false)
		self:SetFootPlant(true)
		if IsValidAnim(self, anim) then
			if self:CanQuickPlayInCombat() then
				self:SetPos(pos)
				self:SetOrientationAngle(angle)
			else
				anim = self:ModifyWeaponAnim(anim)
				self:SetPos(pos, self:GetAnimDuration(anim))
				self:RotateAnim(angle, anim)
			end
		else
			local msg = string.format('Missing animation "%s" for "%s"', anim, self.unitdatadef_id)
			StoreErrorSource(self, msg)
			self:SetPos(pos)
			self:SetOrientationAngle(angle)
		end
	end
	self.return_pos = false
	return true
end

---
--- Updates the animation speed and position of the unit during a move-and-play-animation sequence.
---
--- This function is used to update the animation speed and position of a unit while it is playing an animation and moving to a destination. It sets the animation state, repeatedly updates the animation speed based on the unit's movement speed modifier, and optionally updates the unit's position over time.
---
--- @param anim (string) The name of the animation to play.
--- @param anim_flags (number) The flags to use when setting the animation state.
--- @param crossfade (number) The crossfade duration to use when setting the animation state.
--- @param dest (Vector3) The destination position to move the unit to.
---
function Unit:MovePlayAnimSpeedUpdate(anim, anim_flags, crossfade, dest)
	self:SetState(anim, anim_flags or 0, crossfade or -1)
	repeat
		self:SetAnimSpeed(1, self:CalcMoveSpeedModifier())
		local t = self:TimeToAnimEnd()
		if dest then
			self:SetPos(dest, t)
		end
	until not WaitWakeup(t)
end

---
--- Moves the unit to a destination while playing an animation.
---
--- This function is used to move a unit to a destination position while playing a specified animation. It handles various aspects of the animation and movement, such as:
--- - Setting the animation state and crossfade duration
--- - Updating the animation speed based on the unit's movement speed modifier
--- - Optionally updating the unit's position over time during the animation
--- - Handling different phases of the animation (start, scale, end)
--- - Adjusting the animation speed and acceleration to match the movement
---
--- @param anim (string) The name of the animation to play.
--- @param pos1 (Vector3) The starting position for the movement.
--- @param pos2 (Vector3) The destination position for the movement.
--- @param anim_flags (number) The flags to use when setting the animation state.
--- @param crossfade (number) The crossfade duration to use when setting the animation state.
--- @param ground_orient (boolean) Whether to orient the unit to the ground during the movement.
--- @param angle (number) The orientation angle for the unit.
--- @param start_offset (Vector3) An offset to apply to the starting position.
--- @param end_offset (Vector3) An offset to apply to the ending position.
--- @param sleep_mod (number) A modifier to apply to the sleep duration at the end of the animation.
--- @param acceleration (boolean) Whether to use acceleration during the movement.
---
function Unit:MovePlayAnim(anim, pos1, pos2, anim_flags, crossfade, ground_orient, angle, start_offset, end_offset, sleep_mod, acceleration)
	if not anim or not self:HasState(anim) then
		self:SetPos(pos2)
		self:SetFootPlant(true)
		return
	end
	if not angle then
		if pos1:Equal2D(pos2) then
			angle = self:GetAngle()
		else
			angle = CalcOrientation(pos1, pos2)
		end
	end
	if not pos1:IsValidZ() then
		pos1 = pos1:SetTerrainZ()
	end
	local pos2_3d = pos2:IsValidZ() and pos2 or pos2:SetTerrainZ()
	local t = self:GetVisualDist(pos1) == 0 and 100 or 0
	self:SetPos(pos1)
	self:SetFootPlant(false, t)
	self:SetOrientationAngle(angle, t)
	-- animation movement can be scaled only between "start" and "end" moments
	self:SetState(anim, anim_flags or const.eKeepComponentTargets, crossfade or -1)

	local anim_full_step = GetEntityStepVector(self:GetEntity(), anim)
	local use_animation_step = pos1 ~= pos2_3d and anim_full_step:Len() > 10*guic
	local duration = GetAnimDuration(self:GetEntity(), anim)
	local phase1 = self:GetAnimMoment(anim, "start") or 0
	local phase2 = self:GetAnimMoment(anim, "end")
	if not phase2 then
		local hit = self:GetAnimMoment(anim, "hit")
		phase2 = (hit or duration) - 200
	end
	if phase2 < phase1 then
		phase2 = phase1
	end
	start_offset = start_offset or point30
	end_offset = end_offset or point30

	if phase1 > 0 then
		-- [0 - action_start] - adjust the unit at proper action start position
		local action_phase1 = self:GetAnimMoment(anim, "action_start")
		if action_phase1 then
			action_phase1 = Min(action_phase1, phase1)
		else
			action_phase1 = phase1 / 2
		end
		if action_phase1 > 0 then
			local v = use_animation_step and self:GetStepVector(anim, angle, 0, action_phase1) or point30
			local dest = pos1 + v + start_offset
			local t = self:TimeToPhase(1, action_phase1) or 0
			self:SetPos(dest, t)
			Sleep(t)
		end
		-- [action_start - start scale] - play the animation as it is
		local v = use_animation_step and self:GetStepVector(anim, angle, 0, phase1) or point30
		local dest = pos1 + v + start_offset
		local t = self:TimeToPhase(1, phase1) or 0
		self:SetPos(dest, t)
		Sleep(t)
	end

	-- [scale] - the unit should reach the proper end position at the proper phase2 (the unit should be in the air)
	local v = use_animation_step and self:GetStepVector(anim, angle, phase2, duration - phase2) or point30
	local phase2_pos = pos2_3d - v + end_offset
	local t = phase2 > phase1 and self:TimeToPhase(1, phase2) or 0

	if t == 0 then
		self:SetPos(phase2_pos)
		if ground_orient then
			self:SetGroundOrientation(angle, t)
		end
	else
		local anim_speed, new_anim_speed
		if use_animation_step and self:IsCommandThread() then
			local extra_step_z = pos2_3d:z() - (pos1:z() + anim_full_step:z())
			local scale = 1000
			if anim_full_step:Len2D() > abs(anim_full_step:z()) then
				-- horizontal scale
				local extra_dist_2d = pos1:Dist2D(pos2) - anim_full_step:Len2D()
				if extra_dist_2d > const.SlabSizeX/4 then
					local anim_dist2d = abs(self:GetStepVector(anim, 0, phase1, phase2 - phase1):x())
					scale = anim_dist2d > 0 and MulDivRound(1000, anim_dist2d + extra_dist_2d, anim_dist2d) or 1000000
					scale = Min(scale, 1500) -- fix bugged animations with vely small steps
				end
				local fall_time = extra_step_z < 0 and self:GetGravityFallTime(abs(pos2_3d:z() - pos1:z()), -4000, const.Combat.Gravity) or 0
				if fall_time > phase2 - phase1 then
					scale = Max(scale, MulDivRound(1000, fall_time, phase2 - phase1))
				end
			else
				if extra_step_z < 0 and anim_full_step:z() <= -const.SlabSizeZ/2 then
				-- vertical scale
					scale = MulDivRound(1000, pos2_3d:z() - pos1:z(), anim_full_step:z())
				end
			end
			if scale ~= 1000 then
				anim_speed = self:GetAnimSpeed(1)
				new_anim_speed = MulDivRound(anim_speed, 1000, scale)
				self:SetAnimSpeed(1, new_anim_speed)
				t = self:TimeToPhase(1, phase2) or 0
			end
		end
		local acc = acceleration and self:GetAccelerationAndStartSpeed(phase2_pos, 0, t) or 0
		self:SetAcceleration(acc)
		self:SetPos(phase2_pos, t)
		if ground_orient then
			self:SetGroundOrientation(angle, t)
		end
		if acceleration or anim_speed then
			self:PushDestructor(function(self)
				if IsValid(self) then
					self:SetAcceleration(0)
					if anim_speed and self:GetAnimSpeed(1) == new_anim_speed then
						self:SetAnimSpeed(1, anim_speed)
					end
				end
			end)
		end
		Sleep(t)
		if acceleration or anim_speed then
			self:PopAndCallDestructor()
		end
	end

	-- [end scale - action end] - play the animation as it is
	local action_phase2 = self:GetAnimMoment(anim, "action_end")
	if action_phase2 then
		action_phase2 = Max(action_phase2, phase2)
	else
		action_phase2 =  phase2
	end
	if action_phase2 > phase2 then
		local v = self:GetStepVector(anim, angle, action_phase2, duration - action_phase2)
		local dest = pos2_3d - v + end_offset
		local t = self:TimeToPhase(1, action_phase2) or 0
		self:SetPos(dest, t)
		Sleep(t)
	end

	-- [action end - animation end] - reach pos2 to the animation end
	t = self:TimeToAnimEnd()
	if t >= 999999999 then
		assert(t < 999999999) -- can happen using editor
		t = 0
	end
	if sleep_mod then t = MulDivRound(t, sleep_mod, 100) end
	self:SetPos(pos2_3d, t)
	Sleep(t)
	self:SetPos(pos2)
	self:SetFootPlant(true)
end

---
--- Checks if the given enemy unit can be faced by the current unit.
---
--- @param enemy Unit The enemy unit to check.
--- @return boolean True if the enemy can be faced, false otherwise.
---
function Unit:CanFaceEnemy(enemy)
	return not (enemy:IsDead() or enemy:IsDowned() or enemy:HasStatusEffect("Hidden"))
end

---
--- Checks if the given unit is considered an enemy of the current unit.
---
--- @param unit Unit The unit to check.
--- @return boolean True if the unit is considered an enemy, false otherwise.
---
function Unit:IsConsideredEnemy(unit)
	if self:IsOnEnemySide(unit) then return true end
	for _, groupname in ipairs(self.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for group, _ in pairs(group_modifiers) do
			if table.find(unit.Groups, group) then
				return true
			end
		end
	end
end

---
--- Gets the closest enemy unit to the given position.
---
--- @param pos Vector3 The position to check for the closest enemy. If not provided, the unit's current position is used.
--- @return Unit|nil The closest enemy unit, or nil if no valid enemy is found.
---
function Unit:GetClosestEnemy(pos)
	if not IsValid(self) then return end
	pos = SnapToVoxel(pos or self)
	local face_targets = {}
	local threshold = const.SlabSizeX / 2
	local closest_enemy, min_dist
	-- check directly visible enemies
	local visibility = g_Visibility[self]
	for _, unit in ipairs(visibility) do
		if IsValid(unit) and (not min_dist or IsCloser(unit, pos, min_dist)) then
			local enemy = self:IsConsideredEnemy(unit)
			if IsValidTarget(unit) and enemy and self:CanFaceEnemy(unit) then
				table.insert(face_targets, unit)
				local dist = unit:GetDist(pos)
				if not closest_enemy or dist < min_dist then
					closest_enemy = unit
					min_dist = dist + threshold
				end
			end
		end
	end
	if not closest_enemy then
		return
	end
	if #face_targets > 1 then
		-- prefer targets closer to our current facing
		local cur_angle = self:GetAngle()
		local closest_adiff = abs(AngleDiff(CalcOrientation(pos, closest_enemy), cur_angle))
		for _, unit in ipairs(face_targets) do
			if unit ~= closest_enemy and IsCloser(unit, pos, min_dist) then
				local adiff = abs(AngleDiff(CalcOrientation(pos, unit), cur_angle))
				if adiff < closest_adiff then
					closest_enemy = unit
					closest_adiff = adiff
				end
			end
		end
	end
	return closest_enemy
end

---
--- Checks if the unit is using cover.
---
--- @return boolean True if the unit is using cover, false otherwise.
---
function Unit:IsUsingCover()
	local cover = GetHighestCover(self)	
	return cover and (cover == 2 or cover == 1 and self.stance ~= "Standing")
end

---
--- Finds the closest cover to the unit that faces the closest enemy.
---
--- @param pos Vector3 The position to start searching for cover from.
--- @return boolean, Unit|Vector3 Returns true and the cover position if a cover was found, false and the closest enemy if no cover was found.
---
function Unit:GetCoverToClosestEnemy(pos)
	pos = pos or self:GetVoxelSnapPos()
	if not pos or not pos:IsValid() then
		return
	end
	local enemies = table.copy(GetEnemies(self))
	local closest_enemy, closest_angle, closest_face_target, closest_dist
	local ow_target = self:GetOverwatchTarget()
	
	-- check for script-driven enemy relations
	for _, groupname in ipairs(self.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for target_group, mod in pairs(group_modifiers) do
			for _, obj in ipairs(Groups[target_group]) do
				if IsKindOf(obj, "Unit") then
					table.insert_unique(enemies, obj)
				end
			end
		end
	end	

	local function update_closest(check_pos, angle)
		for _, enemy in ipairs(enemies) do
			local dist = IsValid(enemy) and enemy:GetDist(check_pos)
			if dist and (not closest_dist or dist < closest_dist) then
				closest_enemy = enemy
				closest_dist = dist
				closest_angle = angle
				closest_face_target = check_pos
			end
		end
	end

	local covers
	if self:IsEnemyPresent() then
		covers = GetCoversAt(pos)
	end

	if not next(covers) then
		if ow_target then
			return false, ow_target
		end
		if #enemies == 0 then
			-- no covers, no enemies - nothing to face
			return
		else
			-- no covers - face the closest enemy
			update_closest(pos or self:GetPos())
			return false, closest_enemy
		end
	end

	local covers_count = table.count(covers)
	if covers_count == 1 then
		-- single cover only - face it no matter the enemies
		local angle, cover = next(covers)
		return cover, pos + GetCoverOffset(angle)
	end

	-- multiple covers
	if #enemies == 0 then
		local angle, cover = next(covers)	-- for now choose the 1st cover
		return cover, pos + GetCoverOffset(angle)
	end

	-- multiple covers, enemies around - choose the cover which center has the closest enemy
	for angle, cover in sorted_pairs(covers) do
		local cover_center = pos + GetCoverOffset(angle)
		update_closest(cover_center, angle)
	end
	local cover = covers[(closest_angle + 180*60) % (360*60)]

	return cover, closest_face_target
end

---
--- Calculates the orientation angle for a unit based on the given position, angle, stance, and other factors.
---
--- @param pos table|nil The position to use for the orientation. If not provided, it will use the unit's current position or the nearest passable slab.
--- @param angle number|nil The angle to use for the orientation. If not provided, it will use the unit's current visual orientation angle.
--- @param stance string|nil The stance to use for the orientation. If not provided, it will use the unit's current stance.
--- @param auto_face boolean|nil Whether the unit should automatically face the nearest enemy or bandage target. If not provided, it will use the unit's auto_face setting.
--- @param can_reposition boolean|nil Whether the unit can reposition itself to avoid collisions. If not provided, it will assume the unit can reposition.
--- @return number The calculated orientation angle for the unit.
function Unit:GetPosOrientation(pos, angle, stance, auto_face, can_reposition)
	if not pos then
		pos = GetPassSlab(self) or self:GetPos()
	end
	if not pos:IsValid() then
		return 0
	end
	local bandage_target = self:GetBandageTarget()

	if not angle then
		 -- subsequent calls of self:GetOrientationAngle() can lead to small rotation
		angle = self:GetVisualOrientationAngle()
		if self.last_orientation_angle and abs(AngleDiff(angle, self.last_orientation_angle)) < 5*60 then
			angle = self.last_orientation_angle
		end
	end
	stance = stance or self.stance
	if self:HasStatusEffect("ManningEmplacement") then
		auto_face = false
	elseif IsValid(bandage_target) then
		auto_face = true
	end
	if auto_face == nil then
		auto_face = self.auto_face
	end

	-- face the nearest enemy and orient to high cover
	if g_Combat
		and auto_face
		and self:IsAware()
		and not self:HasStatusEffect("Exposed")
	then
		local to_face = IsValid(bandage_target) and bandage_target or self:GetClosestEnemy(pos)
		if to_face then
			angle = CalcOrientation(pos, to_face.return_pos or to_face)
		end
		if self.species == "Human" and (stance == "Standing" or stance == "Crouch") and GetHighestCover(pos) == const.CoverHigh then
			local face_angle
			if to_face then
				-- face the cover attack step out position
				local action = self:GetDefaultAttackAction("ranged")
				if action and action.AimType ~= "melee" then
					local lof_args = {
						action_id = action.id,
						obj = self,
						step_pos = pos,
						stance = "Standing",
						aimIK = false,
						prediction = true,
					}
					local lof_data = CheckLOF(to_face, lof_args)
					if lof_data and not IsCloser2D(pos, lof_data.step_pos, const.SlabSizeX/2) then
						face_angle = CalcOrientation(pos, lof_data.step_pos)
					end
				end
			end
			if not face_angle then
				face_angle = GetUnitOrientationToHighCover(pos, angle)
			end
			if face_angle then
				angle = face_angle
			end
		end
	end

	-- adjust angle of lying units to not collide with other units or environment
	if self.body_type == "Large animal" then
		local can_reposition = can_reposition ~= false or not self:IsEqualPos(pos)
		local snap_angle, fallback = FindLargeUnitAngle(self, pos, angle, can_reposition)
		angle = snap_angle or fallback or angle
	elseif self.species == "Human" and stance == "Prone" then
		angle = FindProneAngle(self, pos, angle)
	end
	return angle
end

---
--- Sets the target dummy for the unit based on the given position.
---
--- @param pos Vector3 | nil The position to set the target dummy at. If `nil`, the unit's current position is used.
--- @param angle number | nil The orientation angle for the target dummy. If `nil`, the unit's current orientation angle is used.
--- @param can_reposition boolean | nil Whether the unit can reposition the target dummy. If `nil`, the unit's current position is used.
--- @return boolean Whether the target dummy was successfully set.
function Unit:SetTargetDummyFromPos(pos, angle, can_reposition)
	pos = pos or GetPassSlab(self) or self:GetPos()
	if not pos:IsValid() or self:IsDead() then
		return self:SetTargetDummy(false)
	end
	local orientation_angle = self:GetPosOrientation(pos, angle, self.stance, true, can_reposition)
	local anim_style = GetAnimationStyle(self, self.cur_idle_style)
	local base_idle = anim_style and anim_style:GetMainAnim() or self:GetIdleBaseAnim()
	return self:SetTargetDummy(pos, orientation_angle, base_idle, 0)
end

---
--- Sets the target dummy for the unit based on the given position.
---
--- @param pos Vector3 | nil The position to set the target dummy at. If `nil`, the unit's current position is used.
--- @param orientation_angle number | nil The orientation angle for the target dummy. If `nil`, the unit's current orientation angle is used.
--- @param anim string | nil The animation to use for the target dummy. If `nil`, the unit's current state text is used.
--- @param phase number | nil The animation phase for the target dummy. If `nil`, the unit's current animation phase is used.
--- @param stance string | nil The stance to use for the target dummy. If `nil`, the unit's current stance is used.
--- @param ground_orient boolean | nil Whether to orient the target dummy to the ground. If `nil`, the unit's current ground orientation is used.
--- @return boolean Whether the target dummy was successfully set.
function Unit:SetTargetDummy(pos, orientation_angle, anim, phase, stance, ground_orient)
	local dummy = self.target_dummy
	if dummy and dummy.locked then
		return
	end
	local changed
	if pos ~= false then
		pos = pos or GetPassSlab(self) or self:GetPos()
		--assert(CanOccupy(self, pos)) -- hit when loading savegames with units on impassable
		anim = anim or self:GetStateText()
		phase = phase or self:GetAnimPhase()
		stance = stance or self.stance
		if not orientation_angle then
			orientation_angle = self:GetOrientationAngle()
			if stance == "Prone" then
				orientation_angle = FindProneAngle(self, nil, orientation_angle, 60*60)
			end
		end
		if ground_orient == nil then
			ground_orient = select(2, self:GetFootPlantPosProps(stance))
		end
		if not dummy then
			if self.body_type == "Large animal" then
				dummy = PlaceObject("TargetDummyLargeAnimal", { obj = self })
			else
				dummy = PlaceObject("TargetDummy", { obj = self })
			end
			self.target_dummy = dummy
			changed = changed or "unit"
		end
		-- pos
		if changed or not dummy:IsEqualPos(pos) then
			dummy:SetPos(pos)
			changed = changed or "pos"
		end
		-- animation / phase
		if changed or dummy:GetStateText() ~= anim then
			dummy:SetState(anim)
			dummy:SetAnimSpeed(1, 0)
			changed = changed or "animation"
		end
		if changed or dummy:GetAnimPhase() ~= phase then
			dummy:SetAnimPhase(1, phase)
			changed = changed or "phase"
		end
		-- orientation
		local prev_angle, prev_axisx, prev_axisy, prev_axisz
		if not changed then
			prev_angle, prev_axisx, prev_axisy, prev_axisz = dummy:GetAngle(), dummy:GetVisualAxisXYZ()
		end
		if dummy.stance ~= stance then
			dummy.stance = stance
			changed = changed or "stance"
		end
		if ground_orient then
			dummy:ChangePathFlags(const.pfmGroundOrient)
			dummy:SetGroundOrientation(orientation_angle, 0)
		else
			dummy:ChangePathFlags(0, const.pfmGroundOrient)
			dummy:SetAxisAngle(axis_z, orientation_angle)
		end
		if not changed then
			local new_angle, new_axisx, new_axisy, new_axisz = dummy:GetAngle(), dummy:GetVisualAxisXYZ()
			if new_angle ~= prev_angle or new_axisx ~= prev_axisx or new_axisy ~= prev_axisy or new_axisz ~= prev_axisz then
				changed = true
			end
		end
		dummy:ClearEnumFlags(const.efResting)
		-- notify changed
	elseif dummy then
		changed = true
		DoneObject(dummy)
		self.target_dummy = false
	end
	if changed then
		Msg("TargetDummiesChanged", self)
		return true
	end
	return false
end

---
--- Generates a list of target dummies from a given path.
---
--- @param path table|nil The combat path to generate dummies from. If not provided, uses the object's `combat_path`.
--- @return table A list of target dummies, each represented as a table with the following fields:
---   - obj: the object the dummy represents
---   - anim: the animation state of the dummy
---   - phase: the animation phase of the dummy
---   - pos: the position of the dummy
---   - angle: the orientation angle of the dummy
---   - stance: the stance of the dummy
---   - insert_idx: the index in the path where the dummy should be inserted
---
function Unit:GenerateTargetDummiesFromPath(path)
	path = path or self.combat_path
	local dummies = {}
	local base_idle = self:GetIdleBaseAnim(self.stance)

	local function AddDummyPos(pos, angle, insert_idx, last_step_pos)
		if pos ~= last_step_pos then
			table.insert(dummies, { obj = self, anim = base_idle, phase = 0, pos = pos, angle = angle, stance = self.stance, insert_idx = insert_idx })
		end
	end

	local p1 = self:GetPos()
	local angle = self:GetOrientationAngle()
	local dummy = self.target_dummy
	if dummy and dummy:GetPos() == p1 then
		table.insert(dummies, { obj = self, anim = dummy:GetStateText(), phase = dummy:GetAnimPhase(1), pos = dummy:GetPos(), angle = dummy:GetAngle(), insert_idx = #path + 1 })
	else
		AddDummyPos(p1, angle)
	end
	for i = #path, 1, -1 do
		local p0 = p1
		p1 = point(point_unpack(path[i]))
		if p0 ~= p1 then
			if not p0:Equal2D(p1) then
				angle = CalcOrientation(p0, p1)
			end
			local tunnel = pf.GetTunnel(p0, p1)
			if not tunnel then
				ForEachWalkStep(p0, p1, AddDummyPos, angle, i + 1, p1)
			end
			AddDummyPos(p1, angle)
		end
	end
	return dummies
end

---
--- Checks if the given unit is on the enemy side of the current unit.
---
--- @param other Unit The other unit to check.
--- @return boolean True if the other unit is on the enemy side, false otherwise.
---
function Unit:IsOnEnemySide(other)
	return self.team and other.team and band(self.team.enemy_mask, other.team.team_mask) ~= 0
end

---
--- Checks if the given unit is on the ally side of the current unit.
---
--- @param other Unit The other unit to check.
--- @return boolean True if the other unit is on the ally side, false otherwise.
---
function Unit:IsOnAllySide(other)
	return self.team and other.team and band(self.team.ally_mask, other.team.team_mask) ~= 0
end

---
--- Checks if the current unit is on the player's ally side.
---
--- @return boolean True if the unit is on the player's ally side, false otherwise.
---
function Unit:IsPlayerAlly()
	return self.team and self.team.player_ally
end

---
--- Checks if the current unit should report its status effects in the log.
---
--- @return boolean True if the unit should report its status effects, false otherwise.
---
function Unit:ReportStatusEffectsInLog()
	--return not (self.team and self.team.side == "neutral")
	return const.DbgStatusEffects and not (self.team and self.team.side == "neutral")
end

local visibility_spots = {
	"Head", "Neck", --head
	"Shoulderl", "Shoulderr", --torso
	"Ribsupperl", "Ribsupperr",
	"Ribslowerl", "Ribslowerr",
	"Pelvisl", "Pelvisr",
	"Groin", --groin
	"Shoulderl", "Shoulderr", --arms
	"Elbowl", "Elbowr",
	"Wristl", "Wristr",
	"Kneel", "Kneer", --legs
	"Anklel", "Ankler",
}
local visibility_spot_indices = {}
---
--- Gets the visibility spot indices for the current unit.
---
--- The visibility spot indices are used to determine which parts of the unit's body are visible to other units. This function calculates and caches the indices for the current unit's entity and state.
---
--- @return table The visibility spot indices for the current unit.
---
function Unit:GetVisibilitySpotIndices()
	local entity = self:GetEntity()
	local current_state = self:GetState()
	
	local states = visibility_spot_indices[entity]
	local indices = states and states[current_state]
	
	if not indices then
		states = states or { }
		visibility_spot_indices[entity] = states
		
		indices = { }
		local n = 1
		for i=1,#visibility_spots do
			local spot_name = visibility_spots[i]
			local first, last = GetSpotRange(entity, 0, spot_name)
			for idx=first,last do
				indices[n] = idx
				n = n + 1
			end
		end
		states[current_state] = indices
	end
	
	return indices or empty_table
end

---
--- Determines if the current unit is an NPC (non-player character).
---
--- @return boolean True if the unit is an NPC, false otherwise.
---
function Unit:IsNPC()
	local unit_data = UnitDataDefs[self.unitdatadef_id]
	return not unit_data or not unit_data.IsMercenary
end

---
--- Determines if the current unit is a mercenary.
---
--- @return boolean True if the unit is a mercenary, false otherwise.
---
function Unit:IsMerc()
	local unit_data = UnitDataDefs[self.unitdatadef_id]
	return unit_data and unit_data.IsMercenary
end

---
--- Determines if the current unit is a civilian.
---
--- @return boolean True if the unit is a civilian, false otherwise.
---
function Unit:IsCivilian()
	return self.team and self.team.side and self.team.side == "neutral" and self.species == "Human"
end

---
--- Returns the maximum sight radius for units.
---
--- @return number The maximum sight radius for units.
---
function GetMaxSightRadius()
	return const.Combat.AwareSightRange * const.Combat.SightModMaxValue / 100  * const.SlabSizeX + const.SlabSizeX / 4
end

---
--- Calculates the sight radius for the current unit, taking into account various environmental and unit-specific factors.
---
--- @param other Unit|Point The target unit or position to check sight for.
--- @param base_sight number (optional) The base sight radius to use, if not using the default.
--- @param step_pos Point (optional) The position to use for environmental checks instead of the target's position.
--- @return number The calculated sight radius.
--- @return boolean Whether the target is hidden.
--- @return boolean Whether it is night time.
---
function Unit:GetSightRadius(other, base_sight, step_pos)
	-- base sight radius, based on awareness (in-combat only) and illumination	
	local modifier = 100
	local other_is_unit = other and IsKindOf(other, "Unit") or false
	local hidden = other_is_unit and other:HasStatusEffect("Hidden")
	local sight = base_sight or (not hidden and self:IsAware() and const.Combat.AwareSightRange or const.Combat.UnawareSightRange)
	local night_time = GameState.Night or GameState.Underground
	if night_time and other and IsIlluminated(other, nil, nil, step_pos) then
		night_time = false
	end

	local force_min_sight = self:CallReactions_Or("OnCheckForceMinSight", self, other, step_pos, night_time)
	force_min_sight = force_min_sight or (IsKindOf(other, "Unit") and other:CallReactions_Or("OnCheckForceMinSight", self, other, step_pos, night_time))
	if force_min_sight then
		return MulDivRound(sight, const.Combat.SightModMinValue, 100) * const.SlabSizeX, hidden, night_time
	end
	modifier = self:CallReactions_Modify("OnCalcSightModifier", modifier, self, other, step_pos, night_time)
	if IsKindOf(other, "Unit") then
		modifier = other:CallReactions_Modify("OnCalcSightModifier", modifier, self, other, step_pos, night_time)
	end
	
	if other_is_unit and not other:IsDead() and not other:IsDowned() then
		if hidden then
			-- add (clamped) attrib difference as modifier
			local steath_mod = Max(0, MulDivRound(other.Agility - self.Wisdom, const.Combat.SightModStealthStatDiff, 100))		
			if other.stance == "Prone" then
				steath_mod = steath_mod + const.Combat.SightModHiddenProne
			end
			modifier = modifier - steath_mod
		end
		local armor = other:GetItemInSlot("Torso", "Armor")
		if armor and armor.Camouflage then
			modifier = modifier - const.Combat.CamoSightPenalty
		end
	end

	-- environmental factors
	if other then
		local env_factors = GetVoxelStealthParams(step_pos or other) or 0
		if band(env_factors, const.vsFlagTallGrass) ~= 0 then
			modifier = modifier + const.EnvEffects.BrushSightMod
		end
	end
	if night_time and other then
		local darknessMod = const.EnvEffects.DarknessSightMod
		if self:HasNightVision() then
			local penaltyReduce = CharacterEffectDefs.NightOps:ResolveValue("night_vision_penalty_reduction")
			darknessMod = MulDivRound(darknessMod, penaltyReduce, 100)
		end
		modifier = modifier + darknessMod
	end	
	if GameState.Fog then
		modifier = modifier + const.EnvEffects.FogSightMod
	end
	if GameState.DustStorm then
		modifier = modifier + const.EnvEffects.DustStormSightMod
	end
	if GameState.FireStorm then
		modifier = modifier + const.EnvEffects.FireStormSightMod
	end
	if other_is_unit then	-- height difference check
		local ox, oy, oz
		if step_pos then
			ox, oy, oz = PosToGridCoords(step_pos:xyz())
		else
			ox, oy, oz = other:GetGridCoords()
		end
		local x, y, z = self:GetGridCoords()
		if oz >= z + const.EnvEffects.SightHeightDiffThreshold then
			modifier = modifier + const.EnvEffects.SightHeightDiffMod
		elseif g_Exploration and oz + const.EnvEffects.SightHeightDiffThreshold < z  then
			modifier = modifier + -(const.EnvEffects.SightHeightDiffMod * 2)
		end
	end
	
	modifier = Clamp(modifier, const.Combat.SightModMinValue, const.Combat.SightModMaxValue)
	
	local sightAmount = MulDivRound(sight, modifier, 100) * const.SlabSizeX
	
	-- Prevent going in and out of sus state due to Pos/VisualPos differences.
	if self.command == "IdleSuspicious" then
		sightAmount = sightAmount + const.SlabSizeX / 4
	end
	
	return sightAmount, hidden, night_time
end

---
--- Checks if the current unit can see the specified target.
---
--- @param other Unit|Point The target to check visibility for.
--- @param overridePos Point An optional position to use instead of the unit's current position.
--- @param overrideStance string An optional stance to use instead of the unit's current stance.
--- @return boolean True if the unit can see the target, false otherwise.
---
function Unit:CanSee(other, overridePos, overrideStance)
	local sight = self:GetSightRadius(other)
	local target = other
	if IsKindOf(other, "Unit") and other.visibility_override then
		target = stance_pos_pack(other.visibility_override.pos, StancesList[other.stance])
	elseif IsPoint(overridePos) then
		self = stance_pos_pack(overridePos, StancesList[overrideStance or self.stance])
	end
	if CheckLOS(target, self, sight) then
		return true
	end
	return false
end

---
--- Orients the unit to face a specific direction.
---
--- @param ... Any arguments to pass to the underlying orientation function.
---
function Unit:Face(...)
	if self.ground_orient then
		self:SetGroundOrientation(...)
	else
		CObject.Face(self, ...)
	end
end

---
--- Orients the unit to face a specific direction.
---
--- @param angle number The angle to orient the unit to, in degrees.
--- @param ... any Any additional arguments to pass to the underlying orientation function.
---
function Unit:SetOrientationAngle(angle, ...)
	if self.ground_orient then
		self:SetGroundOrientation(angle, ...)
		self.last_orientation_angle = angle
	else
		CObject.SetAngle(self, angle, ...)
		self.last_orientation_angle = nil
	end
end

--- Returns the position occupied by the unit.
---
--- @return Point The position occupied by the unit.
function Unit:GetOccupiedPos()
	return self.target_dummy and self.target_dummy:GetPos()
end

---
--- Gets the visual voxels for a unit at the specified position and stance.
---
--- @param pos Point|number The position to get the visual voxels for. If a number is provided, it is assumed to be a terrain height.
--- @param stance string The stance of the unit. If not provided, the unit's current stance is used.
--- @param voxels table A table to store the visual voxels in. If not provided, a new table is created.
--- @return table The table of visual voxels, and the position of the unit's head voxel.
---
function Unit:GetVisualVoxels(pos, stance, voxels)
	local x, y, z 
	voxels = voxels or {}
	if pos then
		if type(pos) == "number" then
			x, y, z = point_unpack(pos)
		elseif IsPoint(pos) and pos:IsValid() then
			x, y, z = pos:xyz()
		else
			return voxels
		end
	else
		if not self:IsValidPos() then
			return voxels
		end
		x, y, z = self:GetPosXYZ()
	end
	if not z then
		z = terrain.GetHeight(x, y)
	end
	local snapped_z = select(3, VoxelToWorld(WorldToVoxel(x, y, z)))
	if z - snapped_z > const.SlabSizeZ / 2 then
		z = z + const.SlabSizeZ
	end
	x, y, z = WorldToVoxel(x, y, z)
	voxels[1] = point_pack(x, y, z)
	local head_voxel
	if self.species == "Human" then
		if (stance or self.stance) == "Prone" then
			head_voxel = voxels[1]
		else
			head_voxel = point_pack(x, y, z + 1)
			voxels[#voxels + 1] = head_voxel
		end
	elseif self.species == "Crocodile" then
		local angle = self:GetOrientationAngle()
		local sina, cosa = sincos(angle)
		local slabsize = const.SlabSizeX
		local dx = MulDivRound(slabsize, cosa, 4096)
		local dy = MulDivRound(slabsize, sina, 4096)
		if dx > slabsize/2 then dx = 1 elseif dx < -slabsize/2 then dx = -1 end
		if dy > slabsize/2 then dy = 1 elseif dy < -slabsize/2 then dy = -1 end
		voxels[#voxels + 1] = point_pack(x + dx, y + dy, z)
		voxels[#voxels + 1] = point_pack(x - dx, y - dy, z)
	end
	return voxels, head_voxel or voxels[1]
end

--- Changes the stance of the unit.
---
--- @param action_id string The action ID that triggered the stance change.
--- @param cost_ap number The AP cost of the stance change.
--- @param stance string The new stance to change to.
--- @param args table Optional arguments, such as the angle to set the unit's orientation.
function Unit:ChangeStance(action_id, cost_ap, stance, args)
	self:WaitResumeOnCommandStart()
	if self.stance == stance or self.species ~= "Human" then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	local pfclass = CalcPFClass(self.team and self.team.side, stance, self.body_type)
	local pos = GetPassSlab(self, pfclass)
	if not pos then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	self:SetPos(pos)
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	PlayFX("ChangeStance", "start", self)
	self:PushDestructor(function(self)
		PlayFX("ChangeStance", "end", self)
	end)
	local angle = args and args.angle
	if stance == "Prone" then
		angle = FindProneAngle(self, nil, angle)
	end
	if angle then
		self:SetOrientationAngle(angle, not GameTimeAdvanced and 0 or 100)
	end
	self:DoChangeStance(stance)
	self:PopAndCallDestructor() -- FX
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

local AnimationStance = {
	nw_Standing_MortarIdle = "Crouch",
	nw_Standing_MortarFire = "Crouch",
}

---
--- Returns the stance of the unit based on its current state.
---
--- @return string The stance of the unit.
function Unit:GetHitStance()
	return AnimationStance[self:GetStateText()] or self.stance
end

---
--- Determines whether the unit can stealth based on its current state and stance.
---
--- @param stance (optional) string The stance to check for stealthiness. If not provided, uses the unit's current stance.
--- @return boolean Whether the unit can stealth in the given or current stance.
function Unit:CanStealth(stance)
	if not self.team or self.team.side == "neutral"
		or not self:IsValidPos()
		or self:IsDead()
		or self:IsDowned()
		or self.command == "ExitCombat" and not self:HasStatusEffect("Hidden")
	then
		return false
	end
	stance = stance or self.stance
	local is_stealthy_stance
	if self.species == "Human" then
		is_stealthy_stance = stance ~= "Standing"
		if HasPerk(self, "FleetingShadow") then
			is_stealthy_stance = true
		end
	elseif self.species == "Crocodile" then
		is_stealthy_stance = true
	end
	if not is_stealthy_stance then
		return false
	end
	
	-- in combat allow Spotted units to remain Hidden for the duration of the effect
	local effects = self.StatusEffects
	local visual_contact = self.enemy_visual_contact
	if g_Combat and effects.Spotted then 
		visual_contact = false
	elseif not self:HasStatusEffect("Hidden") then
		local enemies = GetAllEnemyUnits(self)
		for _, enemy in ipairs(enemies) do
			visual_contact = visual_contact or HasVisibilityTo(enemy, self)
		end
	end
	if visual_contact then
		return false
	end
	if effects.BandagingDowned or effects.Revealed or effects.StationedMachineGun or effects.ManningEmplacement then
		return false
	end
	return true
end

---
--- Determines the stance to use for stealthiness based on the unit's species and current stance.
---
--- @param stance (optional) string The stance to check for stealthiness. If not provided, uses the unit's current stance.
--- @return string The stance to use for stealthiness.
function Unit:GetStanceToStealth(stance)
	stance = stance or self.stance
	if self.species == "Human" and stance == "Standing" and not HasPerk(self, "FleetingShadow") then
		return "Crouch"
	end
	return stance
end

---
--- Hides the unit by setting its stance to a stealthy stance and adding the "Hidden" status effect.
---
--- If the unit's current stance is not stealthy, the function will return without hiding the unit.
---
--- @param self Unit The unit to hide.
--- @return boolean True if the unit was successfully hidden, false otherwise.
function Unit:Hide()
	local stance = self:GetStanceToStealth()
	if not self:CanStealth(stance) then return end
	local wasInterruptable
	if stance ~= self.stance then
		wasInterruptable = self.interruptable
		if wasInterruptable then
			self:EndInterruptableMovement()
		end
		self:DoChangeStance(stance)
	end
	self:AddStatusEffect("Hidden")
	self:UpdateMoveAnim()
	PlayVoiceResponse(self, "BecomeHidden")
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

---
--- Unhides the unit by removing the "Hidden" status effect, updating the move animation, and resuming interruptable movement if applicable.
---
--- If the unit's current stance is not stealthy, the function will return without unhiding the unit.
---
--- @param self Unit The unit to unhide.
--- @return boolean True if the unit was successfully unhidden, false otherwise.
function Unit:Unhide()
	self.goto_hide = false
	self.goto_stance = false
	--self.marked_target_attack_args = false
	self:RemoveStatusEffect("Hidden")
	self:UpdateMoveAnim()
	if self:IsInterruptable() then
		self:BeginInterruptableMovement()
	end
end

---
--- Checks if the unit can take cover.
---
--- A unit can take cover if it is a human, its stance is not prone, and there is cover available at its current position or return position.
---
--- @param self Unit The unit to check.
--- @return boolean True if the unit can take cover, false otherwise.
function Unit:CanTakeCover()
	return self.species == "Human" and self.stance ~= "Prone" and (GetHighestCover(self.return_pos or self) or 0) > 0
end

---
--- Takes cover for the unit if it is able to do so.
---
--- The function first checks if the unit can take cover by calling the `CanTakeCover()` function. If the unit cannot take cover, the function returns without taking any action.
---
--- If the unit can take cover, the function performs the following actions:
--- - Interrupts any prepared attack the unit may have
--- - Adds the "Protected" status effect to the unit
--- - Calls the `UpdateTakeCoverAction()` function
--- - Changes the unit's stance to "Crouch"
--- - Modifies the unit object to notify any interested parties of the changes
---
--- @param self Unit The unit that is taking cover.
function Unit:TakeCover()
	if not self:CanTakeCover() then
		return
	end
	self:InterruptPreparedAttack()
	self:AddStatusEffect("Protected")
	UpdateTakeCoverAction()
	self:DoChangeStance("Crouch")

	ObjModified(self)
end

---
--- Handles the removal of the "Protected" status effect and updates the take cover action when a unit starts any movement.
---
--- This function is called in response to the `OnMsg.UnitAnyMovementStart` message, which is triggered whenever a unit starts moving.
---
--- When a unit starts moving, this function removes the "Protected" status effect from the unit, which indicates that the unit is in cover. It then calls the `UpdateTakeCoverAction()` function to update the take cover action for the unit.
---
--- @param unit Unit The unit that has started moving.
function OnMsg.UnitAnyMovementStart(unit)
	unit:RemoveStatusEffect("Protected")
	UpdateTakeCoverAction()
end

function OnMsg.UnitStanceChanged(unit)
	if unit.stance ~= "Crouch" then
		unit:RemoveStatusEffect("Protected")
	end
end

local sneak_ui_update_thread = false

function OnMsg.UnitStealthChanged(obj)
	if obj == SelectedObj or table.find(Selection or empty_table, obj) then
		sneak_ui_update_thread = sneak_ui_update_thread or CreateGameTimeThread(function()
			while obj.command == "ExitCombat" do
				Sleep(100)
			end
		
			ObjModified("combat_bar")
			sneak_ui_update_thread = false
		end)
	end
end

---
--- Updates the hidden status of the unit.
---
--- If the unit has the "Hidden" status effect, it checks if the unit can still stealth. If not, it removes the "Hidden" status effect and updates the FX class.
---
--- If the unit is not human, it checks if the unit can stealth. If so, it adds the "Hidden" status effect, plays a voice response, and updates the FX class.
---
--- @param self Unit The unit to update the hidden status for.
function Unit:UpdateHidden()
	if self:HasStatusEffect("Hidden") then
		if not self:CanStealth() then
			self:RemoveStatusEffect("Hidden")
			self:UpdateFXClass()
		end
	elseif self.species ~= "Human" then
		if self:CanStealth() then
			self:AddStatusEffect("Hidden")
			PlayVoiceResponse(self, "BecomeHidden")
			self:UpdateFXClass()
		end
	end
end

-- used to control the fx actor class of the unit based on his Hidden status and self.visible
---
--- Updates the FX actor class of the unit based on its visibility, species, and gender.
---
--- If the unit is not visible, the FX actor class is set to "Hidden".
--- If the unit is a mercenary, the FX actor class is set to "ImportantUnit".
--- If the unit is not human, the FX actor class is set to the unit's species.
--- If the unit is an ambient unit, the FX actor class is set based on the unit's gender ("AmbientMale", "AmbientFemale", or "AmbientUnit").
--- Otherwise, the FX actor class is set based on the unit's gender ("Male", "Female", or "Unit").
---
--- @param self Unit The unit to update the FX actor class for.
function Unit:UpdateFXClass()
	if not self.visible then
		self.fx_actor_class = "Hidden"
	elseif IsMerc(self) then
		self.fx_actor_class = "ImportantUnit"
	elseif self.species ~= "Human" then
		self.fx_actor_class = self.species
	elseif self:IsAmbientUnit() then
		if self.gender == "Male" then
			self.fx_actor_class = "AmbientMale"
		elseif self.gender == "Female" then
			self.fx_actor_class = "AmbientFemale"
		else
			self.fx_actor_class = "AmbientUnit"
		end
	else
		if self.gender == "Male" then
			self.fx_actor_class = "Male"
		elseif self.gender == "Female" then
			self.fx_actor_class = "Female"
		else
			self.fx_actor_class = "Unit"
		end
	end
end

function OnMsg.GetCustomFXInheritActorRules(rules)
	-- unit
	rules[#rules + 1] = "Male"
	rules[#rules + 1] = "Unit"
	rules[#rules + 1] = "Female"
	rules[#rules + 1] = "Unit"
	rules[#rules + 1] = "ImportantUnit"
	rules[#rules + 1] = "Unit"
	rules[#rules + 1] = "AmbientUnit"
	rules[#rules + 1] = "Unit"
	-- gender
	rules[#rules + 1] = "AmbientMale"
	rules[#rules + 1] = "Male"
	rules[#rules + 1] = "AmbientMale"
	rules[#rules + 1] = "AmbientUnit"
	rules[#rules + 1] = "AmbientFemale"
	rules[#rules + 1] = "Female"
	rules[#rules + 1] = "AmbientFemale"
	rules[#rules + 1] = "AmbientUnit"
end

local function UpdateHiddenUnits()
	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, unit in ipairs(team.units) do
				unit:UpdateHidden()
			end
		end
	end
end

function OnMsg.UnitMovementDone(obj)
	if GameState.sync_loading then return end
	obj:RemoveStatusEffect("Focused")
	UpdateHiddenUnits()
	NetUpdateHash("UnitMovement", obj, obj:GetPosXYZ())
end

OnMsg.SyncLoadingDone = UpdateHiddenUnits
OnMsg.ExplorationStart = UpdateHiddenUnits

---
--- Changes the stance of the unit.
---
--- @param stance string The new stance for the unit.
--- @return nil
function Unit:GotoChangeStance(stance)
	if not stance or self.stance == stance then
		return
	end
	if not self:CanSwitchStance(stance) then
		return
	end
	local prev_stance = self.stance
	self.stance = stance
	ObjModified(self)
	self:UpdateMoveAnim()
	self:ChangePathFlags(const.pfDirty)
	self:UpdateHidden()
	ObjModified(self)
	if stance == "Prone" or prev_stance == "Prone" then
		local base_idle = self:GetIdleBaseAnim()
		PlayTransitionAnims(self, base_idle)
	end
	Msg("UnitStanceChanged", self)
end

---
--- Changes the stance of the unit.
---
--- @param stance string The new stance for the unit.
--- @return nil
function Unit:DoChangeStance(stance)
	assert(self.species == "Human" or stance == "")
	self.stance = HasPerk(self, "ZombiePerk") and "Standing" or stance
	self.aim_results = false
	self.aim_attack_args = false
	ObjModified(self)
	self:SetFootPlant(true)
	self:SetTargetDummyFromPos()
	self:UpdateMoveAnim()
	if GameTimeAdvanced then
		local base_idle = self:GetIdleBaseAnim()
		local angle = (self.target_dummy or self):GetOrientationAngle()
		PlayTransitionAnims(self, base_idle, angle)
		if not g_Combat and self.command ~= "ExitCombat" and self.command ~= "TakeCover" and self.command ~= "FallDown" then
			self:GotoSlab(self:GetPos())
		end
	end
	self:UpdateHidden()
	ObjModified(self)
	Msg("UnitStanceChanged", self)
end

if FirstLoad then
	g_StanceToStanceAP = {}
end
local function UpdateStanceToStanceAPCache()
	g_StanceToStanceAP = {}
	ForEachPresetInGroup("StanceToStanceAP", "Default", function(def)
		local t = g_StanceToStanceAP[def.start_stance]
		if not t then
			t = {}
			g_StanceToStanceAP[def.start_stance] = t
		end
		t[def.end_stance] = def.ap_cost
	end)
end
OnMsg.DataLoaded = UpdateStanceToStanceAPCache
OnMsg.PresetSave = UpdateStanceToStanceAPCache

---
--- Gets the action point cost for changing from one stance to another.
---
--- @param start_stance string The starting stance.
--- @param end_stance string The ending stance.
--- @return number The action point cost for the stance change, or 0 if the stances are the same.
function GetStanceToStanceAP(start_stance, end_stance)
	if start_stance == end_stance then
		return 0
	end
	return (g_StanceToStanceAP[start_stance] or empty_table)[end_stance]
end

---
--- Gets the action point cost for changing from the unit's current stance to the specified stance.
---
--- @param stance string The stance to change to.
--- @param ownStanceOverride string (optional) The unit's current stance, overriding the actual stance.
--- @return number The action point cost for the stance change, or -1 if the stances are the same.
function Unit:GetStanceToStanceAP(stance, ownStanceOverride)
	local currentStance = ownStanceOverride or self.stance
	if stance == currentStance then 
		return -1 
	end
	
	if HasPerk(self, "HitTheDeck") and stance == "Prone" then return 0 end
	
	return GetStanceToStanceAP(currentStance, stance) or 0	
end

---
--- Gets the archetype of the unit.
---
--- @param self Unit The unit object.
--- @return table The archetype of the unit, or the default Soldier archetype if the unit's archetype is not found.
function Unit:GetArchetype()	
	local arch = Archetypes[self.script_archetype]
	if arch then
		return arch
	end
	return Archetypes[self.current_archetype] or Archetypes.Soldier
end

---
--- Gets the archetype of the unit.
---
--- @param self Unit The unit object.
--- @return table The archetype of the unit, or the default Soldier archetype if the unit's archetype is not found.
function Unit:GetCurrentArchetype()
	return Archetypes[self.current_archetype] or Archetypes.Soldier
end

-- equipped items wihtout weapons, like Grenade, Medicine...
---
--- Gets the equipped quick items for the unit.
---
--- @param self Unit The unit object.
--- @param class string (optional) The class of the items to retrieve.
--- @param slot_name string (optional) The name of the slot to retrieve items from.
--- @return table The list of equipped quick items.
function Unit:GetEquippedQuickItems(class, slot_name)
	local items = {}
	self:ForEachItemInSlot(slot_name,class,function(item, s, l,t, items)
		if not item:IsWeapon() then
			items[#items+1] = item
		end	
	end, items)
	return items
end

---
--- Gets the active weapons for the unit.
---
--- @param self Unit The unit object.
--- @param class string (optional) The class of the weapons to retrieve.
--- @param strict_order boolean (optional) If true, the weapons will be returned in the order they were equipped.
--- @return FirearmBase, FirearmBase, table The first active weapon, the second active weapon, and the list of all active weapons.
function Unit:GetActiveWeapons(class, strict_order)
	if class == "UnarmedWeapon" then
		self.unarmed_weapon = self.unarmed_weapon or g_UnarmedWeapon
		return self.unarmed_weapon, nil, { self.unarmed_weapon }
	end

	if self:GetStatusEffect("ManningEmplacement") then
		local handle = self:GetEffectValue("hmg_emplacement")
		local obj = HandleToObject[handle]
		if obj and obj.weapon and (not class or IsKindOf(obj.weapon, class)) then
			obj.weapon.emplacement_weapon = true
			return obj.weapon, nil, { obj.weapon }
		end
	end
	
	local slot
	if IsSetpiecePlaying() and IsSetpieceActor(self) then
		slot = "SetpieceWeapon"
	else
		slot = self.current_weapon
	end

	self.combat_cache = self.combat_cache or {}
	local key = string.format("%s_%s%s", slot, class or "all", strict_order and "-strict" or "")
	local weapons = self.combat_cache[key]
	if not weapons then
		weapons = {}
		local firearms = {}
		self.combat_cache[key] = weapons
		local equipped = self:GetEquippedWeapons(slot)
		if slot == "SetpieceWeapon" and (#(equipped or empty_table) == 0) then
			equipped = self:GetEquippedWeapons(self.current_weapon)
		end

		for _, o in ipairs(equipped) do
			local match = not class or (class ~= "Firearm") or not IsKindOfClasses(o, "HeavyWeapon", "FlareGun")
			match = match and (not class or IsKindOf(o, class))
			if match then
				table.insert(weapons, o)
			end
			if IsKindOf(o, "FirearmBase") then
				table.insert(firearms, o)
			end
		end		
		-- second pass to add subweapons at the end of the list
		for _, item in ipairs(firearms) do
			for slot, weapon in sorted_pairs(item.subweapons) do
				local match = not class or (class ~= "Firearm") or not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun")
				match = match and (not class or IsKindOf(weapon, class))
				if match then
					table.insert(weapons, weapon)
				end
			end
		end
	end
	
	-- If weapon1 is exhausted and weapon 2 isnt then weapon2 is the main weapon
	if not strict_order then
		local weapon1Exhausted = not self:CanUseWeapon(weapons[1])
		local weapon2Exhausted = not self:CanUseWeapon(weapons[2])
		local weapon2IsntSubWeapon = weapons[1] and weapons[2] and not weapons[2].parent_weapon
		if weapons[1] and weapons[2] and weapon1Exhausted and not weapon2Exhausted and weapon2IsntSubWeapon then
			weapons[1], weapons[2] = weapons[2], weapons[1]
		end
	end
	
	return weapons[1], weapons[2], weapons
end

---
--- Gets a weapon by its definition ID or returns the default weapon.
---
--- @param class string|nil The class of the weapon to get.
--- @param def_id string|nil The definition ID of the weapon to get.
--- @param packed_pos integer|nil The packed position of the weapon to get.
--- @param item_id integer|nil The ID of the weapon to get.
--- @return FirearmBase|nil The weapon, or nil if not found.
function UnitProperties:GetWeaponByDefIdOrDefault(class, def_id, packed_pos, item_id)
	if packed_pos then
		local weapon = self:GetItemAtPackedPos(packed_pos)
		return weapon
	else	
		local weapons = self:GetEquippedWeapons(self.current_weapon)
		local alt_slot = self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
		table.iappend(weapons, self:GetEquippedWeapons(alt_slot))
		table.iappend(weapons, self:GetEquippedWeapons("Inventory"))
		local n = #weapons
		for i = 1, n do
			local weapon = weapons[i]
			if IsKindOf(weapon, "FirearmBase") then
				for _, sub in sorted_pairs(weapon.subweapons) do
					weapons[#weapons + 1] = sub
				end
			end
		end
		local matched
		if def_id then
			matched = table.ifilter(weapons, function(idx, item) return IsKindOf(item, def_id) end)
		end
		if #(matched or empty_table) == 0 then
			matched = weapons
		end
		if item_id then
			for _, weapon in ipairs(matched) do
				if weapon.id == item_id then
					return weapon
				end
			end
		end
		return matched[1]
	end
end

---
--- Checks if the given weapon is out of ammo.
---
--- @param weapon FirearmBase|nil The weapon to check. If nil, the active weapon is used.
--- @param amount integer|nil The minimum amount of ammo required. If nil, 1 is used.
--- @return boolean True if the weapon is out of ammo, false otherwise.
function Unit:OutOfAmmo(weapon, amount)
	weapon = weapon or self:GetActiveWeapons()
	return weapon and weapon:HasMember("ammo") and (not weapon.ammo or weapon.ammo.Amount < (amount or 1))
end

---
--- Returns the current sector the unit is in.
---
--- @return Sector The current sector.
function Unit:GetSector()
	return gv_Sectors[gv_CurrentSectorId]
end

---
--- Checks if the given weapon is jammed.
---
--- @param weapon FirearmBase|nil The weapon to check. If nil, the active weapon is used.
--- @return boolean True if the weapon is jammed, false otherwise.
function Unit:IsWeaponJammed(weapon)
	weapon = weapon or self:GetActiveWeapons()
	return IsKindOf(weapon, "Firearm") and weapon.jammed
end

---
--- Checks if the given weapon can be used by the unit.
---
--- @param weapon FirearmBase|nil The weapon to check. If nil, the active weapon is used.
--- @param num_shots integer|nil The minimum number of shots required. If nil, 1 is used.
--- @return boolean True if the weapon can be used, false otherwise.
--- @return string|nil The reason why the weapon cannot be used, if any.
function Unit:CanUseWeapon(weapon, num_shots)
	if not weapon then
		return false, AttackDisableReasons.NoWeapon
	elseif weapon.Condition <= 0 then
		return false, AttackDisableReasons.WeaponBroken
	end
	if IsKindOf(weapon, "Firearm") then
		if weapon.jammed then
			return false, AttackDisableReasons.WeaponJammed
		elseif not weapon.ammo or weapon.ammo.Amount < (num_shots or 1) then
			return false, AttackDisableReasons.OutOfAmmo
		end
	end
	return true
end

AttackDisableReasons = {
	NoAP = T(526265371339, "<error>Insufficient AP</error>"),
	NoWeapon = T(379423324402, "<error>No active weapon</error>"),
	WeaponJammed = T(522229430242, "<error>The weapon is jammed</error>"),
	WeaponBroken = T(187856566334, "<error>The weapon is broken</error>"),
	OutOfAmmo = T(694516627561, "<error>Out of ammo</error>"),
	InsufficientAmmo = T(48284763278, "<error>Not enough ammo</error>"),
	InvalidTarget = T(332327094836, "<error>Invalid target</error>"),
	InvalidSelfTarget = T(858041242091, "<error>Cannot target self</error>"),
	NoTeamSight = T(308212362965, "<error>Out of team sight</error>"),
	NoTeamSightLivewire = T(316258123370, "<error>Out of sight (Livewire)</error>"),
	NoTarget = T(282471750002, "<error>No target</error>"),
	NoBandageTarget = T(409300745676, "<error>No target. Mercs with lowered max HP are healed in the Sat View.</error>"),
	OutOfRange = T(460146513440, "<error>Out Of Range</error>"),
	ExtremeRange = T(990882650338, "<error>Extreme range</error>"),
	CantReach = T(533577783995, "<error>Can't reach</error>"),
	NoLoS = T(871138850086, "<error>No line of sight</error>"),
	InsufficientMeds = T(589775173410, "<error>Not enough Meds</error>"),
	FullHP = T(270490338639, "<error>At full health</error>"),
	NoLockpick = T(179588362502, "<error>Can't pick a lock without a lockpick</error>"),
	NoCrowbar = T(871669664824, "<error>You need a crowbar to attempt to break this</error>"),
	NoCutters = T(457726671611, "<error>You need a wire cutter.</error>"),
	OnlyStanding = T(589960103330, "<error>Only available in Standing stance</error>"),
	Cooldown = T(591766545566, "<error>This action can be used once per turn</error>"),
	BandagingDowned = T(216477918933, "<error>Currently treating a downed ally</error>"),
	NoAmmo = T(958927508781, "<error>Out of ammo for this weapon</error>"),
	FullClip = T(342527613232, "<error>This weapon is already fully loaded</error>"),
	FullClipHaveOther = T(193803534966, "<error>This weapon is already fully loaded. You can change the ammo type from the inventory.</error>"),
	SignatureRecharge = T(422255119652, "<error>Can only be used once per conflict</error>"),
	SignatureRechargeOnKill = T(895217484195, "<error>Recharges on kill with another attack.</error>"),
	Water = T(389919921473, "<error>Not allowed in water</error>"),
	Stairs = T(377843918366, "<error>Not allowed on stairs</error>"),
	Impassable = T(150460717914, "<error>Impassable</error>"),
	Occupied = T(173250243531, "<error>Occupied</error>"),
	Indoors = T(927774491188, "<error>Cannot use indoors</error>"),
	InEnemySight = T(749326574456, "<error>You cannot sneak while in enemy sight.</error>"),
	Revealed = T(393250883796, "<error>You revealed yourself to the enemies and cannot sneak this turn.</error>"),
	CannotSneak = T(637272145762, "<error>You cannot sneak at this time.</error>"),
	WrongWeapon = T(734977105577, "<error>Wrong active weapon.</error>"),
	RangedWeapon = T(464635588615, "<error>Requires a Firearm.</error>"),
	MacheteWeapon = T(899395755721, "<error>Requires a Machete.</error>"),
	KnifeWeapon = T(270404087675, "<error>Requires a Knife.</error>"),
	CombatOnly = T(607543203128, "<error>Must be used during combat</error>"), 
	RequiresMachineGun = T(293921437394, "<error>Requires a Machine Gun</error>"), 
	RequiresUnarmed = T(252038182681, "<error>Must be Unarmed</error>"),
	NotInCover = T(553368221470, "<error>Only available in cover spots</error>"),
	AlreadyActive = T(492570194020, "Already active"),
	NotInMeleeRange = T(863084049025, "<error>Approach to attack</error>"),
	NotInBandageRange = T(576945352567, "<error>Approach to bandage</error>"),
	NotSneaking = T(465045630742, "<error>Must be sneaking</error>"),
	MinDist =  T(753745088840, "<error>Too close</error>"),
	NoLine =  T(127026985840, "<error>Straight path required</error>"),
	TooFar = T(137552442717, "<error>Too Far</error>"),
	UsingMachineGun = T(504207281345, "<error>Currently operating a machine gun</error>"),
	NoFireArc = T(698332993342, "<error>No fire arc</error>"),
}

---
--- Returns the appropriate attack disable reason for a unit when it has no action points.
---
--- @param unit Unit The unit to check for attack disable reasons.
--- @return string The attack disable reason, or nil if the unit can attack.
function GetUnitNoApReason(unit)
	if unit:GetBandageTarget() then
		return AttackDisableReasons.BandagingDowned
	end
	return AttackDisableReasons.NoAP
end

---
--- Sets the effect value for the specified effect ID on the unit.
---
--- @param id string The ID of the effect.
--- @param value any The value to set for the effect.
function Unit:SetEffectValue(id, value)
	self.effect_values = self.effect_values or {}
	self.effect_values[id] = value or nil
end

---
--- Gets the value of the specified effect on the unit.
---
--- @param id string The ID of the effect.
--- @return any The value of the effect, or nil if the effect is not set.
function Unit:GetEffectValue(id)
	return self.effect_values and self.effect_values[id]
end

---
--- Gets the expiration turn for the specified effect on the unit.
---
--- @param id string The ID of the effect.
--- @param key string The key of the effect.
--- @return integer The turn when the effect expires, or -1 if the effect is not set.
function Unit:GetEffectExpirationTurn(id, key)
	local store_key = string.format("%s:%s", id, key)
	return self.effect_values and self.effect_values[store_key] or -1
end

---
--- Sets the expiration turn for the specified effect on the unit.
---
--- @param id string The ID of the effect.
--- @param key string The key of the effect.
--- @param turn integer The turn when the effect expires.
function Unit:SetEffectExpirationTurn(id, key, turn)
	local store_key = string.format("%s:%s", id, key)
	self.effect_values = self.effect_values or {}
	self.effect_values[store_key] = Max(turn, self.effect_values[store_key] or -1)
end

---
--- Checks if the unit can attack the specified target with the given action.
---
--- @param target CombatObject|Point The target to attack.
--- @param weapon Weapon The weapon to use for the attack.
--- @param action CombatAction The action to perform.
--- @param aim boolean Whether the attack is a free aim.
--- @param goto_pos Point The position to move to before attacking.
--- @param skip_ap_check boolean Whether to skip the AP cost check.
--- @param is_free_aim boolean Whether the attack is a free aim.
--- @return boolean Whether the unit can attack the target.
--- @return string|nil The reason why the unit cannot attack the target, or nil if the unit can attack.
function Unit:CanAttack(target, weapon, action, aim, goto_pos, skip_ap_check, is_free_aim)
	if GetInGameInterfaceMode() == "IModeDeployment" then
		return false
	end
	if action.ActionType ~= "Melee Attack" and action.ActionType ~= "Ranged Attack" then 
		return false
	end
	local args
	if action then
		if action.ActionType == "Melee Attack" and target == self then
			return false, AttackDisableReasons.InvalidSelfTarget
		end
		if (action.ActionType == "Melee Attack" and action.AimType ~= "melee-charge") and IsValid(target) then
			if IsKindOf(target.traverse_tunnel, "SlabTunnelLadder") then
				return false, AttackDisableReasons.InvalidTarget
			end
			if not IsMeleeRangeTarget(self, goto_pos, nil, target) then
				local attack_pos = self:GetClosestMeleeRangePos(target)
				if not attack_pos or (IsKindOf(target, "Unit") and not IsMeleeRangeTarget(self, attack_pos, nil, target)) then
					return false, AttackDisableReasons.CantReach
				end
				local reason = g_Combat and AttackDisableReasons.CantReach or AttackDisableReasons.TooFar
				--[[if attack_pos then
					local cpath = GetCombatPath(self)
					local ap = cpath and cpath:GetAP(attack_pos)
					if ap and action:GetAPCost(self, args) <= self.ActionPoints - ap then
						reason = AttackDisableReasons.NotInMeleeRange
					end
				end
				return false, reason--]]
				if attack_pos then
					--local cpath = GetCombatPath(self)
					--local ap = cpath and cpath:GetAP(attack_pos)
					--if not ap or action:GetAPCost(self, args) > self.ActionPoints - ap then
					args = args or { target = target, goto_pos = attack_pos, aim = aim, ap_cost_breakdown = {} }
					local cost = action:GetAPCost(self, args)
					if cost < 0 or cost > self.ActionPoints then
						return false, reason
					end
				else
					return false, reason
				end
			end
		end
		if action.ActionType == "Ranged Attack" and target == self then -- no
			return false, AttackDisableReasons.InvalidTarget
		end
		if action.id == "UnarmedAttack" or action.id == "ExplodingPalm" or (action.id == "Brutalize" and not weapon) or action.id == "MarkTarget" then
			weapon = self:GetActiveWeapons("UnarmedWeapon")
		end
		if action.group == "SignatureAbilities" then
			local recharge = self:GetSignatureRecharge(action.id)
			if recharge then
				if recharge.on_kill then
					return false, AttackDisableReasons.SignatureRechargeOnKill
				end
				return false, AttackDisableReasons.SignatureRecharge
			end
		end
		if g_Combat and self:GetEffectExpirationTurn(action.id, "cooldown") >= g_Combat.current_turn then
			return false, AttackDisableReasons.Cooldown
		elseif not skip_ap_check and (g_Combat or g_StartingCombat or g_TestingSaveLoadSystem) then
			args = args or { target = target, goto_pos = goto_pos, aim = aim, ap_cost_breakdown = {} }
			local cost = action:GetAPCost(self, args)
			if not self:HasAP(cost, action.id, args) then
				return false, GetUnitNoApReason(self)
			end
		end
		if action.id == "OnMyTarget" then
			return true
		elseif action.id == "MGBurstFire" then
			if target and not CombatActionTargetFilters.MGBurstFire(target, {self}) then
				return false, AttackDisableReasons.OutOfRange
			end
		elseif action.id == "Bombard" or action.id == "FireFlare" then
			if self.indoors then
				return false, AttackDisableReasons.Indoors
			end
		elseif action.id == "PinDown" then
			if not CombatActionTargetFilters.Pindown(target, self, weapon) then
				return false, AttackDisableReasons.InvalidTarget
			end
		end
	end

	if not weapon then
		return false, AttackDisableReasons.NoWeapon
	elseif (weapon.Condition or 100) <= 0 then
		return false, AttackDisableReasons.WeaponBroken
	end

	if IsKindOf(weapon, "Grenade") or (IsKindOf(weapon, "HeavyWeapon") and weapon.trajectory_type == "parabola") then
		if action and target then
			local range = action:GetMaxAimRange(self, weapon)
			if goto_pos then
				if goto_pos:Dist(target) > range * const.SlabSizeX then
					return false, AttackDisableReasons.OutOfRange
				end 
			else
				if self:GetDist(target) > range * const.SlabSizeX then
					return false, AttackDisableReasons.OutOfRange
				end
			end

			args = args or { target = target, goto_pos = goto_pos, aim = aim, ap_cost_breakdown = {} }
			local results = action:GetActionResults(self, args)
			if not results.trajectory or #results.trajectory == 0 then
				return false, AttackDisableReasons.NoFireArc
			end
		end
		return true
	end

	local fireArm = IsKindOf(weapon, "Firearm")
	if fireArm and weapon.jammed then
		return false, AttackDisableReasons.WeaponJammed
	end

	local ammo_amount = fireArm and weapon:GetAutofireShots(action) or 1
	local min_ammo_amount = action:ResolveValue("min_shots")
	if fireArm and not ammo_amount then
		local params = weapon:GetAreaAttackParams(action.id, self)
		ammo_amount = params and params.used_ammo
	end
	ammo_amount = Min(ammo_amount or 1, min_ammo_amount or ammo_amount or 1)
	if action.ActionType ~= "Other" and self:OutOfAmmo(weapon, ammo_amount) then -- Non-attack actions dont require ammo
		return false, AttackDisableReasons.OutOfAmmo
	end

	if IsKindOf(weapon, "MeleeWeapon") and action.ActionType == "Ranged Attack" and target then
		local range = action:GetMaxAimRange(self, weapon)
		local attack_pos = goto_pos or self:GetPos()
		local target_pos = IsPoint(target) and target or target:GetPos()
		if attack_pos:Dist(target_pos) > range * const.SlabSizeX then
			return false, AttackDisableReasons.OutOfRange
		end
	end

	-- If you give me a target I will check it no matter whether you require one.
	local optionalTargetAndNoTarget = not action.RequireTargets and not target
	local invalidObjectTarget = not action.RequireTargets and not IsValid(target) and not IsPoint(target)
	local pointTarget = not action.RequireTargets and IsPoint(target)
	 
	if optionalTargetAndNoTarget or invalidObjectTarget or pointTarget then return true end
	local targetIsUnit = IsKindOf(target, "Unit")
	local targetIsTrap = IsKindOf(target, "Trap")
	local freeAimMeleeTarget = IsValid(target) and is_free_aim and action.ActionType == "Melee Attack"

	if not target and action.RequireTargets then
		return false, AttackDisableReasons.NoTarget
	end
	
	if not targetIsUnit and action.id == "Brutalize" then
		return false, AttackDisableReasons.InvalidTarget
	end

	if not targetIsUnit and not targetIsTrap and not freeAimMeleeTarget then
		return false, AttackDisableReasons.InvalidTarget
	end

	-- all attacks should be able to target all units except dead/defeated
	if targetIsUnit and (target:IsDead() or target:IsDefeatedVillain()) then
		return false, AttackDisableReasons.InvalidTarget
	end

	return true, false
end

---
--- Calculates the move modifier for the unit based on its current stance and the specified action ID.
---
--- @param stance string|nil The stance of the unit. If not provided, the current stance is used.
--- @param action_id string|nil The ID of the action. If not provided, "Move" is used.
--- @return number The move modifier value.
function Unit:GetMoveModifier(stance, action_id)
	stance = stance or self.stance
	action_id = action_id or "Move"

	local modValue = 0
	
	if self:HasStatusEffect("Hidden") then
		modValue = modValue + Hidden:ResolveValue("ap_cost_modifier")
	end

	if GameState.DustStorm then
		modValue = modValue + const.EnvEffects.DustStormMoveCostMod
	end
	modValue = self:CallReactions_Modify("OnCalcMoveModifier", modValue, CombatActions[action_id])

	return modValue
end

---
--- Returns the UI-scaled action points for the unit.
---
--- @return number The UI-scaled action points.
function Unit:GetUIScaledAP()
	return self:GetUIActionPoints() / const.Scale.AP
end

---
--- Returns the UI-scaled maximum action points for the unit.
---
--- @return number The UI-scaled maximum action points.
function Unit:GetUIScaledAPMax()
	local max = Max(self:GetMaxActionPoints(), self:GetUIActionPoints())
	return max / const.Scale.AP
end

---
--- Gathers and modifies the chance to hit (CTH) modifiers for an attack.
---
--- @param id string The identifier for the CTH modifier.
--- @param value number The base chance to hit value.
--- @param data table A table containing information about the attack, including the action, target, and weapons.
--- @return number The modified chance to hit value.
function Unit:GatherCTHModifications(id, value, data)
	if not id then return end
	
	data.meta_text = data.meta_text or {}
	data.mod_mul = 100
	data.mod_add = 0
	data.base_chance = value
	data.enabled = true

	Msg("GatherCTHModifications", self, id, data.action.id, data.target, data.weapon1, data.weapon2, data)
	self:CallReactions("OnModifyCTHModifier", id, self, data.target, data.action, data.weapon1, data.weapon2, data)
	if IsKindOf(data.target, "Unit") then
		data.target:CallReactions("OnModifyCTHModifier", id, self, data.target, data.action, data.weapon1, data.weapon2, data)
	end
	value = data.enabled and MulDivRound(value + data.mod_add, data.mod_mul, 100) or 0
	return value
end

---
--- Calculates the chance to hit (CTH) for an attack.
---
--- @param target CombatObject|Point The target of the attack.
--- @param action CombatAction The action being performed.
--- @param args table A table of optional arguments, including:
---   - weapon: the weapon being used for the attack
---   - target_spot_group: the body part being targeted
---   - aim: the aim modifier for the attack
---   - opportunity_attack: whether this is an opportunity attack
---   - step_pos: the position the attacker is stepping to
---   - goto_pos: the position the attacker is moving to
---   - target_pos: the position of the target
---   - prediction: whether this is a prediction calculation
--- @param chance_only boolean If true, only the final chance to hit is returned.
--- @return number The final chance to hit, base chance to hit, a table of modifiers, and the accuracy penalty.
function Unit:CalcChanceToHit(target, action, args, chance_only)
	-- Argument validation and fallbacks
	if not (IsPoint(target) or IsValid(target) and IsKindOf(target, "CombatObject")) then
		return 0
	end
	local weapon1, weapon2 = action:GetAttackWeapons(self)
	local weapon = args and args.weapon or weapon1
	if not weapon or IsKindOf(weapon, "Medicine") then
		return 0
	end

	local modifiers = not chance_only and {}
	
	if CheatEnabled("AlwaysHit") then
		if modifiers then 
			modifiers[#modifiers + 1] = {
				name = T(521586645369, "Cheat: Always Hit"),
				value = 100,
				id = "cheat"
			}
		end
		return 100, 100, modifiers
	elseif CheatEnabled("AlwaysMiss") then
		if modifiers then
			modifiers[#modifiers + 1] = {
				name = T(455715392693, "Cheat: Always Miss"),
				value = 0,
				id = "cheat"
			}
		end
		return 0, 0, modifiers
	end

	local target_spot_group = args and args.target_spot_group or nil
	if type(target_spot_group) == "table" then
		target_spot_group = target_spot_group.id
	end
	target_spot_group = target_spot_group or g_DefaultShotBodyPart
	if type(target_spot_group) == "string" then
		target_spot_group = Presets.TargetBodyPart.Default[target_spot_group]
	end

	local aim = args and args.aim or 0
	local opportunity_attack = args and args.opportunity_attack
	local attacker_pos = args and (args.step_pos or args.goto_pos) or self:GetPos()
	local target_pos = args and args.target_pos or IsPoint(target) and target or target:GetPos()

	local base = 0

	-- Base CTH
	local skill = self[weapon.base_skill]
	if action.id == "SteroidPunch" then
		skill = self["Strength"]
	end
	base = base + skill
	
	if args and not args.prediction then
		local effects = {}
		for i, effect in ipairs(self.StatusEffects) do
			effects[i] = effect.class
		end
		effects = table.concat(effects, ",")
		local target_effects = "-"
		if IsKindOf(target, "Unit") then
			target_effects = {}
			for i, effect in ipairs(target.StatusEffects) do
				target_effects[i] = effect.class
			end
			target_effects = table.concat(target_effects, ",")
		end
		NetUpdateHash("CalcChanceToHit_Base", self, target, action.id, weapon.class, weapon.id, base, effects, target_effects,
			weapon1 and weapon1.class, weapon1 and weapon1.id, weapon1 and weapon1.Condition, weapon1 and weapon1.MaxCondition,
			weapon2 and weapon2.class, weapon2 and weapon2.id, weapon2 and weapon2.Condition, weapon2 and weapon2.MaxCondition
		)
	end
	
	if modifiers then
		self.combat_cache = self.combat_cache or {}
		local key = "base_cth_" .. weapon.base_skill
		local skillmod = self.combat_cache[key]
		if not skillmod then
			local prop_meta = self:GetPropertyMetadata(weapon.base_skill)
			if prop_meta then
				skillmod =
				{
					name = prop_meta.name,
					value = skill
				}
			else
				assert(false, "weapon base skill '" .. weapon.base_skill .. "' property metadata not found!")
				skillmod =
				{
					name = T(462143455900, "Marksmanship"),
					value = skill
				}
			end
			self.combat_cache[key] = skillmod
		end
		table.insert(modifiers, skillmod)
	end

	local mod_data = {
		attacker = self,
		target = target,
		target_spot_group = target_spot_group,
		action = action, 
		weapon1 = weapon1, 
		weapon2 = weapon2, 
		aim = aim, 
		opportunity_attack = opportunity_attack, 
		attacker_pos = attacker_pos, 
		target_pos = target_pos,
		min = 0,
		max = 100,
	}


	-- Evaluate all modifiers
	ForEachPreset("ChanceToHitModifier", function(mod)
		if mod.RequireTarget and not IsValidTarget(target) then
			return
		end
		local req_action = mod.RequireActionType
		if req_action == "Any Attack" then
			if action.ActionType == "Other" then
				return
			end
		elseif req_action == "Any Melee Attack" then
			if action.ActionType ~= "Melee Attack" then
				return
			end
		elseif req_action == "Any Ranged Attack" then
			if action.ActionType ~= "Ranged Attack" then
				return
			end
		elseif req_action ~= action.id then
			return
		end
		
		local lof = false -- Currently unused by any modifier
		local apply, value, nameOverride, metaText, idOverride = mod:CalcValue(self, target, target_spot_group, action, weapon, weapon2, lof, aim, opportunity_attack, attacker_pos, target_pos)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Modifier", mod.id, apply, value)
		end
		if not apply then
			return
		end
		-- automated GatherCTHModifications provide a standard mechanism for replacing display name & adding meta text (only for the applicable mods)
		mod_data.display_name = nameOverride or mod.display_name
		mod_data.meta_text = (IsT(metaText) and {metaText} or metaText) or nil
		value = self:GatherCTHModifications(mod.id, value, mod_data)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Modifier_Mods", mod.id, value)
		end
		local nameOverride = mod_data.display_name
		local metaText = #mod_data.meta_text > 0 and mod_data.meta_text
		base = base + value
		if mod_data.enabled and modifiers then
			table.insert(modifiers, 
			{ 
				name = nameOverride or mod.display_name,
				value = value,
				id = idOverride or mod.id,
				metaText = metaText
			})
		end
	end)
	
	-- cycle status effects, running GatherCTHModifications() for every one of them, using the effect class/id as mod id
		-- this way status effects can implement their own cth modifiers via the same mechanism
	for _, effect in ipairs(self.StatusEffects) do
		mod_data.display_name = effect.DisplayName
		mod_data.meta_text = nil
		local value = self:GatherCTHModifications(effect.class, 0, mod_data)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Effect_Mods", effect.class, value)
		end
		if value and value ~= 0 then
			base = base + value
			if mod_data.enabled and modifiers then
				table.insert(modifiers, 
				{ 
					name = mod_data.display_name,
					value = value,
					id = effect.id,
					metaText = mod_data.meta_text
				})
			end
		end
	end
	
	-- process weaponcomponenteffects
	mod_data.weapon1 = nil
	mod_data.weapon2 = nil
	local weapons = {weapon1, weapon2}
	for _, weapon in ipairs(weapons) do
		if IsKindOf(weapon, "Firearm") then		
			for slot_id, component_id in sorted_pairs(weapon.components) do
				local def = WeaponComponents[component_id]
				local effects = def and def.ModificationEffects or empty_table
				if next(effects) ~= nil then
					mod_data.weapon1 = weapon
					mod_data.display_name = def.DisplayName
					mod_data.meta_text = nil
					local value = self:GatherCTHModifications(component_id, 0, mod_data)
					if args and not args.prediction then
						NetUpdateHash("CalcChanceToHit_Component_Mods", weapon.id, component_id, value)
					end
					if value and value ~= 0 then
						base = base + value
						if mod_data.enabled and modifiers then
							table.insert(modifiers, 
							{ 
								name = mod_data.display_name,
								value = value,
								id = component_id,
								metaText = mod_data.meta_text
							})
						end
					end
				end
			end
		end
	end
	
	mod_data.modifiers = modifiers
	self:CallReactions("OnCalcChanceToHit", self, action, target, weapon1, weapon2, mod_data)
	if IsKindOf(target, "Unit") then
		target:CallReactions("OnCalcChanceToHit", self, action, target, weapon1, weapon2, mod_data)
	end
	base = Max(0, mod_data.enabled and MulDivRound(base + mod_data.mod_add, mod_data.mod_mul, 100) or 0)

	local target_pos = IsPoint(target) and target or target:GetPos()
	local knife_throw = IsKindOf(weapon, "MeleeWeapon") and (action.ActionType == "Ranged Attack")
	local penalty = weapon:GetAccuracy(attacker_pos:Dist(target_pos), self, action, knife_throw) - 100
	local final = Clamp(base + penalty, 0, 100)
	final = Clamp(final, mod_data.min, mod_data.max)
		
	if args and not args.prediction then
		NetUpdateHash("CalcChanceToHit_Final", final)
	end
	
	if chance_only then
		return final
	end
	if penalty ~= 0 then
		if action.ActionType == "Melee Attack" then
			modifiers[#modifiers + 1] = {
				name = T(660754354729, "Weapon Accuracy"),
				value = penalty,
				id = "Accuracy"
			}
		elseif penalty <= -100 then
			modifiers[#modifiers + 1] = {
				name = T(162704513413, "Out of Range"),
				value = penalty,
				id = "Range"
			}
		else
			modifiers[#modifiers + 1] = {
				name = T(301586030557, "Range"),
				value = penalty,
				id = "Range"
			}
		end
	end
	return final, base, modifiers, penalty
end

-- unused
---
--- Returns the best chance to hit a target with an action.
---
--- @param target Unit The target to calculate the chance to hit.
--- @param action table The action to perform.
--- @param args table Optional arguments to pass to the chance to hit calculation.
--- @param lof boolean Whether to consider line of fire.
--- @return number The best chance to hit the target.
--- @return number The index of the best hit data in the attack data list.
function Unit:GetBestChanceToHit(target, action, args, lof)
	local best_idx, best_hit_chance
	local list = attack_data.lof
	for i, hit_data in ipairs(list) do
		if i == 1 or hit_data.ally_hits_count <= list[best_idx].ally_hits_count then
			args.target_spot_group = hit_data.target_spot_group
			local hit_chance = self:CalcChanceToHit(target, action, args, "chance_only")
			if i == 1 or hit_data.ally_hits_count < list[best_idx].ally_hits_count or hit_chance > best_hit_chance then
				best_idx, best_hit_chance = i, hit_chance
			end
		end
	end
	return best_hit_chance, best_idx
end

---
--- Checks if the given target is within point-blank range of the unit.
---
--- @param target Unit The target to check the range for.
--- @return boolean True if the target is within point-blank range, false otherwise.
function Unit:IsPointBlankRange(target)
	if not IsValid(target) then
		return false
	end
	return IsCloser(target, self, const.Weapons.PointBlankRange * const.SlabSizeX + 1)
end

---
--- Checks if the target's armor can be pierced by the given weapon.
---
--- @param weapon table The weapon to check if it can pierce the target's armor.
--- @param aim number The aim value to use for the armor piercing check.
--- @param target_spot_group string The target's body part group to check for armor.
--- @param action table The action being performed.
--- @return boolean True if the target's armor can be pierced, false otherwise.
--- @return string The reason why the armor was or was not pierced.
function Unit:IsArmorPiercedBy(weapon, aim, target_spot_group, action) -- Can Crit
	local pierced = true
	if target_spot_group == "Head" then
		local helm = self:GetItemInSlot("Head")
		if helm and IsKindOf(helm, "IvanUshanka") then
			return false
		end
	end
	if action and action.id == "KalynaPerk" then
		return true, "ignored"
	end
	if action and action.ActionType == "Melee Attack" then
		return true, "ignored"
	end
	self:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and item.Condition > 0 and weapon.PenetrationClass < item.PenetrationClass and (item.ProtectedBodyParts or empty_table)[target_spot_group] then
			pierced = false
			return "break"
		end
	end)
	return pierced
end

---
--- Calculates the critical hit chance for an attack against a target.
---
--- @param weapon table The weapon being used for the attack.
--- @param target Unit The target of the attack.
--- @param action table The action being performed.
--- @param args table Optional arguments, including:
---   - target_spot_group string The target's body part group to check for armor.
---   - aim number The aim value to use for the attack.
---   - stealth_bonus_crit_chance number A bonus to the critical hit chance from stealth.
--- @param attack_pos table The position of the attack.
--- @return number The calculated critical hit chance, between 0 and 100.
function Unit:CalcCritChance(weapon, target, action, args, attack_pos)
	if not IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then
		return 0
	end
	
	local target_spot_group = args and args.target_spot_group or g_DefaultShotBodyPart	
	local aim = args and args.aim or 0

	if IsKindOf(target, "Unit") and not target:IsArmorPiercedBy(weapon, aim, target_spot_group, action) then
		return 0
	end
	local critChance = self:GetBaseCrit(weapon) + (args and args.stealth_bonus_crit_chance or 0)
	local data = {
		crit_chance = critChance,
		action_id = action and action.id,
		weapon = weapon,
		aim = aim,
		opportunity_attack = args and args.opportunity_attack,
		opportunity_attack_type = args and args.opportunity_attack_type,
		crit_per_aim = const.Combat.AimCritBonus,
		stealth_attack = args and args.stealth_attack,
		target_spot_group = target_spot_group,
		guaranteed_crit = false,
		guaranteed_noncrit = false,
	}
	
	Msg("GatherCritChanceModifications", self, target, action and action.id, weapon, data)
	self:CallReactions("OnCalcCritChance", self, target, action, weapon, data)
	if IsKindOf(target, "Unit") then
		target:CallReactions("OnCalcCritChance", self, target, action, weapon, data)
	end
	
	if data.guaranteed_noncrit or data.opportunity_attack then return 0 end
	if data.guaranteed_crit then return 100 end

	local critChance = data.crit_chance + aim * data.crit_per_aim

	return Clamp(critChance, 0, 100)
end

---
--- Calculates the AP cost for aiming in the current tactical action.
---
--- @return number The AP cost for aiming, divided by the AP scale constant.
function TFormat.AimAPCost()
	local igi = GetInGameInterfaceModeDlg()
	if not igi then return -1 end
	
	local attacker = igi.attacker
	local action = igi.action
	if not action then return -1 end
	
	local weapon = action:GetAttackWeapons(attacker)
	local crosshair = igi.crosshair
	local aimLevel = crosshair and crosshair.aim or 0
	
	local actionCost, aimCost = attacker:GetAttackAPCost(action, weapon, nil, aimLevel + 1, action.ActionPointDelta)
	return aimCost / const.Scale.AP
end

---
--- Calculates the AP cost for an attack action, taking into account the weapon, aim level, and environmental effects.
---
--- @param action CombatAction The combat action being performed.
--- @param weapon Weapon The weapon being used for the attack.
--- @param action_ap_cost number The base AP cost of the action.
--- @param aim number The aim level for the attack.
--- @param delta number An additional AP cost modifier.
--- @return number The total AP cost for the attack.
--- @return number The AP cost for the aiming component of the attack.
function Unit:GetAttackAPCost(action, weapon, action_ap_cost, aim, delta)
	if not weapon then 
		return 0
	end
	
	local min, max = self:GetBaseAimLevelRange(action, weapon)
	aim = Clamp(aim or 0, min, max) - min -- only charge for aiming above min level
	delta = delta or 0
	local aimCost = const.Scale.AP
	local rain_penalty = GameState.RainHeavy and not self.indoors
	if rain_penalty then
		aimCost = MulDivRound(aimCost, 100 + const.EnvEffects.RainAimingMultiplier, 100)
	end
	
	local ap = action_ap_cost or weapon.AttackAP or weapon.ShootAP or 0
	ap = ap + delta 
	ap = self:CallReactions_Modify("OnCalcAPCost", ap, action, weapon, aim)

	if IsKindOf(weapon, "HeavyWeapon") then
	elseif IsKindOf(weapon, "Firearm") or IsKindOf(weapon, "Grenade") or IsKindOf(weapon, "MeleeWeapon") then
		ap = ap + aim * aimCost
	else
		ap = -1
	end
	
	-- legal cheat: during heavy rain last possible aim costs 1 AP regardless of the penalty
	local remainingAP = (self:GetUIActionPoints() / 1000) * 1000
	if rain_penalty and ap > remainingAP and aim > 0 then 
		local diff = abs(remainingAP - ap)
		if diff < aimCost and diff >= const.Scale.AP then
			ap = remainingAP
			aimCost = 1000
		end
	end
	
	return ap, aimCost
end

---
--- Resolves the attack parameters for a given action and target.
---
--- @param action_id string The ID of the combat action being performed.
--- @param target table The target of the attack.
--- @param lof_params table Optional parameters for the line of fire calculation.
--- @return table The attack data, including the attacker, target, and other relevant information.
function Unit:ResolveAttackParams(action_id, target, lof_params)
	local action = action_id and CombatActions[action_id]
	if action and action.AimType == "melee" then
		local attack_data = {
			obj = self,
			step_pos = self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos(),
			target = target
		}
		return attack_data
	end
	lof_params = lof_params or {}
	lof_params.obj = self
	if not lof_params.action_id then
		lof_params.action_id = action_id
	end
	if lof_params.weapon == nil then
		lof_params.weapon = action and action:GetAttackWeapons(self) or false
	end
	if not lof_params.step_pos then
		lof_params.step_pos = self:GetOccupiedPos()
	end
	if lof_params.can_use_covers == nil then
		lof_params.can_use_covers = true
	end
	lof_params.prediction = true
	local attack_data = GetLoFData(self, target, lof_params)
	if not attack_data then
		attack_data = {
			obj = self,
			step_pos = self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos(),
			target = target,
			stuck = true,
		}
	end
	return attack_data
end

---
--- Prepares the attacker for an attack, handling camera positioning, visual effects, and delays.
---
--- @param attack_args table The arguments for the attack, including the target and other relevant information.
--- @param attack_results table The results of the attack, including any effects or outcomes.
---
function Unit:PrepareToAttack(attack_args, attack_results)
	if not self.visible then
		local targetIsUnit = attack_args.target and IsKindOf(attack_args.target, "Unit") and attack_args.target
		if targetIsUnit and targetIsUnit.visible then
			local floor = GetStepFloor(targetIsUnit)
			SnapCameraToObj(targetIsUnit, "force", floor)
		else
			return
		end
	end
	local showMiddle
	local dontMoveCamera, ccAttacker = StopCinematicCombatCamera()
	local updateLastUnitShoot = false
	if dontMoveCamera then updateLastUnitShoot = ccAttacker end
	local targetPos = not IsPoint(attack_args.target) and attack_args.target:GetVisualPos() or attack_args.target
	local notInGivenCommand = self.command ~= "OverwatchAction" and self.command ~= "MGSetup" and self.command ~= "MGTarget"
	local attackerPos = self:GetVisualPos()
	local isRetaliation = attack_args.opportunity_attack_type and attack_args.opportunity_attack_type == "Retaliation"
	local isAIControlled = not ActionCameraPlaying and not self:IsMerc() and g_AIExecutionController and 
		(not self.opportunity_attack or #g_CombatCamAttackStack == 0)
	local mercPlayingAsAI = self:IsMerc() and g_AIExecutionController and g_AIExecutionController.units_playing and g_AIExecutionController.units_playing[self]
	local isAIControlledMerc = not ActionCameraPlaying and (isRetaliation or attack_args.gruntyPerk or mercPlayingAsAI)
	local cameraPosChanged

	--Show attacker
	local movedToShowAttacker
	if isAIControlled or isAIControlledMerc then
		--handle camera
		if g_LastUnitToShoot ~= self and not dontMoveCamera then
			local midPoint = (attackerPos + targetPos) / 2
			local floor = GetStepFloor(self)
			local target_floor = GetStepFloor(attack_args.target)
			showMiddle = floor == target_floor and notInGivenCommand and DoPointsFitScreen({ attackerPos, targetPos }, midPoint, 10)
			local posToShow = showMiddle and midPoint or attackerPos
			local cameraIsNear = DoPointsFitScreen({posToShow}, nil, const.Camera.BufferSizeNoCameraMov)
			if cameraIsNear and showMiddle then
				cameraIsNear = DoPointsFitScreen({ attackerPos, targetPos }, nil, 10)
			end
			
			if not cameraIsNear then
				movedToShowAttacker = true
				SnapCameraToObj(posToShow, "force", GetStepFloor(showMiddle and targetPos or attackerPos))
				if not self:CanQuickPlayInCombat() then Sleep(1000) end
			elseif not IsVisibleFromCamera(self) or GetStepFloor(self) > cameraTac.GetFloor() then
				--no movement of camera should still take into account the floor
				cameraTac.SetFloor(GetStepFloor(self), hr.CameraTacInterpolatedMovementTime * 10, hr.CameraTacInterpolatedVerticalMovementTime * 10)
			end
			updateLastUnitShoot = self
		end
	elseif not ActionCameraPlaying and self.opportunity_attack and not isRetaliation then
		movedToShowAttacker = not DoPointsFitScreen({ targetPos }, nil, const.Camera.BufferSizeNoCameraMov)
		CombatCam_ShowAttackNew(self, attack_args.target, nil, attack_results, dontMoveCamera)
	end
	
	--handle badges
	if not g_AITurnContours[self.handle] and (isAIControlled or isAIControlledMerc or (self.opportunity_attack and not isRetaliation)) then
		local enemy = self.team.side == "enemy1" or self.team.side == "enemy2" or self.team.side == "neutralEnemy"
		g_AITurnContours[self.handle] = SpawnUnitContour(self, enemy and "CombatEnemy" or "CombatAlly")
		ShowBadgeOfAttacker(self, true)
	end

	self:AimTarget(attack_args, attack_results, true)

	--delay after aim
	if not self:CanQuickPlayInCombat() and movedToShowAttacker and (g_AIExecutionController or isRetaliation or attack_args.gruntyPerk or self.opportunity_attack) then
		local delay
		local consecutiveDelay = not dontMoveCamera and g_LastUnitToShoot == self

		if dontMoveCamera then
			delay = const.Combat.ShootDelayAfterAimCinematic
		elseif consecutiveDelay then
			delay = const.Combat.ConsecutiveShootDelayAfterAim
		else
			delay = const.Combat.ShootDelayAfterAim
		end
		Sleep(delay)
	end

	self:SetTargetDummy(nil, nil, attack_args.anim, 0, attack_args.stance)

	--Show target
	if not showMiddle then cameraPosChanged = not DoPointsFitScreen({targetPos}, nil, const.Camera.BufferSizeNoCameraMov) end
	if isAIControlled and notInGivenCommand and g_LastUnitToShoot ~= self or isAIControlledMerc then
		local interrupts = self:CheckProvokeOpportunityAttacks(attack_args.action_id and CombatActions[attack_args.action_id], "attack interrupt", {self.target_dummy or self})
		local targetNotVisible = showMiddle and IsKindOf(attack_args.target, "Unit") and not IsVisibleFromCamera(attack_args.target)
		CombatCam_ShowAttackNew(self, attack_args.target, interrupts, attack_results, dontMoveCamera or showMiddle, targetNotVisible)
	elseif self:IsMerc() and not ActionCameraPlaying and not g_AIExecutionController then
		--edge case where merc/player shoots but he is in overwatch so the overwatch will be shown first and then his attack
		local interrupts = self:CheckProvokeOpportunityAttacks(attack_args.action_id and CombatActions[attack_args.action_id], "attack interrupt", {self.target_dummy or self})
		if interrupts then
			CombatCam_ShowAttackNew(self, attack_args.target, interrupts, attack_results)
		else
			local cameraIsNear = DoPointsFitScreen({targetPos}, nil, const.Camera.BufferSizeNoCameraMov)
			if attack_results.explosion and (not attack_args.action_id or attack_args.action_id ~= "Bombard") and not cameraIsNear then
				SnapCameraToObj(targetPos, nil, GetStepFloor(targetPos), 500)
				Sleep(500)
			end
		end
	end

	--delay before shooting
	if not self:CanQuickPlayInCombat() then
		if g_AIExecutionController or isRetaliation or self.opportunity_attack then
			local delay
			local consecutiveDelay = not dontMoveCamera and g_LastUnitToShoot == self
			
			if dontMoveCamera then
				delay = const.Combat.ShootDelayCinematic
			elseif not cameraPosChanged then
				delay = const.Combat.ShootDelayTargetOnScreen
			elseif consecutiveDelay then
				delay = const.Combat.ConsecutiveShootDelay
			else
				delay = const.Combat.ShootDelay
			end
			Sleep(delay)
		elseif self.command ~= "PrepareBombard" and self.command ~= "OverwatchAction" then
			if cameraPosChanged then
				Sleep(const.Combat.ShootDelayNonAI)
			else
				Sleep(const.Combat.ShootDelayTargetOnScreen)
			end
		end
	end
	if updateLastUnitShoot then
		g_LastUnitToShoot = updateLastUnitShoot
	end
end

---
--- Calculates the chance of a successful stealth kill for the given unit, weapon, and target.
---
--- @param weapon table The weapon being used for the stealth kill.
--- @param target table The target of the stealth kill.
--- @param target_spot_group string The body part of the target being targeted for the stealth kill.
--- @param aim number The aim value of the attack.
--- @return number The calculated chance of a successful stealth kill.
function Unit:CalcStealthKillChance(weapon, target, target_spot_group, aim)
	if not IsValidTarget(target) or not IsKindOf(target, "Unit") or not weapon then return 0 end

	local chance = Max(0, self.Dexterity - target.Wisdom)
	local min_chance = 1

	if target_spot_group == "Head" or target_spot_group == "Neck" then
		chance = chance + const.Combat.HeadshotStealthKillChanceMod
	end

	chance = self:CallReactions_Modify("OnCalcStealthKillChance", chance, self, target, weapon, target_spot_group, aim)
	chance = target:CallReactions_Modify("OnCalcStealthKillChance", chance, self, target, weapon, target_spot_group, aim)

	min_chance = self:CallReactions_Modify("OnCalcStealthKillMinChance", min_chance, self, target, weapon, target_spot_group, aim)
	min_chance = target:CallReactions_Modify("OnCalcStealthKillMinChance", min_chance, self, target, weapon, target_spot_group, aim)


	local stealthKillBonus = GetComponentEffectValue(weapon, "StealthKillBonusPerAim", "stealth_kill_bonus")
	if stealthKillBonus then
		chance = chance + (aim or 0) * (stealthKillBonus or 0)
	end
	
	if target:IsAware() then
		chance = MulDivRound(chance, 33, 100)
	elseif target:HasStatusEffect("Surprised") or target:HasStatusEffect("Suspicious") then
		chance = MulDivRound(chance, Max(0, 100 + CharacterEffectDefs.Surprised:ResolveValue("stealthkill_modifier")), 100)
	end
	
	if CheatEnabled("SkillCheck") then
		chance = 100
	end
	
	local weapon_pen_class = weapon:HasMember("PenetrationClass") and weapon.PenetrationClass or 1
	local armor_class = 0
	target:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and item.ProtectedBodyParts and item.ProtectedBodyParts[target_spot_group] then
			armor_class = Max(armor_class, item.PenetrationClass)
		end
	end)
	if weapon_pen_class < armor_class and chance > 0 then
		chance = chance / 2
	end
	
	chance = Clamp(chance, min_chance, 100)
	return chance
end

---
--- Prepares the attack arguments for a unit's attack action.
---
--- @param action_id string The ID of the attack action to prepare.
--- @param args table The attack arguments to use.
--- @return table The prepared attack arguments.
function Unit:PrepareAttackArgs(action_id, args)
	action_id = action_id or self:GetDefaultAttackAction("ranged")
	args = args or empty_table
	local action = CombatActions[action_id]
	local weapon = args.weapon or action and action:GetAttackWeapons(self)
	local target = args.target
	local prediction = args.prediction or args.prediction == nil
	local aim_type = action and action.AimType
	local thermal_aim = IsKindOf(weapon, "Firearm") and IsFullyAimedAttack(args) and weapon:HasComponent("IgnoreGrazingHitsWhenFullyAimed")

	local attack_args = table.copy(args)
	attack_args.action_id = action_id
	attack_args.obj = self
	attack_args.weapon = weapon
	attack_args.target_pos = attack_args.target_pos or IsPoint(target) and target
	attack_args.step_pos = attack_args.step_pos or self.return_pos or self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos()
	attack_args.ignore_smoke = thermal_aim
	if attack_args.fire_relative_point_attack == nil then
		attack_args.fire_relative_point_attack = self.WeaponType == "Shotgun"
	end
	attack_args.prediction = prediction

	if aim_type ~= "melee" then
		attack_args.prediction = true
		local attack_data
		if IsPoint(target) and attack_args.target_height_range then
			if not target:IsValidZ() then
				target = target:SetTerrainZ()
			end
			local min_dist
			for h = 0, attack_args.target_height_range, guim/2 do
				local pt = target:SetZ(target:z() + h)
				local data = GetLoFData(self, pt, attack_args)
				if data then
					local dist
					for _, lof_data in ipairs(data.lof) do
						for _, hit in ipairs(lof_data.hits) do
							local d = target:Dist(hit.pos)
							if not dist or dist > d then
								dist = d
							end
						end
					end
					if dist and (not attack_data or min_dist > dist) then
						attack_data, min_dist = data, dist
					end
				end
			end
		else
			attack_data = GetLoFData(self, target, attack_args)
		end
		if attack_data then
			for k, v in pairs(attack_data) do
				attack_args[k] = v
			end
		else
			attack_args.stuck = true
		end
		attack_args.prediction = prediction
	end

	attack_args.num_shots = attack_args.num_shots or 1 -- number of direct shots (with simulated projectiles
	attack_args.aoe_action_id = attack_args.aoe_action_id or false -- defines cone area for collateral/aoe damage (as used in Firearm:GetAreaAttackParams)
	attack_args.aoe_fx_action = attack_args.aoe_fx_action or false -- fx action to play for the aoe part of the attack, if any
	attack_args.aoe_damage_type = attack_args.aoe_damage_type or "default" -- "default", "fixed" or "percent", defines how the aoe damage is calculated
	attack_args.aoe_damage_value = attack_args.aoe_damage_value or false -- when "fixed" or "percent" type is used
	attack_args.applied_status = attack_args.applied_status or false -- status effect on hit
	attack_args.damage_bonus = attack_args.damage_bonus or false -- bonus damage applied by the attack (0/false = no change, 100 = x2, -100 = x0)
	attack_args.consumed_ammo = attack_args.consumed_ammo or false -- defaults to num_shots/used_ammo (from aoe params)
	attack_args.aoe_damage_bonus = attack_args.aoe_damage_bonus or false -- same as above for collateral/aoe damage
	attack_args.cth_loss_per_shot = attack_args.cth_loss_per_shot or false -- for attacks with num_shots > 1, defines the accuracy of the follow-up shots based on the attack roll
	attack_args.fx_action = attack_args.fx_action or false -- fx action to play in the hit moment(s) of the attack anim (defaults to WeaponFire)
	attack_args.single_fx = attack_args.single_fx or false -- if set to true, attacks will not play their fx_action more than once per attack

	if weapon and aim_type == "cone" then
		local aoe_params = weapon:GetAreaAttackParams(action_id, self, attack_args.target_pos, attack_args.step_pos)
		for k, v in pairs(aoe_params) do
			attack_args[k] = v
		end
	end

	-- Stealth kill
	local is_stealth = attack_args.stealth_attack or self:HasStatusEffect("Hidden")
	local lethal_weapon = (attack_args.target_spot_group == "Neck") and IsKindOf(weapon, "MeleeWeapon") and (weapon.NeckAttackType == "lethal")
	if action and (is_stealth or lethal_weapon)  then
		local stealth_targeted = is_stealth and action.StealthAttack and IsKindOf(target, "Unit") and IsValidTarget(target)
		local stealth_aoe, chance
		if stealth_targeted or stealth_aoe then
			local crosshair = GetInGameInterfaceModeDlg().crosshair
			local aim = args.aim or (crosshair and crosshair.aim) or 0
			chance = self:CalcStealthKillChance(weapon, target, attack_args.target_spot_group, aim)
			attack_args.stealth_attack = true
		end
		if lethal_weapon then
			local lethal_chance = 5 + Max(0, (self.Strength - target.Health) / 2)
			chance = Max(chance or 0, lethal_chance)
		end
		if stealth_targeted or lethal_weapon then
			if target:IsNPC() and not target.villain then
				attack_args.stealth_kill_chance = chance
				attack_args.stealth_bonus_crit_chance = 0
			else
				attack_args.stealth_kill_chance = 0
				attack_args.stealth_bonus_crit_chance = chance
			end
		end
	end

	return attack_args
end

---
--- Starts the fire animation for a unit, optionally with aim IK and a delay.
---
--- @param shot table|nil The shot information, if available.
--- @param attack_args table The attack arguments.
--- @param aim_pos Vector3|nil The position to aim at, if not provided it will use the shot's target position or the attack arguments' target position.
--- @param shotAnimDelay number|nil The delay in milliseconds before starting the shot animation.
---
function Unit:StartFireAnim(shot, attack_args, aim_pos, shotAnimDelay)
	if self:CanAimIK(attack_args.weapon) then
		if not aim_pos then
			aim_pos = shot and (shot.lof_pos2 or shot.target_pos) or attack_args.target_pos
		end
		if aim_pos then
			self:SetIK("AimIK", aim_pos) -- the unit should be in aim or fire state
			if shotAnimDelay then
				Sleep(shotAnimDelay)
				shotAnimDelay = 0
			else
				Sleep(200)
			end
		end
	end
	if (shotAnimDelay or 0) > 0 then
		Sleep(shotAnimDelay)
	end
	local hit_moment = shot and shot.hit_moment or "hit" -- todo: make sure DualShot passes the correct hit moments
	local anim = self:ModifyWeaponAnim(attack_args.anim)
	self:SetState(anim, const.eKeepComponentTargets, 0)
	local time_to_hit = self:TimeToMoment(1, hit_moment)
	if time_to_hit then
		Sleep(time_to_hit)
	end
end

---
--- Generates attack and critical hit rolls for a unit.
---
--- @param num_shots number The number of shots to generate rolls for.
--- @param multishot boolean Whether the attack is a multishot.
--- @param atk_value number|nil The attack value to use for the rolls, or nil to generate random values.
--- @param crit_value number|nil The critical hit value to use for the rolls, or nil to generate random values.
--- @return table|number, table|number The attack rolls and critical hit rolls. If `multishot` is false, these will be single numbers, otherwise they will be tables of the same length as `num_shots`.
---
function Unit:GetAttackRolls(num_shots, multishot, atk_value, crit_value)
	local attack_roll, crit_roll
	if not multishot or ((num_shots or 1) <= 1) then
		attack_roll = atk_value or (1 + self:Random(100))
		crit_roll = crit_value or (1 + self:Random(100))
	else
		attack_roll, crit_roll = {}, {}
		for i = 1, num_shots do
			attack_roll[i] = atk_value or (1 + self:Random(100))
			crit_roll[i] = crit_value or (1 + self:Random(100))
		end
	end
	return attack_roll, crit_roll
end

---
--- Converts an animation name to an action name.
---
--- @param anim string The animation name to convert.
--- @return string The action name.
---
function FXAnimToAction(anim)
	return "Anim:" .. anim
end

---
--- Converts an action name to an animation name.
---
--- @param action string The action name to convert.
--- @return string The animation name.
---
function FXActionToAnim(action)
	return remove_prefix(action, "Anim:") or action
end

---
--- Returns the display name of the unit.
---
--- @return string The display name of the unit.
---
function Unit:GetLogName()
	return self:GetDisplayName()
end

--- Sets the attack reason and opportunity attack flag for the unit.
---
--- @param reason string The reason for the attack.
--- @param opportunity_attack boolean Whether this is an opportunity attack.
---
function Unit:SetAttackReason(reason, opportunity_attack)
	self.attack_reason = reason
	self.opportunity_attack = opportunity_attack
end

---
--- Returns the attack reason text for the unit.
---
--- @return string The attack reason text, or an empty string if no attack reason is set.
---
function Unit:GetAttackReasonText()
	return self.attack_reason and T{295729060245, "<em><name></em>: ", name = self.attack_reason} or ""
end

---
--- Calculates the base damage of a weapon for the unit.
---
--- @param weapon table The weapon to calculate the base damage for. If not provided, the unit's active weapons will be used.
--- @param target table The target of the attack. Used to determine if the weapon is within range.
--- @param breakdown table An optional table to store the breakdown of the damage calculation.
--- @return number The base damage of the weapon.
---
function Unit:GetBaseDamage(weapon, target, breakdown)
	if self.infinite_dmg then
		return 10000
	end
	weapon = weapon or self:GetActiveWeapons()
	local mod = 100
	local base_damage = 0
			
	if IsKindOf(weapon, "Firearm") then
		base_damage = weapon.Damage
		if IsValidTarget(target) and self:GetDist(target) <= weapon.WeaponRange * const.SlabSizeX / 2  then
			local damageIncrease = GetComponentEffectValue(weapon, "HalfRangeDmgIncrease", "base_dmg_bonus")
			if damageIncrease then
				base_damage = base_damage + damageIncrease
			end
		end
	elseif IsKindOf(weapon, "Grenade") then
		if IsKindOf(weapon, "ThrowableTrapItem") then
			base_damage = weapon:GetBaseDamage()
		else
			base_damage = weapon.BaseDamage
		end
		mod = 100 + GetGrenadeDamageBonus(self)
	elseif IsKindOfClasses(weapon, "MeleeWeapon", "Ordnance") then
		base_damage = weapon.BaseDamage
	end
	
	local data = { base_damage = base_damage, modifier = mod, breakdown = breakdown or {} }
	Msg("CalcBaseDamage", self, weapon, target, data)
	self:CallReactions("OnCalcBaseDamage", weapon, target, data)
	return MulDivRound(data.base_damage, data.modifier, 100)
end

---
--- Enables or disables various god-mode abilities for the unit.
---
--- @param mode string The mode to enable or disable. Defaults to "god_mode".
--- @param state boolean Whether to enable or disable the mode. Defaults to true.
---
function Unit:GodMode(mode, state)
	mode = mode or "god_mode"
	if state == nil then 
		state = true 
	end
	self[mode] = state
	if mode == "god_mode" then
		self.infinite_ap = state
		self.infinite_ammo = state
		self.infinite_dmg = state
		self.infinite_condition = state
		self.invulnerable = state
	end
	if self.infinite_ap then
		self:GainAP(self:GetMaxActionPoints())
	end
end

local l_all_equiped_weapons_reloaded

---
--- Reloads all equipped weapons for the unit.
---
--- @param ammo_type string (optional) The type of ammo to use for reloading. If not provided, the default ammo for each weapon will be used.
--- @return boolean Whether any of the equipped weapons were successfully reloaded.
---
function Unit:ReloadAllEquipedWeapons(ammo_type)
	l_all_equiped_weapons_reloaded = false
	self:ForEachItemInSlot("Handheld A", "Firearm", function(gun, slot, left, top, self, ammo_type)
		if ammo_type or not gun.ammo or gun.ammo.Amount < gun.MagazineSize then
			if self:ReloadWeapon(gun, ammo_type) then
				l_all_equiped_weapons_reloaded = true
			end
		end
	end, self, ammo_type)
	self:ForEachItemInSlot("Handheld B", "Firearm", function(gun, slot, left, top, self, ammo_type)
		if ammo_type or not gun.ammo or gun.ammo.Amount < gun.MagazineSize then
			if self:ReloadWeapon(gun, ammo_type) then
				l_all_equiped_weapons_reloaded = true
			end
		end
	end, self, ammo_type)
	return l_all_equiped_weapons_reloaded
end

---
--- Calculates the cover percentage for a unit based on the attacker's position and the unit's position.
---
--- @param attackerPos Vector3 The position of the attacker.
--- @param target_pos Vector3 (optional) The position of the target. If not provided, the unit's position is used.
--- @param stance string (optional) The stance of the unit. If not provided, the unit's current stance is used.
--- @return boolean, boolean, number The cover percentage, whether the unit is in cover, and whether the unit is moving in combat.
---
function Unit:GetCoverPercentage(attackerPos, target_pos, stance)
	if g_Combat and self.combat_path then
		return false, false, 0 -- unit is moving in combat and does not benefit from cover
	end
	return GetCoverPercentage(target_pos or self:GetPos(), attackerPos, stance or self.stance)
end

---
--- Sets the visibility of the unit.
---
--- @param visible boolean Whether the unit should be visible or not.
--- @param force boolean (optional) If true, the visibility will be set regardless of the current state of the game.
---
function Unit:SetVisible(visible, force)
	visible = visible or (not force and IsSetpiecePlaying() and g_SetpieceFullVisibility)

	--NetUpdateHash("Unit:SetVisible", self, visible, force, IsSetpiecePlaying(), g_SetpieceFullVisibility)

	if visible then
		if g_Exploration  and not self:IsDead() then
			if not self.visible then
				self:SetOpacity(100, 500)
			end
		else
			self:SetOpacity(100)
		end

		local hidden_parts = self.Headshot and self.species == "Human" and HeadshotHideParts
		self:SetEnumFlags(const.efVisible)
		for name, body_part in pairs(self.parts) do
			if hidden_parts and table.find(hidden_parts, name) then
				body_part:ClearEnumFlags(const.efVisible)
			else
				body_part:SetEnumFlags(const.efVisible)
			end
		end
		if self.prepared_attack_obj then
			self.prepared_attack_obj:SetEnumFlags(const.efVisible)
		end
	else
		if g_Exploration and not self:IsDead() then
			if self.visible then
				self:SetOpacity(0, 2000)
			end
		else
			self:ClearEnumFlags(const.efVisible)
			for _, body_part in pairs(self.parts) do
				body_part:ClearEnumFlags(const.efVisible)
			end
		end

		if self.prepared_attack_obj then
			self.prepared_attack_obj:ClearEnumFlags(const.efVisible)
		end
	end
	
	if self.visible ~= visible then
		if self.melee_threat_contour then
			self.melee_threat_contour:SetVisible(visible)
		end
		
		if self.ui_badge then
			local badgeVisible = visible and not self:IsDead()
			self.ui_badge:SetVisible(badgeVisible, "unit")
		end
		
		self:SetSoundMute(not visible)
		self:ForEachAttach("GrenadeVisual", function(obj) 
			obj:SetSoundMute(not visible)
		end)
		self.visible = visible
		ObjModified(self)
		
		if self.carry_flare then
			self:UpdateOutfit()
		end
		
		self:UpdateFXClass()
	end
end

---
--- Returns a table of all visible enemies for the current unit.
---
--- @return table visible Visible enemies
function Unit:GetVisibleEnemies()
	local visible = {}
	
	if self.team then
		-- Add all enemies visible by my team.
		local team_visible = g_Visibility[self.team] or empty_table
		for _, u in ipairs(team_visible) do
			if IsValidTarget(u) and self:IsOnEnemySide(u) then
				table.insert_unique(visible, u)
			end
		end
	end
		
	return visible
end

---
--- Called when the unit's gear has changed.
---
--- This function is responsible for updating the unit's state when their gear changes, such as when they equip or unequip items.
---
--- It checks if the unit is using any cumbersome items, and updates the appropriate state variables and network messages accordingly.
--- It also applies any modifiers associated with the equipped items.
---
--- Finally, it notifies other systems that the unit's AP has changed, and marks the unit and its inventory as modified.
---
--- @param isLoad boolean Whether the gear change is due to the unit loading in (true) or some other action (false).
---
function Unit:OnGearChanged(isLoad)
	self.using_cumbersome = false
	NetUpdateHash("CumbersomeReset", self)
	self:ForEachItem(false, function(item, slot)
		if slot ~= "Inventory" and item:IsCumbersome() then
			self.using_cumbersome = true
			NetUpdateHash("CumbersomeSet", self)
		end
		item:ApplyModifiersList(item.applied_modifiers)
	end)
	Msg("UnitAPChanged", self)
	ObjModified(self)
	ObjModified(self.Inventory)
end

---
--- Checks if the unit can use the Ironclad perk.
---
--- The Ironclad perk allows a unit to ignore the cumbersome penalty, but only if the unit is not wielding any cumbersome items.
---
--- @return boolean canUse Whether the unit can use the Ironclad perk.
---
function Unit:CanUseIroncladPerk()
	local canUse = HasPerk(self, "Ironclad")

	if canUse then
		local weapons = self:GetHandheldItems()
		for _, weapon in ipairs(weapons) do
			if weapon:IsCumbersome() then
				canUse = false
				break
			end
		end
	end
	
	return canUse
end

local _is_attack_available_units = {}

---
--- Retrieves the default attack action for the unit based on the current weapon and other conditions.
---
--- This function checks the unit's active weapons and available attacks, and determines the appropriate default attack action to use. It handles cases like dual-wielding, ranged attacks, and stealth.
---
--- @param force_ranged boolean Whether to force a ranged attack, even if the unit has a melee weapon.
--- @param force_ungrouped boolean Whether to force an ungrouped attack action, even if a grouped action is available.
--- @param weapon table The unit's active weapon, or nil to use the unit's current weapons.
--- @param sync boolean Whether to synchronize the action with the network.
--- @param ignore_stealth boolean Whether to ignore the unit's stealth status when determining the action.
--- @param args table Additional arguments to pass to the action's GetUIState method.
--- @param ui boolean Whether the action is being requested for the UI.
--- @return table The default attack action to use.
---
function Unit:GetDefaultAttackAction(force_ranged, force_ungrouped, weapon, sync, ignore_stealth, args, ui)
	local weapon2
	if not weapon then
		weapon, weapon2 = self:GetActiveWeapons()
	end
	local id, action
	
	local weaponAttacks = IsKindOf(weapon, "Firearm") and not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun") and weapon.AvailableAttacks or empty_table
	local weapon2Attacks = IsKindOf(weapon2, "Firearm") and not IsKindOfClasses(weapon2, "HeavyWeapon", "FlareGun") and weapon2.AvailableAttacks or empty_table
	
	_is_attack_available_units[1] = self
	
	-- Check if dual shot.
	if #weaponAttacks > 0 and #weapon2Attacks > 0 then
		if table.find(weaponAttacks, "DualShot") and table.find(weapon2Attacks, "DualShot") then
			action = CombatActions.AttackDual
			if action:GetUIState(_is_attack_available_units, args) == "enabled" then
				id = action.id
			end
		end
	end

	if force_ranged and IsKindOf(weapon, "MeleeWeapon") and weapon.CanThrow then
		id = "KnifeThrow"
	end
	if IsKindOf(weapon, "FlareGun") then
		weapon = nil
		if weapon2 and not IsKindOf(weapon2, "FlareGun") then
			weapon = weapon2
			weapon2 = nil
		end
	end
	
	if not id then
		id = weapon and weapon:GetBaseAttack(self, force_ranged) or "UnarmedAttack"
	end	
	
	action = CombatActions[id]

	if force_ungrouped and action:GetUIState(_is_attack_available_units, args) == "enabled" then
		if sync then NetUpdateHash("GetDefaultAttackAction", self, id) end
		return action 
	end
	
	local firingMode = action and action.FiringModeMember
	if firingMode and CombatActions[firingMode]:GetUIState({self}, args) == "enabled" then
		if not force_ungrouped then
			if sync then NetUpdateHash("GetDefaultAttackAction", self, firingMode) end
			return CombatActions[firingMode]
		end
		local action_id = self:ResolveDefaultFiringModeAction(CombatActions[firingMode], ui, sync)
		if action_id then
			return CombatActions[action_id]
		end
	end
	if sync then	NetUpdateHash("GetDefaultAttackAction", self, action.id) end
	return action
end

local _resolve_default_firing_mode_actions = {}

---
--- Resolves the default firing mode action for a unit based on the available actions for the current firing mode.
---
--- @param firingMode CombatAction The firing mode to resolve the default action for.
--- @param ui boolean Whether the action is being resolved for a UI context.
--- @param sync boolean Whether the action resolution should be synchronized.
--- @return string, table The ID of the resolved default action, and the list of available actions.
---
function Unit:ResolveDefaultFiringModeAction(firingMode, ui, sync)
	local actions = _resolve_default_firing_mode_actions
	table.iclear(actions)
	local firing_id = firingMode.id

	local weapon = firingMode:GetAttackWeapons(self)
	if IsKindOf(weapon, "Firearm") then
		for _, id in ipairs(weapon.AvailableAttacks) do
			if CombatActions[id].FiringModeMember == firing_id then
				actions[#actions + 1] = CombatActions[id]
			end
		end
	else
		for id, action in pairs(CombatActions) do
			if action.FiringModeMember == firing_id then
				actions[#actions + 1] = action
			end
		end
	end

	-- special casea
	if firing_id == "AttackDual" then
		table.insert_unique(actions, CombatActions.LeftHandShot)
		table.insert_unique(actions, CombatActions.RightHandShot)
	elseif firing_id == "Attack" and weapon:HasComponent("EnableFullAuto") then
		table.insert_unique(actions, CombatActions.AutoFire)
	end
	table.sort(actions, function(a, b)
		return a.SortKey < b.SortKey
	end)

	if self:HasStatusEffect("Hidden") then
		if table.find(actions, "id", "SingleShot") then
			return "SingleShot", actions
		end
	end
	_is_attack_available_units[1] = self
	if ui and self.lastFiringMode and table.find(actions, "id", self.lastFiringMode) then
		local action = CombatActions[self.lastFiringMode]
		if action:GetUIState(_is_attack_available_units) == "enabled" then
			if self:HasAP(action:GetAPCost(self), action.id) then
				return action.id, actions
			end
		end
	end
	for _, action in ipairs(actions) do
		if action:GetUIState(_is_attack_available_units) == "enabled" then
			if not ui or self:HasAP(action:GetAPCost(self), action.id) then
				return action.id, actions
			end
		end
	end
	return actions[1] and actions[1].id, actions
end

local function ResetIdleLookAt(unit)
	if not g_Combat then
		return
	end
	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, u in ipairs(team.units) do
				if u.command == "Idle" and u.target_dummy and u:IsAware() then
					local pos = GetPassSlab(u.target_dummy) or u.target_dummy:GetPos()
					if u:SetTargetDummyFromPos(pos, nil, false) then
						u:SetCommand("Idle")
					end
				end
			end
		end
	end
end

---
--- Updates the `indoors` property of the given `unit` based on the current game state and the unit's environment.
---
--- If the game is currently underground, the unit is considered indoors and the `indoors` property is set to `true`.
---
--- Otherwise, the function checks the volume the unit is in. If the volume has a roof, the `indoors` property is set to `true`, otherwise it is set to `false`.
---
--- @param unit Unit The unit to update the `indoors` property for.
---
function UpdateIndoors(unit)
	if GameState.Underground then
		unit.indoors = true
		return
	end
	local volume = EnumVolumes(unit, "smallest")
	--unit.indoors = volume and not volume.dont_use_interior_lighting
	unit.indoors = volume and volume:HasRoof(true)
end

OnMsg.UnitMovementDone = ResetIdleLookAt
OnMsg.UnitDied = ResetIdleLookAt
OnMsg.VisibilityUpdate = ResetIdleLookAt
OnMsg.CoversChanged = ResetIdleLookAt
OnMsg.CombatObjectDied = ResetIdleLookAt

function OnMsg.EnterSector()
	for _, unit in ipairs(g_Units) do
		UpdateIndoors(unit)
		if HasPerk(unit, "ZombiePerk") then
			unit.stance = "Standing"
		end
	end
end

function OnMsg.UnitDied(dead_unit) -- bandage target death handler
	dead_unit:PlaceBlood()
	if not g_Combat then return end
	for _, unit in ipairs(g_Units) do
		if unit.combat_behavior == "CombatBandage" then
			local target = unit.combat_behavior_params[1]
			if target == dead_unit then
				unit:EndCombatBandage()
			end
		end
	end
end

local function UnitsUpdateCovers(bbox)
	MapForEach(bbox or "map", "Unit", function(u)
		if u:IsDead() or not u:IsAware() then
			return
		end
		if u:HasStatusEffect("Protected") and not GetCoversAt(u) then
			u:RemoveStatusEffect("Protected")
		end
		if u.command == "Idle" then
			u:SetCommand("Idle")
		end
	end)
end
OnMsg.CoversChanged = UnitsUpdateCovers
function OnMsg.CombatObjectDied(obj, bbox)
	UnitsUpdateCovers(bbox)
end

--- Sets the highlight color modifier for the unit.
---
--- @param visible boolean Whether the highlight should be visible or not.
--- @return string "break" to indicate the function should stop executing.
function Unit:SetHighlightColorModifier(visible)
	if not IsValid(self) then return "break" end
	if not visible then
		self.interactable_highlight_ctr = SpawnUnitContour(false, false, self.interactable_highlight_ctr)
	end

	local dead = self:IsDead()
	if not self:IsNPC() and not dead then return "break" end
	if dead then
		return Interactable.SetHighlightColorModifier(self, visible)
	end

	if visible == not not self.interactable_highlight_ctr then return "break" end
	self.interactable_highlight_ctr = SpawnUnitContour(self, "Interact", self.interactable_highlight_ctr)
	return "break"
end

if Platform.developer then
	function TestSpawnNPC(class, pos)
		local session_id = GenerateUniqueUnitDataId("TestNPC", gv_CurrentSectorId or "A1", class)
		return SpawnUnit(class, session_id, pos or GetCursorPos())
	end
end

--- Formats a numerical value as a string with the "AP" suffix.
---
--- @param context_obj any The context object, not used.
--- @param value number The numerical value to format.
--- @return string The formatted string with the "AP" suffix.
TFormat.ap = function(context_obj, value)
	return T{747393774818, "<num> AP", num = value/const.Scale.AP}
end

--- Formats a numerical value as a string with the "AP" suffix.
---
--- @param context_obj any The context object, not used.
--- @param value number The numerical value to format.
--- @return string The formatted string with the "AP" suffix.
TFormat.apn = function(context_obj, value)
	return T{867764319678, "<num>", num = type(value) == "number" and value/const.Scale.AP or value or ""}
end

--- Updates the pathfinding class for the unit based on its team, status effects, and body type.
---
--- If the unit's pathfinding class has been overwritten, this function will not update it.
--- Otherwise, it calculates the appropriate pathfinding class based on the unit's team, stance, and body type, and sets the pathfinding class accordingly.
---
--- @param self Unit The unit object.
function Unit:UpdatePFClass()
	if self.pfclass_overwritten then
		return
	end
	local side = self.team and self.team.side
	if (side == "player1" or side == "player2") and (self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk")) then
		side = "enemy1" -- player units controlled by AI use the same pathfinding rules as the AI units
	end
	local pfclass = CalcPFClass(side, self.stance, self.body_type)
	self:SetPfClass(pfclass)
end

--- Overrides the pathfinding class for the unit.
---
--- If a `pfclass` is provided, it sets the pathfinding class for the unit to the specified value and marks the pathfinding class as overwritten.
--- If no `pfclass` is provided and the pathfinding class was previously overwritten, it resets the pathfinding class to the default value calculated by `Unit:UpdatePFClass()`.
---
--- @param self Unit The unit object.
--- @param pfclass string|nil The pathfinding class to set, or `nil` to reset to the default.
function Unit:OverwritePFClass(pfclass)
	if pfclass then
		self.pfclass_overwritten = pfclass
		self:SetPfClass(pfclass)
	elseif self.pfclass_overwritten then
		self.pfclass_overwritten = false
		self:UpdatePFClass()
	end
end

SuppressTeamUpdate = false

--- Sets the team for the unit.
---
--- If the unit's team is changed, this function updates the unit's pathfinding class, handles awareness and selection changes, and sends appropriate messages.
---
--- @param self Unit The unit object.
--- @param team Team The new team for the unit.
function Unit:SetTeam(team)
	local old_team = self.team
	local aware = self:IsAware()
	self.team = team
	self:UpdatePFClass()
	
	if old_team and team ~= old_team and old_team.side == "neutral" and not team.player_team then
		self:AddStatusEffect("Unaware")
	end
	
	if old_team and team ~= old_team and IsValidTarget(self) then
		local next_unit
		if table.find(Selection or empty_table, self) then
			SelectionRemove(self)
			if #Selection == 0 then
				next_unit = true
			end
		end
		if SelectedObj == self or next_unit then
			local igi = GetInGameInterfaceModeDlg()
			if igi then
				igi:NextUnit()
			end
		end
		if aware and team.side ~= "player1" and team.side ~= "player2" and team.side ~= "neutral" and team.side ~= old_team.side then
			if g_Combat then
				self:AddStatusEffect("Surprised")
			else
				self:AddStatusEffect("Suspicious")
			end
			if old_team and not GameState.sync_loading and not GameState.loading_savegame then
				for _, unit in ipairs(old_team.units) do
					PushUnitAlert("discovered", unit)
				end
				AlertPendingUnits()
			end
		end
	end

	Msg("UnitSideChanged", self, team)
	if not SuppressTeamUpdate then Msg("TeamsUpdated") end
end

--- Sets the side for the unit.
---
--- If the unit's side is changed, this function updates the unit's team, handles awareness and selection changes, and sends appropriate messages.
---
--- @param self Unit The unit object.
--- @param side string The new side for the unit.
function Unit:SetSide(side)
	if not g_Teams or #g_Teams == 0 then SetupDummyTeams() end

	local new_team = table.find_value(g_Teams, "side", side)
	SendUnitToTeam(self, new_team)
	self.CurrentSide = side
	if side ~= "neutral" then
		-- remove forced weapon anim prefix
		for command, params in pairs(self.command_specific_params) do
			params.weapon_anim_prefix = nil
		end
	end
	self:SyncWithSession("map")
end

--- Calculates the combat move cost for the unit to move to the specified position.
---
--- If the unit is already in the same slab as the destination position, the cost is 0.
--- Otherwise, the cost is calculated using the combat path for the unit.
---
--- @param self Unit The unit object.
--- @param pos point The destination position.
--- @return number The combat move cost for the unit to move to the specified position.
function Unit:GetCombatMoveCost(pos)
	if point_pack(SnapToVoxel(pos:xyz())) == point_pack(SnapToVoxel(self:GetPosXYZ())) then
		return 0 -- the unit is in the same slab with the destination
	end
	local combatPath = GetCombatPath(self)
	local ap = combatPath:GetAP(pos)
	return ap
end

--- Gets the closest melee range position for the unit to attack the target.
---
--- If the unit is in combat, the closest melee range position is calculated using the combat path.
--- Otherwise, the closest melee range position is calculated using the pathfinding system.
---
--- @param self Unit The unit object.
--- @param target Unit The target unit.
--- @param target_pos point The position of the target.
--- @param stance string The stance of the unit.
--- @param interaction boolean Whether the position is for an interaction.
--- @return point The closest melee range position.
function Unit:GetClosestMeleeRangePos(target, target_pos, stance, interaction)
	local closest_pos
	if g_Combat then
		local combatPath = GetCombatPath(self, stance)
		closest_pos = combatPath:GetClosestMeleeRangePos(target, target_pos, true, interaction)
	else
		if target.behavior == "Visit" and IsKindOf(target.last_visit, "AL_SitChair") then
			return target.last_visit:GetPos()
		end
		local positions = GetMeleeRangePositions(self, target, target_pos, true)
		if positions then
			for i, packed_pos in ipairs(positions) do
				positions[i] = point(point_unpack(packed_pos))
			end
			local has_path, pf_closest_pos = pf.HasPosPath(self, positions)
			if has_path and table.find(positions, pf_closest_pos) then
				if interaction or not IsKindOf(target, "Unit") or IsMeleeRangeTarget(self, pf_closest_pos, stance, target, target_pos) then
					closest_pos = pf_closest_pos
				end
			end
		end
	end
	return closest_pos
end

--- Calculates the minimum and maximum attack cost range for the given action and target.
---
--- If the action is a FiringModeMetaAction, it will calculate the range for each firing mode action and return the overall minimum and maximum.
--- Otherwise, it will calculate the range based on the unit's base aim level range for the action.
---
--- @param self Unit The unit object.
--- @param action Action The action to calculate the cost range for.
--- @param target Unit The target of the action.
--- @param item_id string The ID of the item used for the action.
--- @return number, number The minimum and maximum attack cost range.
function Unit:CalcAttackCostRange(action, target, item_id)
	if action.group == "FiringModeMetaAction" then
		local _, firingModeActions = GetUnitDefaultFiringModeActionFromMetaAction(self, action)
		local max, min = 0, 1000 * const.Scale.AP
		for i, fm in ipairs(firingModeActions) do
			local mode_min, mode_max = self:CalcAttackCostRange(fm, target)
			max = Max(max, mode_max)
			min = Min(min, mode_min)
		end
		return min, max
	end
	
	local min_aim, max_aim = self:GetBaseAimLevelRange(action)
	local args = {target = target, item_id = item_id}
	local min, max, display_cost
	
	for aim = min_aim, max_aim do
		args.aim = aim
		local ap = action:GetAPCost(self, args)
		if ap > 0 then
			min = Min(min, ap)
			max = Max(max, ap)
		end
	end
	return min, max
end

-- Returns the maximum aim level the unit can use to execute the provided action
---
--- Calculates the minimum and maximum aim level range for the given action and target.
---
--- If the action is an aimable attack, this function will return the minimum and maximum aim level that the unit can use to execute the action.
--- The maximum aim level is determined by the maximum aim actions of the attack weapon, and can be modified by reactions on the unit and target.
--- The minimum aim level is also determined by reactions on the unit and target.
---
--- @param self Unit The unit object.
--- @param action Action The action to calculate the aim level range for.
--- @param target Unit The target of the action.
--- @return number, number The minimum and maximum aim level range.
function Unit:GetBaseAimLevelRange(action, target)
	if not action.IsAimableAttack then return 0, 0 end
	local actionWep = action:GetAttackWeapons(self)
	local min, max = 0, 0
	if IsKindOfClasses(actionWep, "Firearm", "MeleeWeapon") then
		max = actionWep.MaxAimActions
	end
	if max > 0 then
		max = self:CallReactions_Modify("OnCalcMaxAimActions", max, self, target, action, actionWep)
		if IsKindOf(target, "Unit") then
			max = target:CallReactions_Modify("OnCalcMaxAimActions", max, self, target, action, actionWep)
		end
		min = self:CallReactions_Modify("OnCalcMinAimActions", min, self, target, action, actionWep)
		if IsKindOf(target, "Unit") then
			min = target:CallReactions_Modify("OnCalcMinAimActions", min, self, target, action, actionWep)
		end
		max = Max(max, min)
	end
	
	return min, max
end

---
--- Calculates the minimum and maximum aim level range for the given action and target.
---
--- If the action is an aimable attack, this function will return the minimum and maximum aim level that the unit can use to execute the action.
--- The maximum aim level is determined by the maximum aim actions of the attack weapon, and can be modified by reactions on the unit and target.
--- The minimum aim level is also determined by reactions on the unit and target.
---
--- @param self Unit The unit object.
--- @param action Action The action to calculate the aim level range for.
--- @param target Unit The target of the action.
--- @param goto_pos Vector3 The position to move to before executing the action.
--- @param is_free_aim boolean Whether the action is being executed in free aim mode.
--- @return number, number, number The minimum aim level, the maximum current aim level, and the maximum total aim level.
function Unit:GetAimLevelRange(action, target, goto_pos, is_free_aim)
	local minAim, maxCurrent, maxTotal
	minAim, maxTotal = self:GetBaseAimLevelRange(action, target)
		
	for i = 1, maxTotal do
		if action:GetUIState({self}, { target = target, aim = i, goto_pos = goto_pos, free_aim = is_free_aim }) ~= "enabled" then
			maxCurrent = i - 1
			break
		end
	end
	
	return minAim, (maxCurrent or maxTotal), maxTotal
end

---
--- Spawns a new unit and adds it to the specified squad.
---
--- @param merc_id string The ID of the unit to spawn.
--- @param squad table The squad to add the new unit to.
--- @return Unit The newly spawned unit.
function Unit:JoinSquadAs(merc_id, squad)
	local unit = SpawnUnit(merc_id, merc_id, self:GetPos(), self:GetAngle())
	unit:ApplyAppearance(self.Appearance)
	unit:SetState(self:GetState(), 0, 0)
	unit:SetAnimPhase(1, self:GetAnimPhase())
	unit.stance  = self.stance
	unit.current_weapon = self.current_weapon

	local weapon1, weapon2 = self:GetActiveWeapons(false, "strict")
	if IsKindOf(weapon1, "Firearm") then
		unit:Attach(weapon1:CreateVisualObj(unit), unit:GetSpotBeginIndex("Weaponr"))
	end
	if IsKindOf(weapon2, "Firearm") then
		unit:Attach(weapon2:CreateVisualObj(unit), unit:GetSpotBeginIndex("Weaponl"))
	end

	self.villain = false
	self.HitPoints = 0
	self:ClearHierarchyEnumFlags(const.efVisible)

	local tidx = g_Teams and table.find(g_Teams, "side", squad.Side)
	if tidx then
		table.insert(g_Teams[tidx].units, unit)
		unit:SetTeam(g_Teams[tidx])
		ObjModified(unit.team)
	end
	
	AddToGlobalUnits(unit)

	-- Check if trying to join a full squad.
	local unitCount, unitCountWithJoining = GetSquadUnitCountWithJoining(squad.UniqueId)
	if unitCountWithJoining >= const.Satellite.MercSquadMaxPeople then
		local oldSector, oldVisualPos = squad.CurrentSector, squad.VisualPos
		local name = SquadName:GetNewSquadName("player1")
		local squadParams = {Side = "player1", CurrentSector = oldSector, VisualPos = oldVisualPos, Name = name}
		local squad_id = CreateNewSatelliteSquad(squadParams, {merc_id})
		squad = gv_Squads[squad_id]
		Msg("UnitJoinedPlayerSquad",squad_id)
	else
		AddUnitsToSquad(squad, {merc_id}, nil, InteractionRand(nil, "Satellite"))
	end
	
	-- Mark unit as spawned, so satellite doesnt respawn.
	local newUd = gv_UnitData[unit.session_id]
	assert(newUd)
	newUd.already_spawned_on_map = true
	unit.already_spawned_on_map = true

	-- Remove old UD from its squad.
	local ud = gv_UnitData[self.session_id]
	if ud then
		RemoveUnitFromSquad(ud, "despawn")
	end

	if g_Combat then
		Msg("UnitEnterCombat", unit)
	end
	Msg("TeamsUpdated")

	DoneObject(self)
	Msg("UnitJoinedAsMerc", unit)
end

function OnMsg.UnitJoinedPlayerSquad()
	if g_Combat then
		ObjModified(g_Combat)
	else
		ForceUpdateCommonUnitControlUI()
	end
end

---
--- Returns a list of all unique group IDs used by waypoint and grid markers on the map.
---
--- This function scans all waypoint and grid markers on the map and collects the unique group IDs
--- they belong to. The resulting list is sorted and deduplicated.
---
--- @return table A table of unique group IDs used by markers on the map.
---
function GetBehaviorGroups()
	local marker_groups = {}
	for id, group in sorted_pairs(Groups) do
		for _, o in ipairs(group) do
			if IsKindOf(o, "WaypointMarker") or (IsKindOf(o, "GridMarker") and (o.Type == "Position" or o.Type=="Entrance") )then
				marker_groups[#marker_groups + 1] = id
				break
			end
		end
	end
	return marker_groups
end

MapVar("gv_UnitGroups",false)
MapVar("gv_NPCGroups",false)
MapVar("gv_TargetUnitGroups",false)

local groups_separator = "-----------------"

---
--- Returns a list of all unique group IDs used by waypoint and grid markers on the map.
---
--- This function scans all waypoint and grid markers on the map and collects the unique group IDs
--- they belong to. The resulting list is sorted and deduplicated.
---
--- @return table A table of unique group IDs used by markers on the map.
---
function GetUnitSpawnMarkerGroups()
	local marker_groups = {}
	
	MapForEach("map", "UnitMarker", function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	MapForEachMarker("Defender", false, function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	MapForEachMarker("DefenderPriority", false, function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	table.sort(marker_groups)
	-- remove duplicates
	for i = #marker_groups, 2, -1 do
		if marker_groups[i] == marker_groups[i - 1] then
			table.remove(marker_groups, i)
		end
	end
	return marker_groups
end

---
--- Returns a list of all unique unit group IDs used on the map.
---
--- This function recalculates and returns the list of all unique unit group IDs used by various unit markers on the map. The list includes groups for mercs, non-mercs, and any custom groups defined in the `custom_unit_groups` table.
---
--- @return table A table of unique unit group IDs used on the map.
---
function GetUnitGroups()
	if not gv_UnitGroups then
		RecalcGroups()
	end
	return gv_UnitGroups
end

---
--- Returns the list of all unique unit group IDs used on the map.
---
--- This function recalculates and returns the list of all unique unit group IDs used by various unit markers on the map. The list includes groups for mercs, non-mercs, and any custom groups defined in the `custom_unit_groups` table.
---
--- @return table A table of unique unit group IDs used on the map.
---
function GetTargetUnitCombo()
	if not gv_TargetUnitGroups and not IsChangingMap() then
		RecalcGroups()
	end
	return gv_TargetUnitGroups
end

local custom_unit_groups = {"EnemySquad", "Villains"}
g_AnyUnitGroups = { 
	["any"] = true, 
	["any merc"] = true, 
	["current unit"] = true, 
	["player mercs on map"] = true 
}

---
--- Recalculates and returns the list of all unique unit group IDs used by various unit markers on the map.
---
--- This function calculates the list of all unique unit group IDs used on the map, including groups for mercs, non-mercs, and any custom groups defined in the `custom_unit_groups` table. The resulting lists are stored in the `gv_UnitGroups` and `gv_TargetUnitGroups` global variables.
---
--- @return nil
---
function RecalcGroups()
	if GetMap() == "" then return end
	
	local groups = GetUnitSpawnMarkerGroups()
	groups[#groups+1] = groups_separator
	local mercs = {}
	for k,v in pairs(UnitDataDefs) do
		if IsMerc(v) then
			mercs[#mercs+1] = k
		end
	end
	table.sort(mercs)
	table.iappend(groups, mercs)
	groups[#groups+1] = groups_separator
	
	local non_mercs = {}
	for k,v in pairs(UnitDataDefs) do
		if not IsMerc(v) then
			non_mercs[#non_mercs+1] = k
		end
	end
	table.sort(non_mercs)
	table.iappend(groups, non_mercs)
	table.iappend(groups, custom_unit_groups)
	
	gv_UnitGroups = groups
	
	gv_TargetUnitGroups = table.keys2(g_AnyUnitGroups, "sorted")
	table.iappend(gv_TargetUnitGroups, groups)
end

function TFormat.GetNumAliveUnitsInGroup(context, groupName)
	return GetNumAliveUnitsInGroup(groupName)
end

---
--- Returns the number of alive units in the specified group.
---
--- @param group string The name of the unit group.
--- @return integer The number of alive units in the group.
---
function GetNumAliveUnitsInGroup(group)
	local num = 0
	for _, obj in ipairs(Groups and Groups[group]) do
		if IsKindOf(obj, "Unit") and not obj:IsDead() then
			num = num + 1
		end
	end
	return num
end

OnMsg.NewMapLoaded = RecalcGroups
OnMsg.GameExitEditor = RecalcGroups

function OnMsg.UnitDied()
	ObjModified(gv_Quests)
end

GameVar("DeadGroupsInSectors", {})
---
--- Updates the dead groups in the current sector.
---
--- @param groups table A table of group names.
---
function UpdateDeadGroups(groups)
	local deadGroups = DeadGroupsInSectors[gv_CurrentSectorId] or {}
	for _, group in ipairs(groups) do
		local allDead = GetNumAliveUnitsInGroup(group) == 0
		if allDead then
			deadGroups[group] = "all"
		else
			deadGroups[group] = "any"
		end
	end
	DeadGroupsInSectors[gv_CurrentSectorId] = deadGroups
end

function OnMsg.UnitDieStart(unit)
	UpdateDeadGroups(unit.Groups)
end

function OnMsg.VillainDefeated(unit)
	UpdateDeadGroups(unit.Groups)
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "StepRun")
	table.insert(list, "StepWalk")
	table.insert(list, "StepRunCrouch")
	table.insert(list, "StepRunProne")

	table.insert(list, "Interact")
	for i,combat_action in ipairs(Presets.CombatAction.Interactions) do
		table.insert(list, combat_action.id)
	end
end

function OnMsg.GatherFXActors(list)
	table.insert(list, "Unit")
end

---
--- Automatically removes any combat-related status effects from the unit.
---
--- This function iterates through the unit's status effects and removes any
--- that have the `RemoveOnEndCombat` flag set in their definition.
---
--- @param self Unit The unit to remove combat effects from.
---
function Unit:AutoRemoveCombatEffects()
	local effect_ids = table.map(self.StatusEffects or empty_table, "class")
	for _, id in ipairs(effect_ids) do
		local def = CharacterEffectDefs[id]
		if def and def.RemoveOnEndCombat then
			self:RemoveStatusEffect(id, "all")
		end
	end
end

local ExitCombatUninterruptable = {
	["Visit"] = true,
	["EnterMap"] = true,
	["Cower"] = true,
}

function OnMsg.CombatEnd(combat)
	MapForEach("map", "Unit", function(unit)
		unit:AutoRemoveCombatEffects()
		if not unit:IsDead() and g_Overwatch[unit] and (not g_Overwatch[unit].permanent or unit.team.control ~= "UI") then
			unit:InterruptPreparedAttack()
			unit:RemovePreparedAttackVisuals()
		end
		if not unit:IsDead() or unit.immortal then
			local overwatch = g_Overwatch[unit]
			if not ExitCombatUninterruptable[unit.command] then
				if overwatch and overwatch.permanent then
					-- only check for reload
					unit:UpdateNumOverwatchAttacks()
					CreateGameTimeThread(Unit.AutoReload, unit)
				else
					unit:InterruptCommand("ExitCombat")
				end
			end
		end
	end)
end

---
--- Checks if the given unit is adjacent to the current unit.
---
--- @param other Unit The other unit to check adjacency with.
--- @param check_pos? Vector3 An optional position to check adjacency from, instead of the unit's current position.
--- @return boolean True if the units are adjacent, false otherwise.
---
function Unit:IsAdjacentTo(other, check_pos)
	local x, y, z
	if check_pos then
		x, y, z = PosToGridCoords(check_pos:xyz())
	else
		x, y, z = self:GetGridCoords()
	end
	
	local ox, oy, oz = other:GetGridCoords()

	return abs(x - ox) <= 1 and abs(y - oy) <= 1 and abs(z - oz) <= 1
end

---
--- Checks if the given unit can surround the other unit.
---
--- @param other Unit The other unit to check if this unit can surround.
--- @param check_pos? Vector3 An optional position to check surrounding from, instead of the unit's current position.
--- @return boolean True if the unit can surround the other unit, false otherwise.
---
function Unit:CanSurround(other, check_pos)
	-- side
	if not self:IsOnEnemySide(other) or self:IsDead() or self:IsDowned() then
		return false
	end
	
	-- status effects
	if self:HasStatusEffect("Suppressed") then
		return false
	end
	
	-- Not valid gameplay wise, but happens in some rare cases and fires asserts down the line.
	local pos = check_pos or self:GetPos()
	if other:GetPos() == pos then
		return false
	end
	
	-- visibility
	if check_pos then
		-- checking from another position, use CheckLOS
		if not CheckLOS(other, self, self:GetSightRadius()) then
			return false
		end
	else
		-- checking from current position, can use precomputed visibility
		if not HasVisibilityTo(self, other) then
			return false
		end
	end
	
	-- weapon range
	local adjacent = self:IsAdjacentTo(other, check_pos)
	local in_range = false
	local w1, w2, weapons = self:GetActiveWeapons()
	for _, weapon in ipairs(weapons) do
		if IsKindOf(weapon, "Firearm") or (IsKindOf(weapon, "MeleeWeapon") and weapon.CanThrow) then
			-- heavy weapons are Firearms and go here too
			in_range = in_range or other:GetDist(pos) <= weapon.WeaponRange * const.SlabSizeX
		elseif IsKindOf(weapon, "MeleeWeapon") then
			in_range = in_range or adjacent
		end
	end
	
	return in_range
end

---
--- Checks if the given unit is surrounded by enemy units.
---
--- @param unitReplace table|nil A table that maps units to their replacement positions. If provided, the function will use the replacement positions instead of the units' actual positions.
--- @return boolean true if the unit is surrounded, false otherwise
---
function Unit:IsSurrounded(unitReplace)
	if not g_Visibility or not g_Combat or self:IsDead() then
		return
	end
	
	local pos = unitReplace and unitReplace[self] or self:GetPos()
	local enemy_pos = {}
	local angle = 120*60
	local cosa = MulDivRound(cos(angle), guim*guim, 4096)

	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, u in ipairs(team.units) do
				if u:CanSurround(self, unitReplace and unitReplace[u]) then
					enemy_pos[#enemy_pos + 1] = unitReplace and unitReplace[u] or u:GetPos()
				end
			end
		end
	end
	if #enemy_pos < 2 then
		return
	end
	local pts = ConvexHull2D(enemy_pos)

	for i = 1, #pts - 1 do
		local v1 = pts[i]:Equal2D(pos) and point30 or SetLen(pts[i] - pos, guim)
		for j = i + 1, #pts do
			local v2 = pts[j]:Equal2D(pos) and point30 or SetLen(pts[j] - pos, guim)
			local dp = Dot2D(v1, v2)
			if dp < cosa then
				return true
			end
		end
	end	
end

---
--- Interpolates a cover effect value based on the given coverage percentage.
---
--- @param coverage number The coverage percentage, between 0 and 100.
--- @param full_value number The full cover value.
--- @param exposed_value number The exposed value.
--- @return number The interpolated cover effect value.
---
function InterpolateCoverEffect(coverage, full_value, exposed_value)
	local threshold = 40
	if coverage >= 80 then
		return full_value
	elseif coverage < threshold then
		return exposed_value
	end
	return exposed_value + MulDivRound(full_value - exposed_value, coverage - threshold, threshold)
end

---
--- Applies damage reduction from armor to a hit.
---
--- @param hit table The hit information, including damage, effects, and other details.
--- @param weapon table The weapon used in the attack.
--- @param hit_body_part string The body part that was hit.
--- @param ignore_cover boolean Whether to ignore cover when calculating damage reduction.
--- @param ignore_armor boolean Whether to ignore armor when calculating damage reduction.
--- @param record_breakdown boolean Whether to record a breakdown of the damage reduction calculations.
--- @return nil
---
function Unit:ApplyHitDamageReduction(hit, weapon, hit_body_part, ignore_cover, ignore_armor, record_breakdown)
	local damage = hit.damage or 0
	hit.damage = damage
	local weapon_pen_class = weapon:HasMember("PenetrationClass") and weapon.PenetrationClass or 1
	self:ForEachItem("Armor", function(item, slot, left, top, hit, ignore_armor, record_breakdown, weapon_pen_class)
		if hit.damage > 0 and slot ~= "Inventory" and item.ProtectedBodyParts and item.ProtectedBodyParts[hit_body_part] then
			local dr, degrade, pierced
			if not ignore_armor and item.Condition > 0 then
				dr = item.DamageReduction
				degrade = item.Degradation
				if weapon_pen_class < item.PenetrationClass then
					dr = dr + item.AdditionalReduction
					degrade = MulDivRound(degrade, const.Combat.ArmorDegradePercent, 100)
				else
					pierced = true
				end
			else
				pierced = true
			end
			-- scale DR down on poor condition
			dr = MulDivRound(dr or 0, Min(100, 50 + item.Condition), 100)

			local scaled = hit.damage * (100 - dr)
			local result = scaled / 100
			if pierced and scaled % 100 > 0 then
				-- round the resulting damage up when pierced only
				result = result + 1
			end

			if record_breakdown then
				if pierced then
					record_breakdown[#record_breakdown + 1] = { name = T{191288543859, "<em><DisplayName></em> (Pierced)", item}, value = -dr }
				else
					record_breakdown[#record_breakdown + 1] = { name = T{516752639882, "<em><DisplayName></em>", item}, value = -dr }
				end
			end

			hit.damage = Min(hit.damage, result)
			if not hit.armor_decay then hit.armor_decay = {} end
			if not hit.armor_pen then hit.armor_pen = {} end
			hit.armor_decay[item] = Min(item.Condition, degrade or 0)
			if pierced then
				hit.armor_pen[item] = true
			end
		end
	end, hit, ignore_armor, record_breakdown, weapon_pen_class)

	local armor_prevented = damage - hit.damage

	-- HoldPosition perk damage reduction
	if HasPerk(self, "HoldPosition") and (g_Overwatch[self] or g_Pindown[self]) then
		local statPercent = CharacterEffectDefs.HoldPosition:ResolveValue("percentHealth")
		local percent_reduction = MulDivRound(self.Health, statPercent, 100)
		if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = CharacterEffectDefs.HoldPosition.DisplayName, value = -percent_reduction } end
		hit.damage = Max(0, MulDivRound(hit.damage, 100 - percent_reduction, 100))
	end

	local armor = next(hit.armor_decay)
	hit.armor = armor and armor.DisplayName
	hit.armor_prevented = armor_prevented
end

---
--- Checks if the unit has any armor equipped that protects the specified body part group.
---
--- @param target_spot_group string|nil The body part group to check for armor protection. If nil, checks all equipped armor.
--- @return boolean|table, string|false, string Whether armor was found, the icon name for the highest penetration class, and the icon path.
---
function Unit:IsArmored(target_spot_group)
	if self:IsDead() then return false end
	local armorFound = false
	self:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and (not target_spot_group or item.ProtectedBodyParts and item.ProtectedBodyParts[target_spot_group]) then 
			armorFound = item
			return "break"
		end
	end)
	
	local iconName = false
	if armorFound and armorFound.PenetrationClass > 1 then
		local classId = PenetrationClassIds[armorFound.PenetrationClass]
		iconName = classId:lower() .. "_armor"
	end
	
	return armorFound, iconName, "UI/Hud/"
end

---
--- Applies damage and effects to a unit.
---
--- @param attacker Unit The unit that is attacking.
--- @param damage number The amount of damage to apply.
--- @param hit table The hit information.
--- @param armor_decay table The armor decay information.
---
function Unit:ApplyDamageAndEffects(attacker, damage, hit, armor_decay)
	if self:IsDead() or not IsValid(self) then return end

	if damage and damage > 0 or hit.setpiece then
		self:TakeDamage(damage or 0, attacker, hit)	
	end
	
	local invulnerable = self:IsInvulnerable()
	if not invulnerable then
		local effects = hit.effects
		if type(effects) == "string" and effects ~= "" then
			self:AddStatusEffect(effects)
		else
			for _, effect in ipairs(effects) do
				if effect and effect ~= "" then
					self:AddStatusEffect(effect)
				end
			end
		end
	end
	
	-- blood/soot stains
	local was_wounded = self:HasStatusEffect("Wounded")
	if hit.direct_shot then -- bullet-simulated firearm attacks
		local spot, params = CalcStainParamsFromShot(self, attacker, hit)
		if spot then
			assert(not params or type(params) == "table")
			self:AddStain("Blood", spot, params)
		end
	elseif not was_wounded then
		-- pick a spot and save it as effect value for the Wounded status to use if it gets applied
		local spot
		if hit.melee_attack then
			spot = GetRandomStainSpot(hit.spot_group)
		else
			spot = GetRandomStainSpot()
		end
		if spot then
			self:SetEffectValue("wounded_stain_spot", spot)
		end
	end
	
	-- cleanup wounded_stain_spot
	self:SetEffectValue("wounded_stain_spot", nil)
	
	-- add soot from explosions (if there's no blood)
	if hit.explosion and not self:HasStainType("Blood") then
		local spot = GetRandomStainSpot()
		self:AddStain("Soot", spot)
	end
		
	if not invulnerable then
		local change = false
		for item, degrade in pairs(armor_decay) do
			item.Condition = self:ItemModifyCondition(item, - degrade)
			if IsKindOf(item, "TransmutedItemProperties") and item.RevertCondition=="damage" then
				item.RevertConditionCounter = item.RevertConditionCounter-1
				if item.RevertConditionCounter== 0 then
					local slot_name = self:GetItemSlot(item)
					local new, prev = item:MakeTransmutation("revert")
					armor_decay[new] = degrade
					armor_decay[item] = false
					self:RemoveItem(slot_name, item)
					self:AddItem(slot_name, new)					
					DoneObject(prev)
					change = true
				end
			end	
		end
		if change then
			self:UpdateOutfit()
		end
	end
end

---
--- Swaps the active weapon of the unit.
---
--- @param action_id number The action ID associated with the weapon swap.
--- @param cost_ap number The AP cost of the weapon swap.
---
function Unit:SwapActiveWeapon(action_id, cost_ap)
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "IModeCombatBase") and igi.attacker == self then
		InvokeShortcutAction(igi, "ExitAttackMode", igi)
	end

	if self.current_weapon == "Handheld A" then
		self.current_weapon = "Handheld B"
	else
		self.current_weapon = "Handheld A"
	end

	self:OnSetActiveWeapon(action_id, cost_ap)
end

---
--- Sets the active weapon of the unit and performs related actions.
---
--- @param action_id number The action ID associated with the weapon swap.
--- @param cost_ap number The AP cost of the weapon swap.
---
function Unit:OnSetActiveWeapon(action_id, cost_ap)
	if not self.current_weapon then return end
	if HasPerk(self, "Scoundrel") and g_Combat then
		self:ActivatePerk("Scoundrel")
		PlayVoiceResponse(self, "Scoundrel")
	end
	if GameTimeAdvanced then
		if g_Overwatch[self] and not self:FindWeaponInSlotById(self.current_weapon, g_Overwatch[self].weapon_id) or
			g_Pindown[self] and not self:FindWeaponInSlotById(self.current_weapon, g_Pindown[self].weapon_id) or
			self.prepared_bombard_zone and not self:FindWeaponInSlotById(self.current_weapon, self.prepared_bombard_zone.weapon_id)
		then
			self:InterruptPreparedAttack()
		end
	end
	self:UpdateOutfit(self.Appearance)
	self:RecalcUIActions()
	--self.lastFiringMode = false
	self:SetAimTarget(false, false)
	if not cost_ap or cost_ap == 0 then
		-- if the action was free we still want the UI to reflect possible differences
		Msg("UnitAPChanged", self, action_id) 
	end
	Msg("UnitSwappedWeapon", self)
	ObjModified(self)
end

---
--- Starts the AI for the unit.
---
--- @param debug_data table Optional debug data to be used for the AI.
--- @param forced_behavior AIBehavior Optional behavior to force the AI to use.
---
--- @return boolean True if the AI was successfully started, false otherwise.
---
function Unit:StartAI(debug_data, forced_behavior)
	if not IsValid(self) or self:IsDead() or self.ai_context or self:HasStatusEffect("Unconscious") then
		return
	end
	AIReloadWeapons(self)
	
	local proto_context = {}
	self:SelectArchetype(proto_context)
	
	--local context = AICreateContext(self, proto_context)
	--local archetype = context.archetype
	local archetype = self:GetArchetype()
	
	local scores, available = {}, {}
	local total = 0

	AIUpdateBiases()
	for i, behavior in ipairs(archetype.Behaviors) do
		local weight_mod, disable, priority
		if behavior:MatchUnit(self) then
			weight_mod, disable, priority = AIGetBias(behavior.BiasId, self)
			priority = priority or behavior.Priority
		else
			weight_mod, disable, priority = 0, true, false
		end

		if debug_data then
			debug_data.behaviors = debug_data.behaviors or {}
			debug_data.behaviors[i] = {
				name = behavior:GetEditorView(),
				priority = priority,
				disable = disable,
				behavior = behavior,
				index = i,
			}
		end

		if not disable then
			local score = MulDivRound(behavior:Score(self, proto_context, debug_data), weight_mod, 100)
			if debug_data then
				debug_data.behaviors[i].score = score
			end
			if score > 0 then
				if priority and not forced_behavior then
					forced_behavior = behavior
					break
				end
				scores[#scores + 1] = score
				available[#available + 1] = behavior
				total = total + score
			end
		end
	end
	
	if total == 0 and not forced_behavior then 
		printf("unit of %s archetype failed to select a behavior!", archetype.id)
		return
	end
	
	local roll = InteractionRand(total, "AIBehavior", self)
	local selected
	if not forced_behavior then
		for i, behavior in ipairs(available) do
			local score = scores[i]
			if roll <= score then
				selected = behavior
				break
			end
			roll = roll - score
		end
	end
	
	if self.ai_context then
		self.ai_context.behavior = forced_behavior or selected or available[#available]
	else
		proto_context.behavior = forced_behavior or selected or available[#available]
		AICreateContext(self, proto_context)
	end
	if self.ai_context.behavior then
		self.ai_context.behavior:OnStart(self)
	end
	return true
end

---
--- Updates the "Flanked" status effect for all units based on whether they are surrounded or not.
---
--- This function iterates through all units in the `g_Units` table and checks if each unit is surrounded. If a unit is surrounded, it adds the "Flanked" status effect to that unit. If a unit is not surrounded, it removes the "Flanked" status effect from that unit.
---
--- @function UpdateSurrounded
--- @return nil
function UpdateSurrounded()	
	for _, unit in ipairs(g_Units) do
		if unit:IsSurrounded() then
			unit:AddStatusEffect("Flanked")
		else
			unit:RemoveStatusEffect("Flanked")
		end
	end
end

---
--- Rolls a skill check for the given unit and skill, with optional modifiers.
---
--- @param unit UnitPropertiesStats The unit performing the skill check.
--- @param skill string The name of the skill being checked.
--- @param modifier number (optional) A percentage modifier to apply to the skill value.
--- @param add number (optional) A value to add to the skill value.
--- @return boolean True if the skill check passes, false otherwise.
---
function RollSkillCheck(unit, skill, modifier, add)
	assert(IsKindOf(unit, "UnitPropertiesStats"))
	
	modifier = modifier or 100
	add = add or 0
	
	local roll = 1 + unit:Random(100)
	--adjust roll based on diff
	local adjustRoll = GameDifficulties[Game.game_difficulty]:ResolveValue("rollSkillCheckBonus") or 0
	roll = roll + adjustRoll
	roll = Min(roll, 95)
	
	local value = MulDivRound(unit[skill], modifier, 100) + add
	local pass = roll < value or CheatEnabled("SkillCheck")
	
	--CombatLog("debug", 
	local t_res = pass and Untranslated("<em>Pass</em>") or Untranslated("<em>Fail</em>")
	local meta = unit:GetPropertyMetadata(skill)
	local t_skill = meta.name
	if modifier ~= 100 then
		if add > 0 then
			t_skill = T{816405633181, "<percent(n1)> <skill>+<n2>", n1 = modifier, n2 = add, skill = meta.name}
		elseif add < 0 then
			t_skill = T{656059859333, "<percent(n1)> <skill><n2>", n1 = modifier, n2 = add, skill = meta.name}
		else
			t_skill = T{570928040607, "<percent(number)> <skill>", number = modifier, skill = meta.name}
		end
	elseif add > 0 then
		t_skill = T{481345361355, "<skill>+<number>", number = add, skill = meta.name}
	elseif add < 0 then
		t_skill = T{945399039468, "<skill><number>", number = add, skill = meta.name}
	end
	
	CombatLog("debug", T{Untranslated("<em><name><em> Skill check (<em><skill></em>) <roll>/<target>: <result>"), 
		name = unit:GetLogName(),
		skill = t_skill,
		roll = roll, 
		target = value,
		result = t_res,
	})
	return pass
end

---
--- Performs a skill check for the given unit and skill.
---
--- @param unit UnitPropertiesStats The unit performing the skill check.
--- @param skill string The name of the skill being checked.
--- @param threshold number The minimum value required to pass the skill check.
--- @param dont_report_fails boolean (optional) If true, don't log a failure message.
--- @return string "success" if the skill check passes, "fail" if it fails, or "error" if the input is invalid.
--- @return number The difference between the skill value and the threshold (positive if passed, negative if failed).
--- @return number The current skill value of the unit.
---
function SkillCheck(unit, skill, threshold,dont_report_fails)
	if not unit or not IsKindOf(unit, "UnitPropertiesStats") then return "error" end
	local stat = unit[skill]
	if not stat then return "error" end
	if threshold <= stat or CheatEnabled("SkillCheck") then
		CombatLog("debug", "(success) " .. unit.session_id .. " " .. skill.. " check (" .. stat.. " / " ..threshold .. ")")
		PlayFX("SkillCheck", "success", unit, skill)
		return "success", stat - threshold, stat
	end	
	if not dont_report_fails then
		PlayFX("SkillCheck", "fail", unit, skill)
		CombatLog("debug", "(fail) " .. unit.session_id .." " .. skill.. " check (" .. stat.. " / " ..threshold .. ")")
	end
	return "fail", threshold - stat, stat
end

---
--- Spawns a new unit with the given class, session ID, position, angle, groups, spawner, and entrance.
---
--- @param class string The class of the unit to spawn.
--- @param session_id string The session ID of the unit to spawn.
--- @param pos table The position to spawn the unit at.
--- @param angle number The angle to set the unit's orientation to.
--- @param groups table A list of groups to add the unit to.
--- @param spawner UnitMarker|GridMarker The spawner object that is spawning the unit.
--- @param entrance UnitMarker|GridMarker The entrance marker that the unit is spawning from.
--- @return Unit The newly spawned unit.
---
function SpawnUnit(class, session_id, pos, angle, groups, spawner, entrance)
	session_id = session_id or class
	NetUpdateHash("SpawnUnit", class, session_id, pos)
	local unit_data = CreateUnitData(class, session_id, InteractionRand(nil, "Satellite"))

	local unit_group = UnitDataDefs[unit_data.class].group
	local unit = Unit:new{ 
		unitdatadef_id = unit_data.class,
		group = unit_group,
		session_id = session_id,
		spawner = spawner,
		entrance_marker = entrance,
	}

	AddToGlobalUnits(unit)

	for _, group in ipairs(groups) do
		unit:AddToGroup(group)
	end

	if angle then
		unit:SetAngle(angle)
	end
	if pos then
		unit:SetPos(pos)
	end

	if unit:IsNPC() and not unit.dummy then
		if IsKindOf(spawner, "UnitMarker") then
			for _, effect in ipairs(spawner.status_effects) do
				if CharacterEffectDefs[effect] then
					unit:AddStatusEffect(effect)
				end
			end
		end
		if IsKindOf(spawner, "GridMarker") and spawner.Suspicious or IsKindOf(entrance, "GridMarker") and entrance.Suspicious then
			unit:AddStatusEffect("HighAlert")
			if not spawner or spawner.Side ~= "neutral" then
				unit:AddStatusEffect("Unaware")
			end
		else
			local data = gv_UnitData[session_id]
			local squad_idx = data and data.Squad and table.find(g_SquadsArray, "UniqueId", data.Squad)
			local squad = squad_idx and g_SquadsArray[squad_idx]
			if squad and squad.militia then
				unit:AddStatusEffect("HighAlert")
			elseif not spawner or spawner.Side ~= "neutral" then
				unit:AddStatusEffect("Unaware")
			end
		end
	end
	unit:SetTargetDummyFromPos()

	return unit
end

---
--- Validates the unit group for effect execution.
---
--- @param group string The group to validate.
--- @param effect table The effect to validate.
--- @param trigger_obj table The trigger object.
--- @return table The units in the group, or an empty table if the group is invalid.
---
function ValidateUnitGroupForEffectExec(group, effect, trigger_obj)
	local units = Groups[group]
	if Platform.developer and GameState.entered_sector and not units then
		local trigger_obj_idx = 1
		local errs = {}
		local sector_ids, effect_classes = {}, {}
		
		local function addErr(effect, parents, obj)
			if effect:HasMember("Group") and effect.Group == group then
				if obj == trigger_obj then
					trigger_obj_idx = #errs + 1
				end
				if IsKindOf(obj, "QuestsDef") then
					errs[#errs + 1] = {obj, string.format("Effect %s with invalid group %s in quest %s", effect.class, group, obj.id)}
				elseif IsKindOf(obj, "SatelliteSector") then
					sector_ids[#sector_ids + 1] = obj.Id
					effect_classes[#effect_classes + 1] = effect.class
				elseif IsKindOf(obj, "GridMarker") then
					errs[#errs + 1] = {obj, string.format("Effect %s with invalid group %s in marker", effect.class, group)}
				end
			end
		end
		
		-- check quest effects
		ForEachPresetInCampaign("QuestsDef", function(quest)
			if quest.TCEs and next(quest.TCEs) then
				for _, tce in ipairs(quest.TCEs) do
					tce:ForEachSubObject("Effect", addErr, quest)
				end
			end
		end)
		
		-- check sector effects
		local campaign_preset = Game.Campaign and CampaignPresets[Game.Campaign]
		for _, sector in ipairs(campaign_preset and campaign_preset.Sectors) do
			for _, event in ipairs(sector.Events) do
				sector:ForEachSubObject("Effect", addErr, sector)
			end
		end
		if next(sector_ids) then
			errs[#errs + 1] = {campaign_preset, string.format("Effects - %s - with invalid group %s in sectors: %s", table.concat(effect_classes, ", "), group, table.concat(sector_ids, ", "))}
		end
		
		--check grid marker effects
		MapForEachMarker("GridMarker", nil, function(marker)
			marker:ForEachSubObject("Effect", addErr, marker)
		end)
		
		errs[1], errs[trigger_obj_idx] = errs[trigger_obj_idx], errs[1]
		for _, err in ipairs(errs) do
			StoreErrorSource(err[1], err[2])
		end
	end
	return units or empty_table
end

OnMsg.VisibilityUpdate = UpdateSurrounded
OnMsg.CombatApplyVisibility = UpdateSurrounded
OnMsg.CombatStart = UpdateSurrounded
OnMsg.CombatEnd = UpdateSurrounded

function OnMsg.CombatStart(dynamic_data)
	local transfer_keys = {
		"hmg_emplacement",
		"spent_ap",
		"PrisonDoor",
		"CellLeaveBanters"
	}

	for _, unit in ipairs(g_Units) do
		if unit.team.side == "neutral" and not unit.behavior then
			unit:SetBehavior("GoBackAfterCombat", {unit:GetPos()})
		end
		if not dynamic_data then
			local values = {}
			for i, key in ipairs(transfer_keys) do
				values[i] = unit:GetEffectValue(key)				
			end
			unit.effect_values = nil -- reset effect data on combat start
			for i, key in ipairs(transfer_keys) do
				if values[i] ~= nil then
					unit:SetEffectValue(key, values[i])
				end					
			end
			if unit.carry_flare then
				unit:RoamDropFlare()
			end
		end
		unit.marked_target_attack_args = nil	-- invalid in combat
		unit.neutral_retal_attacked = nil
	end
end

DefineClass.DummyUnit = {
	__parents = { "AppearanceObject" },
	flags = { gofPermanent = true, gofUnitLighting = false },
	properties = {
		{category = "Dummy Unit", id = "UnitLighting", name = "Unit Lighting", editor = "bool",
			default = false,
		},
		{category = "Dummy Unit", id = "FreezePhase", name = "Freeze Phase", editor = "number",
			default = false, slider = true, min = 0,
			max = function(obj)
				return GetAnimDuration(obj:GetEntity(), obj.anim) - 1
			end,
			help = "The unit will be freezed at this frame.",
		},
	},
	entity = "Male",
	Appearance = "Raider_01",
}

--- Called when the DummyUnit is initialized. Updates the freeze phase of the unit's animation.
function DummyUnit:GameInit()
	self:UpdateFreezePhase()
end

--- Called when a property of the DummyUnit is changed in the editor.
--- Updates the freeze phase of the unit's animation if the "FreezePhase" or "anim" property is changed.
function DummyUnit:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "FreezePhase" or prop_id == "anim" then
		self:UpdateFreezePhase()
	end
end

--- Updates the freeze phase of the unit's animation.
---
--- This function is called to update the freeze phase of the DummyUnit's animation. If the "FreezePhase" property is set, it sets the animation pose to the specified frame. Otherwise, it sets the animation speed modifier to 1000 to play the animation at normal speed.
---
--- @param self DummyUnit The DummyUnit instance.
function DummyUnit:UpdateFreezePhase()
	local phase = self:GetProperty("FreezePhase")
	if phase then
		self:SetAnimPose(self.anim, phase)
		self:SetAnimSpeedModifier(0)
	else
		self:SetAnimSpeedModifier(1000)
	end
end

-- NOTE: Level Designers are setting the anim through StateText which gets overridden by 'anim' property
--- Sets the state text and animation of the DummyUnit.
---
--- This function is called to update the state text and animation of the DummyUnit. It first calls the `SetStateText` function of the `AppearanceObject` class to set the state text, and then sets the `anim` property of the DummyUnit to the provided `state` value.
---
--- @param self DummyUnit The DummyUnit instance.
--- @param state string The new state text and animation to set.
function DummyUnit:SetStateText(state)
	AppearanceObject.SetStateText(self, state)
	self:SetProperty("anim", state)
end

--- Sets the unit lighting flag for the DummyUnit.
---
--- This function is used to set or clear the unit lighting flag for the DummyUnit. When the flag is set, the unit will be affected by lighting. When the flag is cleared, the unit will not be affected by lighting.
---
--- @param self DummyUnit The DummyUnit instance.
--- @param value boolean True to set the unit lighting flag, false to clear it.
function DummyUnit:SetUnitLighting(value)
	if value then
		self:SetHierarchyGameFlags(const.gofUnitLighting)
	else
		self:ClearHierarchyGameFlags(const.gofUnitLighting)
	end
	self:DestroyRenderObj()
end

--- Gets whether the unit's lighting is enabled.
---
--- This function returns a boolean indicating whether the unit's lighting is enabled. When the unit lighting flag is set, the unit will be affected by lighting. When the flag is cleared, the unit will not be affected by lighting.
---
--- @param self DummyUnit The DummyUnit instance.
--- @return boolean True if the unit lighting is enabled, false otherwise.
function DummyUnit:GetUnitLighting(value)
	return self:GetGameFlags(const.gofUnitLighting) ~= 0
end

--- Hangs a unit from a specified group.
---
--- This function is used to hang a unit from a group. It first retrieves all the units in the specified group, and ensures that there is exactly one unit in the group. If there is not exactly one unit, an error is stored. Otherwise, the function sets the command of the unit to "Hang" and removes the unit from any groups it was previously a part of.
---
--- @param group_id string The ID of the group containing the unit to hang.
function ErnyTown_HangUnit(group_id)
	local group = Groups[group_id]
	local units = {}
	for _, o in ipairs(group) do
		if IsKindOf(o, "Unit") then
			table.insert(units, o)
		end
	end	
	if #units ~= 1 then
		StoreErrorSource(point30, "There should be exactly one unit of the group " .. group_id)
		return
	end
	local unit = units[1]
	unit:SetCommand("Hang")
	unit:SetGroups(false)
end

function OnMsg.ValidateMap()
	if Game and not g_IdleAnimActionStances then
		FillIdleAnimActionsAndStances()
	end
end

function OnMsg.ChangeMapDone(map)
	if IsModEditorMap(map) and not g_IdleAnimActionStances then
		FillIdleAnimActionsAndStances()
	end
end

if FirstLoad then
	g_IdleAnimActionStances = false
end

local function GetAllEntitiesValidAnimations()
	local dummy = PlaceObject("Unit", {
		NetUpdateHash = empty_func,
		IsSyncObject = function(self) return false end,
	})
	dummy:ClearGameFlags(const.gofSyncObject)
	dummy:SetCommand(false)
	dummy:SetPos(point30)
	
	local anims = {}
	for id, app in sorted_pairs(AppearancePresets) do
		if app.Body then
			dummy:ApplyAppearance(AppearancePresets[id])
			if IsValidEntity(dummy:GetEntity()) then
				dummy:SetState("idle")
				local dummy_anims = ValidAnimationsCombo(dummy)
				for _, a in ipairs(dummy_anims) do
					anims[a] = true
				end
			end
		end
	end
	DoneObject(dummy)
	
	return anims
end

---
--- Fills the `g_IdleAnimActionStances` table with the valid idle animation actions and stances for entities in the game.
---
--- This function is called when the map is loaded or changed, to ensure the idle animation data is up-to-date.
---
--- It first initializes the `g_IdleAnimActionStances` table with default values, then populates it by iterating over all the appearance presets and checking the valid animations for each.
---
--- The resulting table maps animation names to the corresponding stances and actions, categorized by whether the entity is wielding a weapon or not.
---
function FillIdleAnimActionsAndStances()
	g_IdleAnimActionStances = {
		no_weapon = {g_StanceActionDefault, [g_StanceActionDefault] = {g_StanceActionDefault}},
		weapon = {g_StanceActionDefault, [g_StanceActionDefault] = {g_StanceActionDefault}}
	}
	
	local anims = GetAllEntitiesValidAnimations()
	for a, _ in sorted_pairs(anims) do
		local prefix, stance, action = string.match(a, "(.*)_(.*)_(.*)")
		if prefix and stance and action then
			local key = prefix == "civ" and "no_weapon" or "weapon"
			table.insert_unique(g_IdleAnimActionStances[key], stance)
			g_IdleAnimActionStances[key][stance] = g_IdleAnimActionStances[key][stance] or {g_StanceActionDefault}
			table.insert_unique(g_IdleAnimActionStances[key][stance], action)
		end
	end
end

---
--- Returns the valid idle animation actions and stances for a unit based on whether it is wielding a weapon or not.
---
--- @param use_weapons boolean Whether the unit is wielding a weapon or not.
--- @return table The table of valid idle animation actions and stances.
---
function GetIdleAnimStances(use_weapons)
	assert(g_IdleAnimActionStances)
	return g_IdleAnimActionStances[use_weapons and "weapon" or "no_weapon"]
end

---
--- Returns the valid idle animation actions for a unit based on whether it is wielding a weapon or not, and the current stance.
---
--- @param use_weapons boolean Whether the unit is wielding a weapon or not.
--- @param stance string The current stance of the unit.
--- @return table The table of valid idle animation actions for the given stance.
---
function GetIdleAnimStanceActions(use_weapons, stance)
	assert(g_IdleAnimActionStances)
	return g_IdleAnimActionStances[use_weapons and "weapon" or "no_weapon"][stance]
end

---
--- Resolves the UI action associated with the given index.
---
--- @param idx number The index of the UI action to resolve.
--- @return table|nil The combat action associated with the UI action, or nil if no action is found.
---
function Unit:ResolveUIAction(idx)
	local id = self.ui_actions and self.ui_actions[idx]
	return id and self.ui_actions[id] and CombatActions[id]
end

---
--- Checks if the unit is aware of its surroundings.
---
--- @param check_pending boolean Whether to check the pending aware state of the unit.
--- @return boolean True if the unit is aware, false otherwise.
---
function Unit:IsAware(check_pending)
	if self.team and self.team.side == "neutral" or self.command == "Die" or self:IsDead() then
		return false
	end
	local status_effects = self.StatusEffects
	if check_pending then
		if self.pending_aware_state == "aware" or self.pending_aware_state == "surprised" or status_effects["Surprised"] then
			return true
		end
	end
	return not status_effects["Unaware"] and not status_effects["Suspicious"] and not status_effects["Surprised"]
end

--- Checks if the unit is in a suspicious state.
---
--- @return boolean True if the unit is in a suspicious state, false otherwise.
function Unit:IsSuspicious()
	if self:IsDead() or self.command == "Die" then return false end
	return self:HasStatusEffect("Suspicious")
end

---
--- Adds an item to the unit's inventory, stacking it if possible.
---
--- @param item_id string The ID of the item to add to the inventory.
--- @param amount number The amount of the item to add.
--- @param callback function (optional) A callback function to be called after the item is added.
--- @return number The remaining amount of the item that could not be added.
---
function Unit:AddToInventory(item_id, amount, callback)
	if not item_id then return 0 end
	amount = amount or 1
	local unit_amount = 0	
	self:ForEachItemInSlot("Inventory", "InventoryStack", 
		function(curitm, slot_name, item_left, item_top)
		   if curitm and item_id and curitm.class == item_id and curitm.Amount < curitm.MaxStacks then
				local to_add = Min(curitm.MaxStacks - curitm.Amount, amount)
				curitm.Amount =curitm.Amount + to_add
				Msg("InventoryAddItem", self, curitm, to_add)
				amount = amount - to_add			
				unit_amount = unit_amount + to_add
				if amount <= 0 then
					if callback then
						callback(self, curitm, unit_amount)
					end
					return "break"
				end
			end
		end)
	
	
	local itm
	while amount > 0 do			 
		local item = PlaceInventoryItem(item_id) 
		local is_stack = IsKindOf(item, "InventoryStack")
		
		if self:AddItem("Inventory", item) then 
			local to_add = 1
			if is_stack then
				to_add = Min(item.MaxStacks, amount) 
				item.Amount = to_add 
			end	
			unit_amount = unit_amount + to_add
			amount = amount - to_add
			unit_amount = unit_amount + to_add
			Msg("InventoryAddItem", self, item, to_add)
			itm =  item
		else
			DoneObject(item)
			break
		end				
	end		
	if callback and itm and unit_amount>0 then
		callback(self, itm, unit_amount)
	end
	ObjModified(self)

	return amount
end

-- Drop a container with a new item created from item_id.
---
--- Drops a container with a new item created from `item_id`.
---
--- @param item_id string The ID of the item to create and drop.
--- @param amount number The amount of the item to drop.
--- @param callback function An optional callback function that is called after the item is added to the container.
---
function Unit:DropItemContainer(item_id, amount, callback)
	if amount <= 0 then return end
	local item = PlaceInventoryItem(item_id)
	local is_stack = IsKindOf(item, "InventoryStack")
	if is_stack then
		item.Amount = amount
	end

	local container = GetDropContainer(self, false,item )
	if container then
		local pos, res = container:AddItem("Inventory", item)
		if pos and callback then
			callback(self, item, amount)
		end
	end
end

-- Add already generated items (from loot table) into a container and drop it. Stack them if possible.
---
--- Drops items in a container.
---
--- @param items table A table of items to drop in the container.
--- @param callback function An optional callback function that is called after each item is added to the container.
---
function Unit:DropItemsInContainer(items, callback)
	local container = GetDropContainer(self)
	if not container then return end
	for i = #items, 1, -1 do
		local item = items[i]
		if not container:CanAddItem("Inventory", item) then
			container = GetDropContainer(self, false, item)
		end
		local pos, reason = container:AddItem("Inventory", item)
		if pos then
			if callback then
				callback(self, item, IsKindOf("InventoryStack") and item.Amount or 1)
			end
			table.remove(items, i)
		end
	end	
end

---
--- Sets a highlight reason for the unit and updates the highlight marking.
---
--- @param reason string The reason to set for highlighting the unit.
--- @param enable boolean Whether to enable or disable the highlight reason.
---
function Unit:SetHighlightReason(reason, enable)
	self.highlight_reasons = self.highlight_reasons or {}
	self.highlight_reasons[reason] = enable
	
	self:UpdateHighlightMarking()

	if self.session_id then
		ObjModified(self.session_id .. "_combat_badge")
	end
	if reason == "deploy_predict" and self.ui_badge then
		self.ui_badge:SetVisible(not enable, "deploy_predict")
	end
end

---
--- Updates the highlight marking for the unit based on various reasons.
---
--- @param self Unit The unit object.
---
function Unit:UpdateHighlightMarking() 
	if WaitRecalcVisibility then return end

	local marking = false

	-- if the unit was set invisible by visibility logic we dont want to mark it, as it would show it
	if not self.visible or IsSetpiecePlaying() or CheatEnabled("IWUIHidden") then
		marking = -1
	end
	
	-- during combat, only show marking of playing
	if not marking then
		local pov_team = GetPoVTeam()
		local enemyTurn = g_Combat and g_Teams[g_CurrentTeam] ~= pov_team
		local playing = IsMerc(self) or (g_AIExecutionController and table.find(g_AIExecutionController.currently_playing, self)) -- if merc skip  this check so we show hard to see mercs
		if enemyTurn and not playing then
			marking = -1
		end
	end
	
	if not marking then
		local reasons = self.highlight_reasons
		if reasons["dark voxel"] then
			marking = 3
		elseif reasons["area target"] then
			marking = 3
		elseif reasons["melee"] then
			marking = 3
		elseif reasons["melee-target"] then
			marking = 3
		elseif reasons["bandage-target"] then
			marking = 0
		elseif reasons["concealed"] then
			if HasThermalVision(Selection) then
				marking = 10
			else
				marking = 9
			end
		elseif reasons["obscured"] then
			marking = 7
		elseif reasons["visibility"] then
			local pov_team = GetPoVTeam()
			if pov_team:IsEnemySide(self.team) then
				local enemyTurn = g_Combat and g_Teams[g_CurrentTeam] ~= pov_team
				local playing = g_AIExecutionController and table.find(g_AIExecutionController.currently_playing, self)
				
				local seen = enemyTurn or playing
				if not seen then
					for _, unit in ipairs(Selection) do
						if HasVisibilityTo(unit, self) then
							seen = true
							break
						end
					end
				end
				marking = seen and 3 or 1
			elseif reasons["faded"] or g_Combat and not g_Combat:ShouldEndCombat() then -- ally and neutral only get marking in conflict unless they're walking in the air
				if pov_team:IsAllySide(self.team) then
					marking = 0
				else -- neutral
					marking = 2
				end
			end
		elseif reasons["deploy_predict"] then
			marking = 5
		elseif reasons["darkness"] then
			marking = 8
		elseif reasons["can_be_interacted"] then
			marking = 11
		end
	end

	marking = marking or -1
	self:SetObjectMarking(marking)
	if marking < 0 then
		self:ClearHierarchyGameFlags(const.gofObjectMarking)
	else
		self:SetHierarchyGameFlags(const.gofObjectMarking)
	end
end

const.utWellRested = -1
const.utNormal = 0
const.utTired = 1
const.utExhausted = 2
const.utUnconscious = 3

UnitTirednessEffect = {
	[const.utWellRested] = "WellRested",
	[const.utNormal] = "Default",
	[const.utTired] = "Tired",
	[const.utExhausted] = "Exhausted",
	[const.utUnconscious] = "Unconscious",
}

---
--- Formats the tiredness value to a display name.
---
--- @param context_obj any The context object.
--- @param value integer The tiredness value.
--- @return string The display name for the tiredness value.
---
function TFormat.tiredness(context_obj, value)
	local effect = UnitTirednessEffect[value]
	if effect and g_Classes[effect] then
		return g_Classes[effect].DisplayName
	elseif effect == "Default" then
		return T(714191851131, "Normal")
	end
	return ""
end

---
--- Returns a table of combo items representing the different unit tiredness effects.
---
--- @return table The combo items for unit tiredness effects.
---
function UnitTirednessComboItems()
	local items = {}
	for k, v in sorted_pairs(UnitTirednessEffect) do
		items[#items + 1] = { name = v, value = k }
	end
	return items
end

function OnMsg.UnitRelationsUpdated()
	for _, unit in ipairs(g_Units) do
		unit:UpdateMeleeTrainingVisual()
	end
end

-- sort units map by pos
---
--- Sorts a map of units by their session ID.
---
--- @param units_map table A map of units, where the keys are the units and the values are their associated data.
--- @return table A sorted array of tables, where each table contains the session ID, unit, and associated data.
---
function SortUnitsMap(units_map) 
	if not units_map or not next(units_map) then return units_map end
	local first_key = next(units_map)
	if next(units_map, first_key) == nil then 
		return {{id = first_key.session_id, unit = first_key, data = units_map[first_key]}}
	end

	local positions = {}
	for unit, data in pairs(units_map) do
		if IsValid(unit) then
			positions[#positions + 1] = {id = unit.session_id, unit = unit, data = data}		
		end
	end
	table.sortby(positions, "id")
	return positions
end

---
--- Returns a table of body parts that can be targeted for the given attack weapon.
---
--- @param attack_weapon table The attack weapon to get the target body parts for.
--- @return table A table of body part names that can be targeted.
---
function Unit:GetBodyParts(attack_weapon)
	local list = Presets.TargetBodyPart.Default
	if self.species == "Human" then
		local head = list.Head
		if IsKindOf(attack_weapon, "MeleeWeapon") then
			head = list.Neck
		end
		return { head, list.Arms, list.Torso, list.Groin, list.Legs } 
	end
	return { list.Head, list.Torso, list.Legs } 
end

---
--- Displays a notification when a unit experiences a mishap during an attack.
---
--- @param action table The action that caused the mishap.
---
function Unit:ShowMishapNotification(action)
	if self.team.player_team then
		local text = action:GetAttackWeapons(self).DisplayName
		HideTacticalNotification("playerAttack")
		ShowTacticalNotification("playerAttack", false, T{989807512852, "<attack> Mishap", attack = text})
	else
		local text = GetTacticalNotificationText("enemyAttack") or action:GetAttackWeapons(self).DisplayName
		HideTacticalNotification("enemyAttack")
		ShowTacticalNotification("enemyAttack", false, T{989807512852, "<attack> Mishap", attack = text})
	end
	CreateFloatingText(self, T(371973388445, "Mishap!"), "FloatingTextMiss")
end

---
--- Determines the valid stance for a unit based on the target stance and the unit's position.
---
--- @param target_stance string The target stance to check for validity.
--- @param pos table The position to check the stance validity for.
--- @return string The valid stance, which may be different from the target stance.
---
function Unit:GetValidStance(target_stance, pos)
	if target_stance == "Prone" then
		local side = self.team and self.team.side or "player1"
		local pfclass = CalcPFClass(side, "Prone", self.body_type)
		if not GetPassSlab(pos or self, pfclass) then
			return "Crouch"
		end
	end
	return target_stance
end

---
--- Determines if a unit can switch to the specified stance.
---
--- @param toDoStance string The stance to switch to.
--- @param args table Optional arguments, including a `goto_pos` field to check the validity of the stance at a specific position.
--- @return boolean Whether the stance switch is allowed.
--- @return string|nil The reason why the stance switch is not allowed, if any.
---
function Unit:CanSwitchStance(toDoStance, args)
	--no stance switch available for machineguns 
	if self:IsStanceChangeLocked() then
		return false
	end
	--no stance switch for prone - addition checks
	local action
	if toDoStance == "Standing" then
		action = "StanceStanding"
	elseif toDoStance == "Crouch" then
		action = "StanceCrouch"
	elseif toDoStance == "Prone" then
		local unitOrGotoPos = args and args.goto_pos or self
		local in_water = terrain.IsWater(unitOrGotoPos) -- disable when all the units are in water
		if in_water then 
			return false, AttackDisableReasons.Water 
		end		
		local valid_stance = self:GetValidStance("Prone", unitOrGotoPos)
		if valid_stance ~= "Prone" then
			return false, AttackDisableReasons.Stairs
		end
		action = "StanceProne"
	end
	--no stance switch avaible for lack of ap
	local cost = CombatActions[action]:GetAPCost(self, args)
	if cost < 0 then 
		return false, "hidden" 
	end
	if not self:UIHasAP(cost, action) then 
		return false, GetUnitNoApReason(self)
	end
	return true
end

---
--- Determines if a unit's stance is locked, preventing stance changes.
---
--- Stance changes are locked if the unit is using a machine gun and is in overwatch mode, or if the unit is currently bandaging another unit.
---
--- @return boolean Whether the unit's stance is locked.
---
function Unit:IsStanceChangeLocked()
	if IsKindOf(self:GetActiveWeapons(), "MachineGun") and (self.behavior == "OverwatchAction" or self.combat_behavior == "OverwatchAction")then 
		return true
	end
	if self:GetBandageTarget() then -- bandaging other unit
		return true
	end
	
	return false
end

MapVar("g_AttackRevealQueue", false)

---
--- Reveals units to the attacker based on the results of an attack.
---
--- If the attack kills a unit, the attacker is revealed to the killed unit. If the attack hits a unit, the attacker is revealed to that unit.
---
--- If there is no active combat, the units to be revealed are added to a queue to be revealed when combat starts.
---
--- @param action The action that triggered the attack.
--- @param attack_args The arguments passed to the attack.
--- @param results The results of the attack.
---
function Unit:AttackReveal(action, attack_args, results)
	local attacker = self
	local target = attack_args.target
	local killed = results.killed_units or empty_table
	if not g_Combat then
		g_AttackRevealQueue = {self}
	end
	if IsKindOf(target, "Unit") and not target:IsDead() and not table.find(killed, target) then
		if g_Combat then
			self:RevealTo(target)
		else
			g_AttackRevealQueue[#g_AttackRevealQueue + 1] = target
		end
	end
	for _, hit in ipairs(results) do
		local unit = IsKindOf(hit.obj, "Unit") and not hit.obj:IsIncapacitated() and hit.obj
		if unit and unit.team ~= self.team and not unit:IsDead() and not table.find(killed, unit) then
			if g_Combat then
				self:RevealTo(unit)
			else
				g_AttackRevealQueue[#g_AttackRevealQueue + 1] = unit
			end
		end
	end
end

---
--- Called when the unit has sighted an enemy.
---
--- If the unit has the "AlwaysReady" perk, is not hidden, is in combat, is not on the current team, has not prepared an attack, and is not threatened by overwatch, then the unit will try to activate the "AlwaysReady" behavior.
---
--- @param other The enemy unit that was sighted.
---
function Unit:OnEnemySighted(other)
	--printf("%s has seen %s", unit.unitdatadef_id, other.unitdatadef_id)
	if HasPerk(self, "AlwaysReady") and 
		not self:HasStatusEffect("Hidden") and
		g_Combat and not g_Combat:ShouldEndCombat() and
		g_Teams[g_CurrentTeam] ~= self.team and
		not self:HasPreparedAttack() and
		not self:IsThreatened(nil, "overwatch")
	then	
		self:TryActivateAlwaysReady(other)
	end
end

--- Calculates the movement AP cost for the unit to move to the specified destination.
---
--- If the unit is not in combat or the game is not starting combat, the cost is 0.
---
--- Otherwise, the cost is calculated based on the combat path for the unit. If a valid path is found, the AP cost of that path is returned, minus any free move AP the unit has. If no valid path is found, -1 is returned.
---
--- @param dest The destination to calculate the move cost for.
--- @return The movement AP cost to reach the destination, or -1 if no valid path is found.
function Unit:GetMoveAPCost(dest)
	if not dest or not (g_Combat or g_StartingCombat) then return 0 end
	
	local move_cost = 0
	local path = GetCombatPath(self)
	move_cost = path and path:GetAP(dest)
	if not move_cost then return -1 end
	
	return Max(0, move_cost - self.free_move_ap)
end

---
--- Checks if the unit has night vision capabilities.
---
--- If the unit has the "NightOps" perk, it is considered to have night vision.
--- Otherwise, the unit is checked for a "NightVisionGoggles" item in the head slot, and if the item is in working condition (Condition > 0), the unit is considered to have night vision.
---
--- @return boolean true if the unit has night vision, false otherwise
function Unit:HasNightVision()
	if HasPerk(self, "NightOps") then
		return true
	end
	local helm = self:GetItemInSlot("Head")
	return IsKindOf(helm, "NightVisionGoggles") and helm.Condition > 0
end

---
--- Synchronizes the auto-face state of a unit.
---
--- This function is called when the auto-face state of a unit needs to be synchronized across the network.
---
--- If the unit's auto-face state is being changed, this function will update the unit's auto-face property and, if certain conditions are met, start a reorientation thread to have the unit face the correct direction.
---
--- @param obj The unit object whose auto-face state is being synchronized.
--- @param auto_face The new auto-face state for the unit.
---
function NetSyncEvents.SetAutoFace(obj, auto_face)
	if not obj or obj.auto_face == auto_face then
		return
	end
	obj.auto_face = auto_face
	-- reorientation
	if auto_face
		and obj.command == "Idle"
		and obj.stance ~= "Prone"
		and not obj.interrupt_callback
		and not IsValidThread(obj.reorientation_thread)
	then
		obj.reorientation_thread = CreateGameTimeThread(function(obj)
			Sleep(obj:Random(500))
			if obj.auto_face
				and obj.command == "Idle"
				and (obj.stance == "Standing" or obj.stance == "Crouch")
				and not obj.interrupt_callback
			then
				obj:InterruptCommand("Idle")
			end
			obj.reorientation_thread = false
		end, obj)
	end
end

function OnMsg.SelectedObjChange()
	local obj = SelectedObj
	if not obj then
		return
	end
	if not obj.auto_face then
		return
	end
	if not (g_Combat and g_Teams and g_Teams[g_CurrentTeam] == obj.team) then
		return
	end
	if not obj:IsLocalPlayerControlled() then
		return
	end
	NetSyncEvent("SetAutoFace", obj, false)
end

function OnMsg.SelectionRemoved(obj)
	if not (g_Combat and g_Teams and g_Teams[g_CurrentTeam] == obj.team) then
		return
	end
	if not obj:IsLocalPlayerControlled() then
		return
	end
	if obj.stance == "Prone" then
		return
	end
	NetSyncEvent("SetAutoFace", obj, true)
end

function OnMsg:TurnEnded(team)
	for i, unit in ipairs(g_Teams[g_CurrentTeam].units) do
		unit.auto_face = true
	end
end

-- TargetDummy
DefineClass.TargetDummy = {
	__parents = { "Movable", "SyncObject", "AppearanceObject" },
	flags = {
		efUnit = true, efVisible = false, efSelectable = false, efWalkable = false, efCollision = false,
		efPathExecObstacle = false, efResting = false,
		efApplyToGrids = false, efShadow = false, efSunShadow = false, gofOnRoof = false,
	},
	__toluacode = empty_func,
	obj = false,
	stance = false,
	locked = false,
}
DefineClass.TargetDummyLargeAnimal = {
	__parents = { "TargetDummy" },
}

--- Initializes a TargetDummy object.
---
--- This function is called when a TargetDummy object is created. It applies the appearance of the associated object, sets the ground orientation offsets, destination lock radius, collision radius, and animation speed.
---
--- @param self TargetDummy The TargetDummy object being initialized.
function TargetDummy:Init()
	local obj = self.obj
	if obj then
		self:ApplyAppearance(obj.Appearance)
		pf.SetGroundOrientOffsets(self, table.unpack(obj:GetGroundOrientOffsets()))
	end
	self:SetDestlockRadius(obj and obj:GetDestlockRadius() or 0)
	self:SetCollisionRadius(0)
	self:SetAnimSpeed(1, 0)
	Msg("NewTargetDummy", self) -- for debug visualization
end

-- disable setting efPathExecObstacle
TargetDummy.InitPathfinder = empty_func
TargetDummy.EnterPathfinder = empty_func
TargetDummy.EnterPathfinder = empty_func

--- Removes all TargetDummy objects from the given sector data.
---
--- This function iterates through the spawn data in the sector data and removes any TargetDummy objects found.
---
--- @param sector_data table The sector data to clear TargetDummy objects from.
function SavegameSectorDataFixups.ClearTargetDummies(sector_data)
	local spawn_data = sector_data.spawn
	while true do
		local idx = table.find(spawn_data, "TargetDummy")
		if not idx then
			break
		end
		table.remove(spawn_data, idx + 1) -- handle
		table.remove(spawn_data, idx)     -- TargetDummy
	end
end

--- Checks if the given list of units contains the last standing unit in the team.
---
--- This function iterates through the list of units and keeps track of the last standing unit. If another unit is found that is not dead, it means there are multiple units still standing and the function returns false. Otherwise, it returns the last standing unit.
---
--- @param units table A list of units to check.
--- @return boolean|Unit The last standing unit, or false if there are multiple units still standing.
function IsLastUnitInTeam(units)
	local lastStanding = false
	for _, unit in ipairs(units) do
		if not unit:IsDead() and not lastStanding then
			lastStanding = unit
		elseif not unit:IsDead() and lastStanding then
			return false
		end
	end
	return lastStanding
end

---
--- Fixes up the experience values in the unit data of a savegame.
---
--- This function iterates through the unit data in the savegame and ensures that each unit has a valid experience value. If a unit is missing an experience value, it sets the experience to the minimum value for the unit's starting level.
---
--- Additionally, this function removes any "ExperienceBonus" modifiers from the unit data, as these are no longer needed.
---
--- @param data table The savegame data to fix up.
--- @param metadata table The metadata associated with the savegame data.
--- @param lua_ver string The version of Lua used in the savegame.
function SavegameSessionDataFixups.ExpFixup(data, metadata, lua_ver)
	local ud = data.gvars.gv_UnitData
	for _, data in pairs(ud) do
		if not data.Experience then
			local minXP = GetXPTable(data.StartingLevel)
			data.Experience = minXP
		end
		data:RemoveModifier("ExperienceBonus", "Experience")
	end
end

UndefineClass('AdditionalGroup')
DefineClass.AdditionalGroup = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Weight", name = "Weight", editor = "number", min = 0, max = 100, default = 100, help = "Integer numbers.(0:never picked / 100:always picked)"},
		{ id = "Exclusive", name = "Mutually Exclusive", editor = "bool", default = false, 
		help = "If marked as exclusive, only one will be chosen from all marked as exclusive. NB: If only one is marked as exclusive and weight > 0, it will be ALWAYS picked." },
		{ id = "Name", name = "Name", editor = "text", default = "", help = "The name of the group." },
	},
}

--- Provides a string representation of the AdditionalGroup object for the editor view.
---
--- This function returns a string that displays the name of the AdditionalGroup, if it has been set. If the name is empty, it returns a generic string "AdditionalGroup".
---
--- @return string The string representation of the AdditionalGroup for the editor view.
function AdditionalGroup:EditorView()
	return string.format("AdditionalGroup %s", self.Name and self.Name ~= "" and ("- " .. self.Name) or "")
end

---
--- Checks if the unit is concealed from the given observer.
---
--- This function returns true if the unit is concealed from the given observer due to the current game state's fog of war, and the unit is not indoors and is not closer to the observer than the specified fog of war distance.
---
--- @param observer Unit The unit observing the current unit.
--- @return boolean True if the unit is concealed from the observer, false otherwise.
function Unit:IsConcealedFrom(observer)
	return GameState.Fog and not self.indoors and not IsCloser(self, observer, const.EnvEffects.FogUnkownFoeDistance)
end

---
--- Checks if the unit is obscured from the given observer due to a dust storm.
---
--- This function returns true if the unit is obscured from the given observer due to the current game state's dust storm, and the unit is not indoors and is not closer to the observer than the specified dust storm obscure distance.
---
--- @param observer Unit The unit observing the current unit.
--- @return boolean True if the unit is obscured from the observer, false otherwise.
function Unit:IsObscuredFrom(observer)
	return GameState.DustStorm and not self.indoors and not IsCloser(self, observer, const.EnvEffects.DustStormUnkownFoeDistance)
end

---
--- Checks if any of the given units have a weapon that ignores concealment and obscurement.
---
--- This function iterates through the given units and their active weapons, and returns true if any of the weapons have the "IgnoreConcealAndObscure" component.
---
--- @param units table A table of units to check for thermal vision.
--- @return boolean True if any of the units have a weapon that ignores concealment and obscurement, false otherwise.
function HasThermalVision(units)
	for _, unit in ipairs(units) do
		local _, _, weapons = unit:GetActiveWeapons()
		for _, weapon in ipairs(weapons) do
			if weapon:HasComponent("IgnoreConcealAndObscure") then
				return true
			end
		end
	end
end

---
--- Checks if the unit is obscured from the given observer due to a dust storm.
---
--- This function returns true if the unit is obscured from the given observer due to the current game state's dust storm, and the unit is not indoors and is not closer to the observer than the specified dust storm obscure distance.
---
--- @param observer Unit The unit observing the current unit.
--- @return boolean True if the unit is obscured from the observer, false otherwise.
function Unit:UIObscured()
	local side = self.CurrentSide or (self.team and self.team.side)
	if not side or side == "player1" or side == "player2" or side == "ally" then
		return false
	end
	if not GameState.DustStorm then
		return false
	end

	local units = Selection or empty_table
	if #units == 0 then
		local team = GetPoVTeam()
		units = team and team.units
	end
	local obscured = true
	for _, unit in ipairs(units) do
		obscured = obscured and CheckSightCondition(unit, self, const.usObscured)
	end
	return obscured
end

---
--- Checks if the unit is concealed from the given observer due to the current game state's fog.
---
--- This function returns true if the unit is concealed from the given observer due to the current game state's fog, and the observer does not have thermal vision that can ignore concealment.
---
--- @param skip_check boolean (optional) If true, skips the thermal vision check.
--- @return boolean True if the unit is concealed from the observer, false otherwise.
function Unit:UIConcealed(skip_check)
	local side = self.CurrentSide or (self.team and self.team.side)
	if not side or side == "player1" or side == "player2" or side == "ally" then
		return false
	end
	if not GameState.Fog then
		return false
	end
	if not skip_check and HasThermalVision(Selection) then 
		return false 
	end
	
	local concealed = true
	local units = Selection or empty_table
	if #units == 0 then
		local team = GetPoVTeam()
		units = team and team.units
	end
	for _, unit in ipairs(units) do
		concealed = concealed and CheckSightCondition(unit, self, const.usConcealed)
	end
	return concealed
end

---
--- Returns the display name of the unit, or "???" if the unit is obscured or concealed.
---
--- @param self Unit The unit object.
--- @return string The display name of the unit, or "???" if the unit is obscured or concealed.
function Unit:GetDisplayName()
	if self:UIObscured() or self:UIConcealed() then
		return T(393866533740, "???")
	end
	
	return UnitProperties.GetDisplayName(self)
end

---
--- Checks if the unit has any visible effects.
---
--- This function returns false if the unit's team is neutral, otherwise it returns the result of checking if the unit has any visible effects using the `StatusEffectObject.HasVisibleEffects` function.
---
--- @param self Unit The unit object.
--- @return boolean True if the unit has visible effects, false otherwise.
function Unit:HasVisibleEffects()
	if self.team.neutral then return false end
	return StatusEffectObject.HasVisibleEffects(self)
end

---
--- Advances the command of a unit, and if the command is "ExitMap" and the unit does not have the "DontFastForwardExit" status effect, the unit is despawned.
---
--- @param self Unit The unit object.
function Unit:FastForwardCommand()
	if self.command == "ExitMap" and not self:HasStatusEffect("DontFastForwardExit") then
		self:Despawn()
	end
end

---
--- Sets the command of the unit if the unit is not dead.
---
--- If the unit is dead or the command is "Die", this function does nothing.
--- Otherwise, it calls the `SetCommand` function with the provided arguments.
---
--- @param self Unit The unit object.
--- @param ... any Arguments to pass to the `SetCommand` function.
function Unit:SetCommandIfNotDead(...)
	if self:IsDead() or self.command == "Die" then return end
	self:SetCommand(...)
end

DefineClass.World_HangingSkeleton_Base = {
	__parents = { "CombatObject", "DecorStateFXAutoAttachObject" },
	flags = { efApplyToGrids = false },
}
