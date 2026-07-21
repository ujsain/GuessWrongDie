--[[
	PurchaseService (server — ServerScriptService.Data.Services.PurchaseService)

	Generic, game-agnostic Robux Developer Product handler. The whole game may
	only have ONE MarketplaceService.ProcessReceipt callback, so this is the
	single router: every paid item registers a grant against its product id, and
	ProcessReceipt dispatches by id.

	Reusable in any project: it doesn't know about your data layer — you inject a
	getProfile(player) -> profile function once. `profile` is expected to be a
	ProfileStore session (uses :IsActive(), :Save(), .LastSavedData, .OnAfterSave
	and a Profile.Data.PurchaseIdCache list for idempotency).

	Usage (in your bootstrap):
	    PurchaseService.SetProfileGetter(DataManager.GetProfile)
	    PurchaseService.RegisterProduct(123456, function(player, profile)
	        profile.Data.OwnedGuns["AceShot"] = true        -- grant
	    end)
	    PurchaseService.Init()                               -- set ProcessReceipt

	Grants run ONLY in ProcessReceipt (never on the prompt-finished event), are
	idempotent per PurchaseId, and the receipt is only confirmed to Roblox once
	the grant is durably saved — so a server crash can't lose or double a grant.
]]--

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local PurchaseService = {}

local PURCHASE_ID_CACHE_SIZE = 100   -- how many recent PurchaseIds we remember
local grantById = {}                  -- [productId] = function(player, profile)
local getProfile                      -- injected: function(player) -> profile?

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------
function PurchaseService.SetProfileGetter(fn)
	assert(type(fn) == "function", "SetProfileGetter expects a function")
	getProfile = fn
end

-- grant(player, profile) runs when a confirmed receipt for productId arrives.
function PurchaseService.RegisterProduct(productId, grant)
	if type(productId) ~= "number" or productId <= 0 then return end   -- skip placeholders
	assert(type(grant) == "function", "RegisterProduct expects a grant function")
	grantById[productId] = grant
end

--------------------------------------------------------------------------------
-- Idempotent, crash-safe grant (ProfileStore PurchaseIdCheck pattern)
--------------------------------------------------------------------------------
local function grantSavedAsync(profile, purchaseId, grant)
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local cache = profile.Data.PurchaseIdCache
	if cache == nil then
		cache = {}
		profile.Data.PurchaseIdCache = cache
	end

	-- run the grant only if this exact purchase hasn't been recorded yet
	if table.find(cache, purchaseId) == nil then
		local ok = pcall(grant)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet   -- grant errored; retry later
		end
		table.insert(cache, purchaseId)
		while #cache > PURCHASE_ID_CACHE_SIZE do
			table.remove(cache, 1)   -- FIFO trim
		end
	end

	-- confirm to Roblox only once this purchase is written to the DataStore
	local function isSaved()
		local saved = profile.LastSavedData and profile.LastSavedData.PurchaseIdCache
		return saved ~= nil and table.find(saved, purchaseId) ~= nil
	end

	if isSaved() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local done = false
	local conn = profile.OnAfterSave:Connect(function()
		if isSaved() then done = true end
	end)
	profile:Save()
	while not done do
		if not profile:IsActive() then
			conn:Disconnect()
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		task.wait()
	end
	conn:Disconnect()
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------------------
-- The single ProcessReceipt callback
--------------------------------------------------------------------------------
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet   -- offline; retry on rejoin
	end

	local grant = grantById[receipt.ProductId]
	if not grant then
		warn("[PurchaseService] no handler registered for product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = getProfile and getProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return grantSavedAsync(profile, receipt.PurchaseId, function()
		grant(player, profile)
	end)
end

function PurchaseService.Init()
	assert(getProfile, "PurchaseService.Init: call SetProfileGetter(...) first")
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
