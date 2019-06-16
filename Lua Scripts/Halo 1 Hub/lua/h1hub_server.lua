--Talking Timer Server Side Script by Michelle
api_version = "1.9.0.0"


-- Enable Training Mode in a match using:  lua_call h1hub_server enable_training_mode
-- Disable Training Mode in a match using: lua_call h1hub_server disable_training_mode


-- Admin setup:
enable_timer_functions = true
	enable_talking_timer = true
		enable_weapon_announcements = true
			enable_rocket_announcement = true
			enable_os_announcement     = true
			enable_camo_announcement   = true
			enable_sniper_announcement = false
	
	enable_cutscene_title_timer = true
		tens_flash_in_a_different_color = true
		
team_mate_spawn_beeps = true

-- Announcements that require a second instead of just half a second
long_announcements = { "overshield", "camo", "rocket", "sniper", "up_next", "20(twenny)_seconds"}

-- Script setup:
script_version = 4 --DO NOT EDIT!

-- You shouldn't edit these:
tick_counter = nil
sv_map_reset_tick = nil
game_in_progress = false
training_mode = false
cutscene_titles = {}
netgame_equipment = {}
ROCKET_LAUNCHER = 10
SNIPER_RIFLE = 11
OVERSHIELD = 12
CAMO = 13
SHIELD_CAMO = 14
game_type = nil

-- Callables:
function enable_training_mode()
	training_mode = true
end

function disable_training_mode()
	training_mode = false
end

--
function OnScriptLoad()
	register_callback(cb['EVENT_GAME_START'],"OnGameStart")
	register_callback(cb['EVENT_GAME_END'],"OnGameEnd")
	register_callback(cb['EVENT_TICK'],"OnTick")
	
	register_callback(cb['EVENT_DIE'],"OnDeath")
	register_callback(cb['EVENT_KILL'],"OnKill")
	register_callback(cb['EVENT_SUICIDE'],"OnSuicide")
	
	register_callback(cb['EVENT_WEAPON_PICKUP'],"OnPickup")
	register_callback(cb['EVENT_SPAWN'],"OnSpawn")
	
	register_callback(cb['EVENT_JOIN'],"OnJoin")
	
	InitializeTimers()
	OnGameStart()
	game_type = get_var(0, "$gt")
end

function OnJoin(player_id)
	rprint(player_id, "|n" ..sep.. "version" ..sep .. script_version)
	
	if training_mode then
		rprint(player_id, "|n" ..sep.. "training_mode" ..sep .. "true")
	else
		rprint(player_id, "|n" ..sep.. "training_mode" ..sep .. "false")
	end
end

function OnGameStart()
	game_in_progress = true
	GetScenarioData()
	game_type = get_var(0, "$gt")
end
function OnGameEnd()
	game_in_progress = false
	training_mode = false
end

last_tick_training_mode = false
function OnTick()
	if game_in_progress == true then
		if enable_timer_functions == true then
			TimersOnTick()
		end
	end
	
	if training_mode == true and last_tick_training_mode == false then
		for player_id=1,16 do
			rprint(player_id, "|n" ..sep.. "training_mode" ..sep .. "true")
		end
		last_tick_training_mode = true
	elseif training_mode == false and last_tick_training_mode == true then
		for player_id=1,16 do
			rprint(player_id, "|n" ..sep.. "training_mode" ..sep .. "false")
		end
		last_tick_training_mode = false
	end
	
	if team_mate_spawn_beeps then
		for player_id=1,16 do
			player = get_player(player_id)
			if player ~= 0 then
				local team = read_byte(player+0x20)
				local respawn_ticks = read_dword(player+0x2C)
				if respawn_ticks <= 90 and respawn_ticks >= 30 and respawn_ticks % 30 == 0 then
					for i=1,16 do
						if i ~= player_id then
							player_i = get_player(i)
							if player_i ~= 0 then
								local team_i = read_byte(player_i+0x20)
								if team == team_i then
									rprint(i, "|n" ..sep.. "spawn_beep" ..sep .. "nope")
								end
							end
						end
					end
				end
			end
		end
	end
end

function OnDeath(player_id, causer) --expect second arg as string

end

function OnKill(killer, killed) --expect second arg as string

end

function OnSuicide(player_id)

end

