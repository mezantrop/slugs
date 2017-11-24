-- Slugs. Found them on grass and dirt.
-- Simple snake/wormlike creatures mod implementation for Minetest
-- v 0.1, 2017.11.24    Initial, very buggy and ugly. Slugs are brainless, they just move for now.

-------------------------------------------------------------------------------
-- "THE BEER-WARE LICENSE" (Revision 42):
-- zmey20000@yahoo.com wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, and you think
-- this stuff is worth it, you can buy me a beer in return Mikhail Zakharov
-------------------------------------------------------------------------------

-- Textures are inspired by [Mod] Worms and Snakes [worm] https://forum.minetest.net/viewtopic.php?f=9&t=17522

local tsunit_size = 1
local speed_walk = 1
local speed_swim = speed_walk / 2
local speed_run = 4
local speed_jump = 4                    -- Set it to 4 or more to jump on the block on the first attempt
local gravity = 1
local drop_probability = 30
local drop_item = "default:dirt"
local maxage = 300

------------------------------------------------------------------------------------------------------------------------
round = function(x, precision) return tonumber(string.format("%." .. (precision or 4) .. "f", x)) end

------------------------------------------------------------------------------------------------------------------------
local angle0 = 0
local angle45 = round(math.pi / 4)                                          -- Unused
local angle90 = round(math.pi / 2)
local angle135 = round(angle45 * 3)                                         -- Unused
local angle180 = round(math.pi)
local angle225 = round(angle45 * 5)                                         -- Unused
local angle270 = round(3 * math.pi / 2)
local angle315 = round(angle45 * 7)                                         -- Unused
local angle360 = round(2 * math.pi)

local left = "left"
local right = "right"
local up = "up"
local down = "down"
local forward = "forward"
local backward = "backward"

------------------------------------------------------------------------------------------------------------------------
alignpos = function(self, alignment)
    local my_yaw = round(self.object:getyaw())
    local my_pos = self.object:getpos()

    if alignment == "lr" then                                               -- Align left/right position only
        if my_yaw == angle0 or my_yaw == angle360 or my_yaw == angle180 then
            my_pos.x = round(my_pos.x, 0)
        elseif my_yaw == angle90 or my_yaw == angle270 then
            my_pos.z = round(my_pos.z, 0)
        end
    elseif alignment == "fb" then                                           -- Align forward/backward position only
        if my_yaw == angle0 or my_yaw == angle360 or my_yaw == angle180 then
            my_pos.z = round(my_pos.z, 0)
        elseif my_yaw == angle90 or my_yaw == angle270 then
            my_pos.x = round(my_pos.x, 0)
        end
    elseif alignment == "ud" then                                           -- Align up/down position only
            my_pos.y = round(my_pos.y, 0)
    else                                                                    -- Center everything: x, y, z
        my_pos.x = round(my_pos.x, 0)
        my_pos.z = round(my_pos.z, 0)
        my_pos.y = round(my_pos.y, 0)
    end

    self.object:setpos(my_pos)
end

------------------------------------------------------------------------------------------------------------------------
isaligned = function(self)
    local ix, fx
    local iz, fz

    local my_pos = self.object:getpos()

    ix, fx = math.modf(math.abs(my_pos.x))
    iz, fz = math.modf(math.abs(my_pos.z))

    -- to be strict fx, fz must be greater then 0, but in practice we have to
    -- check a range from 0.1 to 0.9 because of "step size" and collisions
    if fx >= 0.1 and fx <= 0.9 then return false end
    if fz >= 0.1 and fz <= 0.9 then return false end

    -- consider the node is aligned
    return true
end

------------------------------------------------------------------------------------------------------------------------
get_near_pos = function(self, pos, direction, distance)
    -- Get node coordinates in front or behind of the entity; By default assume direction if "infront"
    local sunit_delta = tsunit_size / 2
    if distance then sunit_delta = distance end
    local near_pos = pos

    if direction == "under" then
        near_pos.y = near_pos.y - sunit_delta - 0.1
        return near_pos
    end

    if direction == "above" then
        near_pos.y = near_pos.y + sunit_delta + 0.1
        return near_pos
    end

    if direction == "infront_above" or direction == "behind_above" then
        near_pos.y = near_pos.y + sunit_delta + 0.1
    elseif direction == "infront_under" or direction == "behind_under" then
        near_pos.y = near_pos.y - sunit_delta - 0.1
    end

    if tsunit_size < 1 then sunit_delta = sunit_delta + (1 - tsunit_size) / 2 end
    if distance then sunit_delta = distance end
    local angle = round(self.object:getyaw())

    if direction == "behind" or direction == "behind_above" or direction == "behind_under" then
        angle = round(angle + angle180)
        if angle > angle360 then angle = round(angle - angle360) end
    end

    if angle == angle0 or angle == angle360 then
        near_pos.z = near_pos.z + sunit_delta
    elseif angle == angle90 then
        near_pos.x = near_pos.x - sunit_delta
    elseif angle == angle180 then
        near_pos.z = near_pos.z - sunit_delta
    elseif angle == angle270 then
        near_pos.x = near_pos.x + sunit_delta
    elseif angle == angle45 then
        near_pos.x = near_pos.x - sunit_delta
        near_pos.z = near_pos.z + sunit_delta
    elseif angle == angle135 then
        near_pos.x = near_pos.x - sunit_delta
        near_pos.z = near_pos.z - sunit_delta
    elseif angle == angle225 then
        near_pos.x = near_pos.x + sunit_delta
        near_pos.z = near_pos.z - sunit_delta
    elseif angle == angle315 then
        near_pos.x = near_pos.x + sunit_delta
        near_pos.z = near_pos.z + sunit_delta
    end

    return near_pos
