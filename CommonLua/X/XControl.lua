DefineClass.XControl = {
	__parents = { "XWindow", "FXObject" },

	properties = {
		{ category = "Interaction", id = "Enabled", editor = "bool", default = true, },
		{ category = "Interaction", id = "Target", editor = "text", default = "", },
		{ category = "FX", id = "FXMouseIn", editor = "text", default = "", },
		{ category = "FX", id = "FXPress", editor = "text", default = "", },
		{ category = "FX", id = "FXPressDisabled", editor = "text", default = "", },
		{ category = "Visual", id = "FocusedBorderColor", name = "Focused border color", editor = "color", default = RGB(0, 0, 0), },
		{ category = "Visual", id = "FocusedBackground", name = "Focused background", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "DisabledBorderColor", name = "Disabled border color", editor = "color", default = RGB(0, 0, 0), },
		{ category = "Visual", id = "DisabledBackground", name = "Disabled background", editor = "color", default = RGBA(0, 0, 0, 0), },
		-- read only
		{ category = "FX", id = "Particles", read_only = true, editor = "string_list", default = false, }
	},
	enabled = true,
	IdNode = true,
	HandleMouse = true,
	particles = false,
}

------ BEGIN PARTICLES CODE

DefineClass.UIParticleInstance = {
	__parents = {"PropertyObject"},
	
	id = false,
	parsys_name = false,
	foreground = true,
	lifetime = -1,
	transfer_to_parent = false,
	stop_on_transfer = true,
	offset = point(0, 0),
	owner = false,
	delete_owner = false,
	halign = "middle",
	valign = "middle",
	keep_alive = false,
	polyline = false,
	params = false,
	dynamic_params = false,
}

local function align_position(alignment, rstart, rend)
	if alignment == "begin" then
		return rstart
	elseif alignment == "end" then
		return rend
	elseif alignment == "middle" then
		return (rstart + rend) / 2
	else
		assert("Invalid alignment")
		return rstart
	end
end

local function calc_particle_origin(control, particle)
	local box = control.content_box
	local posx = align_position(particle.halign, box:minx(), box:maxx())
	local posy = align_position(particle.valign, box:miny(), box:maxy())
	return posx, posy
end

---
--- Applies dynamic parameters to the particle instance.
---
--- This function retrieves the dynamic parameters for the particle system
--- associated with this instance, and sets the default values for each
--- parameter on the instance.
---
--- If the particle system has no dynamic parameters, the `dynamic_params`
--- field of the instance is set to `nil`.
---
function UIParticleInstance:ApplyDynamicParams()
	local proto = self.parsys_name
	local dynamic_params = ParGetDynamicParams(proto)
	if not next(dynamic_params) then
		self.dynamic_params = nil
		return
	end
	self.dynamic_params = dynamic_params
	local set_value = self.SetParamDef
	for k, v in pairs(dynamic_params) do
		set_value(self, v, v.default_value)
	end
end 

local UIParticleSetDynamicDataString = UIL.UIParticleSetDynamicDataString
---
--- Sets the points of the particle instance as a polyline.
---
--- @param pts table A table of points to set as the polyline.
---
function UIParticleInstance:SetPointsAsPolyline(pts)
	self.polyline = pstr("")
	for _, pt in ipairs(pts or empty_table) do
		self.polyline:AppendVertex(pt)
	end
	UIParticleSetDynamicDataString(self.id, 0, self.polyline)
end


---
--- Sets a dynamic parameter on the particle instance.
---
--- @param param string The name of the dynamic parameter to set.
--- @param value any The value to set for the dynamic parameter.
---
function UIParticleInstance:SetParam(param, value)
	local dynamic_params = self.dynamic_params
	local def = dynamic_params and rawget(dynamic_params, param)
	if def then
		self:SetParamDef(def, value)
	end
end

---
--- Sets a dynamic parameter on the particle instance.
---
--- @param def table The definition of the dynamic parameter to set.
--- @param value any The value to set for the dynamic parameter.
---
function UIParticleInstance:SetParamDef(def, value)
	local ptype = def.type
	if ptype == "number" then
		UIParticleSetDynamicDataString(self.id, def.index, value)
	elseif ptype == "color" then
		UIParticleSetDynamicDataString(self.id, def.index, value)
	elseif ptype == "point" then
		local x, y, z = value:xyz()
		local idx = def.index
		UIParticleSetDynamicDataString(self.id, idx, x)
		UIParticleSetDynamicDataString(self.id, idx + 1, y)
		UIParticleSetDynamicDataString(self.id, idx + 2, z or 0)
	elseif ptype == "bool" then
		UIParticleSetDynamicDataString(self.id, def.index, value and 1 or 0)
	end
end

---
--- Updates the polyline that represents the borders of the particle instance.
---
--- The polyline is calculated based on the bounding box of the particle's owner, and the particle's origin is used to offset the polyline points.
---
--- @param self UIParticleInstance The particle instance to update the polyline for.
---
function UIParticleInstance:UpdateBordersPolyline()
	local bbox = self.owner.box
	local pts = {
		point(bbox:minx(), bbox:miny()),
		point(bbox:maxx(), bbox:miny()),
		point(bbox:maxx(), bbox:maxy()),
		point(bbox:minx(), bbox:maxy()),
	}

	local x, y = calc_particle_origin(self.owner, self)
	local origin = point(x, y)
	for idx, _ in ipairs(pts) do
		local diff = (pts[idx] - origin)
		pts[idx] = point(diff:x() * guim, diff:y() * -guim)
	end

	self:SetPointsAsPolyline(pts)

	self:SetParam("width", bbox:sizex() * 1000)
	self:SetParam("height", bbox:sizey() * 1000)	
end

local HasUIParticles = UIL.HasUIParticles
local StopUIParticlesEmitter = UIL.StopUIParticlesEmitter
local function ParticleLifetimeFunc(particle, lifetime)
	if lifetime >= 0 then
		Sleep(lifetime)
		StopUIParticlesEmitter(particle.id)
	end

	local last_tick_had_particles = true
	Sleep(1000)
	while true do
		local has_particles = HasUIParticles(particle.id) or particle.keep_alive
		if not has_particles and not last_tick_had_particles then
			break
		end
		last_tick_had_particles = has_particles
		Sleep(1000)
	end

	assert(particle.owner)
	particle.owner:KillParSystem(particle.id, "leave_lifetimethread")
end

---
--- Updates the polyline borders for all particle instances owned by this XControl.
--- This is called when the bounding box of the XControl changes, to ensure the particle borders
--- are updated to match the new size.
---
--- @param self XControl The XControl instance.
---
function XControl:OnBoxChanged()
	for _, particle in ipairs(self.particles) do
		particle:UpdateBordersPolyline()
	end
end

---
--- Adds a new particle system to the XControl instance.
---
--- @param self XControl The XControl instance.
--- @param id string The unique identifier for the particle system.
--- @param name string The name of the particle system.
--- @param instance UIParticleInstance The particle system instance to add.
--- @return string The unique identifier for the added particle system.
---
function XControl:AddParSystem(id, name, instance)
	self.particles = self.particles or {}
	instance = instance or UIParticleInstance:new({})
	
	assert(name)
	if not id then
		id = UIL.PlaceUIParticles(name)
	end
	assert(id)
	assert(instance.owner == false)
	instance.id = id
	instance.parsys_name = name
	instance.owner = self
	instance:ApplyDynamicParams()

	instance.lifetime_thread = CreateRealTimeThread(ParticleLifetimeFunc, instance, instance.lifetime)
	table.insert(self.particles, instance)

	self:Invalidate()
	instance:UpdateBordersPolyline()
	return id
end

---
--- Stops a particle system owned by this XControl instance.
---
--- @param self XControl The XControl instance.
--- @param particle table|string The particle system instance or its unique identifier to stop.
--- @param force boolean If true, the particle system will be immediately killed. Otherwise, the particle system's lifetime thread will be deleted and a new one will be created with a lifetime of 0.
---
function XControl:StopParticle(particle, force)
	if type(particle) ~= "table" then
		particle = table.find_value(self.particles, "id", particle)
		if not particle then return end
	end
	particle.keep_alive = false
	if force then
		self:KillParSystem(particle.id)
	else
		DeleteThread(particle.lifetime_thread)
		particle.lifetime_thread = CreateRealTimeThread(ParticleLifetimeFunc, particle, 0)
	end
end
---
--- Kills all particle systems owned by this XControl instance that have the given name.
---
--- @param self XControl The XControl instance.
--- @param name string The name of the particle systems to kill.
---
function XControl:KillParticlesWithName(name)
	if not self.particles then return end
	for _, particle in ipairs(self.particles) do
		if particle.parsys_name == name then
			self:KillParSystem(particle.id)
		end
	end
end

---
--- Gets the name of the particle system with the given ID that is owned by this XControl instance.
---
--- @param self XControl The XControl instance.
--- @param id string The unique identifier of the particle system.
--- @return string The name of the particle system, or nil if no particle system with the given ID is found.
---
function XControl:GetParticleName(id)
	if not self.particles then return end
	local particle = table.find_value(self.particles, "id", id)
	if not particle then return end
	return particle.parsys_name
end

