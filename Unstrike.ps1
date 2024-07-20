Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$esc = [char]27
$batchFile = @"
@echo off
setlocal enabledelayedexpansion
title Unstrike 1.0 - legacyupdate.net

echo.
echo $esc[1;46;38m Unstrike $esc[m
echo.
echo This software is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. Use of this software is at your own risk.
echo.

:: Open a debug cmd window
start /min

:: Find the Windows volume
:retry
for %%i in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
	:: Check if the volume exists at all
	manage-bde -status %%i: >nul
	if %errorlevel% equ -1 (continue)

	:: Check if the volume contains Windows
	if exist %%i:\Windows\System32 (
		set winpart=%%i:
		goto :found
	) else (
		manage-bde -status %%i: | find "Locked" >nul
		if %errorlevel% equ 0 (
			echo.
			echo $esc[1;43;38m BitLocker $esc[m
			echo.
			echo %%i: is encrypted. Select an option:
			echo.
			echo  P: Enter startup password
			echo  R: Enter recovery key
			echo  S: Skip this volume
			echo.
			choice /c prs /m "Unlock method: "
			set unlockmethod=!errorlevel!
			if !unlockmethod! equ 1 (
				manage-bde -unlock %%i: -Password
				if exist %%i:\Windows\System32 (
					set winpart=%%i:
					goto :found
				) else (
					echo $esc[1;41;38m ERROR $esc[m
					echo Failed to unlock %%i:, or %%i: does not contain an installation of Windows.
					goto :retry
				)
			)
			if !unlockmethod! equ 2 (
				echo.
				echo Recovery key identification:
				manage-bde -protectors -get %%i: -type recoverypassword | find "ID:"
				echo.
				set /p "key=Enter the recovery key to unlock this volume: "
				manage-bde -unlock %%i: -RecoveryPassword "%key%"
				if exist %%i:\Windows\System32 (
					set winpart=%%i:
					goto :found
				) else (
					echo $esc[1;41;38m ERROR $esc[m
					echo Failed to unlock %%i:, or %%i: does not contain an installation of Windows.
					goto :retry
				)
			)
		)
	)
)

if not defined winpart (
	echo $esc[1;41;38m ERROR $esc[m
	echo Windows volume not found.
	pause
	exit /b 1
)

:found
echo.
echo Windows volume found at %winpart%

:: Verify that the volume is mounted
if not exist %winpart%\Windows\System32 (
	echo $esc[1;41;38m ERROR $esc[m
	echo Failed to mount the Windows volume.
	pause
	exit /b 1
)

:: Handle deleting problematic CrowdStrike files
if exist %winpart%\Windows\System32\drivers\CrowdStrike\C-00000291*.sys (
	del %winpart%\Windows\System32\drivers\CrowdStrike\C-00000291*.sys
)

:: Did it fail?
if exist %winpart%\Windows\System32\drivers\CrowdStrike\C-00000291*.sys (
	echo $esc[1;41;38m ERROR $esc[m
	echo Fix failed.
	pause
	exit /b 1
)

echo.
echo $esc[1;46;38m SUCCESS $esc[m
echo Disconnect the USB drive and press any key to restart.
pause
"@

$StatusLabel = $null

function Show-Dialog {
	[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
				xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
				Title="Unstrike"
				Width="500"
				SizeToContent="Height"
				ResizeMode="CanMinimize">
	<StackPanel Orientation="Vertical">
		<Grid Width="500" Height="65">
			<Rectangle Width="500" Height="65">
				<Rectangle.Fill>
					<LinearGradientBrush StartPoint="0, 0" EndPoint="1, 1">
						<GradientStop Color="White" Offset="0.0" />
						<GradientStop Color="#b6c5ee" Offset="1" />
					</LinearGradientBrush>
				</Rectangle.Fill>
			</Rectangle>

			<StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center">
				<TextBlock FontWeight="Medium" FontSize="35" TextAlignment="Center" VerticalAlignment="Center" LineHeight="1">
					Unstrike
				</TextBlock>
			</StackPanel>

			<Line X1="0" Y1="64" X2="500" Y2="64" Stroke="{DynamicResource {x:Static SystemColors.ControlLightBrushKey}}" StrokeThickness="0.5" />
		</Grid>

		<TextBlock Margin="15" TextWrapping="Wrap">
			Unstrike can automatically rescue a Windows 10 or 11 installation that has been affected by the 19 July 2024 CrowdStrike Falcon content update error. This tool will create a new ISO file that can be copied to a USB drive using software such as <Hyperlink x:Name="btnRufus">Rufus</Hyperlink>.
			<LineBreak />
			<LineBreak />
			To use it, provide the path to an original Windows 10 or 11 ISO file, and specify the destination for the new ISO file. For best results, the ISO should be the same or a later version to the affected versions of Windows needing rescue.
			<LineBreak />
			<LineBreak />
			<Span FontWeight="Medium">This software is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. Use of this software is at your own risk.</Span>
		</TextBlock>

		<StackPanel Orientation="Vertical" Margin="15, 0">
			<TextBlock FontWeight="SemiBold">Windows ISO:</TextBlock>

			<Grid Margin="0, 5, 0, 15">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="Auto" />
				</Grid.ColumnDefinitions>

				<TextBox x:Name="txtInputISO" Grid.Column="0" Margin="0, 0, 10, 0" />
				<Button x:Name="btnBrowseInput" Grid.Column="1" Width="75">Browse</Button>
			</Grid>

			<TextBlock FontWeight="SemiBold">Destination ISO:</TextBlock>

			<Grid Margin="0, 5, 0, 15">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="Auto" />
				</Grid.ColumnDefinitions>

				<TextBox x:Name="txtOutputISO" Grid.Column="0" Margin="0, 0, 10, 0" />
				<Button x:Name="btnBrowseOutput" Grid.Column="1" Width="75">Browse</Button>
			</Grid>

			<ProgressBar x:Name="progressBar" Height="18" Margin="0, 10" />
			<TextBlock x:Name="txtStatus" TextAlignment="Center">Idle</TextBlock>
		</StackPanel>

		<Canvas Height="50" Margin="0, 15, 0, 0">
			<Line X1="0" Y1="0" X2="500" Y2="0" Stroke="{DynamicResource {x:Static SystemColors.ControlLightBrushKey}}" StrokeThickness="0.5" />

			<Rectangle Width="500" Height="50" Fill="{DynamicResource {x:Static SystemColors.ControlBrushKey}}" />

			<Grid Width="455" Height="20" Canvas.Left="15" Canvas.Top="15">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto" />
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="Auto" />
					<ColumnDefinition Width="Auto" />
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Column="0">
					Unstrike 1.0 - <Hyperlink x:Name="btnLegacyUpdate">legacyupdate.net</Hyperlink>
				</TextBlock>

				<Button x:Name="btnOK" Grid.Column="2" Width="75" Margin="0, 0, 10, 0">OK</Button>
				<Button x:Name="btnCancel" Grid.Column="3" Width="75">Cancel</Button>
			</Grid>
		</Canvas>
	</StackPanel>
</Window>
"@

	$reader = (New-Object System.Xml.XmlNodeReader $xaml)
	$Window = [Windows.Markup.XamlReader]::Load($reader)

	$btnBrowseInput = $Window.FindName("btnBrowseInput")
	$btnBrowseOutput = $Window.FindName("btnBrowseOutput")
	$btnOK = $Window.FindName("btnOK")
	$btnCancel = $Window.FindName("btnCancel")
	$txtInputISO = $Window.FindName("txtInputISO")
	$txtOutputISO = $Window.FindName("txtOutputISO")
	$txtStatus = $Window.FindName("txtStatus")
	$progressBar = $Window.FindName("progressBar")
	$btnRufus = $Window.FindName("btnRufus")
	$btnLegacyUpdate = $Window.FindName("btnLegacyUpdate")

	$script:StatusLabel = $txtStatus

	$btnBrowseInput.Add_Click({
		$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$openFileDialog.Filter = "ISO files (*.iso)|*.iso"
		if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
			$txtInputISO.Text = $openFileDialog.FileName
		}
	})

	$btnBrowseOutput.Add_Click({
		$saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
		$saveFileDialog.Filter = "ISO files (*.iso)|*.iso"
		if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
			$txtOutputISO.Text = $saveFileDialog.FileName
		}
	})

	$btnOK.Add_Click({
		$Window.IsEnabled = $false
		$progressBar.IsIndeterminate = $true

		Create-RescueImage -InputISO $txtInputISO.Text -OutputISO $txtOutputISO.Text

		$Window.IsEnabled = $true
		$progressBar.IsIndeterminate = $false
	})

	$btnCancel.Add_Click({
		$Window.Close()
		[System.Windows.Threading.Dispatcher]::ExitAllFrames()
	})

	$btnRufus.Add_Click({
		Start-Process "https://rufus.ie/"
	})

	$btnLegacyUpdate.Add_Click({
		Start-Process "https://legacyupdate.net/unstrike"
	})

	$Window.Show()
	Write-Output "Unstrike started"
	[System.Windows.Threading.Dispatcher]::Run()
}

function Set-Status {
	Param(
		[string]$Text
	)

	Write-Output "$Text"

	if ($script:StatusLabel -ne $null) {
		$script:StatusLabel.Dispatcher.Invoke({
			$script:StatusLabel.Text = $Text
		})
	}
}

function Create-RescueImage {
	Param(
		[string]$InputISO,
		[string]$OutputISO
	)

	Remove-TempFiles

	Set-Status -Text "Processing..."

	# Validate inputs
	if ($InputISO -eq "") {
		Set-Status -Text "Please provide an input path."
		return
	}

	if ($OutputISO -eq "") {
		Set-Status -Text "Please provide an output path."
		return
	}

	if (-not (Test-Path (Split-Path $InputISO))) {
		Set-Status -Text "Invalid input path."
		return
	}

	if (-not (Test-Path (Split-Path $OutputISO))) {
		Set-Status -Text "Invalid output path."
		return
	}

	if (Test-Path $OutputISO) {
		Set-Status -Text "Output ISO already exists."
		return
	}

	# Check OS compatibility
	$osVersion = [System.Environment]::OSVersion.Version
	if (-not $env:WINDIR -or $osVersion.Major -ne 10) {
		Set-Status -Text "This tool requires Windows 10."
		return
	}

	if (-not (Test-Path "$env:WINDIR\SysWOW64")) {
		Set-Status -Text "This tool only supports 64-bit Windows."
		return
	}

	# Check for mkisofs.exe
	Set-Location -Path $PSScriptRoot
	$mkisofs = Join-Path -Path $PSScriptRoot -ChildPath "mkisofs.exe"
	if (-not (Test-Path $mkisofs)) {
		Set-Status -Text "mkisofs.exe not found. Make sure to extract all files before running the script."
		return
	}

	# Clean up temp files in case a previous run failed
	Remove-TempFiles -InputISO $InputISO

	# Mount the input ISO
	Set-Status -Text "Mounting ISO..."
	$mountResult = Mount-DiskImage -ImagePath $InputISO -PassThru
	$driveLetter = ($mountResult | Get-Volume).DriveLetter + ":"

	# Create a temp folder
	Set-Status -Text "Creating temporary directory..."
	$tempPath = Join-Path -Path $env:TEMP -ChildPath "UnstrikeTemp"
	if (Test-Path $tempPath) {
		Remove-TempFiles -InputISO $InputISO
		Remove-Item -Path $tempPath -Recurse
	}
	$tempFolder = New-Item -ItemType Directory -Path $tempPath

	# Copy files to temp folder
	foreach ($item in @("boot", "efi", "sources", "bootmgr", "bootmgr.efi")) {
		Set-Status -Text "Extracting $item..."

		if (Test-Path -Path "$driveLetter\$item" -PathType Container) {
			New-Item -ItemType Directory -Path (Join-Path -Path $tempFolder -ChildPath $item)
			Copy-Item -Path "$driveLetter\$item\*" -Destination (Join-Path -Path $tempFolder -ChildPath $item) -Recurse -Exclude install.wim,bootfix.bin
		} else {
			Copy-Item -Path "$driveLetter\$item" -Destination $tempFolder
		}
	}

	# Unmount ISO
	Set-Status -Text "Unmounting ISO..."
	Dismount-DiskImage -ImagePath $InputISO

	# Make boot.wim read-write
	$bootWim = Join-Path -Path $tempFolder -ChildPath "sources\boot.wim"
	$bootWimItem = Get-ChildItem -Path $bootWim
	$bootWimItem.Attributes = $bootWimItem.Attributes -band ([System.IO.FileAttributes]::ReadOnly -bxor 0xFFFFFFFF)

	# Mount boot.wim
	Set-Status -Text "Mounting boot.wim..."
	$mountDir = Join-Path -Path $env:TEMP -ChildPath "UnstrikeBootWim"
	New-Item -ItemType Directory -Path $mountDir
	& dism /Mount-Wim /WimFile:"$bootWim" /index:2 /MountDir:"$mountDir"

	# Check error
	if (-not $?) {
		Remove-TempFiles
		Set-Status -Text "Failed to mount boot.wim."
		return
	}

	# Write the script and set it to run on boot
	Set-Content -Path "$mountDir\Windows\System32\unstrike.cmd" -Value $batchFile

	$winpeshlContent = @"
[LaunchApp]
AppPath = %SYSTEMDRIVE%\Windows\System32\unstrike.cmd
"@
	Set-Content -Path (Join-Path -Path $mountDir -ChildPath "Windows\System32\winpeshl.ini") -Value $winpeshlContent

	# Copy choice.exe from running system
	Copy-Item -Path "$env:SystemRoot\System32\choice.exe" -Destination (Join-Path -Path $mountDir -ChildPath "Windows\System32")

	# Unmount and commit boot.wim
	Set-Status -Text "Unmounting boot.wim..."
	& dism /Unmount-Wim /MountDir:"$mountDir" /Commit

	# Check error
	if (-not $?) {
		Set-Status -Text "Failed to unmount boot.wim."
		return
	}

	Remove-Item -Path $mountDir -Recurse

	# Create the new ISO
	Set-Status -Text "Creating ISO..."
	& $mkisofs -iso-level 4 -l -R -udf -D -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -hide boot.catalog -eltorito-alt-boot -no-emul-boot -b efi/microsoft/boot/efisys_noprompt.bin -o "$outputISO" "$tempFolder"

	# Clean up temp folder
	Remove-TempFiles -InputISO $InputISO

	# Open in Explorer
	Set-Status -Text "Done"
	Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$outputISO`""
	$job | Stop-Job
	[System.Windows.Threading.Dispatcher]::ExitAllFrames()
	Exit
}

function Remove-TempFiles {
	Param(
		[string]$InputISO
	)

	Set-Status -Text "Cleaning up..."

	$tempFolder = Join-Path -Path $env:TEMP -ChildPath "UnstrikeTemp"
	$mountDir = Join-Path -Path $env:TEMP -ChildPath "UnstrikeBootWim"

	# Unmount ISO if still mounted
	if ($InputISO -ne $null -and $InputISO -ne "" -and (Test-Path $InputISO)) {
		Set-Status -Text "Unmounting ISO..."
		Dismount-DiskImage -ImagePath $InputISO
	}

	# Unmount and discard boot.wim
	if (Test-Path $mountDir) {
		Set-Status -Text "Unmounting boot.wim..."
		& dism /Unmount-Wim /MountDir:"$mountDir" /Discard
		Remove-Item -Path $mountDir -Recurse -Force
	}

	# Clean up temp folder
	if (Test-Path $tempFolder) {
		Set-Status -Text "Cleaning up temp files..."
		Remove-Item -Path $tempFolder -Recurse -Force
	}
}

# Elevate if needed
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Start-Process -FilePath "powershell.exe" -Verb runas -ArgumentList "-File `"$PSCommandPath`""
	Exit
}

Show-Dialog
# SIG # Begin signature block
# MIIRRgYJKoZIhvcNAQcCoIIRNzCCETMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDHnwscgfD94v+f
# SD5qVfHQbZ57QAg8/ZNkSYdUkHyqnqCCDYAwgga5MIIEoaADAgECAhEAmaOACiZV
# O2Wr3G6EprPqOTANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNV
# BAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBD
# ZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQg
# TmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIxOFowVjEL
# MAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEk
# MCIGA1UEAxMbQ2VydHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5cTbq96y34
# vuTmflN4mSAfgLKTvggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7VS5+djSo
# McbvIKck6+hI1shsylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1PH9ud0IF+
# njvMk2xqbNTIPsnWtw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOouu9Tj1yHI
# ohzuC8KNqfcYf7Z4/iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv8aGUsRda
# CtVD2bSlbfsq7BiqljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtMLK+Wo837
# Q4QOZgYqVWQ4x6cM7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9lDV2nT8m
# FSkcSkAExzd4prHwYjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/JHuurfTI
# 5XDYO962WZayx7ACFf5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkKbWpQ5bou
# fUnq1UiYPIAHlezf4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADaCi2JSplK
# ShBSND36E/ENVv8urPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAWd18Jx5n8
# 58JSqPECAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFN10
# XUwA23ufoHTKsW73PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbR
# Og79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAwBgNVHR8E
# KTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsG
# AQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVt
# LmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0
# bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6
# Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhYD+WPUCia
# U58Q7EP89DttyZqGYn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUStJl490L9
# 4C9LGF3vjzzH8Jq3iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChDUyuQy6rG
# DxLUUAsO0eqeLNhLVsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiRsWrhWM2f
# 8pXdd3x2mbJCKKtl2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7bWRLDm0Cd
# Y9rNLqyA3ahe8WlxVWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mATwZWwSD+B
# 7eMcZNhpn8zJ+6MTyE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3/bFAEloM
# U+vUBfSouCReZwSLo8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESYkOh1/w1t
# VxTpV2Na3PR7nxYVlPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR+x+zPF/2
# DaGgK2W1eEJfo2qyrBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C+xN4YaNj
# t2ywzOr+tKyEVAotnyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qwt4HOUBCr
# W602NCmvO1nm+/80nLy5r0AZvCQxaQ4wgga/MIIEp6ADAgECAhAPcTLyvIQuYKK3
# B8lNjSJJMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNp
# Z25pbmcgMjAyMSBDQTAeFw0yMzEwMDMxMDQ2MzZaFw0yNTEwMDIxMDQ2MzVaMGUx
# CzAJBgNVBAYTAkFVMRgwFgYDVQQIDA9Tb3V0aCBBdXN0cmFsaWExHTAbBgNVBAoM
# FEhhc2hiYW5nIFByb2R1Y3Rpb25zMR0wGwYDVQQDDBRIYXNoYmFuZyBQcm9kdWN0
# aW9uczCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMlNqwbinWbM8lnz
# zRhqBuPN2V6pjScrctxV8c9X/OO0pXtAb5io9N4uQ3HZikq5znfx83TFBQREs0dQ
# 7PEYOJC7otDEAKEzsCPTLGyq+7tjqbsI5JzsIsjnDooLMPZt3ZSGvpoIOdodPt5G
# jDfw4eCs9gxWvxVQdg/5zHBFE9PZ3dvSjb2NnYOjYte4nyZEtXVpwJ0qGGSYjFcX
# yrsawQsrMOKvN+AVKw/9h0FFugRnf8HvQkn5fFMvhizumJQ27+SXah1nWQSozgaB
# 2Y3mJZ0GHob5wJuxpkWKdBLGkw7CqEUePX/M8r5dEEiuVdwxvKqM7yfxpkJNaxBF
# NIYSxvnO91b7knaP6m91D4DboPvmpywexniXyvVLiuG131EW+T2a9KcC0rv1YPt5
# LsSsusCs8ruI816Q7HNy885qmk/6ZAeqgrwlM0qTHgDBgTWLJtjFi3B1z0XSj8DA
# SqDOHHg3CRQaKwirM/BNY1Iidn/kFo3nPBvPjmAa3iVYWxWDKQPMIRN3+xUWFdeu
# FGfHQTpjzlJ3/veZOyU64W5ieJCVuokUy4Gqic95Sttsw7OOD8Z1U7iks31m++ZB
# a4ALpL/uBZD7KotvmZ1e/FvvmZATFJJbG5AfT4NXZPrSm0XgzdU3uFwwIqnOYmrL
# oKQelA2mA7qKKNQ+wiXal77rJnwjAgMBAAGjggF4MIIBdDAMBgNVHRMBAf8EAjAA
# MD0GA1UdHwQ2MDQwMqAwoC6GLGh0dHA6Ly9jY3NjYTIwMjEuY3JsLmNlcnR1bS5w
# bC9jY3NjYTIwMjEuY3JsMHMGCCsGAQUFBwEBBGcwZTAsBggrBgEFBQcwAYYgaHR0
# cDovL2Njc2NhMjAyMS5vY3NwLWNlcnR1bS5jb20wNQYIKwYBBQUHMAKGKWh0dHA6
# Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9jY3NjYTIwMjEuY2VyMB8GA1UdIwQYMBaA
# FN10XUwA23ufoHTKsW73PMAywHDNMB0GA1UdDgQWBBRCuUJx0+YTECSgnp7C1QnE
# ytQgxDBLBgNVHSAERDBCMAgGBmeBDAEEATA2BgsqhGgBhvZ3AgUBBDAnMCUGCCsG
# AQUFBwIBFhlodHRwczovL3d3dy5jZXJ0dW0ucGwvQ1BTMBMGA1UdJQQMMAoGCCsG
# AQUFBwMDMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAMKGQ57nz
# hFzCdxsL8jcc+g8w62t9wV+PwGBy2gc3gaEdyDCdmEnKBH2gR3sileEtbq0uBWdM
# pe4YHjX6P8Hn4AgE0tkErjajns+eDknn/YvZbvMJTEMjlltB9H1qccqpuzJU2jHq
# 61+EtMv6WIXysUd2MAl14ap2r2BrSHzjgcx6Cu3Aos81Y7qbkz/1p2F9T9TSM0LI
# v7W+6OEdT+vmQOr2Fr0kvwo8xFeAyl+qTPfm8GnU8IBGkfFrZvNuChNhhNTE0uY/
# oEbFb/eWAzLs3yDqpqfTkhFGH65K6+xFCp1jgYfm2PNfSRk/OgaOVXvVtvupxSmg
# QajOmg71/AKmSsMmZgfUQikyKaK/XaBBE6hkNinkT+0w2Phzbgl7yoDagsdiqg7f
# 2cFaWJqwMvxX8OS0YZkUDnfiGoS4VH1apvQNbWlMp0VsU3v5tfwARgPpI2+KXQ+V
# Pd+0IL9O9OaaYX9UMpXJPN5qbgVG2IyDdQ4BSCLCumdcmZn5ZfKvwrGHknhLi4bt
# VUgSSw+VGuTKilABZzySNgKh6vw9MZQ50zaJZMq23pE6Mdm6jlCT4Vs9vD5TiV+9
# su4ohS1hRPLNDA/G84UVco0h8mlwRHc+HM4RpVMXajfEeVdyY9aGfwyhx08c6SlK
# Hea3eCELu3tWepL8if8cSO6uf/p9GC4uVTsxggMcMIIDGAIBATBqMFYxCzAJBgNV
# BAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNV
# BAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQQIQD3Ey8ryELmCitwfJTY0i
# STANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDmSyNoHc6i9HkOEUgdKAxzMM/bHvw6gL+3
# Y5op7U982jANBgkqhkiG9w0BAQEFAASCAgB5x24sqoZZehzTbXoX/c9t8x5q2XhL
# AwNPHfp/YNC9OpVNpPDUfxtR1bBIb3nJZghVHP/L8/b4Xb35KZZjcNxkjRmbqhRr
# VCVIQ2cA+/zfKJm6ICzUGxAsO/mr/PNJxtiVTSrkBR68aA9QmIbPlHSntYvGdyG7
# NgQbxc13XK435W62y6ZRbF34HgsStCeU158zkCx4g5WmnCvEZKEXUqavmizEOczK
# 8Sy4lqE4q4zBYi7gDP4s4svpKo1ghBwf6rLaowrxzJIJk9Kg0xEOhAZ/t4yM1Mr4
# ScjCwOyGmoUoaRwqLzui/15IJ9eMP2Af9pCgtWZdH4jAaEih7y9ivLsx4hVIMbY+
# C0+iKVjadIJZYZQqU9v52rReoBCJfWy+acktpm1VhWpgRuCOsamqxJenGNHaCzmF
# Ymf5/UkHmfN5KenCrT7/gJ/EZ7hKNTrdGpKqWaU9rhLRmTp78UF5USaGzj+76apZ
# MhycRKW3/CG9ducaU91T4auSHp8QantKDoVREglc7iq8h2tH42OVfRi4VMwlRXBZ
# XY1P0T73ujNrIg6SwpysAGPVmFzw75MTovZYx927YsaaJ1GYRcUYSRhBeR3MmdrI
# +Y/bcUSCZDXF6esDDa0qFrS8jK/52c5e7zVhmGye5QM1SfB4oNk7f/Dw2BqJED9K
# IPLEWnvzuQ6Wcw==
# SIG # End signature block
