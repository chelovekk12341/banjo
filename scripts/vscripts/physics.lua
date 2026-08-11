PHYSICS_NAV_NOTHING = 0
PHYSICS_NAV_HALT = 1
PHYSICS_NAV_SLIDE = 2
PHYSICS_NAV_BOUNCE = 3

PHYSICS_GROUND_NOTHING = 0
PHYSICS_GROUND_ABOVE = 1
PHYSICS_GROUND_LOCK = 2

COLLIDER_SPHERE = 0
COLLIDER_BOX = 1
COLLIDER_AABOX = 2

PHYSICS_THINK = 0.01

if Physics == nil then
	print ( '[PHYSICS] creating Physics' )
	Physics = {}
	Physics.__index = Physics
end

function IsPhysicsUnit(unit)
	return unit.GetPhysicsVelocity ~= nil
end

function Physics:new( o )
	o = o or {}
	setmetatable( o, Physics )
	return o
end

ColliderProfiles = {}

function ColliderProfiles:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Physics:start()
	Physics = self

	if self.thinkEnt == nil then
		self.timers = {}
		self.Colliders = {}
		self.ColliderProfiles = {}
		self.anggrid = nil
		self.offsetX = nil
		self.offsetY = nil
		self.colliderSkipOffset = 0
		self.frameCount = 0

		self.thinkEnt = Entities:CreateByClassname("info_target") -- Entities:FindByClassname(nil, 'CWorld')
		--wspawn:SetContextThink("PhysicsThink", Dynamic_Wrap( Physics, 'Think' ), PHYSICS_THINK )
		self.thinkEnt:SetThink("Think", self, "physics", PHYSICS_THINK)

		Convars:RegisterCommand( "phystest", Dynamic_Wrap(Physics, 'PhysicsTestCommand'), "Test different Physics library commands", FCVAR_CHEAT )
	end
end

function Physics:CreateColliderProfile(name, profile)
	self.ColliderProfiles[name] = ColliderProfiles:new(profile)
	profile.name = name
	return self.ColliderProfiles[name]
end

function Physics:ColliderFromProfile(name, collider)
	return self.ColliderProfiles[name]:new(collider)
end

function Physics:AddCollider(name, collider)
	if type(name) == "table" then
		collider = name
		name = DoUniqueString("collider")
	end

	collider.skipOffset = self.colliderSkipOffset
	self.colliderSkipOffset = self.colliderSkipOffset + 1

	collider.name = name
	self.Colliders[name] = collider
	return collider
end

function Physics:RemoveCollider(name)
	if type(name) == "table" then
		name = name.name
	end

	local collider = self.Colliders[name]
	if collider == nil then
		return
	end
	if collider.unit ~= nil and collider.unit.oColliders[collider.name] ~= nil then
		collider.unit.oColliders[collider.name] = nil
	end


	self.Colliders[name] = nil
end

function Physics:Think()
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end

	-- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
	local now = GameRules:GetGameTime()
	--print("now: " .. now)
	if Physics.t0 == nil then
		Physics.t0 = now
	end
	local dt = now - Physics.t0
	Physics.t0 = now

	self.frameCount = self.frameCount + 1

	-- Process timers
	for k,v in pairs(Physics.timers) do
		local bUseGameTime = false
		if v.useGameTime and v.useGameTime == true then
			bUseGameTime = true;
		end
		-- Check if the timer has finished
		if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
			-- Remove from timers list
			Physics.timers[k] = nil

			-- Run the callback
			local status, nextCall = pcall(v.callback, Physics, v)

			-- Make sure it worked
			if status then
				-- Check if it needs to loop
				if nextCall then
					-- Change it's end time
					v.endTime = nextCall
					Physics.timers[k] = v
				end

				-- Update timer data
				--self:UpdateTimerData()
			else
				-- Nope, handle the error
				Physics:HandleEventError('Timer', k, nextCall)
			end
		end
	end

	if dt > 0 then
		for name,collider in pairs(Physics.Colliders) do
			if collider.skipFrames == 0 or ((self.frameCount + collider.skipOffset) % (collider.skipFrames + 1) == 0) then
				if collider.type == COLLIDER_SPHERE then
					local rad2 = collider.radius * collider.radius
					local unit = collider.unit
					if IsValidEntity(unit) then
						if collider.draw then
							local alpha = 0
							local color = Vector(200,0,0)
							if type(collider.draw) == "table" then
								alpha = collider.draw.alpha or alpha
								color = collider.draw.color or color
							end

							DebugDrawCircle(unit:GetAbsOrigin(), color, alpha, collider.radius, true, .01)
						end

						local ents = nil
						if collider.filter then
							if type(collider.filter) == "table" then
								ents = collider.filter
							else
								local status = nil
								status, ents = pcall(collider.filter, collider)
								if not status then
									print('[PHYSICS] Collision Filter Failure!: ' .. ents)
								end
							end
						else
							ents = Entities:FindAllInSphere(unit:GetAbsOrigin(), collider.radius + MAX_COLLISION_RADIUS)
						end

						for k,v in pairs(ents) do
							if IsValidEntity(v) and IsValidEntity(unit) and v ~= unit and (not v.tempremoved and not unit.tempremoved) and rad2 >= VectorDistanceSq(unit:GetAbsOrigin(), v:GetAbsOrigin()) then
								-- if collider.tester then
									-- print('vccc',VectorDistanceSq(unit:GetAbsOrigin(), v:GetAbsOrigin()),rad2, v:GetAbsOrigin(), unit:GetAbsOrigin())
								-- end
								local status, test = pcall(collider.test, collider, unit, v)

								if not status then
									print('[PHYSICS] Collision Test Failure!: ' .. test)
								elseif test then
									if collider.preaction then
										local status, action = pcall(collider.preaction, collider, unit, v)
										if not status then
											print('[PHYSICS] Collision preaction Failure!: ' .. action)
										end
									end
									local status, action = pcall(collider.action, collider, unit, v)
									if not status then
										print('[PHYSICS] Collision action Failure!: ' .. action)
									end
									if collider.postaction then
										local status, action = pcall(collider.postaction, collider, unit, v)
										if not status then
											print('[PHYSICS] Collision postaction Failure!: ' .. action)
										end
									end


									--unit.nNextCollide = now + collider.recollideTime
									--v.nNextCollide = now + v.collider.recollideTime
								end
							end
						end
					else
						Physics:RemoveCollider(name)
					end
				elseif collider.type == COLLIDER_BOX then
					-- box collider
					local box = collider.box
					if box.recalculate or box.ad2 == nil then
						collider.box = Physics:PrecalculateBox(box)
					end

					if collider.draw then
						local alpha = 5
						local color = Vector(200,0,0)
						if type(collider.draw) == "table" then
							alpha = collider.draw.alpha or alpha
							color = collider.draw.color or color
						end

						if not collider.box.drawAngle then
							Physics:PrecalculateBoxDraw(collider.box)
						end

						-- what the hell is that xoffset on the origin, but it works
						DebugDrawBoxDirection(Vector(box.drawAngle * 9,0,0), box.drawMins, box.drawMaxs, RotatePosition(Vector(0,0,0), QAngle(0,box.drawAngle,0), Vector(1,0,0)), color, alpha, .01)
					end

					local ents = nil
					if collider.filter then
						if type(collider.filter) == "table" then
							ents = collider.filter
						else
							local status = nil
							status, ents = pcall(collider.filter, collider)
							if not status then
								print('[PHYSICS] Collision Filter Failure!: ' .. ents)
							end
						end
					else
						ents = Entities:FindAllInSphere(box.center, box.radius + MAX_COLLISION_RADIUS)
					end

					for k,v in pairs(ents) do
						if IsValidEntity(v) then
							local pos = v:GetAbsOrigin()
							if (pos.z >= box.zMin and pos.z <= box.zMax) then
								pos.z = 0
								local am = pos - box.a
								local amDotAb = am:Dot(box.ab)
								if amDotAb > 0 and amDotAb < box.ab2 then
									local amDotAd = am:Dot(box.ad)
									if amDotAd > 0 and amDotAd < box.ad2 then
										--inside
										local status, test = pcall(collider.test, collider, v)

										if not status then
											print('[PHYSICS] Collision Test Failure!: ' .. test)
										elseif test then
											if collider.preaction then
												local status, action = pcall(collider.preaction, collider, box, v)
												if not status then
													print('[PHYSICS] Collision preaction Failure!: ' .. action)
												end
											end
											local status, action = pcall(collider.action, collider, box, v)
											if not status then
												print('[PHYSICS] Collision action Failure!: ' .. action)
											end
											if collider.postaction then
												local status, action = pcall(collider.postaction, collider, box, v)
												if not status then
													print('[PHYSICS] Collision postaction Failure!: ' .. action)
												end
											end
										end
									end
								end
							end
						end
					end
				elseif collider.type == COLLIDER_AABOX then
					-- box collider
					local box = collider.box
					if box.recalculate or box.xMin == nil then
						collider.box = Physics:PrecalculateAABox(box)
					end

					if collider.draw then
						local alpha = 5
						local color = Vector(200,0,0)
						if type(collider.draw) == "table" then
							alpha = collider.draw.alpha or alpha
							color = collider.draw.color or color
						end

						DebugDrawBox(Vector(0,0,0), Vector(box.xMin, box.yMin, box.zMin), Vector(box.xMax, box.yMax, box.zMax), color.x, color.y, color.z, alpha, .01)
					end

					local ents = nil
					if collider.filter then
						if type(collider.filter) == "table" then
							ents = collider.filter
						else
							local status = nil
							status, ents = pcall(collider.filter, collider)
							if not status then
								print('[PHYSICS] Collision Filter Failure!: ' .. ents)
							end
						end
					else
						ents = Entities:FindAllInSphere(box.center, box.radius + MAX_COLLISION_RADIUS)
					end

					for k,v in pairs(ents) do
						if IsValidEntity(v) then
							local pos = v:GetAbsOrigin()
							if (pos.x >= box.xMin and pos.x <= box.xMax and
								pos.y >= box.yMin and pos.y <= box.yMax and
								pos.z >= box.zMin and pos.z <= box.zMax) then

								--inside
								local status, test = pcall(collider.test, collider, v)

								if not status then
									print('[PHYSICS] Collision Test Failure!: ' .. test)
								elseif test then
									if collider.preaction then
										local status, action = pcall(collider.preaction, collider, box, v)
										if not status then
											print('[PHYSICS] Collision preaction Failure!: ' .. action)
										end
									end
									local status, action = pcall(collider.action, collider, box, v)
									if not status then
										print('[PHYSICS] Collision action Failure!: ' .. action)
									end
									if collider.postaction then
										local status, action = pcall(collider.postaction, collider, box, v)
										if not status then
											print('[PHYSICS] Collision postaction Failure!: ' .. action)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return PHYSICS_THINK
