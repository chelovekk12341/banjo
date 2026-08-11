LinkLuaModifier("modifier_tempest_double", "abilities/tempest_double", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tempest_double_tracker", "abilities/tempest_double", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_newsprint", "modifiers/newsprint.lua", LUA_MODIFIER_MOTION_NONE)


tempest_double = class({})










function tempest_double:Precache(context)


end



-- function tempest_double:GetCastPoint()
	-- return 100
-- end




-- function tempest_double:GetCooldown(level)


	-- return 25
-- end



function tempest_double:GetIntrinsicModifierName()
if self:GetCaster():HasModifier("modifier_arc_warden_tempest_double") then return end
return "modifier_tempest_double_tracker"
end

function tempest_double:OnAbilityPhaseStart()
	return not self:GetCaster():IsTempestDouble()
end


function tempest_double:OnSpellStart()
if not IsServer() then return end
local caster = self:GetCaster()
local ability = self

local point = self:GetCursorPosition()

if not caster or caster:IsNull() then return end

if caster:IsTempestDouble() then return end

local tempest = ability:GetHerotempest()

if not tempest or tempest:IsNull() then return end

tempest:RespawnHero(false, false)

-- self:ModifyTempest(tempest)

tempest:SetHealth(caster:GetMaxHealth())
tempest:SetMana(caster:GetMaxMana())
tempest:SetBaseAgility(caster:GetBaseAgility())
tempest:SetBaseStrength(caster:GetBaseStrength())
tempest:SetBaseIntellect(caster:GetBaseIntellect())
tempest:Purge(true, true, false, true, true)
tempest:SetAbilityPoints(0)
tempest:SetHasInventory(false)
tempest:SetCanSellItems(false)
tempest.owner = caster
tempest:RemoveModifierByName("modifier_fountain_invulnerability")
tempest:AddNewModifier(caster, self, "modifier_arc_warden_tempest_double", {})

-- Инициализируем физику, коллизии и способности копии
Banjoball:InitTempestDouble(tempest, caster)
Timers:CreateTimer(FrameTime(), function()
    tempest:RemoveModifierByName("modifier_fountain_invulnerability")
end)
local duration = 15--ability:GetSpecialValueFor("duration")
tempest.noball = false
tempest.tempremoved = false
caster.tempest_double_tempest = tempest

tempest:RemoveGesture(ACT_DOTA_DIE)


FindClearSpaceForUnit(tempest, point, true)



tempest:AddNewModifier(caster, self, "modifier_kill", {duration = duration})
tempest:AddNewModifier(caster, self, "modifier_tempest_double", {duration = duration})
if not tempest:HasModifier("modifier_newsprint")  then
	tempest:AddNewModifier(tempest,tempest,"modifier_newsprint", {duration=99999})
end

local particle = ParticleManager:CreateParticle( "particles/units/heroes/hero_arc_warden/arc_warden_tempest_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster )
ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
ParticleManager:ReleaseParticleIndex(particle)


local particle2 = ParticleManager:CreateParticle( "particles/units/heroes/hero_arc_warden/arc_warden_tempest_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, tempest )
ParticleManager:SetParticleControlEnt(particle2, 0, tempest, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", tempest:GetAbsOrigin(), true)
ParticleManager:ReleaseParticleIndex(particle2)

caster:EmitSound("Hero_ArcWarden.TempestDouble")


end










function tempest_double:GetHerotempest()
local caster = self:GetCaster()
if not caster or caster:IsNull() then return end


if not self.tempest then
	if caster.tempest_double_tempest then
		self.tempest = caster.tempest_double_tempest
	else
		local tempest = CreateUnitByName( caster:GetUnitName(), caster:GetAbsOrigin(), true, caster, caster, caster:GetTeamNumber()  )

        tempest:AddNewModifier(caster, self, "modifier_arc_warden_tempest_double", {})
        local particle = ParticleManager:CreateParticle( "particles/units/heroes/hero_arc_warden/arc_warden_tempest_eyes.vpcf", PATTACH_ABSORIGIN, tempest )
        ParticleManager:SetParticleControlEnt(particle, 0, tempest, PATTACH_POINT_FOLLOW, "attach_head", tempest:GetAbsOrigin(), true)
		tempest.owner = caster
        tempest:SetUnitCanRespawn(true)
        tempest:SetRespawnsDisabled(true)
        tempest:RemoveModifierByName("modifier_fountain_invulnerability")
		tempest.IsRealHero = function() return true end
		tempest.IsMainHero = function() return false end
		tempest.IsTempestDouble = function() return true end
		tempest:SetControllableByPlayer(caster:GetPlayerOwnerID(), true)
		tempest:SetRenderColor(0, 0, 190)
		self.tempest = tempest
	end
end



return self.tempest
end






modifier_tempest_double = class({})
function modifier_tempest_double:IsHidden() return true end
function modifier_tempest_double:IsPurgable() return false end


function modifier_tempest_double:OnCreated()
print('haha i am')
local caster = self:GetCaster()
local ability = self:GetAbility()

self.parent = self:GetParent()
self.ability = self:GetAbility()

if not ability or ability:IsNull() then return end

self.far_distance = 100

if not IsServer() then return end
print('haha i am only server')
self.bounty = ability:GetSpecialValueFor("bounty")
self.parent = self:GetParent()
self.caster = caster
self.ability = ability
self.far_distance = 100



self.str = 0

-- self:GetAbility():EndCooldown()
-- self:GetAbility():SetActivated(false)




end


function modifier_tempest_double:DeclareFunctions()
	return 
    {
        MODIFIER_EVENT_ON_DEATH
	}
end






function modifier_tempest_double:OnDestroy( params )
	print('deadsksss')
if not IsServer() then return end
	local tempest = self.caster.tempest_double_tempest
	if tempest == Ball.unit.controller then
		Ball.unit.controller = nil
	end

	tempest.noball = true
	tempest.tempremoved = true
	
	-- Удаляем копию из vHeroes и colliderFilter
	Banjoball:RemoveTempestDouble(tempest)

	-- tempest:SetAbsOrigin(Vector(0,0,GROUND_Z))
	if tempest.goalie then
		print('taking goalie off')
		tempest.goalie = false
		tempest.gc.goalie = nil
		tempest.ballGoalieProc = false

		tempest:RemoveModifierByName("modifier_goalie")
	end
	-- print('bullydone',self.caster.tempest_double_tempest.tempremoved)
end




