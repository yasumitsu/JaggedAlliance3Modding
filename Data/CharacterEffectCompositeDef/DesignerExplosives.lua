-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "DesignerExplosives",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "hoursToProduce",
			'Value', 168,
			'Tag', "<hoursToProduce>",
		}),
		PlaceObj('PresetParamNumber', {
			'Name', "amountToProduce",
			'Value', 2,
			'Tag', "<amountToProduce>",
		}),
		PlaceObj('PresetParamNumber', {
			'Name', "nextProductionTime",
			'Tag', "<nextProductionTime>",
		}),
	},
	'Comment', "Barry - Shaped charges;",
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				local effect = obj:GetStatusEffect(self.id)
				effect:SetParameter("nextProductionTime", Game.CampaignTime + effect:ResolveValue("hoursToProduce") * const.Scale.h)
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
				local effect = obj:GetStatusEffect(self.id)
				effect:SetParameter("nextProductionTime", Game.CampaignTime + effect:ResolveValue("hoursToProduce") * const.Scale.h)
			end,
		}),
		PlaceObj('MsgActorReaction', {
			Event = "NewHour",
			Handler = function (self)
				
				local function exec(self, reaction_actor)
				local unit =  gv_UnitData.Barry
				unit = unit.HireStatus == "Hired" and unit
				
				if unit  then
					local effect = unit:GetStatusEffect(self.id)
					local next_production = effect:ResolveValue("nextProductionTime")
					if Game.CampaignTime >= next_production and not gv_Squads[unit.Squad].water_travel then
						local amountToProduce = DesignerExplosives:ResolveValue("amountToProduce")
						local item_name = amountToProduce > 1 and g_Classes["ShapedCharge"].DisplayNamePlural or  g_Classes["ShapedCharge"].DisplayName
						effect:SetParameter("nextProductionTime", Game.CampaignTime + effect:ResolveValue("hoursToProduce") * const.Scale.h)
						
						local slots = {  "Handheld A",  "Handheld B",  "Inventory" }
						local canPlaceError, amountLeft
						local amountToPlace = amountToProduce
						for _, slot in ipairs(slots) do
							canPlaceError, amountLeft = CanPlaceItemInInventory("ShapedCharge", amountToPlace, unit, slot)
							if not canPlaceError then
								PlaceItemInInventory("ShapedCharge", amountToPlace, unit, nil, nil, slot)
								if not amountLeft then
									break
								else
									amountToPlace = amountLeft
								end
							end
						end
						
						local text = T{318623454402, "<merc> produced <amount> <item_name>.", merc = unit.Nick, amount = amountToProduce, item_name = item_name}
						if canPlaceError or (amountLeft and amountLeft > 0) then
							amountToPlace = amountToPlace or amountToProduce
							PlaceItemInInventory("ShapedCharge", amountToPlace, gv_Squads[unit.Squad].CurrentSector)
							text = text .. T(447763084369, " Some were placed in the sector stash.")
							CombatLog("important", text)	
						else
							CombatLog("important", text)
						end
						
						if IsKindOf(unit, "Unit") then
							local unit_data = gv_UnitData[unit.session_id] 
							CopyPropertiesShallow(unit_data, unit, StatusEffectObject:GetProperties(), "copy_values")
							ObjModified(unit_data)
						end
					end
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "NewHour" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					local reaction_actor
					exec(self, reaction_actor)
				end
				
				
				local actors = self:GetReactionActors("NewHour", reaction_def, nil)
				for _, reaction_actor in ipairs(actors) do
					if self:VerifyReaction("NewHour", reaction_def, reaction_actor, nil) then
						exec(self, reaction_actor)
					end
				end
			end,
			HandlerCode = function (self, reaction_actor)
				local unit =  gv_UnitData.Barry
				unit = unit.HireStatus == "Hired" and unit
				
				if unit  then
					local effect = unit:GetStatusEffect(self.id)
					local next_production = effect:ResolveValue("nextProductionTime")
					if Game.CampaignTime >= next_production and not gv_Squads[unit.Squad].water_travel then
						local amountToProduce = DesignerExplosives:ResolveValue("amountToProduce")
						local item_name = amountToProduce > 1 and g_Classes["ShapedCharge"].DisplayNamePlural or  g_Classes["ShapedCharge"].DisplayName
						effect:SetParameter("nextProductionTime", Game.CampaignTime + effect:ResolveValue("hoursToProduce") * const.Scale.h)
						
						local slots = {  "Handheld A",  "Handheld B",  "Inventory" }
						local canPlaceError, amountLeft
						local amountToPlace = amountToProduce
						for _, slot in ipairs(slots) do
							canPlaceError, amountLeft = CanPlaceItemInInventory("ShapedCharge", amountToPlace, unit, slot)
							if not canPlaceError then
								PlaceItemInInventory("ShapedCharge", amountToPlace, unit, nil, nil, slot)
								if not amountLeft then
									break
								else
									amountToPlace = amountLeft
								end
							end
						end
						
						local text = T{318623454402, "<merc> produced <amount> <item_name>.", merc = unit.Nick, amount = amountToProduce, item_name = item_name}
						if canPlaceError or (amountLeft and amountLeft > 0) then
							amountToPlace = amountToPlace or amountToProduce
							PlaceItemInInventory("ShapedCharge", amountToPlace, gv_Squads[unit.Squad].CurrentSector)
							text = text .. T(447763084369, " Some were placed in the sector stash.")
							CombatLog("important", text)	
						else
							CombatLog("important", text)
						end
						
						if IsKindOf(unit, "Unit") then
							local unit_data = gv_UnitData[unit.session_id] 
							CopyPropertiesShallow(unit_data, unit, StatusEffectObject:GetProperties(), "copy_values")
							ObjModified(unit_data)
						end
					end
				end
			end,
		}),
	},
	'DisplayName', T(715337616257, --[[CharacterEffectCompositeDef DesignerExplosives DisplayName]] "Boutique Explosives"),
	'Description', T(405122724505, --[[CharacterEffectCompositeDef DesignerExplosives Description]] "Produces <amountToProduce> <GameTerm('ShapedCharge')> every <hoursToProduce> hours. Can craft Shaped Charges with the Craft Explosives operation in Sat View. "),
	'Icon', "UI/Icons/Perks/DesignerExplosives",
	'Tier', "Personal",
})

