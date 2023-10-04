-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('ManningEmplacement')
DefineClass.ManningEmplacement = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				local emplacementHandle = obj:GetEffectValue("hmg_emplacement")
				local emplacementObj = HandleToObject[emplacementHandle]
				if emplacementObj then
					emplacementObj.manned_by = false
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "StatusEffectRemoved" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks, reason)
				end
				
				if self:VerifyReaction("StatusEffectRemoved", reaction_def, obj, obj, id, stacks, reason) then
					exec(self, obj, id, stacks, reason)
				end
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				local emplacementHandle = obj:GetEffectValue("hmg_emplacement")
				local emplacementObj = HandleToObject[emplacementHandle]
				if emplacementObj then
					emplacementObj.manned_by = false
				end
			end,
		}),
	},
}

