-- Space Exploration related functionality
local SpaceExploration = {}

SpaceExploration.name = "space-exploration"
SpaceExploration.enabled = not not remote.interfaces[SpaceExploration.name]

-- Whether the Surface has been taken as a Space Sandbox
function SpaceExploration.IsSandbox(surface)
    return SpaceExploration.enabled
            and global.seSurfaces[surface.name]
end

-- Whether the Surface has been taken as a Planetary Lab Sandbox
function SpaceExploration.IsPlanetarySandbox(surface)
    return SpaceExploration.enabled
            and global.seSurfaces[surface.name]
            and not global.seSurfaces[surface.name].orbital
end

-- Whether the Zone is Star
function SpaceExploration.IsStar(zoneName)
    if not SpaceExploration.enabled then
        return false
    end
    return remote.call(SpaceExploration.name, "get_zone_from_name", {
        zone_name = zoneName,
    }).type == "star"
end

-- Ask Space Exploration for the Player's current Character
function SpaceExploration.GetPlayerCharacter(player)
    if not SpaceExploration.enabled then
        return
    end
    return remote.call(SpaceExploration.name, "get_player_character", {
        player = player,
    })
end

-- Whether the Sandbox might have Biters falling
function SpaceExploration.IsZoneThreatening(zone)
    return (zone.type == "planet" or zone.type == "moon")
            and zone.controls
            and zone.controls["se-vitamelange"]
            and zone.controls["se-vitamelange"].richness > 0
end

-- Walk Parent Indexes to find the Root Zone (Star)
function SpaceExploration.GetRootZone(zoneIndex, zone)
    local rootZone = zone
    while rootZone.parent_index do
        rootZone = zoneIndex[rootZone.parent_index]
    end
    return rootZone
end

-- Chooses a non-home-system Star or Moon for a Force's Space Sandbox, if necessary
-- Notably, Star _Orbits_ are "usable" Zones, but not Stars themselves
-- In other words, these should be completely safe and invisible outside of this mod!
-- Moons, on the other hand, will take a valuable resource away from the player
-- We also carefully choose Moons in order to not take away too much from them,
-- and to not be too dangerous.
function SpaceExploration.ChooseZoneForForce(player, sandboxForce, type)
    if not SpaceExploration.enabled then
        return
    end

    local zoneIndex = remote.call(SpaceExploration.name, "get_zone_index", {})
    for _, zone in pairs(zoneIndex) do
        if zone.type == type
                and not zone.is_homeworld
                and not zone.ruins
                and not zone.glyph
                and zone.special_type ~= "homesystem"
                and not global.seSurfaces[zone.name]
        then
            local rootZone = SpaceExploration.GetRootZone(zoneIndex, zone)
            if not SpaceExploration.IsZoneThreatening(zone)
                    and rootZone.special_type ~= "homesystem"
            then
                Debug.log("Choosing SE Zone " .. zone.name .. " as Sandbox for " .. sandboxForce.name)
                return zone.name
            end
        end
    end
end

function SpaceExploration.GetOrCreateSurface(zoneName)
    if not SpaceExploration.enabled then
        return
    end

    local surface = remote.call(SpaceExploration.name, "zone_get_make_surface", {
        zone_index = remote.call(SpaceExploration.name, "get_zone_from_name", {
            zone_name = zoneName,
        }).index,
    })
    surface.freeze_daytime = true
    surface.daytime = global.seSurfaces[zoneName].daytime
    surface.show_clouds = false
    return surface
end

-- Chooses a non-home-system Star for a Force's Space Sandbox, if necessary
function SpaceExploration.GetOrCreatePlanetarySurfaceForForce(player, sandboxForce)
    if not SpaceExploration.enabled then
        return
    end

    local zoneName = global.sandboxForces[sandboxForce.name].sePlanetaryLabZoneName
    if zoneName == nil then
        zoneName = SpaceExploration.ChooseZoneForForce(player, sandboxForce, "moon")
        global.sandboxForces[sandboxForce.name].sePlanetaryLabZoneName = zoneName
        global.seSurfaces[zoneName] = {
            sandboxForceName = sandboxForce.name,
            daytime = 0.95,
            orbital = false,
        }
    end

    local surface = SpaceExploration.GetOrCreateSurface(zoneName)
    surface.generate_with_lab_tiles = true

    return surface
end

