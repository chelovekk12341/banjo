--[[
	ReplacePlayerHero()
	Replaces the player's hero with the hero type specified.
	player - Player with hero being replaced
	heroName - Hero class to replace hero with
]]--
function Banjoball:ReplacePlayerHero(player, heroName)
	local playerID = player:GetPlayerID()
	local hero = player:GetAssignedHero()
	hero:SetAbsOrigin(Vector(hero.spawn_pos.x, hero.spawn_pos.y, GroundZ))
	hero:StopPhysicsSimulation()
	hero:AddNoDraw()
	PlayerResource:ReplaceHeroWith(playerID, heroName, 0, 0)
	local newHero = player:GetAssignedHero()
	hero:SetAbsOrigin(Vector(10000,10000,1000)) -- Just in case the replace causes issues (hint, it does)
	if hero.goalie then
		hero.goalie = false
		hero.gc.goalie = nil
		hero.ballGoalieProc = false
	end
	hero.isBanjoHero = false;
	for i=1, #Banjoball.vHeroes do
		if Banjoball.vHeroes[i] == hero then
			table.remove(Banjoball.vHeroes, i)
			return nil
		end
	end
	-- Send panorama command to switch control to newHero
end
