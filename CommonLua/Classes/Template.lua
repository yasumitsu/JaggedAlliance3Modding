DefineClass.Template =
{
	-- It currently inherits CObject because that's all the editor will currently show in default brush mode
	__parents = { "Shapeshifter", "EditorVisibleObject", "EditorTextObject", "EditorCallbackObject" },
	entity = "WayPoint",
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false },

	properties = {
		{ id = "TemplateOf", category = "Template", editor = "combo", default = "", important = true, items = function(self) return self:GetTemplatesList() end },
		{ id = "autospawn", category = "Template", name = "Autospawn", editor = "bool", default = true },
		{ id = "EditorLabel", category = "Template", editor = "text", default = "", no_edit = true },
		{ id = "Opacity" },
		{ id = "LastSpawnedObject", category = "Template", name = "Last Spawned Object", editor = "object", default = false, read_only = true, dont_save = true },
		{ id = "RemainingHandles", category = "Template", name = "Remaining Handles", editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "SpawnCount", category = "Template", name = "Spawned Objects", editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "template_root", category = "Template", name = "Root Class", editor = "text", read_only = true, dont_save = true },
	},

	template_root = "CObject", -- must be set by descendants

	Walkable = false,
	Collision = false,
	ApplyToGrids = false,

	reserved_handles = 10,
	
	editor_text_color = RGB(128,192,128),
	editor_text_member = "TemplateOf",
}

-- template functions
--- Initializes the Template object by setting its opacity to 65.
-- This function is called during the initialization of the Template object.
-- It sets the opacity property of the object to 65, which determines the transparency of the object.
-- @function Template:Init
-- @return nil
function Template:Init()
	self:SetOpacity(65)
end

--- Returns the last spawned object for this Template.
-- @function Template:GetLastSpawnedObject
-- @return table|nil The last spawned object, or nil if no objects have been spawned.
function Template:GetLastSpawnedObject()
	return TemplateSpawn[self]
end

--- Returns the number of remaining handles available for this Template object.
-- The Template object maintains a pool of reserved handles that can be used to spawn objects.
-- This function checks how many of those reserved handles are currently available (not in use).
-- @function Template:GetRemainingHandles
-- @return number The number of remaining available handles for this Template.
function Template:GetRemainingHandles()
	local count = 0
	for i=self.handle+1, self.handle+self.reserved_handles do	
		if not HandleToObject[i] then
			count = count + 1
		end
	end
	return count
end

--- Returns the number of objects that have been spawned from this Template.
-- The Template object maintains a pool of reserved handles that can be used to spawn objects.
-- This function calculates the number of spawned objects by subtracting the number of remaining available handles from the total number of reserved handles.
-- @function Template:GetSpawnCount
-- @return number The number of objects that have been spawned from this Template.
function Template:GetSpawnCount()
	return self.reserved_handles - self:GetRemainingHandles()
end

local TemplatesListCache = {}
function OnMsg.ClassesBuilt()
	 TemplatesListCache = {}
end
--- Returns a list of all Template classes that inherit from the current Template's template_root.
-- This function caches the result of the lookup to improve performance.
-- The lookup filters out any non-instantiatable classes or classes that end with "impl".
-- @function Template:GetTemplatesList
-- @return table A table containing all Template classes that inherit from the current Template's template_root.
function Template:GetTemplatesList()
	if TemplatesListCache[self.template_root] then
		return TemplatesListCache[self.template_root]
	end
	-- Get all classes that inherit from template_root
	-- WARNING: It will get non-instantiatable classes as well!
	local cache = ClassDescendantsList(self.template_root, function(name, class)
		return class:GetEntity() ~= "" and IsValidEntity(class:GetEntity()) and not name:ends_with("impl", true)
	end)
	TemplatesListCache[self.template_root] = cache
	return cache
end

local template_props = {}
--- Checks if the given property ID is a template property.
-- The Template class maintains a list of its properties, and this function checks if the given property ID is one of those properties.
-- The results of this lookup are cached to improve performance.
-- @function Template:IsTemplateProperty
-- @param string id The property ID to check.
-- @return boolean True if the given property ID is a template property, false otherwise.
function Template:IsTemplateProperty(id)
	local props = template_props[self.class]
	if not props then
		props = {}
		template_props[self.class] = props
		for i = 1, #self.properties do
			props[self.properties[i].id] = true
		end
	end
	return props[id]
