-- user_text_type: currently used for Steam only, see https://partner.steamgames.com/doc/api/steam_api#ETextFilteringContext
--		values are "unknown", "game_content", "chat", "name", defaulting to "unknown"
---
--- Creates a new user text object.
---
--- @param text string The text of the user text.
--- @param user_text_type string The type of the user text, used for Steam filtering. Can be "unknown", "game_content", "chat", or "name".
--- @return table The new user text object.
function CreateUserText(text, user_text_type)
    return setmetatable({text, _language=GetLanguage(),
        _steam_id=(Platform.steam and IsSteamAvailable()) and SteamGetUserId64() or nil, _user_text_type=user_text_type},
        TMeta)
end

-- input is a list of UserText
-- has two outputs: 
-- 	an "error table" (or false)
--		numeric table (indexed by sequential integers), each entry is itself a table with keys "user_text" and "error"
-- 	a table mapping each input userText to a filteredUserText; 
-- 		the second output is a table because Steam's API works on a text by text basis, so it can fail on specific text instead of the full list/batch (these failures are not included in the returned list), so we need to associate each user text with its filtered result
-- 		if a UserText from the input does not appear in the output table, there was an error and a fallback must be used before the text is displayed (applied outside the function)
-- This is fallback implementation, to be overriden for each platform
---
--- A default implementation of the internal user text filtering function.
---
--- @param unfilteredTs table A table of unfiltered user texts.
--- @return boolean, table A boolean indicating if there were any errors, and a table mapping each unfiltered text to its filtered version.
---
function _DefaultInternalFilterUserTexts(unfilteredTs)
    local filteredTs = {}
    for _, T in ipairs(unfilteredTs) do
        filteredTs[T] = TDevModeGetEnglishText(T, "deep", "no_assert")
    end
    return false, filteredTs
end

_InternalFilterUserTexts = _DefaultInternalFilterUserTexts

-- table indexed by table.hash(T)
-- each value is itself a table with "filtered" as the result of platform specific filtering and "custom" as the custom filter/fallback value
if FirstLoad then
	FilteredTextsTable = {}
end

-- user texts are filtered using table.hash so that they are filtered by value instead of by reference
---
--- Asynchronously filters a list of user texts, caching the filtered results.
---
--- This function preprocesses the input list to remove duplicate entries and entries that have already been filtered. It then calls the internal user text filtering function to filter the remaining unfiltered texts. The filtered results are cached in the `FilteredTextsTable` for future use.
---
--- If any of the filtered texts are not valid UTF-8 strings, the function will use the unfiltered text as a fallback and cache that instead.
---
--- @param user_texts table A table of user texts to be filtered.
--- @return boolean Indicates whether there were any errors during the filtering process.
---
function AsyncFilterUserTexts(user_texts)
    -- preprocess to remove entries duplicate hash values or entries that were already translated
    local set = {}
    local unfiltered_list = {}
    for _, T in ipairs(user_texts) do
        local hash = table.hash(T)
        if not (FilteredTextsTable[hash] and FilteredTextsTable[hash].filtered) and not set[hash] and T ~= "" then
            set[hash] = true
            table.insert(unfiltered_list, T)
        end
    end

    if not unfiltered_list then
        return false
    end -- every text had a cached filter already

    local errors, filtered_list = _InternalFilterUserTexts(unfiltered_list)

    for T, filteredT in pairs(filtered_list) do
        if not utf8.IsValidString(filteredT) then
            local rawText = TDevModeGetEnglishText(T, "deep", "no_assert")
            print(string.format(
                "Filtered text is not a valid UTF-8 string! Using unfiltered text as fallback instead.\nUser Text: <%s>\nFilteredText: <%s>\nUnfilteredText: <%s>",
                UserTextToLuaCode(T), filteredT, rawText))
            SetCustomFilteredUserText(T, rawText)
        else
            local hash = table.hash(T)
            FilteredTextsTable[hash] = FilteredTextsTable[hash] or {}
            FilteredTextsTable[hash].filtered = filteredT
        end
    end

    return errors
end

---
--- Sets the custom filtered text for a given user text.
---
--- If a custom filter text is provided, it will be used as the filtered text for the given user text. Otherwise, the function will fall back to using the English text from `TDevModeGetEnglishText`.
---
--- @param T string The user text to set the custom filtered text for.
--- @param custom_filter_text string|nil The custom filtered text to use, or `nil` to use the fallback English text.
---
function SetCustomFilteredUserText(T, custom_filter_text)
    assert(IsUserText(T))
    local hash = table.hash(T)
    FilteredTextsTable[hash] = FilteredTextsTable[hash] or {}
    FilteredTextsTable[hash].custom = custom_filter_text or TDevModeGetEnglishText(T, not "deep", "no_assert")
end

---
--- Sets the custom filtered text for a list of user texts.
---
--- If a custom filter text is provided for a user text, it will be used as the filtered text for that user text. Otherwise, the function will fall back to using the English text from `TDevModeGetEnglishText`.
---
--- @param Ts table<string> The list of user texts to set the custom filtered text for.
--- @param custom_filter_texts table<string|nil> The list of custom filtered texts to use, or `nil` to use the fallback English text.
---
function SetCustomFilteredUserTexts(Ts, custom_filter_texts)
    assert(not custom_filter_texts or #Ts == #custom_filter_texts)
    for i, v in ipairs(Ts) do
        SetCustomFilteredUserText(v, custom_filter_texts and custom_filter_texts[i])
    end
end

---
--- Gets the filtered text for a given user text.
---
--- If a custom filtered text has been set for the user text, it will be returned. Otherwise, the function will return the filtered text that was previously generated.
---
--- @param T string The user text to get the filtered text for.
--- @return string The filtered text for the given user text.
---
function GetFilteredText(T)
    assert(IsUserText(T), "Trying to get filtered text of a T that is not a UserText.")
    local cache_entry = FilteredTextsTable[table.hash(T)]
    return cache_entry and (cache_entry.filtered or cache_entry.custom)
end
