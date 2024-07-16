---@class CharacterEffect
---Represents a character effect in the game.
---@field components_cache boolean
---@field GetComponents fun(self: CharacterEffect): table
---@field ComponentClass table
---@field ObjectBaseClass table
---
---Defines extra definitions for the CharacterEffect class.
function __CharacterEffectExtraDefinitions()
end

---Called when classes are built.
---Calls the __CharacterEffectExtraDefinitions function.
function OnMsg.ClassesBuilt()
	__CharacterEffectExtraDefinitions()
end
-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========

---Defines extra definitions for the CharacterEffect class.
function __CharacterEffectExtraDefinitions()
	CharacterEffect.components_cache = false
	CharacterEffect.GetComponents = CharacterEffectCompositeDef.GetComponents
	CharacterEffect.ComponentClass = CharacterEffectCompositeDef.ComponentClass
	CharacterEffect.ObjectBaseClass = CharacterEffectCompositeDef.ObjectBaseClass

end

function OnMsg.ClassesBuilt() __CharacterEffectExtraDefinitions() end
