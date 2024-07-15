local UIL = UIL

DefineClass.XFxModifier = {
	__parents = { "InitDone" },

	properties = {
		{ category = "FX", id = "UIEffectModifierId", default = "", editor = "preset_id", preset_class = "UIFxModifierPreset", },
		{ category = "FX", id = "UIFXInternalModifierId", default = "", editor = "preset_id", preset_class = "UIFxModifierPreset", help = "Keeps internal state. ", dont_save = true, no_edit = true, },
	},
	effect_shader_modifier = false,
	effect_shader_params = false,
}

--- Initializes the XFxModifier instance.
--
-- If the `UIEffectModifierId` property is set, this function sets the UI effect modifier ID for the instance.
function XFxModifier:Init()
	if self.UIEffectModifierId and self.UIEffectModifierId ~= "" then
		self:SetUIEffectModifierId(self.UIEffectModifierId)
	end
end

---
--- Updates a shader effect modifier with the specified parameters.
---
--- @param fx_id string The ID of the UI effect modifier preset.
--- @param modifier table The modifier table to update.
--- @param params table Optional table of parameters to override the preset properties.
--- @return table The updated modifier table.
---
function XUpdateShaderEffectModifier(fx_id, modifier, params)
	local mod_data = UIFxModifierPresets[fx_id]
	if not mod_data then return end

	modifier = modifier or {}
	modifier.modifier_type = const.modShader
	modifier.shader_flags = mod_data.shader_flags
	local getter = false
	if params and next(params) then
		getter = function(mod_data, prop_id)
			local param_value = params[prop_id]
			if param_value then
				return param_value
			end
			return mod_data:GetProperty(prop_id)
		end
	end
	modifier.payload = mod_data:ComposeBuffer(modifier.payload, getter)

	return modifier
end

local XUpdateShaderEffectModifier = XUpdateShaderEffectModifier
local ModifiersSetTop = UIL.ModifiersSetTop
local ModifiersGetTop = UIL.ModifiersGetTop
local PushModifier = UIL.PushModifier


---
--- Pushes a shader effect modifier onto the UI modifier stack.
---
--- @param fx_id string The ID of the UI effect modifier preset.
--- @param modifier table The modifier table to push.
--- @param params table Optional table of parameters to override the preset properties.
--- @return integer, table The position of the modifier on the stack, and the updated modifier table.
---
function XPushShaderEffectModifier(fx_id, modifier, params)
	local mod_data = UIFxModifierPresets[fx_id]
	if not mod_data then return end

	local pos = ModifiersGetTop()
	modifier = XUpdateShaderEffectModifier(fx_id, modifier, params)

	PushModifier(modifier)
	return pos, modifier
end

--- Updates the UI effect modifiers for the FxModifier.
---
--- If the `effect_shader_modifier` is set, it is removed from the modifier stack.
---
--- If the `UIFXInternalModifierId` is set, the corresponding modifier preset is retrieved and updated using `XUpdateShaderEffectModifier`. The updated modifier is then added to the modifier stack using `AddShaderModifier`.
---
--- @self XFxModifier The FxModifier instance.
function XFxModifier:UpdateUIEffectModifiers()
	if self.effect_shader_modifier then
		self:RemoveModifier(self.effect_shader_modifier)
	end
	if self.UIFXInternalModifierId and self.UIFXInternalModifierId ~= "" then
		local mod_data = UIFxModifierPresets[self.UIFXInternalModifierId]
		if not mod_data then return end
		
		local modifier = XUpdateShaderEffectModifier(self.UIFXInternalModifierId, self.effect_shader_modifier, self.effect_shader_params)
		self.effect_shader_modifier = self:AddShaderModifier(modifier)
	end
end

---
--- Sets the UI effect modifier ID for the FxModifier instance.
---
--- This function handles the transition between different UI effect modifiers. It updates the `UIEffectModifierId` and `UIFXInternalModifierId` properties, and creates a thread to manage the fade-in and fade-out of the effect.
---
--- If the current and target effect modifiers are different, the function will:
--- - Save the current shader parameters
--- - Delete the "UIFX" thread
--- - Create a new "UIFX" thread to handle the transition
---   - If there is a current effect, it will fade it out
---   - It will then wait for the fade-in delay of the target effect
---   - It will set the fade-in start time for the target effect
---   - It will update the effect modifiers
---   - It will wait for the fade-in duration of the target effect
---   - If the target effect has a duration, it will wait for that duration and then fade out the effect
---   - Finally, it will reset the effect modifiers
---
--- @param id string The ID of the UI effect modifier preset to set.
---
function XFxModifier:SetUIEffectModifierId(id)
	local current_fx_id = self.UIEffectModifierId or self.UIFXInternalModifierId
	local target_fx = UIFxModifierPresets[id]
	local current_fx = UIFxModifierPresets[current_fx_id]
	self.UIEffectModifierId = id

	if current_fx ~= target_fx then
		local shader_params = self.effect_shader_params or {}
		self.effect_shader_params = shader_params

		self:DeleteThread("UIFX")
		self:CreateThread("UIFX", function()
			if current_fx then
				shader_params.UIFXFadeInStartTime = 0
				shader_params.UIFXFadeOutStartTime = RealTime()
				self.UIFXInternalModifierId = current_fx_id
				self:UpdateUIEffectModifiers()
				Sleep(current_fx.FadeOut)
			end
			self.UIFXInternalModifierId = false
			self:UpdateUIEffectModifiers()
			if target_fx then
				Sleep(target_fx.FadeInDelay)
				shader_params.UIFXFadeInStartTime = RealTime()
				shader_params.UIFXFadeOutStartTime = 0
				self.UIFXInternalModifierId = id
				self:UpdateUIEffectModifiers()
				Sleep(target_fx.FadeIn)
				if target_fx.Duration > 0 then
					Sleep(target_fx.Duration)
					if self.UIEffectModifierId == id then
						self.UIEffectModifierId = false

						shader_params.UIFXFadeInStartTime = 0
						shader_params.UIFXFadeOutStartTime = RealTime()
						self:UpdateUIEffectModifiers()
						Sleep(target_fx.FadeOut)

						self.UIFXInternalModifierId = false
						self:UpdateUIEffectModifiers()
					end
				end
			end
		end)
	end

	self:UpdateUIEffectModifiers()
