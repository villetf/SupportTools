## Kontrollerar att Powershell 7 är installerat
if (!(Test-Path "C:\Program Files\PowerShell\7\pwsh.exe")) {
   Write-Host "SupportTools kräver Powershell 7, som inte är installerat. Installera det genom Sysman och kör detta skript igen. Går till Sysman..." -ForegroundColor Red
   Start-Sleep -Seconds 5
   Start-Process "https://sysman.lkl.ltkalmar.se/SysMan/Application/InstallForClients#targetName=$env:computername"
   exit
}

## Kollar ifall SupportTools redan är installerat, frågar isåfall om ominstallation
if (Test-Path "$env:LocalAppData\SupportTools") {
   $reinstallAnswer = Read-Host "SupportTools är redan installerat. Vill du ominstallera? Y/N"
   if (($reinstallAnswer -eq "Y") -or ($reinstallAnswer -eq "Yes") -or ($reinstallAnswer -eq "J")) {
      Remove-Item "$env:LocalAppData\SupportTools" -Recurse -Force
   } else {
      exit
   }
}

## Kollar att ExecutionPolicyn inte är Restricted
if ((Get-ExecutionPolicy) -eq "Restricted") {
   Write-Host "Din ExecutionPolicy tillåter inte skriptkörning. Ändra den som beskrivet under Vanliga problem i KA #1498. Går till KA..."
   Start-Sleep -Seconds 10
   Start-Process "https://servicedesk.lkl.ltkalmar.se/ui/solutions?entity_id=1498&mode=detail#feedback"
}

## Skapar mapp för filerna
New-Item -ItemType Directory "$env:LocalAppData\SupportTools" | Out-Null

## Hämtar zip från webservern
try {
   Invoke-WebRequest -Uri "https://serverx.lkl.ltkalmar.se/supporttools/SupportTools.zip" -OutFile "$env:LocalAppData\SupportTools\SupportTools.zip"
}
catch {
   Write-Host "Installationsfilen kunde inte hämtas. Se nedan"
   throw $_
}

## Unzippar, tar bort zipen, kopierar genvägen till Startmenyn, öppnar utforskarfönster till mappen
Expand-Archive -Path "$env:LocalAppData\SupportTools\SupportTools.zip" -DestinationPath "$env:LocalAppData\SupportTools"
Remove-Item -Path "$env:LocalAppData\SupportTools\SupportTools.zip"
Copy-Item -Path "$env:LocalAppData\SupportTools\SupportTools.lnk" -Destination "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Force
Start-Process -FilePath "$env:LocalAppData\SupportTools"
