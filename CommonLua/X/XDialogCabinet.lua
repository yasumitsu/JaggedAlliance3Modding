DefineClass.XCabinetBase =
{
	__parents = {"XDialog"},
	
	properties = {
		{ category = "Scene", id = "HideDialogs", name = "Hide Dialogs", editor = "bool", default = true },
		{ category = "Scene", id = "LeaveDialogsOpen", editor = "string_list", default = {}, items = ListAllDialogs, arbitrary_value = true, },
		{ category = "Scene", id = "InitialDialogMode", name = "Initial Dialog Mode", editor = "text", default = false },
		{ category = "Scene", id = "Lightmodel", name = "Lightmodel", editor = "combo", items = LightmodelsCombo, default = false },
		{ category = "Scene", id = "SetupScene", name = "Setup Scene", editor = "func", params = "self", default = function() end },
		{ category = "Scene", id = "RestorePrevScene", name = "Restore Prev Scene", editor = "func", params = "self", default = function() end },
	},
	
	hidden_meshes = false,
	fadeinout = true,
	restore_light_model = false,
	lightmodel_cubemaps = false,
}

---
--- Initializes the XCabinetBase class.
--- If the `fadeinout` property is true, creates a new `XDialog` object with the following properties:
---   - Id: "idFade"
---   - ZOrder: 1000
---   - Visible: false
---   - Background: RGBA(0, 0, 0, 255)
---   - FadeInTime: 300
---   - FadeOutTime: 300
---   - RolloverZoomInTime: 1000
---   - RolloverZoomOutTime: 1000
---
function XCabinetBase:Init()
	if self.fadeinout then
		XDialog:new({
			Id = "idFade",
			ZOrder = 1000,
			Visible = false,
			Background = RGBA(0, 0, 0, 255),
			FadeInTime = 300,
			FadeOutTime = 300,
			RolloverZoomInTime = 1000,
			RolloverZoomOutTime = 1000,
		}, self)
	end
end

---
--- Handles the transition between the open and close states of the XCabinetBase dialog.
---
--- When the dialog is opened, this function:
--- - Sets the visibility of the "idFade" dialog to true
--- - Disables rollover functionality
--- - Waits for the FadeInTime of the "idFade" dialog to elapse
--- - Waits for the next frame
---
--- When the dialog is closed, this function:
--- - Sets the visibility of the "idFade" dialog to true
--- - Waits for the FadeInTime of the "idFade" dialog to elapse
--- - Deletes all child dialogs except for the "idFade" dialog
--- - Waits for the FadeOutTime of the "idFade" dialog to elapse
---
--- @param opening string The state the dialog is transitioning to ("open" or "close")
--- @param inout string The stage of the transition ("begin" or "end")
---
function XCabinetBase:Transition(opening, inout)
	if opening == "open" and inout == "begin" then
		self.idFade:SetVisible(true)
		SetRolloverEnabled(false)
		Sleep(self.idFade.FadeInTime)
		WaitNextFrame(5)
	elseif opening == "open" and inout == "end" then
		self.idFade:SetVisible(false)
		SetRolloverEnabled(true)
	elseif opening == "close" and inout == "begin" then
		self.idFade:SetVisible(true)
		Sleep(self.idFade.FadeInTime)
		WaitNextFrame(5)
	elseif opening == "close" and inout == "end" then
		self.idFade:SetVisible(false)
		-- delete all children except for idFade
		for i = #self, 1, -1 do
			if self[i].Id ~= "idFade" then
				self[i]:delete()
			end
		end
		Sleep(self.idFade.FadeOutTime)
	end
end


---
--- Handles the routine logic for the XCabinetBase dialog.
---
--- This function is called after the dialog has been opened and the scene has been set up. It can be used to implement any additional logic or behavior for the cabinet dialog.
---
--- @param self XCabinetBase The instance of the XCabinetBase dialog.
---
function XCabinetBase:CabinetRoutine()

end

