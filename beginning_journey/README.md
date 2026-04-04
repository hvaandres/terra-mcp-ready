# Beginning Journey — Getting Started with terra-mcp-ready

This folder contains everything you need to set up your environment for working with the Terraform modules in this repository.

## What you need

| Tool | Minimum | Recommended | Purpose |
|------|---------|-------------|---------|
| **Terraform** | >= 1.5 | 1.14.8 | Infrastructure as Code engine |
| **Azure CLI** | >= 2.60 | 2.84.0 | Azure authentication and management |
| **jq** | >= 1.6 | 1.7+ | JSON processing (used by test scripts) |
| **Git** | >= 2.30 | latest | Version control |
| **Homebrew** | latest | latest | Package manager (macOS only) |

## Quick start

### 1. Check what you have

```bash
./beginning_journey/check_prerequisites.sh
```

This will scan your machine and report:
- ✓ Tools already installed at a compatible version
- ⬆ Tools that need upgrading
- ✗ Tools that are missing

### 2. Install or upgrade

```bash
./beginning_journey/install_tools.sh
```

Supports **macOS** (via Homebrew) and **Linux** (apt/yum). The script will:
- Install any missing tools
- Upgrade outdated tools to the latest stable version
- Skip tools that are already up to date

### 3. Verify everything works

```bash
./beginning_journey/verify_setup.sh
```

Runs an end-to-end check:
- All tools present and at the right versions
- `terraform init` succeeds on the example module
- `terraform validate` passes
- `terraform fmt -check` passes
- Test suite passes (`scripts/run_tests.sh`)

## Azure authentication

After tools are installed, log in to Azure:

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

To verify:

```bash
az account show --output table
```

## Upgrading Terraform

Your current Terraform version matters. Here's what each range gives you:

| Version | Key features available |
|---------|----------------------|
| **1.5.x** | `optional()` defaults, `endswith()`, `import` blocks |
| **1.6+** | Native test framework (`.tftest.hcl`), `terraform test` |
| **1.7+** | `removed` blocks, config-driven `import` |
| **1.9+** | `variable` validation in `terraform validate` |
| **1.14.x** | Latest stable — full feature set, all bug fixes |

We recommend **1.14.8** for the best experience. The `install_tools.sh` script handles the upgrade.

## Troubleshooting

**Homebrew not found (macOS)**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Permission denied on scripts**
```bash
chmod +x beginning_journey/*.sh scripts/*.sh
```

**Terraform version conflict with tfenv**
If you use `tfenv`, pin the version:
```bash
tfenv install 1.14.8
tfenv use 1.14.8
```

**Azure CLI login issues**
Try device-code flow if browser-based login fails:
```bash
az login --use-device-code
```
