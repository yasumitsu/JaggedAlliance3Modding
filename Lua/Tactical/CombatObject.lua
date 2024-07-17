DefineClass.ZuluFloatingText = {
	__parents = { "XFloatingText" },

	expire_time = 3000,
	fade_start = 0,
	MaxWidth = 450,
	HAlign = "left",
	TextHAlign = "center",

	TextStyle = "FloatingTextDefault",
	interpolate_opacity = true,
}

DefineClass.DamageFloatingText = {
	__parents = { "ZuluFloatingText" },
	TextStyle = "FloatingTextDamage",
	always_show_on_distance = true,
	WordWrap = false
}

---
--- Creates a floating damage text effect for a target.
---
--- @param target table|Point The target object or position to display the floating text.
--- @param text string The text to display in the floating text.
--- @param style string The text style to use for the floating text.
--- @return table The created floating text object.
---
function CreateDamageFloatingText(target, text, style)
	if not config.FloatingTextEnabled or CheatEnabled("CombatUIHidden") then return end
	local valid_target
	if IsPoint(target) then
		valid_target = target:IsValid()
	elseif IsValid(target) then
		if IsKindOf(target, "Unit") and not target.visible then
			return
		end
		valid_target = target:IsValidPos()
	end
	--= IsPoint(target) and target:IsValid() or IsValid(target) and target:IsValidPos()
	assert(valid_target)
	if not valid_target then
		return
	end
	local ftext = XTemplateSpawn("DamageFloatingText", EnsureDialog("FloatingTextDialog"), false)
	return CreateCustomFloatingText(ftext, target, text, style, nil, "stagger_spawn")
end

DefineClass.DepositionCombatObject = {
	__parents = { "Deposition", "CombatObject" },
	flags = { efSelectable = true },
}

DefineClass.CombatObject = {
	__parents = { "GameDynamicDataObject", "CommandObject" },
	flags = { efSelectable = true },
	MaxHitPoints = 0,
	HitPoints = -1,
	TempHitPoints = 0,
	armor_class = 1,
	invulnerable = false,
	impenetrable = false,
	lastFloatingDamageText = false,
}

---
--- Checks if the CombatObject is invulnerable.
---
--- @return boolean True if the CombatObject is invulnerable, false otherwise.
---
function CombatObject:IsInvulnerable()
	if IsObjVulnerableDueToLDMark(self) then
		return false
	end

	return self.invulnerable or IsObjInvulnerableDueToLDMark(self) or TemporarilyInvulnerableObjs[self]
end

---
--- Gets the dynamic data for the CombatObject.
---
--- @param data table The table to store the dynamic data in.
---
function CombatObject:GetDynamicData(data)
	if self.HitPoints ~= self.MaxHitPoints then
		data.HitPoints = self.HitPoints
	end
	data.TempHitPoints = (self.TempHitPoints ~= 0) and self.TempHitPoints or nil
end

---
--- Sets the dynamic data for the CombatObject.
---
--- @param data table The table containing the dynamic data to set.
---
function CombatObject:SetDynamicData(data)
	self.HitPoints = data.HitPoints or self.MaxHitPoints
	self.TempHitPoints = data.TempHitPoints or 0
end

---
--- Initializes the CombatObject from its material type.
---
--- This function is called during the GameInit phase to set up the initial state of the CombatObject based on its material type.
---
--- @function CombatObject:GameInit
--- @return nil
---
function CombatObject:GameInit()
	self:InitFromMaterial()
end

---
--- Initializes the CombatObject from its material type.
---
--- This function is called during the GameInit phase to set up the initial state of the CombatObject based on its material type.
---
--- @function CombatObject:InitFromMaterial
--- @return nil
---
function CombatObject:InitFromMaterial()
	local material_type = self:GetMaterialType()
	if material_type then
		local preset = Presets.ObjMaterial.Default[material_type]
		if preset then
			self:InitFromMaterialPreset(preset)
		else
			StoreErrorSource(self, string.format("[WARNING] Object of class %s set to invalid combat material type '%s'", self.class, material_type))
		end
	end
end

---
--- Returns the combat material preset for the CombatObject.
---
--- This function is used to retrieve the combat material preset for the CombatObject, which is determined by the object's material type. The preset contains various properties such as maximum hit points, armor class, and invulnerability.
---
--- @return table|nil The combat material preset for the CombatObject, or nil if the material type is invalid.
---
function CombatObject:GetCombatMaterial()
	--for most objs this is the same as GetMaterialPreset
	--due to naming collisions, for slabs this is different
	local material_type = self:GetMaterialType()
	if material_type then
		return Presets.ObjMaterial.Default[material_type]
	end
end

---
--- Sets the material type of the CombatObject.
---
--- This function is used to update the material type of the CombatObject and initialize it with the corresponding material preset. If the provided material type is invalid, a warning message is printed and the function returns without making any changes.
---
--- @param id string The new material type to set for the CombatObject.
--- @return nil
---
function CombatObject:SetMaterialType(id)
	local material_type = self:GetMaterialType()
	if id == material_type then
		return
	end
	local preset = Presets.ObjMaterial.Default[id]
	if not preset then
		print("once", string.format("[WARNING] Object of class %s set to invalid combat material type '%s'", self.class, id))
		return
	end
	self.material_type = id
	self:InitFromMaterialPreset(preset)
end

function OnMsg.NewMapLoaded()
	MapForEach("map", "CObject", nil, nil, nil, nil, const.cofComponentCollider, function(obj, materials)
		if obj:IsKindOf("CombatObject") then
			return
		end
		local preset = materials[obj.material_type]
		if not preset or preset.impenetrable then
			return -- by default is impenetrable
		end
		collision.SetPenetratingDefense(obj, 1) -- -1 is impenetrable
	end, Presets.ObjMaterial.Default)
end

