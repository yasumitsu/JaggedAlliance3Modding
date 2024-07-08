local AppendVertex = pstr().AppendVertex
local GetHeight = terrain.GetHeight
local height_tile = const.HeightTileSize
local InvalidZ = const.InvalidZ
local KeepRefOneFrame = KeepRefOneFrame

local SetCustomData
local GetCustomData
function OnMsg.Autorun()
	SetCustomData = ComponentCustomData.SetCustomData
	GetCustomData = ComponentCustomData.GetCustomData
end

DefineClass.CodeRenderableObject = 
{
	__parents = { "Object", "ComponentAttach", "ComponentCustomData" },
	entity = "",
	flags = { 
		gofAlwaysRenderable = true, cfCodeRenderable = true, cofComponentInterpolation = true, cfConstructible = false,
		efWalkable = false, efCollision = false, efApplyToGrids = false, efSelectable = false, efShadow = false, efSunShadow = false
	},
	depth_test = false,
	zwrite = true,
}

DefineClass.Text =
{
	--[[
		Custom data layout:
		const.CRTextCCDIndexColorMain    - base color, RGBA
		const.CRTextCCDIndexColorShadow  - shadow color, RGBA
		const.CRTextCCDIndexFlags        - flags: 0: depth test, 1, center
		const.CRTextCCDIndexText         - text, as string - you must keep this string from being GCed while the Text object is alive
		const.CRTextCCDIndexFont         - font_id, integer as returned by UIL.GetFontID
		const.CRTextCCDIndexShadowOffset - shadow offset
		const.CRTextCCDIndexOpacity      - opacity interpolation parameters
		const.CRTextCCDIndexScale        - scale interpolation parameters
		const.CRTextCCDIndexZOffset      - z offset interpolation parameters
	]]
	__parents = { "CodeRenderableObject" },
	text = false,
	text_style = false,
	hide_in_editor = true, -- hide using the T button in the editor statusbar (or Alt-Shift-T shortcut)
}

local TextFlag_DepthTest = 1
local TextFlag_Center = 2
---
--- Sets the main color of the text.
---
--- @param c table The new main color of the text, represented as an RGBA table.
---


function Text:SetColor1(c) SetCustomData(self, const.CRTextCCDIndexColorMain, c) end
function Text:SetColor2(c) SetCustomData(self, const.CRTextCCDIndexColorShadow, c) end
function Text:GetColor1(c) return GetCustomData(self, const.CRTextCCDIndexColorMain) end
function Text:GetColor2(c) return GetCustomData(self, const.CRTextCCDIndexColorShadow) end

---
--- Sets the main color and shadow color of the text.
---
--- @param c table The new main color of the text, represented as an RGBA table.
---
function Text:SetColor(c)
	self:SetColor1(c)
	self:SetColor2(RGB(0,0,0))
end

---
--- Returns the main color of the text.
---
--- @return table The main color of the text, represented as an RGBA table.
---
function Text:GetColor(c)
	return self:GetColor1()
end

---
--- Sets whether depth testing is enabled for the text.
---
--- @param depth_test boolean Whether depth testing should be enabled for the text.
---

function Text:SetDepthTest(depth_test) 
	local flags = GetCustomData(self, const.CRTextCCDIndexFlags)
	if depth_test then
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagSet(flags, TextFlag_DepthTest))
	else
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagClear(flags, TextFlag_DepthTest))
	end
end
---
--- Returns whether depth testing is enabled for the text.
---
--- @return boolean Whether depth testing is enabled for the text.
---
function Text:GetDepthTest()   
	return IsFlagSet(GetCustomData(self, const.CRTextCCDIndexFlags), TextFlag_DepthTest)
end

---
--- Sets whether the text should be centered.
---
--- @param c boolean Whether the text should be centered.
---

function Text:SetCenter(c) 
	local flags = GetCustomData(self, const.CRTextCCDIndexFlags)
	if c then
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagSet(flags, TextFlag_Center)) 
	else
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagClear(flags, TextFlag_Center)) 
	end
end
---
--- Returns whether the text is centered.
---
--- @return boolean Whether the text is centered.
---
function Text:GetCenter()   
	return IsFlagSet(GetCustomData(self, const.CRTextCCDIndexFlags), TextFlag_Center)
end

---
--- Sets the text of the Text object.
---
--- @param txt string The new text to set.
---

function Text:SetText(txt) 
	KeepRefOneFrame(self.text)
	self.text = txt  
	SetCustomData(self, const.CRTextCCDIndexText, self.text) 
end
---
--- Returns the text of the Text object.
---
--- @return string The text of the Text object.
---
function Text:GetText()
	return self.text
end

---
--- Sets the font ID for the Text object.
---
--- @param id number The font ID to set.
---
function Text:SetFontId(id)       SetCustomData(self, const.CRTextCCDIndexFont, id)    end
function Text:GetFontId()         return GetCustomData(self, const.CRTextCCDIndexFont) end
function Text:SetShadowOffset(so) SetCustomData(self, const.CRTextCCDIndexShadowOffset, so)    end
function Text:GetShadowOffset()   return GetCustomData(self, const.CRTextCCDIndexShadowOffset) end

---
--- Sets the text style for the Text object.
---
--- @param style string The name of the text style to use.
--- @param scale number The scale factor to apply to the text style.
---
function Text:SetTextStyle(style, scale)
	local style = TextStyles[style]
	if not style then
		assert(false, string.format("Invalid text style '%s'", style))
		return
	end
	scale = scale or terminal.desktop.scale:y()
	local font, height, base_height = style:GetFontIdHeightBaseline(scale)
	self:SetFontId(font, height, base_height)
	self:SetColor(style.TextColor)
	self:SetShadowOffset(style.ShadowSize)
	self.text_style = style
end

---
--- Sets the opacity interpolation for the Text object.
---
--- @param v0 number The initial opacity value (0-100).
--- @param t0 number The initial time value (in milliseconds).
--- @param v1 number The final opacity value (0-100).
--- @param t1 number The final time value (in milliseconds).
---
function Text:SetOpacityInterpolation(v0, t0, v1, t1)
	-- opacities are 0..100, 7 bits
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 100
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexOpacity, EncodeBits(v0, 7, v1, 7, t0/10, 8, t1/10, 8))
end

---
--- Sets the scale interpolation for the Text object.
---
--- @param v0 number The initial scale value (0-127, representing 0-500% scale).
--- @param t0 number The initial time value (in milliseconds).
--- @param v1 number The final scale value (0-127, representing 0-500% scale).
--- @param t1 number The final time value (in milliseconds).
---
function Text:SetScaleInterpolation(v0, t0, v1, t1)
	-- scales are encoded 0..127, scale in percent/4 - so range 0..500%
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 100
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexScale, EncodeBits(v0/4, 7, v1/4, 7, t0/10, 8, t1/10, 8))
end

---
--- Sets the Z offset interpolation for the Text object.
---
--- @param v0 number The initial Z offset value (0-127, representing 0-6.35 meters).
--- @param t0 number The initial time value (in milliseconds).
--- @param v1 number The final Z offset value (0-127, representing 0-6.35 meters).
--- @param t1 number The final time value (in milliseconds).
---
function Text:SetZOffsetInterpolation(v0, t0, v1, t1)
	-- Z offsets are encoded 0..127, in guim/50 - so range 0..6.35 m
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 0
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexZOffset, EncodeBits(v0/50, 7, v1/50, 7, t0/10, 8, t1/10, 8))
end

--- Initializes the Text object.
---
--- This function sets the text style of the Text object to the value of `self.text_style`, or to "EditorText" if `self.text_style` is not set.
function Text:Init()	
	self:SetTextStyle(self.text_style or "EditorText")
end

---
--- Finalizes the Text object.
---
--- This function releases the reference to the text object, allowing it to be garbage collected.
---
function Text:Done()
	KeepRefOneFrame(self.text)
	self.text = nil
end

---
--- Sets custom data for the Text object.
---
--- @param idx number The index of the custom data to set.
--- @param data any The data to set for the custom data index.
---
--- @note This function should not be used to set the text of the Text object. Use `Text:SetText()` instead.
---
function Text:SetCustomData(idx, data)
    assert(idx ~= const.CRTextCCDIndexText, "Use SetText instead")
    return SetCustomData(self, idx, data)
end

DefineClass.TextEditor = {
	__parents = {"Text", "EditorVisibleObject"},
}

---
--- Places a new text object at the specified position with the given text and color.
---
--- @param text string The text to display.
--- @param pos table|nil The position to place the text object. If not provided, the text will be placed at the origin (0, 0, 0).
--- @param color table|nil The color to apply to the text. If not provided, the default color will be used.
--- @param editor_visibile_only boolean Whether the text object should only be visible in the editor.
--- @return table The created text object.
---
function PlaceText(text, pos, color, editor_visibile_only)
	local obj = PlaceObject(editor_visibile_only and "TextEditor" or "Text")
	if pos then
		obj:SetPos(pos)
	end
	obj:SetText(text)
	if color then
		obj:SetColor(color)
	end
	return obj
