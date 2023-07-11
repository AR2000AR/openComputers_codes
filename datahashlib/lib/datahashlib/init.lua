local component = require("component")
local sha256, md5, crc32
if component.isAvailable("data") then
    sha256 = component.data.sha256
    md5 = component.data.md5
    crc32 = component.data.crc32
else
    sha256 = require('datahashlib.sha256')
    md5 = require('datahashlib.md5')
    crc32 = require('datahashlib.crc32')
end



return {
    sha256 = sha256,
    md5 = md5,
    crc32 = crc32
}