---
--- Initializes the CombatObject from the provided material preset.
---
--- This function is used to set the initial state of the CombatObject based on the provided material preset. It sets the maximum hit points, current hit points, armor class, and invulnerability status of the object.
---
--- @param preset table The material preset to initialize the CombatObject with.
--- @return nil
---
function CombatObject:InitFromMaterialPreset(preset)
	self.MaxHitPoints = preset.max_hp
	self.HitPoints = self.MaxHitPoints
	self.armor_class = preset.armor_class
	local forced_invulnerable = self:HasMember("forceInvulnerableBecauseOfGameRules") and self.forceInvulnerableBecauseOfGameRules
	self.invulnerable = self.invulnerable or forced_invulnerable or preset.invulnerable

	local defense = not self.impenetrable and preset and not preset.impenetrable and self.armor_class or -1
	collision.SetPenetratingDefense(self, defense)
end

---
--- Checks if the CombatObject is dead.
---
--- @return boolean True if the CombatObject's hit points are less than or equal to 0, false otherwise.
---
function CombatObject:IsDead()
	return self.HitPoints <= 0
end

---
--- Checks if the CombatObject is an ally of the player.
---
--- @return boolean False, as CombatObject is not an ally of the player.
---
function CombatObject:IsPlayerAlly()
	return false
end

---
--- Called when the Slab object dies.
---
--- This function overrides the `CombatObject:OnDie()` function to handle the death of a Slab object. It asserts that the Slab object is visible before calling the parent `CombatObject:OnDie()` function.
---
--- @param self Slab The Slab object that is dying.
--- @return nil
---
function Slab:OnDie()
	assert(self.isVisible)
	CombatObject.OnDie(self)
end

---
--- Called when the CombatObject dies.
---
--- This function sets the command of the CombatObject to "Die" when it dies.
---
--- @param self CombatObject The CombatObject that is dying.
--- @return nil
---
function CombatObject:OnDie()
	self:SetCommand("Die")
end

-- Temporary HitPoints are removed at the end of combat
function OnMsg.CombatEnd()
	for i, unit in ipairs(g_Units) do
		unit.TempHitPoints = 0	
		ObjModified(unit)
	end
end

---
--- Applies temporary hit points to the CombatObject.
---
--- @param self CombatObject The CombatObject to apply the temporary hit points to.
--- @param value number The amount of temporary hit points to apply.
--- @return nil
---
function CombatObject:ApplyTempHitPoints(value)
	self.TempHitPoints = Clamp(self.TempHitPoints + value, 0, const.Combat.MaxGrit)
	ObjModified(self)
end

---
--- Returns the total hit points of the CombatObject, including any temporary hit points.
---
--- @param self CombatObject The CombatObject to get the total hit points for.
--- @return number The total hit points of the CombatObject.
---
function CombatObject:GetTotalHitPoints()
	if self.TempHitPoints and self.TempHitPoints > 0 then
		return self.HitPoints + self.TempHitPoints
	else
		return self.HitPoints
	end
end

---
--- Precalculates the damage taken by a CombatObject.
---
--- This function calculates the damage taken by a CombatObject, taking into account any temporary hit points the CombatObject has. It returns the new hit points, temporary hit points, and the actual damage dealt.
---
--- @param self CombatObject The CombatObject to calculate the damage for.
--- @param dmg number The amount of damage to be dealt.
--- @param hp number (optional) The current hit points of the CombatObject. If not provided, the CombatObject's current hit points will be used.
--- @param temp_hp number (optional) The current temporary hit points of the CombatObject. If not provided, the CombatObject's current temporary hit points will be used.
--- @return number, number, number The new hit points, temporary hit points, and the actual damage dealt.
---
function CombatObject:PrecalcDamageTaken(dmg, hp, temp_hp)
	hp = hp or self.HitPoints
	temp_hp = temp_hp or self.TempHitPoints
	local damage_dealt = 0
	
	if not self:IsInvulnerable() then
		if CheatEnabled("WeakDamage") then
			dmg = dmg / 100
		elseif CheatEnabled("StrongDamage") then
			dmg = dmg * 100
		end
		
		damage_dealt = Max(0, dmg - self.TempHitPoints)
		temp_hp = Max(0, temp_hp - dmg)
		hp = Max(0, hp - damage_dealt)		
	end
	return hp, temp_hp, damage_dealt
end

---
--- Applies direct damage to the CombatObject, taking into account any temporary hit points.
---
--- This function calculates the damage taken by a CombatObject, taking into account any temporary hit points the CombatObject has. It updates the CombatObject's hit points and temporary hit points accordingly, and calls the `OnHPLoss` function if the CombatObject loses hit points. If the CombatObject's hit points reach 0, the `OnDie` function is called.
---
--- @param self CombatObject The CombatObject to apply the damage to.
--- @param dmg number The amount of damage to be dealt.
--- @param floating boolean (optional) Whether to create a floating damage text.
--- @param log_type string (optional) The type of log entry to create.
--- @param log_msg string (optional) The message to log.
--- @param attacker CombatObject (optional) The attacker that dealt the damage.
--- @param hit_descr table (optional) A table containing information about the hit.
---
function CombatObject:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	if self:IsInvulnerable() then
		return
	end
	if CheatEnabled("WeakDamage") then
		dmg = dmg / 100
	elseif CheatEnabled("StrongDamage") then
		dmg = dmg * 100
	end
	
	hit_descr = hit_descr or {}
	hit_descr.prev_hit_points = self.HitPoints
	hit_descr.raw_damage = dmg

	
	local hp, thp, damage_taken = self:PrecalcDamageTaken(dmg)
	self.TempHitPoints = thp
	self.HitPoints = hp
	self:OnHPLoss(dmg, attacker)
	self:NetUpdateHash("TakeDirectDamage", dmg, hit_descr.prev_hit_points, self.HitPoints, self.TempHitPoints, damage_taken)

	--local dmg_left = Max(0, dmg - self.TempHitPoints)
	--self.TempHitPoints = Max(0, self.TempHitPoints - dmg)
	--self.HitPoints = Max(0, self.HitPoints - dmg_left)
	--self:OnHPLoss(dmg, dmg_left)

	--self:NetUpdateHash("TakeDirectDamage", dmg, hit_descr.prev_hit_points, self.HitPoints, self.TempHitPoints, dmg_left)
	if self.HitPoints == 0 then
		self:OnDie(attacker, hit_descr)
	end

	if log_type and log_msg then
		CombatLog(log_type, log_msg)
	end
	if floating and not hit_descr.setpiece then
		CreateDamageFloatingText(self, floating)
	end
