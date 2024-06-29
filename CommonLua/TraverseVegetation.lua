---
--- Defines a TraverseVegetation class that represents an object for traversing vegetation.
---
--- @class TraverseVegetation
--- @field __parents table The parent classes of this class.
DefineClass.TraverseVegetation = {
	__parents = { "CObject" },
}

---
--- Defines a VegetationTraverseEvent object that represents an event where a unit traverses through vegetation.
---
--- @class VegetationTraverseEvent
--- @field life_duration number The duration in milliseconds that the traverse effect should last.
--- @field __parents table The parent classes of this class.
DefineClass.VegetationTraverseEvent= {
	__parents = { "CObject" },
	
	life_duration = 1000,
}

---
--- Sets the actors for a VegetationTraverseEvent.
---
--- @param unit table The unit traversing the vegetation.
--- @param bushes table A list of bushes to play the traverse effect on.
---
function VegetationTraverseEvent:SetActors(unit, bushes)
	CreateGameTimeThread(function(self, unit, bushes)
		local pos = self:GetPos()
		PlayFX("Bush", "traverse", self, unit, pos)
		for _, bush in ipairs(bushes) do
			PlayFX("Bush", "traverse", self, bush, pos)
		end
		Sleep(self.life_duration)
		self.life_thread = false
		DoneObject(self)
	end, self, unit, bushes)
end
