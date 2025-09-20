# GitHub Actions Workflows

This directory contains GitHub Actions workflows for continuous integration and deployment:

## Workflows

### `ci.yml` - Continuous Integration

- **Triggers**: Push to main/feat branches, Pull Requests to main
- **Purpose**: Run all test suites automatically
- **Tests**: List (30), Recipe (9), Technology (23+) modules
- **Environment**: Ubuntu with Lua 5.4

### `qa.yml` - Quality Assurance

- **Triggers**: Push to main/feat branches, Pull Requests to main
- **Purpose**: Code quality checks and multi-version testing
- **Checks**:
  - Lua linting with luacheck
  - Documentation file validation
  - JSON file validation (.vscode configs, info.json)
  - Cross-platform testing (Lua 5.4 + LuaJIT)

### `release.yml` - Release Automation

- **Triggers**: Version tags (v*)
- **Purpose**: Automated releases with mod packaging
- **Steps**:
  - Full test suite validation
  - Version consistency checks
  - Factorio mod package creation
  - GitHub release with changelog extraction

## Development Workflow

1. **Development**: Work on feature branches
2. **Testing**: Tests run automatically on push
3. **Quality**: Linting and validation on PR
4. **Release**: Tag version → Automatic release creation

## Local Testing

Tests can still be run locally:

```bash
# Individual test suites
cd tests
lua test_list.lua
lua test_recipe.lua
lua test_technology.lua

# Or via VS Code tasks (Ctrl+Shift+P → "Tasks: Run Task")
```