function OnPickup(player_id, weapon_type, weapon_slot) --expect second and third arg as string

end

function OnSpawn(player_id)
	player = get_player(player_id)
	if player ~= 0 then
		if team_mate_spawn_beeps then
			local team = read_byte(player+0x20)
			
			for i=1,16 do
				if i ~= player_id then
					player_i = get_player(i)
					if player_i ~= 0 then
						local team_i = read_byte(player_i+0x20)
						if team == team_i then
							rprint(i, "|n" ..sep.. "spawn_beep" ..sep .. "spawned")
						end
					end
				end
			end
		end
	end
end

--- Timer functions

ticks_passed = 0
count_down_seconds = 0

function InitializeTimers()
	local tick_counter_sig = sig_scan("8B2D????????807D0000C644240600")
	if(tick_counter_sig == 0) then
		cprint("Failed to find tick_counter_sig.")
		return
	end
	tick_counter = read_dword(read_dword(tick_counter_sig + 2)) + 0xC
	
	local sv_map_reset_tick_sig = sig_scan("8B510C6A018915????????E8????????83C404")
	if(sv_map_reset_tick_sig == 0) then
		cprint("Failed to find sv_map_reset_tick_sig.")
		return
	end
	sv_map_reset_tick = read_dword(sv_map_reset_tick_sig + 7)
end

sound_blocked_secs = 0

function TimersOnTick()
	ticks_passed = read_dword(tick_counter) - read_dword(sv_map_reset_tick)

	if (ticks_passed % 30) == 0 then
		if (count_down_seconds > 0) then
			count_down_seconds = count_down_seconds - 1
		end
	
		sound_blocked_secs = sound_blocked_secs - 1
		--We only want to process stuff every second
		local time_passed = math.floor(ticks_passed / 30)
		local minutes = math.floor(time_passed / 60) % 30 --modulus 30 so it resets after 30 minutes
		local seconds = time_passed % 60
		
		if enable_weapon_announcements == true then
			WeaponAnnounce(time_passed)
			NextNavpointQueueItem()
		end
		if enable_talking_timer == true then
			if sound_blocked_secs < 1 then
				TalkingTimerAnnounce(time_passed, minutes, seconds)
			end
		end
		
		if enable_cutscene_title_timer == true then
			OnScreenTimerUpdate(minutes, seconds)
		end
	end
end

sep = "`" --seperator

function TalkingTimerAnnounce(time_passed, minutes, seconds)
	local seconds_left = 60 - seconds

	local message_to_send = "|n"..sep.."timer"
	
	-- 10 seconds into the minute there is no beep,
	-- during the last 10 seconds there is no beep because of the count down
	if seconds_left % 10 == 0 and seconds ~= 10 and seconds_left ~= 10 then
		message_to_send = message_to_send ..sep.."beepbeep"
	end
	-- minute announcements only happen when the minute has just started
	if seconds == 0 then
		if minutes ~= 0 then
			message_to_send = message_to_send .. sep .. minutes .. "_minute"
			if minutes ~= 1 then
				message_to_send = message_to_send .. "s"
			end
		--30 minutes will show up as 0 due to the modulus,
		--and we need to avoid saying 30 minutes at the start of the game
		elseif ticks_passed > 0 then
			message_to_send = message_to_send .. sep .. "30_minutes"
		end
	-- this else is because this should not be ran on the top of a minute
	else
		if count_down_seconds > 0 and count_down_seconds <= 10 then
			message_to_send = message_to_send .. sep .. count_down_seconds
		elseif seconds_left == 30 then
			message_to_send = message_to_send .. sep .. "30_seconds_left"
		elseif seconds_left == 20 then
			message_to_send = message_to_send .. sep .. "20(twenny)_seconds"
		elseif seconds_left <= 10 then
			message_to_send = message_to_send .. sep .. seconds_left
		end
	end
			
	-- if the message is just "|n:timer" there is no data in it, so only send when we have data
	if message_to_send ~= "|n"..sep.."timer" then
		for i=1,16 do
			rprint(i, message_to_send)
		end
	end
end