end

function Physics:HandleEventError(name, event, err)
	print(err)

	-- Ensure we have data
	name = tostring(name or 'unknown')
	event = tostring(event or 'unknown')
	err = tostring(err or 'unknown')

	-- Tell everyone there was an error
	--Say(nil, name .. ' threw an error on event '..event, false)
	--Say(nil, err, false)

	-- Prevent loop arounds
	if not self.errorHandled then
		-- Store that we handled an error
		self.errorHandled = true
	end
end

function Physics:CreateTimer(name, args)
	if not args.endTime or not args.callback then
		print("Invalid timer created: "..name)
		return
	end

	Physics.timers[name] = args
end

function Physics:RemoveTimer(name)
	Physics.timers[name] = nil
end

function Physics:RemoveTimers(killAll)
	local timers = {}

	if not killAll then
		for k,v in pairs(Physics.timers) do
			if v.persist then
				timers[k] = v
			end
		end
	end

	Physics.timers = timers
end

--[[

  sequence:

     {"type",  Physics_LINEAR, Physics_CURVED, Physics_SPLIT

      LINEAR

      "distance" or "time" or "to"

      "toward" or "angle" or "to"

      "from" or nothing

      "speed" or nothing

      CURVED

      "toward" or "angle"

        "angleTick"

        "tick"

        "ticks"

      "around"

      "speed" or nothing

      SPLIT

      "TBD"

]]

function Physics:GenerateAngleGrid()
	local anggrid = {}
	local worldMin = Vector(GetWorldMinX(), GetWorldMinY(), 0)
	local worldMax = Vector(GetWorldMaxX(), GetWorldMaxY(), 0)

	print(worldMin)
	print(worldMax)

	local boundX1 = GridNav:WorldToGridPosX(worldMin.x)
	local boundX2 = GridNav:WorldToGridPosX(worldMax.x)
	local boundY1 = GridNav:WorldToGridPosX(worldMin.y)
	local boundY2 = GridNav:WorldToGridPosX(worldMax.y)
	local offsetX = boundX1 * -1 + 1
	local offsetY = boundY1 * -1 + 1

	print(boundX1 .. " -- " .. boundX2)
	print(boundY1 .. " -- " .. boundY2)
	print(offsetX)
	print(offsetY)

	local vecs = {
		{vec = Vector(0,1,0):Normalized(), x=0,y=1},-- N
		{vec = Vector(1,1,0):Normalized(), x=1,y=1}, -- NE
		{vec = Vector(1,0,0):Normalized(), x=1,y=0}, -- E
		{vec = Vector(1,-1,0):Normalized(), x=1,y=-1}, -- SE
		{vec = Vector(0,-1,0):Normalized(), x=0,y=-1}, -- S
		{vec = Vector(-1,-1,0):Normalized(), x=-1,y=-1}, -- SW
		{vec = Vector(-1,0,0):Normalized(), x=-1,y=0}, -- W
		{vec = Vector(-1,1,0):Normalized(), x=-1,y=1} -- NW
	}

	print('----------------------')

	anggrid[1] = {}
	for j=boundY1,boundY2 do
		anggrid[1][j + offsetY] = -1
	end
	anggrid[1][boundY2 + offsetY] = -1

	for i=boundX1+1,boundX2-1 do
		anggrid[i+offsetX] = {}
		anggrid[i+offsetX][1] = -1
		for j=(boundY1+1),boundY2-1 do
			local position = Vector(GridNav:GridPosToWorldCenterX(i), GridNav:GridPosToWorldCenterY(j), 0)
			local blocked = not GridNav:IsTraversable(position) or GridNav:IsBlocked(position) --or (pseudoGNV[i] ~= nil and pseudoGNV[i][j])
			local seg = 0
			local sum = Vector(0,0,0)
			local count = 0
			local inseg = false

			if blocked then
				for k=1,#vecs do
					local vec = vecs[k].vec
					local xoff = vecs[k].x
					local yoff = vecs[k].y
					local pos = Vector(GridNav:GridPosToWorldCenterX(i+xoff), GridNav:GridPosToWorldCenterY(j+yoff), 0)
					local blo = not GridNav:IsTraversable(pos) or GridNav:IsBlocked(pos) --or (pseudoGNV[i+xoff] ~= nil and pseudoGNV[i+xoff][j+yoff])

					if not blo then
						count = count + 1
						inseg = true
						sum = sum + vec
					else
						if inseg then
							inseg = false
							seg = seg + 1
						end
					end
				end

				if seg > 1 then
					print ('OVERSEG x=' .. i .. ' y=' .. j)
					anggrid[i+offsetX][j+offsetY] = -1
				elseif count > 5 then
					print ('PROTRUDE x=' .. i .. ' y=' .. j)
					anggrid[i+offsetX][j+offsetY] = -1
				elseif count == 0 then
					anggrid[i+offsetX][j+offsetY] = -1
				else
					local sum = sum:Normalized()
					local angle = math.floor((math.acos(Vector(1,0,0):Dot(sum:Normalized()))/ math.pi * 180))
					if sum.y < 0 then
						angle = -1 * angle
					end
					anggrid[i+offsetX][j+offsetY] = angle
				end
			else
				anggrid[i+offsetX][j+offsetY] = -1
			end
		end
		anggrid[i+offsetX][boundY2+offsetY] = -1
	end

	anggrid[boundX2+offsetX] = {}
	for j=boundY1,boundY2 do
		anggrid[boundX2+offsetX][j+offsetY] = -1
	end
	anggrid[boundX2+offsetX][boundY2+offsetY] = -1

	print('--------------')
	print(#anggrid)
	print(#anggrid[1])
	print(#anggrid[2])
	print(#anggrid[3])

	if MAP_DATA  then
		MAP_DATA.anggrid = anggrid
	end
	Physics:AngleGrid(anggrid)
end

function Physics:AngleGrid( anggrid, angoffsets )
	self.anggrid = anggrid
	print('[PHYSICS] Angle Grid Set')
	local worldMin = Vector(GetWorldMinX(), GetWorldMinY(), 0)
	local worldMax = Vector(GetWorldMaxX(), GetWorldMaxY(), 0)
	local boundX1 = GridNav:WorldToGridPosX(worldMin.x)
	local boundX2 = GridNav:WorldToGridPosX(worldMax.x)
	local boundY1 = GridNav:WorldToGridPosX(worldMin.y)
	local boundY2 = GridNav:WorldToGridPosX(worldMax.y)
	local offsetX = boundX1 * -1 + 1
	local offsetY = boundY1 * -1 + 1
	self.offsetX = offsetX
	self.offsetY = offsetY

	if angoffsets ~= nil then
		self.offsetX = math.abs(angoffsets.x) + 1
		self.offsetY = math.abs(angoffsets.y) + 1
	end
end

function Physics:Unit(unit)
	if IsPhysicsUnit(unit) then
		--unit:StopPhysicsSimulation()
		return
	end
	function unit:StopPhysicsSimulation ()
		Physics.timers[unit.PhysicsTimerName] = nil
		unit.bStarted = false
	end
	function unit:StartPhysicsSimulation ()
		Physics.timers[unit.PhysicsTimerName] = unit.PhysicsTimer
		unit.PhysicsTimer.endTime = GameRules:GetGameTime()
		unit.PhysicsLastPosition = unit:GetAbsOrigin()
		unit.PhysicsLastTime = GameRules:GetGameTime()
		unit.vLastVelocity = Vector(0,0,0)
		unit.bStarted = true
	end

	function unit:SetPhysicsVelocity (velocity)
		unit.vVelocity = velocity / 30
		if unit.nVelocityMax > 0 and unit.vVelocity:Length() > unit.nVelocityMax then
			unit.vVelocity = unit.vVelocity:Normalized() * unit.nVelocityMax
		end

		if unit.bStarted and unit.bHibernating then
			Physics.timers[unit.PhysicsTimerName] = unit.PhysicsTimer
			unit.PhysicsTimer.endTime = GameRules:GetGameTime()
			unit.PhysicsLastPosition = unit:GetAbsOrigin()
			unit.PhysicsLastTime = GameRules:GetGameTime()
			unit.vLastVelocity = Vector(0,0,0)
			unit.bHibernating = false
		end
	end
	function unit:AddPhysicsVelocity (velocity)
		unit.vVelocity = unit.vVelocity + velocity / 30
		if unit.nVelocityMax > 0 and unit.vVelocity:Length() > unit.nVelocityMax then
			unit.vVelocity = unit.vVelocity:Normalized() * unit.nVelocityMax
		end

		if unit.bStarted and unit.bHibernating then
			Physics.timers[unit.PhysicsTimerName] = unit.PhysicsTimer
			unit.PhysicsTimer.endTime = GameRules:GetGameTime()
			unit.PhysicsLastPosition = unit:GetAbsOrigin()
			unit.PhysicsLastTime = GameRules:GetGameTime()
			unit.vLastVelocity = Vector(0,0,0)
			unit.bHibernating = false
		end
	end

	function unit:SetPhysicsVelocityMax (velocityMax)
		unit.nVelocityMax = velocityMax / 30
	end
	function unit:GetPhysicsVelocityMax ()
		return unit.vVelocity * 30
	end

	function unit:SetPhysicsAcceleration (acceleration)
		unit.vAcceleration = acceleration / 900

		if unit.bStarted and unit.bHibernating then
			Physics.timers[unit.PhysicsTimerName] = unit.PhysicsTimer
			unit.PhysicsTimer.endTime = GameRules:GetGameTime()
			unit.PhysicsLastPosition = unit:GetAbsOrigin()
			unit.PhysicsLastTime = GameRules:GetGameTime()
			unit.vLastVelocity = Vector(0,0,0)
			unit.bHibernating = false
		end
	end
	function unit:AddPhysicsAcceleration (acceleration)
		unit.vAcceleration = unit.vAcceleration + acceleration / 900

		if unit.bStarted and unit.bHibernating then
			Physics.timers[unit.PhysicsTimerName] = unit.PhysicsTimer
			unit.PhysicsTimer.endTime = GameRules:GetGameTime()
			unit.PhysicsLastPosition = unit:GetAbsOrigin()
			unit.PhysicsLastTime = GameRules:GetGameTime()
			unit.vLastVelocity = Vector(0,0,0)
			unit.bHibernating = false
		end
	end

	function unit:SetPhysicsFriction (friction)
		unit.fFriction = friction
	end

	function unit:GetPhysicsVelocity ()
		return unit.vVelocity  * 30
	end
	function unit:GetPhysicsAcceleration ()
		return unit.vAcceleration * 900
	end
	function unit:GetPhysicsFriction ()
		return unit.fFriction
	end

	function unit:FollowNavMesh (follow)
		unit.bFollowNavMesh = follow
	end
	function unit:IsFollowNavMesh ()
		return unit.bFollowNavMesh
	end

	function unit:SetGroundBehavior (ground)
		unit.nLockToGround = ground
	end
	function unit:GetGroundBehavior ()
		return unit.nLockToGround
	end

	function unit:PreventDI (prevent)
		unit.bPreventDI = prevent
		if not prevent and unit:HasModifier("modifier_rooted") then
			unit:RemoveModifierByName("modifier_rooted")
		end
	end
	function unit:IsPreventDI ()
		return unit.bPreventDI
	end

	function unit:SetNavCollisionType (collisionType)
		unit.nNavCollision = collisionType
	end
	function unit:GetNavCollisionType ()
		return unit.nNavCollision
	end

	function unit:OnPhysicsFrame(fun)
		unit.PhysicsFrameCallback = fun
	end

	function unit:SetVelocityClamp (clamp)
		unit.fVelocityClamp = clamp / 30
	end

	function unit:GetVelocityClamp ()
		return unit.fVelocityClamp * 30
	end

	function unit:Hibernate (hibernate)
		unit.bHibernate = hibernate
	end

	function unit:IsHibernate ()
		return unit.bHibernate
	end

	function unit:DoHibernate ()
		Physics.timers[unit.PhysicsTimerName] = nil
		unit.bHibernating = true
	end

	function unit:OnHibernate(fun)
		unit.PhysicsHibernateCallback = fun
	end

	function unit:OnPreBounce(fun)
		unit.PhysicsOnPreBounce = fun
	end

	function unit:OnBounce(fun)
		unit.PhysicsOnBounce = fun
	end

	function unit:AdaptiveNavGridLookahead (adaptive)
		unit.bAdaptiveNavGridLookahead = adaptive
	end

	function unit:IsAdaptiveNavGridLookahead ()
		return unit.bAdaptiveNavGridLookahead
	end

	function unit:SetNavGridLookahead (lookahead)
		unit.nNavGridLookahead = lookahead
	end

	function unit:GetNavGridLookahead ()
		return unit.nNavGridLookahead
	end

	function unit:SetRebounceFrames ( rebounce )
		unit.nMaxRebounce = rebounce
		unit.nRebounceFrames = 0
	end

	function unit:GetRebounceFrames ()
		unit.nRebounceFrames = 0
		return unit.nMaxRebounce
	end

	function unit:GetLastGoodPosition ()
		return unit.vLastGoodPosition
	end

	function unit:SetStuckTimeout (timeout)
		unit.nStuckTimeout = timeout
		unit.nStuckFrames = 0
	end
	function unit:GetStuckTimeout ()
		unit.nStuckFrames = 0
		return unit.nStuckTimeout
	end

	function unit:SetAutoUnstuck (unstuck)
		unit.bAutoUnstuck = unstuck
	end
	function unit:GetAutoUnstuck ()
		return unit.bAutoUnstuck
	end

	function unit:SetPhysicsBoundingRadius(bounding)
		unit.fBoundingRadius = bounding
	end
	function unit:GetPhysicsBoundingRadius()
		return unit.fBoundingRadius
	end

	function unit:SetBounceMultiplier (bounce)
		unit.fBounceMultiplier = bounce
	end
	function unit:GetBounceMultiplier ()
		return unit.fBounceMultiplier
	end

	function unit:GetTotalVelocity()
		if unit.bStarted and not unit.bHibernating then
			return unit.vTotalVelocity
		else
			return Vector(0,0,0)
		end
	end

	function unit:GetColliders()
		return unit.oColliders
	end

	function unit:RemoveCollider(name)
		if name == nil then
			local i,v = next(unit.oColliders,  nil)
			if i == nil then
				return
			end
			name = unit.oColliders[i].name
		elseif type(name) == "table" then
			name = name.name
		end
		Physics:RemoveCollider(name)
	end

	function unit:AddCollider(name, collider)
		local coll = Physics:AddCollider(name, collider)
		coll.unit = unit
		unit.oColliders[coll.name] = coll
		return coll
	end

	function unit:AddColliderFromProfile(name, profile, collider)
		if profile == nil then
			profile = name
			name = DoUniqueString("collider")
		elseif type(profile) == "table" then
			collider = profile
			profile = name
			name = DoUniqueString("collider")
		end
		local coll = Physics:AddCollider(name, Physics:ColliderFromProfile(profile, collider))
		coll.unit = unit
		unit.oColliders[coll.name] = coll
		return coll
	end

	function unit:GetMass()
		return unit.fMass
	end

	function unit:SetMass(mass)
		unit.fMass = mass
	end

	unit.PhysicsTimerName = DoUniqueString('phys')
	Physics:CreateTimer(unit.PhysicsTimerName, {
		endTime = GameRules:GetGameTime(),
		useGameTime = true,
		callback = function(banjoball, args)
			local original_IsTraversable = GridNav.IsTraversable
			local original_IsBlocked = GridNav.IsBlocked
			local original_IsNearbyTree = GridNav.IsNearbyTree
			
			if unit.isBall then
				GridNav.IsTraversable = function(self, pos)
					if original_IsNearbyTree(self, pos, 35, true) then
						return true
					end
					return original_IsTraversable(self, pos)
				end
				
				GridNav.IsBlocked = function(self, pos)
					if original_IsNearbyTree(self, pos, 35, true) then
						return false
					end
					return original_IsBlocked(self, pos)
				end
				
				GridNav.IsNearbyTree = function(self, pos, radius, bool)
					return false
				end
			end

			local prevTime = unit.PhysicsLastTime
			if not IsValidEntity(unit) then
				if unit.isBall then
					GridNav.IsTraversable = original_IsTraversable
					GridNav.IsBlocked = original_IsBlocked
					GridNav.IsNearbyTree = original_IsNearbyTree
				end
				return
			end
			local curTime = GameRules:GetGameTime()
			local prevPosition = unit.PhysicsLastPosition
			local position = unit:GetAbsOrigin()
				local lastVelocity = unit.vLastVelocity
			unit.vLastVelocity = unit.vVelocity
			unit.vTotalVelocity = (position - prevPosition) / (curTime - prevTime)

			unit.PhysicsLastTime = curTime
			unit.PhysicsLastPosition = position

			if unit.bPreventDI and not unit:HasModifier("modifier_rooted") then
				unit:AddNewModifier(unit, nil, "modifier_rooted", {})
			end

			-- Adjust velocity
			local newVelocity = unit.vVelocity + unit.vAcceleration - Vector(unit.vVelocity.x, unit.vVelocity.y, 0)*unit.fFriction

			-- Calculate new position
			local newPos = position + unit.vVelocity
			if unit.nLockToGround == PHYSICS_GROUND_LOCK then
				local groundPos = GetGroundPosition(newPos, unit)
				newPos = groundPos
				newVelocity.z = 0
			elseif unit.nLockToGround == PHYSICS_GROUND_ABOVE then
				local groundPos = GetGroundPosition(newPos, unit)
				if groundPos.z > newPos.z then
					newPos = groundPos
					newVelocity.z = 0
				end
			end

			local newVelLength = newVelocity:Length()

			local blockedPos = unit.nNavCollision ~= PHYSICS_NAV_NOTHING and (not GridNav:IsTraversable(position) or GridNav:IsBlocked(position))
			if not blockedPos then
				unit.vLastGoodPosition = position
				unit.nStuckFrames = 0
			else
				unit.nStuckFrames = unit.nStuckFrames + 1
			end

			if unit.nVelocityMax > 0 and newVelLength > unit.nVelocityMax then
				newVelocity = newVelocity:Normalized() * unit.nVelocityMax
			end
			if unit.vAcceleration.x == 0 and unit.vAcceleration.y == 0 and newVelLength <= unit.fVelocityClamp then
				--print('clamp')
				newVelocity = Vector(0,0,newVelocity.z)
				if unit:HasModifier("modifier_rooted") then
					unit:RemoveModifierByName("modifier_rooted")
				end
				if unit.bHibernate then
					unit:DoHibernate()
					local ent = Entities:FindInSphere(nil, position, 35)
					local blocked = false
					while ent ~= nil and not blocked do
						if ent.IsHero ~= nil and ent ~= unit then
							blocked = true
						end
						--print(ent:GetClassname() .. " -- " .. ent:GetName() .. " -- " .. tostring(ent.IsHero))
						ent = Entities:FindInSphere(ent, position, 35)
					end
					if blocked or blockedPos or (GridNav:IsNearbyTree(position, 30, true) and unit.nNavCollision ~= PHYSICS_NAV_NOTHING) then
						FindClearSpaceForUnit(unit, position, false)
						--print('FCS hib')
					end
					if unit.PhysicsHibernateCallback ~= nil then
						local status, nextCall = pcall(unit.PhysicsHibernateCallback, unit)
						if not status then
							print('[PHYSICS] Failed HibernateCallback: ' .. nextCall)
						end
					end
					return
				end

				local ent = Entities:FindInSphere(nil, position, 35)
				local blocked = false
				while ent ~= nil and not blocked do
					if ent.IsHero ~= nil and ent ~= unit then
						blocked = true
					end
					--print(ent:GetClassname() .. " -- " .. ent:GetName() .. " -- " .. tostring(ent.IsHero))
					ent = Entities:FindInSphere(ent, position, 35)
				end
				if blocked or not GridNav:IsTraversable(position) or GridNav:IsBlocked(position) or GridNav:IsNearbyTree(position, 30, true) then
					FindClearSpaceForUnit(unit, position, false)
					--print('FCS nothib lowv + blocked')
				end
				--return curTime
			end


			if unit.vVelocity ~= Vector(0,0,0) then
				if unit.bFollowNavMesh then
					local diff = unit.vVelocity:Normalized()

					position = newPos

					local bound = unit.fBoundingRadius

					local connect = newPos
					local navConnect = not GridNav:IsTraversable(connect) or GridNav:IsBlocked(connect)
					local lookaheadNum = unit.nNavGridLookahead
					if unit.bAdaptiveNavGridLookahead then
						lookaheadNum = math.ceil(unit.vVelocity:Length() / 32)
					end
					local tot = lookaheadNum + 1
					local div = 1 / tot
					local index = 1
					while not navConnect and index < tot do
						connect = newPos + (unit.vVelocity + diff * bound) * (div * index)
						navConnect = not GridNav:IsTraversable(connect) or GridNav:IsBlocked(connect)
						index = index + 1
					end
					--or not GridNav:IsTraversable(newPos + unit.vVelocity * .5) -- diff * unit.nNavGridLookahead
					--or  or GridNav:IsBlocked(newPos + unit.vVelocity * .5)
					if unit.nNavCollision == PHYSICS_NAV_HALT and navConnect then
						newVelocity = Vector(0,0,0)
						FindClearSpaceForUnit(unit, newPos, false)
					elseif unit.nNavCollision == PHYSICS_NAV_SLIDE and navConnect then
						local navX = GridNav:WorldToGridPosX(connect.x)
						local navY = GridNav:WorldToGridPosY(connect.y)
						local navPos = Vector(GridNav:GridPosToWorldCenterX(navX), GridNav:GridPosToWorldCenterY(navY), 0)
						--unit.nRebounceFrames = unit.nMaxRebounce

						local normal = nil
						local anggrid = self.anggrid
						local offX = self.offsetX
						local offY = self.offsetY
						local dir = position - navPos
						local x = position.x
						local y = position.y
						local middle = navPos
						local xblock = true
						local value = 0

						if anggrid then
							local angSize = #anggrid
							local angX = navX + offX
							local angY = navY + offY

							--print(offX .. ' -- ' .. angX .. ' == ' .. angY .. ' -- ' .. offY)

							local angle = anggrid[angX][angY]
							if angle ~= -1 then
								angle = angle
								normal = RotatePosition(Vector(0,0,0), QAngle(0,angle,0), Vector(1,0,0))
								--print(angle)
								--print(normal)
								--print('----------')

								if math.abs(normal.x) > math.abs(normal.y) then
									xblock = true
									if normal.x > 0 then
										value = navPos.x + 33 + bound
									else
										value = navPos.x - 33 - bound
									end
								else
									xblock = false
									if normal.y > 0 then
										value = navPos.y + 33 + bound
									else
										value = navPos.y - 33 - bound
									end
								end
							end
						end

						if normal == nil then

							if x > middle.x then
								if y > middle.y then
									-- up,right
									local relx = (position.x - middle.x)
									local rely = (position.y - middle.y)

									if relx > rely then
										--right
										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									else
										--up
										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								elseif y <= middle.y then
									-- down,right
									local relx = (position.x - middle.x)
									local rely = (middle.y - position.y)

									if relx > rely then
										--right
										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									else
										--down
										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									end
								end
							elseif x <= middle.x then
								if y > middle.y then
									-- up,left
									local relx = (middle.x - position.x)
									local rely = (position.y - middle.y)

									if relx > rely then
										--left
										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										--up
										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								elseif y <= middle.y then
									-- down,left
									local relx = (middle.x - position.x)
									local rely = (middle.y - position.y)

									if relx > rely then
										--left
										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										--down
										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									end
								end
							end

							local navPos2 = navPos + normal * 64
							local navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
							if navConnect2 then
								-- coming in from an invalid side
								if xblock then
									-- coming in on x, test y velocity
									if unit.vVelocity.y > 0 then
										navPos2 = navPos + Vector(0,-64,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, true, navPos.x + (33 + bound) * normal.x, 0, false)
											normal = Vector(0,0,0)
										end

										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									else
										navPos2 = navPos + Vector(0,64,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, true, navPos.x + (33 + bound) * normal.x, 0, false)
											normal = Vector(0,0,0)
										end

										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								else
									-- coming in on y, test x velocity
									if unit.vVelocity.x > 0 then
										navPos2 = navPos + Vector(-64,0,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, false, navPos.y + (33 + bound) * normal.y, 0, false)
											normal = Vector(0,0,0)
										end

										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										navPos2 = navPos + Vector(64,0,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, false, navPos.y + (33 + bound) * normal.y, 0, false)
											normal = Vector(0,0,0)
										end

										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									end
								end
							end
						end

						if normal == Vector(0,0,0) then
							newVelocity = Vector(0,0,0)
						else
							newVelocity = (newVelocity:Dot(normal * -1) * normal) + newVelocity
						end
						unit.vVelocity = newVelocity

						Physics:BlockInAABox(unit, xblock, value, 0, false)
						--print(unit:GetAbsOrigin())
					elseif unit.nRebounceFrames <= 0 and unit.nNavCollision == PHYSICS_NAV_BOUNCE and navConnect then
						--print('bounce')
						local navX = GridNav:WorldToGridPosX(connect.x)
						local navY = GridNav:WorldToGridPosY(connect.y)
						local navPos = Vector(GridNav:GridPosToWorldCenterX(navX), GridNav:GridPosToWorldCenterY(navY), 0)
						--unit.nRebounceFrames = unit.nMaxRebounce

						local normal = nil
						local anggrid = self.anggrid
						local offX = self.offsetX
						local offY = self.offsetY
						local dir = position - navPos
						local x = position.x
						local y = position.y
						local middle = navPos
						local xblock = true
						local value = 0

						if anggrid then
							local angSize = #anggrid
							local angX = navX + offX
							local angY = navY + offY

							--print(offX .. ' -- ' .. angX .. ' == ' .. angY .. ' -- ' .. offY)

							local angle = anggrid[angX][angY]
							if angle ~= -1 then
								angle = angle
								normal = RotatePosition(Vector(0,0,0), QAngle(0,angle,0), Vector(1,0,0))
								--print(angle)
								--print(normal)
								--print('----------')

								if math.abs(normal.x) > math.abs(normal.y) then
									xblock = true
									if normal.x > 0 then
										value = navPos.x + 33 + bound
									else
										value = navPos.x - 33 - bound
									end
								else
									xblock = false
									if normal.y > 0 then
										value = navPos.y + 33 + bound
									else
										value = navPos.y - 33 - bound
									end
								end
							end
						end
						if normal == nil then
							if x > middle.x then
								if y > middle.y then
									-- up,right
									local relx = (position.x - middle.x)
									local rely = (position.y - middle.y)

									if relx > rely then
										--right
										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									else
										--up
										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								elseif y <= middle.y then
									-- down,right
									local relx = (position.x - middle.x)
									local rely = (middle.y - position.y)

									if relx > rely then
										--right
										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									else
										--down
										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									end
								end
							elseif x <= middle.x then
								if y > middle.y then
									-- up,left
									local relx = (middle.x - position.x)
									local rely = (position.y - middle.y)

									if relx > rely then
										--left
										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										--up
										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								elseif y <= middle.y then
									-- down,left
									local relx = (middle.x - position.x)
									local rely = (middle.y - position.y)

									if relx > rely then
										--left
										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										--down
										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									end
								end
							end

							local navPos2 = navPos + normal * 64
							local navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
							if navConnect2 then
								-- coming in from an invalid side
								if xblock then
									-- coming in on x, test y velocity
									if unit.vVelocity.y > 0 then
										navPos2 = navPos + Vector(0,-64,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, true, navPos.x + (33 + bound) * normal.x, 0, false)
											normal = Vector(-1*diff.x,-1*diff.y,diff.z)
										end

										normal = Vector(0,-1,0)
										value = navPos.y - 33 - bound
										xblock = false
									else
										navPos2 = navPos + Vector(0,64,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, true, navPos.x + (33 + bound) * normal.x, 0, false)
											normal = Vector(-1*diff.x,-1*diff.y,diff.z)
										end

										normal = Vector(0,1,0)
										value = navPos.y + 33 + bound
										xblock = false
									end
								else
									-- coming in on y, test x velocity
									if unit.vVelocity.x > 0 then
										navPos2 = navPos + Vector(-64,0,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, false, navPos.y + (33 + bound) * normal.y, 0, false)
											normal = Vector(-1*diff.x,-1*diff.y,diff.z)
										end

										normal = Vector(-1,0,0)
										value = navPos.x - 33 - bound
										xblock = true
									else
										navPos2 = navPos + Vector(64,0,0)
										navConnect2 = not GridNav:IsTraversable(navPos2) or GridNav:IsBlocked(navPos2)
										if navConnect2 then
											Physics:BlockInAABox(unit, false, navPos.y + (33 + bound) * normal.y, 0, false)
											normal = Vector(-1*diff.x,-1*diff.y,diff.z)
										end

										normal = Vector(1,0,0)
										value = navPos.x + 33 + bound
										xblock = true
									end
								end
							end
						end

						if unit.PhysicsOnPreBounce then
							local status, nextCall = pcall(unit.PhysicsOnPreBounce, unit, normal)
							if not status then
								print('[PHYSICS] Failed OnPreBounce: ' .. nextCall)
							end
						end

						newVelocity = ((-2 * newVelocity:Dot(normal) * normal) + newVelocity) * unit.fBounceMultiplier
						unit.vVelocity = newVelocity

						Physics:BlockInAABox(unit, xblock, value, 0, false)
						--print(unit:GetAbsOrigin(), value)
						if unit.PhysicsOnBounce then
							local status, nextCall = pcall(unit.PhysicsOnBounce, unit, normal)
							if not status then
								print('[PHYSICS] Failed OnBounce: ' .. nextCall)
							end
						end
					end
				end -- executes if not unit.bFollowNavMesh
				-- if unit == Ball.unit then
					-- FindClearSpaceForUnit(unit, newPos, false)--unit:SetAbsOrigin(newPos)
				-- else 
				unit:SetAbsOrigin(newPos)
				-- end
			end -- ends if unit.vVelocity ~= Vector(0,0,0)

			unit.nRebounceFrames = unit.nRebounceFrames - 1
			unit.vVelocity = newVelocity

			if unit.PhysicsFrameCallback ~= nil then
				local status, nextCall = pcall(unit.PhysicsFrameCallback, unit)
				if not status then
					print('[PHYSICS] Failed FrameCallback: ' .. nextCall)
				end
			end

			if unit.bAutoUnstuck and unit.nStuckFrames >= unit.nStuckTimeout then
				unit.nStuckFrames = 0

				local navX = GridNav:WorldToGridPosX(position.x)
				local navY = GridNav:WorldToGridPosY(position.y)

				local anggrid = self.anggrid
				local offX = self.offsetX
				local offY = self.offsetY
				local old_pos = position
				local new_pos
				if anggrid then
					local angSize = #anggrid
					local angX = navX + offX
					local angY = navY + offY

					--print(offX .. ' -- ' .. angX .. ' == ' .. angY .. ' -- ' .. offY)

					local angle = anggrid[angX][angY]
					if angle ~= -1 then
						local normal = RotatePosition(Vector(0,0,0), QAngle(0,angle,0), Vector(1,0,0))
						--print(normal)
						--print('----------')

						new_pos = position + normal * 64
						unit:SetAbsOrigin(new_pos)
					else
						new_pos = unit.vLastGoodPosition
						unit:SetAbsOrigin(new_pos)
					end
				else
					new_pos = unit.vLastGoodPosition
					unit:SetAbsOrigin(new_pos)
				end
				-- local msg = string.format("[AutoUnstuck] Unit %s unstuck. Teleporting from (%.1f, %.1f) to (%.1f, %.1f)", 
				-- 	unit:GetUnitName(), old_pos.x, old_pos.y, new_pos.x, new_pos.y)
				-- GameRules:SendCustomMessage(msg, 0, 0)
			end

			if unit.isBall then
				GridNav.IsTraversable = original_IsTraversable
				GridNav.IsBlocked = original_IsBlocked
				GridNav.IsNearbyTree = original_IsNearbyTree
			end

			return curTime
		end
	})

	unit.PhysicsTimer = Physics.timers[unit.PhysicsTimerName]
	unit.vVelocity = Vector(0,0,0)
	unit.vLastVelocity = Vector(0,0,0)
	unit.vAcceleration = Vector(0,0,0)
	unit.fFriction = GROUND_FRICTION
	unit.PhysicsLastPosition = unit:GetAbsOrigin()
	unit.PhysicsLastTime = GameRules:GetGameTime()
	unit.vTotalVelocity = Vector(0,0,0)
	unit.bFollowNavMesh = true
	unit.nLockToGround = PHYSICS_GROUND_ABOVE
	unit.bPreventDI = false
	unit.nNavCollision = PHYSICS_NAV_SLIDE
	unit.nVelocityMax = 0
	unit.PhysicsFrameCallback = nil
	unit.fVelocityClamp = 20.0 / 30.0
	unit.bHibernate = true
	unit.bHibernating = false
	unit.bStarted = true
	unit.nNavGridLookahead = 1
	unit.bAdaptiveNavGridLookahead = false
	unit.nMaxRebounce = 2
	unit.nRebounceFrames = 2
	unit.vLastGoodPosition = unit:GetAbsOrigin()
	unit.bAutoUnstuck = true
	unit.nStuckTimeout = 3
	unit.nStuckFrames = 0
	unit.fBounceMultiplier = 1.0
	unit.oColliders = {}
	unit.fMass = 100
	unit.fBoundingRadius = 0
	if unit.GetPaddedCollisionRadius then
		unit.fBoundingRadius = unit:GetPaddedCollisionRadius() + 1
	elseif unit.GetBoundingMaxs then
		unit.fBoundingRadius = math.max(unit:GetBoundingMaxs().x, unit:GetBoundingMaxs().y)
	end
end

function Physics:BlockInSphere(unit, unitToRepel, radius, findClearSpace)
	local pos = unit:GetAbsOrigin()
	local vPos = unitToRepel:GetAbsOrigin()
	local dir = vPos - pos
	local dist2 = VectorDistanceSq(pos, vPos)
	local move = radius
	local move2 = move * move

	if move2 < dist2 then
		return
	end

	if findClearSpace then
		FindClearSpaceForUnit(unitToRepel, pos + (dir:Normalized() * move), false)
	else
		unitToRepel:SetAbsOrigin(pos + (dir:Normalized() * move))
	end
end

function Physics:BlockInAABox(unit, xblock, value, buffer, findClearSpace)
	local pos = unit:GetAbsOrigin()

	if xblock then
		pos.x = value
	else
		pos.y = value
	end

	if findClearSpace then
		FindClearSpaceForUnit(unit, pos, false)
	else
		unit:SetAbsOrigin(pos)
	end
end

function Physics:PrecalculateBoxDraw(box)
	local ang = RotationDelta(VectorToAngles(box.upNormal), VectorToAngles(Vector(1,0,0))).y
	local ang2 = RotationDelta(VectorToAngles(box.rightNormal), VectorToAngles(Vector(1,0,0))).y
	if ang > 90 then
		ang = 180 - ang
	elseif ang < -90 then
		ang = -180 - ang
	end

	if ang2 > 90 then
		ang2 = 180 - ang2
	elseif ang2 < -90 then
		ang2 = -180 - ang2
	end

	local a = ang
	if math.abs(ang2) < math.abs(ang) then
		a = ang2
	end

	local aRot = RotatePosition(box.a, QAngle(0, a, 0), box.a)
	local bRot = RotatePosition(box.a, QAngle(0, a, 0), box.b)
	local cRot = RotatePosition(box.a, QAngle(0, a, 0), box.c)
	local dRot = RotatePosition(box.a, QAngle(0, a, 0), box.d)

	local minX = math.min(math.min(math.min(aRot.x, bRot.x), cRot.x), dRot.x)
	local minY = math.min(math.min(math.min(aRot.y, bRot.y), cRot.y), dRot.y)
	local maxX = math.max(math.max(math.max(aRot.x, bRot.x), cRot.x), dRot.x)
	local maxY = math.max(math.max(math.max(aRot.y, bRot.y), cRot.y), dRot.y)

	box.drawAngle = -1 * a
	box.drawMins = Vector(minX, minY, box.zMin)
	box.drawMaxs = Vector(maxX, maxY, box.zMax)
end

function Physics:PrecalculateBox(box)
	box.zMin = math.min(math.min(box[1].z, box[2].z), box[3].z)
	box.zMax = math.max(math.max(box[1].z, box[2].z), box[3].z)
	box.center = box[2] + (box[3] - box[2]) / 2
	box.center.z = (box.zMin + box.zMax) / 2
	box.radius = math.max((box[3] - box.center):Length(), (box[2] - box.center):Length())
	box.middle = Vector(box.center.x, box.center.y, box.center.z)
	box.middle.z = 0
	box.a = box[1]
	box.a.z = 0
	box.b = box[2]
	box.b.z = 0
	box.d = box[3]
	box.d.z = 0
	box.c = box.b + (box.d - box.a)
	box.upNormal = (box.d - box.a):Normalized()
	box.rightNormal = (box.b - box.a):Normalized()

	box[1] = nil
	box[2] = nil
	box[3] = nil

	box.ab = box.b - box.a
	box.ad = box.d - box.a
	box.ab2 = box.ab:Dot(box.ab)
	box.ad2 = box.ad:Dot(box.ad)

	box.recalculate = nil
	return box
end

function Physics:PrecalculateAABox(box)
	box.xMin = math.min(box[1].x, box[2].x)
	box.xMax = math.max(box[1].x, box[2].x)
	box.yMin = math.min(box[1].y, box[2].y)
	box.yMax = math.max(box[1].y, box[2].y)
	box.zMin = math.min(box[1].z, box[2].z)
	box.zMax = math.max(box[1].z, box[2].z)
	box.center = Vector((box.xMin + box.xMax) / 2, (box.yMin + box.yMax) / 2, (box.zMin + box.zMax) / 2)
	box.radius =(Vector(xMax, yMax, zMax) - box.center):Length()
	box.middle = Vector(box.center.x, box.center.y, 0)

	box.xScale = box.xMax - box.middle.x
	box.yScale = box.yMax - box.middle.y

	box[1] = nil
	box[2] = nil

	box.recalculate = nil
	return box
end


Physics:start()

Physics:CreateColliderProfile("momentum",
	{
		type = COLLIDER_SPHERE,
		radius = 100,
		recollideTime = .1,
		skipFrames = 0,
		block = true,
		blockRadius = 50,
		moveSelf = false,
		findClearSpace = false,
		elasticity = 1,
		test = function(self, collider, collided)
			return collided.IsRealHero and collided:IsRealHero() and collider:GetTeam() ~= collided:GetTeam() and IsPhysicsUnit(collided)
		end,
		action = function(self, unit, v)
			if self.hitTime == nil or GameRules:GetGameTime() >= self.hitTime then
				local pos = unit:GetAbsOrigin()
				local vPos = v:GetAbsOrigin()
				local dir = vPos - pos
				local mass = unit:GetMass()
				local vMass = v:GetMass()

				dir = dir:Normalized()

				local neg = -1 * dir

				local dot = dir:Dot(unit:GetTotalVelocity())
				local dot2 = dir:Dot(v:GetTotalVelocity())

				local v1 = (self.elasticity * vMass * (dot2 - dot) + (mass * dot) + (vMass * dot2)) / (mass + vMass)
				local v2 = (self.elasticity * mass * (dot - dot2) + (mass * dot) + (vMass * dot2)) / (mass + vMass)

				unit:AddPhysicsVelocity((v1 - dot) * dir)
				v:AddPhysicsVelocity((v2 - dot2) * dir)

				if self.block then
					if self.moveSelf then
						Physics:BlockInSphere(v, unit, self.blockRadius, self.findClearSpace)
					else
						Physics:BlockInSphere(unit, v, self.blockRadius, self.findClearSpace)
					end
				end

				self.hitTime = GameRules:GetGameTime() + self.recollideTime
			end
		end
	})

Physics:CreateColliderProfile("aaboxreflect",
	{
		type = COLLIDER_AABOX,
		box = {Vector(0,0,0), Vector(200,100,500)},
		recollideTime = 0,
		skipFrames = 0,
		buffer = 0,
		block = true,
		findClearSpace = false,
		multiplier = 1,
		test = function(self, unit)
			return unit.IsRealHero and unit:IsRealHero() and unit:GetTeam() ~= unit:GetTeam() and IsPhysicsUnit(unit)
		end,
		action = function(self, box, unit)
			local pos = unit:GetAbsOrigin()

			local x = pos.x
			local y = pos.y
			local middle = box.middle
			local xblock = true
			local value = 0
			local normal = Vector(1,0,0)

			local result = find_closest_point_on_square_boundary(box.xMin, box.yMin, box.xMax, box.yMax, {x, y} )
			value = Vector(result[1], result[2], pos.z )
			
			local normal = calculateNormal(box.xMin, box.yMin, box.xMax, box.yMax, {x, y} )
			local vectorNormal = result[3]

			if self.block then
				unit:SetAbsOrigin(value)
			end

			local newVelocity = unit.vVelocity
			if newVelocity and newVelocity:Dot(vectorNormal) >= 0 then
				-- local msg = string.format("[%s] Unit %s blocked at (%.1f, %.1f) -> (%.1f, %.1f)", 
				-- 	self.name or "aaboxreflect", unit:GetUnitName(), pos.x, pos.y, value.x, value.y)
				-- GameRules:SendCustomMessage(msg, 0, 0)
				return
			end
			if newVelocity then
				local reflected_vel = ((-2 * newVelocity:Dot(vectorNormal) * vectorNormal) + newVelocity) * self.multiplier * 30
				unit:SetPhysicsVelocity(reflected_vel)
				-- local msg = string.format("[%s] Unit %s hit boundary. Pos (%.1f, %.1f) -> (%.1f, %.1f). Vel reflected to (%.1f, %.1f)", 
				-- 	self.name or "aaboxreflect", unit:GetUnitName(), pos.x, pos.y, value.x, value.y, reflected_vel.x, reflected_vel.y)
				-- GameRules:SendCustomMessage(msg, 0, 0)
			end
		end
	})
Physics:CreateColliderProfile("circlenom",
	{
		type = COLLIDER_SPHERE,
		radius = 100,
		recollideTime = .1,
		skipFrames = 0,
		block = true,
		blockRadius = 50,
		findClearSpace = false,
		elasticity = 1,
		multiplier = 1,
		tester = true,
		test = function(self, collider, collided)
			return collided.IsRealHero and collided:IsRealHero() and collider:GetTeam() ~= collided:GetTeam() and IsPhysicsUnit(collided)
		end,
		action = function(self, unit, v)
			local pos = v:GetAbsOrigin()
			local bpos = unit:GetAbsOrigin()
			pos.z = bpos.z
			local dir = (pos - bpos):Normalized()
			local result = bpos  + (dir * self.radius)
			result.z = v:GetAbsOrigin().z
			--value = Vector(result.x, result.y, pos.z )
			

			if self.block then
				v:SetAbsOrigin(result)
			end

			local newVelocity = v.vVelocity
			-- if newVelocity and newVelocity:Dot(vectorNormal) >= 0 then
				-- return
			-- end
			if newVelocity then
				v:SetPhysicsVelocity((newVelocity:Length() * dir ) *  30 *self.multiplier)
			end
		end
	})