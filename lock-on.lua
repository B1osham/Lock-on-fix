--Lock-On Combat with Dodge for Dragons Dogma 2
--Battle enemies in Dragons Dogma 2 with lock on with Dodge. Requires REFramework
--By alphaZomega
local version = "1.13a" --May 27, 2024

-- Support for Skill Maker (lock on target now accessible to other scripts as global variable 'lock_on_target')

local default_lss = {
	enabled = true,
	aim_cam_offset = {0,0,0},
	auto_tilt_damping_rate = 0.94,
	cam_distance = 1.0,
	cam_fov = 1.0,
	cam_look_dn_data = {1, 1},
	cam_look_up_data = {1, 1},
	cam_offset = {0,0,0},
	damping_rate = 0.01,
	disable_cam_reset = false,
	dodge_idx = 1,
	dodge_stam_cost = 50.0,
	do_air_dash = true,
	do_auto_tilt = true,
	do_autotilt_side = false,
	do_cinematic_parry = true,
	do_drift_cam = true,
	do_drift_cam_lockon = true,
	do_epic_parry = true,
	do_face_enemy = true,
	do_hide_dot = false,
	do_mod_camera = false,
	do_mod_camera_offset = false,
	do_no_lockon_camera = false,
	do_lower_cam_during_dodge = false,
	do_perfect_dodge = true,
	do_slide_dodge = true,
	do_vertical_lockon_damp = true,
	do_no_soft_lock = false,
	dodge_esc_threshold = 50.0,
	dodge_cancel_threshold = 15.0,
	dodge_only_unsheathed = true,
	dodge_single_press = false,
	drift_cam_invert = true,
	drift_limit = 1.30,
	drift_speed = 0.25,
	drift_cam_freeze = false,
	drift_hotkeys_lockon_only = true,
	god_mode = false,
	god_mode_invinc = false,
	head_bob_damping_rate = 0.6,
	perf_dodge_stamina_reward = 300.0,
	do_enemy_lifebars = true,
	sliding_dodge_min_speed = 5.0,
	do_wallhack_lifebars = false,
	hotkeys = {
		["Lock On"] = "RStickPush",
		["Lock On (Hold)"] = "[Not Bound]",
		["Change Target L"] = "EmuRleft",
		["Change Target R"] = "EmuRright",
		["Drift Cam L"] = "EmuRleft",
		["Drift Cam L_$"] = "LB (L1)",
		["Drift Cam R"] = "EmuRright",
		["Drift Cam R_$"] = "LB (L1)",
		["Change Joint Up"] = "EmuRup",
		["Change Joint Dn"] = "EmuRdown",
		["Dodge"] = "B (Circle)",
		["Inhibit Dodge 1"] = "LB (L1)",
		["Inhibit Dodge 2"] = "[Not Bound]",
		["Tilt Lockon Up"] = "LUp",
		["Tilt Lockon Down"] = "LDown",
		["Tilt Lockon Left"] = "LLeft",
		["Tilt Lockon Right"] = "LRight",
	},
}

local hk = require("Hotkeys/Hotkeys")

local lss = hk.recurse_def_settings(json.load_file("LockOn.json") or {}, default_lss)

hk.setup_hotkeys(lss.hotkeys, default_lss.hotkeys)

local cam_data = {}
local player_rcol_shapes = {}
local lifebar_enemies = {}
local char_input
local loco
local is_paused = false
local is_running = false
local is_epic_parry = false
local is_aiming = false
local is_sliding = false
local changed, was_changed = false, true
local pl_hip_pos
local cam_ctrl
local target
local cam_matrix
local lookat_mat
local camera
local player
local mfsm2
local chara
local prev_node_name = ""
local node_name = ""
local anim_name = ""
local pl_pos
local pl_cam_settings
local motion
local mlayer
local deltatime
local timescale_mult
local l_mag
local cam_base_offset = Vector3f.new(0, 1.501, -0.043)
local dodge_types = {
	"Thief Dodge",
	"Hindsight Roll",
}
local dodge_names = {
	"Job04.Job04_NormalAttack.Job04_Dodge",
	"Job01.Job01_SkillAttack.Job01_CS08.Job01_HindsightSlashStart",
}
local dodge_name = dodge_names[lss.dodge_idx]


local time_mgr = sdk.get_managed_singleton("app.TimeManager")
local cam_mgr = sdk.get_managed_singleton("app.CameraManager")
local chr_mgr = sdk.get_managed_singleton("app.CharacterManager")
local em_mgr = sdk.get_managed_singleton("app.EnemyManager")
local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
local lookat_method = sdk.find_type_definition("via.matrix"):get_method("makeLookAtRH")
local set_node_method = sdk.find_type_definition("via.motion.MotionFsm2Layer"):get_method("setCurrentNode(System.String, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)")
local rotate_yaw_method = sdk.find_type_definition("via.MathEx"):get_method("rotateYaw(via.vec3, System.Single)")
local og_cam_reset_button

local via_physics_system = sdk.get_native_singleton("via.physics.System")
local contact_pt_td = sdk.find_type_definition("via.physics.ContactPoint")
local ray_result = sdk.create_instance("via.physics.CastRayResult"):add_ref()
local ray_method = sdk.find_type_definition("via.physics.System"):get_method("castRay(via.physics.CastRayQuery, via.physics.CastRayResult)")
local ray_query = sdk.create_instance("via.physics.CastRayQuery"):add_ref()
ray_query:clearOptions()
ray_query:enableAllHits()
ray_query:enableNearSort()
local filter_info = ray_query:get_FilterInfo()
filter_info:set_Group(0)
local shape_cast_result = sdk.create_instance("via.physics.ShapeCastResult"):add_ref()
local shape_ray_method = sdk.find_type_definition("via.physics.System"):get_method("castSphere(via.Sphere, via.vec3, via.vec3, System.UInt32, via.physics.FilterInfo, via.physics.ShapeCastResult)")
local shape_ray_method2 = sdk.find_type_definition("via.physics.System"):get_method("castShape(via.physics.ShapeCastQuery, via.physics.ShapeCastResult)")
local shape_cast_result = sdk.create_instance("via.physics.ShapeCastResult"):add_ref()
local sphere = ValueType.new(sdk.find_type_definition("via.Sphere"))
local box = ValueType.new(sdk.find_type_definition("via.physics.BoxShape"))
box:set_UserData(sdk.create_instance("via.physics.UserData"):add_ref())
local shape_cast_query = sdk.create_instance("via.physics.ShapeCastQuery"):add_ref()
shape_cast_query:set_Shape(box)
shape_cast_query:set_FilterInfo(filter_info)

local interper = sdk.create_instance("via.motion.SetMotionTransitionInfo"):add_ref()
local setn = ValueType.new(sdk.find_type_definition("via.behaviortree.SetNodeInfo"))
interper:set_InterpolationFrame(12.0)
setn:call("set_Fullname", true)

local temp = { --misc data
	fns={},
	add_pitch_amt = 0,
	add_yaw_amt = 0,
	og_cam_tracking = cam_mgr._AutoBehind,
	og_cam_terrain_correct = cam_mgr._TerrainCorrection,
	last_sel_joint_name = "Spine_1",
	last_slide_time = 0,
	add_aim_x = 0,
}

local dr = { --drift cam data
	left_time = os.clock(),
	right_time = os.clock(),
	slider_t = 0.5,
	last_slider_t = 0.5,
	slider_amt = 0.0,
}

local damp = {
	float01 = sdk.create_instance("app.DampingFloat"):add_ref(),
	float02 = sdk.create_instance("app.DampingFloat"):add_ref(),
	float03 = sdk.create_instance("app.DampingFloat"):add_ref(),
	float04 = sdk.create_instance("app.DampingFloat"):add_ref(),
	quat01 = sdk.create_instance("app.DampingQuaternion"):add_ref(),
	vec3_01 = sdk.create_instance("app.DampingVec3"):add_ref(),
}

for name, damp_obj in pairs(damp) do
	damp_obj["<Immediate>k__BackingField"] = true
	damp_obj._DampingRate = 0.3
	damp_obj._DampingTime = 180.0
end
damp.float03["<Exp>k__BackingField"] = 0.95
damp.float04["<Exp>k__BackingField"] = 0.8
damp.vec3_01["<Exp>k__BackingField"] = 0.95


local function cast_ray(start_position, end_position, layer, maskbits, shape_radius, options, do_reverse)
	local result = {}
	local result_obj = shape_radius and shape_cast_result or ray_result
	filter_info:set_Layer(layer)
	filter_info:set_MaskBits(maskbits)
	result_obj:clear()
	if shape_radius then
		sphere:set_Radius(shape_radius)
		shape_ray_method:call(nil, sphere, start_position, end_position, options or 1, filter_info, result_obj)
	else
		ray_query:call("setRay(via.vec3, via.vec3)", start_position, end_position)
		ray_method:call(via_physics_system, ray_query, result_obj)
	end
	local num_contact_pts = result_obj:get_NumContactPoints()
	if num_contact_pts > 0 then
		for i=1, num_contact_pts do
			local new_contactpoint = result_obj:call("getContactPoint(System.UInt32)", i-1)
			local new_collidable = result_obj:call("getContactCollidable(System.UInt32)", i-1)
			local contact_pos = sdk.get_native_field(new_contactpoint, contact_pt_td, "Position")
			local game_object = new_collidable:call("get_GameObject")
			if do_reverse then
				table.insert(result, 1, {game_object, contact_pos})
			else
				table.insert(result, {game_object, contact_pos})
			end
		end
	end
	return result
end

local function is_obscured(position, start_mat, ray_layer, ray_maskbits, leeway)
	start_mat = start_mat or cam_matrix
	local ray_results = cast_ray(start_mat[3], position, ray_layer or 2, ray_maskbits or 0)
	return ray_results[1] and (start_mat[3] - ray_results[1][2]):length() + (leeway or 0.25) < (start_mat[3] - position):length()
