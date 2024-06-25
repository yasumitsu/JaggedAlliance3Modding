
--- Toggles whether atmospheric particles are hidden or not.
---
--- This variable is set to `false` on first load, indicating that atmospheric particles should be visible.
---
--- @field g_AtmosphericParticlesHidden boolean
--- @within CommonLua.AtmosphericParticles
MapVar("g_AtmosphericParticlesHidden", false)
if FirstLoad then
	g_AtmosphericParticlesThread = false
	g_AtmosphericParticles = false
	g_AtmosphericParticlesPos = false
end
function OnMsg.DoneMap()
	g_AtmosphericParticlesThread = false
	g_AtmosphericParticles = false
	g_AtmosphericParticlesPos = false
end

--- Applies atmospheric particles to the scene.
---
--- This function sets up the atmospheric particles by creating a thread to update their positions, and initializing the particle objects and their positions.
---
--- If `mapdata.AtmosphericParticles` is an empty string, this function will return without doing anything.
---
--- @function AtmosphericParticlesApply
--- @within CommonLua.AtmosphericParticles
function AtmosphericParticlesApply()
    if g_AtmosphericParticlesThread then
        DeleteThread(g_AtmosphericParticlesThread)
        g_AtmosphericParticlesThread = false
    end
    DoneObjects(g_AtmosphericParticles)
    g_AtmosphericParticles = false
    g_AtmosphericParticlesPos = false
    if mapdata.AtmosphericParticles == "" then
        return
    end
    g_AtmosphericParticles = {}
    g_AtmosphericParticlesPos = {}
    g_AtmosphericParticlesThread = CreateGameTimeThread(function()
        while true do
            AtmosphericParticlesUpdate()
            Sleep(100)
        end
    end)
end

--- Updates the positions of the atmospheric particles.
---
--- This function is responsible for managing the atmospheric particles in the scene. It determines the number of particles to display based on whether they are currently hidden or not, and the number of views. It then creates, destroys, and updates the positions of the particles as needed.
---
--- If `g_AtmosphericParticlesPos` is `false`, this function will return without doing anything.
---
--- If the distance between the two camera positions is less than 10 game units, this function will average the positions of the two cameras and only display one particle.
---
--- This function is called repeatedly in a game time thread created by `AtmosphericParticlesApply()`.
---
--- @function AtmosphericParticlesUpdate
--- @within CommonLua.AtmosphericParticles
function AtmosphericParticlesUpdate()
    local part_pos = g_AtmosphericParticlesPos
    if not part_pos then
        return
    end
    -- see how many particles we need, depending on whether they currently hidden, 
    -- number of views and how close are the two cameras in case of two views
    local part_number = g_AtmosphericParticlesHidden and 0 or camera.GetViewCount()
    for view = 1, part_number do
        part_pos[view] = camera.GetEye(view) + SetLen(camera.GetDirection(view), 7 * guim)
    end
    if part_number == 2 and part_pos[1]:Dist(part_pos[2]) < 10 * guim then
        part_pos[1] = (part_pos[1] + part_pos[2]) / 2
        part_number = 1
    end

    -- create/destroy particles as needed and update positions
    local part = g_AtmosphericParticles
    for i = 1, Max(#part, part_number) do
        if not IsValid(part[i]) then -- the particles coule be destroyed by code like NetSetGameState()
            part[i] = PlaceParticles(mapdata.AtmosphericParticles)
        end
        if i > part_number then
            if g_AtmosphericParticlesHidden then
                DoneObject(part[i])
            else
                StopParticles(part[i])
            end
            part[i] = nil
        elseif terrain.IsPointInBounds(part_pos[i]) and part_pos[i]:z() < 2000000 then
            part[i]:SetPos(part_pos[i])
        end
    end
end

--- Sets whether the atmospheric particles are hidden or not.
---
--- @function AtmosphericParticlesSetHidden
--- @within CommonLua.AtmosphericParticles
--- @param hidden boolean Whether the atmospheric particles should be hidden or not.
function AtmosphericParticlesSetHidden(hidden)
    g_AtmosphericParticlesHidden = hidden
end

function OnMsg.SceneStarted(scene)
	if scene.hide_atmospheric_particles then
		AtmosphericParticlesSetHidden(true)
	end
end

function OnMsg.SceneStopped(scene)
	if scene.hide_atmospheric_particles then
		AtmosphericParticlesSetHidden(false)
	end
end
