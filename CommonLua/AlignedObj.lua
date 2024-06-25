DefineClass.AlignedObj = {
	__parents = { "EditorCallbackObject" },
	flags = { cfAlignObj = true },
}

-- gets pos and angle from the object if not passed; this base method does not implement this and should not be called
---
--- Aligns the object to a specific position and angle.
--- This base implementation does nothing and should not be called directly.
---
--- @param pos table|nil The position to align the object to. If not provided, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If not provided, the object's current angle is used.
---
function AlignedObj:AlignObj(pos, angle)
    assert(not pos and not angle)
end

---
--- Called when the object is placed in the editor.
--- Aligns the object to its current position and angle.
---
function AlignedObj:EditorCallbackPlace()
    self:AlignObj()
end

---
--- Called when the object is moved in the editor.
--- Aligns the object to its current position and angle.
---
function AlignedObj:EditorCallbackMove()
    self:AlignObj()
end

---
--- Called when the object is rotated in the editor.
--- Aligns the object to its current position and angle.
---
function AlignedObj:EditorCallbackRotate()
    self:AlignObj()
end

---
--- Called when the object is scaled in the editor.
--- Aligns the object to its current position and angle.
---
function AlignedObj:EditorCallbackScale()
    self:AlignObj()
end

---
--- Aligns a HexAlignedObj object to a specific position and angle.
---
--- @param pos table|nil The position to align the object to. If not provided, the object's current position is used.
--- @param angle number|nil The angle to align the object to. If not provided, the object's current angle is used.
---
function HexAlignedObj:AlignObj(pos, angle)
    self:SetPosAngle(HexGetNearestCenter(pos or self:GetPos()), angle or self:GetAngle())
end
if const.HexWidth then
    DefineClass("HexAlignedObj", "AlignedObj")

    function HexAlignedObj:AlignObj(pos, angle)
        self:SetPosAngle(HexGetNearestCenter(pos or self:GetPos()), angle or self:GetAngle())
    end
end

---
--- Realigns all AlignedObj objects in the current map when a new map is loaded.
---
--- This function is called when a new map is loaded. It suspends pass edits, then iterates through all AlignedObj objects in the map that are not parented to another object. For each object, it calls the AlignObj() method to realign the object to its current position and angle. If the object's position or angle has changed, a counter is incremented. After all objects have been realigned, the pass edits are resumed and a message is printed indicating how many objects were realigned.
---
--- This function is only defined when the Platform.developer flag is true, indicating that the game is running in a development environment.
---
if Platform.developer then
    function OnMsg.NewMapLoaded()
        local aligned = 0
        SuspendPassEdits("AlignedObjWarning")
        MapForEach("map", "AlignedObj", function(obj)
            if obj:GetParent() then
                return
            end
            local x1, y1, z1 = obj:GetPosXYZ()
            local a1 = obj:GetAngle()
            obj:AlignObj()
            local x2, y2, z2 = obj:GetPosXYZ()
            local a2 = obj:GetAngle()
            if x1 ~= x2 or y1 ~= y2 or z1 ~= z2 or a1 ~= a2 then
                aligned = aligned + 1
            end
        end)
        ResumePassEdits("AlignedObjWarning")
        if aligned > 0 then
            print(aligned, "object were re-aligned - Save the map!")
        end
    end
end
