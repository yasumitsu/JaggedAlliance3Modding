if Platform.cmdline then return end

MapVar("s_DbgDrawWeaponNoise", false)

---
--- Toggles the display of weapon noise for the currently selected unit(s).
---
--- @param show boolean Whether to show or hide the weapon noise visualization.
--- @param units table|nil A table of units to show/hide the weapon noise for. If nil, the currently selected unit(s) will be used.
---
function DbgShowWeaponNoise(show, units)
	if show then
		local color = const.clrRed
		local prev_meshes = s_DbgDrawWeaponNoise or empty_table
		s_DbgDrawWeaponNoise = {}
		for i, unit in ipairs(units) do
			local weapon = unit:GetActiveWeapons("Firearm")
			local radius = weapon and weapon.Noise * const.SlabSizeX or 0
			local mesh = prev_meshes[unit]
			if mesh then
				prev_meshes[unit] = nil
			end
			if radius > 0 then
				if not mesh then
					mesh = CreateCircleMesh(radius, color, point30)
					mesh:SetHierarchyGameFlags(const.gofLockedOrientation)
					unit:Attach(mesh)
				end
				s_DbgDrawWeaponNoise[unit] = mesh
			elseif mesh then
				DoneObjet(mesh)
			end
		end
		for i, mesh in pairs(prev_meshes) do
			DoneObject(mesh)
		end
	else
		for k, mesh in pairs(s_DbgDrawWeaponNoise) do
			DoneObject(mesh)
		end
		s_DbgDrawWeaponNoise = false
	end
end

---
--- Toggles the display of weapon noise for the currently selected unit(s).
---
--- @param show boolean Whether to show or hide the weapon noise visualization.
--- @param units table|nil A table of units to show/hide the weapon noise for. If nil, the currently selected unit(s) will be used.
---
function DbgToggleWeaponNoise()
	DbgShowWeaponNoise(not s_DbgDrawWeaponNoise, SelectedObj and { SelectedObj })
end

OnMsg.SelectionChange = function() DbgShowWeaponNoise(s_DbgDrawWeaponNoise, SelectedObj and { SelectedObj }) end
