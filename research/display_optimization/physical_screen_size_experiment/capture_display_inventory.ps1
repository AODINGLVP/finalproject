param(
    [string]$Session = (Get-Date -Format 'yyyy-MM-dd_HHmm'),
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot "data/$Session/devices.csv"
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $OutputPath) {
    throw "Inventory already exists and will not be overwritten: $OutputPath"
}

Add-Type -AssemblyName System.Windows.Forms
if (-not ('PhysicalScreenNative' -as [type])) {
    Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class PhysicalScreenNative {
    public class DisplayRow {
        public string GdiName { get; set; }
        public string MonitorId { get; set; }
        public string AdapterName { get; set; }
        public int X { get; set; }
        public int Y { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        public int RefreshHz { get; set; }
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct POINTL { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public POINTL dmPosition;
        public int dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags,
            dmDisplayFrequency, dmICMMethod, dmICMIntent, dmMediaType,
            dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum,
        ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string deviceName, int modeNum,
        ref DEVMODE devMode);

    public static DisplayRow[] EnumerateActive() {
        var rows = new List<DisplayRow>();
        for (uint adapterIndex = 0; ; adapterIndex++) {
            var adapter = new DISPLAY_DEVICE();
            adapter.cb = Marshal.SizeOf(adapter);
            if (!EnumDisplayDevices(null, adapterIndex, ref adapter, 0)) break;
            if ((adapter.StateFlags & 1) == 0) continue;

            var monitor = new DISPLAY_DEVICE();
            monitor.cb = Marshal.SizeOf(monitor);
            if (!EnumDisplayDevices(adapter.DeviceName, 0, ref monitor, 1)) continue;

            var mode = new DEVMODE();
            mode.dmSize = (short)Marshal.SizeOf(mode);
            if (!EnumDisplaySettings(adapter.DeviceName, -1, ref mode)) continue;

            rows.Add(new DisplayRow {
                GdiName = adapter.DeviceName,
                MonitorId = monitor.DeviceID,
                AdapterName = adapter.DeviceString,
                X = mode.dmPosition.x,
                Y = mode.dmPosition.y,
                Width = mode.dmPelsWidth,
                Height = mode.dmPelsHeight,
                RefreshHz = mode.dmDisplayFrequency
            });
        }
        return rows.ToArray();
    }
}
'@
}

function Convert-EdidString($Value) {
    if ($null -eq $Value) { return '' }
    return ([Text.Encoding]::ASCII.GetString([byte[]]$Value)).Trim([char]0).Trim()
}

$displayRows = [PhysicalScreenNative]::EnumerateActive()
$logicalScreens = [System.Windows.Forms.Screen]::AllScreens
$basicParams = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | Where-Object Active)
$monitorIds = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | Where-Object Active)
$capturedAt = (Get-Date).ToUniversalTime().ToString('o')
$inventory = @()

for ($godotIndex = 0; $godotIndex -lt $logicalScreens.Count; $godotIndex++) {
    $logical = $logicalScreens[$godotIndex]
    $native = $displayRows | Where-Object GdiName -eq $logical.DeviceName | Select-Object -First 1
    if ($null -eq $native) { throw "No native display mapping for $($logical.DeviceName)" }
    $monitorParts = $native.MonitorId -split '#'
    if ($monitorParts.Count -lt 2) { throw "Unexpected monitor ID: $($native.MonitorId)" }
    $hardwareKey = $monitorParts[1]
    $basic = $basicParams | Where-Object InstanceName -like "DISPLAY\$hardwareKey\*" | Select-Object -First 1
    $identity = $monitorIds | Where-Object InstanceName -like "DISPLAY\$hardwareKey\*" | Select-Object -First 1
    if ($null -eq $basic -or $null -eq $identity) { throw "Missing active EDID data for $hardwareKey" }
    $widthCm = [double]$basic.MaxHorizontalImageSize
    $heightCm = [double]$basic.MaxVerticalImageSize
    if ($widthCm -le 0 -or $heightCm -le 0) { throw "Invalid EDID dimensions for $hardwareKey" }
    $diagonalIn = [Math]::Sqrt($widthCm * $widthCm + $heightCm * $heightCm) / 2.54
    $uidMatch = [regex]::Match($identity.InstanceName, 'UID(\d+)')
    $uid = if ($uidMatch.Success) { $uidMatch.Groups[1].Value } else { $godotIndex.ToString() }
    $friendlyName = Convert-EdidString $identity.UserFriendlyName
    if ([string]::IsNullOrWhiteSpace($friendlyName)) { $friendlyName = $hardwareKey }
    $inventory += [PSCustomObject]@{
        session = $Session
        captured_at_utc = $capturedAt
        device_key = "${hardwareKey}_UID${uid}"
        gdi_name = $logical.DeviceName
        godot_index = $godotIndex
        manufacturer = Convert-EdidString $identity.ManufacturerName
        model = $friendlyName
        product_code = Convert-EdidString $identity.ProductCodeID
        serial = Convert-EdidString $identity.SerialNumberID
        width_cm = [Math]::Round($widthCm, 2)
        height_cm = [Math]::Round($heightCm, 2)
        diagonal_in = [Math]::Round($diagonalIn, 4)
        screen_area_cm2 = [Math]::Round($widthCm * $heightCm, 2)
        native_width = $native.Width
        native_height = $native.Height
        refresh_hz = $native.RefreshHz
        position_x = $native.X
        position_y = $native.Y
        windows_logical_width = $logical.Bounds.Width
        windows_logical_height = $logical.Bounds.Height
        windows_work_width = $logical.WorkingArea.Width
        windows_work_height = $logical.WorkingArea.Height
        primary = $logical.Primary
        gpu_adapter = $native.AdapterName
    }
}

$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$inventory | Sort-Object diagonal_in | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8
Write-Output "PHYSICAL_SCREEN_INVENTORY_OK devices=$($inventory.Count) output=$OutputPath"
$inventory | Sort-Object diagonal_in | Format-Table device_key,model,width_cm,height_cm,diagonal_in,gdi_name,godot_index -AutoSize
