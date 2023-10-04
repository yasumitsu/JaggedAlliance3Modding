-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('InnerInfo')
DefineClass.InnerInfo = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			Event = "OnEnterMapVisual",
			Handler = function (self)
				
				local function exec(self, reaction_actor)
				CreateGameTimeThread(function()
					local livewire = g_Units.Livewire
					local sector = gv_Sectors[gv_CurrentSectorId]
					local playVr
					if livewire and livewire.HireStatus == "Hired" and sector.intel_discovered then
						while GetInGameInterfaceMode() == "IModeDeployment" do
							Sleep(20)
						end
						for _, unit in ipairs(g_Units) do
							if unit:IsOnEnemySide(livewire) then
								unit:RevealTo(livewire.team)
								unit.innerInfoRevealed = true
								playVr = true
								break
							end
						end
						if playVr then
							Sleep(2000)
							PlayVoiceResponse(livewire,"PersonalPerkSubtitled")
						end
					end
				end)
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "OnEnterMapVisual" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					local reaction_actor
					exec(self, reaction_actor)
				end
				
				
				local actors = self:GetReactionActors("OnEnterMapVisual", reaction_def, nil)
				for _, reaction_actor in ipairs(actors) do
					if self:VerifyReaction("OnEnterMapVisual", reaction_def, reaction_actor, nil) then
						exec(self, reaction_actor)
					end
				end
			end,
			HandlerCode = function (self, reaction_actor)
				CreateGameTimeThread(function()
					local livewire = g_Units.Livewire
					local sector = gv_Sectors[gv_CurrentSectorId]
					local playVr
					if livewire and livewire.HireStatus == "Hired" and sector.intel_discovered then
						while GetInGameInterfaceMode() == "IModeDeployment" do
							Sleep(20)
						end
						for _, unit in ipairs(g_Units) do
							if unit:IsOnEnemySide(livewire) then
								unit:RevealTo(livewire.team)
								unit.innerInfoRevealed = true
								playVr = true
								break
							end
						end
						if playVr then
							Sleep(2000)
							PlayVoiceResponse(livewire,"PersonalPerkSubtitled")
						end
					end
				end)
			end,
		}),
	},
	DisplayName = T(380316218017, --[[CharacterEffectCompositeDef InnerInfo DisplayName]] "Inside Dope"),
	Description = T(222768539188, --[[CharacterEffectCompositeDef InnerInfo Description]] "<em>Reveals</em> all <em>Enemies</em> if you have <em>Intel</em> for the Sector."),
	Icon = "UI/Icons/Perks/InnerInfo",
	Tier = "Personal",
}