end

------------------------------------------------------------------------------------------------------------------------
get_nearme_pos = function(self, direction, distance) return get_near_pos(self, self.object:getpos(), direction, distance) end

-- Shortcuts for getting position above/behind/under/infront/etc me
get_aboveme_pos = function(self, distance) return get_nearme_pos(self, "above", distance) end
get_behindme_pos = function(self, distance) return get_nearme_pos(self, "behind", distance) end
get_behind_aboveme_pos = function(self, distance) return get_nearme_pos(self, "behind_above", distance) end
get_behind_underme_pos = function(self, distance) return get_nearme_pos(self, "behind_under", distance) end
get_infrontme_pos = function(self, distance) return get_nearme_pos(self, "infront", distance) end
get_infront_aboveme_pos = function(self, distance) return get_nearme_pos(self, "infront_above", distance) end
get_infront_underme_pos = function(self, distance) return get_nearme_pos(self, "infront_under", distance) end
get_underme_pos = function(self, distance) return get_nearme_pos(self, "under", distance) end

-- Shortcuts for getting nodes above/behind/under/infront/etc me
get_aboveme_node = function(self, distance) return minetest.get_node(get_aboveme_pos(self, distance)) end
get_behindme_node = function(self, distance) return minetest.get_node(get_behindme_pos(self, distance)) end
get_behind_aboveme_node = function(self, distance) return minetest.get_node(get_behind_aboveme_pos(self, distance)) end
get_behind_underme_node = function(self, distance) return minetest.get_node(get_behind_underme_pos(self, distance)) end
get_infrontme_node = function(self, distance) return minetest.get_node(get_infrontme_pos(self, distance)) end
get_infront_aboveme_node = function(self, distance) return minetest.get_node(get_infront_aboveme_pos(self, distance)) end
get_infront_underme_node = function(self, distance) return minetest.get_node(get_infront_underme_pos(self, distance)) end
get_underme_node = function(self, distance) return minetest.get_node(get_underme_pos(self, distance)) end

------------------------------------------------------------------------------------------------------------------------
look = function(self, radians, direction)
    local my_yaw = 0
    local new_yaw = 0

    my_yaw = self.object:getyaw()

    if direction == left then
        new_yaw = round(my_yaw + radians)
    elseif direction == right then
        new_yaw = round(my_yaw - radians)
    end

    -- Reset angle to start from 0
    if new_yaw > angle360 then
        new_yaw = round(new_yaw - angle360)    -- Turning Left
    elseif new_yaw < 0 then
        new_yaw = round(new_yaw + angle360)    -- Turning Right
    end

    self.object:setyaw(new_yaw)
end

look_left45 = function(self) look(self, angle45, left) end                    -- Unused
look_left90 = function(self) look(self, angle90, left) end
look_left180 = function(self) look(self, angle180, left) end
look_left270 = function(self) look(self, angle270, left) end
look_right45 = function(self) look(self, angle45, right) end                  -- Unused
look_right90 = function(self) look(self, angle90, right) end
look_right180 = function(self) look(self, angle180, right) end
look_right270 = function(self) look(self, angle270, right) end
look_left = look_left90
look_right = look_right90
look_random = function(self)
    if math.random(1, 2) == 1 then look_left(self) else look_right(self) end
end

------------------------------------------------------------------------------------------------------------------------
fall = function(self, gravity)
    local air_density = 10
    local water_density = 100

    local my_pos = self.object:getpos()
