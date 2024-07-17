DefineClass.ActionFXVR = {
	__parents = {"ActionFXObject"},
	
	properties = {
		{category = "VR", id = "EventType", default = false, editor = "dropdownlist", items = PresetsCombo("VoiceResponseType") },
		{category = "VR", id = "Force", default = false, editor = "bool"},
	},
	
	fx_type = "VR",
}

--- Plays the voice response for the given actor based on the EventType property of the ActionFXVR object.
---
--- @param actor table The actor object that is playing the voice response.
--- @param target table The target object of the action.
--- @param action_pos vector The position of the action.
--- @param action_dir vector The direction of the action.
function ActionFXVR:PlayFX(actor, target, action_pos, action_dir)
	PlayVoiceResponse(actor, self.EventType)
end
