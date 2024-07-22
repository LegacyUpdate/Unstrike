Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

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
	if %errorlevel% equ -1 continue

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

$winpeshlIni = @"
[LaunchApp]
AppPath = %SYSTEMDRIVE%\unstrike.cmd
"@

$mkisofs = "$PSScriptRoot\mkisofs.exe"

$Window = $null
$Progress = 0

function Show-Dialog {
	[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
				xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
				Title="Unstrike"
				Width="500"
				SizeToContent="Height"
				ResizeMode="CanMinimize"
				WindowStartupLocation="CenterScreen">
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

			<TextBlock FontWeight="Medium" FontSize="35" TextAlignment="Center" VerticalAlignment="Center">
				Unstrike
			</TextBlock>
		</Grid>

		<Line X2="500" Stroke="{DynamicResource {x:Static SystemColors.ControlLightBrushKey}}" StrokeThickness="1" />

		<TextBlock Margin="15" TextWrapping="Wrap">
			Unstrike can automatically rescue a Windows installation that has been affected by the 19 July 2024 CrowdStrike Falcon content update error. This tool will create a new ISO file that can be copied to a USB drive using software such as <Hyperlink x:Name="btnRufus">Rufus</Hyperlink>.
			<LineBreak />
			<LineBreak />
			Provide the path to an original Windows installation ISO file, and specify the destination for the new ISO file. The ISO should be the same or greater version to the affected versions of Windows needing rescue. For further instructions, visit <Hyperlink x:Name="btnUnstrike">legacyupdate.net/unstrike</Hyperlink>.
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

			<Grid Margin="0, 5, 0, 0">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="Auto" />
				</Grid.ColumnDefinitions>

				<TextBox x:Name="txtOutputISO" Grid.Column="0" Margin="0, 0, 10, 0" />
				<Button x:Name="btnBrowseOutput" Grid.Column="1" Width="75">Browse</Button>
			</Grid>
		</StackPanel>

		<TextBlock Margin="15" TextWrapping="Wrap" FontWeight="Medium">
			This software is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. Use of this software is at your own risk.
		</TextBlock>

		<Line X2="500" Stroke="{DynamicResource {x:Static SystemColors.ControlLightBrushKey}}" StrokeThickness="1" />

		<Canvas Height="50" Background="{DynamicResource {x:Static SystemColors.ControlBrushKey}}">
			<Grid Width="455" Height="20" Canvas.Left="15" Canvas.Top="15">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto" />
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="Auto" />
					<ColumnDefinition Width="Auto" />
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Column="0">
					Unstrike 1.0.1 - <Hyperlink x:Name="btnLegacyUpdate">legacyupdate.net</Hyperlink>
				</TextBlock>

				<Button x:Name="btnBuild" Grid.Column="2" Width="75" Margin="0, 0, 10, 0">Build</Button>
				<Button x:Name="btnCancel" Grid.Column="3" Width="75">Cancel</Button>
			</Grid>
		</Canvas>
	</StackPanel>
</Window>
"@

	$reader = New-Object System.Xml.XmlNodeReader $xaml
	$Window = [Windows.Markup.XamlReader]::Load($reader)

	$btnBrowseInput = $Window.FindName("btnBrowseInput")
	$btnBrowseOutput = $Window.FindName("btnBrowseOutput")
	$btnBuild = $Window.FindName("btnBuild")
	$btnCancel = $Window.FindName("btnCancel")
	$txtInputISO = $Window.FindName("txtInputISO")
	$txtOutputISO = $Window.FindName("txtOutputISO")
	$btnRufus = $Window.FindName("btnRufus")
	$btnLegacyUpdate = $Window.FindName("btnLegacyUpdate")
	$btnUnstrike = $Window.FindName("btnUnstrike")

	$script:Window = $Window

	$Window.Add_Closing({
		Remove-TempFiles
		[System.Windows.Threading.Dispatcher]::ExitAllFrames()
	})

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

	$btnBuild.Add_Click({
		$Window.IsEnabled = $false
		Create-RescueImage -InputISO $txtInputISO.Text -OutputISO $txtOutputISO.Text
		$Window.IsEnabled = $true
	})

	$btnCancel.Add_Click({
		$Window.Close()
	})

	$btnRufus.Add_Click({
		Start-Process "https://rufus.ie/"
	})

	$btnUnstrike.Add_Click({
		Start-Process "https://legacyupdate.net/unstrike"
	})

	$btnLegacyUpdate.Add_Click({
		Start-Process "https://legacyupdate.net/unstrike"
	})

	$Window.Show()
	Write-Host "Unstrike started"
	[System.Windows.Threading.Dispatcher]::Run()
	Write-Host "Script ended"
}

function Set-Status {
	Param(
		[string]$Text,
		[int]$Progress = 5
	)

	$script:Progress += $Progress
	Write-Host "$script:Progress%:`t$Text"
	Write-Progress -Activity Unstrike -Status $Text -PercentComplete $script:Progress
}

function Show-Error {
	Param(
		[string]$Text,
		[bool]$IsFatal = $false
	)

	Set-Status -Text $Text

	$icon = if ($IsFatal) {
		[System.Windows.MessageBoxImage]::Error
	} else {
		[System.Windows.MessageBoxImage]::Warning
	}

	if ($script:Window -eq $null) {
		[System.Windows.MessageBox]::Show($Text, "Unstrike", [System.Windows.MessageBoxButton]::OK, $icon)
	} else {
		[System.Windows.MessageBox]::Show($script:Window, $Text, "Unstrike", [System.Windows.MessageBoxButton]::OK, $icon)
	}

	Write-Progress -Activity Unstrike -Complete
}

function Create-RescueImage {
	Param(
		[string]$InputISO,
		[string]$OutputISO
	)

	$script:Progress = 0

	Set-Status -Text "Processing..."

	# Validate inputs
	if (-not $InputISO) {
		Show-Error -Text "Please provide an input path."
		return
	}
	if (-not $OutputISO) {
		Show-Error -Text "Please provide an output path."
		return
	}

	if (-not (Test-Path (Split-Path $InputISO))) {
		Show-Error -Text "Invalid input path."
		return
	}

	if (-not (Test-Path (Split-Path $OutputISO))) {
		Show-Error -Text "Invalid output path."
		return
	}

	if (Test-Path $OutputISO) {
		Set-Status -Text "Deleting existing output file..."
		Remove-Item -Path $OutputISO -Force

		if (Test-Path $OutputISO) {
			Show-Error -Text "Failed to delete existing output file."
			return
		}
	}

	# Clean up temp files in case a previous run failed
	Remove-TempFiles -InputISO $InputISO

	# Mount the input ISO
	Set-Status -Text "Mounting ISO..."
	$mountResult = Mount-DiskImage -ImagePath $InputISO -PassThru
	$driveLetter = ($mountResult | Get-Volume).DriveLetter + ":"

	# Create a temp folder
	Set-Status -Text "Creating temporary directory..."
	$tempPath = "$env:TEMP\UnstrikeTemp"
	New-Item -ItemType Directory -Path $tempPath
	New-Item -ItemType Directory -Path "$tempPath\sources"

	# Copy files to temp folder
	foreach ($item in @("boot", "efi", "sources\boot.wim", "bootmgr", "bootmgr.efi")) {
		Set-Status -Text "Copying $item..."
		Copy-Item -Path "$driveLetter\$item" -Destination "$tempPath\$item" -Recurse -Exclude bootfix.bin
	}

	# Unmount ISO
	Set-Status -Text "Unmounting ISO..."
	Dismount-DiskImage -ImagePath $InputISO

	# Make boot.wim read-write
	$bootWim = "$tempPath\sources\boot.wim"
	(Get-ChildItem -Path $bootWim).Attributes = "Normal"

	# Mount boot.wim
	Set-Status -Text "Mounting boot.wim..."
	$mountDir = "$env:TEMP\UnstrikeBootWim"
	New-Item -ItemType Directory -Path $mountDir
	dism /Mount-Wim /WimFile:"$bootWim" /index:2 /MountDir:"$mountDir"

	# Check error
	if (-not $?) {
		Show-Error -Text "Failed to mount boot.wim."
		return
	}

	# Write the script and set it to run on boot
	Set-Status -Text "Writing rescue script..."
	Set-Content -Path "$mountDir\unstrike.cmd" -Value $batchFile
	Set-Content -Path "$mountDir\Windows\System32\winpeshl.ini" -Value $winpeshlIni

	# Copy choice.exe from running system
	Copy-Item -Path "$env:WINDIR\System32\choice.exe" -Destination "$mountDir\Windows\System32"

	# Unmount and commit boot.wim
	Set-Status -Text "Unmounting boot.wim..."
	dism /Unmount-Wim /MountDir:"$mountDir" /Commit

	# Check error
	if (-not $?) {
		Show-Error -Text "Failed to unmount boot.wim."
		return
	}

	Remove-Item -Path $mountDir -Recurse

	# Create the new ISO
	Set-Status -Text "Creating ISO..."
	& $mkisofs -quiet -iso-level 4 -l -R -udf -D -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -hide boot.catalog -eltorito-alt-boot -no-emul-boot -b efi/microsoft/boot/efisys_noprompt.bin -o "$outputISO" "$tempPath"

	# Clean up temp folder
	Remove-TempFiles -InputISO $InputISO

	# Open in Explorer
	Set-Status -Text Done
	Write-Progress -Activity Unstrike -Complete
	Start-Process explorer.exe -ArgumentList "/select,`"$outputISO`""
	[System.Windows.Threading.Dispatcher]::ExitAllFrames()
}

function Remove-TempFiles {
	Param(
		[string]$InputISO
	)

	Set-Status -Text "Cleaning up..."

	$tempPath = "$env:TEMP\UnstrikeTemp"
	$mountDir = "$env:TEMP\UnstrikeBootWim"

	# Unmount ISO if still mounted
	if ($InputISO -and (Get-DiskImage -ImagePath $InputISO)) {
		Set-Status -Text "Unmounting ISO..."
		Dismount-DiskImage -ImagePath $InputISO
	}

	# Unmount and discard boot.wim
	if (Test-Path $mountDir) {
		Set-Status -Text "Unmounting boot.wim..."
		dism /Unmount-Wim /MountDir:"$mountDir" /Discard
		Remove-Item -Path $mountDir -Recurse -Force
	}

	# Clean up temp folder
	if (Test-Path $tempPath) {
		Set-Status -Text "Cleaning up temp files..."
		Remove-Item -Path $tempPath -Recurse -Force
	}
}

# Elevate if needed
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Start-Process -FilePath powershell.exe -Verb runas -ArgumentList "-File `"$PSCommandPath`""
	Exit
}

# Check OS compatibility
if (-not $env:WINDIR -or [System.Environment]::OSVersion.Version.Major -ne 10) {
	Show-Error -IsFatal $true -Text "This tool requires at least Windows 10."
	Exit
}

if (-not (Test-Path "$env:WINDIR\SysWOW64")) {
	Show-Error -IsFatal $true -Text "This tool requires x64 Windows."
	Exit
}

# Check for mkisofs.exe
Set-Location -Path $PSScriptRoot
if (-not (Test-Path $mkisofs)) {
	Show-Error -IsFatal $true -Text "mkisofs.exe not found. Make sure to extract all files before running the script."
	Exit
}

Show-Dialog
# SIG # Begin signature block
# MIIRRgYJKoZIhvcNAQcCoIIRNzCCETMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC+9mxJmjvlmD7I
# RlrqxHSxqloP+6BnAFdo+tXWdLdqcKCCDYAwgga5MIIEoaADAgECAhEAmaOACiZV
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
# AYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBNpPs3PNVOXD8ZOh49R4M495LfpEqjifsb
# FHuGE0DPHTANBgkqhkiG9w0BAQEFAASCAgBPV0HyNibL7h91vFbMrWq4dt9J+Ht/
# nAijFnRbWZFqR8I0BdeFld4hqS/EzS+uQPdBN26LSCUWEFU42Zf5LjBgeyaknnhe
# UdBq71enz5pHrkz/xqEz2620AU2PzRTDDdim67LQiILHRMfd+tgmuqe6wzIbgqk6
# TM+nyKDMU1rxIT4AL1thkOX2mO6Sb+uCMaOndWjgsdpMHkDbc53+2vonaC0mwztC
# 2ibUN0kNbBS2/gNB7nyt8yyEEgcOcNS7t8X9Ns23kVYQytFNBIu3AI3eIm/do8Ac
# vo/tOCCJKuMZHo8L9tIXVowWK7uZTzxfoa9qzijfllG3/gqF/nZfhpz2UMZoyMXu
# FSaHlD+jqxiFkZxobtymkFW9Dxo4iYwIq0tuZ1DYEan4GrmzS4J0rXmZ2pAOC+l4
# r/PWC6WgYoeB93pZ0xQJXEAhovFYaKGj5IFO4Sqd42wVwYfIzRFgw8Xz1PlTdweS
# fOUh2WNwVzmXyrEaOknNRB1dpIfA6fjXGGicYBKl2uS8XHZR9phXR69t/9jJ1Lm+
# wkpp+xPdp028XTUSacMOeL23BYo+vAQdZQU4IQUS9akZyACzWEhu1nlPkIVOEkoc
# EsoN4jnjsgCEhm1Yhwpo+S9ctP/psdet3cDlI4ooxUehh+pgbJhjC7TpGTdv1qEJ
# rcRycZ47qMm2nA==
# SIG # End signature block