--    local body_pos = my_pos
    local n_under = get_underme_node(self)

    if isaligned(self) and n_under.name == "air" then
        my_pos.y = round(my_pos.y - gravity / air_density, 1)                               -- air
    elseif isaligned(self) and minetest.get_node_group(n_under.name, "water") > 0 then
        my_pos.y = round(my_pos.y - gravity / water_density, 2)                             -- water
    else
        return false
    end

    self.object:setpos(my_pos)
--    self.body_pos = body_pos
    return true
end

------------------------------------------------------------------------------------------------------------------------
jump = function(self, direction)
    local in_water = false
    local my_pos = self.object:getpos()
    my_pos.y = round(my_pos.y + 1, 1)

    local n_under = get_underme_node(self)
    if minetest.get_node_group(n_under.name, "water") > 0 then
        my_pos.y = round(my_pos.y + 3, 1)
        in_water = true
    end

    local ian = get_infront_aboveme_node(self)
    self.object:setpos(my_pos)
    if direction == "forward" and (ian.name == "air" or in_water) then go(self, 4) end
end

------------------------------------------------------------------------------------------------------------------------
go = function(self, speed)
    -- Move head forward
    local my_yaw = self.object:getyaw()
    local x = math.sin(my_yaw) * -speed
    local z = math.cos(my_yaw) * speed

    local my_pos = self.object:getpos()
    my_pos.x = my_pos.x + x / 40
    my_pos.z = my_pos.z + z / 40

    self.object:setpos(my_pos)
    self.body_pos = get_behindme_pos(self, tsunit_size)
end

------------------------------------------------------------------------------------------------------------------------
grow = function(self, head)
    self.body_pos = get_behindme_pos(self, tsunit_size)
    local my_yaw = self.object:getyaw()

    self.body = minetest.add_entity(self.body_pos, "slugs:body")
    self.body:setyaw(my_yaw)

    self.bodyle = self.body:get_luaentity()
    self.bodyle.head_reference = head
    self.bodyle.parent_reference = self

    head.bodylength = head.bodylength + 1
end

------------------------------------------------------------------------------------------------------------------------
move_body = function(self)
    local my_pos = self.object:getpos()
    if self.parent_reference then
        if self.parent_reference.onlook or self.parent_reference.onfall or self.parent_reference.onjump then
            -- Parent is looking aside
            go(self, speed_walk)

            local mpos = vector.round(my_pos)
            local ppos = vector.round(self.parent_reference.onlook_pos)
            if vector.equals(mpos, ppos) or math.abs(vector.distance(mpos, ppos)) > tsunit_size then
                self.onlook_pos = ppos
                if self.parent_reference.onlook == true then
                    -- Parrent is looking
                    self.onlook = true
                    self.parent_reference.onlook = false
                end
                if self.parent_reference.onfall == true then
                    -- Parent is falling
                    self.onfall = true
                    self.parent_reference.onfall = false
                    self.object:setpos(get_aboveme_pos(self.parent_reference, tsunit_size))
                end
                if self.parent_reference.onjump == true then
                    -- Parent is jumping
                    self.onjump = true
                    self.parent_reference.onjump = false
                    self.object:setpos(get_underme_pos(self.parent_reference, tsunit_size))
                end
            end
        else
            -- Parent is just looking forward
            local cppos = self.parent_reference.object:getpos()
            if cppos then
                if math.abs(vector.distance(my_pos, cppos)) >= tsunit_size then
                    -- Turn and set behind parent
                    local my_yaw = self.parent_reference.object:getyaw()
                    self.object:setyaw(my_yaw)
                    self.object:setpos(self.parent_reference.body_pos)
                    local bmn = get_behindme_node(self)
                    local bman = get_behind_aboveme_node(self)
                    local bmun = get_behind_underme_node(self)
                    if bmn.name == "air" or minetest.get_node_group(bmn.name, "water") > 0 then
                        self.body_pos = get_behindme_pos(self, tsunit_size)
                    elseif bman.name == "air" or minetest.get_node_group(bman.name, "water") > 0 then
                        self.body_pos = get_behind_aboveme_pos(self, tsunit_size)
                    elseif bmun.name == "air" or minetest.get_node_group(bmun.name, "water") > 0 then
                        self.body_pos = get_behind_underme_pos(self, tsunit_size)
                    end
                else
                    -- Just move forward
                    go(self, speed_walk)
                end
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
dropitem = function(self)
    local my_pos = self.object:getpos()
    if math.random(1, 100) <= drop_probability then minetest.add_item(my_pos, drop_item) end
end

