configuration S2D
{
    param
    (
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-Module Storage

    $storagePool = New-StoragePool -FriendlyName "DataPool" `
        -StorageSubSystemUniqueId (Get-StorageSubSystem).uniqueID `
        -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
    Start-Sleep -Seconds 20

    $disk = New-VirtualDisk -FriendlyName "DataDisk01" `
    -StoragePoolFriendlyName "DataPool" -Size $storagePool.Size `
    -ProvisioningType Thin -ResiliencySettingName Simple | Get-Disk
    Start-Sleep -Seconds 20

    Initialize-Disk -Number $disk.Number
    Start-Sleep -Seconds 20

    $part = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
    Start-Sleep -Seconds 20

    Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel "DataDisk01"
}
