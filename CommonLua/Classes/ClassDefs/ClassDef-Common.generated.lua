-- ========== GENERATED BY ClassDef Editor (Ctrl-Alt-F3) DO NOT EDIT MANUALLY! ==========

--- Defines a class `StoryBitWithWeight` that inherits from `PropertyObject`.
---
--- This class represents a story bit with a weight value that determines its probability of being selected.
---
--- @class StoryBitWithWeight
--- @field StoryBitId string The ID of the story bit.
--- @field NoCooldown boolean Whether to skip cooldowns for subsequent story bit activations.
--- @field ForcePopup boolean Whether to directly display the popup without a notification phase.
--- @field Weight number The weight of the story bit, used to determine its probability of being selected.
--- @field StorybitSets string A comma-separated list of the story bit sets this story bit belongs to.
--- @field OneTime boolean Whether this story bit can only be activated once.
DefineClass.StoryBitWithWeight = {__parents={"PropertyObject"}, __generated_by_class="ClassDef",

    properties={{id="StoryBitId", name="Id", editor="preset_id", default=false, preset_class="StoryBit"},
        {id="NoCooldown", help="Don't activate any cooldowns for subsequent StoryBit activations", editor="bool",
            default=false}, {id="ForcePopup", name="Force Popup",
            help="Specifying true skips the notification phase, and directly displays the popup", editor="bool",
            default=true}, {id="Weight", name="Weight", editor="number", default=100, min=0},
        {id="StorybitSets", name="Storybit sets", editor="text", default="<StorybitSets>", dont_save=true,
            read_only=true}, {id="OneTime", editor="bool", default=false, dont_save=true, read_only=true}},
    EditorView=Untranslated('"Activate StoryBit <StoryBitId> (weight: <Weight>)"')}
--- Returns a comma-separated string of the story bit sets that the current story bit belongs to.
---
--- If the story bit preset does not exist or has no sets defined, this function returns "None".
---
--- @return string A comma-separated list of the story bit sets, or "None" if there are no sets.
function StoryBitWithWeight:GetStorybitSets()
    local preset = StoryBits[self.StoryBitId]
    if not preset or not next(preset.Sets) then
        return "None"
    end
    local items = {}
    for set in sorted_pairs(preset.Sets) do
        items[#items + 1] = set
    end
    return table.concat(items, ", ")
end

function StoryBitWithWeight:GetStorybitSets()
    local preset = StoryBits[self.StoryBitId]
    if not preset or not next(preset.Sets) then
        return "None"
    end
    local items = {}
    for set in sorted_pairs(preset.Sets) do
        items[#items + 1] = set
    end
    return table.concat(items, ", ")
end
--- Returns whether the current story bit can only be activated once.
---
--- @return boolean Whether the story bit can only be activated once.
function StoryBitWithWeight:GetOneTime()
    local preset = StoryBits[self.StoryBitId]
    return preset and preset.OneTime
end
--- Returns an error message if the StoryBit preset for the current StoryBitWithWeight instance is invalid.
---
--- @return string An error message if the StoryBit preset is invalid, or nil if it is valid.
function StoryBitWithWeight:GetError()
    local story_bit = StoryBits[self.StoryBitId]
    if not story_bit then
        return "Invalid StoryBit preset"
    end
end