end

---
--- Removes all Text objects from the map.
---
function RemoveAllTexts()
	MapDelete("map", "Text")
end

local function GetMeshFlags()
	local flags = {}
	for name, value in pairs(const) do
		if string.starts_with(name, "mf") then
			flags[value] = name
		end
	end
	return flags
end

DefineClass.MeshParamSet = {
	__parents = { "PropertyObject" },
	properties = {
		
	},
	uniforms = false,
	uniforms_size = 0,
}

local uniform_sizes = {
	integer = 4,
	float = 4,
	color = 4,
	point2 = 8,
	point3 = 12,
}

---
--- Retrieves the metadata for the uniforms defined in the given properties.
---
--- @param properties table The properties to extract uniform metadata from.
--- @return table The uniforms metadata, including the type, offset, size, and scale.
--- @return integer The total size of the uniforms.
---
function GetUniformMeta(properties)
	local uniforms = {}
	local offset = 0
	for _, prop in ipairs(properties) do
		local uniform_type = prop.uniform
		if uniform_type then
			if type(uniform_type) ~= "string" then
				if prop.editor == "number" then
					uniform_type = prop.scale and prop.scale ~= 1 and "float" or "integer"
				elseif prop.editor == "point" then
					uniform_type = "point3"
				else
					uniform_type = prop.editor
				end
			end
			local size = uniform_sizes[uniform_type]
			if not size then
				assert(false, "Unknown uniform type.")
			end
			local space = 16 - (offset % 16)
			if space < size then
				table.insert(uniforms, {id = false, type = "padding", offset = offset, size = space})
				offset = offset + space
			end
			table.insert(uniforms, {id = prop.id, type = uniform_type, offset = offset, size = size, scale = prop.scale})
			offset = offset + size
		end
	end
	return uniforms, offset
end

function OnMsg.ClassesPostprocess()
	ClassDescendantsList("MeshParamSet", function(name, def)
		def.uniforms, def.uniforms_size = GetUniformMeta(def:GetProperties())
	end)
end

---
--- Writes a buffer with the uniforms for the MeshParamSet.
---
--- @param param_pstr string The parameter string to write the uniforms to.
--- @param offset integer The offset to start writing the uniforms at.
--- @param getter function The function to use to get the property values.
--- @return string The updated parameter string with the uniforms written.
---
function MeshParamSet:WriteBuffer(param_pstr, offset, getter)
	if not offset then
		offset = 0
	end
	if not getter then 
		getter = self.GetProperty
	end
	param_pstr = param_pstr or pstr("", self.uniforms_size)
	param_pstr:resize(offset)
	for _, prop in ipairs(self.uniforms) do
		local value
		if prop.type == "padding" then
			value = prop.size
		else
			value = getter(self, prop.id)
		end
		
		param_pstr:AppendUniform(prop.type, value, prop.scale)
	end
	return param_pstr
end

---
--- Composes a buffer with the uniforms for the MeshParamSet.
---
--- @param param_pstr string The parameter string to write the uniforms to.
--- @param getter function The function to use to get the property values.
--- @return string The updated parameter string with the uniforms written.
---
function MeshParamSet:ComposeBuffer(param_pstr, getter)
	return self:WriteBuffer(param_pstr, 0, getter)
end

DefineClass.Mesh = {
	__parents = { "CodeRenderableObject" },
	
	properties = {
		{ id = "vertices_len", read_only = true, dont_save = true, editor = "number", default = 0,},
		{ id = "CRMaterial", editor = "nested_obj", base_class = "CRMaterial", default = false, },
		{ id = "MeshFlags", editor = "flags", default = 0, items = GetMeshFlags },
		{ id = "DepthTest", editor = "bool", default = false, read_only = function(s) return not s.shader or s.shader.depth_test ~= "runtime" end, },
		{ id = "ShaderName", editor = "choice", default = "default_mesh", items = function() return table.keys2(ProceduralMeshShaders, "sorted") end},
	},
	--[[
		Custom data layout:
		const.CRMeshCCDIndexGeometry  - vertices, packed in a pstr
		const.CRMeshCCDIndexPipeline  - shader; depth_test >> 31, 0 for off, 1 for on
		const.CRMeshCCDIndexMeshFlags - mesh flags
		const.CRMeshCCDIndexUniforms  - uniforms, packed in a pstr
		const.CRMeshCCDIndexTexture0, const.CRMeshCCDIndexTexture1 - textures
	]]

	vertices_pstr = false,
	uniforms_pstr = false,
	shader = false,
	textstyle_id = false,
}

---
--- Returns a string representation of the Mesh object, including its class name and the associated CRMaterial or shader name.
---
--- @return string The string representation of the Mesh object.
---
function Mesh:GetTreeViewFormat()
	return string.format("%s (%s)", self.class, self.CRMaterial and self.CRMaterial.id or self:GetShaderName())
end


---
--- Returns the length of the vertices string for the Mesh object.
---
--- @return number The length of the vertices string, or 0 if the vertices string is not set.
---
function Mesh:GetVerticesLen()
	return self.vertices_pstr and #self.vertices_pstr or 0
end


---
--- Returns the name of the shader associated with the Mesh object.
---
--- @return string The name of the shader, or an empty string if no shader is set.
---
function Mesh:GetShaderName()
	return self.shader and self.shader.name or ""
end

---
--- Sets the shader for the Mesh object.
---
--- @param value string The name of the shader to set.
---
function Mesh:SetShaderName(value)
	self:SetShader(ProceduralMeshShaders[value])
end

---
--- Initializes the Mesh object by setting the default shader.
---
function Mesh:Init()
	self:SetShader(ProceduralMeshShaders.default_mesh)
end

---
--- Sets the vertices for the Mesh object.
---
--- @param vpstr string The string representation of the vertices.
---
function Mesh:SetMesh(vpstr)
	KeepRefOneFrame(self.vertices_pstr)
	local vertices_pstr = #(vpstr or "") > 0 and vpstr or nil -- an empty string would result in a crash :|
	self.vertices_pstr = vertices_pstr
	SetCustomData(self, const.CRMeshCCDIndexGeometry, vertices_pstr)
end

---
--- Sets the uniforms for the Mesh object using the provided uniform set.
---
--- @param uniform_set table The uniform set to use for setting the uniforms.
---
function Mesh:SetUniformSet(uniform_set)
	self:SetUniformsPstr(uniform_set:ComposeBuffer())
end

---
--- Sets the uniforms for the Mesh object using the provided uniforms string.
---
--- @param uniforms_pstr string The string representation of the uniforms.
---
function Mesh:SetUniformsPstr(uniforms_pstr)
	KeepRefOneFrame(self.uniforms_pstr)
	self.uniforms_pstr = uniforms_pstr
	SetCustomData(self, const.CRMeshCCDIndexUniforms, uniforms_pstr)
end

