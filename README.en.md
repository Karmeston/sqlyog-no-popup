# SQLyog No Popup

[简体中文](README.md) | **English**

Remove the **promotion popup shown when exiting SQLyog Community Edition**.

A single PowerShell script. No installation, compilation, or background process required. Supports restoring the original behavior.

## Usage

Close SQLyog, then run these commands in **Windows PowerShell 5.1**:

```powershell
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Karmeston/sqlyog-no-popup/v0.1.1/sqlyog-no-popup.ps1' -OutFile sqlyog-no-popup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply
```

The first command downloads the script; the second applies the patch. You can also download the script from [Releases](https://github.com/Karmeston/sqlyog-no-popup/releases).

The script finds your installation automatically. If it cannot find SQLyog or finds multiple installations, specify the executable with `-Path`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 apply -Path 'D:\SQLyog\SQLyogCommunity.exe'
```

## Restore

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sqlyog-no-popup.ps1 restore
```

To check the current state, replace `restore` with `status`. If you specified an installation path, use the same `-Path` when restoring.

## Supported versions

Official **64-bit Community Edition** builds:

- 13.1.6, 13.1.7, 13.1.8, 13.1.9
- 13.2.0, 13.2.1
- 13.3.0, 13.3.1

The script stops without making changes if the version is unsupported or the executable has other modifications.

## Notes

- The first application saves an original backup next to the executable. Existing backups are never overwritten.
- Applying and restoring can be repeated. Apply the patch again after upgrading SQLyog.
- If access is denied, open PowerShell as administrator and retry.

## License

[MIT](LICENSE). An unofficial tool. Does not include SQLyog itself or unlock commercial features.