---
--- Transfers a particle system from this XControl instance to a parent XControl instance.
---
--- @param self XControl The XControl instance.
--- @param particle table The particle system to transfer.
---
function XControl:TransferParticleUp(particle)
	assert(table.find(self.particles, particle))
	local parent = self.parent
	local top_level_end_of_life_window = self
	while parent and (parent.window_state ~= "open" or IsKindOf(parent, "XContentTemplate")) do
		top_level_end_of_life_window = parent
		parent = parent.parent
	end

	if not parent then return end
	-- TODO: Insert the child at the right position in the parent and figure out why it results in asserts on main menu

	--print("Transferting to ", parent.Id, parent.class, top_level_end_of_life_window.Id, top_level_end_of_life_window.class)
	--local child_index = table.find(parent, top_level_end_of_life_window)
	--assert(child_index)

	local particle_holder = XControl:new({}, parent)
	--table.remove_value(parent, particle_holder)
	--table.insert(parent, child_index, particle_holder)

	particle_holder.particles = {}
	table.insert(particle_holder.particles, particle)
	particle.offset = particle.owner.content_box:min() - point(calc_particle_origin(particle_holder, particle)) + particle.offset
	particle.owner = particle_holder
	particle.delete_owner = true
	particle.foreground = true
	table.remove_value(self.particles, particle)
	if #self.particles == 0 then
		self.particles = false
	end
end

---
--- Kills a particle system associated with this XControl instance.
---
--- @param self XControl The XControl instance.
--- @param id string The unique identifier of the particle system to kill.
--- @param leave_lifetimethread boolean If true, the lifetime thread of the particle system will not be deleted.
---
function XControl:KillParSystem(id, leave_lifetimethread)
	if not self.particles then return end

	local idx = table.find(self.particles, "id", id)
	assert(idx)
	local particle = self.particles[idx]
	assert(particle.owner == self)
	if not leave_lifetimethread then
		DeleteThread(particle.lifetime_thread)
	end
	UIL.DeleteUIParticles(particle.id)
	table.remove(self.particles, idx)
	if #self.particles == 0 then
		self.particles = false
	end
	if particle.delete_owner then
		self:delete()
	end
	particle.keep_alive = false
	self:Invalidate()
end
 
---
--- Checks if the XControl instance has a particle with the specified ID.
---
--- @param self XControl The XControl instance.
--- @param id string The unique identifier of the particle to check for.
--- @return boolean True if the particle with the specified ID exists, false otherwise.
---
function XControl:HasParticle(id)
	if not self.particles then return false end
	if not table.find(self.particles, "id", id) then return false end
	return true
end

if Platform.developer then
	function XControl:DbgPlayFX(...)
		local index = self.particles and #(self.particles) or 1
		self:PlayFX(...)
		if not self.particles then
			return
		end
		for i = index, #self.particles do
			local particle = self.particles[i]
			if particle.lifetime == -1 then
				particle.keep_alive = true
			end
		end
	end
end

---
--- Handles the cleanup of particles when the XControl instance is done.
---
--- This function iterates through the particles associated with the XControl instance and performs the following actions:
--- - If the particle has the `transfer_to_parent` flag set, it checks if the particle should wait for the UI particle to be removed. If so, it either stops the particle or transfers it up to the parent.
--- - If the particle does not have the `transfer_to_parent` flag set, it kills the particle system associated with the particle.
---
--- @param self XControl The XControl instance.
---
function XControl:ParticlesOnDone()
	local particles = self.particles
	if particles then
		for i = #particles, 1, -1 do
			local particle = particles[i]
			if particle.transfer_to_parent and UIL.ShouldWaitForHasUIParticles(particle.id) then
				if particle.stop_on_transfer then
					self:StopParticle(particle)
				end
				self:TransferParticleUp(particle)
			else
				self:KillParSystem(particle.id)
			end
		end
	end
end

--- Handles the cleanup of particles when the XControl instance is done.
---
--- This function is called when the XControl instance is done and performs the following actions:
--- - If the particle has the `transfer_to_parent` flag set, it checks if the particle should wait for the UI particle to be removed. If so, it either stops the particle or transfers it up to the parent.
--- - If the particle does not have the `transfer_to_parent` flag set, it kills the particle system associated with the particle.
---
--- @param self XControl The XControl instance.
function XControl:Done()
	self:ParticlesOnDone()
end

---
--- Returns a table of alignment items for UI particles.
---
--- The returned table contains three items, each with a `value` and `text` field:
--- - `{ value = "begin", text = horizontal and "left" or "top" }`
--- - `{ value = "middle", text = "center" }`
--- - `{ value = "end", text = horizontal and "right" or "bottom" }`
---
--- @param horizontal boolean Whether the alignment is horizontal or vertical.
--- @return table A table of alignment items.
---
function GetUIParticleAlignmentItems(horizontal)
	return {
		{ value = "begin", text = horizontal and "left" or "top" },
		{ value = "middle", text = "center" },
		{ value = "end", text = horizontal and "right" or "bottom" },
	}
end

---
--- Draws the particles associated with the XControl instance.
---
--- This function is responsible for rendering the particles that are attached to the XControl instance. It iterates through the `self.particles` table and draws each particle that matches the `foreground` parameter. The particle is drawn using the `UIL.DrawParticles` function, with the particle's origin calculated based on the XControl's position and scale.
---
--- @param self XControl The XControl instance.
--- @param foreground boolean Whether to draw the foreground or background particles.
---
function XControl:DrawParticles(foreground)
	for key, particle in ipairs(self.particles) do
		if particle.foreground == foreground then
			local scale = self.scale:x()
			UIL.DrawParticles(particle.id, point(calc_particle_origin(self, particle)) + particle.offset, scale, scale, 0)
		end
	end
end

---
--- Draws the background and background particles for the XControl instance.
---
--- This function is responsible for rendering the background of the XControl instance. It first calls the `XWindow.DrawBackground` function to draw the background, and then calls the `XControl:DrawParticles` function to draw any background particles that are associated with the XControl.
---
--- @param self XControl The XControl instance.
---
function XControl:DrawBackground()
	XWindow.DrawBackground(self)
	self:DrawParticles(false)
end

---
--- Draws the children of the XControl instance and the foreground particles.
---
--- This function is responsible for rendering the children of the XControl instance, as well as any foreground particles that are associated with the XControl. It first calls the `XWindow.DrawChildren` function to draw the children, and then calls the `XControl:DrawParticles` function to draw the foreground particles.
---
--- @param self XControl The XControl instance.
--- @param clip_box table A table containing the clipping box coordinates.
---
function XControl:DrawChildren(clip_box)
	XWindow.DrawChildren(self, clip_box)
	self:DrawParticles(true)
end

---
--- Returns a table of particle system names associated with the XControl instance.
---
--- This function returns a table containing the names of the particle systems that are associated with the XControl instance. The particle systems are stored in the `self.particles` table, and this function maps that table to extract the `parsys_name` field for each particle system.
---
--- @return table A table of particle system names.
---
function XControl:GetParticles()
	return self.particles and table.map(self.particles, "parsys_name")
end

------ END OF PARTICLES CODE

---
--- Sets the enabled state of the XControl instance.
---
--- This function is used to enable or disable the XControl instance. When the XControl is disabled, it will not respond to user input and will be drawn with a disabled appearance.
---
--- If the `force` parameter is true, the enabled state will be set regardless of whether it has changed from the previous value.
---
--- If the XControl has child controls, this function will recursively set the enabled state of all child controls.
---
--- @param self XControl The XControl instance.
--- @param enabled boolean The new enabled state of the XControl.
--- @param force boolean (optional) If true, the enabled state will be set even if it hasn't changed.
---
function XControl:SetEnabled(enabled, force)
	local old = self.enabled
	self.enabled = enabled and true or false
	if self.enabled == old and not force then return end
	for _, win in ipairs(self) do
		if win:IsKindOf("XControl") then
			win:SetEnabled(enabled)
		end
	end
	self:Invalidate()
end

---
--- Returns the enabled state of the XControl instance.
---
--- This function returns the current enabled state of the XControl instance. When the XControl is disabled, it will not respond to user input and will be drawn with a disabled appearance.
---
--- @param self XControl The XControl instance.
--- @return boolean The enabled state of the XControl.
---
function XControl:GetEnabled()
	return self.enabled
end

---
--- Plays a visual effect (FX) associated with the XControl instance.
---
--- This function is used to play a visual effect (FX) associated with the XControl instance. The FX is specified by the `fx` parameter, and can be played at a specific "moment" (e.g. "start", "end") and position (`pos`).
---
--- If the `fx` parameter is nil or an empty string, this function will not do anything.
---
--- @param self XControl The XControl instance.
--- @param fx string The name of the visual effect to play.
--- @param moment string (optional) The "moment" at which to play the effect (e.g. "start", "end").
--- @param pos table (optional) The position at which to play the effect, specified as a table with `x` and `y` fields.
---
function XControl:PlayFX(fx, moment, pos)
	if fx and fx ~= "" then
		PlayFX(fx, moment or "start", self, self.Id, pos)	
	end
end

---
--- Called when the XControl instance gains focus.
---
--- This function is called when the XControl instance gains focus. It invalidates the control to trigger a redraw, and then calls the base class's `OnSetFocus` function.
---
--- @param self XControl The XControl instance.
--- @param focus boolean True if the control is gaining focus, false if it is losing focus.
---
function XControl:OnSetFocus(focus)
	self:Invalidate()
	XWindow.OnSetFocus(self, focus)
end

---
--- Called when the XControl instance loses focus.
---
--- This function is called when the XControl instance loses focus. It invalidates the control to trigger a redraw, and then calls the base class's `OnKillFocus` function.
---
--- @param self XControl The XControl instance.
---
function XControl:OnKillFocus()
	self:Invalidate()
	XWindow.OnKillFocus(self)
end

