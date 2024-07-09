local hintColor = RGB(210, 255, 210)


----- ContinuousEffect

DefineClass.ContinuousEffect = {
	__parents = { "Effect" },
	properties = {
		{ id = "Id", editor = "text", help = "A unique Id allowing you to later stop this effect using StopEffect/StopGlobalEffect; optional", default = "",
		  no_edit = function(obj) return obj.Id:starts_with("autoid") end,
		},
	},
	CreateInstance = false,
	EditorExcludeAsNested = true,
	container = false, -- restored in ModifiersPreset:PostLoad(), won't be valid if the ContinuousEffect is not stored in a ModifiersPreset
}

---
--- Executes the continuous effect on the given object.
---
--- @param object ContinuousEffectContainer The object to apply the continuous effect to.
--- @param ... any Additional arguments to pass to the effect.
---
function ContinuousEffect:Execute(object, ...)
	self:ValidateObject(object)
	assert(IsKindOf(object, "ContinuousEffectContainer"))
	object:StartEffect(self, ...)
end

if FirstLoad then
	g_MaxContinuousEffectId = 0
end

---
--- Initializes a new ContinuousEffect instance when it is created in the editor.
---
--- This method is called when a new ContinuousEffect is created in the editor. It sets the Id property of the ContinuousEffect based on whether it is embedded in another ContinuousEffect or part of a mod.
---
--- @param parent any The parent object of the ContinuousEffect.
--- @param ged any The GedEditor instance.
--- @param is_paste boolean Whether the ContinuousEffect was pasted from another location.
---
function ContinuousEffect:OnEditorNew(parent, ged, is_paste)
	-- ContinuousEffects embedded in a parent ContinuousEffect are managed by
	-- the parent effect and have an auto-generated internal uneditable Id
	local obj = ged:GetParentOfKind(parent, "PropertyObject")
	if obj and (obj:IsKindOf("ContinuousEffect") or obj:HasMember("ManagesContinuousEffects") and obj.ManagesContinuousEffects) then
		g_MaxContinuousEffectId = g_MaxContinuousEffectId + 1
		self.Id = "autoid" .. tostring(g_MaxContinuousEffectId)
	elseif self.Id:starts_with("autoid") then
		self.Id = ""
	elseif ged.app_template:starts_with("Mod") then
		local mod_item = IsKindOf(parent, "ModItem") and parent or ged:GetParentOfKind(parent, "ModItem")
		local mod_def = mod_item.mod
		self.Id = mod_def:GenerateModItemId(self)
	end
	self.container = obj
end

---
--- Deserializes a ContinuousEffect object from a Lua table.
---
--- This method is called when a ContinuousEffect is deserialized from a Lua table. It sets the `Id` property of the ContinuousEffect based on whether it was auto-generated or part of a mod.
---
--- @param table table The Lua table to deserialize the ContinuousEffect from.
--- @return ContinuousEffect The deserialized ContinuousEffect object.
---
function ContinuousEffect:__fromluacode(table)
	local obj = Effect.__fromluacode(self, table)
	local id = obj.Id
	if id:starts_with("autoid") then
		g_MaxContinuousEffectId = Max(g_MaxContinuousEffectId, tonumber(id:sub(7, -1)))
	end
	return obj
end

---
--- Serializes a ContinuousEffect object to a Lua table.
---
--- This method is called when a ContinuousEffect is serialized to a Lua table. It temporarily sets the `container` property to `nil` to avoid serializing it, then restores it after the serialization is complete.
---
--- @param ... any Additional arguments passed to the serialization function.
--- @return table The serialized Lua table representation of the ContinuousEffect.
---
function ContinuousEffect:__toluacode(...)
	local old = self.container
	self.container = nil -- restored in ModifiersPreset:PostLoad()
	local ret = Effect.__toluacode(self, ...)
	self.container = old
	return ret
end


----- ContinuousEffectDef

DefineClass.ContinuousEffectDef = {
	__parents = { "EffectDef" },
	group = "ContinuousEffects",
	DefParentClassList = { "ContinuousEffect" },
	GedEditor = "ClassDefEditor",
}

