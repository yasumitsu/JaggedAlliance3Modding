if FirstLoad then
UILParamUsage = {}
for i = 0, const.MaxUILParams do
	UILParamUsage[i] = false
end

-- Used by XMap
UILParamUsage[0] = true
UILParamUsage[1] = true

-- Used by Timeline
UILParamUsage[2] = true
UILParamUsage[3] = true
end

---
--- Gets the next available UIL parameter index.
--- If no free UIL parameters are available, it asserts and returns -1.
---
--- @return integer The next available UIL parameter index, or -1 if none are available.
---
function GetUILParam()
	for i, used in ipairs(UILParamUsage) do
		if not used then
			UILParamUsage[i] = true
			return i
		end
	end
	assert(false) -- No free UIL params! Increase MAX_UIL_PARAMS in C
	return -1
end

---
--- Frees a previously allocated UIL parameter.
---
--- @param idx integer The index of the UIL parameter to free.
---
function FreeUILParam(idx)
	assert(UILParamUsage[idx])
	UILParamUsage[idx] = false
end
-------

DefineClass.SmoothBar = {
	__parents = {"XContextWindow"},
	properties = {
		{ category = "Progress", id = "BindTo", name = "BindTo", editor = "text", default = "", },
		{ category = "Progress", id = "MaxValue", name = "MaxValue", editor = "number", default = 1, },
		{ category = "Progress", id = "InterpolationTime", name = "InterpolationTime", editor = "number", default = 100 },
		{ category = "Progress", id = "UpdateTime", name = "UpdateTime", editor = "number", default = 20 },
		{ category = "Progress", id = "FillColor", name = "FillColor", editor = "color", default = "", },
		{ category = "Progress", id = "HideWhenEmpty", name = "HideWhenEmpty", editor = "bool", default = true },
	},

	progress = 0,
	uilParamIdx = -1,

	MaxWidth = 100,
	LayoutMethod = "Box",
	FoldWhenHidden = true,
	
	enabled = "unset"
}

---
--- Opens the SmoothBar window and sets its visibility based on the HideWhenEmpty property.
---
--- @param self SmoothBar The SmoothBar instance.
---
function SmoothBar:Open()
	XContextWindow.Open(self)
	if self.HideWhenEmpty then
		self:SetVisible(false)
	end
	self:SetEnabled(true)
end

---
--- Ensures that a UIL parameter is allocated for the SmoothBar instance.
---
--- If the `uilParamIdx` property is set to -1, indicating that no UIL parameter has been allocated yet,
--- this function will call `GetUILParam()` to allocate a new UIL parameter and store its index in the `uilParamIdx` property.
---
--- This function is typically called before updating the visual representation of the SmoothBar, to ensure that
--- a UIL parameter is available for setting the progress value.
---
function SmoothBar:EnsureUILParam()
	if self.uilParamIdx == -1 then
		self.uilParamIdx = GetUILParam()
	end
end

---
--- Frees the UIL parameter associated with the SmoothBar instance.
---
--- If the `uilParamIdx` property is not set to -1, indicating that a UIL parameter has been allocated,
--- this function will call `FreeUILParam()` to release the UIL parameter and set the `uilParamIdx` property to -1.
---
--- This function is typically called when the SmoothBar instance is being deleted or disabled, to ensure
--- that the allocated UIL parameter is properly freed.
---
--- @param self SmoothBar The SmoothBar instance.
---
function SmoothBar:FreeUILParam()
	if self.uilParamIdx ~= -1 then
		FreeUILParam(self.uilParamIdx)
		self.uilParamIdx = -1
	end
end

---
--- Frees the UIL parameter associated with the SmoothBar instance.
---
--- This function is typically called when the SmoothBar instance is being deleted or disabled, to ensure
--- that the allocated UIL parameter is properly freed.
---
--- @param self SmoothBar The SmoothBar instance.
---
function SmoothBar:OnDelete()
	self:FreeUILParam()
end

