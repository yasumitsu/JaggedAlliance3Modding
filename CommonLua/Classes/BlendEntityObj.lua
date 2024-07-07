DefineClass.BlendEntityObj = {
	__parents = { "Object" },
	properties = {
		{ category = "Blend", id = "BlendEntity1", name = "Entity 1", editor = "choice", default = "Human_Head_M_As_01", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight1", name = "Weight 1", editor = "number", default = 50, slider = true, min = 0, max = 100 },
		{ category = "Blend", id = "BlendEntity2", name = "Entity 2", editor = "choice", default = "", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight2", name = "Weight 2", editor = "number", default = 0, slider = true, min = 0, max = 100 },
		{ category = "Blend", id = "BlendEntity3", name = "Entity 3", editor = "choice", default = "", items = function (obj) return obj:GetBlendEntityList() end },
		{ category = "Blend", id = "BlendWeight3", name = "Weight 3", editor = "number", default = 0, slider = true, min = 0, max = 100 },
	},
	entity = "Human_Head_M_Placeholder_01",
}

--- Returns a list of blend entities that can be used for blending.
---
--- This function is part of the BlendEntityObj class and is used to provide a list of available blend entities
--- that can be used when blending multiple entities together. The list is returned as a table of strings, where
--- each string represents the ID of a blend entity.
---
--- @return table A table of strings representing the available blend entities.
function BlendEntityObj:GetBlendEntityList()
	return { "" }
end

local g_UpdateBlendObjs = {}
local g_UpdateBlendEntityThread = false

--- Returns the idle material of the specified entity.
---
--- This function is used to retrieve the idle material of an entity. If the entity is valid and not an empty string,
--- the function will return the idle material of the entity. Otherwise, it will return an empty string.
---
--- @param entity string The ID of the entity to retrieve the idle material for.
--- @return string The idle material of the specified entity, or an empty string if the entity is invalid or empty.
function GetEntityIdleMaterial(entity)
	return entity and entity ~= "" and GetStateMaterial(entity, "idle") or ""
end

--- Updates the blend of the BlendEntityObj.
---
--- This function is responsible for blending the mesh of the BlendEntityObj based on the configured blend entities and weights.
--- If there are no blend entities or all blend weights are 0, the function will return without performing any blending.
--- Otherwise, it will use the AsyncMeshBlend function to blend the meshes and update the material blend.
---
--- @return nil
function BlendEntityObj:UpdateBlendInternal()
	if (not self.BlendEntity1 or self.BlendWeight1 == 0) and
	   (not self.BlendEntity2 or self.BlendWeight2 == 0) and
	   (not self.BlendEntity3 or self.BlendWeight3 == 0) then
	   return
   end

	local err = AsyncMeshBlend(self.entity, 0,
		self.BlendEntity1, self.BlendWeight1, 
		self.BlendEntity2, self.BlendWeight2,
		self.BlendEntity3, self.BlendWeight3)
	if err then print("Failed to blend meshes: ", err) end

	do
		local mat0 = GetEntityIdleMaterial(self.entity)
		local mat1 = GetEntityIdleMaterial(self.BlendEntity1)
		local mat2 = GetEntityIdleMaterial(self.BlendEntity2)
		local mat3 = GetEntityIdleMaterial(self.BlendEntity3)
		assert(mat0 ~= mat1 and mat0 ~= mat2 and mat0 ~= mat3)
	end
	
	local sumBlends = self.BlendWeight1 + self.BlendWeight2 + self.BlendWeight2
	local blend2, blend3 = 0, 0
	if sumBlends ~= self.BlendWeight1 then
		blend2 = self.BlendWeight2 * 100 / (sumBlends - self.BlendWeight1)
		blend3 = self.BlendWeight3 * 100 / sumBlends
	end
	SetMaterialBlendMaterials(GetEntityIdleMaterial(self.entity),
		GetEntityIdleMaterial(self.BlendEntity1), blend2,
		GetEntityIdleMaterial(self.BlendEntity2), blend3,
		GetEntityIdleMaterial(self.BlendEntity3))
		
	self:ChangeEntity(self.entity)
end

--- Updates the blend of the BlendEntityObj.
---
--- This function is responsible for scheduling the update of the blend for the BlendEntityObj. It adds the BlendEntityObj to a global table `g_UpdateBlendObjs` and starts a real-time thread `g_UpdateBlendEntityThread` if it doesn't already exist. The thread will iterate through the `g_UpdateBlendObjs` table and call the `UpdateBlendInternal()` function on each BlendEntityObj, then clear the table.
---
--- @return nil
function BlendEntityObj:UpdateBlend()
	g_UpdateBlendObjs[self] = true
	if not g_UpdateBlendEntityThread then
		g_UpdateBlendEntityThread = CreateRealTimeThread(function()
			while true do
				local obj, v = next(g_UpdateBlendObjs)
				if obj == nil then
					break
				end
				g_UpdateBlendObjs[obj] = nil
				obj:UpdateBlendInternal()
			end
			g_UpdateBlendEntityThread = false
		end)
	end
end

--- Updates the blend of the BlendEntityObj when certain properties are changed.
---
--- This function is called when the `BlendEntity1`, `BlendEntity2`, `BlendEntity3`, `BlendWeight1`, `BlendWeight2`, or `BlendWeight3` properties of the BlendEntityObj are changed. It schedules an update of the blend by adding the BlendEntityObj to a global table `g_UpdateBlendObjs` and starting a real-time thread `g_UpdateBlendEntityThread` if it doesn't already exist.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The old value of the property.
--- @param ged any The GED (Game Engine Data) object associated with the BlendEntityObj.
--- @return nil
function BlendEntityObj:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "BlendEntity1" or prop_id == "BlendEntity2" or prop_id == "BlendEntity3"
		or prop_id == "BlendWeight1" or prop_id == "BlendWeight2" or prop_id == "BlendWeight3"
	then
		self:UpdateBlend()
	end
end

--- Spawns a new BlendEntityObj and opens the GED game object editor for it.
---
--- This function creates a new BlendEntityObj, sets its position to the terrain cursor, and adds it to the editor selection. It then opens the GED game object editor for the selected object.
---
--- @return BlendEntityObj The newly created BlendEntityObj.
function BlendTest()
	local obj = BlendEntityObj:new()
	obj:SetPos(GetTerrainCursor())
	ViewObject(obj)
	editor.ClearSel()
	editor.AddToSel({obj})
	OpenGedGameObjectEditor(editor.GetSel())
	return obj
end

--- Spawns a new BlendEntityObj, sets its position to the terrain cursor, and opens the GED game object editor for it.
---
--- This function creates a new BlendEntityObj, sets its position to the terrain cursor, and adds it to the editor selection. It then opens the GED game object editor for the selected object.
---
--- @param weight2 number The weight of the second blend entity.
--- @param weight3 number The weight of the third blend entity.
--- @return BlendEntityObj The newly created BlendEntityObj.
function BlendMatTest(weight2, weight3)
	local obj = PlaceObj("Jacket_Nylon_M_Slim_01")
	obj:SetPos(GetTerrainCursor())
	ViewObject(obj)
	editor.ClearSel()
	editor.AddToSel({obj})
	
	local blendEntity1 = "Jacket_Nylon_M_Slim_01"
	local blendEntity2 = "Jacket_Nylon_M_Skinny_01"
	local blendEntity3 = "Jacket_Nylon_M_Chubby_01"
	
	weight2 = weight2 or 50
	weight3 = weight3 or 25
	
	SetMaterialBlendMaterials(GetEntityIdleMaterial(obj:GetEntity()),
		GetEntityIdleMaterial(blendEntity1), weight2,
		GetEntityIdleMaterial(blendEntity2), weight3,
		GetEntityIdleMaterial(blendEntity3))
		
	return obj
end
