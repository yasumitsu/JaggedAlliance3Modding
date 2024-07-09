DefineClass.GameEffect = {
	__parents = { "PropertyObject" },
	StoreAsTable = true,
	EditorName = false,
	Description = "",
	EditorView = Untranslated("<color 128 128 128><u(EditorName)></color> <Description> <color 75 105 198><u(comment)></color>"),
	properties = {
		{ category = "General", id = "comment", name = T(964541079092, "Comment"), default = "", editor = "text" },
	},
}

-- should be called early during the player setup; player structures not fully inited
--- Called when the effect needs to be initialized.
---
--- @param player Player The player the effect is being applied to.
--- @param parent GameEffectsContainer The container holding the effect.
function GameEffect:OnInitEffect(player, parent)
end

-- should be called when the effect needs to be applied
--- Called when the effect needs to be applied.
---
--- @param player Player The player the effect is being applied to.
--- @param parent GameEffectsContainer The container holding the effect.
function GameEffect:OnApplyEffect(player, parent)
end


----- GameEffectsContainer

DefineClass.GameEffectsContainer = {
	__parents = { "Container" },
	ContainerClass = "GameEffect",
}

-- should be called early during the player setup; player structures not fully inited
--- Called when the effect needs to be initialized.
---
--- @param player Player The player the effect is being applied to.
--- @param parent GameEffectsContainer The container holding the effect.
function GameEffectsContainer:EffectsInit(player)
	for _, effect in ipairs(self) do
		procall(effect.OnInitEffect, effect, player, self)
	end
end

-- should be called when the effect needs to be applied
--- Called when the effect needs to be applied.
---
--- @param player Player The player the effect is being applied to.
--- @param parent GameEffectsContainer The container holding the effect.
function GameEffectsContainer:EffectsApply(player)
	for _, effect in ipairs(self) do
		procall(effect.OnApplyEffect, effect, player, self)
	end
end

--- Gathers all the technologies granted by the effects in the GameEffectsContainer and adds them to the provided map.
---
--- @param map table A table to store the granted technologies.
function GameEffectsContainer:EffectsGatherTech(map)
	for _, effect in ipairs(self) do
		if IsKindOf(effect, "Effect_GrantTech") then
			map[effect.Research] = true
		end
	end
end

--- Returns the identifier for the GameEffectsContainer class.
---
--- @return string The identifier for the GameEffectsContainer class.
function GameEffectsContainer:GetEffectIdentifier()
	return "GameEffect"
end
