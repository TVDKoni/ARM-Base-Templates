$user = "msbiadmin"
$password = "xxxx"
$query = "CREATE LOGIN [$($env:computername.ToUpper())\$($user)] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english];GO;ALTER SERVER ROLE [sysadmin] ADD MEMBER [$($env:computername.ToUpper())\$($user)];GO"
Invoke-SQLCmd -ServerInstance "localhost" -Database "master" -ConnectionTimeout 300 -QueryTimeout 600 -Query $query -Username $user -Password $password
Restart-Computer -Force -Timeout 0
