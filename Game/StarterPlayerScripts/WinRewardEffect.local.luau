--[[
	WinRewardEffect (client)
	Listens to the existing GameOver remote. When THIS player is the winner,
	plays the coin-collect animation streaming from the duel table into the HUD.
	Does NOT modify DuelClient — it adds its own separate connection to GameOver.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local EventHub          = require(ReplicatedStorage:WaitForChild("EventHub"))
local CoinCollectEffect = require(ReplicatedStorage:WaitForChild("Coins"):WaitForChild("CoinCollectEffect"))
local GameOver          = EventHub.GameOver

-- Find the world center of the table for a given TableId.
local function tableCenter(tableId)
	for _, cs in ipairs(game:GetService("CollectionService"):GetTagged("ChairSystem")) do
		if cs:IsA("Folder") and cs:IsDescendantOf(workspace) then
			local tid = cs:FindFirstChild("TableId")
			if tid and tid.Value == tableId then
				local tbl = cs:FindFirstChild("table")
				if tbl and tbl:IsA("Model") then
					local cf = tbl:GetBoundingBox()
					return cf.Position
				end
			end
		end
	end
	return nil
end

GameOver.OnClientEvent:Connect(function(tableId, winnerId, reason)
	-- winnerId is set to this player's UserId on both a real win and "opponent_left"
	if winnerId ~= player.UserId then return end

	local pos = tableCenter(tableId)
	if not pos then return end

	CoinCollectEffect.PlayFromWorldPos(pos)
end)