end

---
--- This function takes damage and applies it to the CombatObject. It updates the CombatObject's hit points and temporary hit points, calls the `OnHPLoss` function if the CombatObject loses hit points, and calls the `OnDie` function if the CombatObject's hit points reach 0. It also logs the damage and sends messages about the damage being done and taken.
---
--- @param self CombatObject The CombatObject to apply the damage to.
--- @param dmg number The amount of damage to be dealt.
--- @param attacker CombatObject (optional) The attacker that dealt the damage.
--- @param hit_descr table (optional) A table containing information about the hit.
---
function CombatObject:TakeDamage(dmg, attacker, hit_descr)
	if not IsValid(self) or self:IsDead() or self:IsInvulnerable() then
		return
	end
	
	hit_descr = hit_descr or {}
	
	self:LogDamage(dmg, attacker, hit_descr)

	self:TakeDirectDamage(dmg, nil, nil, nil, attacker, hit_descr)
	Msg("DamageDone", attacker, self, dmg, hit_descr)
	if IsKindOf(attacker, "Unit") then
		attacker:CallReactions("OnDamageDone", self, dmg, hit_descr)
	end
	Msg("DamageTaken", attacker, self, dmg, hit_descr)
	if IsKindOf(self, "Unit") then
		self:CallReactions("OnDamageTaken", attacker, dmg, hit_descr)
	end
end

---
--- This function is called when the CombatObject loses hit points.
---
--- @param self CombatObject The CombatObject that is losing hit points.
--- @param dmg number The amount of damage that was dealt.
--- @param attacker CombatObject (optional) The attacker that dealt the damage.
---
function CombatObject:OnHPLoss(dmg, attacker)
end

---
--- This function displays floating text damage for a CombatObject. It handles accumulating and updating the damage text if the CombatObject is hit multiple times in quick succession. It creates a new floating text object with the appropriate text and styling based on the hit type (grazing, critical, etc.).
---
--- @param self CombatObject The CombatObject to display the floating text damage for.
--- @param damage number The amount of damage to display.
--- @param hit table A table containing information about the hit.
--- @param accumulate boolean Whether to attempt to accumulate the damage with the previous floating text.
---
function CombatObject:DisplayFloatingTextDamage(damage, hit, accumulate)
	if accumulate and not hit.grazing then
		local lastText = self.lastFloatingDamageText
		local marginOfTime = 700
		local oldTextNotFaded = lastText and (GetPreciseTicks() - lastText.timeNow) < marginOfTime
		if lastText and lastText.window_state == "open" and oldTextNotFaded then
			local accumulatedDamage = damage + lastText.Text.num
			lastText.Text.num = accumulatedDamage
			lastText:SetText(lastText.Text)
			lastText:UpdateDrawCache(lastText.draw_cache_text_width, lastText.draw_cache_text_height, true)
			return
		end
	end
	
	local txt
	if not hit.setpiece then
		if hit.grazing then
			if hit.grazing_reason == "fog" then
				txt = CreateDamageFloatingText(self, T{554948654101, "<num> Grazed (Fog)", num = damage}, "FloatingTextMiss")
			elseif hit.grazing_reason == "duststorm" then
				txt = CreateDamageFloatingText(self, T{395798135760, "<num> Grazed (Dust Storm)", num = damage}, "FloatingTextMiss")
			else
				txt = CreateDamageFloatingText(self, T{970945572773, "<num> Grazed", num = damage}, "FloatingTextMiss")
			end
		elseif hit.critical then
			txt = CreateDamageFloatingText(self, T{307116587677, "<num> CRIT!", num = damage}, "FloatingTextCrit")
		else
			txt = CreateDamageFloatingText(self, T{867764319678, "<num>", num = damage}, nil)
		end
	end
	if not hit.grazing then
		self.lastFloatingDamageText = txt
	end
end