end

local function get_onscreen_pos(world_coords, size_multip_x, size_multip_y)
	local disp_sz = imgui.get_display_size()
	local multip_amt = Vector2f.new((size_multip_x or 0) * disp_sz.x, (size_multip_y or 0) * disp_sz.y)
	local pos_2d = draw.world_to_screen(world_coords)
	return pos_2d and (pos_2d.x >= 0 - multip_amt.x) and (pos_2d.y >= 0 - multip_amt.y) and (pos_2d.x <= disp_sz.x + multip_amt.x) and (pos_2d.y <= disp_sz.y + multip_amt.y) and pos_2d
end

local function normalize_single(x, x_min, x_max, r_min, r_max)
	return (r_max - r_min) * ((x - x_min) / (x_max - x_min)) + r_min
end

local function lookat_target(pos)
	local pl_lookat_quat = (lookat_method:call(nil, pl_hip_pos, pos, Vector3f.new(0,1,0)):inverse():to_quat())
	damp.float03._Source = damp.float03._Current
	damp.float03._Target = (pl_lookat_quat:to_euler().y + math.pi) * 57.2958
	damp.float03:updateParam()
	chara["<TargetAngleCtrl>k__BackingField"].Front["<AngleDeg>k__BackingField"] = damp.float03._Current
end

local function getC(gameobj, component_name)
	return gameobj:call("getComponent(System.Type)", sdk.typeof(component_name))
end

local function tooltip(text)
    if imgui.is_item_hovered() then imgui.set_tooltip(text) end
end

local function set_wc(name)
	was_changed = was_changed or changed
	if name and imgui.begin_popup_context_item(name) then  
		if imgui.menu_item("Reset Value") then
			lss[name] = default_lss[name]
			was_changed = true
		end
		imgui.end_popup() 
	end
end

local function write_valuetype(parent_obj, offset_or_field_name, value)
    local offset = tonumber(offset_or_field_name) or parent_obj:get_type_definition():get_field(offset_or_field_name):get_offset_from_base()
    for i=0, value.type:get_valuetype_size()-1 do
        parent_obj:write_byte(offset+i, value:read_byte(i))
    end
end

