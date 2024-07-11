MapVar("Players", false)
MapVar("UIPlayer", false)


----- Player

DefineClass.Player = {
	__parents = { "CooldownObj", "LabelContainer" },
	player = false,
}

--- Initializes the `player` property of the `Player` class to point to the current instance.
-- This sets up the `player` property so that it refers to the current `Player` object.
-- This is likely done to provide a convenient way to access the current player object from within the `Player` class.
function Player:Init()
	self.player = self
end


----- PlayerObject

DefineClass.PlayerObject = {
	__parents = { "Object" },
	properties = {
		{ id = "player", editor = "object", default = false, read_only = true, },
	},
}

--- Clears the `player` property of the `PlayerObject` instance.
-- This function is likely called when the `PlayerObject` is no longer needed, to release the reference to the `Player` object it was associated with.
function PlayerObject:Done()
	self.player = nil
end

--- Sets the `player` property of the `PlayerObject` instance to the `UIPlayer` if the editor is active.
-- This function is likely called after the `PlayerObject` has been loaded, to ensure that the `player` property is properly set.
-- If the editor is active, this function will set the `player` property to the `UIPlayer` object, which is likely the currently active player in the editor.
-- This is likely done to ensure that the `PlayerObject` has a valid reference to the current player, which can be useful for various editor-related functionality.
function PlayerObject:PostLoad()
	if IsEditorActive() then
		self.player = UIPlayer
	end
end


-----

---
--- Creates a new `Player` object and returns it in a table.
---
--- @return table A table containing a single `Player` object with a handle of 1.
function CreatePlayerObjects()
	return { Player:new{ handle = 1 } }
end

function OnMsg.NewMap()
	if not mapdata.GameLogic then return end
	SetPlayers(CreatePlayerObjects())
end

---
--- Sets the global `Players` and `UIPlayer` variables based on the provided `players` and `ui_player` arguments.
---
--- @param players table|nil An optional table of `Player` objects to set as the global `Players` variable.
--- @param ui_player Player|nil An optional `Player` object to set as the global `UIPlayer` variable.
---
function SetPlayers(players, ui_player)
	Players = players or {}
	UIPlayer = ui_player or players and players[1] or false
	for _, player in ipairs(players) do
		Msg("PlayerObjectCreated", player)
	end
end