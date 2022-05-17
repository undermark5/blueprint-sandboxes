PlannerIcons = require("scripts.planner-icons")
Resources = require("scripts.resources")

-- Helpers for Resource Planners
function shouldSkipResourcePlanner(resource)
    return resource.category == "se-core-mining"
end

function createResourcePlannerPrototypes(resource)
    -- First, find a way to name the Planner based on the mining result
    local localisedName
    if resource.minable.result then
        localisedName = { "item-name." .. resource.minable.result }
    elseif resource.minable.results then
        local firstResult = resource.minable.results[1]
        if firstResult then
            if firstResult.type == "item" then
                localisedName = { "item-name." .. firstResult.name }
            elseif firstResult.type == "fluid" then
                localisedName = { "fluid-name." .. firstResult.name }
            end
        end
    end

    -- Finally, create the Selection Tool and its Recipe
    return {
        {
            type = "selection-tool",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            icons = PlannerIcons.CreateLayeredIcon(resource),
            subgroup = Resources.name,
            order = resource.order,
            stack_size = 1,
            stackable = false,
            selection_color = { r = 0, g = 1, b = 0 },
            alt_selection_color = { r = 1, g = 0, b = 0 },
            selection_mode = { "any-tile" },
            alt_selection_mode = { "any-entity" },
            selection_cursor_box_type = "pair",
            alt_selection_cursor_box_type = "pair",
            alt_entity_filters = { resource.name },
            always_include_tiles = true,
        },
        {
            type = "recipe",
            name = Resources.pfx .. resource.name,
            localised_name = localisedName,
            energy_required = 1,
            enabled = false,
            ingredients = {},
            result = Resources.pfx .. resource.name,
            hide_from_stats = true,
        }
    }
end

-- New Items/Recipes for Resource Planners
for _, resource in pairs(data.raw.resource) do
    -- Some Resources are better left alone
    if not shouldSkipResourcePlanner(resource) then
        data:extend(createResourcePlannerPrototypes(resource))
    end
end