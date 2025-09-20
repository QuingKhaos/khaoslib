# Lua Unit Testing Setup for khaoslib

## Testing Infrastructure Status ✅

The Lua unit testing infrastructure has been successfully set up for khaoslib with
the following components:

### Files Created

- ✅ `.vscode/settings.json` - VS Code Lua language server configuration
- ✅ `.vscode/tasks.json` - Test execution tasks
- ✅ `.vscode/launch.json` - Debug configuration
- ✅ `luaunit.lua` - LuaUnit testing framework
- ✅ `tests/test_recipe.lua` - Comprehensive recipe module tests
- ✅ `tests/test_technology.lua` - Technology module tests
- ✅ `tests/test_list.lua` - List utility module tests

### VS Code Tasks Available

1. **Run Lua Tests** - Execute currently open test file
2. **Run All Tests** - Execute all tests in the tests folder
3. **Run Recipe Tests** - Execute recipe module tests specifically
4. **Run Technology Tests** - Execute technology module tests specifically
5. **Run List Tests** - Execute list utility module tests specifically

### To Use the Testing Infrastructure

#### Option 1: Via VS Code Command Palette

1. Press `Ctrl+Shift+P`
2. Type "Tasks: Run Task"
3. Select desired test task

#### Option 2: Via VS Code Task Runner

1. Press `Ctrl+Shift+P`
2. Type "Tasks: Run Test Task"
3. Choose from available test tasks

## Installing Lua (Required)

Since Lua is not currently installed on this system, you'll need to install it first:

### Method 1: Using Chocolatey (Recommended)

```powershell
# Install Chocolatey if not installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Lua
choco install lua
```

### Method 2: Manual Installation

1. Download Lua from: <https://luabinaries.sourceforge.net/download.html>
2. Choose "Windows Libraries/Executables" for your system architecture
3. Extract to a folder (e.g., `C:\lua`)
4. Add the folder to your PATH environment variable

### Method 3: Using Windows Package Manager (winget)

```powershell
winget install DEVCOM.Lua
```

## Running Tests After Lua Installation

Once Lua is installed, you can run tests using:

```powershell
# Run list tests
lua tests/test_list.lua

# Run specific test file
lua tests/test_recipe.lua

# Run technology tests
lua tests/test_technology.lua

# Or use VS Code tasks as described above
```

## Test Coverage

### Recipe Module Tests (`test_recipe.lua`)

- ✅ Module loading and initialization
- ✅ Ingredient manipulation (add, remove, replace)
- ✅ Technology unlock integration
- ✅ Method chaining validation
- ✅ Copy functionality
- ✅ Error handling and validation

### Technology Module Tests (`test_technology.lua`)

- ✅ Technology loading and existence checking
- ✅ Prerequisite management
- ✅ Recipe unlock effects
- ✅ Method chaining
- ✅ Copy functionality
- ✅ Utility functions (exists, find)

### List Module Tests (`test_list.lua`)

- ✅ `has()` function with string and function comparisons
- ✅ `add()` function with duplicate prevention and allowing duplicates
- ✅ `remove()` function with single and bulk removal
- ✅ `replace()` function with single and bulk replacement
- ✅ Deep copying validation for data safety
- ✅ Edge cases (nil lists, empty lists, complex objects)
- ✅ Error handling and parameter validation
- ✅ Integration tests and chained operations

All test suites include comprehensive mocking of the Factorio environment and proper
isolation between test cases.

## Next Steps

1. Install Lua using one of the methods above
2. Run the test suites to validate everything works
3. Expand test coverage as needed for additional modules
4. Use the testing infrastructure during development for TDD workflow

The testing infrastructure is complete and ready for use! 🎉