---
--- Sets the uniforms for the Mesh object using the provided uniform list.
---
--- @param uniforms table The list of uniforms to set.
--- @param isDouble boolean Whether the uniforms are doubles or floats.
---
function Mesh:SetUniformsList(uniforms, isDouble)
	KeepRefOneFrame(self.uniforms_pstr)
	local count = Max(8, #uniforms)
	local uniforms_pstr = pstr("", count * 4)
	self.uniforms_pstr = uniforms_pstr
	for i = 1, count do
		if isDouble then
			uniforms_pstr:AppendUniform("double", uniforms[i] or 0)
		else
			uniforms_pstr:AppendUniform("float", uniforms[i] or 0, 1000)
		end
	end
	SetCustomData(self, const.CRMeshCCDIndexUniforms, uniforms_pstr)
end

---
--- Sets the uniforms for the Mesh object using the provided uniform list.
---
--- @param ... table The list of uniforms to set.
---
function Mesh:SetUniforms(...)
	return self:SetUniformsList{...}
end

---
--- Sets the uniforms for the Mesh object using the provided uniform list, where the uniforms are doubles.
---
--- @param ... table The list of uniforms to set, where each element is a double.
---
function Mesh:SetDoubleUniforms(...)
	return self:SetUniformsList({...}, true)
end

---
--- Sets the shader and depth test for the Mesh object.
---
--- @param shader table The shader to set for the Mesh.
--- @param depth_test boolean|nil The depth test to set for the Mesh. If not provided, it will be determined based on the shader's depth_test property.
---
function Mesh:SetShader(shader, depth_test)
	assert(shader.shaderid)
	assert(shader.defines)
	assert(shader.ref_id > 0)
	if depth_test == nil then
		if shader.depth_test == "always" then
			depth_test = true
		elseif shader.depth_test == "never" then
			depth_test = false
		else
			depth_test = self:GetDepthTest()
		end
	end
	local depth_test_int = 0
	if depth_test then
		depth_test_int = 1
		assert(shader.depth_test == "runtime" or shader.depth_test == "always", "Tried to enable depth test for shader with depth_test = never")
	else
		depth_test_int = 0
		assert(shader.depth_test == "runtime" or shader.depth_test == "never", "Tried to disable depth test for shader with depth_test = always")
	end
	SetCustomData(self, const.CRMeshCCDIndexPipeline, shader.ref_id | (depth_test_int << 31))
	self.shader = shader
end

---
--- Sets the depth test for the Mesh object.
---
--- @param depth_test boolean The depth test to set for the Mesh.
---
function Mesh:SetDepthTest(depth_test)
	assert(self.shader)
	self:SetShader(self.shader, depth_test)
end

---
--- Sets the CRMaterial for the Mesh object.
---
--- @param material table|string The CRMaterial to set for the Mesh. Can be a table or a string representing the ID of the CRMaterial.
---
function Mesh:SetCRMaterial(material)
	if type(material) == "string" then
		local new_material = CRMaterial:GetById(material, true)
		assert(new_material, "CRMaterial not found.")
		material = new_material
	end
	self.CRMaterial = material
	local depth_test = material.depth_test
	if depth_test == "default" then depth_test = nil end

	CodeRenderableLockCCD(self)
	self:SetShader(material:GetShader(), depth_test)
	self:SetUniformsPstr(material:GetDataPstr())
	CodeRenderableUnlockCCD(self)
end

---
--- Gets the CRMaterial for the Mesh object.
---
--- @return table The CRMaterial for the Mesh.
---
function Mesh:GetCRMaterial()
	return self.CRMaterial
end

if FirstLoad then
	MeshTextureRefCount = {}
end

local function ModifyMeshTextureRefCount(id, change)
	if id == 0 then return end
	local old = MeshTextureRefCount[id] or 0
	local new = old + change
	if new == 0 then
		MeshTextureRefCount[id] = nil
		ProceduralMeshReleaseResource(id)
	else
		MeshTextureRefCount[id] = new
	end
end

---
--- Sets the texture for the Mesh object at the specified index.
---
--- @param idx number The index of the texture to set (0 or 1).
--- @param resource_id number The ID of the texture resource to set.
---
function Mesh:SetTexture(idx, resource_id)
	assert(idx >= 0 and idx <= 1)
	if self:GetTexture(idx) == resource_id then return end
	ModifyMeshTextureRefCount(self:GetTexture(idx), -1)
	SetCustomData(self, const.CRMeshCCDIndexTexture0 + idx, resource_id or 0)
	ModifyMeshTextureRefCount(resource_id, 1) 
end

---
--- Gets the texture resource ID for the Mesh object at the specified index.
---
--- @param idx number The index of the texture to get (0 or 1).
--- @return number The ID of the texture resource at the specified index, or 0 if no texture is set.
---
function Mesh:GetTexture(idx)
	assert(idx >= 0 and idx <= 1)
	return GetCustomData(self, const.CRMeshCCDIndexTexture0 + idx) or 0
end

---
--- Cleans up resources used by the Mesh object.
---
--- This function is called when the Mesh object is no longer needed. It releases
--- the reference to the vertices and uniforms buffers, and sets the texture
--- resources to 0 to indicate that they are no longer in use.
---
function Mesh:Done()
	KeepRefOneFrame(self.vertices_pstr)
	KeepRefOneFrame(self.uniforms_pstr)
	self.vertices_pstr = nil
	self.uniforms_pstr = nil
	self:SetTexture(0, 0)
	self:SetTexture(1, 0)
end

function OnMsg.DoneMap()
	for key, value in pairs(MeshTextureRefCount) do
		ProceduralMeshReleaseResource(key)
	end
	MeshTextureRefCount = {}
end

---
--- Sets custom data for the Mesh object at the specified index.
---
--- @param idx number The index of the custom data to set.
--- @param data any The data to set for the specified index.
---
function Mesh:SetCustomData(idx, data)
	assert(idx > const.CRMeshCCDIndexGeometry, "Use SetMesh instead!")
	return SetCustomData(self, idx, data)
end
---
--- Gets whether the Mesh object has depth testing enabled.
---
--- @return boolean True if depth testing is enabled, false otherwise.
---

function Mesh:GetDepthTest() return (GetCustomData(self, const.CRMeshCCDIndexPipeline) >> 31) == 1 end
function Mesh:SetMeshFlags(flags) SetCustomData(self, const.CRMeshCCDIndexMeshFlags, flags) end
function Mesh:GetMeshFlags() return GetCustomData(self, const.CRMeshCCDIndexMeshFlags) end
function Mesh:AddMeshFlags(flags) self:SetMeshFlags(flags | self:GetMeshFlags()) end
function Mesh:ClearMeshFlags(flags) self:SetMeshFlags(~flags & self:GetMeshFlags()) end

---
--- Returns the text color for the specified text style.
---
--- @param id number The ID of the text style.
--- @return color The text color for the specified text style.
---
function Mesh.ColorFromTextStyle(id)
	assert(TextStyles[id])
	return TextStyles[id].TextColor
end

---
--- Appends vertices for a circle to the specified vertex buffer.
---
--- @param vpstr string The vertex buffer to append the vertices to.
--- @param center point30 The center point of the circle.
--- @param radius number The radius of the circle.
--- @param color color The color of the circle.
--- @param strip boolean Whether to draw the circle as a triangle strip.
--- @return string The updated vertex buffer.
---
function AppendCircleVertices(vpstr, center, radius, color, strip)
	local HSeg = 32
	vpstr = vpstr or pstr("", 1024)
	color = color or RGB(254, 127, 156)
	center = center or point30
	local x0, y0, z0
	for i = 0, HSeg do
		local x, y, z = RotateRadius(radius, MulDivRound(360 * 60, i, HSeg), center, true)
		AppendVertex(vpstr, x, y, z, color)
		if not strip then
			if i ~= 0 then
				AppendVertex(vpstr, x, y, z, color)
				if i == HSeg then
					AppendVertex(vpstr, x0, y0, z0)
				end
			else
				x0, y0, z0 = x, y, z
			end
		end
	end

	return vpstr
end

---
--- Appends vertices for a tile to the specified vertex buffer.
---
--- @param vstr string The vertex buffer to append the vertices to.
--- @param x number The x-coordinate of the tile center.
--- @param y number The y-coordinate of the tile center.
--- @param z number The z-coordinate of the tile center. If not provided, the height at (x, y) will be used.
--- @param tile_size number The size of the tile.
--- @param color color The color of the tile.
--- @param offset_z number The z-offset to apply to the tile vertices.
--- @param get_height function A function to get the height at a given (x, y) coordinate.
--- @return string The updated vertex buffer.
---
function AppendTileVertices(vstr, x, y, z, tile_size, color, offset_z, get_height)
	offset_z = offset_z or 0
	z = z or InvalidZ
	local d = tile_size / 2
	local x1, y1, z1 = x - d, y - d
	local x2, y2, z2 = x + d, y - d
	local x3, y3, z3 = x - d, y + d
	local x4, y4, z4 = x + d, y + d
	get_height = get_height or GetHeight
	if z ~= InvalidZ and z ~= get_height(x, y) then
		z = z + offset_z
		z1, z2, z3, z4 = z, z, z, z
	else
		z1 = get_height(x1, y1) + offset_z
		z2 = get_height(x2, y2) + offset_z
		z3 = get_height(x3, y3) + offset_z
		z4 = get_height(x4, y4) + offset_z
	end
	AppendVertex(vstr, x1, y1, z1, color)
	AppendVertex(vstr, x2, y2, z2, color)
	AppendVertex(vstr, x3, y3, z3, color)
	AppendVertex(vstr, x4, y4, z4, color)
	AppendVertex(vstr, x2, y2, z2, color)
	AppendVertex(vstr, x3, y3, z3, color)
end

---
--- Returns the size of the vertex buffer required for a single tile.
---
--- @return number The size of the vertex buffer required for a single tile.
---
function GetSizePstrTile()
	return 6 * const.pstrVertexSize
end

---
--- Appends vertices for a torus to the specified vertex buffer.
---
--- @param vpstr string The vertex buffer to append the vertices to.
--- @param radius1 number The radius of the torus.
--- @param radius2 number The radius of the torus tube.
--- @param axis point The axis of the torus.
--- @param color color The color of the torus.
--- @param normal point The normal vector of the torus. If provided, only the visible side of the torus will be rendered.
--- @return string The updated vertex buffer.
---
function AppendTorusVertices(vpstr, radius1, radius2, axis, color, normal)
	local HSeg = 32
	local VSeg = 10
	vpstr = vpstr or pstr("", 1024)
	local rad1 = Rotate(axis, 90 * 60)
	rad1 = Cross(axis, rad1)
	rad1 = Normalize(rad1)
	rad1 = MulDivRound(rad1, radius1, 4096)
	for i = 1, HSeg do
		local localCenter1 = RotateAxis(rad1, axis, MulDivRound(360 * 60, i, HSeg))
		local localCenter2 = RotateAxis(rad1, axis, MulDivRound(360 * 60, i - 1, HSeg))
		local lastUpperPt, lastPt
		if not normal or not IsPointInFrontOfPlane(point(0, 0, 0), normal, (localCenter1 + localCenter2) / 2) then
			for j = 0, VSeg do
				local rad2 = MulDivRound(localCenter1, radius2, radius1)
				local localAxis = Cross(rad2, axis)
				local pt = RotateAxis(rad2, localAxis, MulDivRound(360 * 60, j, VSeg))
				pt = localCenter1 + pt
				rad2 = MulDivRound(localCenter2, radius2, radius1)
				localAxis = Cross(rad2, axis)
				local upperPt = RotateAxis(rad2, localAxis, MulDivRound(360 * 60, j, VSeg))
				upperPt = localCenter2 + upperPt
				if j ~= 0 then
					AppendVertex(vpstr, pt, color)
					AppendVertex(vpstr, lastPt)
					AppendVertex(vpstr, upperPt)
					AppendVertex(vpstr, upperPt, color)
					AppendVertex(vpstr, lastUpperPt)
					AppendVertex(vpstr, lastPt)
				end
				lastPt = pt
				lastUpperPt = upperPt
			end
		end
	end
	
	return vpstr
end

---
--- Appends vertices for a cone to the specified vertex buffer.
---
--- @param vpstr string The vertex buffer to append the vertices to.
--- @param center point The center point of the cone.
--- @param displacement point The displacement of the cone's top from the center.
--- @param radius1 number The radius of the cone's base.
--- @param radius2 number The radius of the cone's top.
--- @param axis point The axis of the cone.
--- @param angle number The angle of the cone in degrees.
--- @param color color The color of the cone.
--- @param offset point The offset of the cone.
--- @return string The updated vertex buffer.
---
function AppendConeVertices(vpstr, center, displacement, radius1, radius2, axis, angle, color, offset)
	local HSeg = 10
	vpstr = vpstr or pstr("", 1024)
	center = center or point(0, 0, 0)
	displacement = displacement or point(0, 0, 30 * guim)
	axis = axis or axis_z
	angle = angle or 0
	offset = offset or point(0, 0, 0)
	color = color or RGB(254, 127, 156)
	local lastPt, lastUpperPt
	for i = 0, HSeg do
		local rad = point(radius1, 0, 0)
		local pt = center + Rotate(rad, MulDivRound(360 * 60, i, HSeg))
		local upperRad = point(radius2, 0, 0)
		local upperPt = center + displacement + Rotate(upperRad, MulDivRound(360 * 60, i, HSeg))
		pt = RotateAxis(pt, axis, angle * 60) + offset
		upperPt = RotateAxis(upperPt, axis, angle * 60) + offset
		if i ~= 0 then
			AppendVertex(vpstr, pt, color)
			AppendVertex(vpstr, lastPt)
			AppendVertex(vpstr, upperPt)
			if radius2 ~= 0 then
				AppendVertex(vpstr, upperPt, color)
				AppendVertex(vpstr, lastUpperPt)
				AppendVertex(vpstr, lastPt)
			end
		end
		lastPt = pt
		lastUpperPt = upperPt
	end
	
	return vpstr
end

DefineClass.Polyline =
{
	__parents = { "Mesh" },
}

--- Initializes the Polyline object.
---
--- Sets the mesh flags to `const.mfWorldSpace` and the shader to `ProceduralMeshShaders.default_polyline`.
function Polyline:Init()
	self:SetMeshFlags(const.mfWorldSpace)
	self:SetShader(ProceduralMeshShaders.default_polyline)
end

DefineClass.Vector = {
	__parents = {"Polyline"},
}

---
--- Sets the position and geometry of a Vector object.
---
--- @param a point The starting point of the vector.
--- @param b point The ending point of the vector.
--- @param col RGB The color of the vector.
function Vector:Set (a, b, col)
	col = col or RGB(255, 255, 255)
	a = ValidateZ(a)
	b = ValidateZ(b)
	self:SetPos(a)
	
	local vpstr = pstr("", 1024)
	
	AppendVertex(vpstr, a, col)
	AppendVertex(vpstr, b)

	local ab = b - a
	local cb = (ab * 5) / 100
	local f = cb:Len() / 4
	local c = b - cb

	local n = 4
	local ps = GetRadialPoints (n, c, cb, f)
	for i = 1 , n/2 do
		AppendVertex(vpstr, ps[i])
		AppendVertex(vpstr, ps[i + n/2])
		AppendVertex(vpstr, b)
	end
	self:SetMesh(vpstr)
end

---
--- Returns the starting point of the vector.
---
--- @return point The starting point of the vector.
function Vector:GetA()
	return self:GetPos() 
end

---
--- Displays a vector object with the given origin, direction, and color for the specified duration.
---
--- @param vector point The ending point of the vector.
--- @param origin point The starting point of the vector.
--- @param color RGB The color of the vector.
--- @param time number The duration in seconds to display the vector.
--- @return Vector The created vector object.
function ShowVector(vector, origin, color, time)
	local v = PlaceObject("Vector")
	origin = origin:z() and origin or point(origin:x(), origin:y(), GetWalkableZ(origin))
	vector = vector:z() and vector or point(vector:x(), vector:y(), 0)
	v:Set(origin, origin + vector, color)
	if time then
		CreateGameTimeThread(function()
			Sleep(time)
			DoneObject(v)
		end)
	end
	
	return v
end

DefineClass.Segment = {
	__parents = {"Polyline"},
}

---
--- Initializes the Segment object by setting the depth test to false.
---
function Segment:Init()
	self:SetDepthTest(false)
end

---
--- Sets the starting and ending points of the Segment object, and updates its mesh with the specified color.
---
--- @param a point The starting point of the segment.
--- @param b point The ending point of the segment.
--- @param col RGB The color of the segment.
---
function Segment:Set (a, b, col)
	col = col or RGB(255, 255, 255)
	a = ValidateZ(a)
	b = ValidateZ(b)
	self:SetPos(a)
	local vpstr = pstr("", 1024)
	AppendVertex(vpstr, a, col)
	AppendVertex(vpstr, b)
	self:SetMesh(vpstr)
end

-- After loading the code renderables from C, fix their string custom data in the Lua
function OnMsg.PersistLoad(_dummy_)
	MapForEach(true, "Text", function(obj)
		SetCustomData(obj, const.CRTextCCDIndexText, obj.text or 0)
	end)
	MapForEach(true, "Mesh", function(obj)
		CodeRenderableLockCCD(obj)
		SetCustomData(obj, const.CRMeshCCDIndexGeometry, obj.vertices_pstr or 0)
		SetCustomData(obj, const.CRMeshCCDIndexUniforms, obj.uniforms_pstr or 0)
		CodeRenderableUnlockCCD(obj)
	end)
end

----

---
--- Places a terrain circle on the map with the specified center, radius, color, and step size.
---
--- @param center point The center point of the circle.
--- @param radius number The radius of the circle.
--- @param color RGB The color of the circle.
--- @param step number The step size for the circle vertices.
--- @param offset number The vertical offset for the circle vertices.
--- @param max_steps number The maximum number of steps to use for the circle.
--- @return Polyline The placed terrain circle object.
---
function PlaceTerrainCircle(center, radius, color, step, offset, max_steps)
	step = step or guim
	offset = offset or guim
	local steps = Min(Max(12, (44 * radius) / (7 * step)), max_steps or 360)
	local last_pt
	local mapw, maph = terrain.GetMapSize()
	local vpstr = pstr("", 1024)
	for i = 0,steps do
		local x, y = RotateRadius(radius, MulDivRound(360*60, i, steps), center, true)
		x = Clamp(x, 0, mapw - height_tile)
		y = Clamp(y, 0, maph - height_tile)
		AppendVertex(vpstr, x, y, offset, color)
	end

	local line = PlaceObject("Polyline")
	line:SetMesh(vpstr)
	line:SetPos(center)
	line:AddMeshFlags(const.mfTerrainDistorted)
	return line
end

local function GetTerrainPointsPStr(vpstr, pt1, pt2, step, offset, color)
	step = step or guim
	offset = offset or guim
	local diff = pt2 - pt1
	local steps = Max(2, 1 + diff:Len2D() / step)
	local mapw, maph = terrain.GetMapSize()
	vpstr = vpstr or pstr("", 1024)
	for i=1,steps do
		local pos = pt1 + MulDivRound(diff, i - 1, steps - 1)
		local x, y = pos:xy()
		x = Clamp(x, 0, mapw - height_tile)
		y = Clamp(y, 0, maph - height_tile)
		AppendVertex(vpstr, x, y, offset, color)
	end
	return vpstr
end

---
--- Places a terrain line on the map with the specified start and end points, color, step size, and vertical offset.
---
--- @param pt1 point The start point of the line.
--- @param pt2 point The end point of the line.
--- @param color RGB The color of the line.
--- @param step number The step size for the line vertices.
--- @param offset number The vertical offset for the line vertices.
--- @return Polyline The placed terrain line object.
---
function PlaceTerrainLine(pt1, pt2, color, step, offset)
	local vpstr = GetTerrainPointsPStr(false, pt1, pt2, step, offset, color)
	local line = PlaceObject("Polyline")
	line:SetMesh(vpstr)
	line:SetPos((pt1 + pt2) / 2)
	line:AddMeshFlags(const.mfTerrainDistorted)
	return line
end

---
--- Places a terrain box on the map with the specified bounding box, color, step size, and vertical offset.
---
--- @param box table The bounding box of the terrain box.
--- @param color RGB The color of the terrain box.
--- @param step number The step size for the terrain box vertices.
--- @param offset number The vertical offset for the terrain box vertices.
--- @param mesh_obj Polyline The existing polyline object to use, or nil to create a new one.
--- @param depth_test boolean Whether to enable depth testing for the terrain box.
--- @return Polyline The placed terrain box object.
---
function PlaceTerrainBox(box, color, step, offset, mesh_obj, depth_test)
	local p = {box:ToPoints2D()}
	local m
	for i = 1, #p do
		m = GetTerrainPointsPStr(m, p[i], p[i + 1] or p[1], step, offset, color)
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	if depth_test ~= nil then
		mesh_obj:SetDepthTest(depth_test)
	end
	mesh_obj:SetMesh(m)
	mesh_obj:SetPos(box:Center())
	mesh_obj:AddMeshFlags(const.mfTerrainDistorted)
	return mesh_obj
end

---
--- Places a terrain polygon on the map with the specified points, color, step size, and vertical offset.
---
--- @param p table The list of points defining the polygon.
--- @param color RGB The color of the terrain polygon.
--- @param step number The step size for the terrain polygon vertices.
--- @param offset number The vertical offset for the terrain polygon vertices.
--- @param mesh_obj Polyline The existing polyline object to use, or nil to create a new one.
--- @return Polyline The placed terrain polygon object.
---
function PlaceTerrainPoly(p, color, step, offset, mesh_obj)
	local m
	local center = p[1] + ((p[1] - p[3]) / 2)
	for i = 1, #p do
		m = GetTerrainPointsPStr(m, p[i], p[i + 1] or p[1], step, offset, color)
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	mesh_obj:SetMesh(m)
	mesh_obj:SetPos(center)
	return mesh_obj
end

---
--- Places a polyline on the map with the specified points and colors.
---
--- @param pts table The list of points defining the polyline.
--- @param clrs table|RGB The list of colors for each point, or a single color to apply to all points.
--- @param depth_test boolean Whether to enable depth testing for the polyline.
--- @return Polyline The placed polyline object.
---
function PlacePolyLine(pts, clrs, depth_test)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local vpstr = pstr("", 1024)
	local clr
	local pt0
	for i, pt in ipairs(pts) do
		if IsValidPos(pt) then
			pt0 = pt0 or pt
			clr = type(clrs) == "table" and clrs[i] or clrs or clr
			AppendVertex(vpstr, pt, clr)
		end
	end
	line:SetMesh(vpstr)
	if pt0 then
		line:SetPos(pt0)
	end
	return line
end

---
--- Appends vertices to a polyline mesh for a 3D spline.
---
--- @param spline table The 3D spline to generate vertices for.
--- @param color RGB The color to use for the vertices.
--- @param step number The step size to use when sampling the spline. Defaults to `guim`.
--- @param min_steps number The minimum number of steps to use. Defaults to 7.
--- @param max_steps number The maximum number of steps to use. Defaults to 1024.
--- @param vpstr string The existing vertex position string to append to, or `nil` to create a new one.
--- @return string, point The updated vertex position string, and the center position of the spline.
---
function AppendSplineVertices(spline, color, step, min_steps, max_steps, vpstr)
	step = step or guim
	min_steps = min_steps or 7
	max_steps = max_steps or 1024
	local len = BS3_GetSplineLength3D(spline)
	local steps = Clamp(len / step, min_steps, max_steps)
	vpstr = vpstr or pstr("", (steps + 2) * const.pstrVertexSize)
	local x, y, z
	local x0, y0, z0 = BS3_GetSplinePos(spline, 0)
	AppendVertex(vpstr, x0, y0, z0, color)
	for i = 1,steps-1 do
		local x, y, z = BS3_GetSplinePos(spline, i, steps)
		AppendVertex(vpstr, x, y, z, color)
	end
	local x1, y1, z1 = BS3_GetSplinePos(spline, steps, steps)
	AppendVertex(vpstr, x1, y1, z1, color)
	return vpstr, point((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end

---
--- Places a 3D spline as a polyline mesh.
---
--- @param spline table The 3D spline to generate vertices for.
--- @param color RGB The color to use for the vertices.
--- @param depth_test boolean Whether to enable depth testing for the polyline.
--- @param step number The step size to use when sampling the spline. Defaults to `guim`.
--- @param min_steps number The minimum number of steps to use. Defaults to 7.
--- @param max_steps number The maximum number of steps to use. Defaults to 1024.
--- @return Polyline The created polyline object.
---
function PlaceSpline(spline, color, depth_test, step, min_steps, max_steps)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local vpstr, pos = AppendSplineVertices(spline, color, step, min_steps, max_steps)
	line:SetMesh(vpstr)
	line:SetPos(pos)
	return line
end

---
--- Places a collection of 3D splines as a polyline mesh.
---
--- @param splines table An array of 3D splines to generate vertices for.
--- @param color RGB The color to use for the vertices.
--- @param depth_test boolean Whether to enable depth testing for the polyline.
--- @param start_idx number The index of the first spline to use. Defaults to 1.
--- @param step number The step size to use when sampling the splines. Defaults to `guim`.
--- @param min_steps number The minimum number of steps to use. Defaults to 7.
--- @param max_steps number The maximum number of steps to use. Defaults to 1024.
--- @return Polyline The created polyline object.
---
function PlaceSplines(splines, color, depth_test, start_idx, step, min_steps, max_steps)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local count = #(splines or "")
	local pos = point30
	local vpstr = pstr("", count * 128 * const.pstrVertexSize)
	for i = (start_idx or 1), count do
		local _, posi = AppendSplineVertices(splines[i], color, step, min_steps, max_steps, vpstr)
		pos = pos + posi
	end
	if count > 0 then
		pos = pos / count
	end
	line:SetMesh(vpstr)
	line:SetPos(pos)
	return line
end

--- Places a 3D box as a polyline mesh.
---
--- @param box Box The 3D box to place.
--- @param color RGB The color to use for the vertices.
--- @param mesh_obj Polyline The polyline object to use. If not provided, a new one will be created.
--- @param depth_test boolean Whether to enable depth testing for the polyline.
--- @return Polyline The placed polyline object.
function PlaceBox(box, color, mesh_obj, depth_test)
	local p1, p2, p3, p4 = box:ToPoints2D()
	local minz, maxz = box:minz(), box:maxz()
	local vpstr = pstr("", 1024)
	if minz and maxz then
		if minz >= maxz - 1 then
			for _, p in ipairs{p1, p2, p3, p4, p1} do
				local x, y = p:xy()
				AppendVertex(vpstr, x, y, minz, color)
			end
		else
			for _, z in ipairs{minz, maxz} do
				for _, p in ipairs{p1, p2, p3, p4, p1} do
					local x, y = p:xy()
					AppendVertex(vpstr, x, y, z, color)
				end
			end
			AppendVertex(vpstr, p2:SetZ(maxz), color)
			AppendVertex(vpstr, p2:SetZ(minz), color)
			AppendVertex(vpstr, p3:SetZ(minz), color)
			AppendVertex(vpstr, p3:SetZ(maxz), color)
			AppendVertex(vpstr, p4:SetZ(maxz), color)
			AppendVertex(vpstr, p4:SetZ(minz), color)
		end
	else
		local z = terrain.GetHeight(p1)
		for _, p in ipairs{p2, p3, p4} do
			z = Max(z, terrain.GetHeight(p))
		end
		for _, p in ipairs{p1, p2, p3, p4, p1} do
			local x, y = p:xy()
			AppendVertex(vpstr, x, y, z, color)
		end
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	if depth_test ~= nil then
		mesh_obj:SetDepthTest(depth_test)
	end
	mesh_obj:SetMesh(vpstr)
	mesh_obj:SetPos(box:Center())
	return mesh_obj
end

--- Places a 3D vector as a polyline mesh.
---
--- @param pos point The starting position of the vector.
--- @param vec point|number The direction and length of the vector. If a number is provided, it is interpreted as the length of the vector in the Z direction.
--- @param color RGB The color to use for the vertices.
--- @param depth_test boolean Whether to enable depth testing for the polyline.
--- @return Polyline The placed polyline object.
function PlaceVector(pos, vec, color, depth_test)
	vec = vec or 10*guim
	vec = type(vec) == "number" and point(0, 0, vec) or vec
	return PlacePolyLine({pos, pos + vec}, color, depth_test)
end

--- Places a terrain cursor circle mesh.
---
--- @param radius number The radius of the circle in game units.
--- @param color RGB The color of the circle.
--- @return Mesh The placed circle mesh.
function CreateTerrainCursorCircle(radius, color)
	color = color or RGB(23, 34, 122)
	radius = radius or 30 * guim
	
	local line = CreateCircleMesh(radius, color)
	line:SetPos(GetTerrainCursor())
	line:SetMeshFlags(const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace)
	return line
end

--- Places a terrain cursor sphere mesh.
---
--- @param radius number The radius of the sphere in game units.
--- @param color RGB The color of the sphere.
--- @return Mesh The placed sphere mesh.
function CreateTerrainCursorSphere(radius, color)
	color = color or RGB(23, 34, 122)
	radius = radius or 30 * guim
	
	local line = PlaceObject("Mesh")
	line:SetMesh(CreateSphereVertices(radius, color))
	line:SetShader(ProceduralMeshShaders.mesh_linelist)
	line:SetPos(GetTerrainCursor())
	line:SetMeshFlags(const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace)
	return line
end

--- Places a 3D orientation mesh at the specified position.
---
--- @param pos point The position to place the orientation mesh.
--- @return Mesh The placed orientation mesh.
function CreateOrientationMesh(pos)
	local o_mesh = Mesh:new()
	pos = pos or point(0, 0, 0) 
	o_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	local r = guim/4
	local vpstr = pstr("", 1024)
	AppendVertex(vpstr, point(0, 0, 0), RGB(255, 0, 0))
	AppendVertex(vpstr, point(r, 0, 0))
	AppendVertex(vpstr, point(0, 0, 0), RGB(0, 255, 0))
	AppendVertex(vpstr, point(0, r, 0))
	AppendVertex(vpstr, point(0, 0, 0), RGB(0, 0, 255))
	AppendVertex(vpstr, point(0, 0, r))
	o_mesh:SetMesh(vpstr)
	o_mesh:SetPos(pos)
	return o_mesh
end

--- Creates a new sphere mesh with the specified radius and color.
---
--- @param radius number The radius of the sphere in game units.
--- @param color RGB The color of the sphere.
--- @param precision number (optional) The precision of the sphere mesh. Higher values result in a smoother sphere.
--- @return Mesh The created sphere mesh.
function CreateSphereMesh(radius, color, precision)
	local sphere_mesh = Mesh:new()
	sphere_mesh:SetMesh(CreateSphereVertices(radius, color))
	sphere_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	return sphere_mesh
end

--- Places a new sphere mesh at the specified position with the given radius and color.
---
--- @param center point The position to place the sphere mesh.
--- @param radius number The radius of the sphere in game units.
--- @param color RGB The color of the sphere.
--- @param depth_test boolean (optional) Whether to enable depth testing for the sphere mesh.
--- @return Mesh The placed sphere mesh.
function PlaceSphere(center, radius, color, depth_test)
	local sphere = CreateSphereMesh(radius, color)
	if depth_test ~= nil then
		sphere:SetDepthTest(depth_test)
	end
	sphere:SetPos(center)
	return sphere
end

--- Shows a mesh for a specified time using the provided function.
---
--- @param time number The time in seconds to show the mesh.
--- @param func function The function to call to get the mesh(es) to show.
--- @param ... any Arguments to pass to the provided function.
--- @return thread The real-time thread that shows and hides the mesh(es).
function ShowMesh(time, func, ...)
	local ok, meshes = procall(func, ...)
	if not ok or not meshes then
		return
	end
	return CreateRealTimeThread(function(meshes, time)
		Msg("ShowMesh")
		WaitMsg("ShowMesh", time)
		if IsValid(meshes) then
			DoneObject(meshes)
		else
			DoneObjects(meshes)
		end
	end, meshes, time)
end

---
--- Creates a new circle mesh with the specified radius and color.
---
--- @param radius number The radius of the circle in game units.
--- @param color RGB The color of the circle.
--- @param center point The position of the circle's center.
--- @return Mesh The created circle mesh.
function CreateCircleMesh(radius, color, center)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendCircleVertices(nil, center, radius, color, true))
	circle_mesh:SetShader(ProceduralMeshShaders.default_polyline)
	return circle_mesh
end	

--- Places a circle mesh at the specified center position with the given radius and color.
---
--- @param center point The position to place the circle mesh.
--- @param radius number The radius of the circle in game units.
--- @param color RGB The color of the circle.
--- @param depth_test boolean (optional) Whether to enable depth testing for the circle mesh.
--- @return Mesh The placed circle mesh.
function PlaceCircle(center, radius, color, depth_test)
	local circle = CreateCircleMesh(radius, color)
	if depth_test ~= nil then
		circle:SetDepthTest(depth_test)
	end
	circle:SetPos(center)
	return circle
end

---
--- Creates a new cone mesh with the specified center, displacement, radii, axis, angle, and color.
---
--- @param center point The position of the cone's center.
--- @param displacement point The displacement of the cone's apex from the center.
--- @param radius1 number The radius of the cone's base.
--- @param radius2 number The radius of the cone's apex.
--- @param axis point The axis of the cone.
--- @param angle number The angle of the cone in degrees.
--- @param color RGB The color of the cone.
--- @return Mesh The created cone mesh.
function CreateConeMesh(center, displacement, radius1, radius2, axis, angle, color)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendConeVertices(nil, center, displacement, radius1, radius2, axis, angle, color))
	circle_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	return circle_mesh
end	

---
--- Creates a new cylinder mesh with the specified center, displacement, radius, axis, angle, and color.
---
--- @param center point The position of the cylinder's center.
--- @param displacement point The displacement of the cylinder's apex from the center.
--- @param radius number The radius of the cylinder.
--- @param axis point The axis of the cylinder.
--- @param angle number The angle of the cylinder in degrees.
--- @param color RGB The color of the cylinder.
--- @return Mesh The created cylinder mesh.
function CreateCylinderMesh(center, displacement, radius, axis, angle, color)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendConeVertices(nil, center, displacement, radius, radius, axis, angle, color))
	circle_mesh:SetShader(ProceduralMeshShaders.default_mesh)
	return circle_mesh