---
--- Initializes a new `ContinuousEffectDef` instance.
---
--- This method is called when a new `ContinuousEffectDef` instance is created in the editor. It removes any existing `Execute` or `__exec` methods, and adds new `OnStart` and `OnStop` methods, as well as a `CreateInstance` constant.
---
--- @param parent any The parent object of the `ContinuousEffectDef`.
--- @param ged any The GED (Graphical Editor Definition) object associated with the `ContinuousEffectDef`.
--- @param is_paste boolean Whether the `ContinuousEffectDef` is being pasted from the clipboard.
---
function ContinuousEffectDef:OnEditorNew(parent, ged, is_paste)
	if is_paste then return end

	-- remove Execute/__exec metod
	for i = #self, 1, -1 do
		if IsKindOf(self[i], "ClassMethodDef") and (self[i].name == "Execute" and self[i].name == "__exec" )then
			table.remove(self, i)
			break
		end	
	end
	-- add CreateInstance, Start, Stop, and Id
	local idx = #self + 1
	self[idx] = self[idx] or ClassMethodDef:new{ name = "OnStart", params = "obj, context"}
	idx = idx + 1
	self[idx] = self[idx] or ClassMethodDef:new{ name = "OnStop", params = "obj, context"}
	table.insert(self, 1, ClassConstDef:new{ id = "CreateInstance", name = "CreateInstance" , type = "bool", })
end

---
--- Checks if the `ContinuousEffectDef` has valid `Start` and `Stop` methods defined.
---
--- This method is used to validate the `ContinuousEffectDef` and ensure that the necessary `Start` and `Stop` methods are implemented.
---
--- @return table|nil If the `Start` or `Stop` methods are missing or invalid, returns a table with a hint message and the indices of the problematic methods. Otherwise, returns `nil`.
---
function ContinuousEffectDef:CheckExecMethod()
	local start = self:FindSubitem("Start")
	local stop = self:FindSubitem("Stop")
	if start and (start.class ~= "ClassMethodDef" or start.code == ClassMethodDef.code)  or 
		stop and (stop.class ~= "ClassMethodDef" or stop.code == ClassMethodDef.code) then
		return {[[--== Start & Stop ==--
Add Start and Stop methods that implement the effect. 
]], hintColor, table.find(self, start), table.find(self, stop) }
	end
end

---
--- Checks if the `ContinuousEffectDef` has the required `CreateInstance` constant defined.
---
--- This method is used to validate the `ContinuousEffectDef` and ensure that the `CreateInstance` constant is present.
---
--- @return string|nil If the `CreateInstance` constant is missing, returns an error message. Otherwise, returns `nil`.
---
function ContinuousEffectDef:GetError()
	local id = self:FindSubitem("CreateInstance")
	if not id then
		return "The CreateInstance constant is required for ContinuousEffects."
	end
end


----- ContinuousEffectContainer

DefineClass.ContinuousEffectContainer = {
	__parents = {"InitDone"},
	effects = false,	
}

---
--- Cleans up the ContinuousEffectContainer by stopping all active effects.
---
--- This method is called when the ContinuousEffectContainer is being destroyed or reset.
--- It iterates through all the active effects and calls their `OnStop` method, then clears the `effects` table.
---
function ContinuousEffectContainer:Done()
	for _, effect in ipairs(self.effects or empty_table) do
		effect:OnStop(self)
	end
	self.effects = false
end

