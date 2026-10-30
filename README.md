# Manage your software in a repository

> [!NOTE]
> **AI Notice:** Parts of this repository (code, YAML package lists and documentation) were created or revised with the help of AI (Claude Code). All changes were reviewed by the author.

## PowerShell Software Manager

Interactive console menu to install, upgrade and deinstall your everyday software - so you never forget what you had on a fresh machine.

Supported package managers (one YAML each):

| Package manager | File | Platform |
|---|---|---|
| winget | `Software.winget.yaml` | Windows |
| npm | `Software.npm.yaml` | any |
| PowerShell modules | `Software.pwsh.yaml` | any |
| dnf | `Software.dnf.yaml` | Linux |

## Quickstart

Requires [PowerShell 7.2+](https://github.com/PowerShell/PowerShell). The modules `powershell-yaml` (and `Microsoft.WinGet.Client` for winget) are installed on first run.

```powershell
git clone https://github.com/LemurDaniel/PowerShell-Software-Manager-Script.git
cd PowerShell-Software-Manager-Script
./software-manager.ps1              # install / upgrade
./software-manager.ps1 -Deinstall   # deinstall
```

Controls: `↑`/`↓` select, `←`/`→` change page, type to search, `Enter` confirm, `Esc` cancel.

## Make it yours

Fork the repo and edit the YAMLs in [`functions/software/`](functions/software). Nothing else is needed.

### Add a package

```yaml
packages:
  - id: Git.Git            # package id of the package manager
    name: Git.Git          # shown in the menu
    info: Git version control
```

Find winget ids with `winget search <name>`.

### Group packages into categories

```yaml
packages:
  - category: Azure
    packages:
      - id: Microsoft.AzureCLI
        name: Microsoft.AzureCLI
```

### Per-package commands

Each package can override `install`, `update` or `deinstall`. Placeholders: `${id}`, `${name}`, `${version}`.

### Add another package manager

Create `functions/software/Software.<name>.yaml`. It is picked up automatically.

```yaml
id: mymanager
displayName: My Manager
description: What it manages

process:
  path: pwsh                 # executable that runs the commands
  args: [-NoProfile, -NonInteractive, -Command]
  commands:
    list:                    # must print JSON: [{ "id": "...", "version": "..." }]
      - ...
    install:
      - mytool install ${id}
    update:
      - mytool update ${id}
    deinstall:
      - mytool remove ${id}

packages:
  - id: some.package
    name: some.package
```

## Layout

```
software-manager.ps1                    entry point
functions/software/                     menu logic + package lists (*.yaml)
functions/input/                        console menu
```

## License

[MIT](LICENSE)