function OnScreenTimerUpdate(minutes, seconds)
	for i=1,16 do
		ClearPlayerConsole(i)
		if tens_flash_in_a_different_color then
			--rprint(i, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds) .. "|ncin_tit")
			if seconds == 0 then
			CutsceneTitlePrint(i, 2+seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0, 0.25, 0.5, 200, 255, 0, 0)
			CutsceneTitlePrint(i, seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0.75, 1, 1, 160, 117, 186, 255)
			
			elseif seconds == 30 then
			CutsceneTitlePrint(i, 2+seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0, 0.25, 0.5, 200, 0, 255, 0)
			CutsceneTitlePrint(i, seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0.75, 1, 1, 160, 117, 186, 255)
			
			elseif seconds % 10 == 0 then
			CutsceneTitlePrint(i, 2+seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0, 0.25, 0.5, 200, 255, 255, 255)
			CutsceneTitlePrint(i, seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0.75, 1, 1, 160, 117, 186, 255)
			
			else
			CutsceneTitlePrint(i, seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0, 1, 1, 160, 117, 186, 255)
			end
		else
			CutsceneTitlePrint(i, seconds % 2, "|r" .. string.format("%02d", minutes) .. ":" .. string.format("%02d", seconds), -1, -40, 0, 1, 1, 160, 117, 186, 255)
		end
		CutsceneTitleDelete(i, (seconds+1) % 2)
	end
end

function CutsceneTitlePrint(player_id, slot, text, 
                            cutscene_title_x, cutscene_title_y,
                            fade_in_time, staying_time, fade_out_time, 
                            alpha, red, green, blue)
	
	if string.len(text) > 40 then
		text = string.sub(text, 1, 40)
	end
	
	slot = CheckValueBounds(math.floor(slot), 0, 31)
	
	cutscene_title_x = CheckValueBounds(math.floor(cutscene_title_x), -2047, 2047)
	if cutscene_title_x < 0 then
		cutscene_title_x = cutscene_title_x + 0xFFF
	end
	cutscene_title_y = CheckValueBounds(math.floor(cutscene_title_y), -2047, 2047)
	if cutscene_title_y < 0 then
		cutscene_title_y = cutscene_title_y + 0xFFF
	end
	
	fade_in_time = CheckValueBounds(math.floor(fade_in_time*30), 0, 0xFFF)
	staying_time = CheckValueBounds(math.floor(staying_time*30), 0, 0xFFF)
	fade_out_time = CheckValueBounds(math.floor(fade_out_time*30), 0, 0xFFF)
	
	red = CheckValueBounds(math.floor(red), 0, 0xFF)
	green = CheckValueBounds(math.floor(green), 0, 0xFF)
	blue = CheckValueBounds(math.floor(blue), 0, 0xFF)
	
	local text = text .. "|n"..sep.."cin_tit"
	text = text ..sep.. string.format("%02X", slot) 
	text = text .. string.format("%03X", cutscene_title_x) .. string.format("%03X", cutscene_title_y)
	text = text .. string.format("%03X", fade_in_time) .. string.format("%03X", staying_time) .. string.format("%03X", fade_out_time)
	text = text .. string.format("%02X", alpha) .. string.format("%02X", red) .. string.format("%02X", green) .. string.format("%02X", blue)
	
	rprint(player_id, text)
end

function CutsceneTitleDelete(player_id, slot)
	rprint(player_id, "|n" ..sep.. "cin_tit" ..sep.. "del" ..sep.. string.format("%02X", slot))
end

