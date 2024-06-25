---
--- Sets up the rendering environment for capturing billboards.
---
--- This function performs the following steps:
--- - Changes the current map to an empty map
--- - Waits for 5 frames
--- - Activates the `cameraMax` camera and sets its viewport, field of view, and locks it
--- - Changes the video mode to the billboard screenshot capture size
--- - Configures various rendering settings for billboard capture, such as:
---   - Setting the object LOD cap to 100
---   - Disabling terrain rendering
---   - Disabling auto-exposure
---   - Disabling subsurface scattering
---   - Setting the resolution to 100% with SMAA upscaling
---   - Disabling shadows
---   - Setting the near and far planes to 100 and 100,000 respectively
---   - Enabling orthographic projection with a Y scale of 1000
--- - Deletes the current map and waits for 3 frames
---
function SetupBillboardRendering()
    ChangeMap("__Empty")
    WaitNextFrame(5)

    cameraMax.Activate(1)
    camera.SetViewport(box(0, 0, 1000000, 1000000))
    camera.SetFovX(83 * 60)
    camera.Lock(1)

    ChangeVideoMode(hr.BillboardScreenshotCaptureSize, hr.BillboardScreenshotCaptureSize, 0, false, false)

    table.change(hr, "BillboardCapture",
        {ObjectLODCapMax=100, ObjectLODCapMin=100, RenderBillboards=0, RenderTerrain=0, AutoExposureMode=0,
            EnableSubsurfaceScattering=0, ResolutionPercent=100, ResolutionUpscale="smaa", MaxFps=0, Shadowmap=0,
            NearZ=100, FarZ=100000, Ortho=1, OrthoYScale=1000})

    MapDelete("map", nil)
    WaitNextFrame(3)
end

---
--- Defines a class for billboard objects.
---
--- This class inherits from `EntityClass` and has the following properties:
---
--- - `flags`: A table of flags, including `efHasBillboard` which indicates that this object has a billboard.
--- - `ignore_axis_error`: A boolean flag that determines whether to ignore errors related to the object's axis.
---
DefineClass.BillboardObject = {__parents={"EntityClass"}, flags={efHasBillboard=true}, ignore_axis_error=false}
---
--- Returns an error message if the billboard object has an invalid axis.
---
--- If the object has a billboard (`efHasBillboard` flag is set) and `ignore_axis_error` is false, this function checks the object's visual axis. If the X or Y axis is non-zero, or the Z axis is non-positive, it returns an error message indicating that the billboard object should have the default axis.
---
--- @return string|nil An error message if the billboard object has an invalid axis, or nil if the axis is valid or `ignore_axis_error` is true.
function BillboardObject:GetError()
end

function BillboardObject:GetError()
    if self:GetEnumFlags(const.efHasBillboard) ~= 0 and not self.ignore_axis_error then
        local x, y, z = self:GetVisualAxisXYZ()
        if x ~= 0 or y ~= 0 or z <= 0 then
            return "Billboard objects should have default axis"
        end
    end
end
---
--- Returns a sorted list of all `BillboardObject` classes and their descendants.
---
--- This function traverses the class hierarchy starting from the `BillboardObject` class, and collects all valid entities that are instances of `BillboardObject` or its descendants. The resulting list is sorted by the class name.
---
--- @return table A table of `BillboardObject` class definitions, sorted by class name.
function BillboardsTree()
end

function BillboardsTree()
    local billboard_classes = {}
    ClassDescendantsList("BillboardObject", function(name, classdef, billboard_classes)
        if IsValidEntity(classdef:GetEntity()) then
            table.insert(billboard_classes, classdef)
        end
    end, billboard_classes)
    table.sortby_field(billboard_classes, "class")
    return billboard_classes
end
---
--- Bakes a billboard for the selected object in the GED.
---
--- This function resolves the selected object in the GED and then calls `BakeEntityBillboard` to generate a billboard for that object.
---
--- @param ged The GED object.
function GedBakeBillboard(ged)
end

function GedBakeBillboard(ged)
    local obj = ged:ResolveObj("SelectedObject")
    if not obj then
        return
    end
    BakeEntityBillboard(obj:GetEntity())
end
---
--- Bakes a billboard for the specified entity.
---
--- This function generates a billboard for the given entity by executing an external command. The command is constructed using the entity's name and executed asynchronously. If an error occurs during the billboard generation, it is printed to the console.
---
--- @param entity string The name of the entity to generate a billboard for.
function BakeEntityBillboard(entity)
end

