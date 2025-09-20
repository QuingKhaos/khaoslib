# Debugging Guide for khaoslib

This guide covers debugging techniques for khaoslib development, including unit test debugging, module development debugging, and troubleshooting common issues.

## 🛠️ Prerequisites

Before debugging, ensure you have:

- ✅ Lua installed and accessible via `lua` command
- ✅ VS Code with required extensions:
  - `sumneko.lua` (Lua Language Server) - already installed
  - `tomblind.local-lua-debugger-vscode` (Local Lua Debugger) - already installed
  - `formulahendry.code-runner` (Code Runner) - already installed

## 🐛 Debugging Unit Tests

### Quick Test Execution (No Debugging)

#### Method 1: Using VS Code Tasks

1. Press `Ctrl+Shift+P`
2. Type "Tasks: Run Task"
3. Select from available tasks:
   - **Run All Tests** - Execute all test suites
   - **Run List Tests** - Execute `test_list.lua` only
   - **Run Recipe Tests** - Execute `test_recipe.lua` only
   - **Run Technology Tests** - Execute `test_technology.lua` only
   - **Run Current Test** - Execute currently open test file

#### Method 2: Using Code Runner

1. Open any test file (e.g., `tests/test_list.lua`)
2. Press `Ctrl+Alt+N` or right-click → "Run Code"
3. View output in integrated terminal

#### Method 3: Terminal Commands

```powershell
# Run specific test files
lua tests/test_list.lua
lua tests/test_recipe.lua
lua tests/test_technology.lua

# Or run from tests directory
cd tests
lua test_list.lua
```

### Interactive Debugging with Breakpoints

#### Setting Up Debug Session

1. **Set Breakpoints**:
   - Open test file in VS Code
   - Click in left margin next to line numbers (red dots appear)
   - Or place cursor on line and press `F9`

2. **Start Debugging**:
   - Press `F5` or go to Run & Debug panel (`Ctrl+Shift+D`)
   - Select debug configuration:
     - **Debug Current Lua Test File** - Debug active file
     - **Debug List Tests** - Debug list module tests
     - **Debug Recipe Tests** - Debug recipe module tests
     - **Debug Technology Tests** - Debug technology module tests
   - Click green play button or press `F5`

#### Debug Controls

| Action | Shortcut | Description |
|--------|----------|-------------|
| Continue | `F5` | Continue execution until next breakpoint |
| Step Over | `F10` | Execute current line, don't step into functions |
| Step Into | `F11` | Step into function calls |
| Step Out | `Shift+F11` | Step out of current function |
| Restart | `Ctrl+Shift+F5` | Restart debugging session |
| Stop | `Shift+F5` | Stop debugging session |

#### Debug Panels

- **Variables**: Inspect local and global variables at current breakpoint
- **Watch**: Add custom expressions to monitor (e.g., `#my_list`, `table.concat(items)`)
- **Call Stack**: View function call hierarchy
- **Debug Console**: Execute Lua commands during debugging

### Advanced Debugging Techniques

#### 1. Conditional Breakpoints

- Right-click on breakpoint → "Edit Breakpoint"
- Add condition: `i > 5` (only breaks when condition is true)
- Useful for loops: `#ingredients > 2`

#### 2. Logpoints

- Right-click in margin → "Add Logpoint"
- Add message: `"Processing item: {item.name}"`
- Logs output without stopping execution

#### 3. Debug Print Statements

```lua
-- Temporary debug output
print("Debug: Processing ingredient", ingredient.name)
print("Debug: List size before:", #my_list)
luaunit.assertEquals(expected, actual)
print("Debug: List size after:", #my_list)
```

#### 4. Table Inspection

```lua
-- Debug table contents
print("Debug: Table contents:")
for k, v in pairs(my_table) do
  print("  ", k, "=", v)
end

-- Or use utility function
local function debug_table(t, name)
  print("Debug table:", name or "unknown")
  if type(t) ~= "table" then
    print("  Not a table, type:", type(t), "value:", t)
    return
  end
  for k, v in pairs(t) do
    if type(v) == "table" then
      print("  ", k, "= <table>")
    else
      print("  ", k, "=", v)
    end
  end
end
```

## 🔧 Debugging Module Development

### Testing Individual Functions

#### Create Focused Test

```lua
-- Create a minimal test to focus on specific functionality
local test_utils = require('test_utils')
local khaoslib_list = test_utils.load_module('list')

-- Minimal test setup
local test_list = {"apple", "banana", "cherry"}

-- Debug the specific function
print("Before:", table.concat(test_list, ", "))
local result = khaoslib_list.has(test_list, "banana")
print("Result:", result)
print("After:", table.concat(test_list, ", "))
```

#### Debugging Module Loading Issues

If modules fail to load, check:

1. **Environment Detection**:

```lua
-- Add to top of module file for debugging
print("Debug: Module loading environment check")
print("  data type:", type(data))
print("  _G.util exists:", _G.util ~= nil)
print("  Module name (...):", ...)
```

2. **Dependency Loading**:

```lua
-- Debug dependency loading
print("Debug: Loading dependencies")
local success, module_loader = pcall(require, "module_loader")
if not success then
  print("Error loading module_loader:", module_loader)
else
  print("module_loader loaded successfully")
end
```

### Mock Environment Debugging

#### Verify Mock Setup

```lua
-- Add to test files to verify mocking
print("Debug: Mock environment check")
print("  data exists:", data ~= nil)
print("  data.raw exists:", data and data.raw ~= nil)
print("  util exists:", _G.util ~= nil)
print("  util.table.deepcopy exists:", _G.util and _G.util.table and _G.util.table.deepcopy ~= nil)
```

#### Test Mock Functions