end

--- Sets the properties of the Template object.
-- This function takes a table of property values and applies them to the Template object.
-- If the `TemplateOf` property is set, it first verifies that the specified template class exists.
-- It then iterates through all the properties of the Template and sets the corresponding values from the provided table.
-- Properties that are not present in the provided table are not modified.
-- @function Template:SetProperties
-- @param table values A table of property values to set on the Template.
-- @return nil
function Template:SetProperties(values)
	local template = values.TemplateOf
	if template then
		assert(g_Classes[template], "Invalid template class")
		self:SetProperty("TemplateOf", template)
	end
	
	local props = self:GetProperties()
	for i = 1, #props do
		local id = props[i].id
		local value = values[id]
		if value ~= nil and id ~= "TemplateOf" then
			self:SetProperty(id, value)
		end
	end
end

---
--- Gets the properties of the Template object.
--- This function returns a table of all the properties defined for the Template object, including any properties inherited from the template class specified by the `TemplateOf` property.
--- The `TemplateOf` property is moved to the beginning of the properties table, and any properties from the template class that are not already defined in the Template object are added to the end of the properties table.
--- @return table The properties of the Template object.
---
function Template:GetProperties()
	local template_class = g_Classes[(self.TemplateOf or "") ~= "" and self.TemplateOf or self.template_root]
	local properties = table.copy(self.properties)

	-- move TemplateOf first (it should be at least before StateText property)
	local idx = table.find(properties, "id", "TemplateOf")
	local prop = properties[idx]
	table.remove(properties, idx)
	table.insert(properties, 1, prop)

	local properties2 = template_class:GetProperties()
	for i = 1, #properties2 do
		local p = properties2[i]
		local id = p.id
		if id == "Opacity" then
			-- ignore it
		else
			local template_prop_idx = table.find(properties, "id", id)
			if template_prop_idx then
				if id == "ColorModifier" then
					properties[template_prop_idx] = p
				end
			else
				if (p.editor == "combo" or p.editor == "dropdownlist" or p.editor == "set") and type(p.items) == "function" then
					p = table.copy(p)
					local func = p.items
					p.items = function(o, editor)
						return func(o, editor)
					end
				end
				properties[#properties + 1] = p
			end
		end
	end
	return properties
end

---
--- Gets the default property value for the specified property of the Template object.
--- If the property is not a template property, the default value is retrieved from the template class specified by the `TemplateOf` property.
--- If the property is one of `ApplyToGrids`, `Collision`, or `Walkable`, the default value is retrieved using the `GetClassEnumFlags` function.
--- Otherwise, the default property value is retrieved using the `GetDefaultPropertyValue` function of the `CObject` class.
--- @param prop string The name of the property.
--- @param prop_meta table The metadata for the property.
--- @return any The default property value.
---
function Template:GetDefaultPropertyValue(prop, prop_meta)
	if not self:IsTemplateProperty(prop) then
		local class = g_Classes[self.TemplateOf]
		if class then
			return class:GetDefaultPropertyValue(prop, prop_meta)
		end
	end
	if prop == "ApplyToGrids" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efApplyToGrids)
	elseif prop == "Collision" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efCollision)
	elseif prop == "Walkable" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efWalkable)
	end
	return CObject.GetDefaultPropertyValue(self, prop, prop_meta)
end

local function TransferValue(class, prop_meta, prev_class, prev_value)
	local prev_prop_meta = prev_class:GetPropertyMetadata(prop_meta.id)
	if prev_prop_meta and prev_prop_meta.editor == prop_meta.editor then
		if not prop_meta.items then return prev_value end

		local items = prop_meta.items
		if type(items) == "function" then items = items(class) end
		if type(items) == "table" then
			for i = 1, #items do
				local item = items[i]
				if item == prev_value or type(item) == "table" and item.value == prev_value then
					return prev_value
				end
			end
		end
	end
end

