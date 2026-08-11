function Banjoball:FilterExecuteOrder( filterTable )
	local units = filterTable["units"]
	local order = filterTable["order_type"]
	local playerId = filterTable["issuer_player_id_const"]
	

	if order == DOTA_UNIT_ORDER_CAST_POSITION then
		local abilityIndex = filterTable["entindex_ability"]
		if abilityIndex and abilityIndex > 0 then
			local ability = EntIndexToHScript(abilityIndex)
			if ability and not ability:IsNull() then
				local abilityName = ability:GetAbilityName()
				if abilityName == "microblink" or abilityName == "powerdash" or abilityName == "swap" or abilityName == "skewer" then
					if units then
						for _, unitIndex in pairs(units) do
							local unit = EntIndexToHScript(unitIndex)
							if unit and not unit:IsNull() then
								local origin = unit:GetAbsOrigin()
								local target_pos = Vector(filterTable["position_x"], filterTable["position_y"], filterTable["position_z"])
								local dir = target_pos - origin
								local dist = dir:Length2D()
								local max_dist = ability:GetCastRange(origin, nil)
								if max_dist <= 0 or max_dist > 5000 then
									max_dist = 300
								end
								
								if dist > max_dist then
									dir = dir:Normalized()
									local new_pos = origin + dir * max_dist
									filterTable["position_x"] = new_pos.x
									filterTable["position_y"] = new_pos.y
									filterTable["position_z"] = new_pos.z
								end
							end
						end
					end
				end
			end
		end
	end

	if units then
		for _, unitIndex in pairs(units) do
			local unit = EntIndexToHScript(unitIndex)
			-- Check if actually a hero
			if unit and not unit:IsNull() and unit.isBanjoHero then
				if order == DOTA_UNIT_ORDER_MOVE_TO_POSITION then
					unit.last_move_position = Vector(filterTable["position_x"], filterTable["position_y"], filterTable["position_z"])
				end
				if unit.isFakingInjury then
					self:endFakeInjury(unit)
				end
				if unit.isChargingCross then
					if order == DOTA_UNIT_ORDER_HOLD_POSITION or order == DOTA_UNIT_ORDER_STOP then
						if not unit.isChargingCross then return end
						unit.isChargingCross = false
						unit.finishedCrossing = false
					elseif order == DOTA_UNIT_ORDER_CAST_TARGET or order == DOTA_UNIT_ORDER_CAST_POSITION or order == DOTA_UNIT_ORDER_CAST_NO_TARGET or order == DOTA_UNIT_ORDER_MOVE_TO_POSITION then
					else
						return false
					end
				end
				if unit.isPowershot then
					-- Disable anything that isn't casting powerdash or a halt command while charging
					if unit.isChargingPowershot then
						if order == DOTA_UNIT_ORDER_HOLD_POSITION or order == DOTA_UNIT_ORDER_STOP then
							self:powershotCancel(unit)
							unit:FindAbilityByName("powershot"):StartCooldown(POWERSHOT_COOLDOWN)
						elseif order == DOTA_UNIT_ORDER_CAST_TARGET or order == DOTA_UNIT_ORDER_CAST_POSITION then
							-- Do nothing
						else
							return false
						end
					end
				elseif unit.isOgre then
					if unit.isSmashing then -- SMASHING (Stun him)
						return false
					end
				end

				if unit.isUsingOnslaught then
					if order == DOTA_UNIT_ORDER_MOVE_TO_POSITION or order == DOTA_UNIT_ORDER_MOVE_TO_TARGET then
						-- Запоминаем точку клика движения для плавного поворота
						local target_pos = Vector(filterTable["position_x"], filterTable["position_y"], filterTable["position_z"])
						if target_pos then
							unit.onslaught_target_point = target_pos
						end
						return false -- Блокируем стандартную отмену Channeling / C++ движение
					elseif order == DOTA_UNIT_ORDER_STOP or order == DOTA_UNIT_ORDER_HOLD_POSITION then
						if unit.isOnslaughtRunning then
							unit.onslaught_stop_run = true
							return false
						end
					end
				end
			end
		end
	end
	
	return true
end

--[[
#	Order List:
0	DOTA_UNIT_ORDER_NONE
1	DOTA_UNIT_ORDER_MOVE_TO_POSITION
2	DOTA_UNIT_ORDER_MOVE_TO_TARGET
3	DOTA_UNIT_ORDER_ATTACK_MOVE
4	DOTA_UNIT_ORDER_ATTACK_TARGET
5	DOTA_UNIT_ORDER_CAST_POSITION
6	DOTA_UNIT_ORDER_CAST_TARGET
7	DOTA_UNIT_ORDER_CAST_TARGET_TREE
8	DOTA_UNIT_ORDER_CAST_NO_TARGET
9	DOTA_UNIT_ORDER_CAST_TOGGLE
10	DOTA_UNIT_ORDER_HOLD_POSITION
11	DOTA_UNIT_ORDER_TRAIN_ABILITY
12	DOTA_UNIT_ORDER_DROP_ITEM
13	DOTA_UNIT_ORDER_GIVE_ITEM
14	DOTA_UNIT_ORDER_PICKUP_ITEM
15	DOTA_UNIT_ORDER_PICKUP_RUNE
16	DOTA_UNIT_ORDER_PURCHASE_ITEM
17	DOTA_UNIT_ORDER_SELL_ITEM
18	DOTA_UNIT_ORDER_DISASSEMBLE_ITEM
19	DOTA_UNIT_ORDER_MOVE_ITEM
20	DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO
21	DOTA_UNIT_ORDER_STOP
22	DOTA_UNIT_ORDER_TAUNT
23	DOTA_UNIT_ORDER_BUYBACK
24	DOTA_UNIT_ORDER_GLYPH
25	DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH
26	DOTA_UNIT_ORDER_CAST_RUNE
]]--
