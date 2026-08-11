-- Default Spells + Functions
function fake_injury( keys )
	Banjoball:fake_injury(keys)
end

function OnRefereeAttacked( keys )
	Banjoball:OnRefereeAttacked(keys)
end

function surge( keys )
	Banjoball:surge(keys)
end

function surge_break( keys )
	Banjoball:surge_break(keys)
end

function stealth_sprint( keys )
	Banjoball:stealth_sprint(keys)
end

function stealth_sprint_break( keys )
	Banjoball:stealth_sprint_break(keys)
end

function text_particle( keys )
	Banjoball:text_particle(keys)
end

function kick_ball( keys )
	Banjoball:kick_ball(keys)
end

-- Hero Abilities

function backflip( keys )
	Banjoball:backflip(keys)
end

function hook( keys )
	Banjoball:hook(keys)
end

function hook_cancel( keys )
	Banjoball:hook_cancel(keys)
end
function hook_ball( keys )
	Banjoball:hook_ball(keys)
end

function ogre_smash( keys )
	Banjoball:ogre_smash( keys )
end

function powerdash( keys )
	Banjoball:powerdash(keys)
end

function powershot( keys )
	Banjoball:powershot(keys)
end

function pull( keys )
	Banjoball:pull(keys)
end

function pull_break( keys )
	Banjoball:pull_break(keys)
end

function slam( keys )
	Banjoball:slam(keys)
end

function skewer( keys )
	Banjoball:skewer(keys)
end

function shadowraze( keys )
	Banjoball:shadowraze(keys)
end

function truesight( keys )
	Banjoball:truesight(keys)
end

-- Other

function Banjoball:OnAbilityUsed( keys )
	--DeepPrintTable(keys)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local abilityname = keys.abilityname
	local hero = player:GetAssignedHero()
	local ball = Ball.unit
end