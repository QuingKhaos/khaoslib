-- Test file for khaoslib technology module
package.path = package.path .. ";tests/?.lua"
local luaunit = require('luaunit')
local test_utils = require('test_utils')

local khaoslib_technology = test_utils.load_module('technology')

-- Test suite
TestTechnologyModule = {}

function TestTechnologyModule:setUp()
  -- Reset data for each test
  data.raw.recipe = {}
  data.raw.technology = {}
end

function TestTechnologyModule:test_load_existing_technology()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    prerequisites = {"automation"},
    effects = {{type = "unlock-recipe", recipe = "iron-plate"}}
  }

  -- Test
  local tech = khaoslib_technology:load("test-tech")

  -- Assert
  luaunit.assertEquals(tech.technology.name, "test-tech")
  luaunit.assertEquals(#tech.technology.prerequisites, 1)
  luaunit.assertEquals(tech.technology.prerequisites[1], "automation")
end

function TestTechnologyModule:test_exists_utility_function()
  -- Setup
  data.raw.technology["existing-tech"] = {
    type = "technology",
    name = "existing-tech"
  }

  -- Test
  local exists = khaoslib_technology.exists("existing-tech")
  local not_exists = khaoslib_technology.exists("nonexistent-tech")

  -- Assert
  luaunit.assertTrue(exists)
  luaunit.assertFalse(not_exists)
end

function TestTechnologyModule:test_find_utility_function()
  -- Setup
  data.raw.technology["military-1"] = {name = "military-1", type = "technology"}
  data.raw.technology["military-2"] = {name = "military-2", type = "technology"}
  data.raw.technology["electronics"] = {name = "electronics", type = "technology"}

  -- Test
  local military_techs = khaoslib_technology.find(function(tech)
    return tech.name:match("^military%-")
  end)

  -- Assert
  luaunit.assertEquals(#military_techs, 2)
  luaunit.assertItemsEquals(military_techs, {"military-1", "military-2"})
end

function TestTechnologyModule:test_add_prerequisite()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    prerequisites = {}
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:add_prerequisite("automation")

  -- Assert
  luaunit.assertEquals(#tech.technology.prerequisites, 1)
  luaunit.assertEquals(tech.technology.prerequisites[1], "automation")
end

function TestTechnologyModule:test_add_unlock_recipe()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {}
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:add_unlock_recipe("iron-plate")

  -- Assert
  luaunit.assertEquals(#tech.technology.effects, 1)
  luaunit.assertEquals(tech.technology.effects[1].type, "unlock-recipe")
  luaunit.assertEquals(tech.technology.effects[1].recipe, "iron-plate")
end

function TestTechnologyModule:test_has_unlock_recipe()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {
      {type = "unlock-recipe", recipe = "iron-plate"},
      {type = "unlock-recipe", recipe = "copper-plate"}
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  local has_iron = tech:has_unlock_recipe("iron-plate")
  local has_steel = tech:has_unlock_recipe("steel-plate")

  -- Assert
  luaunit.assertTrue(has_iron)
  luaunit.assertFalse(has_steel)
end

function TestTechnologyModule:test_remove_unlock_recipe()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {
      {type = "unlock-recipe", recipe = "iron-plate"},
      {type = "unlock-recipe", recipe = "copper-plate"}
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:remove_unlock_recipe("iron-plate")

  -- Assert
  luaunit.assertEquals(#tech.technology.effects, 1)
  luaunit.assertEquals(tech.technology.effects[1].recipe, "copper-plate")
end

function TestTechnologyModule:test_method_chaining()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    prerequisites = {},
    effects = {}
  }

  -- Test method chaining
  local tech = khaoslib_technology:load("test-tech")
    :add_prerequisite("automation")
    :add_prerequisite("electronics")
    :add_unlock_recipe("iron-plate")
    :add_unlock_recipe("copper-plate")
    :set({unit = {count = 100, time = 30}})

  -- Assert
  luaunit.assertEquals(#tech.technology.prerequisites, 2)
  luaunit.assertEquals(#tech.technology.effects, 2)
  luaunit.assertEquals(tech.technology.unit.count, 100)
end

function TestTechnologyModule:test_copy_technology()
  -- Setup
  data.raw.technology["original-tech"] = {
    type = "technology",
    name = "original-tech",
    prerequisites = {"automation"},
    effects = {{type = "unlock-recipe", recipe = "iron-plate"}},
    unit = {count = 50, time = 15}
  }

  local original = khaoslib_technology:load("original-tech")

  -- Test
  local copy = original:copy("copied-tech")

  -- Assert
  luaunit.assertEquals(copy.technology.name, "copied-tech")
  luaunit.assertEquals(copy.technology.unit.count, 50)
  luaunit.assertEquals(#copy.technology.prerequisites, 1)
  luaunit.assertEquals(copy.technology.prerequisites[1], "automation")
end

-- Science pack manipulation tests
function TestTechnologyModule:test_get_science_packs_empty()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech"
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  local science_packs = tech:get_science_packs()

  -- Assert
  luaunit.assertEquals(#science_packs, 0)
end

function TestTechnologyModule:test_get_science_packs_with_data()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  local science_packs = tech:get_science_packs()

  -- Assert
  luaunit.assertEquals(#science_packs, 2)
  luaunit.assertEquals(science_packs[1][1], "automation-science-pack")
  luaunit.assertEquals(science_packs[1][2], 1)
  luaunit.assertEquals(science_packs[2][1], "logistic-science-pack")
  luaunit.assertEquals(science_packs[2][2], 1)
end

function TestTechnologyModule:test_add_science_pack_to_empty()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech"
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:add_science_pack({"automation-science-pack", 1})

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 1)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "automation-science-pack")
  luaunit.assertEquals(tech.technology.unit.ingredients[1][2], 1)
end

function TestTechnologyModule:test_add_science_pack_to_existing()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:add_science_pack({"logistic-science-pack", 1})

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[2][1], "logistic-science-pack")
end

function TestTechnologyModule:test_add_duplicate_science_pack_ignored()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test - try to add duplicate ingredient
  tech:add_science_pack({"automation-science-pack", 2})

  -- Assert - should still only have 1 ingredient
  luaunit.assertEquals(#tech.technology.unit.ingredients, 1)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][2], 1) -- Original amount preserved
end

function TestTechnologyModule:test_has_science_pack_by_name()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  local has_automation = tech:has_science_pack("automation-science-pack")
  local has_military = tech:has_science_pack("military-science-pack")

  -- Assert
  luaunit.assertTrue(has_automation)
  luaunit.assertFalse(has_military)
end

function TestTechnologyModule:test_has_science_pack_by_function()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 2}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  local has_high_amount = tech:has_science_pack(function(ingredient)
    return ingredient[2] > 1
  end)

  -- Assert
  luaunit.assertTrue(has_high_amount)
end

function TestTechnologyModule:test_remove_science_pack_by_name()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:remove_science_pack("automation-science-pack")

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 1)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "logistic-science-pack")
end

function TestTechnologyModule:test_remove_science_pack_by_function()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 2},
        {"military-science-pack", 3}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test - remove first ingredient with amount > 1
  tech:remove_science_pack(function(ingredient)
    return ingredient[2] > 1
  end)

  -- Assert - should remove logistic (first match)
  luaunit.assertEquals(#tech.technology.unit.ingredients, 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "automation-science-pack")
  luaunit.assertEquals(tech.technology.unit.ingredients[2][1], "military-science-pack")
end

function TestTechnologyModule:test_remove_all_science_packs()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 2},
        {"military-science-pack", 3}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test - remove all ingredients with amount > 1
  tech:remove_science_pack(function(ingredient)
    return ingredient[2] > 1
  end, {all = true})

  -- Assert - should remove both logistic and military
  luaunit.assertEquals(#tech.technology.unit.ingredients, 1)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "automation-science-pack")
end

function TestTechnologyModule:test_replace_science_pack_by_name()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:replace_science_pack("automation-science-pack", {"chemical-science-pack", 1})

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "chemical-science-pack")
  luaunit.assertEquals(tech.technology.unit.ingredients[2][1], "logistic-science-pack")
end

function TestTechnologyModule:test_replace_science_pack_by_function()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 2}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:replace_science_pack(function(ingredient)
    return ingredient[2] > 1
  end, {"military-science-pack", 1})

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][1], "automation-science-pack")
  luaunit.assertEquals(tech.technology.unit.ingredients[2][1], "military-science-pack")
end

function TestTechnologyModule:test_clear_science_packs()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  }

  local tech = khaoslib_technology:load("test-tech")

  -- Test
  tech:clear_science_packs()

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 0)
end

function TestTechnologyModule:test_science_pack_method_chaining()
  -- Setup
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    unit = {
      count = 100,
      time = 30,
      ingredients = {}
    }
  }

  -- Test method chaining
  local tech = khaoslib_technology:load("test-tech")
    :add_science_pack({"automation-science-pack", 1})
    :add_science_pack({"logistic-science-pack", 1})
    :replace_science_pack("automation-science-pack", {"automation-science-pack", 2})

  -- Assert
  luaunit.assertEquals(#tech.technology.unit.ingredients, 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[1][2], 2)
  luaunit.assertEquals(tech.technology.unit.ingredients[2][1], "logistic-science-pack")
end

-- Run the tests
os.exit(luaunit.LuaUnit.run())
