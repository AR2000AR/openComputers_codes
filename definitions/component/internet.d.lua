---@meta

---@class ComponentInternet : Component
local internet = {}

--#region component

---Returns whether TCP connections can be made (config setting).
---@return boolean
function internet.isTcpEnabled()
end

---Returns whether HTTP requests can be made (config setting).
---@return boolean
function internet.isHttpEnabled()
end

---Opens a new TCP connection. Returns the handle of the connection.
---@param address string
---@param port? number
---@return TcpSocket
function internet.connect(address, port)
end

---Sends a new HTTP request. Returns the handle of the connection.
---@param url string
---@param postData? string
---@param headers? table
---@return HttpRequest
function internet.request(url, postData, headers)
end

--#endregion

--#region tcp socket

---@class TcpSocket
local TcpSocket = {}

---Tries to read data from the socket stream. Returns the read byte array.
---@param n? number
---@return string
function TcpSocket.read(n)
end

---Closes an open socket stream.
function TcpSocket.close()
end

---Tries to write data to the socket stream. Returns the number of bytes written.
---@param data string
---@return number
function TcpSocket.write(data)
end

---Ensures a socket is connected. Errors if the connection failed.
---@return boolean
function TcpSocket.finishConnect()
end

---Returns the id for this socket.
---@return string
function TcpSocket.id()
end

--#endregion

--#region http request object

---@class HttpRequest
local HttpRequest = {}

---Tries to read data from the response. Returns the read byte array.
---@param n? number
---@return string
function HttpRequest.read(n)
end

---Get response code, message and headers.
---@return number status, string statusName, table headers
function HttpRequest.response()
end

---Closes an open socket stream.
function HttpRequest.close()
end

---Ensures a response is available. Errors if the connection failed.
---@return boolean
function HttpRequest.finishConnect()
end

--#endregion
