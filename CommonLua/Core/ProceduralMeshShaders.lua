---
--- Initializes the ProceduralMeshShaders table and provides a function to register new procedural mesh shaders.
---
--- The `InsertProceduralMeshShaders` function takes a table of shader definitions and registers them in the `ProceduralMeshShaders` table.
--- Each shader definition is a table with the following fields:
---
--- - `shaderid`: The ID of the shader file to use.
--- - `defines`: A table of preprocessor defines to apply to the shader.
--- - `name`: The unique name to identify the shader.
--- - `topology`: The primitive topology to use for the mesh.
--- - `cull_mode`: The culling mode to use for the mesh.
--- - `blend_mode`: The blend mode to use for the mesh.
--- - `depth_test`: The depth testing mode to use for the mesh.
--- - `pass_type`: The pass type for the shader (optional).
---
--- The `RegisterProceduralMeshRules` function is called to register the new shaders with the rendering system.
---
if FirstLoad then
    ProceduralMeshShaders = {}
    function InsertProceduralMeshShaders(ProceduralMeshShadersTable)
        RegisterProceduralMeshRules(ProceduralMeshShadersTable)

        for key, value in ipairs(ProceduralMeshShadersTable) do
            assert(not ProceduralMeshShaders[value.name], "Shader with that name already registered.")
            ProceduralMeshShaders[value.name] = value
        end
    end
    -- CommonShaders. Feel free to make such call in project specific render.lua
    InsertProceduralMeshShaders({{shaderid="ProceduralMesh.fx", defines={}, name="default_polyline",
        topology=const.ptLineStrip, cull_mode=const.cullModeNone, blend_mode=const.blendNone, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={}, name="default_mesh", topology=const.ptTriangleList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNormal, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={}, name="solid_mesh", topology=const.ptTriangleList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNone, depth_test="always"},
        {shaderid="ProceduralMesh.fx", defines={}, name="defer_mesh", topology=const.ptTriangleStrip,
            cull_mode=const.cullModeBack, blend_mode=const.blendNone, depth_test="always", pass_type=const.PassDefer},
        {shaderid="ProceduralMesh.fx", defines={"DEBUGM"}, name="debug_mesh", topology=const.ptTriangleList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNormal, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={"SOFT"}, name="soft_mesh", topology=const.ptTriangleList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNormal, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={}, name="mesh_linelist", topology=const.ptLineList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNone, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={"UI"}, name="default_ui", topology=const.ptTriangleList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNormal, depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={"UI", "TEX1_AS_SDF"}, name="default_ui_sdf",
            topology=const.ptTriangleList, cull_mode=const.cullModeNone, blend_mode=const.blendNormal,
            depth_test="runtime"},
        {shaderid="ProceduralMesh.fx", defines={}, name="blended_linelist", topology=const.ptLineList,
            cull_mode=const.cullModeNone, blend_mode=const.blendNormal, depth_test="runtime"}})
end