--- Calculates the background color of the XControl instance.
---
--- This function is used to determine the background color of the XControl instance based on its enabled state and focus state. If the control is disabled, it returns the `DisabledBackground` color. Otherwise, it returns either the `FocusedBackground` or `Background` color, depending on whether the control is currently focused.
---
--- @param self XControl The XControl instance.
--- @return table The calculated background color, represented as a table with `r`, `g`, `b`, and `a` fields.
function XControl:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	local FocusedBackground, Background = self.FocusedBackground, self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

---
--- Calculates the border color of the XControl instance.
---
--- This function is used to determine the border color of the XControl instance based on its enabled state and focus state. If the control is disabled, it returns the `DisabledBorderColor`. Otherwise, it returns either the `FocusedBorderColor` or `BorderColor`, depending on whether the control is currently focused.
---
--- @param self XControl The XControl instance.
--- @return table The calculated border color, represented as a table with `r`, `g`, `b`, and `a` fields.
function XControl:CalcBorderColor()
	if not self.enabled then return self.DisabledBorderColor end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end

---
--- Called when the XControl instance's rollover state changes.
---
--- This function is called when the XControl instance's rollover state changes. It calls the base class's `OnSetRollover` function, and then plays the appropriate hover effect animation based on the rollover state.
---
--- @param self XControl The XControl instance.
--- @param rollover boolean True if the control is being rolled over, false if the rollover is ending.
---
function XControl:OnSetRollover(rollover)
	XWindow.OnSetRollover(self, rollover)
	self:PlayHoverFX(rollover)
end

if FirstLoad then
	LastUIFXPos = false
end

---
--- Tries to mark the last position where a UI effect (FX) was played.
---
--- This function checks if the current mouse position is within the control's window and if it is different from the last recorded position. If the conditions are met, it updates the `LastUIFXPos` variable with the current mouse position and returns `true`. Otherwise, it returns `true` without updating the variable.
---
--- This function is used to avoid playing hover effects right after other effects have been played, to prevent visual artifacts.
---
--- @param self XControl The XControl instance.
--- @param event string The name of the UI effect event to be played.
--- @return boolean True if the last UI FX position was marked, false otherwise.
function XControl:TryMarkUIFX(event)
	-- mark LastUIFXPos only if there is an actual event
	if event and event ~= "" then
		local pt = terminal.GetMousePos()
		if self:MouseInWindow(pt) and pt == LastUIFXPos then
			return
		end
		LastUIFXPos = pt
	end
	return true
end

---
--- Plays the appropriate action effect (FX) for the XControl instance based on its enabled state.
---
--- If the control is enabled, this function plays the `FXPress` effect. If the control is disabled, it plays the `FXPressDisabled` effect. The function first checks if the last UI effect position is different from the current mouse position, and if so, it updates the `LastUIFXPos` variable with the current mouse position. This is done to avoid playing hover effects right after other effects have been played, to prevent visual artifacts.
---
--- @param self XControl The XControl instance.
--- @param forced boolean (optional) If true, the effect will be played regardless of the control's enabled state.
--- @return boolean True if the effect was played, false otherwise.
function XControl:PlayActionFX(forced)
	local event = (self.enabled or forced) and self.FXPress or self.FXPressDisabled
	self:TryMarkUIFX(event)
	self:PlayFX(event)
	return true
end

---
--- Plays the appropriate hover effect (FX) for the XControl instance based on its enabled state and the current mouse position.
---
--- If the control is enabled and the current mouse position is different from the last recorded position where a UI effect was played, this function plays the `FXMouseIn` effect. If the control is disabled or the current mouse position is the same as the last recorded position, this function returns `false` to avoid playing hover effects right after other effects have been played, to prevent visual artifacts.
---
--- @param self XControl The XControl instance.
--- @param rollover boolean True if the control is being rolled over, false if the rollover is ending.
--- @return boolean True if the effect was played, false otherwise.
function XControl:PlayHoverFX(rollover)
	if not self.enabled or rollover and not self:TryMarkUIFX(self.FXMouseIn) then
		return false -- avoid playing hover FX right after other FX
	end
	self:PlayFX(self.FXMouseIn, rollover and "start" or "end")
	return true
end

---
--- Handles the mouse button down event for the XControl instance.
---
--- If the left mouse button is pressed, this function plays the appropriate action effect (FX) for the control based on its enabled state.
---
--- @param self XControl The XControl instance.
--- @param pos point The current mouse position.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right, "M" for middle).
---
function XControl:OnMouseButtonDown(pos, button)
	if button == "L" then
		self:PlayActionFX()
	end
end


----- XContextControl

DefineClass.XContextControl = {
	__parents = { "XContextWindow", "XControl", },
	ContextUpdateOnOpen = true,
}


----- XFontControl

DefineClass.XFontControl = {
	__parents = { "XControl" },
	
	properties = {
		category = "Visual",
		{ id = "TextStyle", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "TextFont", editor = "text", default = "", invalidate = "measure", no_edit = true, },
		{ id = "TextColor", editor = "color", default = RGB(32, 32, 32), invalidate = "measure", no_edit = true, },
		{ id = "RolloverTextColor", editor = "color", default = RGB(0, 0, 0), invalidate = "measure", no_edit = true, },
		{ id = "DisabledTextColor", editor = "color", default = RGBA(32, 32, 32, 128), invalidate = "measure", no_edit = true, },
		{ id = "DisabledRolloverTextColor", editor = "color", default = RGBA(40, 40, 40, 128), invalidate = "measure", no_edit = true, },
		{ id = "ShadowType", editor = "choice", default = "shadow", items = {"shadow", "extrude", "outline"}, invalidate = "measure", no_edit = true, },
		{ id = "ShadowSize", editor = "number", default = 0, invalidate = "measure", no_edit = true, },
		{ id = "ShadowColor", editor = "color", default = RGBA(0, 0, 0, 48), invalidate = "measure", no_edit = true, },
		{ id = "ShadowDir", editor = "point", default = point(1,1), invalidate = "measure", no_edit = true, },
		
		{ id = "DisabledShadowColor", editor = "color", default = RGBA(0, 0, 0, 48), invalidate = "measure", no_edit = true, },
	},

	font_id = false,
	font_height = 10,
	font_linespace = 0,
	font_baseline = 8,
}

--- Initializes the XFontControl instance by setting the text style.
---
--- This function is called during the initialization of the XFontControl instance.
--- It sets the text style of the control based on the `TextStyle` property.
---
--- @param self XFontControl The XFontControl instance.
function XFontControl:Init()
	self:SetTextStyle(self.TextStyle)
end

---
--- Sets the text style of the XFontControl instance.
---
--- This function is used to set the text style of the XFontControl instance. It updates various properties of the control, such as the text font, color, shadow, and other related settings, based on the provided text style.
---
--- @param self XFontControl The XFontControl instance.
--- @param style string The name of the text style to set.
--- @param force boolean (optional) If true, the text font will be updated even if it's the same as the current one.
function XFontControl:SetTextStyle(style, force)
	self.TextStyle = style ~= "" and style or nil
	local text_style = TextStyles[style]
	if style == "" or not text_style then return end
	self:SetTextFont(style, force)
	self:SetTextColor(text_style.TextColor)
	self:SetRolloverTextColor(text_style.RolloverTextColor)
	self:SetDisabledTextColor(text_style.DisabledTextColor)
	self:SetShadowType(text_style.ShadowType)
	self:SetShadowSize(text_style.ShadowSize)
	self:SetShadowColor(text_style.ShadowColor)
	self:SetShadowDir(text_style.ShadowDir)
	self:SetDisabledShadowColor(text_style.DisabledShadowColor)
	self:SetDisabledRolloverTextColor(text_style.DisabledRolloverTextColor)
end

---
--- Sets the text font of the XFontControl instance.
---
--- This function is used to set the text font of the XFontControl instance. It updates the `TextFont` property and invalidates the measure and appearance of the control, causing it to be redrawn with the new font.
---
--- @param self XFontControl The XFontControl instance.
--- @param font string The name of the font to set.
--- @param force boolean (optional) If true, the text font will be updated even if it's the same as the current one.
function XFontControl:SetTextFont(font, force)
	if self.TextFont == font and not force then return end
	self.TextFont = font
	self.font_id = false
	self:InvalidateMeasure()
	self:Invalidate()
end

---
--- Called when the scale of the XFontControl instance changes.
---
--- This function is called when the scale of the XFontControl instance changes. It resets the `font_id` property to `false`, which will cause the font ID to be recalculated the next time it is needed.
---
--- @param self XFontControl The XFontControl instance.
--- @param scale table The new scale of the control.
function XFontControl:OnScaleChanged(scale)
	self.font_id = false
end

---
--- Calculates the text color of the XFontControl instance based on its enabled and rollover state.
---
--- @return Color The calculated text color.
function XFontControl:CalcTextColor()
	return self.enabled and 
		(self.rollover and self.RolloverTextColor or self.TextColor) or
		(self.rollover and self.DisabledRolloverTextColor or self.DisabledTextColor)
end

---
--- Called when the rollover state of the XFontControl instance changes.
---
--- This function is called when the rollover state of the XFontControl instance changes. It checks if the text color needs to be invalidated and redrawn based on the enabled and rollover state of the control. It then calls the base `XControl.OnSetRollover` function to handle the rollover state change.
---
--- @param self XFontControl The XFontControl instance.
--- @param rollover boolean The new rollover state of the control.
function XFontControl:OnSetRollover(rollover)
	local invalidate
	if self.enabled then
		invalidate = self.RolloverTextColor ~= self.TextColor
	else
		invalidate = self.DisabledRolloverTextColor ~= self.DisabledTextColor
	end
	if invalidate then
		self:Invalidate()
	end
	
	XControl.OnSetRollover(self, rollover)