-- log/report
---
--- Logs the damage dealt to a CombatObject, including details about the hit such as the body part hit, whether it was a critical hit, and any damage reduction.
---
--- @param dmg number The amount of damage dealt.
--- @param attacker CombatObject (optional) The attacker that dealt the damage.
--- @param hit table A table containing information about the hit, such as the body part hit, whether it was a critical hit, etc.
--- @param reductionInfo table A table containing information about any damage reduction, such as the amount of damage reduced and the status effect that caused the reduction.
---
function CombatObject:LogDamage(dmg, attacker, hit, reductionInfo)
	local logName = self:GetLogName()

	if IsKindOf(self, "Unit") then
		if hit.spot_group and not hit.explosion and not hit.aoe then
			local part = Presets.TargetBodyPart.Default[hit.spot_group].display_name
			if (hit.armor_prevented or 0) > 0 then
				if hit.grazing then
					CombatLog("debug", T{Untranslated("  Grazing hit. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				elseif hit.critical then
					if hit.stealth_crit then
						CombatLog("debug", T{Untranslated("  Stealth Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
					else
						CombatLog("debug", T{Untranslated("  Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
					end
				elseif hit.stray then
					CombatLog("debug", T{Untranslated("  Stray shot. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				else
					CombatLog("debug", T{Untranslated("  <em><target></em> was hit in the <bodypart> for <em><num> damage</em>, <num2> absorbed"), target = logName, num = dmg, num2 = hit.armor_prevented, bodypart = part})
				end
			else
				if hit.grazing then
					CombatLog("debug", T{Untranslated("  Grazing hit. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				elseif hit.critical then
					if hit.stealth_crit then
						CombatLog("debug", T{Untranslated("  Stealth Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, num = dmg, bodypart = part})
					else
						CombatLog("debug", T{Untranslated("  Critical hit! <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, num = dmg, bodypart = part})
					end
				elseif hit.stray then
					CombatLog("debug", T{Untranslated("  Stray shot. <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				else
					CombatLog("debug", T{Untranslated("  <em><target></em> was hit in the <bodypart> for <em><num> damage</em>"), target = logName, bodypart = part, num = dmg})
				end
			end
		else
			CombatLog("debug", T{Untranslated("  <em><target></em> was hit for <em><num> damage</em>"), target = logName, num = dmg})
		end
		
		self:DisplayFloatingTextDamage(dmg, hit, true)

		if reductionInfo then
			for _, s in ipairs(reductionInfo) do
				CombatLog("debug", T{Untranslated("  <amount> damage was reduced by <statusEffect>"), amount = s.Value, statusEffect = s.Effect.DisplayName})
			end
		end
	else
		CombatLog("debug", T{Untranslated("  <em><target></em> was hit for <em><num> damage</em>"), target = logName, num = dmg})
	end
	if hit.stuck then
		CombatLog("debug", T(Untranslated("  Bullet got stuck"))) -- can happen before or after reaching the intended target
	end
end

---
--- Destroys the CombatObject and logs a message to the combat log.
--- Sends a "CombatObjectDied" message with the object and its bounding box.
--- Calls `DoneCombatObject` to clean up the object.
---
--- @param self CombatObject
function CombatObject:Die()
	CombatLog("debug", T{Untranslated("  <name> was destroyed"), name = self:GetLogName()})
	Msg("CombatObjectDied", self, self:GetObjectBBox())
	DoneCombatObject(self)
end

---
--- Returns the log name of the CombatObject.
--- If the CombatObject is a `PropertyObj` and has a `DisplayName` member, returns the `DisplayName`.
--- Otherwise, if the game is in developer mode, returns the class name of the CombatObject.
--- Otherwise, returns an empty string.
---
--- @param self CombatObject
--- @return string The log name of the CombatObject.
function CombatObject:GetLogName()
	if IsKindOf("PropertyObj") and self:HasMember("DisplayName") then
		return self.DisplayName
	end
	if Platform.developer then 
		return Untranslated(self.class)
	end
	return ""
end

---
--- Returns the current health percentage of the CombatObject.
---
--- @param self CombatObject
--- @return number The current health percentage of the CombatObject.
function CombatObject:GetHealthPercentage()
	return MulDivRound(100, self.HitPoints, self.MaxHitPoints)
end

CombatObject.SpreadDebris = DestroyableSlab.SpreadDebris
CombatObject.GetDebrisInfo = DestroyableSlab.GetDebrisInfo

AppendClass.Slab = {
	__parents = { "CombatObject" },

	material_type = false,
	SpreadDebris = DestroyableSlab.SpreadDebris,
	GetDebrisInfo = DestroyableSlab.GetDebrisInfo,
}

function OnMsg.ClassesGenerate(classdefs)
	local prop_meta = table.find_value(classdefs.AppearanceObject.properties, "id", "Appearance")
	prop_meta.default = "Ivan"
end

local function LogAreaDamageHits(hits, attacker, indent, no_units_text, results)
	local units_hit = 0
	for _, hit in ipairs(hits) do
		local target = hit.obj
		if IsValid(target) and hit.damage > 0 and IsKindOf(target, "CombatObject") then
			local is_unit = IsKindOf(target, "Unit")
			local lt = is_unit and "helper" or "debug"
			local prefix  = T(951707939968, "(<em>Hit</em>) ")
			units_hit = units_hit + (is_unit and 1 or 0)
			if table.find(results.killed_units or empty_table, target) then
				prefix = T(545544029910, "(<em>Kill</em>) ")
			end
			
			if attacker:IsOnAllySide(target) then
				prefix = T(322086931590, "(<em>Friendly fire</em>) ")
			end
			
			local log_name = target:GetLogName()
			if log_name ~= "" and IsT(log_name) and (type(log_name) == "table" and not log_name.untranslated) then 			
				CombatLog(lt, T{800299292975, "<prefix><target> takes <em><num> damage</em> by area attack", prefix = prefix, indent = indent or "", target = log_name, num = hit.damage})
			end
		end
	end
	if no_units_text and units_hit == 0 then
		CombatLog("helper", T{646611561441, "No targets hit", indent = indent or ""})
	end
end

local function LogDirectDamage(results, attacker, target, context, indent)
	local damage, hits, crits = 0, 0, 0
	local processed = {}
	local stray, grazing
	local cth = results.chance_to_hit or 100
	local shot_index = 1
	local absorbed_total = 0
	local inaccurate_grazed = 0
	for i,shot in ipairs(results.shots) do
		local cth = 0
		local damage = 0
		local absorbed = 0
		local grazed_miss
		if not results.obstructed then
			cth = shot.cth or 0
			for _, hit in ipairs(shot.hits) do
				if hit.obj == target then
					damage = damage + (hit.damage or 0)
					absorbed = absorbed + hit.armor_prevented
					grazed_miss = grazed_miss or hit.grazed_miss
				end
			end
		end
		absorbed_total = absorbed_total + absorbed
		local absorbed_text = (absorbed > 0) and T{101651236091, "(<absorbed> absorbed)",absorbed = absorbed}	or ""
		local outcome
		if grazed_miss then
			outcome = Untranslated("Grazed (inaccurate)")
		elseif shot.miss then
			outcome = Untranslated("Miss")
		else
			outcome = Untranslated("Hit")
		end
		CombatLog("debug", T{Untranslated("Shot <id> at <target> CtH: <percent(cth)>, roll: <num>/100 <hit_miss> <damage> damage <absorbed_text> "), 
			id = i, target = target:GetLogName(), cth = cth, num = shot.roll or 100, 
			hit_miss = outcome, 
			damage = damage, absorbed_text = absorbed_text
		})
	end
	for _, hit in ipairs(results) do
		if hit.obj == target then			
			damage = damage + hit.damage
			hits = hits + 1
			crits = crits + (hit.critical and 1 or 0)
			stray = stray or hit.stray		
			grazing = grazing or hit.grazing
			if hit.grazed_miss then
				inaccurate_grazed = inaccurate_grazed + 1
			end
		end
	end
	
	if results.miss and (inaccurate_grazed == 0) and not stray or results.obstructed then
		CombatLog("helper",T{556012296568, "<em>Missed</em> <target>",indent=indent, target = target:GetLogName()})
		return
	end
	
	if not IsT(target:GetLogName()) then return end
	
	local prefix, suffix = "", ""
	
	if results.stealth_attack then
		if results.stealth_kill then
			CombatLog("debug",T{Untranslated("<em>Stealth Kill</em> successful (<percent(stealth_chance)> chance)"),indent = indent,stealth_chance = context.stealth_kill_chance})
		else
			CombatLog("debug",T{Untranslated("<em>Stealth Kill</em> failed (<percent(stealth_chance)> chance)"),indent = indent,stealth_chance = context.stealth_kill_chance})
		end
	end
	
	if crits > 1 then
		suffix = T{820883776569, " (<num> crits)", num = crits}
	elseif crits == 1 then
		suffix = T(886703526051, " (crit)")
	end
	
	if results.stealth_kill then
		prefix = T(159664158022, "(<em>Stealth Kill</em>) ")
	elseif table.find(results.killed_units or empty_table, target) then
		prefix = T(545544029910, "(<em>Kill</em>) ")
	elseif hits > 1 then
		prefix = T{284567652570, "(<em><accurate> Hits</em>) ",accurate = hits}
	elseif grazing then
		prefix = T(226851065912, "(<em>Grazing hit</em>) ")
	else
		prefix = T(951707939968, "(<em>Hit</em>) ")
	end
	
	if attacker:IsOnAllySide(target) then
		if stray then
			prefix = T(806182260858, "(<em>Stray friendly fire</em>) ")
		else
			prefix = T(322086931590, "(<em>Friendly fire</em>) ")
		end
	elseif stray then
		prefix = T(623586221175, "(<em>Stray shot</em>) ")
	end
	
	if inaccurate_grazed > 0 then
		CombatLog("helper", T{901890498660, "<number> inaccurate shot(s) grazed the target", number = inaccurate_grazed})
	end
	
	local absorbed_text = absorbed_total > 0 and T{101651236091, "(<absorbed> absorbed)", absorbed = absorbed_total} or ""
	CombatLog("helper", T{575621720323, "<prefix><target> takes <em><num> damage</em> <absorbed_text><suffix>", 
			target = target:GetLogName(),
			prefix = prefix,
			suffix = suffix,
			num = damage,
			indent = indent or "",
			absorbed_text = absorbed_text}, indent)
end

---
--- Logs the details of an attack action in the combat log.
---
--- @param action string The name of the action being performed.
--- @param attack_args table A table containing information about the attack, such as the attacker, target, and weapon.
--- @param results table A table containing the results of the attack, such as the chance to hit, damage, and whether the attack was a stealth kill.
---
function LogAttack(action, attack_args, results)
	local attacker = attack_args.obj
	local target = attack_args.target
	local weapon = results.weapon

	if attack_args.used_action_id then
		action = CombatActions[attack_args.used_action_id] or action
	end
	local spot = attack_args.target_spot_group
	local spotname = spot and Presets.TargetBodyPart.Default[spot] and Presets.TargetBodyPart.Default[spot].display_name

	local context = {
		attacker = attacker:GetLogName(),
		target = IsKindOf(target, "Unit") and target:GetLogName() or "",
		attack = not not attacker.attack_reason and attacker.attack_reason or action:GetActionDisplayName({attacker}),
		retaliation = not not attacker.attack_reason and T(425058684346, "(<em>Interrupt</em>) ") or "",
		weapon = weapon.DisplayName,
		cth = results.chance_to_hit or 100,
		stealth_kill_chance = attack_args.stealth_kill_chance or 0,
		num_attacks = IsKindOf(weapon, "Firearm") and results.fired or 1,
		mishap = results.mishap and T(899186217845, "(<em>Mishap</em>) ") or "",
		target_spot = spotname and T{345592247170, "(<target_spot>)",target_spot = spotname} or ""
	}

	if IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then
		local indent = "  "
		context.indent = indent
		
		if context.target == "" then
			CombatLog("short", T{103704598522, "<mishap><em><retaliation><attack></em> by <em><attacker></em> <target_spot>", context})
		else
			CombatLog("short", T{201907063671, "<mishap><retaliation><em><attack></em> at <target> by <em><attacker></em> <target_spot>", context})
			CombatLog("debug", T{Untranslated("Attack CtH - <percent(cth)>"), context})
		end
		
		local any_hit = true
		if IsKindOf(target, "CombatObject") then
			LogDirectDamage(results, attacker, target, context, indent)
			any_hit = false
		end	
		
		if IsKindOf(weapon, "Firearm") then
			-- basic damage logging for all other hit units (stray shots)
			local processed = { [target] = true }
			for _, hit in ipairs(results) do
				if not processed[hit.obj] and IsKindOf(hit.obj, "Unit") and hit.damage > 0 then
					-- basic damage logging for this unit (stray)
					LogDirectDamage(results, attacker, hit.obj, context, indent)
					processed[hit.obj] = true
					any_hit = false
				end
			end
			
			LogAreaDamageHits(results.area_hits or empty_table, attacker, indent, any_hit, results)
		end
		
		if any_hit and results.stealth_attack and (not results.stealth_kill) and (attack_args.stealth_kill_chance or 0) > 0 then
			CombatLog("short",T{321216462186, "<indent><em>Stealth Kill</em> failed", indent = indent, stealth_chance = attack_args.stealth_kill_chance})
			CombatLog("debug",T{Untranslated("<indent>Stealth Kill< chance (<percent(stealth_chance)>)"), indent = indent, stealth_chance = attack_args.stealth_kill_chance})
		end
		
	elseif IsKindOf(weapon, "Grenade") then
		if attacker.attack_reason then
			CombatLog("short", T{604040871119, "<mishap>Interrupt attack - <em><weapon></em> thrown by <em><attacker></em>", context})
		else
			CombatLog("short", T{339680683529, "<mishap><em><attacker></em> has thrown a <em><weapon></em>", context})
		end
		if not results.trap_placed then
			LogAreaDamageHits(results, attacker, "  ", T(233144990184, "No targets hit"),results)
		end
	elseif IsKindOf(weapon, "Ordnance") then	
		CombatLog("short", T{539114035613, "<mishap><em><attacker></em> has launched a <em><weapon></em>", context})
		LogAreaDamageHits(results, attacker, "  ", T(233144990184, "No targets hit"),results)
	end	
end

DefineClass.HidingCombatObject = {
	__parents = {"CombatObject", "EditorObject"},
	
	properties = {
		{id = "is_destroyed", editor = "bool", default = false, no_edit = true, dont_save = true},
	},
}

--- Destroys the HidingCombatObject and logs its destruction.
---
--- This function is called when the HidingCombatObject is destroyed. It performs the following actions:
--- - Destroys the object
--- - Logs a debug message with the object's name
--- - Sends a "CombatObjectDied" message with the object's bounding box
--- - Sets the object's command to "Dead"
---
--- @param self HidingCombatObject The HidingCombatObject instance
function HidingCombatObject:Die()
	self:Destroy()
	CombatLog("debug", T{Untranslated("  <name> was destroyed"), name = self:GetLogName()})
	Msg("CombatObjectDied", self, self:GetObjectBBox())
	self:SetCommand("Dead")
end

--- Hides and disables collision for the HidingCombatObject.
---
--- This function is called when the HidingCombatObject is in the "Dead" state. It performs the following actions:
--- - Sets the object's visibility to false
--- - Disables collision for the object
function HidingCombatObject:Dead()
	self:SetVisible(false)
	self:SetCollision(false)
end

--- Sets the dynamic data for the HidingCombatObject.
---
--- If the object is dead, this function disables its collision.
---
--- @param self HidingCombatObject The HidingCombatObject instance
--- @param data table The dynamic data to set for the object
function HidingCombatObject:SetDynamicData(data)
	if self:IsDead() then
		collision.SetAllowedMask(self, 0)
	end
end

if FirstLoad then
	g_DbgExplosionDamage = false
end

--- Spawns an incendiary explosion effect at the specified position.
---
--- If no position is provided, the function will attempt to find the closest visible object under the mouse cursor and use its position. If that fails, it will request the pixel world position under the mouse cursor.
---
--- The explosion effect includes:
--- - Placing a "Explosion_Barrel" particle effect at the explosion position
--- - Applying a color modifier to all visible objects within the explosion radius
--- - Placing "Env_Fire1x1" and "Env_Fire1x1_Smoldering" particle effects in a circle around the explosion position
--- - Placing a "DecExplosion_02" object at the explosion position
---
--- @param pos point The position of the explosion (optional)
function DbgIncendiaryExplosion(pos)
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o) --wip, causes collision assert atm
		--local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end
	
	local obj = PlaceParticles("Explosion_Barrel")
	obj:SetPos(pos)

	local origin = SnapToVoxel(pos):SetZ(pos:z())
	local radius = 2*const.SlabSizeX
	local step = const.SlabSizeX
	local step = 70*guic
	local pos_noise = 20*guic
	local terrain1 = Presets.TerrainObj.Default.Dry_BurntGround_01
	local terrain2 = Presets.TerrainObj.Default.Dry_BurntGround_02
	local objs = MapGet(pos, radius, "Object", function(o) return o:GetEnumFlags(const.efVisible) ~= 0 end)
	for _, obj in ipairs(objs) do
		obj:SetColorModifier(RGBA(0, 0, 0, 255))
	end
	for dy = -radius, radius, step do
		for dx = -radius, radius, step do
			local pt = origin + point(dx, dy, 0)
			local slab_obj, z = WalkableSlabByPoint(pt)
			pt = pt:SetZ(z)
			if IsCloser(pos, pt, radius) then
				CreateGameTimeThread(function(p, t)
					local obj = PlaceParticles("Env_Fire1x1")
					obj:SetPos(p)
					terrain.SetTypeCircle(p, step/2, t)
					Sleep(5000 + AsyncRand(1000))
					StopParticles(obj)
					obj = PlaceParticles("Env_Fire1x1_Smoldering")
					obj:SetPos(p)
					Sleep(2000 + AsyncRand(1000))
					StopParticles(obj)
				end, pt, (AsyncRand(100) < 50 and terrain1 or terrain2).idx)
			end
		end
	end

	obj = PlaceObject("DecExplosion_02")
	if obj then
		obj:SetPos(pos)
	end--]]
	
	--[[
	local grenade = PlaceInventoryItem("Super_HE_Grenade")
	local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
	
	local results = GetAreaAttackResults(aoe_params, 0, nil, dmg)
	if dmg then
		DbgTestExplode(pos)
	end
	ApplyExplosionDamage(nil, nil, results, 0)
	DoneCombatObject(grenade)--]]
end

local ce_thread = false
---
--- Generates a carpet of explosions on the terrain, with configurable explosion patterns.
---
--- @param ztype string|number|nil The type of explosion pattern to use:
---   - `nil` or `"grounded"`: Explosions on the terrain surface.
---   - Number: Explosions at terrain height plus the specified number of steps in the Z direction. Negative values go from top to bottom, positive values go from bottom to top.
---   - `"bomb"`: Raycast from the sky, with explosions at the first object hit's maximum Z coordinate.
---
function DbgCarpetExplosionDamage(ztype)
	--ztype:
	--nil or "grounded" -> explosions on terrainz
	--number -> terrain z + 'number' of explosions at terrain z + zstep * z, if negative goes from top pt to bot pt, if positie goest from bot pt to top pt.
	--"bomb" -> raycast from the sky, first obj hit's box maxz
	local stepx = const.SlabSizeX * 3
	local stepy = const.SlabSizeY * 3
	local stepz = const.SlabSizeZ * 3
	local border = GetBorderAreaLimits():grow(stepx, stepy, 0)
	local bmin = border:min()
	local bmax = border:max()
	DbgClear()
	local x, y, z = 0, 0, 0
	if IsValidThread(ce_thread) then
		DeleteThread(ce_thread)
	end
	ce_thread = CreateRealTimeThread(function()
		while true do
			local xx = bmin:x() + const.SlabSizeX / 2 + x * stepx
			if xx >= bmax:x() then
				x = 0
				y = y + 1
				xx = bmin:x() + const.SlabSizeX / 2
			end
			local yy = bmin:y() + const.SlabSizeY / 2 + y * stepy
			if yy >= bmax:y() then
				break
			end
			local zz
			if not ztype or ztype == "grounded" then
				zz = terrain.GetHeight(xx, yy)
				x = x + 1
			elseif type(ztype) == "number" then
				if ztype < 0 then
					zz = terrain.GetHeight(xx, yy) + (abs(ztype) - z) * stepz
				else
					zz = terrain.GetHeight(xx, yy) + z * stepz
				end
				z = z + 1
				if z > abs(ztype) then
					z = 0
					x = x + 1
				end
			elseif ztype == "bomb" then
				local th = terrain.GetHeight(xx, yy)
				zz = th
				local sp = point(xx, yy, th + const.SlabSizeZ * 100)
				local ep = point(xx, yy, th)
				local closest = GetClosestRayObj(sp, ep, const.efVisible + const.efCollision)
				if closest then
					zz = closest:GetObjectBBox():maxz()
				end
				x = x + 1
			end
			
			DbgExplosionDamage(point(xx, yy, zz))
			Sleep(5)
		end
	end)
end

if FirstLoad then
	DbgExplosionFX_ShowRange = false
end

---
--- Generates an explosion effect at the specified position.
---
--- If no position is provided, the function will attempt to find the closest visible and non-destroyed object in the line of sight from the camera to the mouse cursor. If no object is found, it will use the world position under the mouse cursor.
---
--- The function will cycle through a list of available explosion types (grenades, mortar shells, 40mm grenades) and select the next one in the list. It will then place an inventory item of the selected explosion type at the target position, and apply the explosion damage to any affected objects in the area of effect.
---
--- If the `DbgExplosionFX_ShowRange` flag is set, the function will also display a debug circle around the explosion to visualize the area of effect.
---
--- @param pos point|nil The position at which to generate the explosion effect. If not provided, the function will attempt to find the closest valid position.
--- @return nil
function DbgExplosionFX(pos)
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		--local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o)
		local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end	

		local explosion_actor = DbgCycleExplosion(0) --"FragGrenade"
		local surf_fx_type = GetObjMaterial(pos)
		pos = pos - point(0,0,255)
		local grenade = PlaceInventoryItem(explosion_actor)
		local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
		local results = GetAreaAttackResults(aoe_params, 0, nil, false)
		results.burn_ground = grenade.BurnGround
		
		if DbgExplosionFX_ShowRange then
			ShowCircle(pos, results.range, RGB(128, 128, 128)) -- range dbg
		end
		
		if IsKindOf(grenade, "ThrowableTrapItem") then
			explosion_actor = explosion_actor .. "_OnGround"
		end
		if IsKindOf(grenade, "Flare") then
			local flare = PlaceObject("FlareOnGround", {fx_actor_class = grenade.class})
			flare:SetPos(pos)
			PlayFX("Spawn", "start", flare)
		else
			if grenade.aoeType ~= "none" then
				PlayFX("ExplosionGas", "start", explosion_actor, surf_fx_type, pos)	
			else
				PlayFX("Explosion", "start", explosion_actor, surf_fx_type, pos)
			end
			ApplyExplosionDamage(nil, nil, results, 0)
		end
		DoneCombatObject(grenade)
end

local DbgGrenadeIdx = 9

---
--- Sets the explosion type for the given object.
---
--- @param self CombatObject The combat object to set the explosion type for.
--- @param root Object The root object of the combat object.
--- @param prop_id number The property ID of the combat object.
--- @param ged table The game engine data for the combat object.
---
function DbgSetExplosionType(self, root, prop_id, ged)
	DbgCycleExplosion(self.id)
end

---
--- Cycles through the available explosion types for the game.
---
--- @param value number|string The index or name of the explosion type to cycle to.
--- @return string The ID of the selected explosion type.
---
function DbgCycleExplosion(value)
	local explosion_list = GetWeaponsByType("Grenade")
	local grenade_id = table.values(explosion_list, true, "id")
	local mortar_ammo = GetAmmosWithCaliber("MortarShell") --MortarShell
	local _40mm_ammo =  GetAmmosWithCaliber("40mmGrenade") --40mmGrenade
	local mortar_id = table.values(mortar_ammo, true, "id")
	local _40mm_id = table.values(_40mm_ammo, true, "id")
	local all = table.iappend(mortar_id, _40mm_id)
	all = table.iappend(all, grenade_id)
	
	if type(value) == "string" then
		DbgGrenadeIdx = table.find(all, value) or DbgGrenadeIdx
		value = 0
	end
	
	if table.maxn(all) == DbgGrenadeIdx and value == 1 then
		DbgGrenadeIdx = 1
	else
		DbgGrenadeIdx = DbgGrenadeIdx + value
		if DbgGrenadeIdx == 0 then
			DbgGrenadeIdx = table.maxn(all)
		end
	end
	--print(DbgGrenadeIdx, all[DbgGrenadeIdx])
	return all[DbgGrenadeIdx]
end


---
--- Applies explosion damage to objects within the specified area of effect.
---
--- @param pos Vector3 The position of the explosion.
--- @param dmg number The amount of damage to apply. If not provided, uses the global `g_DbgExplosionDamage` value.
---
--- This function first tries to determine the position of the explosion by checking the cursor position. If no position is provided, it will try to find the closest visible and non-destroyed object on the segment between the camera eye and the cursor position.
---
--- Once the explosion position is determined, it creates a "Super_HE_Grenade" inventory item, gets the area of effect parameters for that item, and applies the explosion damage to all objects within the area of effect.
---
--- If the `dmg` parameter is provided, the function will call `DbgTestExplode` to simulate the explosion. Otherwise, it will call `DbgAddVector` to add a visual marker at the explosion position.
---
function DbgExplosionDamage(pos, dmg)
	dmg = dmg or g_DbgExplosionDamage
	if not pos then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false 
		--local objs = IntersectObjectsSphereCast(sp, ep, guim/4, 0, "Slab", function(o)
		local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pos = p1 or closest:GetPos()
		end
		if not pos then
			RequestPixelWorldPos(terminal.GetMousePos()) 
			WaitNextFrame(6)
			pos = ReturnPixelWorldPos()
		end
	end
	if not pos then return end
	
	local grenade = PlaceInventoryItem("Super_HE_Grenade")
	local aoe_params = grenade:GetAreaAttackParams(nil, nil, pos)
	aoe_params.prediction = false
	local results = GetAreaAttackResults(aoe_params, 0, nil, dmg)
	if dmg then
		DbgTestExplode(pos, "Explosion")
	else
		DbgAddVector(pos)
	end
	ApplyExplosionDamage(nil, nil, results, 0)
	DoneCombatObject(grenade)
end

--- Applies damage to a target object at a specified position.
---
--- @param pos Vector3 The position of the bullet impact.
--- @param dmg number The amount of damage to apply.
---
--- This function first tries to determine the target object by checking the cursor position. If no target is found, it prints a message and returns.
---
--- If a target is found, the function tries to find a suitable shot vector around the target. It calculates the attack position and collision position, and then uses the Firearm:ProjectileFly function to simulate the bullet impact.
---
--- If the `dmg` parameter is provided and the target is a `CombatObject`, the function will call the `TakeDirectDamage` method on the target to apply the damage.
function DbgBulletDamage(pos, dmg)
	if not CurrentThread() then
		return CreateGameTimeThread(DbgBulletDamage, pos, dmg)
	end
	-- find target object
	if not pos then
		RequestPixelWorldPos(terminal.GetMousePos())
		WaitNextFrame(6)
		pos = ReturnPixelWorldPos()
		if not pos then
			return
		end
	end
	local target_pos = pos
	local target = GetPreciseCursorObj()
	if IsKindOf(target, "Unit") then
		target = SelectionPropagate(target)
	end
	if not target then
		print("no target found")
		return
	else
--		printf("target found: %s (%s)", target.class, target:GetEntity())
		if target:GetEnumFlags(const.efCollision) == 0 then
			print("  target has no collision, try using normal attacks (F)")
			return
		end
	end

	-- find a suitable shot around the target
	local attacker = SelectedObj
	local attack_pos, collision_pos
	if IsKindOf(attacker, "Unit") then
		attack_pos = attacker:GetSpotLocPos(attacker:GetSpotBeginIndex("Head"))
		target_pos = attack_pos + (target_pos - attack_pos)*5/4
		local any_hit, hit_pos, hit_objs = CollideSegmentsObjs({attack_pos, target_pos})
		if any_hit then
			for i, obj in ipairs(hit_objs) do
				if obj == target then
					collision_pos = hit_pos[i]
					break
				end
			end
		end
	else
		for i = 1, 100 do
			local len = 3 * guim + AsyncRand(5 * guim)
			local origin = RotateRadius(len, AsyncRand(360*60), target_pos)
			for j = 0, 20 do
				attack_pos = SnapToPassSlab(origin:SetTerrainZ(j*guim))
				if attack_pos then break end
			end
			if attack_pos then
				if not attack_pos:IsValidZ() then
					attack_pos = attack_pos:SetTerrainZ()
				end
				attack_pos = attack_pos + point(0, 0, guim)
				local tp = attack_pos + (target_pos - attack_pos)*5/4
				local any_hit, hit_pos, hit_objs = CollideSegmentsObjs({attack_pos, tp})
				if any_hit then
					for i, obj in ipairs(hit_objs) do
						if obj == target then
							collision_pos = hit_pos[i]
							break
						end
					end
				end
			end
			if collision_pos then break end
		end
	end
	
	if not attack_pos or not collision_pos then
		print("failed to find a suitable shot vector")
		return
	end
	
	local hit = {
		obj = target, 
		pos = collision_pos,
		distance = collision_pos:Dist(attack_pos),
	}
	local dir = SetLen(target_pos - attack_pos, 4096)
	Firearm:ProjectileFly(nil, attack_pos, collision_pos, dir, const.Combat.BulletVelocity, {hit})
	if dmg and IsKindOf(target, "CombatObject") then
		target:TakeDirectDamage(dmg)
	end
end

MapVar("g_PlacedDescendantObjects", false)

---
--- Places descendant objects of the given parent classes at the specified position and width.
---
--- @param parent_classes string|string[] The parent class(es) to get descendants from.
--- @param pt point The position to place the objects at.
--- @param width number The maximum width to place the objects within.
---
function PlaceDescendantObjects(parent_classes, pt, width)
	if type(parent_classes) == "string" then
		parent_classes = { parent_classes }
	end
	local classes = {}
	for _, parent in ipairs(parent_classes) do
		ClassDescendants(parent, function(child, classdef, classes)
			classes[child] = true
		end, classes)
	end
	
	classes = table.keys2(classes)
	table.sort(classes)

	local n = sqrt(#classes)+1
	local x, y = pt:xyz()
	local idx = 1
	
	SuspendPassEdits("pdo")
	
	for _, obj in ipairs(g_PlacedDescendantObjects or empty_table) do
		DoneObject(obj)
	end
	
	local placed_objs = {}
	
	for j=1,#classes do
		x = pt:x()
		local maxr, sumr = 0, 0
		for i=1,#classes do
			if idx < #classes then
				local obj = PlaceObject(classes[idx])
				local r = Max(const.SlabSizeX, Min(obj:GetEntityBBox():size():Len2D()/2, obj:GetRadius()))
				obj:SetPos(point(x, y))
				maxr = Max(maxr, r)
				sumr = sumr + r
				idx = idx + 1
				x = x + r * 2
				placed_objs[#placed_objs+1] = obj
				
				if sumr > width then break end
			end
		end
		y = y + maxr*2
	end
	
	ResumePassEdits("pdo")
	g_PlacedDescendantObjects = placed_objs
end