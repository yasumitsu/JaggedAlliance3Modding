--[==[

DLC OS-specific files have the following structure:
 
DLC content is:
 |- autorun.lua
 |- revisions.lua
 |- Lua.hpk (if containing newer version of Lua, causes reload) 
 |- Data.hkp (if containing newer version of Data)
 |- Data/... (additional data)
 |- Maps/...
 |- Sounds.hpk
 |- EntityTextures.hpk (additional entity textures)
 |- ...

The Autorun returns a table with a description of the dlc:
return {
	name = "Colossus",
	display_name = T{"Colossus"}, -- optional, must be a T with an id if present
	pre_load = function() end,
	post_load = function() end,
	required_lua_revision = 12345, -- skip loading this DLC below this revision
}


DLC mount steps:

1. Enumerate and mount OS-specific DLC packs (validating them on steam/pc)
	-- result is a list of folders containing autorun.lua files
	
2. Execute autorun.lua and revisions.lua; autorun.lua should set g_AvailableDlc[dlc.name] = true
	
3. Check required_lua_revision and call dlc:pre_load() for each dlc that passes the check

4. If necessary reload localization, lua and data from the lasest packs (it can update the follow up Dlc load steps)

5. If necessary reload the latest Dlc assets
	-- reload entities
	-- reload BinAssets
	-- reload sounds
	-- reload music

6. Call the dlc:post_load() for each dlc
]==]
local function Boot()
	print("EpicEnabler is running")
	Platform.developer=true;
end

--rawset(_G, "SirNiDLC", SirNiDLC)

return {
  display_name = T(8565,"Sir Ni's test DLC"),
  enabled = true,
  name = "SirNiDLC",
  pops_dlc_id = "SirNiDLC",
  pre_load = function(self)
    Boot()
    dofile("Data/Script1.lua")
    dofile("Data/Script2.lua")
    dofile("Data/Script.lua")
    dofile("Data/AllShenanigans.lua")
  end,
  post_load = function(self)
    g_AvailableDlc[self.name] = true
  end,
  ps4_gid = 0,
  ps4_label = "nope",
  ps4_trophy_group_description = false,
  required_lua_revision = 227000,
  steam_dlc_id = 1234567
}
