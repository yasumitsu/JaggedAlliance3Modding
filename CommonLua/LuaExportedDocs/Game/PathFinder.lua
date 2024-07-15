--- Path Finder related functions.

---
--- Gets the path between two positions.
---
--- @param src table The starting position.
--- @param dst table The destination position.
--- @param pfclass string The path finding class to use.
--- @param range number The maximum range of the path.
--- @param min_range number The minimum range of the path.
--- @param path_owner table The object that owns the path.
--- @param restrict_radius number The radius to restrict the path to.
--- @param restrict_center table The center point to restrict the path to.
--- @param path_flags number Flags to control the path finding behavior.
--- @return table The path between the two positions.
function pf.GetPosPath(src, dst, pfclass, range, min_range, path_owner, restrict_radius, restrict_center, path_flags)
end

---
--- Checks if there is a valid path between two positions.
---
--- @param src table The starting position.
--- @param dst table The destination position.
--- @param pfclass string The path finding class to use.
--- @param range number The maximum range of the path.
--- @param min_range number The minimum range of the path.
--- @param path_owner table The object that owns the path.
--- @param restrict_radius number The radius to restrict the path to.
--- @param restrict_center table The center point to restrict the path to.
--- @param path_flags number Flags to control the path finding behavior.
--- @return boolean True if a valid path exists, false otherwise.
function pf.HasPosPath(src, dst, pfclass, range, min_range, path_owner, restrict_radius, restrict_center, path_flags)
end

---
--- Gets the length of the path between two positions.
---
--- @param src table The starting position.
--- @param dst table The destination position.
--- @param pfclass string The path finding class to use.
--- @param range number The maximum range of the path.
--- @param min_range number The minimum range of the path.
--- @param path_owner table The object that owns the path.
--- @param restrict_radius number The radius to restrict the path to.
--- @param restrict_center table The center point to restrict the path to.
--- @param path_flags number Flags to control the path finding behavior.
--- @return number The length of the path between the two positions.
function pf.PosPathLen(src, dst, pfclass, range, min_range, path_owner, restrict_radius, restrict_center, path_flags)
end

---
--- Gets the linear distance between two positions.
---
--- @param src table The starting position.
--- @param dst table The destination position.
--- @return number The linear distance between the two positions.
function pf.GetLinearDist(src, dst)
end

---
--- Gets the length of the path between two positions.
---
--- @param obj table The object that owns the path.
--- @param end_idx number The index of the end position in the path.
--- @param max_length number The maximum length of the path.
--- @param skip_tunnels boolean Whether to skip tunnels when calculating the path length.
--- @return number The length of the path between the two positions.
function pf.GetPathLen(obj, end_idx, max_length, skip_tunnels)
end
