----- XContextWindow
-- Any lua value can be context of the window.
-- When the value or in case of a composite context any of the internal values are modified the window receives OnContextUpdate call.

DefineClass.XContextWindow = {
	__parents = { "XWindow" },
	properties = {
		{ category = "Interaction", id = "ContextUpdateOnOpen", editor = "bool", default = false, },
		{ category = "Interaction", id = "OnContextUpdate", editor = "func", params = "self, context, ...", },
	},
	context = false,
}

--- Initializes a new XContextWindow instance.
---
--- @param parent table The parent window of this XContextWindow instance.
--- @param context any The initial context of this XContextWindow instance. If provided, the context will be set using `self:SetContext(context, false)`.
function XContextWindow:Init(parent, context)
	if context then
		self:SetContext(context, false)
	end
end

---
--- Marks the XContextWindow as no longer having a context.
---
--- @param self XContextWindow The XContextWindow instance.
function XContextWindow:Done()
	self:SetContext(nil, false)
end

---
--- Opens the XContextWindow and optionally triggers the OnContextUpdate callback if ContextUpdateOnOpen is true.
---
--- @param self XContextWindow The XContextWindow instance.
--- @param ... any Additional arguments to pass to the XWindow.Open function.
function XContextWindow:Open(...)
	XWindow.Open(self, ...)
	if self.ContextUpdateOnOpen then
		procall(self.OnContextUpdate, self, self.context, "open")
	end
end

---
--- Callback function that is called when the context of the XContextWindow is updated.
---
--- @param self XContextWindow The XContextWindow instance.
--- @param context any The new context of the window.
--- @param ... any Additional arguments passed to the callback.
function XContextWindow:OnContextUpdate(context, ...)
end

--- Returns the context of the XContextWindow instance.
---
--- @param self XContextWindow The XContextWindow instance.
--- @return any The context of the XContextWindow instance.
function XContextWindow:GetContext()
	return self.context
end

---
--- Returns the context of the parent window of this XContextWindow instance.
---
--- @param self XContextWindow The XContextWindow instance.
--- @return any The context of the parent window, or nil if there is no parent window.
function XContextWindow:GetParentContext()
	local parent = self.parent
	if parent then
		return parent:GetContext()
	end
end

---
--- Sets the context of the XContextWindow instance.
---
--- @param self XContextWindow The XContextWindow instance.
--- @param context any The new context of the window.
--- @param update boolean|string Whether to trigger the OnContextUpdate callback. Can be a string to specify the update type.
function XContextWindow:SetContext(context, update)
	if self.context == (context or false) and not update then return end
	ForEachObjInContext(self.context, function (obj, self)
		local windows = ObjToWindows[obj]
		if windows then
			table.remove_entry(windows, self)
			if #windows == 0 then
				ObjToWindows[obj] = nil
			end
		end
	end, self)
	self.context = context
	ForEachObjInContext(context, function (obj, self)
		local windows = ObjToWindows[obj]
		if windows then
			windows[#windows + 1] = self
		else
			ObjToWindows[obj] = { self }
		end
	end, self)
	if update ~= false then
		procall(self.OnContextUpdate, self, context, update or "set")
	end
end

--[[function XContextWindow:ResolveValue(id)
	local value = ResolveValue(self.context, id)
	if value ~= nil then return value end
	return PropertyObject.ResolveValue(self, id)
end]]


----- globals

if FirstLoad then
	ObjToWindows = setmetatable({}, weak_keys_meta)
	XContextUpdateLogging = false
end

---
--- Updates the context of all XContextWindow instances that are associated with the given context.
---
--- @param context any The context to update.
--- @param ... any Additional arguments to pass to the OnContextUpdate callback.
---
function XContextUpdate(context, ...)
	if not context then return end
	for _, window in ipairs(ObjToWindows[context] or empty_table) do
		if XContextUpdateLogging then
			print("ContextUpdate:", FormatWindowPath(window))
		end
		procall(window.OnContextUpdate, window, window.context, ...)
	end
end

function OnMsg.ObjModified(obj)
	XContextUpdate(obj, "modified")
end

