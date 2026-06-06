--[[
	CoinController  (client — ReplicatedStorage.Coins.CoinController)

	Client-only API for reading the balance and requesting spends.

	    local CoinController = require(ReplicatedStorage.Coins.CoinController)
	    CoinController.Get()                        -- current balance (number)
	    CoinController.OnChanged(fn)                 -- balance changed -> (number)
	    CoinController.OnNotify(fn)                  -- earn/spend toast -> (amount, reason, newBalance)
	    CoinController.RequestSpend(amount, itemId)  -- ask server to deduct
]]--

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventHub = require(ReplicatedStorage:WaitForChild("EventHub"))

local player = Players.LocalPlayer
assert(player, "CoinController must be required from the client")

local CoinController = {}

--- Current coin balance (reads the replicated "Coins" attribute).
function CoinController.Get(): number
	local c = player:GetAttribute("Coins")
	return (typeof(c) == "number") and c or 0
end

--- Subscribe to balance changes (driven by the server's attribute push).
function CoinController.OnChanged(callback: (number) -> ()): RBXScriptConnection
	return player:GetAttributeChangedSignal("Coins"):Connect(function()
		callback(CoinController.Get())
	end)
end

--- Subscribe to coin notifications: (amount, reason, newBalance).
--- amount > 0 = earn, amount < 0 = spend.
function CoinController.OnNotify(callback: (number, string, number) -> ()): RBXScriptConnection
	return EventHub.CoinRemote.OnClientEvent:Connect(callback)
end

--- Ask the server to deduct coins (e.g. from a shop UI). Server validates.
function CoinController.RequestSpend(amount: number, itemId: string)
	EventHub.CoinRemote:FireServer("spend", amount, itemId)
end

return CoinController