```lua
-- Test mock functionality
local test_obj = {a = 1, b = {c = 2}}
local copied = _G.util.table.deepcopy(test_obj)
print("Original:", test_obj.b.c)
test_obj.b.c = 999
print("After modify original:", test_obj.b.c)
print("Copy still has:", copied.b.c) -- Should be 2
```

## 🚨 Common Issues & Solutions

### Issue 1: "module not found" Error

**Symptoms**:

```
lua.exe: module 'test_utils' not found
```

**Solutions**:

1. Check `package.path` is set correctly:

```lua
print("Package path:", package.path)
-- Should include ";tests/?.lua" or ";./?.lua"
```

2. Verify file exists and has correct name
3. Run from correct directory (project root)

### Issue 2: Mock Environment Not Working

**Symptoms**:

```
attempt to index a nil value (global 'data')
```

**Solutions**:

1. Ensure `test_utils.setup_test_environment()` is called
2. Check mock setup in test file:

```lua
-- Verify mocks are set up
assert(data, "data global not set up")
assert(_G.util, "_G.util not set up")
```

### Issue 3: Tests Pass Individually but Fail Together

**Symptoms**: Single test files pass, but running all tests fails

**Solutions**:

1. Check for test isolation issues:

```lua
function TestModule:setUp()
  -- Reset state between tests
  data.raw.recipe = {}
  data.raw.technology = {}
end
```

2. Look for global variable pollution
3. Check for module caching issues

### Issue 4: Debugger Not Stopping at Breakpoints

**Solutions**:

1. Verify Local Lua Debugger extension is installed and enabled
2. Check that `lua` command is in PATH
3. Restart VS Code
4. Try different debug configuration
5. Verify file paths in `launch.json` are correct

### Issue 5: Deep Copy Issues

**Symptoms**: Objects share references when they shouldn't

**Debug approach**:

```lua
-- Test deep copy behavior
local original = {items = {}}
local copy = util.table.deepcopy(original)

print("Before modification:")
print("  Original items:", #original.items)
print("  Copy items:", #copy.items)

table.insert(original.items, "test")

print("After modifying original:")
print("  Original items:", #original.items) -- Should be 1
print("  Copy items:", #copy.items)         -- Should still be 0
```

## 📊 Performance Debugging

### Timing Tests

```lua
-- Add timing to tests
local start_time = os.clock()
-- ... test code ...
local end_time = os.clock()
print("Test execution time:", end_time - start_time, "seconds")
```

### Memory Usage (Limited in Lua)

```lua
-- Basic memory tracking
local function get_memory_kb()
  return collectgarbage("count")
end

local mem_before = get_memory_kb()
-- ... test code ...
local mem_after = get_memory_kb()
print("Memory used:", mem_after - mem_before, "KB")
```

## 🎯 Best Practices

### 1. Incremental Debugging

- Start with the smallest failing test
- Add debug prints progressively
- Remove debug code before committing

### 2. Structured Debug Output

```lua
local DEBUG = true -- Toggle debug output

local function debug_print(...)
  if DEBUG then
    print("DEBUG:", ...)
  end
end

debug_print("Processing ingredient:", ingredient.name)
```

### 3. Test Data Validation

```lua
-- Validate test data before use
local function validate_test_recipe(recipe)
  assert(recipe, "Recipe is nil")
  assert(recipe.name, "Recipe missing name")
  assert(recipe.ingredients, "Recipe missing ingredients")
  assert(type(recipe.ingredients) == "table", "Ingredients not a table")
end
```

### 4. Error Context

```lua
-- Provide context in error messages
local function safe_add_ingredient(recipe, ingredient)
  if not recipe then
    error("Cannot add ingredient: recipe is nil")
  end
  if not ingredient then
    error("Cannot add ingredient to '" .. (recipe.name or "unnamed") .. "': ingredient is nil")
  end
  -- ... rest of function
end
```

## 🔄 Debugging Workflow

1. **Identify the Problem**
   - Run all tests to see which fail
   - Look at error messages and stack traces
   - Identify the specific failing assertion

2. **Isolate the Issue**
   - Run only the failing test
   - Add debug prints around the failing assertion
   - Check input data and expected vs actual values

3. **Deep Dive**
   - Set breakpoints in the failing test
   - Step through code to understand flow
   - Inspect variables at each step

4. **Fix and Verify**
   - Make the minimal fix needed
   - Run the specific test to verify fix
   - Run all tests to ensure no regressions

5. **Clean Up**
   - Remove debug prints
   - Remove unnecessary breakpoints
   - Document any complex fixes

## 📝 Debug Logging Template

Create a reusable debug logging system:

```lua
-- debug_logger.lua
local debug_logger = {}

local DEBUG_ENABLED = os.getenv("KHAOSLIB_DEBUG") == "1"

function debug_logger.log(category, message, ...)
  if DEBUG_ENABLED then
    local args = {...}
    local formatted_args = {}
    for i, arg in ipairs(args) do
      if type(arg) == "table" then
        formatted_args[i] = "<table>"
      else
        formatted_args[i] = tostring(arg)
      end
    end

    print(string.format("[DEBUG:%s] %s %s",
      category,
      message,
      table.concat(formatted_args, " ")
    ))
  end
end

return debug_logger
```

Usage:

```lua
local debug = require('debug_logger')

debug.log("LIST", "Adding item to list:", item.name)
debug.log("RECIPE", "Processing ingredient:", ingredient.type, ingredient.name)
```

Enable with: `set KHAOSLIB_DEBUG=1` (Windows) or `export KHAOSLIB_DEBUG=1` (Linux/Mac)

---

This debugging guide should help you efficiently identify and fix issues in khaoslib development. Remember: good debugging is systematic, patient, and methodical! 🎯
