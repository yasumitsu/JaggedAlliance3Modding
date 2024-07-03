----- Height editing - terrain & grid invalidation logic

if FirstLoad then
	EditorHeightDirtyBox = false
end

function OnMsg.EditorHeightChanged(final, bbox)
	if bbox then
		EditorHeightDirtyBox = AddRects(EditorHeightDirtyBox or bbox, bbox)
	end
	
	terrain.InvalidateHeight(bbox)
	editor.UpdateObjectsZ(bbox)
	if final then
		ApplyAllWaterObjects(bbox)
		if EditorHeightDirtyBox then
			DelayedCall(1250, XEditorRebuildGrids)
		end
		Msg("EditorHeightChangedFinal", EditorHeightDirtyBox)
	end
end

--- Rebuilds the editor grids after the terrain height has been changed.
---
--- This function is called after the terrain height has been changed, and it
--- rebuilds the editor grids to reflect the new terrain height. It also resets
--- the `EditorHeightDirtyBox` flag to indicate that the grids have been
--- rebuilt.
---
--- @param EditorHeightDirtyBox table The bounding box of the terrain that was
---                             changed, which is used to determine the area
---                             that needs to be rebuilt.
function XEditorRebuildGrids()
	RebuildGrids(EditorHeightDirtyBox)
	EditorHeightDirtyBox = false
end