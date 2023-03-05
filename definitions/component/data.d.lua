---@meta
---@class ComponentData : Component
local data = {}

--#region Tier 1 Callbacks

---Computes CRC-32 hash of the data. Result is in binary format.
---@param data string
---@return string
function data.crc32(data)
end

---Applies base64 decoding to the data.
---@param data string
---@return string
function data.decode64(data)
end

---Applies base64 encoding to the data. Result is in binary format.
---@param data string
---@return string
function data.encode64(data)
end

---Computes MD5 hash of the data. Result is in binary format
---@param data string
---@return string
function data.md5(data)
end

---Computes SHA2-256 hash of the data. Result is in binary format.
---@param data string
---@return string
function data.sha256(data)
end

---Applies deflate compression to the data.
---@param data string
---@return string
function data.deflate(data)
end

---Applies inflate decompression to the data.
---@param data string
---@return string
function data.inflate(data)
end

---The maximum size of data that can be passed to other functions of the card.
---@return number
function data.getLimit()
end

--endregion

--#region Tier 2 Callbacks

---Applies AES encryption to the data using the key and (preferably) random IV.
---@param data string
---@param key string
---@param iv string
---@return string
function data.encrypt(data, key, iv)
end

---Reverses AES encryption on the data using the key and the IV.
---@param data string
---@param key string
---@param iv string
---@return string
function data.decrypt(data, key, iv)
end

---Generates a random binary string of len length.
---@param len number
---@return string
function data.random(len)
end

--#endregion

--#region Tier 3 Callbacks

---@class EcKey
local ecKey = {}

---is the key public
---@return boolean
function ecKey.isPublic()
end

---serialize the key to save it
---@return string
function ecKey.serialize()
end

---@class EcKeyPublic : EcKey

---@class EcKeyPrivate :EcKey

---Generates a public/private key pair for various cryptiographic functions.\
---Optional second parameter specifies key length, 256 or 384 bits accepted.\
---Key types include “ec-public” and “ec-private”. Keys can be serialized with\
---key.serialize():string Keys also contain the function key.isPublic():boolean
---@param bitLen? 256 | 384
---@return EcKeyPublic publicKey, EcKeyPrivate privateKey
function data.generateKeyPair(bitLen)
end

---Generates a signiture of data using a private key. If signature is present\
---verifies the signature using the public key, the previously generated\
---signature string and the original string.
---@param data string
---@param key EcKey
---@param sig? string
---@return string|boolean
function data.ecdsa(data, key, sig)
end

--- Generates a Diffie-Hellman shared key using the first user's private key and\
--- the second user's public key. An example of a basic key relation:\
--- ecdh(userA.private, userB.public) == ecdh(userB.private, userA.public)
---@param privateKey EcKeyPrivate
---@param publicKey EcKeyPublic
---@return string
function data.ecdh(privateKey, publicKey)
end

---Transforms a key from string to it's arbitrary type.
---@param data string
---@param type "ec-public" | "ec-private"
---@return table
function data.deserializeKey(data, type)
end

--#endregion