end

---
--- Gets the font ID for the XFontControl instance.
---
--- This function calculates and returns the font ID for the XFontControl instance. If the `font_id` property is not set, it retrieves the font ID, height, and baseline from the text style associated with the control's text style. The calculated font ID is then stored in the `font_id` property for future use.
---
--- @param self XFontControl The XFontControl instance.
--- @return number The font ID for the control.
function XFontControl:GetFontId()
	local font_id = self.font_id
	if not font_id then
		local text_style = TextStyles[self:GetTextStyle()]
		if not text_style then
			assert(false, string.format("Invalid text style '%s'", self:GetTextStyle()))
			return
		end
		font_id, self.font_height, self.font_baseline = text_style:GetFontIdHeightBaseline(self.scale:y())
		self.font_id = font_id
	end
	return font_id
end

---
--- Gets the font height for the XFontControl instance.
---
--- This function calculates and returns the font height for the XFontControl instance. It first calls the `GetFontId()` function to ensure the `font_height` property is set, and then returns the `font_height` value.
---
--- @param self XFontControl The XFontControl instance.
--- @return number The font height for the control.
function XFontControl:GetFontHeight()
	self:GetFontId()
	return self.font_height
end

---
--- Sets the font properties of the XFontControl instance based on the properties of another font control.
---
--- This function sets the text style, font, text color, rollover text color, disabled text color, shadow type, shadow size, shadow color, shadow direction, disabled shadow color, and disabled rollover text color of the XFontControl instance based on the properties of the provided `font_control` instance.
---
--- @param self XFontControl The XFontControl instance.
--- @param font_control XFontControl The font control to copy properties from.
function XFontControl:SetFontProps(font_control)
	local style = font_control:GetTextStyle()
	if style ~= "" and TextStyles[style] then
		self:SetTextStyle(style)
		return
	end
	self:SetTextFont(font_control:GetTextFont())
	self:SetTextColor(font_control:GetTextColor())
	self:SetRolloverTextColor(font_control:GetRolloverTextColor())
	self:SetDisabledTextColor(font_control:GetDisabledTextColor())
	self:SetShadowType(font_control:GetShadowType())
	self:SetShadowSize(font_control:GetShadowSize())
	self:SetShadowColor(font_control:GetShadowColor())
	self:SetShadowDir(font_control:GetShadowDir())
	self:SetDisabledShadowColor(font_control:GetDisabledShadowColor())
	self:SetDisabledRolloverTextColor(font_control:GetDisabledRolloverTextColor())
end


----- XTranslateText

DefineClass.XTranslateText = {
	__parents = { "XFontControl", "XContextControl" },
	
	properties = {
		{ category = "General", id = "Translate", editor = "bool", default = false, },
		{ category = "General", id = "Text", editor = "text", default = "", translate = function (obj) return obj:GetProperty("Translate") end, },
		{ category = "General", id = "UpdateTimeLimit", name = "Update limit", editor = "number", default = 0, },
	},
	ContextUpdateOnOpen = false,
	text = "",
	last_update_time = 0,
}

--- Called when the text of the XTranslateText control has changed.
---
--- @param self XTranslateText The XTranslateText instance.
--- @param text string The new text value.
function XTranslateText:OnTextChanged(text)
end

---
--- Sets the text of the XTranslateText control.
---
--- If the `Translate` property is `true`, the text will be translated using the `_InternalTranslate` function. If the `Translate` property is `false`, the text must be a string.
---
--- @param self XTranslateText The XTranslateText instance.
--- @param text string|number The new text value. If a number is provided, it will be converted to a string.
function XTranslateText:SetText(text)
	if type(text) == "number" then text = tostring(text) end
	self.Text = text or nil
	text = text or ""
	assert(self.Translate or type(text) == "string") -- passing a T value with Translate == false?
	assert(not self.Translate or IsT(text)) -- passing a text value with Translate == true?
	if text ~= "" and (self.Translate or IsT(text)) then
		text = _InternalTranslate(text, self.context)
	end
	if self.text ~= text then
		self:OnTextChanged(text)
		self.text = text
		self.last_update_time = RealTime()
		self:InvalidateMeasure()
		self:Invalidate()
	end
end

---
--- Updates the context of the XTranslateText control.
---
--- If the `UpdateTimeLimit` property is set to 0 or the time since the last update exceeds the `UpdateTimeLimit`, the text is updated by calling `self:SetText(self.Text)`.
---
--- If the `UpdateTimeLimit` is greater than 0 and the time since the last update has not exceeded the limit, a new thread is created to sleep for the remaining time and then call `self:OnContextUpdate()`.
---
--- @param self XTranslateText The XTranslateText instance.
--- @param context table The current context.
function XTranslateText:OnContextUpdate(context)
	local limit = self.UpdateTimeLimit
	if limit == 0 or (RealTime() - self.last_update_time) >= limit then
		self:SetText(self.Text)
	elseif not self:GetThread("ContextUpdate") then
		self:CreateThread("ContextUpdate", function(self)
			Sleep(self.last_update_time + self.UpdateTimeLimit - RealTime())
			self:OnContextUpdate()
		end, self)
	end
end

---
--- Handles changes to the `Translate` property of the `XTranslateText` control.
---
--- When the `Translate` property is changed, this function updates the `Text` property to toggle between `Ts` and strings, depending on the value of `Translate`.
---
--- @param self XTranslateText The `XTranslateText` instance.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
function XTranslateText:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when Translate is edited
	if prop_id == "Translate" then
		self:UpdateLocalizedProperty("Text", self.Translate)
		ObjModified(self)
	end
end

---
--- Recursively updates the text of all `XTranslateText` controls in the given `root` object and its children.
---
--- For each `XTranslateText` control that has the `Translate` property set to `true` and has a `T` value as its text, this function will call `SetText` to update the text and `SetTextStyle` to force a style update.
---
--- This function is called when the translation system has changed, to ensure all translated texts are up-to-date.
---
--- @param root table The root object to start the recursive update from.
function RecursiveUpdateTTexts(root)
	if IsKindOf(root, "XTranslateText") and root.Translate and IsT(root:GetText()) then
		root:SetText(root:GetText())
		root:SetTextStyle(root:GetTextStyle(), "force")
	end
	for i = 1, #root do
		RecursiveUpdateTTexts(root[i])
	end
end

function OnMsg.TranslationChanged()
	ClearTextStyleCache()
	RecursiveUpdateTTexts(terminal.desktop)
end

----- XEditableText

DefineClass.XEditableText = {
	__parents = { "XFontControl", "XContextControl" },
	
	properties = {
		{ category = "General", id = "Translate", name = "Translated text", editor = "bool", default = false,
			help = "Enabled for texts that the developers enter and that need to go into the translation tables.\n\nGetText will return a T value with a localization ID.",
		},
		{ category = "General", id = "UserText", name = "User text", editor = "bool", default = false,
			help = "Enable for user-entered texts that need to be filtered for profanity.\n\nGetText will return a special T value with extra data such as source user ID, language, etc.",
		},
		{ category = "General", id = "UserTextType", editor = "choice", default = "unknown", items = {"name", "chat", "game_content", "unknown"}, no_edit = function(obj) return not obj.UserText end,
			help = "The user text is filtered in a different way, depending on this value; supported by Steam only.",
		},
		{ category = "General", id = "Text", editor = "text", translate = function(self) return self.Translate end, default = "", },
		{ category = "General", id = "OnTextChanged", editor = "func", params = "self"},
	},
	
	text = "",
	text_translation_id = false,
}

---
--- Sets the text of the `XEditableText` control.
---
--- If the `Translate` property is `true`, the `text` parameter is expected to be a localization ID (`T` value). The text will be set to the English translation of the localization ID.
---
--- If the `UserText` property is `true`, the `text` parameter is expected to be a user-entered text. The text will be set to the English translation of the user text.
---
--- @param text string The text to set for the control.
function XEditableText:SetText(text)
	if self.Translate then
		assert(IsT(text))
		self.text_translation_id = TGetID(text) or nil
		text = type(text) == "string" and text or TDevModeGetEnglishText(text, "deep", "no_assert")
	elseif self.UserText then
		assert(IsUserText(text))
		text = type(text) == "string" and text or TDevModeGetEnglishText(text, "deep", "no_assert")
	end
	self:SetTranslatedText(text)
end

---
--- Sets the translated text of the `XEditableText` control.
---
--- If the `text` parameter is a localization ID (`T` value), the text will be set to the English translation of the localization ID.
---
--- If the `notify` parameter is not `false`, the `OnTextChanged` event will be triggered.
---
--- @param text string The translated text to set for the control.
--- @param notify boolean (optional) Whether to trigger the `OnTextChanged` event. Defaults to `true`.
function XEditableText:SetTranslatedText(text, notify)
	if self.text ~= text then
		assert(type(text) == "string")
		self.text = IsT(text) and TDevModeGetEnglishText(text) or text
		if notify ~= false then
			self:OnTextChanged()
		end
		self:InvalidateMeasure()
		self:Invalidate()
	end
end

---
--- Gets the text of the `XEditableText` control.
---
--- If the `text` property is empty or neither `Translate` nor `UserText` is true, the `text` property is returned as-is.
---
--- If `UserText` is true, the `text` property is wrapped in a `CreateUserText` function call to create a user text object.
---
--- If `Translate` is true, the `text` property is assumed to be a localization ID (`T` value). A random localization ID is generated and assigned to `text_translation_id`, and the text is returned as a `T` function call with the localization ID.
---
--- @return string The text of the `XEditableText` control.
function XEditableText:GetText()
	local text = self.text
	if text == "" or (not self.Translate and not self.UserText) then
		return text
	elseif self.UserText then
		return CreateUserText(self.text, self.UserTextType)
	end
	local id = self.text_translation_id or RandomLocId()
	self.text_translation_id = id
	text = text:gsub("\r?\n", "\n")
	return T{id, text}
