local filename_chars =
{
	['"'] = "'",
	["\\"] = "_",
	["/"] = "_",
	[":"] = "-",
	["*"] = "+",
	["?"] = "_",
	["<"] = "(",
	[">"] = ")",
	["|"] = "-",
}

local escape_symbols =
{
	["%%"] = "%%%%",
	["%("] = "%%(",
	["%)"] = "%%)",
	["%]"] = "%%]",
	["%["] = "%%[",
	["%-"] = "%%-",
	["%+"] = "%%+",
	["%*"] = "%%*",
	["%?"] = "%%?",
	["%$"] = "%%$",
	["%."] = "%%.",
	["%^"] = "%%^",
}

local filter = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ()_+-'"

local filename_strings =
{
    ["A"] = { "À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ā", "Ă", "Ą", "Ǟ", "ǟ", "Ǡ", "ǡ", "Ǣ", "ǣ", "ǻ", "Ǽ", "ǽ", "Ȁ", "ȁ", "Ȃ", "ȃ" },
    ["a"] = { "à", "á", "â", "ã", "ä", "å", "æ", "ā", "ă", "ą", },
    ["C"] = { "Ç" },
    ["c"] = { "ç", },
    ["D"] = { "Ď", "Đ", "Ð", },
    ["d"] = { "ď", "đ", "ð" },
    ["E"] = { "È", "É", "Ê", "Ë", "Ĕ", "Ė", "Ę", "Ě", },
    ["e"] = { "ė", "ę", "ĕ", "ě", "è", "é", "ê", "ë" },
    ["G"] = { "Ĝ", "Ġ", "Ğ", "Ģ", },
    ["g"] = { "ğ", "ĝ", "ġ", "ģ" },
    ["H"] = { "Ĥ", "Ħ", },
    ["h"] = { "ĥ", "ħ" },
    ["I"] = { "Ì", "Í", "Î", "Ï", "Į", "Ĭ", "Ī", "Ĩ", "Ĳ", "İ", },
    ["i"] = { "ı", "ĳ", "ĩ", "ī", "ĭ", "į", "ì", "í", "î", "ï", },
    ["J"] = { "ĵ", "ĵ", "ĵ" },
    ["K"] = { "Ķ", },
    ["k"] = { "ķ", "ĸ" },
    ["L"] = { "Ł", "Ŀ", "Ľ", "Ĺ", "Ļ", },
    ["l"] = { "ļ", "ĺ", "ľ", "ŀ", "ł" },
    ["N"] = { "Ņ", "Ń", "Ň", "Ŋ", "Ñ", },
    ["n"] = { "ñ", "ŋ", "ň", "ń", "ņ", "ŉ", },
    ["O"] = { "Ò", "Ó", "Ô", "Õ", "Õ", "Ö", "Ø", "Ō", "Ŏ", "Ŏ", "Ő", "Œ", },
    ["o"] = { "ò", "ó", "ô", "õ", "ö", "ø", "ō", "ő", "œ" },
    ["R"] = { "Ŕ", "Ŗ", "Ř", },
    ["r"] = { "ř", "ŗ", "ŕ", },
    ["S"] = { "Ś", "Ŝ", "Ş", "Š", },
    ["s"] = { "ß", "ś", "ŝ", "ŝ", "ş", "š" },
    ["T"] = { "Þ", "Ţ", "Ť", "Ŧ", },
    ["t"] = { "þ", "ţ", "ť", "ŧ", },
    ["U"] = { "Ũ", "Ū", "Ŭ", "Ů", "Ų", "Ű", "Ù", "Ú", "Û", "Ü", },
    ["u"] = { "ù", "ú", "û", "ü", "ű", "ų", "ů", "ŭ", "ū", "ũ", },
    ["W"] = { "Ŵ", },
    ["w"] = { "ŵ" },
    ["Y"] = { "Ý", "Ŷ", "Ÿ", },
    ["y"] = { "ý", "ÿ", "ŷ" },
    ["Z"] = { "Ź", "Ż", "Ž", },
    ["z"] = { "ż", "ź", "ž" },
    ["'"] = { "“", "”" },
}

---
--- Canonizes a save game name by performing the following transformations:
---
--- 1. Replaces any non-alphanumeric characters (except for `()_+-'`) with an underscore (`_`).
--- 2. Replaces any accented or non-ASCII characters with their closest ASCII equivalents.
---
--- @param name string The name to be canonized.
--- @return string The canonized name.
function CanonizeSaveGameName(name)
    if not name then
        return
    end

    name = name:gsub("(.)", filename_chars)
    for k, v in pairs(filename_strings) do
        if type(v) == "string" then
            name = name:gsub(v, k)
        elseif type(v) == "table" then
            for i = 1, #v do
                name = name:gsub(v[i], k)
            end
        end
    end
    return name
end

function EscapePatternMatchingMagicSymbols(name)
	for k,v in sorted_pairs(escape_symbols) do
		name = name:gsub(k, v)
	end
	return name
end
