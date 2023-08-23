-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "Surprised",
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "stealthkill_modifier",
			'Value', -50,
			'Tag', "<stealthkill_modifier>%",
		}),
	},
	'object_class', "CharacterEffect",
	'msg_reactions', {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectAdded")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks)
				obj:RemoveStatusEffect("Unaware")
				if IsKindOf(obj, "Unit") and obj.command == "Idle" then
					obj:SetCommand("Idle")
				end
				ObjModified(SelectedObj)
				ObjModified("combat_bar")
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks) end
				
			end,
			HandlerCode = function (self, obj, id, stacks)
				obj:RemoveStatusEffect("Unaware")
				if IsKindOf(obj, "Unit") and obj.command == "Idle" then
					obj:SetCommand("Idle")
				end
				ObjModified(SelectedObj)
				ObjModified("combat_bar")
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectRemoved")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") and obj.command == "Idle" then
					obj:SetCommand("Idle")
				end
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks, reason) end
				
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") and obj.command == "Idle" then
					obj:SetCommand("Idle")
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "UnitBeginTurn")
				if not reaction_idx then return end
				
				local function exec(self, unit)
				PushUnitAlert("surprise", unit)
				end
				local id = GetCharacterEffectId(self)
				
				if id then
					if IsKindOf(unit, "StatusEffectObject") and unit:HasStatusEffect(id) then
						exec(self, unit)
					end
				else
					exec(self, unit)
				end
				
			end,
			HandlerCode = function (self, unit)
				PushUnitAlert("surprise", unit)
			end,
		}),
	},
	'Conditions', {
		PlaceObj('CheckExpression', {
			Expression = function (self, obj) return not not g_Combat and IsKindOf(obj, "Unit") and not obj:IsAware() end,
		}),
	},
	'DisplayName', T(197461676465, --[[CharacterEffectCompositeDef Surprised DisplayName]] "Surprised"),
	'Description', T(877523356845, --[[CharacterEffectCompositeDef Surprised Description]] "Alerted but doesn't know what's going on. Better resistance against <em>Stealth Kills</em>. Will become fully <em>Aware</em> at the start of their next turn or when engaged by an enemy. "),
	'Icon', "UI/Hud/Status effects/surprised",
	'RemoveOnEndCombat', true,
	'Shown', true,
	'HasFloatingText', true,
})