-- invoked from the editor; transfers as much info as possible
---
--- Sets the template class for the current Template object.
--- If the specified class is not valid or does not inherit from the template root class, an error is thrown.
--- If a previous template class was set, the default property values from that class are removed to prevent them from being transferred to the new template class.
--- The entity, collision flags, and walkable flags are reset to the defaults for the new template class.
--- If a previous template class was set, any non-template properties that were not the default value for the previous class are transferred to the new class using the `TransferValue` function.
--- @param classname string The name of the new template class.
---
function Template:SetTemplateOf(classname)
	local prev_class = g_Classes[self.TemplateOf]
	local class = g_Classes[classname]
	assert(class and class:IsKindOf(self.template_root) or classname == "WayPoint", "Invalid template class: " .. classname)
	if not class then
		return
	end

	if prev_class then
		-- remove default property values so they're not transfered to the new template class
		local props = prev_class.properties
		for i = 1, #props do
			local prop_meta = props[i]
			local prop = prop_meta.id
			if not self:IsTemplateProperty(prop) then
				local value = rawget(self, prop)
				if value ~= nil and prev_class:IsDefaultPropertyValue(prop, prop_meta, value) then
					self[prop] = nil
				end
			end
		end
	end

	self.TemplateOf = classname
	self:DestroyAttaches()

	local entity = class:GetEntity()
	if entity == "" then entity = Template.entity end
	self:ChangeEntity(entity)
	-- reset collision flags to their defaults for the new class
	self.ApplyToGrids = GetClassEnumFlags(classname, const.efApplyToGrids)
	self.Collision = GetClassEnumFlags(classname, const.efCollision)
	self.Walkable = GetClassEnumFlags(classname, const.efWalkable)

	if prev_class then
		local props = class.properties
		for i = 1, #props do
			local prop_meta = props[i]
			local prop = prop_meta.id

			if not self:IsTemplateProperty(prop) then
				local value = rawget(self, prop)
			
				if value ~= nil then
					self[prop] = TransferValue(class, prop_meta, prev_class, value)
				end
			end
		end
	end
end

---
--- Callback function called when the Template object is placed in the editor.
--- This function sets the TemplateOf property to a default value if it is not already set,
--- then randomizes the properties and applies them to the Template object.
---
--- @function Template:EditorCallbackPlace
--- @return nil
function Template:EditorCallbackPlace()
	if not self.TemplateOf then
		if self.template_root == "CObject" then
			self:SetTemplateOf("WayPoint")
		else
			local list = self:GetTemplatesList()
			if list and #list > 0 then
				self:SetTemplateOf(list[1])
			else
				self:SetTemplateOf("WayPoint")
			end
		end
	end
	self:RandomizeProperties()
	self:TemplateApplyProperties()
end

---
--- Callback function called when the Template object is cloned in the editor.
--- This function randomizes the properties of the cloned Template object and applies them.
---
--- @function Template:EditorCallbackClone
--- @return nil
function Template:EditorCallbackClone()
	assert(g_Classes[self.TemplateOf])
	self:RandomizeProperties()
	self:TemplateApplyProperties()
end

---
--- Callback function called when a property of the Template object is set in the editor.
--- This function clears the Template's properties, then re-applies them.
--- If the "TemplateOf" property is set, it notifies that the object has been modified.
---
--- @function Template:OnEditorSetProperty
--- @param prop_id string The ID of the property that was set
--- @return nil
function Template:OnEditorSetProperty(prop_id)
	assert(g_Classes[self.TemplateOf])
	self:TemplateClearProperties()
	self:TemplateApplyProperties()
	if prop_id == "TemplateOf" then
		ObjModified(self)
	end
end

---
--- Turns a list of Template objects into their corresponding game objects.
---
--- @param list table A list of Template objects to be turned into game objects.
--- @return table The updated list with Template objects replaced by their corresponding game objects.
function Template.TurnTemplatesIntoObjects(list)
	local listOfObjsToDestroy = {}
	for i = 1, #list do
		local t = list[i]
		if t:IsKindOf("Template") then
			local obj = t:Spawn()
			if obj then
				obj:SetGameFlags(const.gofPermanent)
				list[i] = obj
				table.insert(listOfObjsToDestroy,t)
			end
		end
	end
	DoneObjects(listOfObjsToDestroy)
	return list
