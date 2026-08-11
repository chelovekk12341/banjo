primal_beast_passive = class({})

LinkLuaModifier("modifier_primal_beast_passive", "abilities/primal_beast_passive", LUA_MODIFIER_MOTION_NONE)

function primal_beast_passive:OnUpgrade()
	if not self:GetToggleState() then
		self:ToggleAbility()
	end
end

function primal_beast_passive:OnToggle()
	local caster = self:GetCaster()
	if self:GetToggleState() then
		-- Сначала снимаем старый модификатор (мог остаться с прошлого раунда, т.к. RemoveOnDeath=false),
		-- иначе AddNewModifier не вызовет OnCreated/StartIntervalThink у уже существующего модификатора
		caster:RemoveModifierByName("modifier_primal_beast_passive")
		caster:AddNewModifier(caster, self, "modifier_primal_beast_passive", {})
	else
		caster:RemoveModifierByName("modifier_primal_beast_passive")
	end
end

modifier_primal_beast_passive = class({})

function modifier_primal_beast_passive:IsHidden() return false end
function modifier_primal_beast_passive:IsDebuff() return false end
function modifier_primal_beast_passive:IsPurgable() return false end
function modifier_primal_beast_passive:RemoveOnDeath() return false end

function modifier_primal_beast_passive:GetTexture()
	return "primal_beast_uproar"
end

function modifier_primal_beast_passive:CheckState()
	return {
		[MODIFIER_STATE_UNSLOWABLE] = true,
	}
end

function modifier_primal_beast_passive:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
	}
end

function modifier_primal_beast_passive:GetModifierIgnoreMovespeedLimit()
	return 1
end

function modifier_primal_beast_passive:GetModifierMoveSpeedLimit()
	return 550
end

function modifier_primal_beast_passive:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(0.03)
end

function modifier_primal_beast_passive:OnIntervalThink()
	if not IsServer() then return end
	local parent = self:GetParent()
	if not parent or parent:IsNull() then return end

	-- Если герой не использует Onslaught, форсируем высокое трение для остановки скольжения
	if not parent.isUsingOnslaught then
		parent.dontChangeFriction = true
		if parent.SetPhysicsFriction then
			parent:SetPhysicsFriction(1.0)
		end
		
		-- Если горизонтальная скорость движения мала, сбрасываем её в 0
		local vel = parent:GetPhysicsVelocity()
		if vel and vel:Length2D() < 150 then
			parent:SetPhysicsVelocity(Vector(0, 0, vel.z))
		end
	end
end

function modifier_primal_beast_passive:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if parent and not parent:IsNull() then
		parent.dontChangeFriction = false
		if parent.SetPhysicsFriction then
			parent:SetPhysicsFriction(0.045)
		end
	end
end