local function imgui_table_vec(func, name, value, args)
    changed, value = func(name, _G["Vector"..#value.."f"].new(table.unpack(value)), table.unpack(args or {}))
    value = {value.x, value.y, value.z, value.w} --convert back to table
    return changed, value
end  

local function reset_camera_mods(do_force)
	if cam_ctrl and pl_cam_settings and (lss.do_mod_camera or do_force) then 
		pl_cam_settings:call(".ctor")
		if lss.do_mod_camera_offset then
			cam_ctrl["<MainCameraController>k__BackingField"]["<BaseOffset>k__BackingField"] = cam_base_offset --cam_data.BaseOffset
		end
	end
end

local function make_dampen_rot_fn(time_limit)
	temp.fns.dampen_rotation_fn = function()
		temp.fns.dampen_rotation_fn = (os.clock() - temp.last_action_time < time_limit) and temp.fns.dampen_rotation_fn or nil
		if temp.fns.dampen_rotation_fn then
			local new_quat = temp.prev_quat:slerp(pl_xform:get_Rotation(), 0.33)
			pl_xform:set_Rotation(new_quat)
		end
	end
end

local Enemy = {
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		setmetatable(o, self)
		o.gameobj = 		args.gameobj
		o.xform = 			args.xform or o.gameobj:get_Transform()
		o.lockon = 			args.lockon or getC(o.gameobj, "app.LockOnTarget")
		o.hp = 				args.hp or getC(result[1], "app.HitController")
		o.chara = 			args.chara or getC(o.gameobj, "app.Character")
		o.obscured_time =	os.clock()
		o.main_joints = 	args.main_joints or {
			R_Leg_Ankle = o.xform:getJointByName("R_Leg_Ankle"),
			L_Leg_Ankle = o.xform:getJointByName("L_Leg_Ankle"),
			Hip = o.xform:getJointByName("Hip"),
			Spine_1 = o.xform:getJointByName("Spine_1"),
			Spine_2 = o.xform:getJointByName("Spine_2"),
			Head_0 = o.xform:getJointByName("Head_0"),
		}
		o.lockon_works = 	args.lockon_works or o.lockon["<Works>k__BackingField"]
		o.lockon_joint = 	args.lockon_joint or o.main_joints[temp.last_sel_joint_name] or o.lockon_works[0].LockOnJoint
		for i, joint in pairs(o.lockon_works._items) do
			if joint then 
				o.main_joints[joint.LockOnJoint:get_Name()] = joint.LockOnJoint
				if joint.LockOnJoint:get_Name() == temp.last_sel_joint_name then 
					o.lockon_joint = joint.LockOnJoint
				end
			end
		end
		o.lock_pos = 		o.lockon_joint:get_Position()
		o.ray_pos = 		args.ray_pos or o.lock_pos
		
		temp.last_sel_joint_name = o.lockon_joint:get_Name()
		damp.float04._Current = o.lock_pos.y
		
		return o
	end,
	update = function(self)
		self.lock_pos = self.lockon_joint:get_Position()
		if lss.do_vertical_lockon_damp then
			damp.float04._Source = damp.float04._Current
			damp.float04._Target = self.lock_pos.y
			damp.float04:updateParam()
			self.lock_pos.y = damp.float04._Current
		end
		self.obscured_time = not is_paused and is_obscured(self.lock_pos) and self.obscured_time or os.clock()
		self.dist_to_pl = (self.lock_pos - pl_hip_pos):length()
	end,
}

re.on_application_entry("UpdateBehavior", function()
	--Handle lifebars
	if lss.do_enemy_lifebars then
		local temp_enemies = {}
		for i, enemy in pairs(em_mgr._EnemyList._items) do
			if enemy then 
				local em_chr = enemy["<Chara>k__BackingField"]
				if em_chr then
				local tbl = lifebar_enemies[em_chr] or {enemy=enemy, last_gauge_time=0, hit=em_chr["<Hit>k__BackingField"], health=em_chr["<Hit>k__BackingField"]:get_Hp(), last_vis_time=0}
				temp_enemies[em_chr] = tbl
				local hp = tbl.hit:get_Hp()
				if hp ~= tbl.health then
					tbl.health = hp
					tbl.last_gauge_time = os.clock()
				end
				if tbl.health > 0 and ((target and target.chara == em_chr) or os.clock() - tbl.last_gauge_time < 10.0) then
					local xform = em_chr["<Transform>k__BackingField"]
					local lockon_joint = xform:getJointByName("Hip") or xform:getJointByName("root")
					local is_vis_time = lss.do_wallhack_lifebars or (lockon_joint and not is_obscured(lockon_joint:get_Position()))
					if is_vis_time or (os.clock() - tbl.last_vis_time < 3.0) then
						tbl.last_vis_time = is_vis_time and os.clock() or tbl.last_vis_time
						local ui_xform = enemy:get_GameObject():get_Transform():find("ui020601")
						if ui_xform then 
							tbl.ui = getC(ui_xform:get_GameObject(), "app.ui020601")
							tbl.ui.IsReqDisp = true
							tbl.ui:set_UpdateSelf(true)
							tbl.last_req = os.clock()
						end
					end
				end
				end
			end
		end
		lifebar_enemies = temp_enemies
	end
end)

re.on_application_entry("LateUpdateBehavior", function()
	
	math.randomseed(math.floor(os.clock()*100))
	
	_G.lock_on_target = target
	local mc_ctrl = cam_mgr._MainCameraControllers[0]
	cam_ctrl = mc_ctrl and mc_ctrl._CurrentCameraController
	camera = sdk.get_primary_camera()
	local cam_xform = camera and camera:get_GameObject():get_Transform()
	cam_joint = camera and cam_xform:get_Joints()[0]
	temp.prev_cam_matrix = cam_matrix
	cam_matrix = cam_joint and cam_joint:get_WorldMatrix()
	chara = chr_mgr:get_ManualPlayer()
	player = chara and chara:get_Valid() and chara:get_GameObject()
	target = target and temp.toggled and target.gameobj:get_Valid() and (os.clock() - target.obscured_time) < 3.0 and target
	if target then target:update() end
	local was_toggled = temp.toggled
	temp.toggled = target and temp.toggled
	
	deltatime = scene:get_FirstTransform():get_DeltaTime()
	timescale_mult = 1 / sdk.call_native_func(sdk.get_native_singleton("via.Application"), sdk.find_type_definition("via.Application"), "get_GlobalSpeed")
	
	--Delayed functions
	for i, fn in pairs(temp.fns) do
		fn()
	end
	
	if not is_paused and lss.enabled and player and cam_matrix and cam_ctrl then
		
		pl_xform = player:get_Transform()
		mfsm2 = getC(player, "via.motion.MotionFsm2")
		char_input = chara:get_Input()
		prev_node_name = node_name
		node_name = mfsm2:getCurrentNodeName(0)
		local tree = mfsm2:getLayer(0):get_tree_object()
		loco = tree:get_node_by_name("NormalLocomotion"):get_actions()[1]
		is_running = true
		is_strafing = not not node_name:find("Strafe")
		is_aiming = (cam_ctrl.setupAim ~= nil)
		is_sliding = temp.is_dodging and (node_name == "Job02.Job02_NormalAttack.Job02_SlidingAttack")
		motion = getC(player, "via.motion.Motion")
		mlayer = motion:getLayer(0)
		local mnode = mlayer:get_HighestWeightMotionNode()
		anim_name = mnode and mnode:get_MotionName()
		
		local last_pl_pos = pl_pos
		pl_pos = pl_xform:get_Position()
		pl_hip_pos = pl_xform:getJointByName("Hip"):get_Position()
		temp.last_action_time = (prev_node_name ~= node_name) and os.clock() or temp.last_action_time or 0
		l_mag = char_input["<AxisMagnitudeL>k__BackingField"]
		
		if not player_rcol_shapes[1] then
			local pl_rcol = getC(player, "via.physics.RequestSetCollider")
			for j=1, pl_rcol:call("getNumCollidables(System.UInt32)", 0) do
				local col = pl_rcol:call("getCollidableFromIndex(System.UInt32, System.UInt32)", 0, j-1)
				player_rcol_shapes[j] = {col=col, shape=col:get_Shape(), x_shape=col:get_TransformedShape(), og_radius=col:get_Shape():get_Radius()}
			end
		end
		
		for i, id in ipairs({4, 5, 10, 8}) do  --the game's own drift and other cam submodules
			local modulars = cam_ctrl["<Modulars>k__BackingField"]
			if modulars:ContainsKey(id) and modulars[id] then
				modulars[id]._Param._Enabled = not (lss.do_drift_cam or target)
			end
		end
		
		local pitch_module = lss.do_mod_camera and cam_ctrl["<Modulars>k__BackingField"]:ContainsKey(6) and cam_ctrl["<Modulars>k__BackingField"][6]
		if pitch_module then
			pitch_module._Param._LookUp._DistanceOffset = 	-4.5 * lss.cam_look_up_data[1]
			pitch_module._Param._LookDown._DistanceOffset = -1.0 * lss.cam_look_dn_data[1]
			pitch_module._Param._LookUp._PogOffset =	  	Vector3f.new(0, -0.1 * lss.cam_look_up_data[2],  0.8)
			pitch_module._Param._LookDown._PogOffset = 		Vector3f.new(0, -0.3 * lss.cam_look_dn_data[2], -1.0)
		end
		
		--Enable/disable cam reset:
		if (char_input and lss.enabled) and was_changed then
			og_cam_reset_button = og_cam_reset_button or char_input.PadAssign.AssignList[18].Button
			char_input.PadAssign.AssignList[18].Button = (lss.enabled and lss.disable_cam_reset) and 0 or og_cam_reset_button
		end
		
		--Handle god mode:
		if lss.god_mode then
			--chara:get_StaminaManager():recoverAll()
			local pawn = sdk.get_managed_singleton("app.PawnManager"):call("get_MainPawn()")
			for i, hc in ipairs({getC(player, "app.HitController"), pawn and getC(pawn["<CachedGameObject>k__BackingField"], "app.HitController")}) do
				hc["<IsNoDie>k__BackingField"] = true
				--hc["<IsDamageZero>k__BackingField"] = true
				--hc["<IsAttackNoDie>k__BackingField"] = true
				hc["<IsInvincible>k__BackingField"] = lss.god_mode_invinc
			end
		end
		
		--Handle lock-on toggle:
		if hk.check_hotkey("Lock On") or (hk.check_hotkey("Lock On (Hold)", 1) and not temp.toggled) and cam_ctrl then
			temp.toggled = not temp.toggled
			
			if temp.toggled then
				target = nil
				temp.is_held_lockon = hk.check_hotkey("Lock On (Hold)", 1) 
				local beam_sz = 5.0
				local beam_dist = 60
				local results = cast_ray(cam_matrix[3] + cam_matrix[2] * -(beam_sz), cam_matrix[3] + cam_matrix[2] * -beam_dist, 3, 1, beam_sz)
				local enemy_dict = {}
				for i, enemy in pairs(em_mgr._EnemyList._items) do
					if enemy then enemy_dict[enemy:get_GameObject()] = true end
				end
				for i, result in ipairs(results) do
					local hp = (enemy_dict[result[1] ]) and getC(result[1], "app.HitController")
					if result[1] ~= player and hp and hp:get_Hp() > 0 and not is_obscured(result[2]) then
						target = Enemy:new{gameobj=result[1], ray_pos=result[2], hp=hp}
						target:update()
						break
					end
				end
				temp.toggled = target and temp.toggled
				
				--Set up a constant function that runs while locked-on:
				if target then
					
					temp.add_aim_x = 0
					lookat_mat = lookat_method:call(nil, cam_ctrl._Position, target.lockon_joint:get_Position(), Vector3f.new(0,1,0))--:inverse()
					damp.float01["<Exp>k__BackingField"] = lss.auto_tilt_damping_rate
					temp.add_pitch_amt, temp.add_yaw_amt = 0, 0
					
					lock_on_fn = function()
						lock_on_fn = player and temp.toggled and target and lss.enabled and lock_on_fn or nil
						
						if lock_on_fn and not node_name:find("FinishingMove") and target.dist_to_pl and cam_ctrl._Angle then	
							local pos = cam_joint:get_Position()
							lookat_mat = lookat_method:call(nil, pos, target.lock_pos, Vector3f.new(0,1,0))
							damp.quat01._Source = cam_matrix:to_quat()
							
							chara["<AimObject>k__BackingField"] = target.gameobj
							chara["<AimCharacter>k__BackingField"] = target.chara
							
							local aim_pos = chara["<AimTargetUniversalPosition>k__BackingField"]
							aim_pos._HasValue = true
							aim_pos._Value = target.lock_pos
							write_valuetype(chara, "<AimTargetUniversalPosition>k__BackingField", aim_pos)
							
							local aim_pos2 = chara["<AimTargetRootUniversalPosition>k__BackingField"]
							aim_pos2._HasValue = true
							aim_pos2._Value = target.xform:get_Position()
							write_valuetype(chara, "<AimTargetRootUniversalPosition>k__BackingField", aim_pos2)
							
							if not lss.do_no_lockon_camera then
								damp.quat01["<Exp>k__BackingField"] = lss.damping_rate
								damp.quat01._Target = lookat_mat:to_quat()
								damp.quat01:updateParam()
								local eulers = lss.damping_rate > 0 and damp.quat01._Current:conjugate():to_euler() or damp.quat01._Target:conjugate():to_euler()
								
								if (lss.do_auto_tilt or lss.do_autotilt_side or is_aiming) then
									local results = cast_ray(pos, target.lock_pos, 3, 1, 0.33, 0)
									local does_pl_obscure = (results[1] and results[1][1] == player)
									local pos_2d = not does_pl_obscure and draw.world_to_screen(target.lock_pos)
									local temp_name = is_aiming and "add_aim_x" or "add_pitch_amt"
									if is_aiming or lss.do_autotilt_side then
										if does_pl_obscure then
											temp.add_aim_x = temp.add_aim_x + 0.0025 * timescale_mult * deltatime
										elseif (pos_2d and pos_2d.x < imgui.get_display_size().x / 2) then
											temp.add_aim_x = temp.add_aim_x +  -0.0025 * timescale_mult * deltatime
										end
										local limit = target.dist_to_pl < 0.5 and target.dist_to_pl or 1.0
										if temp.add_aim_x > limit then temp.add_aim_x = limit end; if temp.add_aim_x < 0 then temp.add_aim_x = 0 end
									end
									if not is_aiming and lss.do_auto_tilt and math.abs(temp.add_yaw_amt) < 0.05 then
										if does_pl_obscure then
											temp.add_pitch_amt = (temp.add_pitch_amt + -0.0025 * timescale_mult * deltatime)
										elseif (pos_2d and pos_2d.y < imgui.get_display_size().y / 2) then
											temp.add_pitch_amt = (temp.add_pitch_amt +  0.0025 * timescale_mult * deltatime)
										end
									end
									damp.float01._Source = damp.float01._Current
									damp.float01._Target = temp[temp_name]
									damp.float01:updateParam()
									temp[temp_name] = damp.float01._Current
								end
								
								if not is_aiming then
									if hk.check_hotkey("Tilt Lockon Up", true) then 
										temp.add_pitch_amt = (temp.add_pitch_amt + -0.005 * timescale_mult * deltatime)
									elseif hk.check_hotkey("Tilt Lockon Down", true) then
										temp.add_pitch_amt = (temp.add_pitch_amt +  0.005 * timescale_mult * deltatime)
									end
									
									if hk.check_hotkey("Tilt Lockon Left", true) then 
										temp.add_yaw_amt = (temp.add_yaw_amt + -0.005 * timescale_mult * deltatime)
									elseif hk.check_hotkey("Tilt Lockon Right", true) then
										temp.add_yaw_amt = (temp.add_yaw_amt +  0.005 * timescale_mult * deltatime)
									end
								end
								
								local pitch_limit = is_aiming and -0.850 or -0.500
								--current_yaw = damp.quat01._Current:to_euler().y
								--player_yaw = damp.quat01._Source:to_euler().y
								if temp.add_pitch_amt < -0.500 then temp.add_pitch_amt = -0.500 end; if temp.add_pitch_amt > 0.200 then temp.add_pitch_amt = 0.200 end
								if temp.add_yaw_amt < -0.150 then temp.add_yaw_amt = -0.150 end; if temp.add_yaw_amt > 0.150 then temp.add_yaw_amt = 0.150 end
								eulers.x = eulers.x + (is_aiming and 0 or temp.add_pitch_amt); eulers.y = eulers.y + (is_aiming and 0 or temp.add_yaw_amt)
								if eulers.x < pitch_limit then eulers.x = pitch_limit end; if eulers.x >  1.047 then eulers.x =  1.047 end
								--if eulers.y + player_yaw < -0.1 then eulers.y = eulers.y + 0.1 end; if eulers.y + player_yaw > 0.1 then eulers.y = eulers.y + -0.1 end;
								
								cam_ctrl._Angle = eulers
							end
							
							local targets = target.lockon and getC(player, "app.Player")["<LockOnCtrl>k__BackingField"].Targets
							if targets and targets[0] then
								targets[0] = target.lockon["<Works>k__BackingField"][0]
							end
							
							--[[if lss.do_no_lockon_camera and not get_onscreen_pos(target.lock_pos) then
								local em_pos_2d = draw.world_to_screen(target.lock_pos)
								if em_pos_2d then
									damp.quat01["<Exp>k__BackingField"] = 0.95
									damp.quat01._Target = lookat_mat:to_quat():conjugate() --damp.quat01._Source:slerp(lookat_mat:to_quat():conjugate(), 0.05)
									damp.quat01:updateParam()
									cam_ctrl._Angle = damp.quat01._Current:to_euler()
								end
							end]]
						end
					end
				end
			end
		end
		
		if temp.is_held_lockon and not hk.check_hotkey("Lock On (Hold)", true) then
			temp.toggled = false
			temp.is_held_lockon = false
		end
		
		--Handle target switching:
		
		if target then
			
			local is_pressed_full = true --char_input["<AxisMagnitudeL>k__BackingField"] > 0.5
			local changed_l = is_pressed_full and hk.check_hotkey("Change Target L", 1)
			local changed_r = is_pressed_full and hk.check_hotkey("Change Target R", 1)
			local died = (target.hp:get_Hp() == 0)
			
			if changed_l or changed_r or died then
				local old_target = target
				local og_em_2d_pos = get_onscreen_pos(target.lock_pos, 0.66, 1.0)
				local closest = 9999
				
				if og_em_2d_pos then
					
					for i, enemy in pairs(em_mgr._EnemyList._items) do
						local em_gameobj = enemy and enemy:get_GameObject()
						
						if em_gameobj and em_gameobj ~= old_target.gameobj then
							local em_pos = em_gameobj:get_Transform():get_Position()
							local pos_2d = get_onscreen_pos(em_pos, 0.66, 1.0)
							
							if pos_2d and (pl_hip_pos - em_pos):length() < 20.0 and not is_obscured(em_pos) then
								local distance = math.abs(og_em_2d_pos.x - pos_2d.x)
								local hp = getC(em_gameobj, "app.HitController")
								
								if distance < closest and hp:get_Hp() > 0 and (died or (changed_l and (pos_2d.x < og_em_2d_pos.x)) or (changed_r and (pos_2d.x > og_em_2d_pos.x))) then
									target = Enemy:new{gameobj=em_gameobj, hp=hp}
									closest = distance
								end
							end
						end
					end
					if target.hp:get_Hp() == 0 then 
						target = nil 
					elseif target and target ~= old_target then
						target:update()
					end
				end
			end
			
			local j_changed_up = hk.check_hotkey("Change Joint Up")
			local j_changed_dn = hk.check_hotkey("Change Joint Dn")
			
			if j_changed_up or j_changed_dn then
				local screen_pos = draw.world_to_screen(target.lock_pos)
				if screen_pos then
					local dist, closest = 99999
					for i, joint in pairs(target.main_joints) do
						local new_targ_2d = draw.world_to_screen(joint:get_Position())
						local this_dist = (screen_pos - new_targ_2d):length()
						if this_dist < dist and ((j_changed_dn and new_targ_2d.y > screen_pos.y) or (j_changed_up and new_targ_2d.y < screen_pos.y)) then
							dist = this_dist
							target.lockon_joint = joint
							temp.last_sel_joint_name = joint:get_Name()
						end
					end
				end
			end
		end
		
		if temp.setup_face_enemy and (lss.do_face_enemy or lss.do_no_soft_lock) then
			temp.setup_face_enemy()
		end
		
		if temp.setup_perfect_dodge and lss.hotkeys.Dodge ~= "[Not Bound]" then
			temp.setup_perfect_dodge()
		end
		
		--Input dodge:
		local dodge_pressed = hk.check_hotkey("Dodge", 1) and l_mag > 0 and not hk.check_hotkey("Inhibit Dodge 1", true) and not hk.check_hotkey("Inhibit Dodge 2", true) and (not lss.dodge_only_unsheathed or not getC(player, "app.Human"):isSheathedWeaponPlayer())
		temp.dodge_triggered = dodge_pressed and (lss.dodge_single_press or (os.clock() - temp.dodge_timer) < 0.33) and ((lss.dodge_idx == 1 and lss.do_air_dash) or not chara:get_IsJumpCtrlActive())
		temp.dodge_timer = dodge_pressed and os.clock() or temp.dodge_timer or os.clock()
		
		local is_run_loop = false
		if (lss.dodge_single_press and temp.was_dashing) or (not lss.dodge_single_press and not temp.was_dashing and os.clock() - temp.dodge_timer < 0.33) then
			local move_speed = chara["<AnimationController>k__BackingField"].AnimationController.AnimationDict._entries[0].value["<TransMoveLocalVolocity>k__BackingField"]:length()
			is_run_loop = move_speed > lss.sliding_dodge_min_speed
		end

		--Make the player face the enemy:
		if lss.do_face_enemy and target and lock_on_fn and not is_aiming and not chara:get_IsJumpCtrlActive() and not hk.check_hotkey("Lock On (Hold)", true) then
			local is_shield = node_name=="Locomotion.Strafe" or (node_name=="Job01.Job01_Guard" and l_mag < 1.0)
			temp.is_under_target = (Vector3f.new(pl_hip_pos.x, 0, pl_hip_pos.z) - Vector3f.new(target.lock_pos.x, 0, target.lock_pos.z)):length() < 0.5 or nil
			if not temp.is_under_target then
				if node_name == "Locomotion.NormalLocomotion" and not is_running and l_mag > 0 then --and math.abs(pl_xform:get_EulerAngle().y - cam_joint:get_EulerAngle().y) < 1.57
					set_node_method:call(mfsm2:getLayer(0), "Locomotion.Strafe", setn, interper)
					temp.did_set_move = true
				end
				if not is_running and (os.clock() - temp.dodge_timer > 0.33) and (is_shield or node_name:find("Attack") or (node_name == "Locomotion.NormalLocomotion" and ((loco.Routine == 5 or loco.Routine == 0)))) then 
					lookat_target(target.lock_pos)
				end
				if ((not temp.was_dashing and chara["<InputProcessor>k__BackingField"].DashSwitch) or (was_toggled ~= temp.toggled and not temp.toggled and node_name:find("Strafe"))) then --or (l_mag == 0 and is_shield) then
					set_node_method:call(mfsm2:getLayer(0), "Locomotion.NormalLocomotion", setn, interper)
					temp.did_set_move = nil
				end
			end
		end
		
		if temp.did_set_move and (not target or temp.is_under_target) then
			if not is_aiming then 
				set_node_method:call(mfsm2:getLayer(0), "Locomotion.NormalLocomotion", setn, interper)
			end
			temp.did_set_move = nil
		end
		
		--Handle Dodge:
		if temp.dodge_triggered and chara:get_StaminaManager()["<RemainingAmount>k__BackingField"] > 0 and node_name ~= dodge_name and not is_sliding and 
		((node_name:sub(1,4) == "Loco" or chara:get_IsGuard()) or (node_name:find("Damage_Root") and (mlayer:get_Frame() / mlayer:get_EndFrame()) > lss.dodge_esc_threshold * 0.01) 
		or (not temp.is_dodging and node_name:sub(1,3)=="Job" and (mlayer:get_Frame() / mlayer:get_EndFrame()) > lss.dodge_cancel_threshold * 0.01 and (not chara:get_IsJumpCtrlActive() or (lss.dodge_idx == 1 and lss.do_air_dash)))) then
			local real_dodge_name = dodge_name
			local add_amt = math.pi
			
			if is_run_loop and lss.do_slide_dodge and not chara:get_IsJumpCtrlActive() then --sprinting slide
				real_dodge_name = "Job02.Job02_NormalAttack.Job02_SlidingAttack"
				is_sliding = true
				
				temp.fns.ensure_speed_fn = function()
					if not is_sliding then
						temp.fns.ensure_speed_fn = nil
						mlayer:set_Speed(1.0)
					end
				end
			elseif lss.dodge_idx == 2 then --hindsight roll
				local new_dir = cam_joint:get_EulerAngle().y + char_input:get_AngleRadL() + math.pi
				chara["<TargetAngleCtrl>k__BackingField"].Front["<AngleDeg>k__BackingField"] = new_dir * 57.2958
				temp.dodge_dir = {char_input:get_AxisL(), new_dir}
				tree:get_node(294):get_actions()[1]:set_Enabled(false)
				add_amt = 0
			end
			
			local pl_eul = pl_xform:get_EulerAngle()
			pl_xform:set_EulerAngle(Vector3f.new(pl_eul.x, cam_joint:get_EulerAngle().y + char_input:get_AngleRadL() + add_amt, pl_eul.z))
			
			if lss.dodge_stam_cost ~= 0 then
				local stam_mgr = chara:get_StaminaManager()
				stam_mgr["<RemainingAmount>k__BackingField"] = stam_mgr["<RemainingAmount>k__BackingField"] - lss.dodge_stam_cost
			end
			
			set_node_method:call(mfsm2:getLayer(0), real_dodge_name, setn, interper)
			temp.is_dodging = true
			
		elseif temp.is_dodging then
			local frame = motion:getLayer(0):get_Frame()
			local is_dodge = (node_name == dodge_name) or is_sliding
			
			if not is_dodge or (is_sliding and anim_name:find("ch00_002_atk_NA_dash_shoot_turn") and frame > 12) or (not is_sliding and ((lss.dodge_idx == 1 and frame > 35) or (lss.dodge_idx == 2 and frame > 28))) then-- and ) then
				temp.is_dodging = nil
				is_perfect_dodge = false
				
				if is_dodge then 
					set_node_method:call(mfsm2:getLayer(0), "Locomotion.NormalLocomotion", setn, interper) --mfsm2:restartTree()
					
					if is_sliding then
						temp.do_dash_req = true --lock_on_fn and char_input:get_AxisL().y < -0.5
						temp.dodge_dir = nil
						mlayer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)", 0, l_mag > 0 and 206 or 213, 0.0, 20.0, 2, 0)
					end 
					if temp.dodge_dir then
						tree:get_node(294):get_actions()[1]:set_Enabled(true)
						chara["<TargetAngleCtrl>k__BackingField"].Front["<AngleDeg>k__BackingField"] = temp.dodge_dir[2]  * 57.2958
						local pl_eul = pl_xform:get_EulerAngle()
						pl_xform:set_EulerAngle(Vector3f.new(pl_eul.x, temp.dodge_dir[2], pl_eul.z))
						make_dampen_rot_fn(0.2)
						temp.fns.dampen_rotation_fn()
						temp.dodge_dir = nil
					end
				end
			elseif is_sliding then
				temp.last_slide_time = os.clock()
				local frame = mlayer:get_Frame()
				slope_angle = -chara["<SlopeInfo>k__BackingField"]["<SlopeAngleDegForMove>k__BackingField"] * 0.5
				if slope_angle < 0 then slope_angle = 0 end; if slope_angle > 7 then slope_angle = 7 end  
				if frame > 30 then
					mlayer:set_Speed(frame > (35 + slope_angle) and 1.0 or (hk.check_hotkey("Dodge", true) and 0.15 or 0.25))
					local further_pos = Vector3f.new(last_pl_pos.x, pl_pos.y, last_pl_pos.z):lerp(pl_pos, (1.0 + (1 - mlayer:get_Speed())))
					pl_xform:set_Position(further_pos)
					--local wep_joint, holst_joint = pl_xform:getJointByName("R_PropA"),  pl_xform:getJointByName("L_Prop_HipA")
					local elbow, hand = pl_xform:getJointByName("L_Arm_Lower"),  pl_xform:getJointByName("L_Arm_Hand")
					local last_elbow, last_hand = elbow:get_LocalEulerAngle(), hand:get_LocalEulerAngle()
					
					temp.fns.correct_hand_fn = function()
						temp.fns.correct_hand_fn = nil
						elbow:set_LocalEulerAngle(last_elbow:lerp(Vector3f.new(-0.08, -1.485, -0.03), 0.66))
						hand:set_LocalEulerAngle(last_hand:lerp(Vector3f.new(0.177, 0.753, 0.487), 0.66))
						--wep_joint:set_Position(holst_joint:get_Position())
						--wep_joint:set_Rotation(holst_joint:get_Rotation())
					end
				end
			--elseif lss.dodge_idx == 1 and frame > 5 and target and lss.do_face_enemy and char_input:get_AxisL().y > -0.5 then
			--	temp.new_axis_l = {Vector2f.new(char_input:get_AxisL().x, 1.0)} --add a little curl to the end of the dodge, going towards the enemy
			end
		end

		--Lock-on:
		if lock_on_fn then 
			lock_on_fn()
		end
		
		local is_narrow = not not cam_ctrl["<CurrentLevelInfo>k__BackingField"]
		
		--Calculate Drift
		local drift_offset
		if lss.do_drift_cam and char_input and cam_ctrl._Angle then --and (not lock_on_fn or lss.do_drift_cam_lockon)
			local cam_pos = cam_joint:get_Position()
			local axis_l = char_input:get_AxisL()
			local swinging_multip = node_name:sub(1,3) == "Job" and 5.0 or 1.0
			local is_left_side, is_right_side = dr.slider_t < 0.45 and dr.last_slider_t <= dr.slider_t, dr.slider_t >= 0.55 and dr.last_slider_t >= dr.slider_t
			local manual_drift_l, manual_drift_r = hk.check_hotkey("Drift Cam L", true), hk.check_hotkey("Drift Cam R", true)
			local manual_drift_multip = lock_on_fn and (hk.check_hotkey("Drift Cam L", true) or hk.check_hotkey("Drift Cam R", true)) and 2.00 or 1.0
			local do_lockon_ctr = lock_on_fn and not lss.do_drift_cam_lockon and not lss.drift_cam_freeze
			local centering_speed_multip = axis_l.y >= 0.9 and 0.99 or 1
			local narrow_mult = is_narrow and 0.97 or 1.0
			dr.last_slider_t = dr.slider_t
			
			if not is_collided_wait then
				if ((manual_drift_r and (lock_on_fn or not lss.drift_hotkeys_lockon_only)) or (axis_l.x > 0.2 and is_running and not do_lockon_ctr) or (is_left_side and (do_lockon_ctr or swinging_multip > 1))) then
					if not lss.drift_cam_freeze then
						dr.slider_t = dr.slider_t + 0.01 * lss.drift_speed * swinging_multip * manual_drift_multip * deltatime * timescale_mult
					elseif manual_drift_multip > 1.0 then
						dr.slider_t = dr.slider_t + 0.01 * lss.drift_speed * manual_drift_multip * deltatime * timescale_mult
					end
				elseif ((manual_drift_l and (lock_on_fn or not lss.drift_hotkeys_lockon_only)) or (axis_l.x < -0.2 and is_running and not do_lockon_ctr) or (is_right_side and (do_lockon_ctr or swinging_multip > 1))) then
					if not lss.drift_cam_freeze then
						dr.slider_t = dr.slider_t + -0.01 * lss.drift_speed * swinging_multip * manual_drift_multip * deltatime * timescale_mult
					elseif manual_drift_multip > 1.0 then
						dr.slider_t = dr.slider_t + -0.01 * lss.drift_speed * manual_drift_multip * deltatime * timescale_mult
					end
				end
			end
			local slider_multip = (not lss.drift_cam_freeze and centering_speed_multip * narrow_mult) or 1.0
			if dr.slider_t > 1 then dr.slider_t = 1 end; if dr.slider_t < 0 then dr.slider_t = 0 end
			dr.slider_t = (dr.slider_t - 0.5) * slider_multip + 0.5 --average of this frame vs last frame, squinched back towards 0.5 based on multipliers for if a wall was touched or is running straight
			
			local invert_multip = lss.drift_cam_invert  and -1 or 1
			local slider_offs = Vector3f.new(lss.drift_limit * invert_multip, 0, 0):lerp(Vector3f.new(-lss.drift_limit * invert_multip, 0, 0), dr.slider_t)
			if lock_on_fn then
				slider_offs.x = slider_offs.x > target.dist_to_pl and target.dist_to_pl or slider_offs.x
			end
			drift_offset = rotate_yaw_method:call(nil, slider_offs, cam_ctrl._Angle.y)
		end
		
		local prev_pl_settings = pl_cam_settings
		local settings_name = is_narrow and "<CurrentLevelInfo>k__BackingField" or is_aiming and "_AimSetting" or "_PlayerCameraSettings"
		local fov_name = (is_narrow or is_aiming) and "_Fov" or "_FOV"
		local dist_name = (is_narrow or is_aiming) and "_Distance" or "_CameraDistance"
		
		--Handle Camera:
		--[[if is_aiming and (lss.do_mod_camera or lss.do_auto_tilt) then
			local add_aim_x = lss.do_auto_tilt and temp.add_aim_x or 0
			cam_ctrl["<MainCameraController>k__BackingField"]["<BaseOffset>k__BackingField"] = cam_base_offset + rotate_yaw_method:call(nil, Vector3f.new(lss.aim_cam_offset[1], lss.aim_cam_offset[2], lss.aim_cam_offset[3]), cam_joint:get_EulerAngle().y)
		end]]
		if cam_ctrl[settings_name] then
			pl_cam_settings = cam_ctrl[settings_name]
			if pl_cam_settings then
				local main_ctrl = cam_ctrl["<MainCameraController>k__BackingField"]
				local cd_obj_name = cam_ctrl:get_type_definition():get_full_name()
				cam_data[cd_obj_name] = cam_data[cd_obj_name] or {
					obj = pl_cam_settings,
					[fov_name] = is_aiming and 60 or pl_cam_settings[fov_name],
					[dist_name] = pl_cam_settings[dist_name],
					BaseOffset = main_ctrl["<BaseOffset>k__BackingField"],
				}
				cam_data.first_obj = cam_data.first_obj or cam_data[cd_obj_name]
				local cd = lss.do_affect_cams_equally and cam_data.first_obj or cam_data[cd_obj_name]
				local aim_offs = lss.do_mod_camera and is_aiming and rotate_yaw_method:call(nil, Vector3f.new(lss.aim_cam_offset[1], lss.aim_cam_offset[2], lss.aim_cam_offset[3]), cam_joint:get_EulerAngle().y)
				local side_aim_offs = lock_on_fn and (is_aiming or lss.do_autotilt_side) and rotate_yaw_method:call(nil, Vector3f.new(temp.add_aim_x, 0, 0), cam_joint:get_EulerAngle().y)
				local game_baseoffset = main_ctrl["<BaseOffset>k__BackingField"]
				
				if (lss.do_mod_camera and lss.do_mod_camera_offset) or drift_offset or side_aim_offs or (lss.do_lower_cam_during_dodge and temp.is_dodging) then
					main_ctrl["<BaseOffset>k__BackingField"] = cam_base_offset 
					if drift_offset then main_ctrl["<BaseOffset>k__BackingField"] = main_ctrl["<BaseOffset>k__BackingField"] + drift_offset end
					if side_aim_offs then main_ctrl["<BaseOffset>k__BackingField"] = main_ctrl["<BaseOffset>k__BackingField"] + side_aim_offs end
					if aim_offs then main_ctrl["<BaseOffset>k__BackingField"] = main_ctrl["<BaseOffset>k__BackingField"] + aim_offs end
					if temp.is_dodging and lss.do_lower_cam_during_dodge then main_ctrl["<BaseOffset>k__BackingField"] = Vector3f.new(main_ctrl["<BaseOffset>k__BackingField"].x, 0.9, main_ctrl["<BaseOffset>k__BackingField"].z) end
				end
				
				if lss.do_mod_camera then
					if is_aiming then 
						local copy = pl_cam_settings[fov_name]
						copy._HasValue = true
						copy._Value = 60.0 * lss.cam_fov
						write_valuetype(pl_cam_settings, fov_name, copy)
					elseif cd[fov_name] then
						pl_cam_settings[fov_name] = cd[fov_name] * lss.cam_fov
					end
					pl_cam_settings[dist_name] = (cd._CameraDistance or cd._Distance) * lss.cam_distance
					if lss.do_mod_camera_offset then
						main_ctrl["<BaseOffset>k__BackingField"] = main_ctrl["<BaseOffset>k__BackingField"] + rotate_yaw_method:call(nil, Vector3f.new(lss.cam_offset[1], lss.cam_offset[2], lss.cam_offset[3]), cam_joint:get_EulerAngle().y)
					end
					if is_aiming then
						pl_cam_settings._PosOffset = Vector3f.new(0.7, 0, lss.do_affect_cams_equally and 0 or 3.0)
					end
				end
				if lss.do_lower_cam_during_dodge and game_baseoffset ~= main_ctrl["<BaseOffset>k__BackingField"] then
					main_ctrl["<BaseOffset>k__BackingField"] = (temp.prev_baseoffset or main_ctrl["<BaseOffset>k__BackingField"]):lerp(main_ctrl["<BaseOffset>k__BackingField"], temp.is_dodging and 1.0 or 0.05)
				end
				temp.prev_baseoffset = main_ctrl["<BaseOffset>k__BackingField"]
			end
		end
		
		--Handle epic parry:
		local was_epic_parry = is_epic_parry
		is_epic_parry = is_epic_parry or (lss.do_epic_parry and node_name:find("JustGuard") and prev_node_name ~= node_name and 0.1)
		if is_epic_parry then 
			local frame = motion:getLayer(0):get_Frame()
			if frame >= 16  or not node_name:find("JustGuard") then
				sdk.call_native_func(sdk.get_native_singleton("via.Application"), sdk.find_type_definition("via.Application"), "set_GlobalSpeed", (is_epic_parry > 1) and 1.0 or is_epic_parry)
				is_epic_parry = is_epic_parry < 1 and (is_epic_parry + 0.05 * deltatime * timescale_mult)
			elseif frame >= 13 and frame < 16 then
				sdk.call_native_func(sdk.get_native_singleton("via.Application"), sdk.find_type_definition("via.Application"), "set_GlobalSpeed", 0.1)
			end
			if lss.do_cinematic_parry then
				cam_ctrl:set_Enabled(false)
				cam_joint:set_Position(cam_matrix[3]) --lookat_method:call(nil, cam_matrix[3], pl_xform:getJointByName("Spine_2"):get_Position(), Vector3f.new(0,1,0)):inverse():to_quat())
			end
		end
		if was_epic_parry and not is_epic_parry then
			cam_ctrl:set_Enabled(true)
		end
		temp.was_dashing = chara["<InputProcessor>k__BackingField"].DashSwitch
	elseif not player then
		player_rcol_shapes = {}
	end