---
--- Opens the XCabinetBase dialog and sets up the scene.
---
--- This function is called to open the XCabinetBase dialog. It performs the following steps:
--- - Calls XDialog.Open to open the dialog
--- - Creates a new thread to set up the scene
--- - Transitions the dialog to the "open" state
--- - Overrides the wind and light model if the Lightmodel property is set
--- - Hides all visible meshes on the map and stores them in the hidden_meshes table
--- - Calls SetupScene to set up the scene
--- - Sets the initial dialog mode if the InitialDialogMode property is set
--- - Transitions the dialog to the "open" end state
--- - Calls CabinetRoutine to handle any additional logic for the cabinet dialog
---
--- @param self XCabinetBase The instance of the XCabinetBase dialog.
--- @param ... Any additional arguments passed to the Open function.
---
function XCabinetBase:Open(...)
	XDialog.Open(self, ...)
	
	self:CreateThread("SetupScene", function()
		self:Transition("open", "begin")

		if self.Lightmodel then
			 -- We need to override the wind that is to come with the current wind, as it is sync.
			WindOverride = CurrentWindAnimProps()
			
			if LightmodelOverride then
				self.restore_light_model = LightmodelOverride
			end
			self.lightmodel_cubemaps = PreloadLightmodelCubemaps(self.Lightmodel)
			SetLightmodelOverride(1, self.Lightmodel)
		end
		if self.HideDialogs then
			XHideDialogs:new({Id = "idHideDialogs", LeaveDialogIds = self.LeaveDialogsOpen}, self):Open()
		end
		-- Hide everything on the map
		self.hidden_meshes = {}
		MapForEach("map", "Mesh", function(o) 
			if o:GetEnumFlags(const.efVisible) ~= 0 then
				self.hidden_meshes[#self.hidden_meshes + 1] = o
				o:ClearEnumFlags(const.efVisible)
			end
		end)
		self:SetupScene()
		if self.InitialDialogMode then
			self:SetMode(self.InitialDialogMode)
		end
		self:Transition("open", "end")
		self:CabinetRoutine()
	end)
end

---
--- Closes the XCabinetBase dialog.
---
--- If `force` is true, the dialog is immediately closed without any transitions or cleanup.
--- Otherwise, the dialog is transitioned to the "close" state, the previous scene is restored,
--- any hidden dialogs are deleted, and the dialog is finally closed.
---
--- @param self XCabinetBase The instance of the XCabinetBase dialog.
--- @param force boolean (optional) If true, the dialog is immediately closed without any transitions or cleanup.
---
function XCabinetBase:Close(...)
	local force = ...
	if force then
		self:OnCloseAfterBlackFadeIn()
		self:OnCloseAfterBlackFadeOut()
		XDialog.Close(self)
		return
	end
	self:CreateThread("SetupScene", function()
		self:Transition("close", "begin")
		self:OnCloseAfterBlackFadeIn()
		if self:HasMember("idHideDialogs") and self.idHideDialogs.window_state ~= "destroying" then
			self.idHideDialogs:delete()
		end
		self:Transition("close", "end")
		self:OnCloseAfterBlackFadeOut()
		XDialog.Close(self)
	end)
end

---
--- Restores the previous scene and light model after the XCabinetBase dialog is closed.
---
--- This function is called after the black fade-out transition when the dialog is closed.
--- It restores the previous scene by calling `self:RestorePrevScene()`, and if a light model
--- was used, it cleans up the cubemaps and restores the original light model.
---
--- @param self XCabinetBase The instance of the XCabinetBase dialog.
---
function XCabinetBase:OnCloseAfterBlackFadeIn()
	self:RestorePrevScene()
	if self.Lightmodel then
		if self.lightmodel_cubemaps then
			self.lightmodel_cubemaps:Done()
			self.lightmodel_cubemaps = false
		end
		SetLightmodelOverride(1, self.restore_light_model)
		WindOverride = false
	end
end

---
--- Restores any hidden meshes after the XCabinetBase dialog is closed and the black fade-out transition is complete.
---
--- This function is called after the black fade-out transition when the dialog is closed. It iterates through the `hidden_meshes` table and sets the visibility flag on each mesh to make them visible again.
---
--- @param self XCabinetBase The instance of the XCabinetBase dialog.
---
function XCabinetBase:OnCloseAfterBlackFadeOut()
	if not self.hidden_meshes then return end
	
	-- Restore hidden meshes
	for _, mesh in ipairs(self.hidden_meshes) do
		if IsValid(mesh) then
			mesh:SetEnumFlags(const.efVisible)
		end
	end
end