-- Chooses a non-home-system Star for a Force's Planetary Sandbox, if necessary
function SpaceExploration.GetOrCreateOrbitalSurfaceForForce(player, sandboxForce)
    if not SpaceExploration.enabled then
        return
    end

    local zoneName = global.sandboxForces[sandboxForce.name].seOrbitalSandboxZoneName
    if zoneName == nil then
        zoneName = SpaceExploration.ChooseZoneForForce(player, sandboxForce, "star")
        global.sandboxForces[sandboxForce.name].seOrbitalSandboxZoneName = zoneName
        global.seSurfaces[zoneName] = {
            sandboxForceName = sandboxForce.name,
            daytime = 0.95,
            orbital = true,
        }
    end

    local surface = SpaceExploration.GetOrCreateSurface(zoneName)
    surface.generate_with_lab_tiles = false

    return surface
end

-- Set a Sandbox's Daytime to a specific value
function SpaceExploration.SetDayTime(player, surface, daytime)
    if SpaceExploration.IsSandbox(surface) then
        surface.freeze_daytime = true
        surface.daytime = daytime
        global.seSurfaces[surface.name].daytime = daytime
        Events.SendDaylightChangedEvent(player.index, surface.name, daytime)
        return true
    else
        return false
    end
end

-- Reset the Space Sandbox a Player is currently in
function SpaceExploration.Reset(player)
    if not SpaceExploration.enabled then
        return
    end

    if SpaceExploration.IsSandbox(player.surface) then
        Debug.log("Resetting SE Sandbox: " .. player.surface.name)
        player.teleport({ 0, 0 }, player.surface.name)
        player.surface.clear(false)
        return true
    else
        Debug.log("Not a SE Sandbox, won't Reset: " .. player.surface.name)
        return false
    end
end

-- Return a Sandbox to the available Zones
function SpaceExploration.PreDeleteSandbox(sandboxForceData, zoneName)
    if not SpaceExploration.enabled or not zoneName then
        return
    end

    if global.seSurfaces[zoneName] then
        Debug.log("Pre-Deleting SE Sandbox: " .. zoneName)
        global.seSurfaces[zoneName] = nil
        if sandboxForceData.sePlanetaryLabZoneName == zoneName then
            sandboxForceData.sePlanetaryLabZoneName = nil
        end
        if sandboxForceData.seOrbitalSandboxZoneName == zoneName then
            sandboxForceData.seOrbitalSandboxZoneName = nil
        end
    else
        Debug.log("Not a SE Sandbox, won't Pre-Delete: " .. zoneName)
    end
end

-- Delete a Space Sandbox and return it to the available Zones
function SpaceExploration.DeleteSandbox(sandboxForceData, zoneName)
    if not SpaceExploration.enabled or not zoneName then
        return
    end

    if global.seSurfaces[zoneName] then
        SpaceExploration.PreDeleteSandbox(sandboxForceData, zoneName)
        Debug.log("Deleting SE Sandbox: " .. zoneName)
        game.delete_surface(zoneName)
        return true
    else
        Debug.log("Not a SE Sandbox, won't Delete: " .. zoneName)
        return false
    end
end

-- Add some helpful initial Entities to a Space Sandbox
function SpaceExploration.Equip(surface)
    if not SpaceExploration.enabled then
        return
    end

    local surfaceData = global.seSurfaces[surface.name]
    if not surfaceData then
        Debug.log("Not a SE Sandbox, won't Equip: " .. surface.name)
        return false
    end

    Debug.log("Equipping SE Sandbox: " .. surface.name)

    if (surfaceData.orbital) then
        -- Otherwise it will fill with Empty Space on top of the Tiles
        surface.request_to_generate_chunks({ x = 0, y = 0 }, 1)
        surface.force_generate_chunk_requests()

        local tiles = {}
        for y = -16, 16, 1 do
            for x = -16, 16, 1 do
                table.insert(tiles, {
                    name = "se-space-platform-scaffold",
                    position = { x = x, y = y }
                })
            end
        end
        surface.set_tiles(tiles)
    end

    electricInterface = surface.create_entity {
        name = "electric-energy-interface",
        position = { 0, 0 },
        force = surfaceData.sandboxForceName
    }
    electricInterface.minable = true

    bigPole = surface.create_entity {
        name = "big-electric-pole",
        position = { 0, -2 },
        force = surfaceData.sandboxForceName
    }
    bigPole.minable = true

    trashCan = surface.create_entity {
        name = "infinity-chest",
        position = { 0, 2 },
        force = surfaceData.sandboxForceName,
    }
    trashCan.remove_unfiltered_items = true
    trashCan.minable = true

    return true
end

--[[ Ensure that NavSat is not active
NOTE: This was not necessary in SE < 0.5.109 (the NavSat QoL Update)
Now, without this, the Inventory-differences after entering a Sandbox while
in the Navigation Satellite would be persisted, and without any good way
to undo that override.
--]]
function SpaceExploration.ExitRemoteView(player)
    if not SpaceExploration.enabled then
        return
    end
    remote.call(SpaceExploration.name, "remote_view_stop", { player = player })
end

return SpaceExploration