end)

re.on_draw_ui(function()
	if imgui.tree_node("Lock-On Combat with Dodge") then
	
		if imgui.button("Reset to Defaults") then
			was_changed = true
			lss = hk.recurse_def_settings({}, default_lss)
			hk.reset_from_defaults_tbl(default_lss.hotkeys)
			reset_camera_mods(true)
		end
		tooltip("Resets all mod settings to their original values")
		imgui.same_line()
		imgui.text("*Right click on most options to reset them")
		
		imgui.begin_rect()
		changed, lss.enabled = imgui.checkbox("Mod Enabled", lss.enabled); set_wc("Enabled")
		tooltip("Enable / Disable the mod")
		
		if imgui.tree_node("Lock-On Options") then
			imgui.begin_rect()
			changed, lss.do_face_enemy = imgui.checkbox("Face Enemy", lss.do_face_enemy); set_wc("do_face_enemy")
			tooltip("Always turn to face the enemy when lock-on has been toggled")
			
			changed, lss.disable_cam_reset = imgui.checkbox("Disable Cam Reset", lss.disable_cam_reset); set_wc("disable_cam_reset")
			tooltip("Prevent pushing the right thumbstick from snapping the camera into alignment with the player")
			
			changed, lss.do_hide_dot = imgui.checkbox("Hide Dot", lss.do_hide_dot); set_wc("do_hide_dot")
			tooltip("Do not display the white dot on the selected enemy")
			
			changed, lss.do_no_lockon_camera = imgui.checkbox("No Camera Lock", lss.do_no_lockon_camera); set_wc("do_no_lockon_camera")
			tooltip("Lock-on without locking on the camera")
			
			changed, lss.do_vertical_lockon_damp = imgui.checkbox("Vertical Lock-on Damping", lss.do_vertical_lockon_damp); set_wc("do_vertical_lockon_damp")
			tooltip("The camera will follow the locked-on joint on the vertical axis more lazily, to prevent jitter")
			
			changed, lss.do_auto_tilt = imgui.checkbox("Automatic Lock-On Tilt", lss.do_auto_tilt); set_wc("do_auto_tilt")
			tooltip("The camera will automatically tilt down to let you see the enemy while locked on, or move right to see when aiming")
			if changed then temp.add_pitch_amt = 0 end
			
			changed, lss.do_autotilt_side = imgui.checkbox("Move Cam Right", lss.do_autotilt_side); set_wc("do_autotilt_side")
			tooltip("The camera offset will automatically move to the right to see the locked enemy")
			if changed then temp.add_aim_x = 0 end
			
			if lss.do_auto_tilt or lss.do_autotilt_side then
				changed, lss.auto_tilt_damping_rate = imgui.slider_float("Lock-On Tilt Damping Rate", lss.auto_tilt_damping_rate, 0, 1); set_wc("auto_tilt_damping_rate")
				tooltip("How slowly / smoothly the camera tilts to see the target. Gets stronger as it approaches 1.0")
			end
			
			changed, lss.damping_rate = imgui.slider_float("Lock On Damping Rate", lss.damping_rate, 0, 1); set_wc("damping_rate")
			tooltip("How lazily the camera follows the target. Gets stronger as it approaches 1.0")
			
			if lss.do_face_enemy then
				changed, lss.head_bob_damping_rate = imgui.slider_float("Head Bob Damping Rate", lss.head_bob_damping_rate, 0, 1); set_wc("head_bob_damping_rate")
				tooltip("Reduces the amount of head bobbing when strafing with 'Face Enemy'. Gets stronger as it approaches 1.0")
			end
			
			imgui.text_colored("Lock-On Hotkeys", 0xFFAAFFFF)
			imgui.indent()
			imgui.begin_rect()
			
			changed = hk.hotkey_setter("Lock On", nil, nil, "Lock on to an enemy in the center of the screen"); set_wc()
			changed = hk.hotkey_setter("Lock On (Hold)", nil, nil, "Lock on to an enemy in the center of the screen only while the button is held"); set_wc()
			changed = hk.hotkey_setter("Change Target L", nil, nil, "Flip to the next onscreen target to the left of the current target"); set_wc()
			changed = hk.hotkey_setter("Change Target R", nil, nil, "Flip to the next onscreen target to the right of the current target"); set_wc()
			changed = hk.hotkey_setter("Change Joint Up", nil, nil, "Select the lock-on joint above the one currently locked on"); set_wc()
			changed = hk.hotkey_setter("Change Joint Dn", nil, nil, "Select the lock-on joint below the one currently locked on"); set_wc()
			changed = hk.hotkey_setter("Tilt Lockon Up", nil, nil, "Tilt the camera up during lock-on"); set_wc()
			changed = hk.hotkey_setter("Tilt Lockon Down", nil, nil, "Tilt the camera down during lock-on"); set_wc()
			changed = hk.hotkey_setter("Tilt Lockon Left", nil, nil, "Tilt the camera left during lock-on"); set_wc()
			changed = hk.hotkey_setter("Tilt Lockon Right", nil, nil, "Tilt the camera right during lock-on"); set_wc()
			
			imgui.end_rect()
			imgui.unindent()
			imgui.end_rect(1)
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Dodge Options") then
			imgui.begin_rect()
			changed, lss.dodge_esc_threshold = imgui.slider_float("Stunlock Escape Threshold", lss.dodge_esc_threshold, 0, 100, "%.2f%%"); set_wc("dodge_esc_threshold")
			tooltip("You can use the dodge to escape from a damaged state (to avoid stun-lock) at this percent of the way through a stunned animation")
			
			changed, lss.dodge_cancel_threshold = imgui.slider_float("Dodge Cancel Threshold", lss.dodge_cancel_threshold, 0, 100, "%.2f%%"); set_wc("dodge_cancel_threshold")
			tooltip("You can use the dodge to cancel this percent of the way through an attack animation")
			
			changed, lss.dodge_stam_cost = imgui.drag_float("Dodge Stamina Cost", lss.dodge_stam_cost, 1, 0, 1000); set_wc("dodge_stam_cost")
			tooltip("How much stamina is consumed by doing a dodge")
			
			changed, lss.sliding_dodge_min_speed = imgui.drag_float("Sliding Dodge Minimum Speed", lss.sliding_dodge_min_speed, 0.01, 0, 10.0); set_wc("sliding_dodge_min_speed")
			tooltip("The minimum speed you have to be sprinting at to trigger sliding dodge")
			
			changed, lss.dodge_idx = imgui.combo("Dodge Type", lss.dodge_idx, dodge_types); set_wc("dodge_idx")
			dodge_name = dodge_names[lss.dodge_idx]
			tooltip("Select dodge motion that is used when dodging")
			
			changed, lss.dodge_only_unsheathed = imgui.checkbox("Dodge Only when Unsheathed", lss.dodge_only_unsheathed); set_wc("dodge_only_unsheathed")
			tooltip("Makes it so you can only dodge when your weapon is drawn")
			
			changed, lss.dodge_single_press = imgui.checkbox("Single Press Dodge", lss.dodge_single_press); set_wc("dodge_single_press")
			tooltip("Dodge by pressing the button only once instead of twice")
			
			changed, lss.do_air_dash = imgui.checkbox("Air Dash", lss.do_air_dash); set_wc("do_air_dash")
			tooltip("Dodge in midair")
			
			changed, lss.do_slide_dodge = imgui.checkbox("Slide Dodge", lss.do_slide_dodge); set_wc("do_slide_dodge")
			tooltip("Dodge while sprinting to slide. Hold down the dodge button to extend the slide length")
			
			changed, lss.do_lower_cam_during_dodge = imgui.checkbox("Lower Cam on Dodge", lss.do_lower_cam_during_dodge); set_wc("do_lower_cam_during_dodge")
			tooltip("Lower the height of the camera while dodging")
			
			changed, lss.do_perfect_dodge = imgui.checkbox("Perfect Dodge", lss.do_perfect_dodge); set_wc("do_perfect_dodge")
			tooltip("Slow down time on a last-moment dodge")
			
			if lss.do_perfect_dodge then
				changed, lss.perf_dodge_stamina_reward = imgui.drag_float("Perfect Dodge Stamina Reward", lss.perf_dodge_stamina_reward, 1, 0, 10000); set_wc("perf_dodge_stamina_reward")
				tooltip("How much stamina is regained on a successful Perfect Dodge")
			end
			
			imgui.text_colored("Dodge Hotkeys", 0xFFAAFFFF)
			imgui.indent()
			imgui.begin_rect()
			
			changed = hk.hotkey_setter("Dodge", nil, nil, "Double tap this button to quickly dash a short distance, evading attacks"); set_wc()
			
			changed = hk.hotkey_setter("Inhibit Dodge 1", nil, nil, "Dodge cannot be performed while this button is held down"); set_wc()
			changed = hk.hotkey_setter("Inhibit Dodge 2", nil, nil, "Dodge cannot be performed while this button is held down"); set_wc()
			
			imgui.end_rect()
			imgui.unindent()
			imgui.end_rect(1)
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Camera Controls") then
			imgui.begin_rect()
			changed, lss.do_mod_camera = imgui.checkbox("Third Person Camera Controller", lss.do_mod_camera); set_wc("do_mod_camera")
			tooltip("Modify the position, FOV and distance of the camera")
			
			if lss.do_mod_camera then 
				imgui.indent()
				imgui.begin_rect()
				changed, lss.do_affect_cams_equally = imgui.checkbox("Affect All Cam Types Equally", lss.do_affect_cams_equally); set_wc("do_affect_cams_equally")
				tooltip("All camera types (normal, aiming, tight spaces etc) will use the same settings")
				changed, lss.do_mod_camera_offset = imgui.checkbox("Change Offset", lss.do_mod_camera_offset); set_wc("do_mod_camera_offset")
				tooltip("Modify the offset position of the camera")
				if lss.do_mod_camera_offset then
					changed, lss.cam_offset = imgui_table_vec(imgui.drag_float3, "Camera Offset", lss.cam_offset, {0.01, -50.0, 50.0}); set_wc("cam_offset")
					tooltip("Add X, Y and Z to the position of the camera")
				elseif changed then
					cam_ctrl["<MainCameraController>k__BackingField"]["<BaseOffset>k__BackingField"] = cam_base_offset
				end
				changed, lss.cam_fov = imgui.slider_float("Camera Field of View", lss.cam_fov, 0, 3); set_wc("cam_fov")
				tooltip("The camera's field of view / zoom will be multiplied by this number")
				changed, lss.cam_distance = imgui.slider_float("Camera Distance", lss.cam_distance, 0, 10); set_wc("cam_distance")
				tooltip("The distance between the camera and the player will be multiplied by this number\nMay clip")
				changed, lss.cam_look_up_data = imgui_table_vec(imgui.drag_float2, "LookUp Distance/Y Offset", lss.cam_look_up_data, {0.01, -50, 50}); set_wc("cam_look_up_data")
				tooltip("Multipliers for the distance to the camera and the offset up/down that the camera will assume when looking up")
				changed, lss.cam_look_dn_data = imgui_table_vec(imgui.drag_float2, "LookDn Distance/Y Offset", lss.cam_look_dn_data, {0.01, -50, 50}); set_wc("cam_look_dn_data")
				tooltip("Multipliers for the distance to the camera and the offset up/down that the camera will assume when looking down")
				changed, lss.aim_cam_offset = imgui_table_vec(imgui.drag_float3, "Aim Offset", lss.aim_cam_offset, {0.01, -50, 50}); set_wc("aim_cam_offset")
				tooltip("The camera will be moved by this offset when aiming")
				imgui.end_rect(1)
				imgui.unindent()
			elseif changed then
				reset_camera_mods(true)
			end
			
			imgui.end_rect(2)
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Camera Drift Options") then
			imgui.begin_rect()
			changed, lss.do_drift_cam = imgui.checkbox("Camera Drift", lss.do_drift_cam); set_wc("do_drift_cam")
			tooltip("Makes the camera pan from left to right as you run sideways")
			if lss.do_drift_cam then
				imgui.same_line()
				changed, lss.do_drift_cam_lockon = imgui.checkbox("During Lock On", lss.do_drift_cam_lockon); set_wc("do_drift_cam_lockon")
				tooltip("Drift while locked on")
				imgui.indent()
				imgui.begin_rect()
				changed, lss.drift_cam_invert = imgui.checkbox("Invert	  ", lss.drift_cam_invert); set_wc("drift_cam_invert")
				tooltip("If inverted, the player will move away from the side of the screen they are running towards")
				imgui.same_line()
				changed, lss.drift_cam_freeze = imgui.checkbox("Freeze", lss.drift_cam_freeze); set_wc("drift_cam_freeze")
				tooltip("Freeze the current level of drift")
				changed, lss.drift_limit = imgui.slider_float("Drift Limit", lss.drift_limit, 0, 1.5); set_wc("drift_limit")
				tooltip("Limit how far the camera can drift in either direction")
				changed, lss.drift_speed = imgui.slider_float("Drift Speed", lss.drift_speed, 0, 0.5); set_wc("drift_speed")
				tooltip("Set how fast the camera can travel from one side to the other")
				changed, dr.slider_t = imgui.slider_float("Current Drift", dr.slider_t, 0, 1)
				tooltip("The current level of drift")
				imgui.end_rect(1)
				imgui.unindent()
			end
			imgui.text_colored("Drift Hotkeys", 0xFFAAFFFF)
			imgui.indent()
			imgui.begin_rect()
			
			changed, lss.drift_hotkeys_lockon_only = imgui.checkbox("Use Hotkeys Only When Locked-on", lss.drift_hotkeys_lockon_only); set_wc("drift_hotkeys_lockon_only")
			tooltip("Lets you use the drift hotkeys while not locked-on")
			
			changed = hk.hotkey_setter("Drift Cam L", nil, nil, "Drift the camera to the left during lock-on"); set_wc()
			changed = hk.hotkey_setter("Drift Cam R", nil, nil, "Drift the camera to the right during lock-on"); set_wc()
			
			imgui.end_rect()
			imgui.unindent()
			imgui.end_rect(2)
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Misc Options") then
			imgui.begin_rect()
			
			changed, lss.do_enemy_lifebars = imgui.checkbox("Show Life Bars", lss.do_enemy_lifebars); set_wc("do_enemy_lifebars")
			tooltip("Display the enemy's life bar when their HP changes or when locked-on")
			
			if lss.do_enemy_lifebars then
				imgui.same_line()
				changed, lss.do_wallhack_lifebars = imgui.checkbox("Wallhack Life Bars", lss.do_wallhack_lifebars); set_wc("do_wallhack_lifebars")
				tooltip("Display the enemy's life bar through the wall")
			end
			
			changed, lss.do_no_soft_lock = imgui.checkbox("No Soft Lock    ", lss.do_no_soft_lock); set_wc("do_no_soft_lock")
			tooltip("Disables automatically moving / aiming attacks towards nearby enemies")
			
			if lss.do_no_soft_lock then
				imgui.same_line()
				changed, lss.no_soft_lock_when_locked = imgui.checkbox("Only When Locked On", lss.no_soft_lock_when_locked); set_wc("no_soft_lock_when_locked")
				tooltip("Disables soft lock only when locked on")
			end
			
			changed, lss.god_mode = imgui.checkbox("Practice Mode ", lss.god_mode); set_wc("god_mode")
			tooltip("You cant die. Also infinite stamina\nJust for playing around/testing")
			if changed and player and not lss.god_mode then
				local mainpawn = sdk.get_managed_singleton("app.PawnManager"):call("get_MainPawn()")
				for i, hc in ipairs({getC(player, "app.HitController"), mainpawn and getC(mainpawn["<CachedGameObject>k__BackingField"], "app.HitController")}) do
					hc["<IsNoDie>k__BackingField"] = false
					hc["<IsDamageZero>k__BackingField"] = false
					hc["<IsAttackNoDie>k__BackingField"] = false
					hc["<IsInvincible>k__BackingField"] = false
				end
			end
			
			if lss.god_mode then
				imgui.same_line()
				changed, lss.god_mode_invinc = imgui.checkbox("Invincible", lss.god_mode_invinc); set_wc("god_mode_invinc")
				tooltip("You cant be hit")
			end
			
			changed, lss.do_epic_parry = imgui.checkbox("Slo Mo Parry	", lss.do_epic_parry); set_wc("do_epic_parry")
			tooltip("Go into slow motion for a moment when performing a parry")
			
			if lss.do_epic_parry then
				imgui.same_line()
				changed, lss.do_cinematic_parry = imgui.checkbox("Cinematic Parry", lss.do_cinematic_parry); set_wc("do_cinematic_parry")
				tooltip("Do an Epic Parry from a fixed perspective")
			end
			
			imgui.end_rect(1)
			imgui.tree_pop()
		end
		
		if was_changed then
			hk.update_hotkey_table(lss.hotkeys)
			json.dump_file("LockOn.json", lss)
		end
		imgui.text("																			v"..version.."  |  By alphaZomega")
		imgui.end_rect(1)
		imgui.tree_pop()
	end
end)