end	

---
--- Creates a new move gizmo and starts a real-time thread to update its position based on the terrain cursor.
---
--- The move gizmo is a visual representation of the object's position that can be used to manipulate the object's transform.
--- This function creates a new move gizmo instance and starts a real-time thread that updates the gizmo's position to match the terrain cursor's position.
--- The thread runs continuously, updating the gizmo's position every 100 milliseconds.
---
--- @return nil
function CreateMoveGizmo()
	local g_MoveGizmo = MoveGizmo:new()
	CreateRealTimeThread(function()
		while true do
			g_MoveGizmo:OnMousePos(GetTerrainCursor())
			Sleep(100)
		end
	end)
end

---
--- Creates a new torus mesh representing the terrain cursor.
---
--- The torus mesh is centered at the position of the selected object (selo()) and has a larger outer radius of 2.3 * guim and a smaller inner radius of 0.15 * guim. The torus is oriented along the y-axis by default, but can be rotated around the x, y, or z axes by specifying the `axis` and `angle` parameters.
---
--- The torus is rendered with a gradient of colors, with the default color being RGB(255, 0, 0). An additional larger torus is also rendered in a cyan color.
---
--- @param radius1 number The outer radius of the torus.
--- @param radius2 number The inner radius of the torus.
--- @param axis point The axis of the torus.
--- @param angle number The angle of the torus in degrees.
--- @param color RGB The color of the torus.
--- @return Mesh The created torus mesh.
function CreateTerrainCursorTorus(radius1, radius2, axis, angle, color)
	color = color or RGB(255, 0, 0)
	radius1 = radius1 or 2.3 * guim
	radius2 = radius2 or 0.15 * guim
	axis = axis or axis_y
	angle = angle or 90
	
	local line = PlaceObject("Mesh")
	local vpstr = pstr("", 1024)
	local normal = selo():GetPos() - camera.GetEye()
	local b = selo():GetPos()
	local bigTorusAxis, bigTorusAngle = GetAxisAngle(normal, axis_z)
	bigTorusAxis = Normalize(bigTorusAxis)
	bigTorusAngle = 180 - bigTorusAngle / 60
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, bigTorusAxis, bigTorusAngle, RGB(128, 128, 128))
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_y, 90, RGB(255, 0, 0), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_x, 90, RGB(0, 255, 0), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_z, 0, RGB(0, 0, 255), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 3.5 * guim, 0.15 * guim, bigTorusAxis, bigTorusAngle, RGB(0, 192, 192))
	line:SetMesh(vpstr)
	line:SetPos(selo():GetPos())
	return line
