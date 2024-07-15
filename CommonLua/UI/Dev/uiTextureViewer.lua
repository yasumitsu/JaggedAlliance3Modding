---
--- Opens the texture viewer for the specified object and property.
---
--- @param root table The root object containing the texture property.
--- @param obj table The object containing the texture property.
--- @param prop string The name of the texture property.
--- @param ged table The GED object.
--- @param alpha_only boolean If true, only the alpha channel of the texture will be displayed.
--- @param in_game boolean If true, the texture viewer will be opened in-game.
---
--- If the Alt key is pressed, the file containing the texture will be located.
--- If the Ctrl key is pressed, the file containing the texture will be opened.
---
function OpenTextureViewer(root, obj, prop, ged, alpha_only, in_game)
	if terminal.IsKeyPressed(const.vkAlt) then
		OS_LocateFile(obj[prop] or "")
		return nil
	elseif terminal.IsKeyPressed(const.vkControl) then
		OS_OpenFile(obj[prop] or "")
		return nil
	end
	
	local game_path = obj[prop] or ""
	OpenGedApp("GedImageViewer", false, { file_name = game_path or "", show_alpha_only = alpha_only }, nil, in_game)
end

---
--- Opens the texture viewer for the specified object and property, displaying only the alpha channel.
---
--- @param editor table The root object containing the texture property.
--- @param obj table The object containing the texture property.
--- @param prop string The name of the texture property.
--- @param ged table The GED object.
---
function OpenTextureViewerAlpha(editor, obj, prop, ged)
	OpenTextureViewer(editor, obj, prop, ged, true)
end

---
--- Opens the texture viewer for the specified object and property, displaying the texture in-game.
---
--- @param editor table The root object containing the texture property.
--- @param obj table The object containing the texture property.
--- @param prop string The name of the texture property.
--- @param ged table The GED object.
---
function OpenTextureViewerIngame(editor, obj, prop, ged)
	OpenTextureViewer(editor, obj, prop, ged, false, true)
end