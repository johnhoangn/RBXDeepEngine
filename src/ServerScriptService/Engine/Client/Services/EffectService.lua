-- Effect Service client
-- Dynamese(Enduo)
-- May 22, 2021

--[[
	
	EffectService:Make(baseID, effectUID, ...), returns uid
	EffectService:ChangeEffect(effectUID, ...)
	EffectService:StopEffect(effectUID, ...)
	
]]



local EffectService = {}
local Network, AssetService, HttpService


local ActiveEffects
local EffectCaches



-- Creates a new effect via server notice
-- @param dt to reach client
-- @param pre_dt to reach server (from original client, if applicable, DEFAULT == 0)
-- @param baseID
-- @param effectUID
-- @param ... effect args
local function HandleServerCreate(dt, pre_dt, baseID, effectUID, ...)
	-- Add the total network delay and provide as standard first argument to the effect
	EffectService:Make(baseID, effectUID, pre_dt + dt, ...)
end


-- Changes an effect via server notice
-- @param dt to reach client
-- @param pre_dt to reach server (from original client, if applicable, DEFAULT == 0)
-- @param effectUID
-- @param ... change args
local function HandleServerChange(dt, pre_dt, effectUID, ...)
	EffectService:ChangeEffect(effectUID, pre_dt + dt, ...)
end


-- Remove an effect via server notice
-- @param dt to reach client
-- @param pre_dt to reach server (from original client, if applicable, DEFAULT == 0)
-- @param effectUID
-- @param ... remove args
local function HandleServerRemove(dt, pre_dt, effectUID, ...)
	EffectService:StopEffect(effectUID, pre_dt + dt, ...)
end


-- Creates a new effect
-- @param baseID
-- @param effectUID, auto generated default
-- @param ... effect args
-- @return uid of effect
function EffectService:Make(baseID, effectUID, ...)
	local uid = effectUID or HttpService:GenerateGUID()
	local cache = EffectCaches:Get(baseID)
	local effect
	
	if (cache ~= nil and cache.Size > 0) then
		effect = cache:Dequeue()
		
	else
		effect = self.Instancer:Make(
			"Effect", 
			AssetService:GetAsset(baseID)
		)
		
		effect.OnStop:Connect(function()
			-- Remove from active list
			ActiveEffects:Remove(effectUID)
			
			-- Prepare for re-use
			effect:Reset()			
						
			-- Create a effect-type queue if needed
			if (cache == nil) then
				EffectCaches:Add(baseID, self.Instancer:Make("Queue"))
			end
			
			-- Insert this effect into the appropriate queue
			EffectCaches:Get(baseID):Enqueue(effect)
		end)
	end
	
	-- Log this effect 
	ActiveEffects:Add(uid, effect)
	
	self.Modules.ThreadUtil.Spawn(effect.Play, effect, ...)
	
	return uid
end


-- Changes an effect
-- @param effectUID
-- @param ... change args
function EffectService:ChangeEffect(effectUID, ...)
	local effect = ActiveEffects:Get(effectUID)

	if (effect ~= nil) then
		effect:Change(...)
	end
end


-- Stops an effect
-- @param effectUID
-- @param ... stop args
function EffectService:StopEffect(effectUID, ...)
	local effect = ActiveEffects:Get(effectUID)
	
	if (effect ~= nil) then
		effect:Stop(...)
	end
end


function EffectService:EngineInit()
	Network = self.Services.Network
	AssetService = self.Services.AssetService
	HttpService = self.RBXServices.HttpService
	
	ActiveEffects = self.Instancer:Make("IndexedMap")
	EffectCaches = self.Instancer:Make("IndexedMap")
end


function EffectService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.Effect, HandleServerCreate)
	Network:HandleRequestType(Network.NetRequestType.EffectChange, HandleServerChange)
	Network:HandleRequestType(Network.NetRequestType.EffectStop, HandleServerRemove)
end


return EffectService