end

---
--- Creates a mesh representing the surface of a game object.
---
--- The mesh is created by iterating over the surfaces of the specified game object, and generating a triangle mesh for each surface. The mesh can be colored using a single color, or a gradient between two colors.
---
--- @param obj Game object The game object to create the surface mesh for.
--- @param surface_flag number A bitfield specifying which surfaces to include in the mesh.
--- @param color1 RGB The first color to use in the gradient.
--- @param color2 RGB The second color to use in the gradient.
--- @return Mesh The created surface mesh.
function CreateObjSurfaceMesh(obj, surface_flag, color1, color2)
	if not IsValidPos(obj) then
		return
	end
	local v_pstr = pstr("", 1024)
	ForEachSurface(obj, surface_flag, function(pt1, pt2, pt3, v_pstr, color1, color2)
		local color
		if color1 and color2 then
			local rand = xxhash(pt1, pt2, pt3) % 1024
			color = InterpolateRGB(color1, color2, rand, 1024)
		end
		v_pstr:AppendVertex(pt1, color)
		v_pstr:AppendVertex(pt2, color)
		v_pstr:AppendVertex(pt3, color)
	end, v_pstr, color1, color2)
	local mesh = PlaceObject("Mesh")
	mesh:SetMesh(v_pstr)
	mesh:SetPos(obj:GetPos())
	mesh:SetMeshFlags(const.mfWorldSpace)
	mesh:SetDepthTest(true)
	if color1 and not color2 then
		mesh:SetColorModifier(color1)
	end
	return mesh