re.on_frame(function()
	if target and lock_on_fn and not lss.do_hide_dot then
		local pos_2d = draw.world_to_screen(target.lock_pos)
		if pos_2d then 
			draw.filled_circle(pos_2d.x, pos_2d.y, 5.0, 0xAAFFFFFF, 0)
		end
	end
	if player and pl_xform then
		temp.prev_quat = pl_xform:get_Rotation()
	end
	is_paused = true
end)

re.on_script_reset(function()
	reset_camera_mods(true)
end)

--Handle No-Soft-Lock and Face Enemy (in hook)
temp.setup_face_enemy = function()
	temp.setup_face_enemy = nil
	sdk.hook(sdk.find_type_definition("app.TurnController"):get_method("updateAngle"), function(args)
		if not lss.enabled or is_aiming or sdk.to_managed_object(args[2]).Transform ~= pl_xform then return end
		
		local is_turnmoving = temp.is_dodging or node_name:find("Jump") --or is_sliding
		local is_attacking = node_name:sub(1,3) == "Job" and not node_name:find("inish")
		local is_lockon_lookat = not is_turnmoving and (lock_on_fn and target and lss.do_face_enemy and (is_strafing or is_attacking)) and not temp.dodge_triggered and not temp.is_under_target
		
		if (lss.do_no_soft_lock and l_mag == 0 and ((lock_on_fn or not lss.no_soft_lock_when_locked))) or is_lockon_lookat or is_turnmoving then 
			if node_name == "Locomotion.NormalLocomotion" or node_name == "Locomotion.Strafe" or is_attacking or is_turnmoving then
				local pl_lookat_yaw = is_lockon_lookat and lookat_method:call(nil, pl_xform:get_Position(), target.lockon_joint:get_Position(), Vector3f.new(0,1,0)):inverse():to_quat():to_euler().y
				if (is_lockon_lookat or l_mag > 0) then 
					if not is_sliding and (lss.dodge_idx ~= 2 or motion:getLayer(0):get_Frame() < 10) then
						local add_amt = (temp.is_dodging and lss.dodge_idx == 2) and 0 or math.pi
						local yaw = ((pl_lookat_yaw or (cam_joint:get_EulerAngle().y + char_input:get_AngleRadL())) + add_amt) * 57.2958
						chara:setVariableTurnAngleDeg(yaw)
						chara:set_TargetFrontAngleDeg(yaw)
						chara:set_TargetMoveAngleDeg(yaw)
					end
					if is_sliding then
						local pl_eul = pl_xform:get_EulerAngle()
						pl_xform:set_EulerAngle(Vector3f.new(pl_eul.x, cam_joint:get_EulerAngle().y + char_input:get_AngleRadL() + math.pi, pl_eul.z))
						new_quat = temp.prev_quat:slerp(pl_xform:get_Rotation(), 0.05)  --allow limited turning
						pl_xform:set_Rotation(new_quat)
						
					elseif is_lockon_lookat and (char_input:get_AxisL().y > -0.5 or os.clock() - temp.last_slide_time > 0.2) then
						local pl_eul = pl_xform:get_EulerAngle()
						pl_xform:set_EulerAngle(Vector3f.new(pl_eul.x, pl_lookat_yaw + math.pi, pl_eul.z))
						
						if lss.head_bob_damping_rate > 0 and l_mag >= 0.7 then
							damp.float02["<Exp>k__BackingField"] = lss.head_bob_damping_rate
							temp.fns.set_pos_again_fn = function()
								temp.fns.set_pos_again_fn = nil
								local pos = pl_xform:getJointByName("Hip"):get_LocalPosition()
								damp.float02._Target = pos.y
								damp.float02._Source = damp.float02._Current
								damp.float02:updateParam()
								pl_xform:getJointByName("Hip"):set_LocalPosition(Vector3f.new(pos.x, damp.float02._Current, pos.z))
								pl_xform:getJointByName("Hip"):set_LocalPosition(Vector3f.new(pos.x, damp.float02._Current, pos.z))
							end
						end
						make_dampen_rot_fn(0.2)
					end
					
					if is_lockon_lookat and node_name:find("Jump") then
						local pl_eul = pl_xform:get_EulerAngle()
						pl_xform:set_EulerAngle(Vector3f.new(pl_eul.x, cam_joint:get_EulerAngle().y + char_input:get_AngleRadL() + math.pi, pl_eul.z))
					end
				else
					return 1 
				end
			end
		end
	end)
