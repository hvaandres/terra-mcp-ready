# Beginning Journey — Getting Started with terra-mcp-ready (GCP)

This folder contains everything you need to set up your environment for working with the Terraform modules in this repository.

## What you need

| Tool | Minimum | Recommended | Purpose |
|------|---------|-------------|---------|
| **Terraform** | >= 1.5 | 1.14.8 | Infrastructure as Code engine |
| **gcloud CLI** | >= 460.0.0 | latest | Google Cloud authentication and management |
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
- `terraform init` succeeds on the example modules
- `terraform validate` passes
- `terraform fmt -check` passes
- Test suite passes (`scripts/run_tests.sh`)

### 4. Capture your GCP env vars

```bash
./beginning_journey/setup_env.sh            # interactive
./beginning_journey/setup_env.sh --quiet    # auto-discover from gcloud config

# Then in every shell where you want them exported:
source beginning_journey/.env
```

This collects the values Terraform + gcloud need and writes them to `beginning_journey/.env` (gitignored). Source the file at the start of a session and `terraform plan/apply` against the example modules picks up your project, region, and zone without extra flags.

Collected values:

| Var | Purpose |
|---|---|
| `GOOGLE_PROJECT` / `GOOGLE_CLOUD_PROJECT` | Default project for the google provider |
| `GOOGLE_REGION` | Default region (e.g. `us-central1`) |
| `GOOGLE_ZONE` | Default zone (e.g. `us-central1-a`) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Optional path to a service-account key JSON (leave empty to use ADC) |
| `GOOGLE_BILLING_ACCOUNT` | Optional; used by `modules/project` |

Default source precedence for each value: **current shell > previously-saved `.env` > `gcloud config` > empty**. If you skip a prompt, the best-available default is used.

Why not auto-export? Scripts can't modify the parent shell's environment. You always have to `source` the file explicitly in each terminal (or add `source /path/to/beginning_journey/.env` to your `~/.zshrc`).

## GCP authentication

After tools are installed, log in to Google Cloud:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project "<YOUR_PROJECT_ID>"
```

To verify:

```bash
gcloud auth list
gcloud config list --format=json
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

**gcloud login issues**
If the browser-based flow fails, use a no-browser / device-code flow:
```bash
gcloud auth login --no-browser
```

**Application Default Credentials (ADC)**
The Terraform `google` provider reads ADC — not the user credentials set by `gcloud auth login`. You must run:
```bash
gcloud auth application-default login
```
to populate `~/.config/gcloud/application_default_credentials.json`, or set
`GOOGLE_APPLICATION_CREDENTIALS` to the path of a service-account key.