---
--- Starts a continuous effect in the ContinuousEffectContainer.
---
--- If an effect with the same ID already exists, it will be stopped before the new effect is started.
--- If the effect has a `CreateInstance` property, a new instance of the effect will be created before starting it.
--- The effect's `OnStart` method will be called with the ContinuousEffectContainer and the provided context.
---
--- @param effect ContinuousEffectDef|string The effect to start, or the ID of the effect to start.
--- @param context table Any additional context to pass to the effect's `OnStart` method.
---
function ContinuousEffectContainer:StartEffect(effect, context)
	self.effects = self.effects or {}
	
	local id = effect.Id or ""
	if id == "" then
		id = effect
	end
	if self.effects[id] then
		-- TODO: Add an AllowReplace property and assert whether AllowReplace is true?
		self:StopEffect(id)
	end
	if effect.CreateInstance then
		effect = effect:Clone()
	end
	self.effects[id] = effect
	self.effects[#self.effects + 1] = effect
	effect:OnStart(self, context)
	Msg("OnEffectStarted", self, effect)
	assert(effect.CreateInstance or not effect:HasNonPropertyMembers()) -- please set the CreateInstance class constant to 'true' to use dynamic members
end

---
--- Stops a continuous effect in the ContinuousEffectContainer.
---
--- If the effect with the given ID exists, its `OnStop` method is called and the effect is removed from the `effects` table.
--- A "OnEffectEnded" message is sent after the effect is stopped.
---
--- @param id string The ID of the effect to stop.
---
function ContinuousEffectContainer:StopEffect(id)
	if not self.effects then return end
	local effect = self.effects[id]
	if not effect then return end
	effect:OnStop(self)
	table.remove_entry(self.effects, effect)
	self.effects[id] = nil
	Msg("OnEffectEnded", self, effect)
end

----- InfopanelMessage Effects

MapVar("g_AdditionalInfopanelSectionText", {})
---
--- Gets the additional infopanel section text for the given section ID and object.
---
--- If the section ID is not provided or is an empty string, an empty string is returned.
--- If the section does not exist or has no text, an empty string is returned.
--- The text is returned as a concatenated string, with each label's text separated by a newline.
--- If the object matches the label (or the label is "__AllSections"), the text for that label is included.
---
--- @param sectionId string The ID of the infopanel section to get the text for.
--- @param obj table The object to check the labels against.
--- @return string The concatenated additional infopanel section text.
---
function GetAdditionalInfopanelSectionText(sectionId, obj)
	-- Implementation details
end
function GetAdditionalInfopanelSectionText(sectionId, obj)	
	if not sectionId or sectionId=="" then
		return ""
	end	
	local section = g_AdditionalInfopanelSectionText[sectionId]
	if not section or not next(section) then 
		return ""
	end
	local texts = {}
	for label, text in pairs(section) do
		if label== "__AllSections" or IsKindOf(obj, label) then
			texts[#texts + 1] = text
		end
	end
	if not next(texts)then 
		return ""
	end
	return table.concat(texts, "\n")
end

---
--- Adds additional text to an infopanel section.
---
--- @param sectionId string The ID of the infopanel section to add text to.
--- @param label string (optional) The label to associate the text with. If not provided, defaults to "__AllSections".
--- @param text string The text to add to the infopanel section.
--- @param color string (optional) The color of the text. Can be "red", "green", or any other valid CSS color.
--- @param object table (optional) The object to associate the text with.
--- @param context table (optional) Additional context to include in the text.
---
function AddAdditionalInfopanelSectionText(sectionId, label, text, color, object, context)
	local style = "Infopanel"
	if color == "red" then
		style = "InfopanelError"
	elseif	color == "green" then
		style = "InfopanelBonus"	
	end
	local section = g_AdditionalInfopanelSectionText[sectionId] or {}
	label = label or "__AllSections"
	section[label] =  T{410957252932, "<textcolor><text></color>", textcolor = "<color " .. style .. ">", text = T{text, object, context}}	
	g_AdditionalInfopanelSectionText[sectionId] = section
end

---
--- Removes additional text from an infopanel section.
---
--- @param sectionId string The ID of the infopanel section to remove text from.
--- @param label string (optional) The label to associate the text with. If not provided, defaults to "__AllSections".
---
function RemoveAdditionalInfopanelSectionText(sectionId, label)
	if g_AdditionalInfopanelSectionText[sectionId] then
		label = label or "__AllSections"
		g_AdditionalInfopanelSectionText[sectionId][label]= nil
	end
end
