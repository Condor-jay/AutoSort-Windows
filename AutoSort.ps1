
# AutoSort v2.0
# Organize files from multiple common Windows folders.
# Review the preview before confirming any file moves.

$ErrorActionPreference = "Stop"

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Find common Windows folders.
    $FolderOptions = @(
        [PSCustomObject]@{
            Name = "Desktop"
            Path = [Environment]::GetFolderPath("Desktop")
        }
        [PSCustomObject]@{
            Name = "Downloads"
            Path = (Join-Path $HOME "Downloads")
        }
        [PSCustomObject]@{
            Name = "Documents"
            Path = [Environment]::GetFolderPath("MyDocuments")
        }
        [PSCustomObject]@{
            Name = "Pictures"
            Path = [Environment]::GetFolderPath("MyPictures")
        }
        [PSCustomObject]@{
            Name = "Music"
            Path = [Environment]::GetFolderPath("MyMusic")
        }
        [PSCustomObject]@{
            Name = "Videos"
            Path = [Environment]::GetFolderPath("MyVideos")
        }
    ) | Where-Object {
        $_.Path -and (Test-Path -LiteralPath $_.Path -PathType Container)
    }

    # File type categories.
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

        ".exe"="Programs"; ".msi"="Programs"; ".apk"="Programs"
    }

    # Choose locations in a window.
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "AutoSort - Choose folders"
    $Form.Size = New-Object System.Drawing.Size(470, 420)
    $Form.StartPosition = "CenterScreen"
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false

    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = "Select the folders you want AutoSort to organize:"
    $Label.Location = New-Object System.Drawing.Point(18, 18)
    $Label.Size = New-Object System.Drawing.Size(420, 28)
    $Form.Controls.Add($Label)

    $List = New-Object System.Windows.Forms.CheckedListBox
    $List.Location = New-Object System.Drawing.Point(20, 55)
    $List.Size = New-Object System.Drawing.Size(410, 220)
    $List.CheckOnClick = $true
    $List.DisplayMember = "Name"

    foreach ($Option in $FolderOptions) {
        [void]$List.Items.Add($Option, $false)
    }
    $Form.Controls.Add($List)

    $Note = New-Object System.Windows.Forms.Label
    $Note.Text = "Files directly inside selected folders are organized. Existing subfolders are left alone."
    $Note.Location = New-Object System.Drawing.Point(20, 285)
    $Note.Size = New-Object System.Drawing.Size(410, 42)
    $Form.Controls.Add($Note)

    $RunButton = New-Object System.Windows.Forms.Button
    $RunButton.Text = "Preview files"
    $RunButton.Location = New-Object System.Drawing.Point(220, 335)
    $RunButton.Size = New-Object System.Drawing.Size(105, 30)
    $RunButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $Form.Controls.Add($RunButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Text = "Cancel"
    $CancelButton.Location = New-Object System.Drawing.Point(330, 335)
    $CancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Form.Controls.Add($CancelButton)

    $Form.AcceptButton = $RunButton
    $Form.CancelButton = $CancelButton

    $Choice = $Form.ShowDialog()
    if ($Choice -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Cancelled. No files were changed."
        exit
    }

    $SelectedFolders = @($List.CheckedItems)
    if ($SelectedFolders.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Select at least one folder.",
            "AutoSort"
        ) | Out-Null
        exit
    }

    # Build the plan without moving anything.
    $Plan = @()
    $Ignored = 0

    foreach ($Folder in $SelectedFolders) {
        $Files = @(Get-ChildItem -LiteralPath $Folder.Path -File)

        foreach ($File in $Files) {
            # Keep common shortcuts and system metadata in place.
            if ($File.Extension -in @(".lnk", ".url") -or
                $File.Name -ieq "desktop.ini" -or
                $File.Name -ieq "AutoSort.ps1") {
                $Ignored++
                continue
            }

            $Extension = $File.Extension.ToLowerInvariant()
            if ($Categories.ContainsKey($Extension)) {
                $Category = $Categories[$Extension]
            }
            else {
                $Category = "Other"
            }

            $SortedRoot = Join-Path $Folder.Path "Sorted"
            $TargetFolder = Join-Path $SortedRoot $Category
            $TargetPath = Join-Path $TargetFolder $File.Name

            $Plan += [PSCustomObject]@{
                Name = $File.Name
                From = $File.FullName
                FolderName = $Folder.Name
                TargetFolder = $TargetFolder
                TargetPath = $TargetPath
            }
        }
    }

    if ($Plan.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No eligible files were found in the selected folders.",
            "AutoSort"
        ) | Out-Null
        exit
    }

    # Show a preview and ask for confirmation.
    $PreviewLines = @(
        $Plan | Select-Object -First 22 | ForEach-Object {
            "$($_.FolderName): $($_.Name) -> Sorted\$(
                Split-Path $_.TargetFolder -Leaf
            )"
        }
    )

    $Preview = $PreviewLines -join "`r`n"
    if ($Plan.Count -gt 22) {
        $Preview += "`r`n...and $($Plan.Count - 22) more files."
    }

    $Message = @"
AutoSort found $($Plan.Count) file(s) to organize.
Ignored shortcuts/system metadata: $Ignored

PREVIEW:
$Preview

Files will be moved into a "Sorted" folder inside each selected location.
Existing subfolders will not be scanned.
Files with destination name conflicts will be skipped.
Continue? Test on copies first.
"@

    $Answer = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "AutoSort - Confirm changes",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($Answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "Cancelled. No files were changed."
        exit
    }

    # Move only after confirmation.
    $Moved = 0
    $Skipped = 0
    $Errors = 0

    foreach ($Item in $Plan) {
        try {
            # Never overwrite an existing destination file.
            if (Test-Path -LiteralPath $Item.TargetPath) {
                $Skipped++
                continue
            }

            if (-not (Test-Path -LiteralPath $Item.TargetFolder)) {
                New-Item -ItemType Directory `
                    -Path $Item.TargetFolder | Out-Null
            }

            # Recheck just before moving.
            if (Test-Path -LiteralPath $Item.TargetPath) {
                $Skipped++
                continue
            }

            Move-Item -LiteralPath $Item.From `
                -Destination $Item.TargetPath -ErrorAction Stop

            $Moved++
        }
        catch {
            Write-Host "Could not move $($Item.Name): $($_.Exception.Message)" `
                -ForegroundColor Red
            $Errors++
        }
    }

    $Summary = @"
AutoSort finished!

Files moved: $Moved
Files skipped: $Skipped
Errors: $Errors

Check the "Sorted" folder inside each selected location.
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

    Write-Host $_.Exception.Message -ForegroundColor Red
}