---
--- Gets the bound property value for the SmoothBar instance.
---
--- If the `context` property is set and has a member matching the `BindTo` property, this function
--- will return the value of that member. Otherwise, it will return `nil`.
---
--- This function is typically called to retrieve the value that the SmoothBar should display as its progress.
---
--- @param self SmoothBar The SmoothBar instance.
--- @return number|nil The bound property value, or `nil` if the property is not found.
---
function SmoothBar:GetBoundPropValue()
	local context = self.context
	if not context or not context:HasMember(self.BindTo) then return end
	return context[self.BindTo]
end

---
--- Updates the visual representation of the SmoothBar based on the provided value.
---
--- This function is responsible for setting the UIL parameter that controls the progress bar's visual appearance.
--- It also handles the visibility of the SmoothBar based on the current progress value and other conditions.
---
--- @param self SmoothBar The SmoothBar instance.
--- @param value number The new progress value to be displayed.
--- @param first boolean (optional) Indicates whether this is the first update (used for interpolation).
---
function SmoothBar:UpdateVisual(value, first)
	self.progress = value or self:GetBoundPropValue() or 0
	self.progress = Min(self.progress, self.MaxValue)
	UIL.SetParam(self.uilParamIdx, MulDivRound(self.progress, 1000, self.MaxValue), 1000, first and 0 or self.InterpolationTime)

	local shouldBeVisible = self.progress ~= 0 or not self.HideWhenEmpty
	local combatActionInProgress = HasCombatActionInProgress(self.context) and not self.context:IsInterruptableMovement()
	
	shouldBeVisible = shouldBeVisible and not combatActionInProgress

	self:DeleteThread("hide")
	if not shouldBeVisible then
		if combatActionInProgress then
			self:SetVisible(false)
			return
		end
	
		self:CreateThread("hide", function()
			Sleep(self.InterpolationTime)
			self:SetVisible(false)
		end)
	else
		self:SetVisible(true)
	end
end

---
--- Sets the enabled state of the SmoothBar.
---
--- When enabled, the SmoothBar will update its visual representation based on the bound property value.
--- When disabled, the SmoothBar will be hidden and its UIL parameter will be freed.
---
--- @param self SmoothBar The SmoothBar instance.
--- @param enabled boolean The new enabled state of the SmoothBar.
---
function SmoothBar:SetEnabled(enabled)
	if enabled == self.enabled then
		return
	end

	self.enabled = enabled
	self:DeleteThread("UpdateBar")
	if not enabled then
		self:SetVisible(false)
		self:FreeUILParam()
		return
	end

	self:EnsureUILParam()
	if enabled then
		self:AddInterpolation{
			id = "progress",
			type = const.intParamRect,
			translationConstant = self.box:min(),
			scaleParam = self.uilParamIdx,
			OnLayoutComplete = function(modifier, window)
				modifier.translationConstant = window.box:min()
			end
		}
		UIL.SetParam(self.uilParamIdx, 0, 1000, 0)
		local propVal = self:GetBoundPropValue()
		self:UpdateVisual(propVal, true)
		
		self:CreateThread("UpdateBar", function()
			local propVal = self:GetBoundPropValue()
			self:UpdateVisual(propVal)

			while self.window_state ~= "destroying" do
				local propVal = self:GetBoundPropValue() or 0
				if propVal ~= self.progress then
					self:UpdateVisual(propVal)
				end
				WaitFramesOrSleepAtLeast(1, 10)
			end
		end)
	end
end

local UIL = UIL
local irOutside = const.irOutside
---
--- Draws the window for the SmoothBar UI element.
---
--- @param self SmoothBar The SmoothBar instance.
--- @param clip_box table The clipping box for the window.
---
function SmoothBar:DrawWindow(clip_box)
	local myBox = self.box
	if myBox:sizex() == 0 then return end
	
	local border = self.BorderWidth
	local background = self:CalcBackground()
	if background ~= 0 then
		UIL.DrawBorderRect(myBox, self.BorderWidth, self.BorderWidth, self:CalcBorderColor(), background)
	end

	XContextWindow.DrawWindow(self, clip_box)
end

---
--- Draws the fill color of the SmoothBar UI element.
---
function SmoothBar:DrawContent()
	UIL.DrawSolidRect(self.box, self.FillColor)
end