end

g_convert_template_order = { "Template" }
---
--- Turns a list of game objects into their corresponding Template objects.
---
--- @param list table A list of game objects to be turned into Template objects.
--- @return table The updated list with game objects replaced by their corresponding Template objects.
function Template.TurnObjectsIntoTemplates(list)
	local listOfObjsToDestroy = {}
	for i = 1, #list do
		local o = list[i]
		local template_class
		if not o:IsKindOf("Template") and o:GetGameFlags(const.gofPermanent) ~= 0 then
			for j = 1, #g_convert_template_order do
				local template_class = g_convert_template_order[j]
				if o:IsKindOf(g_Classes[template_class].template_root) then
					local template = PlaceObject(template_class)
					template:SetTemplateOf(o.class)
					template:CopyProperties(o)
					-- Boilerplate Stuff
					template:SetEnumFlags(const.efVisible)
					template:SetGameFlags(const.gofPermanent)
					template.SpawnCheckpoint = "Start"
					template:TemplateApplyProperties()
					list[i] = template
					table.insert(listOfObjsToDestroy,o)
					break
				end
			end
		end
	end
	DoneObjects(listOfObjsToDestroy)
	return list
end

---
--- Gets the value of the specified property.
---
--- If the property is a template property, it will return the value from the `PropertyObject` class.
--- Otherwise, it will return the value of the property directly from the template object.
--- If the property is not found on the template object, it will return the default property value from the template class.
---
--- @param property string The name of the property to get.
--- @return any The value of the specified property.
function Template:GetProperty(property)
	if self:IsTemplateProperty(property) then
		return PropertyObject.GetProperty(self, property)
	end
	local value = rawget(self, property)
	if value ~= nil then
		return value
	end
	local class = g_Classes[self.TemplateOf]
	if class then
		return class:GetDefaultPropertyValue(property)
	end
end

---
--- Sets the value of the specified property on the template object.
---
--- If the property is a template property, it will set the value in the `PropertyObject` class.
--- Otherwise, it will set the value of the property directly on the template object.
---
--- @param property string The name of the property to set.
--- @param value any The value to set for the property.
--- @return boolean True if the property was set successfully, false otherwise.
function Template:SetProperty(property, value)
	if self:IsTemplateProperty(property) then
		return PropertyObject.SetProperty(self, property, value)
	end
	self[property] = value
	return true
end

---
--- Clears the properties of the template object by pretending to be an instance of the template class.
---
--- This method is called when the template object needs to have its properties cleared, such as when the template is being destroyed or reset.
---
--- @param self Template The template object to clear the properties of.
function Template:TemplateClearProperties()
	local template_class = g_Classes[self.TemplateOf]
	if template_class and template_class:HasMember("TemplateClearProperties") then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self:TemplateClearProperties(template_class)
		setmetatable(self, old_meta) -- return to being a template again
	end
end

---
--- Applies the properties of the template to the object that is being spawned from the template.
---
--- This method is called when the template object needs to have its properties applied to the spawned object, such as when the template is being entered in the editor.
---
--- @param self Template The template object to apply the properties to.
function Template:TemplateApplyProperties()
	local template_class = g_Classes[self.TemplateOf]
	if template_class and template_class:HasMember("TemplateApplyProperties") then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self.GetProperty = old_meta.GetProperty
		rawset(self, "IsTemplateProperty", old_meta.IsTemplateProperty)
		self:TemplateApplyProperties(template_class)
		self.GetProperty = nil
		self.IsTemplateProperty = nil
		setmetatable(self, old_meta) -- return to being a template again
	end
end

---
--- Randomizes the properties of the template object by pretending to be an instance of the template class.
---
--- This method is called when the template object needs to have its properties randomized, such as when the template is being generated procedurally.
---
--- @param self Template The template object to randomize the properties of.
--- @param seed number The seed to use for the randomization.
function Template:RandomizeProperties(seed)
	local template_class = g_Classes[self.TemplateOf]
	if template_class then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self:RandomizeProperties(seed)
		setmetatable(self, old_meta) -- return to being a template again
	end
end

