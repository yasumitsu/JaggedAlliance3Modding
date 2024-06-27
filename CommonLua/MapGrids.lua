----- Lua-defined saved in maps
--
-- To add a new grid that a part of the map data, call DefineMapGrid:
--  * the grid will be saved in the map folder if 'save_in_map' is true (otherwise, it gets recreated when the map changes)
--  * the OnMapGridChanged message is invoked when the grid is changed via the Map Editor

if FirstLoad then
	MapGridDefs = {}
end

---
--- Defines a new map grid that can be used to represent a part of the map data.
---
--- @param name string The name of the map grid.
--- @param bits number The number of bits used to represent the grid.
--- @param tile_size number The size of each tile in the grid.
--- @param patch_size number The size of each patch in the grid.
--- @param save_in_map boolean Whether the grid should be saved in the map folder.
---
--- When a new grid is defined, the `OnMapGridChanged` message is invoked when the grid is changed via the Map Editor.
function DefineMapGrid(name, bits, tile_size, patch_size, save_in_map)
	assert(type(bits) == "number" and type(tile_size) == "number" and tile_size >= 50*guic) -- just a reasonable tile size limit, feel free to lower
	MapGridDefs[name] = {
		bits = bits,
		tile_size = tile_size,
		patch_size = patch_size,
		save_in_map = save_in_map,
	}
end

---
--- Defines a new map hex grid that can be used to represent a part of the map data.
---
--- @param name string The name of the map hex grid.
--- @param bits number The number of bits used to represent the grid.
--- @param patch_size number The size of each patch in the grid.
--- @param save_in_map boolean Whether the grid should be saved in the map folder.
---
--- When a new hex grid is defined, the `OnMapGridChanged` message is invoked when the grid is changed via the Map Editor.
function DefineMapHexGrid(name, bits, patch_size, save_in_map)
	assert(const.HexWidth)
	MapGridDefs[name] = {
		bits = bits,
		tile_size = const.HexWidth,
		patch_size = patch_size,
		save_in_map = save_in_map,
		hex_grid = true,
	}
end


----- Utilities

---
--- Returns the tile size of the specified map grid.
---
--- @param name string The name of the map grid.
--- @return number The tile size of the map grid.
function MapGridTileSize(name)
	return MapGridDefs[name] and MapGridDefs[name].tile_size
end

---
--- Returns the size of the map grid in tiles.
---
--- @param name string The name of the map grid.
--- @param mapdata table The map data, if not provided the global `mapdata` will be used.
--- @return point The size of the map grid in tiles.
function MapGridSize(name, mapdata)
	-- can't use GetMapBox, the realm might not have been created yet
	mapdata = mapdata or _G.mapdata
	local map_size = point(mapdata.Width - 1, mapdata.Height - 1) * const.HeightTileSize
	
	local data = MapGridDefs[name]
	local tile_size = data.tile_size
	if data.hex_grid then
		local tile_x = tile_size
		local tile_y = MulDivRound(tile_size, const.HexGridVerticalSpacing, const.HexWidth)
		local width  = (map_size:x() + tile_x - 1) / tile_x
		local height = (map_size:y() + tile_y - 1) / tile_y
		return point(width, height)
	end
	return map_size / tile_size
end

---
--- Converts a world-space bounding box to a storage box for the specified map grid.
---
--- @param name string The name of the map grid.
--- @param bbox sizebox The world-space bounding box to convert.
--- @return sizebox The storage box for the specified map grid.
function MapGridWorldToStorageBox(name, bbox)
	if not bbox then
		return sizebox(point20, MapGridSize(name))
	end
	
	local data = MapGridDefs[name]
	if data.hex_grid then
		return HexWorldToStore(bbox)
	end
	return bbox / data.tile_size
end


---- Grid saving/loading with map

function OnMsg.MapFolderMounted(map, mapdata)
	for name, data in pairs(MapGridDefs) do
		if rawget(_G, name) then
			_G[name]:free()
		end
		
		local grid
		local filename = string.format("Maps/%s/%s", map, name:lower():gsub("grid", ".grid"))
		if data.save_in_map and io.exists(filename) then
			grid = GridReadFile(filename)
		else
			local width, height = MapGridSize(name, mapdata):xy()
			if data.patch_size then
				grid = NewHierarchicalGrid(width, height, data.patch_size, data.bits)
			else
				grid = NewGrid(width, height, data.bits)
			end
		end
		rawset(_G, name, grid)
	end