end

DefineClass.UIFxModifierPreset = {
	__parents = { "Preset", "MeshParamSet" },

	properties = {
		{id = "Duration", editor = "number", min = 0, default = 0, scale = 1000, },
		{id = "FadeInDelay", editor = "number", min = 0, default = 0, scale = 1000, },
		{uniform = true, id = "FadeIn", editor = "number", min = 0, default = 0, scale = 1000, help = "Depends on per-feature implementation."},
		{uniform = true, id = "FadeOut", editor = "number", min = 0, default = 0, scale = 1000, help = "Depends on per-feature implementation."},
		{uniform = true, id = "UIFXFadeInStartTime", editor = "number", min = 0, default = 0, no_edit = true, dont_save = true, },
		{uniform = true, id = "UIFXFadeOutStartTime", editor = "number", min = 0, default = 0, no_edit = true, dont_save = true, },
	},
	GlobalMap = "UIFxModifierPresets",
	EditorMenubar = "Editors.Art",
	PresetClass = "UIFxModifierPreset",
}


---
--- Callback function that is called when a property of the `UIFxModifierPreset` class is edited in the editor.
--- This function updates the UI effect modifiers for all `XFxModifier` windows that are using the current preset,
--- and invalidates the UI to force a redraw.
---
--- @param self UIFxModifierPreset The preset object that had a property edited.
--- @param ... any Additional arguments passed to the callback.
---
function UIFxModifierPreset:OnEditorSetProperty(...)
	CreateRealTimeThread( function()
		local container_list = GetChildrenOfKind(terminal.desktop, "XFxModifier")
		for _, mod_window in ipairs(container_list) do
			if mod_window.UIEffectModifierId == self.id then
				mod_window:UpdateUIEffectModifiers()
				mod_window:Invalidate()
			end
		end
		UIL.Invalidate()
	end)
	Preset.OnEditorSetProperty(self, ...)
end

---
--- Creates a new UI window with a splash screen image.
---
--- This function creates a new `XWindow` with a docked layout at the top of the screen.
--- The window has a minimum size of 100x100 pixels and a maximum size of 500x500 pixels.
--- An `XImage` is added to the window, displaying the "UI/SplashScreen" image, centered both horizontally and vertically.
---
--- @function TestUIFxModifiers
--- @return none
function TestUIFxModifiers()
	local wrapper = XWindow:new({
		Dock = "top",
		MinWidth = 100,
		MinHeight = 100,
		MaxWidth = 500,
		MaxHeight = 500,
		UIEffectModifierId = "Default",
	}, terminal.desktop)
	XImage:new({
		Image = "UI/SplashScreen", HAlign = "center", VAlign = "center",
	}, wrapper)
end

DefineClass.UIFxModifierDefault = {
	__parents = { "UIFxModifierPreset" },

	shader_flags = const.msfUIEnableFX,
	properties = {
		{ uniform = true, category = "FX", id = "InterlacedStrength", editor = "number", scale = 1000, default = 0, min = 0, max = 1000, slider=true, },
		{ uniform = true, category = "FX", id = "AberrationShift", editor = "number", scale = 1000, default = 0, min = 0, max = 1000, slider=true, },
		{ uniform = true, category = "FX", id = "AberrationStrength", editor = "number", scale = 1000, default = 0, min = 0, max = 1000, slider=true, },
		
		{ uniform = true, category = "FX", id = "GrainStrength", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "Desaturate", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },

		{ uniform = true, category = "FX", id = "GroundLoopStrength", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "GroundLoopShift", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "GroundLoopFreq", editor = "number", scale = 255, default = 0, min = -255, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "GroundLoopScale", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },

		{ uniform = true, category = "FX", id = "DVDropoutStrength", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "DVDropoutTileSize", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },
		{ uniform = true, category = "FX", id = "DVDropoutTimeWindow", editor = "number", scale = 255, default = 0, min = 0, max = 255, slider=true, },

		{ uniform = true, category = "FX", id = "BaseColor", editor = "color", default = RGB(255,255,255), },
		{ uniform = true, category = "FX", id = "LodBias", name = "LodBias (Blur)", editor = "number", scale = 1000, default = 0, min = -10000, max = 10000, slider=true, },
		{ uniform = true, category = "FX", id = "Pad01", no_edit = true, editor = "number", default = 0, },
		{ uniform = true, category = "FX", id = "Pad02", no_edit = true, editor = "number", default = 0, },
	},
}

DefineClass.UIFxFadeoutBox = {
	__parents = { "UIFxModifierPreset" },

	shader_flags = const.msfFadeoutBoxFX,
	properties = {
		{ uniform = true, category = "FX", id = "BoxMinX", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "BoxMinY", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "BoxMaxX", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "BoxMaxY", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "FadeDistance", editor = "number", scale = 1000, default = 0, min = 0, },

		{ uniform = true, category = "FX", id = "pad1", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "pad2", editor = "number", scale = 1000, default = 0, min = 0, },
		{ uniform = true, category = "FX", id = "pad3", editor = "number", scale = 1000, default = 0, min = 0, },
	},
}