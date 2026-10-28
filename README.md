# AutoSort — Free Windows File Organizer

AutoSort is a simple PowerShell script that organizes files into folders based on their file types.

## Features

- Organizes images, documents, videos, audio, archives, design files, and other files.
- Lets you select a folder using a window.
- Shows a preview before moving files.
- Skips files when a file with the same name already exists at the destination.
- Does not intentionally delete files.
- Requires no paid software.

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell.
- Basic familiarity with saving and running a script.

## How to use

1. Download `AutoSort.ps1` from this repository.
2. Test it first using a folder containing copies of your files.
3. Open PowerShell in the folder where you saved the script.
4. Run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\AutoSort.ps1"
   ```

5. Choose the folder you want to organize.
6. Review the preview carefully.
7. Confirm only if you are happy with the proposed changes.

## Important limitations

The current version organizes files directly inside one selected folder. It does not automatically scan the entire computer or search inside existing subfolders.

The script moves files after confirmation. Always back up important files and test with copies first.

## Safety

This is a PowerShell script, not an installer. Review the source code before running it. Do not run it as administrator, and do not disable Windows security protections to use it.

## Credits

Created as a free PC productivity project.
