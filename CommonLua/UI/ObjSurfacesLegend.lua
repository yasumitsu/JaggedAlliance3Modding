DefineClass.ObjSurfacesLegend = {
	__parents = {"XDialog"},
	
	Padding = box(0, 0, 10, 60),
	Dock = "box",
	ZOrder = 100,
	HAlign = "right",
	VAlign = "bottom",
	UseClipBox = false,
	HandleMouse = true,
}

---
--- Initializes the ObjSurfacesLegend UI element, which displays a legend for the object surfaces in the game.
---
--- The legend consists of a list of checkboxes, one for each type of object surface. Checking or unchecking a checkbox will enable or disable the corresponding object surface.
---
--- The legend also includes a "Close" button that will hide all object surfaces.
---
--- @param self ObjSurfacesLegend The ObjSurfacesLegend instance.
function ObjSurfacesLegend:Init()
	local parent = XWindow:new({
		LayoutMethod = "VList",
		UniformRowHeight = true,
		Background = const.clrBlack,
	}, self)
	
	for stype, color in sorted_pairs(ObjectSurfaceColors) do
		if color ~= RGBA(0, 0, 0, 0) then
			local background = XWindow:new({
				Margins = box(5, 5, 5, 5),
				HAlign = "left",
				VAlign = "center",
				LayoutMethod = "HList",
				MinWidth = 200,
				MinHeight = 30,
				MaxWidth = 200,
				MaxHeight = 30,
				Background = color,
				Clip = false,
			}, parent)
			local button = XCheckButton:new({
				OnChange = function(button, checked)
					SetObjSurfaceDisabled(stype, not checked)
				end,
			}, background)
			button:SetCheck(not TurnedOffObjSurfaces[stype])
			local text = XText:new({
				Margins = box(5, 0, 5, 0),
				HAlign = "left",
				VAlign = "center",
				MinWidth = 50,
				MaxHeight = 30,
				TextVAlign = "center",
				TextStyle = "GedDefaultDarkModeOutline",
				Clip = false,
			}, background)
			text:SetText(stype)
		end
	end
	
	local close_button = XTextButton:new({
		Margins = box(5, 0, 5, 0),
		HAlign = "center",
		VAlign = "center",
		MinWidth = 50,
		MaxHeight = 30,
		TextVAlign = "center",
		TextStyle = "GedDefault",
		OnPress = function(button)
			for obj in pairs(ObjToShownSurfaces) do
				obj:HideSurfaces()
			end
		end,
	}, parent)
	close_button:SetText("Close")
end

---
--- Disables or enables the display of a specific object surface type.
---
--- @param stype string The type of object surface to enable or disable.
--- @param disabled boolean Whether to disable the object surface (true) or enable it (false).
function SetObjSurfaceDisabled(stype, disabled)
	TurnedOffObjSurfaces[stype] = disabled or nil
	for obj, entry in pairs(ObjToShownSurfaces) do
		if disabled then
			if type(entry) == "table" then
				DoneObject(entry[stype])
				entry[stype] = nil
			end
		else
			obj:ShowSurfaces()
		end
	end
end