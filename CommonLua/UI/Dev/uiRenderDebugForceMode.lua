DefineClass.DevDSForceModeDlg = {
	__parents = { "XDialog" },
}

if FirstLoad then
	DebugForceModeIdx = {
		gbuffers = 0,
		stencil = 0,
		misc = 0,
		lights = 0,
	}
end

local DebugForceModeList = {
	["gbuffers"]     = { "NORMAL", "GEOMETRY_NORMAL", "BASECOLOR", "COLORMAP", "ROUGHNESS", "METALLIC", "AO",  "SI", "TANGENT", "ENCODED_NORMAL", "DEPTH", "NONE"},

	["stencil"]      = { "STENCIL", "NONE" },
	
	["misc"]         = { "BRDF", "ENV_IRRAD","ENV_DIFFUSE", "SUN_DIFFUSE", "DIFFUSE",
	                     "ENV_SPECULAR","SUN_SPECULAR", "SPECULAR", "SUN_SHADOW", 
	                     "TRANSLUCENCY", "REFLECTION", "REFLECTION_ITERATIONS", "PRECISE_SELECTION_IDS", "NONE"},

	["lights"]       = { "LIGHTS", "LIGHTS_DIFFUSE", "LIGHTS_SPECULAR", "LIGHTS_SHADOW",
	                     "LIGHTS_COUNT", "LIGHTS_ATTENUATION", "LIGHTS_CLUSTER", "NONE"}
}

local DebugForceModeRemap = {
	["COLORMAP"] = "BASECOLOR",
	["TANGENT"] = "NORMAL",
}

local DebugForceModeHROptions =
{
	["STENCIL"]  = { ShowStencil = 2, ShowRT = "show_rt_buffer", ShowRTEnable = 1, },
	["COLORMAP"] = { ForceColorizationRGB = 1, DisableBaseColorMaps = 1, RenderClutter = 0, },
	["TANGENT"] = { UseTangentNormalMap = 1 },
	["REFLECTION"] = { EnableScreenSpaceReflections = 1, RenderClutter = 0, SSRDebug = 1 },
	["REFLECTION_ITERATIONS"] = { EnableScreenSpaceReflections = 1, RenderClutter = 0, SSRDebug = 2 },
	["PRECISE_SELECTION_IDS"] = { ShowPreciseSelectionIDs = 1, RenderTransparent = 1 },
}

---
--- Initializes the `DevDSForceModeDlg` class.
--- This function is called when the `DevDSForceModeDlg` class is created.
--- It creates a new `XText` object and sets its properties, including the text to be displayed.
---
--- @param self table The `DevDSForceModeDlg` instance.
---
function DevDSForceModeDlg:Init()
	XText:new({
		Id = "idText",
		Margins = box(100, 80, 0, 0),
		TextStyle= "GizmoText",
		HandleMouse = false,
	}, self)
	self.idText:SetText(self.context.text or "")
end

---
--- Restores the "ForceModeSpecific" and "ForceMode" properties in the `hr` table, and then recreates the render objects.
--- This function is called when the "DevDSForceModeDlg" dialog is closed.
---
function DevDSForceModeDlg:Done()
	table.restore(hr, "ForceModeSpecific")
	table.restore(hr, "ForceMode")
	RecreateRenderObjects()
end

---
--- Opens the "DevDSForceModeDlg" dialog and sets the "ForceMode" and "ForceModeSpecific" properties in the "hr" table based on the provided mode.
---
--- @param mode string The mode to set in the "ForceMode" and "ForceModeSpecific" properties.
---
function OpenDevDSForceModeDlg(mode)
	CloseDialog("DevDSForceModeDlg")
	table.change(hr, "ForceMode", { 
		EnablePostprocess = 0,
		EnableScreenSpaceReflections = 0,
		EnableSubsurfaceScattering = 0,
		RenderTransparent = 0,
		RenderParticles = 0,
		ShowStencil = 0,
		ShowRT = "",
		ShowRTEnable = 0,
		DeferMode = DeferModes[DebugForceModeRemap[mode] or mode],
	})
	table.change(hr, "ForceModeSpecific", DebugForceModeHROptions[mode] or {})
	RecreateRenderObjects()
	OpenDialog("DevDSForceModeDlg", terminal.desktop, { text = mode })
end