function GetScenarioData()
	local scenario_ptr = read_dword(0x40440028+0x14)
	local cutscene_flags_reflexive_offset = 1252
	local cutscene_flag_count = read_dword(scenario_ptr+cutscene_flags_reflexive_offset)
	local cutscene_flag_ptr = read_dword(scenario_ptr+cutscene_flags_reflexive_offset+4)
	
	cutscene_flags = {}
	for i=0,cutscene_flag_count-1 do
		local this_name = read_string(cutscene_flag_ptr+i*92+4)
		local pos_x, pos_y, pos_z  = read_vector3d(cutscene_flag_ptr+i*92+36)
		local this_entry = {name=this_entry, x=pos_x, y=pos_y, z=pos_z}
		table.insert(cutscene_flags, this_entry)
	end
	
	local netgame_equipment_reflexive_offset = 900
	local equipment_count = read_dword(scenario_ptr+netgame_equipment_reflexive_offset)
	local equipment_ptr = read_dword(scenario_ptr+netgame_equipment_reflexive_offset+4)
	
	local ctf_enabled    = {1}
	local slayer_enabled = {2, 12, 13, 14}
	local ball_enabled   = {3, 12, 13, 14}
	local king_enabled   = {4, 12, 13, 14}
	
	netgame_equipment = {}
	
	for i=0,equipment_count-1 do
		local ctf    = false
		local slayer = false
		local ball   = false
		local king   = false
		local spawn_time = read_word(equipment_ptr+i*144+14)
		local pos_x, pos_y, pos_z = read_vector3d(equipment_ptr+i*144+64)
		local equip_type = 0
		for j=0,3 do
			for k, v in pairs(ctf_enabled) do
				if ctf_enabled[k] == read_word(equipment_ptr+i*144+j*2+4) then
					ctf = true
					break
				end
			end
			for k, v in pairs(slayer_enabled) do
				if slayer_enabled[k] == read_word(equipment_ptr+i*144+j*2+4) then
					slayer = true
					break
				end
			end
			for k, v in pairs(ball_enabled) do
				if ball_enabled[k] == read_word(equipment_ptr+i*144+j*2+4) then
					ball = true
					break
				end
			end
			for k, v in pairs(king_enabled) do
				if king_enabled[k] == read_word(equipment_ptr+i*144+j*2+4) then
					king = true
					break
				end
			end
		end
		local tag_path = read_string(read_dword(equipment_ptr+i*144+80+4))
		if spawn_time == 0 then
			spawn_time = read_word(read_dword(lookup_tag(read_dword(equipment_ptr+i*144+80+12))+0x14)+12)
			if spawn_time == 0 then
				spawn_time = 30
			end
		end
		if ends_with(tag_path, "rocket launcher") then
			equip_type = ROCKET_LAUNCHER
		elseif ends_with(tag_path, "sniper rifle") then
			equip_type = SNIPER_RIFLE
		elseif ends_with(tag_path, "powerup super shield") then
			equip_type = OVERSHIELD
		elseif ends_with(tag_path, "powerup invisibility") then
			equip_type = CAMO
		elseif ends_with(tag_path, "shield-invisibility") then
			equip_type = SHIELD_CAMO
		end
		
		local this_entry = {}
		this_entry.gt_ctf=ctf
		this_entry.gt_slayer=slayer
		this_entry.gt_ball=ball
		this_entry.gt_king=king
		this_entry.respawn_time=spawn_time
		this_entry.x=pos_x
		this_entry.y=pos_y
		this_entry.z=pos_z
		this_entry.equipment_type=equip_type
		
		table.insert(netgame_equipment, this_entry)
	end
end

navpoint_queue = {}

function NextNavpointQueueItem()
	if navpoint_queue[1] ~= nil then
		for i=1,16 do
			rprint(i, navpoint_queue[1])
		end
		table.remove(navpoint_queue, 1)
	end
end

