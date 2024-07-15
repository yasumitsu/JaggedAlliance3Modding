local user_location = "AppData/en-us.lua"
local default_location = "CommonAssets/__en-us.lua"
local location = default_location

if FirstLoad then
	SpellcheckDict = false
end

---
--- Loads the spellcheck dictionary from a file.
---
--- If the user-specific dictionary file does not exist, it copies the default dictionary file to the user location.
--- The dictionary is then loaded from the user location.
---
--- @function LoadDictionary
--- @return nil
function LoadDictionary()
	if not Platform.developer then
		if not io.exists(user_location) then
			AsyncCopyFile(default_location, user_location)
		end
		location = user_location
	end
	dofile(location)
end

---
--- Writes the contents of the provided dictionary to the spellcheck dictionary file.
---
--- The dictionary is written to the user-specific dictionary file location. If the file does not exist, it will be created.
---
--- @param dict table The dictionary to write to the file.
--- @return nil
function WriteToDictionary(dict)
	local lines = {}
	lines[1] = "SpellcheckDict = {"
	for word, _ in sorted_pairs(dict) do
		lines[#lines + 1] = "\t[\""..word.."\"] = true,"
	end
	lines[#lines + 1] = "}"
	AsyncStringToFile(location, table.concat(lines, "\n"))
end

---
--- Checks if the given word is in the spellcheck dictionary.
---
--- If the spellcheck dictionary has not been loaded yet, this function will return `true`.
--- Otherwise, it will check if the word or its lowercase version is in the dictionary.
--- It will also return `true` if the word is a number or starts with a number.
---
--- @param word string The word to check
--- @param lowercase_word string The lowercase version of the word to check
--- @return boolean `true` if the word is in the dictionary, `false` otherwise
---
function WordInDictionary(word, lowercase_word)
	if not SpellcheckDict then
		return true
	end
	if word ~= nil and word ~= "" and not SpellcheckDict[word] and not SpellcheckDict[lowercase_word] and not tonumber(word) and not tonumber(string.sub(word,2)) then
		return false
	end
	return true
end