end

---
--- Creates a flat image mesh with an optional glow effect.
---
--- @param texture string The texture to use for the image.
--- @param width number The width of the image in meters. Leave 0 to calculate automatically.
--- @param height number The height of the image in meters. Leave 0 to calculate automatically.
--- @param glow_size number The size of the glow effect in pixels.
--- @param glow_period number The period of the glow effect in seconds.
--- @param glow_color RGB The color of the glow effect.
--- @return Mesh The created image mesh.
function FlatImageMesh(texture, width, height, glow_size, glow_period, glow_color)
	local text = PlaceObject("Mesh")
	local vpstr = pstr("", 1024)
	local color = RGB(255,255,255)
	local half_size_x = width or 1000
	local half_size_y = height or 1000
	glow_size = glow_size or 0
	glow_period = glow_period or 0
	glow_color = glow_color or RGB(255,255,255)

	AppendVertex(vpstr, point(-half_size_x, -half_size_y, 0), color, 0, 0)
	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(half_size_x, half_size_y, 0), color, 1, 1)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	text:SetMesh(vpstr)

	if texture then
		local use_sdf = false
		local padding = 0
		local low_edge = 0
		local high_edge = 0
		if glow_size > 0 then
			use_sdf = true
			padding = 16
			low_edge = 490
			high_edge = 510
		end
		text:SetTexture(0, ProceduralMeshBindResource("texture", texture, false, 0))
		if glow_size > 0 then
			text:SetTexture(1, ProceduralMeshBindResource("texture", texture, true, 0, const.fmt_unorm16_c1))
			text:SetShader(ProceduralMeshShaders.default_ui_sdf)
		else
			text:SetShader(ProceduralMeshShaders.default_ui)
		end
		local r, g, b = GetRGB(glow_color)
		text:SetUniforms(low_edge, high_edge, glow_size, glow_period, r, g, b)
	end
	
	return text
