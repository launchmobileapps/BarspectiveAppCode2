﻿

socket = require "socket"

client = {}
client.__index = client
client.version = "0.01.5"

if LUBE_VERSION then
	if LUBE_VERSION ~= client.version then
		error("LUBE VERSIONS DO NOT MATCH")
		return nil
	end
else LUBE_VERSION = client.version
end
	
client.udp = {}
client.udp.protocol = "udp"
client.tcp = {}
client.tcp.protocol = "tcp"
client.ping = {}
client.ping.enabled = false
client.ping.time = 0
client.ping.msg = "ping"
client.ping.queue = {}
client.ping.dt = 0

function client:Init(socktype)
	self.host = ""
	self.port = 0
	self.connected = false
	if socktype then
		if self[socktype] then
			self.socktype = socktype
		elseif love.filesystem.exists(socktype .. ".sock") then
			love.filesystem.require(socktype .. ".sock")
			self[socktype] = _G[socktype]
			self.socktype = socktype
		else
			self.socktype = "udp"
		end
	else
		self.socktype = "udp"
	end
	for i, v in pairs(self[self.socktype]) do
		self[i] = v
	end
	self.socket = socket[self.protocol]()
	self.socket:settimeout(0)
	self.callback = function(data) end
	self.handshake = ""
end

function client:setPing(enabled, time, msg)
	self.ping.enabled = enabled
	if enabled then self.ping.time = time; self.ping.msg = msg; self.ping.dt = time end
end

function client:setCallback(cb)
	if cb then
		self.callback = cb
		return true
	else
		self.callback = function(data) end
		return false
	end
end

function client:setHandshake(hshake)
	self.handshake = hshake
end

function client.udp:connect(host, port, dns)
	if dns then
		host = socket.dns.toip(host)
		if not host then
			return false, "Failed to do DNS lookup"
		end
	end
	self.host = host
	self.port = port
	self.connected = true
	if self.handshake ~= "" then self:send(self.handshake) end
end

function client.udp:disconnect()
	if self.handshake ~= "" then self:send(self.handshake) end
	self.host = ""
	self.port = 0
	self.connected = false
end

function client.udp:send(data)
	if not self.connected then return end
	return self.socket:sendto(data, self.host, self.port)
end

function client.udp:receive()
	if not self.connected then return false, "Not connected" end
	local data, err = self.socket:receive()
	if err then
		return false, err
	end
	return true, data
end

function client.tcp:connect(host, port, dns)
	if dns then
		host = socket.dns.toip(host)
		if not host then
			return false, "Failed to do DNS lookup"
		end
	end
	self.host = host
	self.port = port
	self.socket:connect(self.host, self.port)
	self.connected = true
	if self.handshake ~= "" then self:send(self.handshake) end
end

function client.tcp:disconnect()
	if self.handshake ~= "" then self:send(self.handshake) end
	self.host = ""
	self.port = 0
	self.socket:shutdown()
	self.connected = false
end

function client.tcp:send(data)
	if not self.connected then return end
	if data:sub(-1) ~= "\n" then data = data .. "\n" end
	return self.socket:send(data)
end

function client.tcp:receive()
	if not self.connected then return false, "Not connected" end
	local data, err = self.socket:receive()
	if err then
		return false, err
	end
	return true, data
end

function client:doPing(dt)
	if not self.ping.enabled then return end
	self.ping.dt = self.ping.dt + dt
	if self.ping.dt >= self.ping.time then
		self:send(self.ping.msg)
		self.ping.dt = 0
	end
end

function client:update()
	if not self.connected then return end
	local success, data = self:receive()
	if success then
		self.callback(data)
	end
end