---
--- Toggles the debug force mode for the specified debug type.
---
--- If `debug_type` is `nil`, the "DevDSForceModeDlg" dialog is closed and the function returns.
---
--- Otherwise, the function retrieves the list of debug modes for the specified `debug_type` from the `DebugForceModeList` table. It then calculates the index of the next mode to be used, based on the current index stored in the `DebugForceModeIdx` table. If the dialog is already open, the index is incremented by 1.
---
--- If the calculated index is not the last index in the list of modes, the function opens the "DevDSForceModeDlg" dialog and passes the corresponding mode to the `OpenDevDSForceModeDlg` function.
---
--- If the calculated index is the last index in the list of modes, the function closes the "DevDSForceModeDlg" dialog.
---
--- Finally, the function calls `PP_Rebuild()` and `RecreateRenderObjects()` to update the rendering.
---
--- @param debug_type string The type of debug mode to toggle.
---
function ToggleDebugForceMode(debug_type)
	if not debug_type then
		CloseDialog("DevDSForceModeDlg")
		return
	end
	local modes = DebugForceModeList[debug_type]
	local index = (DebugForceModeIdx[debug_type] % #modes) + (GetDialog("DevDSForceModeDlg") and 1 or 0)
	DebugForceModeIdx[debug_type] = index
	if index ~= #modes then
		OpenDevDSForceModeDlg(modes[index])
	else
		CloseDialog("DevDSForceModeDlg")
	end
	PP_Rebuild()
	RecreateRenderObjects()
end

if FirstLoad then
	g_PostProcDebugMode = "Off"
end

local PostProcDebugModesIdxs = {
	HsvDebug = 0,
}

local PostProcDebugModes = {
	HsvDebug = { names = {   			"Hue", 		"Saturation", 			"Lightness", 			"Lighness_WO_Shadows", 												"Off" },
					hr_vars = { 			{},			{},						{},			 			{ Shadowmap = 0, EnableScreenSpaceAmbientObscurance = 0 },	{} },
					debug_passes = { 	"debug_hue",	"debug_saturation",	"debug_lightness", 	"debug_lightness",														"Off" },
	}
}

DefineClass.PostProcDebugFeatureDlg = {
	__parents = { "XDialog" },
}

--- Initializes the `PostProcDebugFeatureDlg` dialog.
---
--- This function creates a new `XText` object with the ID "idText" and sets its text to the `text` field of the dialog's context. The text is styled using the "EditorText" text style, and the mouse handling is disabled.
---
--- @param self PostProcDebugFeatureDlg The dialog instance.
function PostProcDebugFeatureDlg:Init()
	XText:new({
		Id = "idText",
		Margins = box(20, 90, 0, 0),
		TextStyle= "EditorText",
		HandleMouse = false,
	}, self)
	self.idText:SetText(self.context.text or "")
end

--- Restores the `PostProcForceMode` table in the `hr` table to its original state.
---
--- This function is called when the `PostProcDebugFeatureDlg` dialog is closed. It restores the `PostProcForceMode` table in the `hr` table to its original state, effectively disabling any post-processing debug modes that were enabled.
function PostProcDebugFeatureDlg:Done()
	table.restore(hr, "PostProcForceMode")
end

--- Opens the `PostProcDebugFeatureDlg` dialog with the specified post-processing debug mode and index.
---
--- This function is responsible for setting up the `PostProcForceMode` table in the `hr` table with the appropriate options for the selected post-processing debug mode and index. It then opens the `PostProcDebugFeatureDlg` dialog, passing the name of the selected mode as the `text` field of the dialog's context.
---
--- @param mode string The name of the post-processing debug mode to be displayed in the dialog.
--- @param idx number The index of the selected post-processing debug mode within the `PostProcDebugModes[mode].debug_passes` table.
function OpenPostProcDebugFeatureDlg(mode, idx)
	CloseDialog("PostProcDebugFeatureDlg")
	
	local hr_options = {}
	for op, value in pairs(PostProcDebugModes[mode].hr_vars[idx]) do
		hr_options[op] = value
	end
	table.change(hr, "PostProcForceMode", hr_options)
	
	OpenDialog("PostProcDebugFeatureDlg", terminal.desktop, { text = PostProcDebugModes[mode].names[idx] })
end

--- Toggles the HSV debug force mode.
---
--- This function is responsible for cycling through the different post-processing debug modes and opening the `PostProcDebugFeatureDlg` dialog to display the selected mode. It updates the `PostProcDebugModesIdxs` table to keep track of the current index for each mode, and sets the `g_PostProcDebugMode` global variable to the appropriate debug pass. Finally, it calls `PP_Rebuild()` to update the post-processing effects.
---
--- @param mode string The name of the post-processing debug mode to toggle.
function ToggleHsvDebugForceMode(mode)
	local num_modes = #PostProcDebugModes[mode].debug_passes
	local idx = (PostProcDebugModesIdxs[mode] % num_modes) + 1
	PostProcDebugModesIdxs[mode] = idx
	
	if idx ~= num_modes then
		OpenPostProcDebugFeatureDlg(mode, idx)
	else
		CloseDialog("PostProcDebugFeatureDlg")
	end
	
	g_PostProcDebugMode = PostProcDebugModes[mode].debug_passes[idx]
	PP_Rebuild()
end