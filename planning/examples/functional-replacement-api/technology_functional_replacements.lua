-- Technology Tree Transformation Examples
-- Demonstrates functional replacement patterns for technology prerequisites and requirements

local khaoslib_technology = require("__khaoslib__..technology")

-- Example 1: Dynamic Technology Tree Simplification
print("=== Example 1: Overhaul Mod Technology Simplification ===")

-- Simplify complex technology trees for overhaul mods like Pyanodons
local function create_prerequisite_simplifier(complexity_threshold)
    return function(prerequisite_name)
        local prereq_tech = data.raw.technology[prerequisite_name]

        if not prereq_tech then
            return prerequisite_name  -- Keep if technology doesn't exist
        end

        -- Calculate complexity based on prerequisite count and science pack requirements
        local complexity_score = #(prereq_tech.prerequisites or {})

        if prereq_tech.unit and prereq_tech.unit.ingredients then
            complexity_score = complexity_score + #prereq_tech.unit.ingredients
        end

        -- Replace overly complex prerequisites with simpler alternatives
        if complexity_score > complexity_threshold then
            local simplifications = {
                ["advanced-electronics-2"] = "electronics",
                ["chemical-science-pack"] = "military-science-pack",
                ["production-science-pack"] = "chemical-science-pack",
                ["utility-science-pack"] = "production-science-pack",
                ["space-science-pack"] = "utility-science-pack"
            }

            local simplified = simplifications[prerequisite_name]
            if simplified then
                print(string.format("  Simplified: %s -> %s (complexity: %d)",
                    prerequisite_name, simplified, complexity_score))
                return simplified
            end
        end

        return prerequisite_name  -- Keep original if not too complex
    end
end

-- Apply technology tree simplification
local target_technologies = {
    "advanced-electronics-2",
    "rocket-fuel",
    "low-density-structure",
    "rocket-control-unit",
    "satellite"
}

for _, tech_name in ipairs(target_technologies) do
    if data.raw.technology[tech_name] then
        print("Simplifying technology: " .. tech_name)

        khaoslib_technology:load(tech_name)
            :replace_prerequisite("advanced-electronics-2", create_prerequisite_simplifier(4))
            :replace_prerequisite("chemical-science-pack", create_prerequisite_simplifier(4))
            :replace_prerequisite("production-science-pack", create_prerequisite_simplifier(6))
            :commit()
    end
end

-- Example 2: Science Pack Cost Rebalancing
print("\n=== Example 2: Science Pack Cost Optimization ===")

-- Reduce science pack costs for early game accessibility
local function create_science_cost_reducer(reduction_factor)
    return function(science_ingredient)
        local original_amount = science_ingredient.amount
        science_ingredient.amount = math.max(1, math.floor(original_amount * reduction_factor))

        print(string.format("  Reduced %s: %d -> %d (%.1f%% reduction)",
            science_ingredient.name,
            original_amount,
            science_ingredient.amount,
            (1 - reduction_factor) * 100))

        return science_ingredient
    end
end

-- Apply cost reduction to expensive research
local expensive_research = {
    "advanced-electronics-2",
    "rocket-fuel",
    "kovarex-enrichment-process",
    "space-science-pack"
}

for _, tech_name in ipairs(expensive_research) do
    if data.raw.technology[tech_name] then
        print("Reducing costs for: " .. tech_name)

        khaoslib_technology:load(tech_name)
            :replace_unit_ingredient("chemical-science-pack", create_science_cost_reducer(0.6))
            :replace_unit_ingredient("production-science-pack", create_science_cost_reducer(0.4))
            :replace_unit_ingredient("utility-science-pack", create_science_cost_reducer(0.3))
            :commit()
    end
end

-- Example 3: Conditional Technology Gating
print("\n=== Example 3: Smart Technology Gate Management ===")

-- Remove technology gates that don't make sense in certain mod combinations
local function create_conditional_gate_remover(mod_conditions)
    return function(prerequisite_name)
        -- Check if certain mods are loaded that change the logic
        for mod_name, condition in pairs(mod_conditions) do
            if mods[mod_name] and condition.remove_gates then
                local gates_to_remove = condition.remove_gates

                for _, gate in ipairs(gates_to_remove) do
                    if prerequisite_name == gate then
                        print(string.format("  Removed gate %s due to mod %s", gate, mod_name))
                        return nil  -- Remove this prerequisite entirely
                    end
                end
            end
        end

        return prerequisite_name  -- Keep original prerequisite
    end
end

-- Define mod-specific gating logic
local mod_conditions = {
    ["pyanodon"] = {
        remove_gates = {"advanced-electronics-2", "chemical-science-pack"},
        reason = "Pyanodons has different progression"
    },
    ["bobsmods"] = {
        remove_gates = {"production-science-pack"},
        reason = "Bob's mods restructure production chains"
    },
    ["angelsmods"] = {
        remove_gates = {"oil-processing"},
        reason = "Angel's refining changes oil processing completely"
    }
}

-- Apply conditional gate removal
local gated_technologies = {
    "advanced-electronics-2",
    "rocket-fuel",
    "kovarex-enrichment-process"
}

for _, tech_name in ipairs(gated_technologies) do
    if data.raw.technology[tech_name] then
        print("Applying conditional gates for: " .. tech_name)

        khaoslib_technology:load(tech_name)
            :replace_prerequisite("advanced-electronics-2", create_conditional_gate_remover(mod_conditions))
            :replace_prerequisite("chemical-science-pack", create_conditional_gate_remover(mod_conditions))
            :replace_prerequisite("production-science-pack", create_conditional_gate_remover(mod_conditions))
            :commit()
    end
end