------------------------------------------------------------------------------------------------------------------------
minetest.register_entity("slugs:head", {
    hp_max = 7,
    physical = true,
    weight = 5,

    collisionbox = {-tsunit_size / 2, -tsunit_size / 2, -tsunit_size / 2,
                    tsunit_size / 2, tsunit_size / 2, tsunit_size / 2},
    visual = "cube",
    visual_size = {x = tsunit_size, y = tsunit_size},
    mesh = "model",
    textures = {"slugs_top.png", "slugs_bottom.png",                        -- Top and bottom images
                "slugs_side2.png", "slugs_side1.png",                       -- Sides left(?), right(?)
                "slugs_face.png", "slugs_tail.png"},                        -- Front, back
    colors = {}, -- number of required colors depends on visual
    is_visible = true,
    makes_foot_sound = false,
    automatic_rotate = false,

    grow_on = true,
    bodylength = 0,

    body = nil,
    bodyle = nil,
    body_pos = {x=0,y=0,z=0},
    onlook_pos = {x=0,y=0,z=0},
    onlook = false,
    onjump = false,
    onfall = false,
    direction = forward,
    age = 0,

    --------------------------------------------------------------------------------------------------------------------
    on_activate = function(self, staticdata)
        alignpos(self)
        fall(self, gravity)
    end,

    --------------------------------------------------------------------------------------------------------------------
    on_step = function(self, dtime)
        self.age = self.age + dtime
        if self.age > maxage then
            -- Drop items and remove the corpse
            dropitem(self)
            self.object:set_hp(0)
            self.object:remove()
        end

        -- Gravity
        local my_pos = self.object:getpos()
        local falling = fall(self, gravity)

        -- On the ground
        if not falling then
            local ifu = get_underme_node(self)
            local ifn = get_infrontme_node(self)
            -- Jump
            if ifu.name ~= "air" and ifn.name ~= "air" and
                minetest.get_node_group(ifn.name, "water") == 0 and math.random(0,1) then
                    jump(self, "forward")
                    self.onlook_pos = my_pos
                    self.direction = up
                    self.onjump = true
            end
            -- Go
            if ifn.name == "air" or minetest.get_node_group(ifn.name, "water") > 0 or
                minetest.get_node_group(ifn.name, "torch") > 0 then
                    go(self, speed_walk)
            end

            if self.grow_on and self.body == nil then
                    grow(self, self)
                    self.grow_on = false
            end

            -- Grow
            if math.random(1, 1000) <= 10 and self.bodylength < 5 then self.grow_on = true else self.grow_on = false end
        else
            -- falling
            if self.direction ~= down then
                self.onlook_pos = my_pos
                self.onfall = true
                self.direction = down
            end
        end

        -- Look
        if not self.onlook and isaligned(self) == true and math.random(1, 500) <= 10 and
            -- prevent overfolding
            math.abs(vector.distance(self.onlook_pos, self.body_pos)) > tsunit_size then

            look_random(self)
            alignpos(self, "lr")

            self.onlook_pos = my_pos
            self.onlook = true
        end
    end,

    --------------------------------------------------------------------------------------------------------------------
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir) dropitem(self) end
})

------------------------------------------------------------------------------------------------------------------------
minetest.register_entity("slugs:body", {
    hp_max = 5,
    physical = true,
    weight = 5,
    groups = {fleshy = 3},

    collisionbox = {-tsunit_size / 2, -tsunit_size / 2, -tsunit_size / 2,
                    tsunit_size / 2, tsunit_size / 2, tsunit_size / 2},
    visual = "cube",
    visual_size = {x = tsunit_size, y = tsunit_size},
    mesh = "model",
    textures = {"slugs_top.png", "slugs_bottom.png",                        -- Top and bottom images
                "slugs_side2.png", "slugs_side1.png",                       -- Sides left(?), right(?)
                "slugs_tail.png", "slugs_tail.png"},                        -- Front, back
    colors = {}, -- number of required colors depends on visual
    is_visible = true,
    makes_foot_sound = false,
    automatic_rotate = false,

    body = nil,
    bodyle = nil,
    body_pos = {x=0,y=0,z=0},
    onlook_pos = {x=0,y=0,z=0},
    onlook = false,

    --------------------------------------------------------------------------------------------------------------------
    on_step = function(self, dtime)
        move_body(self)

        local head = self.head_reference

        if head and head.object:get_luaentity() then
            if head.grow_on and self.body == nil then
                grow(self, head)
                head.grow_on = false
            end
        else
            -- Drop items and remove the body piece
            dropitem(self)
            self.object:set_hp(0)
            self.object:remove()
        end
    end,

    --------------------------------------------------------------------------------------------------------------------
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir) dropitem(self) end
})

------------------------------------------------------------------------------------------------------------------------
minetest.register_abm({
	nodenames = {"default:dirt_with_grass", "default:dirt"},
	interval = 60,
	chance = 7500,
	action = function(pos)
		pos.y = pos.y + 1
        minetest.add_entity(pos, "slugs:head")
	end,
})
