# AutoSort - Windows File Organizer
# Organizes files by type. Does not delete files or overwrite duplicates.
# Test with copies of your files before using it on important folders.

$ErrorActionPreference = "Stop"

try {
    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose a folder to organize"
    $dialog.ShowNewFolderButton = $false

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Cancelled. No files were changed."
        exit
    }

    $Source = $dialog.SelectedPath
    $Destination = Join-Path $Source "Sorted"

    # Safety check: avoid common Windows system folders.
    $ProtectedFolders = @(
        $env:WINDIR,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:ProgramData
    ) | Where-Object { $_ }

    foreach ($Protected in $ProtectedFolders) {
        if ($Source.TrimEnd('\') -ieq $Protected.TrimEnd('\')) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please choose a normal folder, not a Windows system folder.",
                "AutoSort - Safety Check"
            ) | Out-Null
            exit
        }
    }

    $Categories = @{
        ".jpg"="Images"; ".jpeg"="Images"; ".png"="Images"
        ".gif"="Images"; ".bmp"="Images"; ".webp"="Images"
        ".tif"="Images"; ".tiff"="Images"; ".heic"="Images"
        ".svg"="Images"; ".ico"="Images"

        ".pdf"="Documents"; ".doc"="Documents"; ".docx"="Documents"
        ".txt"="Documents"; ".rtf"="Documents"; ".odt"="Documents"
        ".xls"="Documents"; ".xlsx"="Documents"; ".csv"="Documents"
        ".ppt"="Documents"; ".pptx"="Documents"; ".epub"="Documents"

        ".mp4"="Videos"; ".mov"="Videos"; ".avi"="Videos"
        ".mkv"="Videos"; ".wmv"="Videos"; ".webm"="Videos"
        ".mpeg"="Videos"; ".mpg"="Videos"; ".m4v"="Videos"

        ".mp3"="Audio"; ".wav"="Audio"; ".m4a"="Audio"
        ".aac"="Audio"; ".flac"="Audio"; ".ogg"="Audio"
        ".wma"="Audio"; ".opus"="Audio"

        ".zip"="Archives"; ".7z"="Archives"; ".rar"="Archives"
        ".tar"="Archives"; ".gz"="Archives"

        ".psd"="Design"; ".ai"="Design"; ".eps"="Design"
        ".cdr"="Design"; ".indd"="Design"; ".xcf"="Design"

        ".exe"="Programs"; ".msi"="Programs"
        ".apk"="Programs"; ".bat"="Programs"
    }

    $Files = @(
        Get-ChildItem -LiteralPath $Source -File |
        Where-Object { $_.DirectoryName -ne $Destination }
    )

    if ($Files.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No files found directly inside the selected folder.",
            "AutoSort"
        ) | Out-Null
        exit
    }

    $Plan = foreach ($File in $Files) {
        $Extension = $File.Extension.ToLowerInvariant()

        if ($Categories.ContainsKey($Extension)) {
            $Category = $Categories[$Extension]
        }
        else {
            $Category = "Other"
        }

        $TargetFolder = Join-Path $Destination $Category
        $TargetPath = Join-Path $TargetFolder $File.Name

        [PSCustomObject]@{
            Name = $File.Name
            Category = $Category
            SourcePath = $File.FullName
            TargetFolder = $TargetFolder
            TargetPath = $TargetPath
        }
    }

    $Preview = (
        $Plan | Select-Object -First 20 | ForEach-Object {
            "$($_.Name)  ->  $($_.Category)"
        }
    ) -join "`r`n"

    if ($Plan.Count -gt 20) {
        $Preview += "`r`n...and $($Plan.Count - 20) more files."
    }

    $Message = @"
AutoSort will organize files inside:

$Source

A "Sorted" folder will be created with categories such as Images,
Documents, Videos, Audio, Archives, Design, Programs, and Other.

It will NOT delete files or overwrite files with the same name.
Subfolders will not be processed.

PREVIEW:
$Preview

Continue? Test on copies of files first.
"@

    $Answer = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "AutoSort - Review Before Moving",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($Answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "Cancelled. No files were changed."
        exit
    }

    $Moved = 0
    $Skipped = 0
    $Errors = 0

    foreach ($Item in $Plan) {
        try {
            # Skip files that already exist at the destination.
            if (Test-Path -LiteralPath $Item.TargetPath) {
                Write-Host "Skipped duplicate: $($Item.Name)" -ForegroundColor Yellow
                $Skipped++
                continue
            }

            if (-not (Test-Path -LiteralPath $Item.TargetFolder)) {
                New-Item -ItemType Directory `
                    -Path $Item.TargetFolder | Out-Null
            }

            # Recheck immediately before moving.
            if (Test-Path -LiteralPath $Item.TargetPath) {
                $Skipped++
                continue
            }

            Move-Item -LiteralPath $Item.SourcePath `
                -Destination $Item.TargetPath

            Write-Host "Organized: $($Item.Name)" -ForegroundColor Green
            $Moved++
        }
        catch {
            Write-Host "Could not move $($Item.Name): $($_.Exception.Message)" `
                -ForegroundColor Red
            $Errors++
        }
    }

    $Summary = @"
Organization complete!

Files moved: $Moved
Files skipped: $Skipped
Errors: $Errors

Your organized files are in:
$Destination
"@

    [System.Windows.Forms.MessageBox]::Show(
        $Summary,
        "AutoSort - Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "AutoSort stopped because of an error:`r`n$($_.Exception.Message)",
        "AutoSort - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}