---
--- Copies the properties from the source object to the current object.
---
--- If the source object is a Template, the TemplateOf property is set to the class of the source object.
--- Otherwise, the TemplateOf property is set to the class of the source object.
---
--- The CopyProperties function from the Object class is then called to copy the specified properties from the source object to the current object.
---
--- @param self Template The current Template object.
--- @param source table The source object to copy properties from.
--- @param properties table The list of properties to copy.
function Template:CopyProperties(source, properties)
	if IsKindOf(source, "Template") then
		self:SetTemplateOf(source.TemplateOf)
	else
		self:SetTemplateOf(source.class)
	end
	Object.CopyProperties(self, source, properties)
end

MapVar("TemplateSpawn", {}) -- todo: handle the case of multiplayer

---
--- Spawns a new object based on the template.
---
--- This function searches for an available handle to place the new object, and then copies the properties from the template to the new object. If the new object is a Hero, it is also added to the Hero's group.
---
--- The new object is stored in the TemplateSpawn table, and if the object has a "spawned_by_template" member, it is set to the current template.
---
--- @param self Template The template object to spawn.
--- @return table The newly spawned object, or nil if it could not be spawned.
function Template:Spawn()
	-- Some templates can only be spawned on e.g. "easy"
	local handle
	for i=self.handle+1, self.handle+self.reserved_handles do	
		if not HandleToObject[i] then
			handle = i
			break
		end
	end
	if not handle then return end
	local object = PlaceObject(self.TemplateOf, { handle = handle } )
	if not object then return end
	object:CopyProperties(self, object:GetProperties())
	
	if object:IsKindOf("Hero") and not (object.groups and table.find(object.groups, object.class)) then
		object:AddToGroup(object.class)
	end
	TemplateSpawn[self] = object
	if object:HasMember("spawned_by_template") then
		object.spawned_by_template = self
	end
	Msg(self)
	return object
end

---
--- Called when the Template object enters the editor.
--- This function applies the properties of the Template object to the editor.
---
--- @param self Template The Template object.
---
function Template:EditorEnter()
	self:TemplateApplyProperties()
end

---
--- Called when the Template object is about to exit the editor.
--- This function clears the properties of the Template object from the editor.
---
--- @param self Template The Template object.
---
function Template:EditorExit()
	self:TemplateClearProperties()
end

---
--- Returns the value of the ApplyToGrids property of the Template object.
---
--- @param self Template The Template object.
--- @return boolean The value of the ApplyToGrids property.
function Template:GetApplyToGrids()
	return self.ApplyToGrids
end

---
--- Sets the ApplyToGrids property of the Template object.
---
--- @param self Template The Template object.
--- @param value boolean The new value for the ApplyToGrids property.
---
function Template:SetApplyToGrids(value)
	self.ApplyToGrids = value
end

---
--- Returns the Collision property of the Template object.
---
--- @param self Template The Template object.
--- @return boolean The Collision property of the Template object.
function Template:GetCollision()
	return self.Collision
end

---
--- Sets the Collision property of the Template object.
---
--- @param self Template The Template object.
--- @param value boolean The new value for the Collision property.
---
function Template:SetCollision(value)
	self.Collision = value
end

---
--- Returns the value of the Walkable property of the Template object.
---
--- @param self Template The Template object.
--- @return boolean The value of the Walkable property.
function Template:GetWalkable()
	return self.Walkable
end

---
--- Sets the Walkable property of the Template object.
---
--- @param self Template The Template object.
--- @param value boolean The new value for the Walkable property.
---
function Template:SetWalkable(value)
	self.Walkable = value
end

---
--- Returns the enumeration value of the Template object.
---
--- If the Template object has a TemplateOf property that references a valid class in the global namespace, this function will return the enumeration value of that class. Otherwise, it will return the enumeration value of the PropertyObject base class.
---
--- @param self Template The Template object.
--- @return number The enumeration value of the Template object.
function Template:__enum()
	if self.TemplateOf and _G[self.TemplateOf] then
		return _G[self.TemplateOf]:__enum()
	end
	return PropertyObject.__enum(self)
end