end

---
--- Gets the translated text of the `XEditableText` control.
---
--- If the `text` property is empty or neither `Translate` nor `UserText` is true, the `text` property is returned as-is.
---
--- If `UserText` is true, the `text` property is wrapped in a `CreateUserText` function call to create a user text object.
---
--- If `Translate` is true, the `text` property is assumed to be a localization ID (`T` value). A random localization ID is generated and assigned to `text_translation_id`, and the text is returned as a `T` function call with the localization ID.
---
--- @return string The text of the `XEditableText` control.
function XEditableText:GetTranslatedText()
	return self.text
end

---
--- Called when the text of the `XEditableText` control has changed.
---
--- This function is called whenever the text of the `XEditableText` control is updated. It is an empty implementation that can be overridden by subclasses to provide custom behavior when the text changes.
---
function XEditableText:OnTextChanged()
end


----- XPopup

xpopup_anchor_types = {"none", "custom", "drop", "drop-right", "smart", "left", "right", "top", "bottom", "center-top", "center-bottom", "bottom-right", "bottom-left", "top-left", "top-right", "right-center", "left-center" , "mouse", "live-mouse"}
DefineClass.XPopup = {
	__parents = { "XControl" },
	properties = {
		{ category = "General", id = "Anchor", editor = "rect", default = box(0, 0, 0, 0), },
		{ category = "General", id = "AnchorType", editor = "choice", default = "none", items = xpopup_anchor_types },
	},
	LayoutMethod = "VList",
	Dock = "ignore",
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(240, 240, 240),
	BorderWidth = 1,
	BorderColor = RGB(128, 128, 128),
	FocusedBorderColor = RGB(128, 128, 128),
	
	popup_parent = false,
}

---
--- Gets the safe area box for the popup.
---
--- The safe area box is the area of the screen that is not obscured by system UI elements like the status bar or navigation bar.
---
--- @return number, number, number, number The x, y, width, and height of the safe area box.
function XPopup:GetSafeAreaBox()
	return GetSafeAreaBox()
end

---
--- Gets the custom anchor box for the popup.
---
--- The custom anchor box is used to position the popup relative to a specific point on the screen.
---
--- @param x number The x-coordinate of the custom anchor box.
--- @param y number The y-coordinate of the custom anchor box.
--- @param width number The width of the custom anchor box.
--- @param height number The height of the custom anchor box.
--- @param anchor table The anchor box to use for positioning the popup.
--- @return number, number, number, number The x, y, width, and height of the custom anchor box.
function XPopup:GetCustomAnchor(x, y, width, height, anchor)
	return anchor:minx(), anchor:miny(), width, height
end

---
--- Updates the layout of the XPopup.
---
--- This function is responsible for positioning the popup on the screen based on its anchor type and the available safe area.
---
--- @param self XPopup The XPopup instance.
--- @return boolean True if the layout was updated successfully, false otherwise.
function XPopup:UpdateLayout()
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local anchor = self:GetAnchor()
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	local x, y = self.box:minxyz()
	local width, height = self.measure_width - margins_x1 - margins_x2, self.measure_height - margins_y1 - margins_y2
	local a_type = self.AnchorType
	if a_type == "smart" then
		local space = anchor:minx() - safe_area_x1 - width - margins_x2
		a_type = "left"
		if space < safe_area_x2 - anchor:maxx() - width - margins_x1 then
			space = safe_area_x2 - anchor:maxx() - width - margins_x1
			a_type = "right"
		end
		if space < anchor:miny() - safe_area_y1 - height - margins_y2 then
			space = anchor:miny() - safe_area_y1 - height - margins_y2
			a_type = "top"
		end
		if space < safe_area_y2 - anchor:maxy() - height - margins_y1 then
			space = safe_area_y2 - anchor:maxy() - height - margins_y1
			a_type = "bottom"
		end
	end
	if a_type == "live-mouse" then
		local pos = terminal.GetMousePos()
		anchor = sizebox(pos, UIL.MeasureImage(GetMouseCursor()))
		a_type = "bottom"
	end
	if a_type == "mouse" then
		x, y = anchor:x(), anchor:y()
	elseif a_type == "left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny() - margins_y1
	elseif a_type == "right" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() - margins_y1
	elseif a_type == "top" then
		x = anchor:minx() - margins_x1
		y = anchor:miny() - height - margins_y2
	elseif a_type == "bottom" then
		x = anchor:minx() - margins_x1
		y = anchor:maxy() + margins_y2
	end
	if a_type == "center-top" then
		x = anchor:minx() + ((anchor:maxx() - anchor:minx())  -  width)/2
		y = anchor:miny() - height - margins_y2
	end
	if a_type == "center-bottom" then
		x = anchor:minx() + ((anchor:maxx() - anchor:minx())  -  width)/2
		y = anchor:maxy() + margins_y2
	end
	if a_type == "bottom-right" then
		x = anchor:maxx() + margins_x1
		y = anchor:maxy() - height - margins_y2
	end	
	if a_type == "bottom-left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:maxy() - height - margins_y2
	end	
	if a_type == "right-center" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() + ((anchor:maxy() - anchor:miny())  -  height)/2
	end
	if a_type == "left-center" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny() + ((anchor:maxy() - anchor:miny())  -  height)/2
	end
	if a_type == "top-right" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny()- margins_y1
	end
	if a_type == "top-left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny()- margins_y1
	end
	if a_type == "drop" then
		x, y = anchor:minx(), anchor:maxy()
		width = Max(anchor:sizex(), width)
	end
	if a_type == "drop-right" then
		x, y = anchor:minx() + anchor:sizex() - width, anchor:maxy()
		width = Max(anchor:sizex(), width)
	end
	if a_type == "custom" then
		x, y, width, height = self:GetCustomAnchor(x, y, width, height, anchor)
	end
	-- fit window to safe area
	if x + width + margins_x2 > safe_area_x2 then
		x = safe_area_x2 - width - margins_x2
	elseif x < safe_area_x1 then
		x = safe_area_x1
	end
	if y + height + margins_y2 > safe_area_y2 then
		y = safe_area_y2 - height - margins_y2
	elseif y < safe_area_y1 then
		y = safe_area_y1
	end
	-- layout
	self:SetBox(x, y, width, height)
	return XControl.UpdateLayout(self)
end

--- Handles the behavior when the popup loses focus.
---
--- When the popup loses focus, it will close all popups up to the common parent in the popup chain, unless the new focus is within the popup chain.
---
--- @param self XPopup The popup instance.
--- @param new_focus table|nil The new focus object, if any.
function XPopup:OnKillFocus(new_focus)
	if self.window_state ~= "open" then 
		XWindow.OnKillFocus(self)
		return
	end
	-- close all popups up to the common parent in the popup chain
	local popup = self
	while IsKindOf(popup, "XPopup") and not (new_focus and popup:IsWithinPopupChain(new_focus)) do
		popup:Close()
		popup = popup.popup_parent
	end
	XWindow.OnKillFocus(self)
end

--- Checks if the given child window is within the popup chain of the current popup.
---
--- This function recursively checks if the given child window is a popup or is a child of a popup that is in the popup chain of the current popup.
---
--- @param self XPopup The current popup instance.
--- @param child table The child window to check.
--- @return boolean true if the child window is within the popup chain, false otherwise.
function XPopup:IsWithinPopupChain(child)
	local popup = child:IsKindOf("XPopup") and child or GetParentOfKind(child, "XPopup")
	while popup do
		if popup == self then return true end
		popup = GetParentOfKind(popup.popup_parent, "XPopup")
	end
end

--- Handles the mouse button down event for the XPopup.
---
--- When the left mouse button is pressed on the popup, the popup will set itself as the focused window.
---
--- @param self XPopup The popup instance.
--- @param pt table The mouse position.
--- @param button string The mouse button that was pressed.
--- @return string "break" to indicate the event has been handled.
function XPopup:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:SetFocus()
		return "break"
	end
end


----- XPopupList

DefineClass.XPopupList = {
	__parents = { "XPopup" },
	properties = {
		{ category = "General", id = "MinItems", editor = "number", default = 5, },
		{ category = "General", id = "MaxItems", editor = "number", default = 25, },
		{ category = "General", id = "AutoFocus", editor = "bool", default = true, },
	},
	IdNode = true,
}

--- Initializes the XPopupList control.
---
--- This function sets up the scroll area and scroll bar for the XPopupList control. It creates a new XSleekScroll control and attaches it to the "idScroll" target, and creates a new XScrollArea control and attaches it to the "idContainer" target.
---
--- The scroll area is configured to use a vertical list layout, and the scroll bar is set to automatically hide when not needed. The minimum thumb size for the scroll bar is set to 30 pixels.
---
--- The `EnumFocusChildren` function is also defined for the `idContainer` scroll area. This function iterates over the child windows of the scroll area and calls the provided function `f` for each child window that has a focus order set. If a child window does not have a focus order set, the function recursively calls `EnumFocusChildren` on that child window.
---
--- @param self XPopupList The XPopupList instance.
function XPopupList:Init()
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idContainer",
		Dock = "right",
		Margins = box(1, 1, 1, 1),
		AutoHide = true,
		MinThumbSize = 30,
	}, self)
	XScrollArea:new({
		Id = "idContainer",
		Dock = "box",
		LayoutMethod = "VList",
		VScroll = "idScroll",
	}, self)
	self.idContainer.EnumFocusChildren = function(this, f)
		for _, win in ipairs(this) do
			local order = win:GetFocusOrder()
			if order then
				f(win, order:xy())
			else
				win:EnumFocusChildren(f)
			end
		end
	end
