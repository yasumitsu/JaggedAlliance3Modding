-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Conscience_Guilty')
DefineClass.Conscience_Guilty = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectAdded")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					local effect = obj:GetStatusEffect(self.id)
					effect:SetParameter("guilty_start_time", Game.CampaignTime)
					
					--local procentCalc = 1000-self:ResolveValue("decrease")*10
					--local stats = UnitPropertiesStats:GetProperties()
					--for i, stat in ipairs(stats) do
						--obj:AddModifier("guilty_" .. stat.id, stat.id, procentCalc)
					--end
				end
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks) end
				
			end,
			HandlerCode = function (self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					local effect = obj:GetStatusEffect(self.id)
					effect:SetParameter("guilty_start_time", Game.CampaignTime)
					
					--local procentCalc = 1000-self:ResolveValue("decrease")*10
					--local stats = UnitPropertiesStats:GetProperties()
					--for i, stat in ipairs(stats) do
						--obj:AddModifier("guilty_" .. stat.id, stat.id, procentCalc)
					--end
				end
			end,
			param_bindings = false,
		}),
		PlaceObj('MsgReaction', {
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectRemoved")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("guilty_start_time", false)
					
					-- Handles old guilty modifiers, new guilty applies morale modifier
					local stats = UnitPropertiesStats:GetProperties()
					for i, stat in ipairs(stats) do
						obj:RemoveModifier("guilty_" .. stat.id, stat.id)
					end
				end
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks, reason) end
				
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("guilty_start_time", false)
					
					-- Handles old guilty modifiers, new guilty applies morale modifier
					local stats = UnitPropertiesStats:GetProperties()
					for i, stat in ipairs(stats) do
						obj:RemoveModifier("guilty_" .. stat.id, stat.id)
					end
				end
			end,
			param_bindings = false,
		}),
		PlaceObj('MsgReactionEffects', {
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Effects', {
						PlaceObj('ExecuteCode', {
							Code = function (self, obj)
								local effect = obj:GetStatusEffect("Conscience_Guilty")
								local duration = effect:ResolveValue("days")
								local startTime = effect:ResolveValue("guilty_start_time") or 0
								
								local dayStarted = GetTimeAsTable(startTime)
								dayStarted = dayStarted and dayStarted.day
								
								local dayNow = GetTimeAsTable(Game.CampaignTime)
								dayNow = dayNow and dayNow.day
								
								-- Intentionally check if days have passed calendar, and not time wise.
								if dayNow - dayStarted >= duration then
									obj:RemoveStatusEffect("Conscience_Guilty")
								end
							end,
							FuncCode = 'local effect = obj:GetStatusEffect("Conscience_Guilty")\nlocal duration = effect:ResolveValue("days")\nlocal startTime = effect:ResolveValue("guilty_start_time") or 0\n\nlocal dayStarted = GetTimeAsTable(startTime)\ndayStarted = dayStarted and dayStarted.day\n\nlocal dayNow = GetTimeAsTable(Game.CampaignTime)\ndayNow = dayNow and dayNow.day\n\n-- Intentionally check if days have passed calendar, and not time wise.\nif dayNow - dayStarted >= duration then\n	obj:RemoveStatusEffect("Conscience_Guilty")\nend',
							SaveAsText = false,
							param_bindings = false,
						}),
					},
				}),
			},
			Event = "SatelliteTick",
			Handler = function (self)
				CE_ExecReactionEffects(self, "SatelliteTick")
			end,
			param_bindings = false,
		}),
	},
	DisplayName = T(374563958345, --[[CharacterEffectCompositeDef Conscience_Guilty DisplayName]] "Guilty"),
	Description = T(117856843594, --[[CharacterEffectCompositeDef Conscience_Guilty Description]] "Morale decreased by 1 for a day."),
	AddEffectText = T(446826511839, --[[CharacterEffectCompositeDef Conscience_Guilty AddEffectText]] "<em><DisplayName></em> is feeling guilty and lost Morale"),
	type = "Debuff",
	Icon = "UI/Hud/Status effects/encumbered",
	HasFloatingText = true,
}

