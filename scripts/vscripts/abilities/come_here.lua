LinkLuaModifier("modifier_come_here_debuff", "abilities/come_here", LUA_MODIFIER_MOTION_NONE)

come_here = class({})

function come_here:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_static_link.vpcf", context)
end

function come_here:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	if target then
		if target.goalie or target:HasModifier("modifier_goalie") then
			ShowErrorMsg(caster, "#cant_pull_goalkeeper")
			self:EndCooldown()
			return
		end

		-- Play cast sound (Custom Batrider Lasso & Razor Static Link loop)
		caster:EmitSound("Abaddon.ComeHere.Cast")
		target:EmitSound("Hero_Razor.StaticLink.Loop")

		-- Create visual link between caster and target
		local link = ParticleManager:CreateParticle("particles/units/heroes/hero_razor/razor_static_link.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
		ParticleManager:SetParticleControlEnt(link, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(link, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)

		-- Считываем динамические параметры из AbilityValues
		local duration = self:GetSpecialValueFor("duration")
		local speed = self:GetSpecialValueFor("speed")
		local min_distance = self:GetSpecialValueFor("min_distance")

		-- Apply debuff on enemy
		target:AddNewModifier(caster, self, "modifier_come_here_debuff", {duration = duration})

		-- Pull logic on timer
		local elapsed = 0
		local tick = FRAME_TIME

		Timers:CreateTimer(function()
			if elapsed >= duration or not target:IsAlive() or not caster:IsAlive() then
				ParticleManager:DestroyParticle(link, false)
				target:StopSound("Hero_Razor.StaticLink.Loop")
				caster:StopSound("Abaddon.ComeHere.Cast")
				return nil
			end

			local toCaster = (caster:GetAbsOrigin() - target:GetAbsOrigin())
			local currentDist = toCaster:Length()

			if currentDist > min_distance then
				local dir = toCaster:Normalized()
				if not target.SetPhysicsVelocity then
					Banjoball:SetupPhysicsSettings(target)
				end
				target:SetPhysicsVelocity(dir * speed)
			end

			elapsed = elapsed + tick
			return tick
		end)
	end
end

-- Debuff definition
modifier_come_here_debuff = class({})

function modifier_come_here_debuff:IsHidden() return false end
function modifier_come_here_debuff:IsDebuff() return true end
function modifier_come_here_debuff:IsPurgable() return true end
function modifier_come_here_debuff:GetTexture() return "abaddon_aphotic_shield" end