function BakeEntityBillboard(entity)
    if not entity then
        return
    end
    local cmd = string.format("cmd /c Build GenerateBillboards --billboard_entity=%s", entity)
    local dir = ConvertToOSPath("svnProject/")
    local err = AsyncExec(cmd, dir, true, true)
    if err then
        print("Failed to create billboard for %s: %s", entity, err)
    end
end
---
--- Spawns a billboard object at the cursor position, with a random offset.
---
--- This function resolves the selected object in the GED and then places multiple instances of that object in a grid pattern around the cursor position, with a random offset applied to each instance.
---
--- @param ged The GED object.
function GedSpawnBillboard(ged)
end

function GedSpawnBillboard(ged)
    local obj = ged:ResolveObj("SelectedObject")
    if not obj then
        return
    end

    local pos = GetTerrainCursorXY(UIL.GetScreenSize() / 2)
    local step = 20 * guim
    SuspendPassEdits("spawn billboards")
    for y = -50, 50 do
        for x = -50, 50 do
            local o = PlaceObject(obj.class)
            local curr_pos = pos + point(x * step + (AsyncRand(21) - 11) * guim, y * step + (AsyncRand(21) - 11) * guim)
            local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
            o:SetPos(curr_pos)
        end
    end
    ResumePassEdits("spawn billboards")
end
---
--- Spawns a grid of billboard objects around the cursor position, with a random offset.
---
--- This function resolves the selected object in the GED and then places multiple instances of that object in a grid pattern around the cursor position, with a random offset applied to each instance. This can be used to debug billboard rendering.
---
--- @param ged The GED object.
function GedDebugBillboards(ged)
end