end

DefineClass.FlatTextMesh = {
	__parents = { "Mesh" },
	properties = {
		{id = "font_id", editor = "number", read_only = true, default = 0, category = "Rasterize" },
		{id = "text_style_id", editor = "preset_id", preset_class = "TextStyle", editor_preview = true, default = false, category = "Rasterize" },
		{id = "text_scale", editor = "number", default = 1000, category = "Rasterize" },
		{id = "text", editor = "text", default = "", category = "Rasterize" },
		{id = "padding", editor = "number", default = 0, category = "Rasterize", help = "How much pixels to leave around the text(for effects)"},

		{id = "width", editor = "number", default = 0, category = "Present", help = "In meters. Leave 0 to calculate automatically"},
		{id = "height", editor = "number", default = 0, category = "Present", help = "In meters. Leave 0 to calculate automatically"},
		{id = "text_color", editor = "color", default = RGB(255,255,255), category = "Present"},
		{id = "effect_type", editor = "choice", items = {"none", "glow"}, default = "glow", category = "Present" },
		{id = "effect_color", editor = "color", default = RGB(255,255,255), category = "Present"},
		{id = "effect_size", editor = "number", default = 0, help = "In pixels from the rasterized image.", category = "Present" },
		{id = "effect_period", editor = "number", default = 0, help = "1 pulse per each period seconds. ", category = "Present"},
	}
}

--- Initializes the FlatTextMesh object by calling the Recreate() function.
-- This function is called when the FlatTextMesh object is first created.
-- It sets up the initial state of the text mesh, including the font, text style, and other properties.
-- @function FlatTextMesh:Init
-- @return nil
function FlatTextMesh:Init()
	self:Recreate()
end

---
--- Fetches the effects properties (color, size, type) from the specified text style and applies them to the FlatTextMesh object.
---
--- @param self FlatTextMesh The FlatTextMesh object.
function FlatTextMesh:FetchEffectsFromTextStyle()
	local text_style = TextStyles[self.text_style_id]
	if not text_style then return end
	self.text_color = text_style.TextColor
	self.effect_type = text_style.ShadowType == "glow" and "glow" or "none"
	self.effect_color = text_style.ShadowColor
	self.effect_size = text_style.ShadowSize
	self.textstyle_id = self.text_style_id
end

---
--- Sets the color and effect properties of the FlatTextMesh object based on the specified text style.
---
--- @param self FlatTextMesh The FlatTextMesh object.
--- @param text_style_id number The ID of the text style to apply.
function FlatTextMesh:SetColorFromTextStyle(text_style_id)
	self.text_style_id = text_style_id
	self.textstyle_id = text_style_id
	self:FetchEffectsFromTextStyle()
	self:Recreate()
end

---
--- Calculates the width and height of the FlatTextMesh object based on the provided maximum width and height, and the default scale.
---
--- @param self FlatTextMesh The FlatTextMesh object.
--- @param max_width number The maximum width of the text mesh, in meters.
--- @param max_height number The maximum height of the text mesh, in meters.
--- @param default_scale number The default scale to use if the maximum width and height are both 0.
--- @return nil
function FlatTextMesh:CalculateSizes(max_width, max_height, default_scale)
	local width_pixels, height_pixels = UIL.MeasureText(self.text, self.font_id)
	local scale = 0
	if max_width == 0 and max_height == 0 then
		scale = default_scale or 10000
	elseif max_width == 0 then
		max_width = 1000000
	elseif max_height == 0 then
		max_height = 1000000
	end

	if scale == 0 then
		local scale1 = MulDivRound(max_width, 1000, width_pixels)
		local scale2 = MulDivRound(max_height, 1000, height_pixels)
		scale = Min(scale1, scale2)
	end

	self.width = MulDivRound(width_pixels, scale, 1000)
	self.height = MulDivRound(height_pixels, scale, 1000)
end

---
--- Recreates the FlatTextMesh object by updating its mesh and textures based on the current text style and effect settings.
---
--- @param self FlatTextMesh The FlatTextMesh object to recreate.
--- @return nil
function FlatTextMesh:Recreate()
	local text_style = TextStyles[self.text_style_id]
	if not text_style then return end
	local font_id = text_style:GetFontIdHeightBaseline(self.text_scale)
	self.font_id = font_id

	local effect_type = self.effect_type
	local use_sdf = false
	local padding = 0
	if effect_type == "glow" then
		use_sdf = true
		padding = 16
	end

	local width_pixels, height_pixels = UIL.MeasureText(self.text, font_id)
	local width = self.width
	local height = self.height
	if width == 0 and height == 0 then
		local default_scale = 10000
		width = MulDivRound(width_pixels, default_scale, 1000)
		height = MulDivRound(height_pixels, default_scale, 1000)
	end
	if width == 0 then
		width = MulDivRound(width_pixels, height, height_pixels)
	end
	if height == 0 then
		height = MulDivRound(height_pixels, width, width_pixels)
	end
	
	--add for padding
	width = width + MulDivRound(width, padding * 2 * 1000, width_pixels * 1000)
	height = height + MulDivRound(height, padding * 2 * 1000, height_pixels * 1000)


	local vpstr = pstr("", 1024)
	local half_size_x = (width or 1000) / 2
	local half_size_y = (height or 1000) / 2
	local color = self.text_color
	AppendVertex(vpstr, point(-half_size_x, -half_size_y, 0), color, 0, 0)
	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(half_size_x, half_size_y, 0), color, 1, 1)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	self:SetMesh(vpstr)

	self:SetTexture(0, ProceduralMeshBindResource("text", self.text, font_id, use_sdf, padding))
	local r, g, b = GetRGB(self.effect_color)
	self:SetUniforms(use_sdf and 1000 or 0, 0, self.effect_size * 1000, self.effect_period, r, g, b)
	self:SetShader(ProceduralMeshShaders.default_ui)
end