end

--Handle perfect dodge:
temp.setup_perfect_dodge = function()
	temp.setup_perfect_dodge = nil
	sdk.hook(sdk.find_type_definition("via.physics.RequestSetCollider"):get_method("getCollidable(System.UInt32, System.UInt32, System.UInt32)"), 
		function(args)
			if not lss.enabled or not lss.do_perfect_dodge then return end
			if temp.is_dodging and not is_perfect_dodge and mlayer:get_Frame() <= 7.0 and mlayer:get_HighestWeightMotionNode():get_MotionName() == "ch00_004_atk_dodge_start" and mlayer:get_Frame() >= 5.5 then
				local rcol = sdk.to_managed_object(args[1])
				local gameobj = rcol:get_GameObject()
				local em_mot = (gameobj ~= player) and getC(gameobj, "via.motion.Motion")
				local em_layer = em_mot and em_mot:getLayer(0)
				if em_layer and em_layer:get_Frame() > em_layer:get_EndFrame() / 2 then
					temp.rcol = rcol
				end
			end
		end,
		function(retval)
			if not temp.rcol then return retval end
			local collider = sdk.to_managed_object(retval)
			local gameobj = temp.rcol:get_GameObject()
			temp.rcol = nil
			
			if collider and hk.find_index(em_mgr._EnemyList._items, getC(gameobj, "app.Ch200000")) then
				local em_shape = collider:get_TransformedShape()--; em_shape = em_shape.Capsule or em_shape.Sphere or em_shape
				em_shape = em_shape.get_Capsule and em_shape:get_Capsule() or em_shape.get_Sphere and em_shape:get_Sphere() or em_shape 
				local centers = {em_shape.get_Center and em_shape:get_Center() or (em_shape.p0 + (em_shape.p1 - em_shape.p0) * 0.5)}
				if em_shape.p1 then
					centers[2], centers[3] = em_shape.p0, em_shape.p1
				end
				local radius = em_shape:get_Radius()
				for i, center in pairs(centers) do
					for j, shape in pairs(player_rcol_shapes) do
						local min_sz = radius + shape.og_radius
						if (shape.x_shape:get_Center() - center):length() < (min_sz > 5.5 and min_sz or 5.5) then
							local stam_mgr = chara:get_StaminaManager()
							stam_mgr["<RemainingAmount>k__BackingField"] = stam_mgr["<RemainingAmount>k__BackingField"] + lss.perf_dodge_stamina_reward
							
							local start = os.clock()
							temp.fns.perfect_dodge_fn = function()
								temp.fns.perfect_dodge_fn = temp.is_dodging and mlayer:get_Frame() < 11.0 and os.clock() - start < 1.0 and temp.fns.perfect_dodge_fn or nil
								sdk.call_native_func(sdk.get_native_singleton("via.Application"), sdk.find_type_definition("via.Application"), "set_GlobalSpeed", temp.fns.perfect_dodge_fn and 0.1 or 1.0)
								--getC(gameobj, "via.motion.Motion"):getLayer(0):set_Speed(temp.fns.perfect_dodge_fn and 0.66 or 1.0)
							end
							break
						end
					end
				end
			end
			return retval
		end
	)