-- Example 4: Progressive Research Scaling
print("\n=== Example 4: Adaptive Research Complexity ===")

-- Scale research requirements based on technology tier
local function create_adaptive_research_scaler(player_progress_level)
    return function(science_ingredient)
        local science_tiers = {
            ["automation-science-pack"] = 1,
            ["logistic-science-pack"] = 2,
            ["military-science-pack"] = 2,
            ["chemical-science-pack"] = 3,
            ["production-science-pack"] = 4,
            ["utility-science-pack"] = 5,
            ["space-science-pack"] = 6
        }

        local ingredient_tier = science_tiers[science_ingredient.name] or 3
        local original_amount = science_ingredient.amount

        -- Scale based on player progress vs ingredient tier
        local scale_factor = 1.0
        if ingredient_tier > player_progress_level then
            -- Reduce requirements for advanced science packs
            scale_factor = math.max(0.3, 1.0 - (ingredient_tier - player_progress_level) * 0.2)
        elseif ingredient_tier < player_progress_level then
            -- Slightly increase basic science pack requirements
            scale_factor = 1.0 + (player_progress_level - ingredient_tier) * 0.1
        end

        science_ingredient.amount = math.max(1, math.floor(original_amount * scale_factor))

        if scale_factor != 1.0 then
            print(string.format("  Scaled %s: %d -> %d (tier %d, progress %d)",
                science_ingredient.name, original_amount, science_ingredient.amount,
                ingredient_tier, player_progress_level))
        end

        return science_ingredient
    end
end

-- Apply adaptive scaling based on different progression scenarios
local progression_scenarios = {
    early_game = {level = 2, technologies = {"military", "automation-2", "logistic-science-pack"}},
    mid_game = {level = 4, technologies = {"chemical-science-pack", "advanced-electronics", "rocket-fuel"}},
    late_game = {level = 6, technologies = {"kovarex-enrichment-process", "space-science-pack", "satellite"}}
}

for scenario_name, scenario in pairs(progression_scenarios) do
    print(string.format("Applying %s progression scaling (level %d):", scenario_name, scenario.level))

    for _, tech_name in ipairs(scenario.technologies) do
        if data.raw.technology[tech_name] then
            khaoslib_technology:load(tech_name)
                :replace_unit_ingredient("chemical-science-pack", create_adaptive_research_scaler(scenario.level))
                :replace_unit_ingredient("production-science-pack", create_adaptive_research_scaler(scenario.level))
                :replace_unit_ingredient("utility-science-pack", create_adaptive_research_scaler(scenario.level))
                :replace_unit_ingredient("space-science-pack", create_adaptive_research_scaler(scenario.level))
                :commit()
        end
    end
end

-- Example 5: Zero-Argument Performance Optimization for Technology
print("\n=== Example 5: High-Performance Technology Batch Processing ===")

-- Pre-computed technology transformations for zero-argument optimization
local tech_transformations = {
    -- Pyanodons technology simplification
    pyanodons_compat = {
        prerequisites = {
            ["advanced-electronics-2"] = "electronics",
            ["chemical-science-pack"] = "military-science-pack",
            ["production-science-pack"] = "chemical-science-pack"
        },
        science_costs = {
            ["chemical-science-pack"] = {name = "chemical-science-pack", amount = 50},
            ["production-science-pack"] = {name = "production-science-pack", amount = 75},
            ["utility-science-pack"] = {name = "utility-science-pack", amount = 25}
        }
    }
}

-- Zero-argument callback factories for maximum performance
local function create_zero_arg_prerequisite_replacer(transformation_name, prerequisite_name)
    local replacement = tech_transformations[transformation_name].prerequisites[prerequisite_name]

    return function()
        -- Zero arguments = no deepcopy overhead (94% performance improvement)
        return replacement
    end
end

local function create_zero_arg_science_replacer(transformation_name, science_name)
    local replacement = tech_transformations[transformation_name].science_costs[science_name]

    return function()
        -- Zero arguments = no deepcopy overhead
        return {
            type = "item",
            name = replacement.name,
            amount = replacement.amount
        }
    end
end

-- Apply high-performance bulk technology transformations
local processed_tech_count = 0

for tech_name, _ in pairs(data.raw.technology) do
    -- Apply to technologies that match certain patterns
    if string.find(tech_name, "advanced") or string.find(tech_name, "rocket") or string.find(tech_name, "space") then
        processed_tech_count = processed_tech_count + 1

        -- Apply prerequisite simplifications
        for prerequisite_name, _ in pairs(tech_transformations.pyanodons_compat.prerequisites) do
            khaoslib_technology:load(tech_name)
                :replace_prerequisite(prerequisite_name,
                    create_zero_arg_prerequisite_replacer("pyanodons_compat", prerequisite_name))
                :commit()
        end

        -- Apply science cost reductions
        for science_name, _ in pairs(tech_transformations.pyanodons_compat.science_costs) do
            khaoslib_technology:load(tech_name)
                :replace_unit_ingredient(science_name,
                    create_zero_arg_science_replacer("pyanodons_compat", science_name))
                :commit()
        end
    end
end

print(string.format("Applied high-performance transformations to %d technologies", processed_tech_count))

print("\n=== Technology Functional Replacement Examples Completed ===")
print("These examples demonstrate advanced technology transformation patterns:")
print("1. Dynamic prerequisite simplification based on complexity analysis")
print("2. Science pack cost optimization with configurable reduction factors")
print("3. Conditional technology gate removal based on mod compatibility")
print("4. Adaptive research scaling based on player progression levels")
print("5. Zero-argument performance optimization for bulk technology processing")
print("\nThese patterns enable sophisticated mod compatibility and game balance adjustments")
