---
--- Serializes the provided arguments and returns the serialized string.
---
--- @param ... any The arguments to serialize.
--- @return string The serialized string.
function Serialize(...)
end

---
--- Serializes the provided arguments, compresses the serialized string, and returns the compressed string.
---
--- @param ... any The arguments to serialize and compress.
--- @return string The compressed serialized string.
function SerializeAndCompress(...)
end

---
--- Deserializes the provided serialized string and returns the deserialized value.
---
--- @param str string The serialized string to deserialize.
--- @return any The deserialized value.
function Unserialize(str)
end

---
--- Serializes the provided string table and arguments into a serialized string.
---
--- @param string_table table A table of strings to serialize.
--- @param ... any The arguments to serialize.
--- @return string The serialized string.
function SerializeStr(string_table, ...)
end

---
--- Deserializes the provided serialized string table and returns the deserialized value.
---
--- @param string_table table A table of strings to deserialize.
--- @param str string The serialized string to deserialize.
--- @return any The deserialized value.
function UnserializeStr(string_table, str)
end

---
--- Compresses the provided string and returns the compressed string.
---
--- @param str string The string to compress.
--- @return string The compressed string.
function Compress(str)
end

---
--- Decompresses the provided string and returns the decompressed string.
---
--- @param str string The string to decompress.
--- @return string The decompressed string.
function Decompress(str)
end

---
--- Decompresses the provided string and deserializes the decompressed data.
---
--- @param str string The compressed and serialized string to decompress and deserialize.
--- @return any The deserialized value.
function DecompressAndUnserialize(str)
end

---
--- Escapes a string for binary serialization.
---
--- @param str string The string to escape.
--- @param escape boolean Whether to perform escaping.
--- @param compression boolean Whether to perform compression.
--- @param inplace boolean Whether to perform the operation in-place.
--- @return string The escaped string.
function BinaryEscape(str, escape, compression, inplace)
end