end

--Its paused if its not controllable
sdk.hook(sdk.find_type_definition("app.CharacterInput"):get_method("set_AxisL"), function(args)
	is_paused = false
	
	--Force inputs Lstick:
	if temp.new_axis_l then
		local input = sdk.to_valuetype(args[3], "via.vec2")
		input.x, input.y = temp.new_axis_l.x, temp.new_axis_l.y
		args[3] = sdk.to_ptr(input:get_address())
		if not temp.new_axis_l[2] or os.clock() - temp.new_axis_l[3] > temp.new_axis_l[2] then
			temp.new_axis_l = nil
		end
	end
end)

sdk.hook(sdk.find_type_definition("app.PlayerInputProcessor"):get_method("isDashTrigger"), nil, function(retval)
	if temp.do_dash_req then
		temp.do_dash_req = nil
		is_running = true
		return sdk.to_ptr(true)
	end
	return retval
end)

sdk.hook(sdk.find_type_definition("app.SetHumanState"):get_method("update"), function(args)
	if mlayer and mlayer:get_Speed() ~= 1.0 then
		if is_falling then
			local last_pos = pl_xform:get_Position() 
			temp.fns.fall_fn = function()
				temp.fns.fall_fn, is_falling = nil
				local pos = pl_xform:get_Position() 
				local interp_pos = last_pos:lerp(pos, 0.75)
				pl_xform:set_Position(Vector3f.new(interp_pos.x, pos.y, interp_pos.z))
			end
		end
		return sdk.PreHookResult.SKIP_ORIGINAL
	end
end)

sdk.hook(sdk.find_type_definition("app.HumanFallAction"):get_method("update(via.behaviortree.ActionArg)"), function(args)
	if is_sliding or os.clock() - temp.last_slide_time < 1.0 then
		is_falling = true
		return sdk.PreHookResult.SKIP_ORIGINAL
	end
end)