end

--- Opens the XPopupList control.
---
--- If the `AutoFocus` property is true, this function sets the focus to the `idContainer` scroll area. It then calls the `Open` function of the `XPopup` class to open the popup.
---
--- @param self XPopupList The XPopupList instance.
--- @param ... Any additional arguments to pass to the `XPopup.Open` function.
function XPopupList:Open(...)
	if self.AutoFocus then
		self.idContainer:SetFocus()
	end
	XPopup.Open(self, ...)
end

--- Updates the layout of the XPopupList control.
---
--- This function is responsible for positioning and sizing the XPopupList control based on its anchor and the available safe area. It handles cases where the XPopupList is anchored to a "drop" or "drop-right" position.
---
--- The function first checks the anchor type and calls the parent `XPopup.UpdateLayout` function if the anchor type is not "drop" or "drop-right". Otherwise, it calculates the width and height of the XPopupList based on the anchor position and the safe area.
---
--- If the XPopupList would extend beyond the safe area, the function attempts to adjust the position and size to fit within the safe area. If the XPopupList still cannot fit within the safe area, the function reduces the number of items displayed to fit within the available space.
---
--- @param self XPopupList The XPopupList instance.
--- @return boolean True if the layout was successfully updated, false otherwise.
function XPopupList:UpdateLayout()
	local a_type = self.AnchorType
	if a_type ~= "drop" and a_type ~= "drop-right" then
		return XPopup.UpdateLayout(self)
	end

	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local anchor = self.Anchor
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = GetSafeAreaBox()
	local width, height =  Max(anchor:sizex(),self.measure_width - margins_x1 - margins_x2), self.measure_height - margins_y1 - margins_y2
	
	local x, y = anchor:minx(), anchor:maxy()	
	
	if a_type == "drop-right" then
		x = anchor:minx() + anchor:sizex() - width
	end
	
	-- fit window to safe area
	if x + width + margins_x2 > safe_area_x2 then
		x = safe_area_x2 - width - margins_x2
	elseif x < safe_area_x1 then
		x = safe_area_x1
	end
	
	local items = self.idContainer
	local popup_max_y = y + height + margins_y2 
	local space_y = safe_area_y2 - y
	local fail = false
	if (safe_area_y2 - popup_max_y)<0 then
		-- try to reduce items count
		local vspace = self.idContainer.LayoutVSpacing
		y = anchor:maxy()		
		local size = margins_y1 + margins_y2 - vspace
		for i = 1, Min(#items, self.MaxItems) do
			local newsize = size + vspace + items[i].measure_height
			if newsize > space_y then
				fail = i<=self.MinItems 
				break
			end	
			size = newsize
		end
		if not fail then
			height = size
		end
		
		-- try to place over the control
		if fail then
			y = anchor:miny()
			local popup_min_y = y - height - margins_y1 
			local space_y = y - safe_area_y1
			if (popup_min_y - safe_area_y1)<0 then			
				-- try to reduce items count
				fail = false
				size = margins_y1 + margins_y2 + items[1].measure_height
				for i = 2, Min(#items, self.MaxItems) do
					local newsize = size + vspace + items[i].measure_height
					if newsize > space_y then
						fail = i<=self.MinItems
						break
					end	
					size = newsize
				end
				height = size
			end
			y = y - height
		end
	end
	-- layout	
	if fail then
		if y + height + margins_y2 > safe_area_y2 then
			y = safe_area_y2 - height - margins_y2
		elseif y < safe_area_y1 then
			y = safe_area_y1
		end
	end
	self:SetBox(x, y, width, height)
	return XControl.UpdateLayout(self)
end

---
--- Measures the size of the XPopupList control.
---
--- If the number of items in the control exceeds the `MaxItems` property, the function calculates the height of the control based on the maximum number of items to display and the height of each item. It also sets the `MouseWheelStep` property of the `idContainer` to allow scrolling through the items.
---
--- If the number of items does not exceed the `MaxItems` property, the function simply returns the width and height of the control as measured by the `XPopup.Measure` function.
---
--- @param preferred_width number The preferred width of the control.
--- @param preferred_height number The preferred height of the control.
--- @return number, number The measured width and height of the control.
function XPopupList:Measure(preferred_width, preferred_height)
	local width, height = XPopup.Measure(self, preferred_width, preferred_height)
	local items = self.idContainer
	if #items > self.MaxItems then
		local item_height = (self.MaxItems - 1) * self.idContainer.LayoutVSpacing
		for i = 1, self.MaxItems do
			item_height = item_height + items[i].measure_height
		end
		self.idContainer.MouseWheelStep = items[1].measure_height * 2
		return width, Min(height, item_height)
	end
	return width, height
end

---
--- Handles keyboard shortcuts for the XPopupList control.
---
--- This function is called when a keyboard shortcut is triggered while the XPopupList is open. It handles the following shortcuts:
---
--- - "Escape" or "ButtonB": Closes the XPopupList and returns "break" to stop further processing of the shortcut.
--- - "Down" or "Up": Moves the keyboard focus to the next or previous item in the XPopupList, and scrolls the list to ensure the focused item is visible.
---
--- @param shortcut string The name of the triggered keyboard shortcut.
--- @param source table The object that triggered the shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, nil otherwise.
function XPopupList:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" or shortcut == "ButtonB" then
		self:Close()
		return "break"
	end
	local relation = XShortcutToRelation[shortcut]
	if shortcut == "Down" or shortcut == "Up" or relation == "down" or relation == "up" then
		local focus = self.desktop.keyboard_focus
		local order = focus and focus:GetFocusOrder()
		if shortcut == "Down" or relation == "down" then
			focus = self.idContainer:GetRelativeFocus(order or point(0, 0), "next")
		else
			focus = self.idContainer:GetRelativeFocus(order or point(1000000000, 1000000000), "prev")
		end
		if focus then
			self.idContainer:ScrollIntoView(focus)
			focus:SetFocus()
		end
		return "break"
	end
end


----- XPropControl

DefineClass.XPropControl = {
	__parents = { "XContextControl" },
	properties = {
		{ category = "Scroll", id = "BindTo", name = "Bind to property", editor = "text", default = "", },
		
	},
	prop_meta = false,
	value = false,
}

---
--- Initializes an XPropControl instance with the given parent and context.
---
--- @param parent table The parent object of the XPropControl.
--- @param context table The context object for the XPropControl.
function XPropControl:Init(parent, context)
	self.prop_meta = ResolveValue(context, "prop_meta")
end

---
--- Sets the property that the XPropControl is bound to.
---
--- @param prop_id string The ID of the property to bind to.
--- @param prop_meta table The metadata for the property to bind to.
function XPropControl:SetBindTo(prop_id, prop_meta)
	self.BindTo = prop_id
	if not prop_meta then
		ForEachObjInContext(self.context, function(obj, self, prop_id)
			prop_meta = prop_meta or IsKindOf(obj, "PropertyObject") and obj:GetPropertyMetadata(prop_id)
		end, self, prop_id)
	end
	self.prop_meta = prop_meta
end

---
--- Called when the property bound to the XPropControl is updated.
---
--- @param context table The context object for the XPropControl.
--- @param prop_meta table The metadata for the property that was updated.
--- @param value any The new value of the property.
function XPropControl:OnPropUpdate(context, prop_meta, value)
end

---
--- Returns the name of the property that the XPropControl is bound to.
---
--- @return string The name of the bound property, or an empty string if no property is bound.
function XPropControl:GetPropName()
	local prop_meta = self.prop_meta
	return prop_meta and prop_meta.name or ""
end

---
--- Updates the property name and help text for the XPropControl.
---
--- @param prop_meta table The metadata for the property bound to the XPropControl.
function XPropControl:UpdatePropertyNames(prop_meta)
	local name = self:ResolveId("idName")
	if name then
		name:SetText(prop_meta.name or prop_meta.id)
	end
	if prop_meta.help and editor ~= "help" then
		self:SetRolloverText(prop_meta.help)
	end
end

---
--- Called when the context of the XPropControl is updated.
---
--- @param context table The new context object for the XPropControl.
function XPropControl:OnContextUpdate(context)
	local prop_id = self.BindTo
	local prop_meta = self.prop_meta
	if context and (prop_id ~= "" or prop_meta) then
		if prop_meta then
			prop_id = prop_meta.id
			self:UpdatePropertyNames(prop_meta)
		end
		local value = ResolveValue(context, prop_id)
		if value ~= rawget(self, "value") then
			self.value = value
			self:OnPropUpdate(context, prop_meta, value)
		end
	end
	XContextControl.OnContextUpdate(self, context)
end


----- XProgress

DefineClass.XProgress = {
	__parents = { "XPropControl" },
	
	properties = {
		{ category = "Progress", id = "Horizontal", name = "Horizontal", editor = "bool", default = true },
		{ category = "Progress", id = "Progress", name = "Progress", editor = "number", default = 0 },
		{ category = "Progress", id = "MaxProgress", name = "Max progress", editor = "number", default = 100, invalidate = "measure", },
		{ category = "Progress", id = "MinProgressSize", name = "Size at progress 0", editor = "number", default = 0 },
		{ category = "Progress", id = "ProgressClip", name = "Clip window", editor = "bool", default = false, invalidate = true, },
	},
}

---
--- Called when the property bound to the XPropControl is updated.
---
--- @param context table The current context object for the XPropControl.
--- @param prop_meta table The metadata for the property bound to the XPropControl.
--- @param value number The new value of the property.
function XProgress:OnPropUpdate(context, prop_meta, value)
	assert(type(value) == "number")
	if type(value) == "number" then
		if prop_meta then
			local scale = prop_meta.scale
			scale = type(scale) == "string" and const.Scale[scale] or scale or 1
			local min = prop_eval(prop_meta.min, context, prop_meta) or 0
			local max = prop_eval(prop_meta.max, context, prop_meta)
			self:SetMaxProgress(max and (max - min) / scale or self.MaxProgress)
			self:SetProgress((value - min) / scale)
		else
			self:SetProgress(value)
		end
	end
end

---
--- Sets the progress value of the XProgress control.
---
--- @param value number The new progress value, between 0 and 1.
---
function XProgress:SetProgress(value)
	if self.Progress == value then return end
	self.Progress = value
	if self.ProgressClip then
		self:Invalidate()
	else
		self:InvalidateMeasure()
	end
end

---
--- Adjusts the size of the XProgress control based on the available maximum width and height.
---
--- @param max_width number The maximum available width for the control.
--- @param max_height number The maximum available height for the control.
--- @return number, number The adjusted width and height of the control.
---
function XProgress:MeasureSizeAdjust(max_width, max_height)
	local old_width = max_width

	local docked_x, docked_y = 0, 0
	for _, win in ipairs(self) do
		local dock = win.Dock
		if dock then
			win:UpdateMeasure(max_width, max_height)
			if dock == "left" or dock == "right"  then
				docked_x =  docked_x + win.measure_width
			elseif dock == "top" or dock == "bottom" then
				docked_y = docked_y + win.measure_height
			end
		end
	end
	
	local max = Max(1, self.MaxProgress)
	local progress = self.ProgressClip and max or Clamp(self.Progress, 0, max)
	if self.Horizontal then
		max_width = max_width - docked_x
		local min = ScaleXY(self.scale, self.MinProgressSize)
		max_width = min + (max_width - min) * progress / max
		max_width = max_width + docked_x
	else
		max_height = max_height - docked_y
		local _, min = ScaleXY(self.scale, 0, self.MinProgressSize)
		max_height = min + (max_height - min) * progress / max
		max_height = max_height + docked_y
	end
	
	return max_width, max_height
end

----- XAspectWindow

DefineClass.XAspectWindow = {
	__parents = { "XWindow" },
	properties = {
		{ category = "General", id = "Aspect", name = "Aspect", editor = "combo", default = point(16, 9), items = {
			{ name = "21:9 movie (64:27)", value = point(64, 27)}, 
			{ name = "2:1 Univisium", value = point(2, 1)}, 
			{ name = "16:9 HD", value = point(16, 9)}, 
			{ name = "5:3", value = point(5, 3)}, 
			{ name = "1.618:1 golden ratio", value = point(1618, 1000)}, 
			{ name = "3:2 35mm film", value = point(3, 2)}, 
			{ name = "4:3 legacy TV/monitor", value = point(4, 3)}, 
			{ name = "1:1", value = point(1, 1)}, 
			{ name = "1:2", value = point(1, 2)}, 
			{ name = "1:3", value = point(1, 3)}, 
			{ name = "1:4", value = point(1, 4)}, 
			{ name = "1:5", value = point(1, 5)}, 
		}},
		{ category = "General", id = "UseAllSpace", name = "Use available space", editor = "bool", default = true, },
		{ category = "General", id = "Fit", name = "Fit", editor = "choice", default = "smallest", items = {"none", "width", "height", "smallest", "largest"}, },
	}
}

local box0 = box(0, 0, 0, 0)
---
--- Sets the layout space for an XAspectWindow.
---
--- This function is responsible for setting the layout space of an XAspectWindow, taking into account the aspect ratio and the specified fit mode.
---
--- @param x number The x-coordinate of the layout space.
--- @param y number The y-coordinate of the layout space.
--- @param width number The width of the layout space.
--- @param height number The height of the layout space.
---
function XAspectWindow:SetLayoutSpace(x, y, width, height)
	local fit = self.Fit
	if fit ~= "none" then
		assert(self.Margins == box0)
		assert(self.Padding == box0)
		local aspect_x, aspect_y = self.Aspect:xy()
		local h_align = self.HAlign
		if fit == "smallest" or fit == "largest" then
			local space_is_wider = width * aspect_y >= height * aspect_x
			fit = space_is_wider == (fit == "largest") and "width" or "height"
		end
		if fit == "width" then
			local h = width * aspect_y / aspect_x
			local v_align = self.VAlign
			if v_align == "top" then
			elseif v_align == "center" or v_align == "stretch" then
				y = y + (height - h) / 2
			elseif v_align == "bottom" then
				y = y + (height - h)
			end
			height = h
		elseif fit == "height" then
			local w = height * aspect_x / aspect_y
			local h_align = self.HAlign
			if h_align == "left" then
			elseif h_align == "center" or h_align == "stretch" then
				x = x + (width - w) / 2
			elseif h_align == "right" then
				x = x + (width - w)
			end
			width = w
		end
		self:SetBox(x, y, width, height)
		return
	end
	XWindow.SetLayoutSpace(self, x, y, width, height)
end

---
--- Measures the layout space required for an XAspectWindow, taking into account the aspect ratio and the specified fit mode.
---
--- This function is responsible for calculating the minimum width and height required for an XAspectWindow, based on the provided maximum width and height, and the aspect ratio of the window.
---
--- @param max_width number The maximum width available for the window.
--- @param max_height number The maximum height available for the window.
--- @return number, number The minimum width and height required for the window.
---
function XAspectWindow:Measure(max_width, max_height)
	local aspect_x, aspect_y = self.Aspect:xy()
	local m_width = Min(max_width, max_height * aspect_x / aspect_y)
	local m_height = Min(max_height, max_width * aspect_y / aspect_x)
	local width, height = XWindow.Measure(self, m_width, m_height)
	local min_width = Max(width, height * aspect_x / aspect_y)
	local min_height = Max(height, width * aspect_y / aspect_x)
	if self.UseAllSpace then
		return Max(min_width, m_width), Max(min_height, m_height)
	end
	return min_width, min_height
end


----- XVirtualContent
--
-- Use to embed in XList; does not spawn the controls from its XTemplate until it is visible,
-- thus making lists with 1000s elements perform decently.

---
--- Creates a new XVirtualContent object.
---
--- XVirtualContent is used to embed in XList and does not spawn the controls from its XTemplate until it is visible, thus making lists with 1000s elements perform decently.
---
--- @param parent XWindow The parent window for the XVirtualContent.
--- @param context table The context data for the XVirtualContent.
--- @param xtemplate string The name of the XTemplate to use for the XVirtualContent.
--- @param width number The maximum width of the XVirtualContent.
--- @param height number The maximum height of the XVirtualContent.
--- @param refresh_interval number The interval in milliseconds to refresh the context of the XVirtualContent.
--- @param min_width number The minimum width of the XVirtualContent.
--- @param min_height number The minimum height of the XVirtualContent.
--- @return XVirtualContent The new XVirtualContent object.
---
function NewXVirtualContent(parent, context, xtemplate, width, height, refresh_interval, min_width, min_height)
	local obj = {
		MinWidth = min_width or width or 10,
		MaxWidth = width or 1000000,
		MinHeight = min_height or height or 10,
		MaxHeight = height or 1000000,
		desktop = false,
		parent = false,
		children = false,
		window_state = false,
		box = empty_box,
		content_box = empty_box,
		scale = XWindow.scale,
		xtemplate = xtemplate,
		context = context or false,
		measure_update = true,
		layout_update = true,
		outside_parent = true,
		RefreshInterval = refresh_interval,
	}
	return XVirtualContent:new(obj, parent, context)
end

DefineClass.XVirtualContent = {
	__parents = { "XControl" },
	xtemplate = false,
	spawned = false,
	selected = false,
	RefreshInterval = false,
}

local function UpdateContext(win)
	for _, child in ipairs(win) do
		if IsKindOf(child, "XContextWindow") then
			child:OnContextUpdate(child.context)
		end
		UpdateContext(child)
	end
end

---
--- Spawns the children of the XVirtualContent object based on the provided XTemplate and context.
--- If a RefreshInterval is set, it also creates a thread that periodically updates the context of the children.
---
--- @param self XVirtualContent The XVirtualContent object to spawn the children for.
---
function XVirtualContent:SpawnChildren()
	XTemplateSpawn(self.xtemplate, self, self.context)
	if self.RefreshInterval then
		self:CreateThread("UpdateContext", function(self)
			while true do
				Sleep(self.RefreshInterval)
				UpdateContext(self)
			end
		end, self)
	end
end

---
--- Updates the measure of the XVirtualContent object, taking into account whether the object is spawned or not.
---
--- If the object is not spawned and its measure width or height is not zero, the measure update is disabled to avoid measuring the control incorrectly without its child controls.
---
--- Otherwise, the measure is updated using the XControl.UpdateMeasure function.
---
--- @param self XVirtualContent The XVirtualContent object to update the measure for.
--- @param max_width number The maximum width available for the object.
--- @param max_height number The maximum height available for the object.
---
function XVirtualContent:UpdateMeasure(max_width, max_height)
	-- once measured, don't update measure if the control goes outside the parent (it would be measured wrong without child controls anyway)
	if not self.spawned and (self.measure_width ~= 0 or self.measure_height ~= 0) then
		self.measure_update = false
		return
	end
	XControl.UpdateMeasure(self, max_width, max_height)
end

---
--- Sets whether the XVirtualContent object is outside its parent.
---
--- If the object is set to be outside its parent, it will be spawned or unspawned accordingly.
---
--- @param self XVirtualContent The XVirtualContent object.
--- @param outside_parent boolean Whether the object is outside its parent.
---
function XVirtualContent:SetOutsideParent(outside_parent)
	XWindow.SetOutsideParent(self, outside_parent)
	self:SetSpawned(not outside_parent)
end

---
--- Sets whether the XVirtualContent object is spawned or not.
---
--- If the object is set to be spawned, it will create and open its child controls. If it is set to be unspawned, it will delete its child controls.
---
--- This function also updates the measure and layout of the XVirtualContent object, and sets the child selected state if the object is spawned.
---
--- @param self XVirtualContent The XVirtualContent object.
--- @param spawn boolean Whether the object should be spawned or not.
---
function XVirtualContent:SetSpawned(spawn)
	if self.spawned == spawn then return end
	if not spawn and self.parent.force_keep_items_spawned then return end
	self.spawned = spawn
	
	self.Invalidate = empty_func
	self:DeleteChildren()
	if spawn then
		self:SpawnChildren()
		for _, win in ipairs(self) do
			win:Open()
		end
		self:UpdateMeasure(self.parent.content_box:size():xy())
		self:UpdateLayout()
	else
		self:DeleteThread("UpdateContext")
	end
	self.Invalidate = nil
	if spawn then
		local scrollarea = GetParentOfKind(self, "XScrollArea")
		if scrollarea then
			scrollarea:InvalidateMeasure()
		end
		self:SetChildSelected()
		Msg("XWindowRecreated", self)
	end
	if self.desktop:GetKeyboardFocus() == self then
		self:SetFocus()
	end
end

---
--- Sets the selected state of the XVirtualContent object.
---
--- This function also calls the SetChildSelected function to set the selected state of the child controls.
---
--- @param self XVirtualContent The XVirtualContent object.
--- @param selected boolean Whether the object should be selected or not.
---
function XVirtualContent:SetSelected(selected)
	self.selected = selected
	self:SetChildSelected()
end

---
--- Sets the selected state of the child controls of the XVirtualContent object.
---
--- This function resolves the relative focus order of the first child control, and sets the selected state of the child control if it has a `SetSelected` member function.
---
--- @param self XVirtualContent The XVirtualContent object.
---
function XVirtualContent:SetChildSelected()
	local child = self[1]
	if child then
		child:ResolveRelativeFocusOrder(self.FocusOrder)
		if child:HasMember("SetSelected") then
			child:SetSelected(self.selected)
		end
	end
end

---
--- Sets the focus to the first child control of the XVirtualContent object.
---
--- This function calls the SetFocus function of the first child control, or the XVirtualContent object itself if it has no children.
---
--- @param self XVirtualContent The XVirtualContent object.
---
function XVirtualContent:SetFocus()
	XControl.SetFocus(self[1] or self)
end


----- XSizeConstrainedWindow

--XSizeConstrainedWindows are XWindows that will scale down,
--if they would otherwise exceed their maximum space when measuring.
--Note: avoid assigning margins, as they get scaled as well.
DefineClass.XSizeConstrainedWindow = {
	__parents = { "XWindow" },
}

local one = point(1000, 1000)
---
--- Updates the measure of the XSizeConstrainedWindow object, ensuring it does not exceed the maximum width and height constraints.
---
--- This function first performs a normal measure of the window, allowing the content to fit within the maximum space. If the window has exceeded any of its maximum space constraints, it clears the scale modifier and measures the window again. It then determines which side (width or height) should be constrained, and calculates a new scale modifier to ensure the constrained side is as big as the maximum space in that dimension.
---
--- @param self XSizeConstrainedWindow The XSizeConstrainedWindow object.
--- @param max_width number The maximum width available for the window.
--- @param max_height number The maximum height available for the window.
---
function XSizeConstrainedWindow:UpdateMeasure(max_width, max_height)
	if not self.measure_update then return end
	
	--Normal measure (allow the content to fit within the max space)
	XWindow.UpdateMeasure(self, max_width, max_height)
	
	--If the window has exceeded any of it's maximum space contraints
	if self.measure_width > max_width or self.measure_height > max_height then
		--Before measuring again, the scale must be cleared
		local scale_x, scale_y = self.scale:xy()
		local scale_ratio = MulDivRound(scale_y, 1000, scale_x)
		self:SetScaleModifier(one)
		XWindow.UpdateMeasure(self, max_width, max_height)
		
		--Figure out which side should be contrained (width or height)
		local space_ratio = MulDivRound(max_height, 1000, max_width)
		local measure_ratio = MulDivRound(self.measure_height, 1000, self.measure_width)
		local width_contrained = measure_ratio < space_ratio
		
		--Determine a new scale, such that the contrained side will be as big as the max space in that dimension
		local content_width, content_height = ScaleXY(self.parent.scale, self.measure_width, self.measure_height)
		if width_contrained then
			scale_x = MulDivRound(self.parent.scale:x(), max_width, content_width)
			scale_y = MulDivRound(scale_x, scale_ratio, 1000)
		else
			scale_y = MulDivRound(self.parent.scale:y(), max_height, content_height)
			scale_x = MulDivRound(scale_y, 1000, scale_ratio)
		end
		
		self:SetScaleModifier(point(scale_x, scale_y))
		XWindow.UpdateMeasure(self, max_width, max_height)
	end
end

---
--- Creates a number editor UI element with optional up and down buttons.
---
--- The number editor consists of an XNumberEdit control with optional up and down buttons. The buttons allow the user to increment or decrement the value using the mouse or keyboard shortcuts.
---
--- @param parent XWindow The parent window for the number editor.
--- @param id string The unique identifier for the number editor.
--- @param up_pressed function The function to call when the up button is pressed.
--- @param down_pressed function The function to call when the down button is pressed.
--- @param no_buttons boolean (optional) If true, the up and down buttons will not be created.
--- @return XNumberEdit, XTextButton, XTextButton The number edit control, the top button, and the bottom button.
---
function CreateNumberEditor(parent, id, up_pressed, down_pressed, no_buttons)
	local panel = XWindow:new({ Dock = "box" }, parent)
	local button_panel = XWindow:new({
		Id = "idNumberEditor",
		Dock = "right",
	}, panel)
	local function get_button_multiplier()
		if terminal.IsKeyPressed(const.vkControl) then
			return 10
		elseif terminal.IsKeyPressed(const.vkShift) then
			return 100
		else
			return 1
		end
	end
	local button_rollover_text = "Use LMB, Ctrl+LMB, or Shift+LMB to change the value."
	local top_btn = not no_buttons and XTextButton:new({
		Dock = "top",
		OnPress = function(button) up_pressed(get_button_multiplier()) end,
		Padding = box(1, 2, 1, 1),
		Icon = "CommonAssets/UI/arrowup-40.tga",
		IconScale = point(500, 500),
		IconColor = RGB(0, 0, 0),
		FoldWhenHidden = true,
		DisabledIconColor = RGBA(0, 0, 0, 128),
		Background = RGBA(0, 0, 0, 0),
		DisabledBackground = RGBA(0, 0, 0, 0),
		RolloverBackground = RGB(204, 232, 255),
		PressedBackground = RGB(121, 189, 241),
		RolloverTemplate = "GedPropRollover",
		RolloverText = button_rollover_text,
		RolloverAnchor = "center-top",
	}, button_panel)
	
	local bottom_btn = not no_buttons and XTextButton:new({
		Dock = "bottom",
		OnPress = function(button) down_pressed(get_button_multiplier()) end,
		Padding = box(1, 1, 1, 2),
		Icon = "CommonAssets/UI/arrowdown-40.tga",
		IconScale = point(500, 500),
		IconColor = RGB(0, 0, 0),
		FoldWhenHidden = true,
		DisabledIconColor = RGBA(0, 0, 0, 128),
		Background = RGBA(0, 0, 0, 0),
		DisabledBackground = RGBA(0, 0, 0, 0),
		RolloverBackground = RGB(204, 232, 255),
		PressedBackground = RGB(121, 189, 241),
		RolloverTemplate = "GedPropRollover",
		RolloverText = button_rollover_text,
		RolloverAnchor = "center-bottom",
	}, button_panel)

	local edit = XNumberEdit:new({
		Id = id,
		Dock = "box",
		OnShortcut = function(control, shortcut, ...)
			if shortcut == "Up" then
				up_pressed(1)
			elseif shortcut == "Down" then
				down_pressed(1)
			elseif shortcut == "Ctrl-Up" then
				up_pressed(10)
			elseif shortcut == "Ctrl-Down" then
				down_pressed(10)
			elseif shortcut == "Ctrl-Left" then
				up_pressed(100)
			elseif shortcut == "Ctrl-Right" then
				down_pressed(100)
			else
				return XNumberEdit.OnShortcut(control, shortcut, ...)
			end
			return "break"
		end,
		top_btn = top_btn or nil,
		bottom_btn = bottom_btn or nil,
		OnMouseWheelForward = function() if terminal.IsKeyPressed(const.vkControl) then   up_pressed(1) return "break" end end,
		OnMouseWheelBack    = function() if terminal.IsKeyPressed(const.vkControl) then down_pressed(1) return "break" end end,
		RolloverTemplate = "GedPropRollover",
		RolloverText = "Use arrow keys, Ctrl+arrows, or Ctrl+MouseWheel to change the value.",
	}, panel)
	
	return edit, top_btn, bottom_btn
end