end

function OnMsg.SaveMap(folder)
	for name, data in pairs(MapGridDefs) do
		local filename = string.format("%s/%s", folder, name:lower():gsub("grid", ".grid"))
		if data.save_in_map and not _G[name]:equals(0) then
			GridWriteFile(_G[name], filename)
			SVNAddFile(filename)
		else
			SVNDeleteFile(filename)
		end
	end
end


----- Engine function overrides

if Platform.editor then

local old_GetGridNames = editor.GetGridNames
---
--- Returns a list of all map grid names defined in `MapGridDefs`.
---
--- This function overrides the original `editor.GetGridNames()` function to include
--- all grid names defined in `MapGridDefs`, in addition to the grids returned by
--- the original function.
---
--- @return table A table of all map grid names.
---
function editor.GetGridNames()
	local grids = old_GetGridNames()
	for name in sorted_pairs(MapGridDefs) do
		table.insert_unique(grids, name)
	end
	return grids
end

local old_GetGrid = editor.GetGrid
---
--- Returns a new grid instance with the contents of the specified grid, cropped to the given bounding box.
---
--- If the specified grid name is defined in `MapGridDefs`, the function will use the grid instance stored in the global table.
--- Otherwise, it will call the original `editor.GetGrid()` function.
---
--- @param name string The name of the grid to retrieve.
--- @param bbox table A bounding box in world coordinates.
--- @param source_grid table (optional) The source grid to copy from.
--- @param mask_grid table (optional) A mask grid to apply.
--- @param mask_grid_tile_size number (optional) The tile size of the mask grid.
--- @return table A new grid instance with the contents of the specified grid, cropped to the given bounding box.
---
function editor.GetGrid(name, bbox, source_grid, mask_grid, mask_grid_tile_size)
	local data = MapGridDefs[name]
	if data then
		local bxgrid = MapGridWorldToStorageBox(name, bbox)
		local new_grid = _G[name]:new_instance(bxgrid:sizex(), bxgrid:sizey())
		new_grid:copyrect(_G[name], bxgrid, point20)
		return new_grid
	end
	return old_GetGrid(name, bbox, source_grid, mask_grid, mask_grid_tile_size)
end

local old_SetGrid = editor.SetGrid
---
--- Sets the contents of the specified map grid.
---
--- If the specified grid name is defined in `MapGridDefs`, the function will copy the contents of the source grid to the specified grid, cropped to the given bounding box.
--- Otherwise, it will call the original `editor.SetGrid()` function.
---
--- @param name string The name of the grid to set.
--- @param source_grid table The source grid to copy from.
--- @param bbox table A bounding box in world coordinates.
--- @param mask_grid table (optional) A mask grid to apply.
--- @param mask_grid_tile_size number (optional) The tile size of the mask grid.
---
function editor.SetGrid(name, source_grid, bbox, mask_grid, mask_grid_tile_size)
	local data = MapGridDefs[name]
	if data then
		local bxgrid = MapGridWorldToStorageBox(name, bbox)
		_G[name]:copyrect(source_grid, bxgrid - bxgrid:min(), bxgrid:min())
		DbgInvalidateTerrainOverlay(bbox)
		Msg("OnMapGridChanged", name, bbox)
		return
	end
	old_SetGrid(name, source_grid, bbox, mask_grid, mask_grid_tile_size)
end

local old_GetGridDifferenceBoxes = editor.GetGridDifferenceBoxes
---
--- Returns a list of bounding boxes that represent the differences between two grids.
---
--- If the specified grid name is defined in `MapGridDefs`, the function will use the tile size from the grid definition.
--- Otherwise, it will call the original `editor.GetGridDifferenceBoxes()` function.
---
--- @param name string The name of the grid.
--- @param grid1 table The first grid to compare.
--- @param grid2 table The second grid to compare.
--- @param bbox table (optional) The bounding box to consider.
--- @return table A list of bounding boxes that represent the differences between the two grids.
---
function editor.GetGridDifferenceBoxes(name, grid1, grid2, bbox)
	local data = MapGridDefs[name]
	return old_GetGridDifferenceBoxes(name, grid1, grid2, bbox or empty_box, data and data.tile_size or 0)
end

end -- Platform.editor