function GedDebugBillboards(ged)
    hr.BillboardDebug = 1
    hr.BillboardDistanceModifier = 10000
    hr.ObjectLODCapMax = 100
    hr.ObjectLODCapMin = 100

    local pos = GetTerrainCursorXY(UIL.GetScreenSize() / 2)
    local step = 12 * guim

    local billboard_entities = {}
    for k, v in ipairs(GetClassAndDescendantsEntities("BillboardObject")) do
        if IsValidEntity(v) then
            billboard_entities[#billboard_entities + 1] = v
        end
    end

    local i = 1
    for y = -10, 10 do
        for x = -5, 5 do
            local entity = billboard_entities[i]
            if i == #billboard_entities then
                i = 0
            end
            i = i + 1
            local o = PlaceObject(entity)
            local curr_pos = pos + point(x * step * 2, y * step)
            local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
            o:SetPos(curr_pos)
        end
    end
end

---
--- Generates billboards for all billboard objects in the game.
---
--- This function executes an external command to generate billboards for all billboard objects in the game. It uses the `GenerateBillboards` function to create the billboards.
---
--- @param ged The GED object.
function GedBakeAllBillboards(ged)
end

function GedBakeAllBillboards(ged)
    local cmd = string.format("cmd /c Build GenerateBillboards")
    local dir = ConvertToOSPath("svnProject/")

    local err = AsyncExec(cmd, dir, true, true)
    if err then
        print("Failed to create billboards!")
    end
end
---
--- Generates billboards for all billboard objects in the game.
---
--- This function executes an external command to generate billboards for all billboard objects in the game. It uses the `GenerateBillboards` function to create the billboards.
---
--- @param ged The GED object.
function GedBakeAllBillboards(ged)
end

function GenerateBillboards(specific_entity)
    CreateRealTimeThread(function()
        SetupBillboardRendering()

        local billboard_entities = {}
        if specific_entity then
            billboard_entities[specific_entity] = true
        else
            ClassDescendantsList("BillboardObject", function(name, classdef, billboard_entities)
                local ent = classdef:GetEntity()
                if IsValidEntity(ent) then
                    billboard_entities[ent] = true
                end
            end, billboard_entities)
        end

        local o = PlaceObject("Shapeshifter")
        o:SetPos(point(0, 0))

        local OctahedronSize = hr.BillboardScreenshotGridWidth - 1

        local screenshot_downsample = hr.BillboardScreenshotCaptureSize / hr.BillboardScreenshotSize
        local unneeded_lods
        local power = 1
        for i = 0, 10 do
            if power == screenshot_downsample then
                unneeded_lods = i
                break
            end
            power = power * 2
        end

        local dir = ConvertToOSPath("svnAssets/BuildCache/win32/Billboards/")
        AsyncCreatePath("svnAssets/BuildCache/win32/Billboards/")

        for ent, _ in pairs(billboard_entities) do
            hr.MipmapLodBias = unneeded_lods * 1000

            o:ChangeEntity(ent)
            local bbox = o:GetEntityBBox()
            local bbox_center = bbox:Center()
            local camera_target = o:GetVisualPos() + bbox_center

            WaitNextFrame(5)

            local dlc_name = EntitySpecPresets[ent].save_in
            if dlc_name ~= "" then
                dlc_name = dlc_name .. "\\"
            end
            local curr_dir = dir .. dlc_name
            local err = AsyncCreatePath(curr_dir)
            assert(not err)

            local _, radius = o:GetBSphere()
            local draw_radius = (radius * 173) / 100
            local max_range = radius * OctahedronSize
            local half_max = (max_range * 173) / 100 + (hr.BillboardScreenshotGridWidth % 2 == 0 and 1 or 0)

            local bc_atlas = curr_dir .. ent .. "_bc.tga"
            local nm_atlas = curr_dir .. ent .. "_nm.tga"
            local rt_atlas = curr_dir .. ent .. "_rt.tga"
            local siao_atlas = curr_dir .. ent .. "_siao.tga"
            local depth_atlas = curr_dir .. ent .. "_dep.tga"
            local borders = curr_dir .. ent .. "_bor.dds"
            local id = 0

            hr.OrthoX = radius * 2

            BeginCaptureBillboardEntity(bc_atlas, nm_atlas, rt_atlas, siao_atlas, depth_atlas, borders)
            for y = 0, OctahedronSize do
                for x = 0, OctahedronSize do
                    local curr_x, curr_y, curr_z = BillboardMap(x, y, OctahedronSize, half_max)
                    local pos = SetLen(point(curr_x, curr_y, curr_z), draw_radius)
                    SetCamera(camera_target + pos, camera_target)

                    WaitNextFrame(1)
                    CaptureBillboardFrame(draw_radius, id)
                    WaitNextFrame(1)

                    id = id + 1
                end
            end
            WaitNextFrame(1)
        end
        WaitNextFrame(100)
        quit()
    end)
end
---
--- Checks if the given object has a billboard associated with it.
---
--- @param obj table The object to check for a billboard.
--- @return boolean True if the object has a billboard, false otherwise.
function HasBillboard(obj)
    return hr.BillboardEntities and IsValid(obj) and IsValidEntity(obj:GetEntity())
               and not not table.find(hr.BillboardEntities, obj:GetEntity())
end


---
--- Gets a list of all billboard entities in the game.
---
--- @param err_print function An optional function to call if there are any errors finding billboard entities.
--- @return table A table of all valid billboard entity names.
function GetBillboardEntities(err_print)
    if hr.BillboardDirectory then
        hr.BillboardDirectory = "Textures/Billboards/"
        local suffix = Platform.playstation and "_bc.hgt" or "_bc.dds"
        local err, textures = AsyncListFiles("Textures/Billboards", "*" .. suffix, "relative")

        local billboard_entities = {}
        for _, entity in ipairs(GetClassAndDescendantsEntities("BillboardObject")) do
            local check_texture = not Platform.developer or Platform.console or table.find(textures, entity .. suffix)
            if not check_texture then
                err_print("Entity %s is marked as a billboard entity, but has no billboard textures!", entity)
            end
            if IsValidEntity(entity) and check_texture then
                billboard_entities[#billboard_entities + 1] = entity
            end
        end

        hr.BillboardEntities = billboard_entities
    end
end

---
--- Stress tests the billboards in the game by randomly placing and removing tree objects.
---
--- This function creates a real-time thread that continuously places and removes tree objects
--- at random positions within a certain radius. The function keeps track of the number of
--- objects placed and removed, and sleeps for a short period of time after every 1000 iterations.
---
--- This function is likely used for testing and debugging purposes to ensure the billboards
--- are rendering correctly and efficiently.
---
--- @function StressTestBillboards
--- @return nil
function StressTestBillboards()
    CreateRealTimeThread(function()
        local count = 0
        while true do
            local pos = point((1000 + AsyncRand(4144)) * guim, (1000 + AsyncRand(4144)) * guim)
            local o = MapGetFirst(pos:x(), pos:y(), 100, "Tree_01")
            if o then
                DoneObject(o)
                local new = PlaceObject("Tree_01")
                local curr_pos = point((1000 + AsyncRand(4144)) * guim, (1000 + AsyncRand(4144)) * guim)
                local real_pos = point(curr_pos:x(), curr_pos:y(), terrain.GetHeight(curr_pos:x(), curr_pos:y()))
                new:SetPos(real_pos)
            end
            count = count + 1
            if count == 1000 then
                count = 0
                Sleep(100)
            end
        end
    end)
end

function OnMsg.ClassesPostprocess()
	CreateRealTimeThread(function()
		GetBillboardEntities(function(...) printf("once", ...) end)
	end)
end