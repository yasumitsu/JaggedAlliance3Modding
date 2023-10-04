-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Distracted')
DefineClass.Distracted = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					-- force recalc/redraw of sight range
					Msg("UnitStanceChanged", obj)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "StatusEffectAdded" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks)
				end
				
				if self:VerifyReaction("StatusEffectAdded", reaction_def, obj, obj, id, stacks) then
					exec(self, obj, id, stacks)
				end
			end,
			HandlerCode = function (self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					-- force recalc/redraw of sight range
					Msg("UnitStanceChanged", obj)
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					-- force recalc/redraw of sight range
					Msg("UnitStanceChanged", obj)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "StatusEffectRemoved" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks, reason)
				end
				
				if self:VerifyReaction("StatusEffectRemoved", reaction_def, obj, obj, id, stacks, reason) then
					exec(self, obj, id, stacks, reason)
				end
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					-- force recalc/redraw of sight range
					Msg("UnitStanceChanged", obj)
				end
			end,
		}),
	},
	Conditions = {
		PlaceObj('CheckExpression', {
			Expression = function (self, obj) return IsKindOf(obj, "Unit") and not obj:IsAware("pending") end,
		}),
	},
	DisplayName = T(420820589875, --[[CharacterEffectCompositeDef Distracted DisplayName]] "Distracted"),
	Description = T(841639099544, --[[CharacterEffectCompositeDef Distracted Description]] "Awareness range drastically reduced."),
	Icon = "UI/Hud/Status effects/unconscious",
	Shown = true,
}

