DefineClass.ZuluPlayer = {
	__parents = { "CooldownObj", "LabelContainer" },
}

--- Creates a new ZuluPlayer object.
---
--- @return table A table containing a new ZuluPlayer object.
function CreatePlayerObjects()
	return {ZuluPlayer:new{handle = 1}}
end