---
--- Resolves the object reference for the given object.
---
--- If the object is valid and is a Template object, this function will return the TemplateSpawn[obj] value. Otherwise, it will return the original object.
---
--- @param obj any The object to resolve the reference for.
--- @return any The resolved object reference.
function ResolveObjectRef(obj)
	if IsValid(obj) and obj:IsKindOf("Template") then
		return TemplateSpawn[obj]
	end
	return obj
end

---
--- Waits for the object reference to be resolved for the given object.
---
--- If the object is valid and is a Template object, this function will wait for the TemplateSpawn[obj] value to be available before returning it. Otherwise, it will return the original object.
---
--- @param obj any The object to resolve the reference for.
--- @return any The resolved object reference.
function WaitResolveObjectRef(obj)
	if IsValid(obj) and obj:IsKindOf("Template") then
		if not TemplateSpawn[obj] then
			WaitMsg(obj)
		end
		return TemplateSpawn[obj]
	end
	return obj
end

---
--- Checks if the given object is a Template object or an instance of the specified class.
---
--- If the object is a Template object and has a TemplateOf property that references a valid class in the global namespace, this function will check if that class is a subclass of the specified class.
---
--- @param obj any The object to check.
--- @param class string The class to check against.
--- @return boolean True if the object is a Template object or an instance of the specified class, false otherwise.
function IsTemplateOrClass(obj, class)
	if obj:IsKindOf(class) then return true end
	return obj:IsKindOf("Template") and rawget(_G, obj.TemplateOf) and _G[obj.TemplateOf]:IsKindOf(class)
end

---
--- Checks if the given object is a Template object or an instance of any of the specified classes.
---
--- If the object is a Template object and has a TemplateOf property that references a valid class in the global namespace, this function will check if that class is a subclass of any of the specified classes.
---
--- @param obj any The object to check.
--- @param classes table The classes to check against.
--- @return boolean True if the object is a Template object or an instance of any of the specified classes, false otherwise.
function IsTemplateOrClasses(obj, classes)
	if obj:IsKindOfClasses(classes) then return true end
	return obj:IsKindOf("Template") and rawget(_G, obj.TemplateOf) and _G[obj.TemplateOf]:IsKindOfClasses(classes)
end

---
--- Gets a list of template group names that have at least one valid TemplateOpponent object.
---
--- The list will include "Disabled" and "Default Spawn" by default, and then any other template group names that have at least one valid TemplateOpponent object.
---
--- @return table A table of template group names.
function GetTemplateGroupsComboList()
	local list = { "Disabled","Default Spawn"}
	for k,group in pairs(groups) do
		for j=1, #group do
			if IsValid(group[j]) and group[j]:IsKindOf("TemplateOpponent") then
				list[#list + 1] = k
				break
			end
		end
	end
	table.sort(list)
	return list
end

---
--- Creates a new ShapeshifterClass object and attaches a Template object to it.
---
--- The Template object is set to the specified class name, its properties are randomized, and then applied to the ShapeshifterClass object. The color modifier and attachments from the Template object are also copied to the ShapeshifterClass object.
---
--- @param classname string The name of the class to create the ShapeshifterClass and Template objects for.
--- @return table The created ShapeshifterClass object.
function CreateClassShapeshifter(classname)
	local o = PlaceObject("ShapeshifterClass")
	o:ChangeClass(classname)
	o:SetGameFlags(const.gofSyncState)

	local t = PlaceObject("Template")
	t:SetTemplateOf(classname)
	t:RandomizeProperties()
	t:TemplateApplyProperties()

	o:SetColorModifier(t:GetColorModifier())
	for i = t:GetNumAttaches(), 1, -1 do
		local attach = t:GetAttach(i)
		local attach_spot = attach:GetAttachSpot()
		o:Attach(attach, attach_spot)
	end
	DoneObject(t)
	return o
end

---
--- Gets the editor label for the Template object.
---
--- The editor label is determined by the EditorLabel property of the class specified by the TemplateOf property. If no EditorLabel property is found, the TemplateOf value is used instead.
---
--- @return string The editor label for the Template object.
function Template:GetEditorLabel()
	local template_class = g_Classes[self.TemplateOf]
	local template_label = template_class and template_class:GetProperty("EditorLabel")
	return "Template of " .. (template_label or self.TemplateOf)
end