function WeaponAnnounce(time_passed)
	if time_passed % 10 == 0 then
		for i=1,16 do
			rprint(i, "|n"..sep.."nav"..sep.."del"..sep.."rocket_flag"..sep..(i-1))
			rprint(i, "|n"..sep.."nav"..sep.."del"..sep.."sniper_flag"..sep..(i-1))
			rprint(i, "|n"..sep.."nav"..sep.."del"..sep.."camo_flag"..sep..(i-1))
			rprint(i, "|n"..sep.."nav"..sep.."del"..sep.."overshield_flag"..sep..(i-1))
		end
	end

	local message_to_send = "|n"..sep.."timer"
	
	local rockets = 0
	local sniper = 0
	local ovie = 0
	local camo = 0
	local combo = 0
	
	seceridos = 0
	
	ne = netgame_equipment
	for k,v in pairs(ne) do
		if ne[k].gt_slayer == true and game_type == "slayer"
		or (ne[k].gt_ctf  == true and gametype == "ctf")
		or (ne[k].gt_king == true and gametype == "king")
		or (ne[k].gt_ball == true and gametype == "oddball") then
			resp_time = ne[k].respawn_time
			time_till_resp = resp_time - (time_passed % resp_time)
			if time_till_resp == 10 then
				if time_passed % 60 == 50 then
					if ne[k].equipment_type == ROCKET_LAUNCHER then
						if enable_rocket_announcement == true then
							rockets = rockets + 1
						end
					end
					if ne[k].equipment_type == SNIPER_RIFLE then
						if enable_sniper_announcement == true then
							sniper = sniper + 1
						end
					end
					if ne[k].equipment_type == OVERSHIELD then
						if enable_os_announcement == true then
							ovie = ovie + 1
						end
					end
					if ne[k].equipment_type == SHIELD_CAMO then
						if enable_os_announcement == true then
							combo = combo + 1
						end
					end
					if ne[k].equipment_type == CAMO then
						if enable_camo_announcement == true then
							camo = camo + 1
						end
					end
				end
			end
			if time_till_resp == 5 then
				if time_passed % 60 ~= 55 then
					if ne[k].equipment_type == ROCKET_LAUNCHER then
						if enable_rocket_announcement == true then
							if (resp_time % 0 ~= 0) then
								rockets = rockets + 1
							end
							count_down_seconds = 5
						end
					end
					if ne[k].equipment_type == SNIPER_RIFLE then
						if enable_sniper_announcement == true then
							if (resp_time % 0 ~= 0) then
								sniper = sniper + 1
							end
							count_down_seconds = 5
						end
					end
					if ne[k].equipment_type == OVERSHIELD then
						if enable_os_announcement == true then
							if (resp_time % 0 ~= 0) then
								ovie = ovie + 1
							end
							count_down_seconds = 5
						end
					end
					if ne[k].equipment_type == CAMO then
						if enable_camo_announcement == true then
							if (resp_time % 0 ~= 0) then
								camo = camo + 1
							end
							count_down_seconds = 5
						end
					end
					if ne[k].equipment_type == SHIELD_CAMO then
						if enable_camo_announcement == true then
							if (resp_time % 0 ~= 0) then
								combo = combo + 1
							end
							count_down_seconds = 5
						end
					end
				end
			end
		end
	end
	-- I don't think I really understand lua
	for i=0,rockets-1 do
		message_to_send = message_to_send ..sep.. "rocket"
		seceridos = seceridos + 1
	end
	for i=0,camo-1 do
		message_to_send = message_to_send ..sep.. "camo"
		seceridos = seceridos + 1
	end
	for i=0,(ovie+combo-1) do
		message_to_send = message_to_send ..sep.. "overshield"
		seceridos = seceridos + 1
	end
	for i=0,sniper-1 do
		message_to_send = message_to_send ..sep.. "sniper"
		seceridos = seceridos + 1
	end

	
	local flag_delay = 1
	
	if training_mode and game_type == "slayer" then
		for i=0,rockets-1 do
			if i==0 then
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."rocket"..sep.."rocket_flag"..sep..(i-1))
			else
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."rocket"..sep.."rocket_flag"..(i+1)..sep..(i-1))
			end
		end
		for i=0,camo-1 do
			if i==0 then
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."camo"..sep.."camo_flag"..sep..(i-1))
			else
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."camo"..sep.."camo_flag"..(i+1)..sep..(i-1))
			end
		end
		for i=0,(ovie+combo-1) do
			if i==0 then
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."overshield"..sep.."overshield_flag"..sep..(i-1))
			else
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."overshield"..sep.."overshield_flag"..(i+1)..sep..(i-1))
			end
		end
		for i=0,sniper-1 do
			if i==0 then
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."sniper"..sep.."sniper_flag"..sep..(i-1))
			else
				table.insert(navpoint_queue, "|n"..sep.."nav"..sep.."sniper"..sep.."sniper_flag"..(i+1)..sep..(i-1))
			end
		end	
	end
	
	if sound_blocked_secs < seceridos then
		sound_blocked_secs = seceridos
	end
	
	if message_to_send ~= "|n"..sep.."timer" then
		for i=1,16 do
			rprint(i, message_to_send)
		end
	end
end

function CheckValueBounds(value, low_bound, high_bound)
	if value ~= nil then
		if value > high_bound then
			return high_bound
		elseif value < low_bound then
			return low_bound
		else
			return value
		end
	else
		return low_bound
	end
end

function ClearPlayerConsole(id)
	for j=1,24 do
		rprint(id, "|ndelete")
	end
end

function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end