---
--- Renders a set of UI elements, including text and images, at a specified position on the terrain.
---
--- @param pt point The position on the terrain where the UI elements will be rendered.
---
function TestUIRenderables()
	local pt = GetTerrainCursor() + point(0, 0, 100)
	for i = 0, 4 do
		local height = 700
		local space = 5000

		local text = FlatTextMesh:new({
			text_style_id = "ProcMeshDefault",
			text_scale = 500 + 400 * i,
			text = "Hello world",
			height = height,
		})
		text:SetPos(pt + point(i * space, 0, 0))

		text = FlatTextMesh:new({
			text_style_id = "ProcMeshDefaultFX",
			text_scale = 500 + 400 * i,
			text = "Hello world",
			height = height,
			effect_type = "glow",
			effect_size = 8,
			effect_period = 200,
			effect_color = RGB(255, 0, 0),
		})
		text:SetPos(pt + point(i * space, 3000, 0))
		text:SetGameFlags(const.gofRealTimeAnim)

		local mesh = FlatImageMesh("UI/MercsPortraits/Buns", 1000, 1000, 200 * i, 1000, RGB(255, 255, 255))
		mesh:SetPos(pt + point(i * space, 6000, 0))

		mesh = FlatImageMesh("UI/MercsPortraits/Buns", 1000, 1000)
		mesh:SetPos(pt + point(i * space, 9000, 0))
	end
end

---
--- Displays a list of all mesh objects in the current map in the Game Object Editor.
---
function DebugShowMeshes()
	local meshes = MapGet("map", "Mesh")
	OpenGedGameObjectEditor(meshes, true)
end

-- Represents combination of shader & the data the shader accepts. Provides "properties" interface for the underlying raw bits sent to the shader.
-- Inherits from PersistedRenderVars(is a preset) and provides minimalistic default logic for updating meshes on the fly.
local function depth_test_values(obj)
	local tbl = {{value = "default", text = "default"}}
	local shader_id = obj.shader_id
	local shader_data = ProceduralMeshShaders[shader_id]
	if shader_data then
		if shader_data.depth_test == "runtime" or shader_data.depth_test == "never" then
			table.insert(tbl, {value = false, text = "never"})
		end
		if shader_data.depth_test == "runtime" or shader_data.depth_test == "always" then
			table.insert(tbl, {value = true, text = "always"})
		end
	end
	return tbl
end
DefineClass.CRMaterial = {
	__parents = {"PersistedRenderVars", "MeshParamSet"},

	properties = { 
		{ id = "ShaderName", editor = "choice", default = "default_mesh", items = function() return table.keys2(ProceduralMeshShaders, "sorted") end, read_only = true,},
		{ id = "depth_test", editor = "choice", items = depth_test_values },
	},
	group = "CRMaterial",
	depth_test = "default",
	cloned_from = false,
	shader_id = "default_mesh",
	shader = false,
	pstr_buffer = false,
	dirty = false,
}

---
--- Returns an error message if the CRMaterial object is invalid.
---
--- If the `shader_id` property is not set, returns "CRMaterial without a shader_id."
--- If the `shader_id` property references a shader that is not valid, returns "ShaderID <shader_id> is not valid."
---
--- @return string|nil error message if the CRMaterial is invalid, nil otherwise
function CRMaterial:GetError()
	if not self.shader_id then
		return "CRMaterial without a shader_id."
	end
	if not ProceduralMeshShaders[self.shader_id] then
		return "ShaderID " .. self.shader_id .. " is not valid."
	end
end

---
--- Returns the shader associated with this CRMaterial object.
---
--- If the `shader` property is set, returns that.
--- Otherwise, if the `shader_id` property is set, returns the shader from the `ProceduralMeshShaders` table with that ID.
--- If neither `shader` nor `shader_id` are set, returns `false`.
---
--- @return table|boolean the shader associated with this CRMaterial, or `false` if no shader is set
function CRMaterial:GetShader()
	if self.shader then
		return self.shader
	end
	if self.shader_id then
		return ProceduralMeshShaders[self.shader_id]
	end
	return false
end

------- Prevent triggering Preset logic on cloned materials. Probably should be implemented smarter, maybe by __index table reference, so even clones are live updated by editor
---
--- Sets the ID of the CRMaterial object.
---
--- If the CRMaterial object is cloned from another object, this sets the ID of the cloned object.
--- Otherwise, it calls the `SetId` method of the `PersistedRenderVars` class to set the ID.
---
--- @param value string the new ID for the CRMaterial object
--- @return void
function CRMaterial:SetId(value)
	if self.cloned_from then
		self.id = value
	else
		PersistedRenderVars.SetId(self, value)
	end
end

---
--- Sets the group of the CRMaterial object.
---
--- If the CRMaterial object is cloned from another object, this sets the group of the cloned object.
--- Otherwise, it calls the `SetGroup` method of the `PersistedRenderVars` class to set the group.
---
--- @param value string the new group for the CRMaterial object
--- @return void
function CRMaterial:SetGroup(value)
	if self.cloned_from then
		self.group = value
	else
		PersistedRenderVars.SetGroup(self, value)
	end
end

---
--- Registers the CRMaterial object with the PersistedRenderVars class.
---
--- If the CRMaterial object is cloned from another object, this method does nothing.
--- Otherwise, it calls the `Register` method of the `PersistedRenderVars` class to register the CRMaterial object.
---
--- @param ... any additional arguments to pass to the `PersistedRenderVars.Register` method
--- @return any the return value of the `PersistedRenderVars.Register` method
function CRMaterial:Register(...)
	if self.cloned_from then
		return
	end
	return PersistedRenderVars.Register(self, ...)
end

---
--- Creates a clone of the CRMaterial object.
---
--- This method creates a new CRMaterial object that is a clone of the current object. The new object has the `cloned_from` field set to the ID of the current object, and all properties are copied from the current object to the new object.
---
--- @return CRMaterial the cloned CRMaterial object
function CRMaterial:Clone()
	local obj = _G[self.class]:new({cloned_from = self.id})
	obj:CopyProperties(self)
	return obj
end

---
--- Returns the persisted render buffer for the CRMaterial object.
---
--- If the CRMaterial object is dirty or the persisted render buffer does not exist, this method calls the `Recreate` method to update the persisted render buffer.
---
--- @return string the persisted render buffer for the CRMaterial object
function CRMaterial:GetDataPstr()
	if self.dirty or not self.pstr_buffer then
		self:Recreate()
	end
	return self.pstr_buffer
end

--- Returns the shader ID for the CRMaterial object.
---
--- If the `shader` field is set, this method returns the `id` property of the `shader` field. Otherwise, it returns the `shader_id` field.
---
--- @return string the shader ID for the CRMaterial object
function CRMaterial:GetShaderName()
	return self.shader and self.shader.id or self.shader_id
end

---
--- Recreates the persisted render buffer for the CRMaterial object.
---
--- This method sets the `dirty` flag to `false` and then calls the `WriteBuffer` method to generate a new persisted render buffer, which is stored in the `pstr_buffer` field.
---
--- @return nil
function CRMaterial:Recreate()
	self.dirty = false
	self.pstr_buffer = self:WriteBuffer()
end

---
--- Called before the CRMaterial object is saved.
---
--- This method sets the `pstr_buffer` field to `nil`, which will cause the `Recreate` method to be called the next time the `GetDataPstr` method is called. This ensures that the persisted render buffer is regenerated when the object is loaded.
---
--- @return nil
function CRMaterial:OnPreSave()
	self.pstr_buffer = nil
end

---
--- Applies the CRMaterial object to all meshes in the current map that reference it.
---
--- If the CRMaterial object is dirty, the `Recreate` method is called to update the persisted render buffer.
---
--- For each mesh in the current map that references the CRMaterial object, this method checks if the mesh's CRMaterial is the same as the current CRMaterial object. If so, the mesh's CRMaterial is set to the current CRMaterial object.
---
--- If the mesh's CRMaterial is not the same as the current CRMaterial object, but has the same ID, this method copies the properties from the current CRMaterial object to the mesh's CRMaterial object, calls the `Recreate` method on the mesh's CRMaterial object, and then sets the mesh's CRMaterial to the updated object.
---
--- @return nil
function CRMaterial:Apply()
	self:Recreate()
	if CurrentMap ~= "" then
		MapGet("map", "Mesh", function(o)
			local omtrl = o.CRMaterial
			if omtrl == self then
				o:SetCRMaterial(self)
			elseif (omtrl and omtrl.id == self.id) then
				for _, prop in ipairs(omtrl:GetProperties()) do
					local value = rawget(omtrl, prop.id)
					if value == nil or (not prop.read_only and not prop.no_edit) then
						omtrl:SetProperty(prop.id, self:GetProperty(prop.id))
					end
				end
				omtrl:Recreate()
				o:SetCRMaterial(omtrl)
			end
		end)
	end
end



DefineClass.CRM_DebugMeshMaterial = {
	__parents = {"CRMaterial"},

	shader_id = "debug_mesh",
	properties = {
	},
}

