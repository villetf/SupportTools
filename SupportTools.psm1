## Funktion för att få upp en lista över valalternativ
function Get-Options {
   Find-Updates
   Clear-Host
   do {
      Clear-Host
      $continueRepeating = $true
      Write-Host "Välkommen till SupportTools! Med SupportTools får du tillgång till ett flertal automatiserade verktyg för Region Kalmar Läns supportfunktioner."`n
      Write-Host "Välj vad du vill göra:"`n
      Write-Host "1. Visa alla låsta konton"
      Write-Host "2. Visa alla datorer en användare är inloggad på"
      Write-Host "3. Visa SupportTools-version"
      Write-Host "4. Avsluta"`n
      
      do {
         $selection = Read-Host "Ange ditt val"
         if (($selection -lt 1) -or ($selection -gt 4)) {
            Write-Host "Du måste ange ett heltal mellan 1 och 4" -ForegroundColor Red
            $selection = ""
         }
      } until (
         $selection
      )

      switch ($selection) {
         1 {
            Get-LockedAccounts
         }

         2 {
            do {
               Clear-Host
               $userToSearch = Read-Host "Ange användarnamnet du vill söka på"
               if ((Invoke-RestMethod -Uri "https://sysman.lkl.ltkalmar.se/SysMan/api/v2/user/validateName?name=$userToSearch" -UseDefaultCredentials).isValid) {
                  Write-Host "Användaren $userToSearch finns inte i SysMan. Kontrollera stavning och försök igen" -ForegroundColor Red
                  Start-Sleep -Seconds 5
                  $userToSearch = ""
               }
            } until (
               $userToSearch
            )
            Get-LoggedOnComputers -User $userToSearch
            Clear-Host
         }

         3 {
            Get-ModuleVersion
         }

         4 {
            exit
         }
      }
   } while (
      $continueRepeating
   )
   
}

## Funktion för att hämta lista över låsta konton
function Get-LockedAccounts {
   Clear-Host
   Write-Host "Söker efter låsta konton..."
   Send-Log -FunctionID 101 | Out-Null
   try {
      $userList = Search-ADAccount -LockedOut -SearchBase "OU=LKL-Users,DC=lkl,DC=ltkalmar,DC=se" | Where-Object {$_.Enabled -eq $true}
   }
   catch {
      Write-Error "Ett fel uppstod i samband med sökning mot Active Directory. Se nedan:"
      $_
      Start-Sleep -Seconds 10
      return
   }

   if (!$userList) {
      Clear-Host
      Write-Host "Inga låsta konton hittades."
      Confirm-Return
      return
   }

   if (Test-Connection "siem.lkl.ltkalmar.se" -Count 1 -TcpPort 443) {
      $lockoutInfo = Get-QradarLockoutInfo
      $qradarConnected = $true
   } else {
      Write-Warning "Kunde inte ansluta till Qradar. Qradar fungerar endast på trådat nät, och inte på VPN eller Wifi."
      Start-Sleep -Seconds 5
      $qradarConnected = $false
   }

   $lockedoutList = @("Låsta konton:`n")

   foreach ($account in $userList) {
      try {
         $detailedList = Get-ADUser -Filter {SamAccountName -eq $account.SamAccountName} -SearchBase "OU=LKL-Users,DC=lkl,DC=ltkalmar,DC=se" -Properties *
      }
      catch {
         Write-Warning "Fel uppstod vid hämtning av detaljer om användaren $($account.SamAccountName)"
      }
      
      $lockedoutList += "$($detailedList.Name) ($($detailedList.SamAccountName))"
      $lockedoutList += "$($detailedList.Title) på $($detailedList.Department)"
      $lockedoutList += "Kontot låst: $(($detailedList.AccountLockoutTime).ToString("yyyy-MM-dd HH:mm"))"

      if (!$qradarConnected) {
         $lockedoutList += ""
         continue
      }

      foreach ($event in $lockoutInfo) {
         if (($account.SamAccountName -eq $event.Username) -and ([string]$lockedoutList -notmatch $event."Machine Identifier (custom)")) {
            $lockedoutList += "Utlåst från: $($event."Machine Identifier (custom)")`n"
         }
      }
   }

   Clear-Host
   $lockedoutList
   Confirm-Return
}

## Funktion för att hitta alla datorer en användare är inloggad på
function Get-LoggedOnComputers {
   param (
      [Parameter(Mandatory=$true)]
      [string]$User
   )

   ## Hämtar lista över alla datorer användaren är inloggad på
   Clear-Host
   Write-Host "Söker efter datorer..."
   Send-Log -FunctionID 108 | Out-Null
   try {
      $userInfo = Invoke-RestMethod -Uri "https://sysman.lkl.ltkalmar.se/SysMan/api/Reporting/User?userName=$User" -UseDefaultCredentials
   }
   catch {
      if (($_ | Test-Json -ErrorAction SilentlyContinue) -and ($_ | ConvertFrom-Json).code -eq "ResourceNotFound") {
         Write-Error "Användaren $User finns inte i Sysman."
         Start-Sleep -Seconds 5
         return
      }
      Write-Error "Lista över datorer kunde inte hämtas från SysMan."
      Start-Sleep -Seconds 5
      return
   }

   $detailedList = Get-ADUser -Filter {SamAccountName -eq $User} -SearchBase "OU=LKL-Users,DC=lkl,DC=ltkalmar,DC=se" -Properties *
   
   if ($detailedList.LockedOut) {
      $lockedoutList = Get-QradarLockoutInfo
   }

   $finalText = @()
   $i = 0
   Clear-Host

   ## För varje hittad dator, skapa en hashtable med all info och lägg till i arrayen
   foreach ($computer in $userInfo.clientLogins) {
      # Skriv ut progress-bar
      $i++
      $percentDone = $i / $userInfo.clientLogins.count * 100
      Write-Progress -Activity "Går igenom datorer" -Status "$([int]$percentDone)% genomsökt" -PercentComplete $percentDone

      ## Skapar en tillfällig hashtable med nödvändiga egenskaper
      $tempVar = @{
         value = "`n" + $computer.name
         connected = $false
         reallyLoggedOn = ""
         hasLockedAccount = $false
      }

      ## Kollar om datorn finns med i listan över datorer som låst ute kontot
      if ($detailedList.LockedOut) {
         if ($lockedoutList."Machine Identifier (custom)" -contains $computer.name) {
            $tempVar.hasLockedAccount = $true
         }
      }

      ## Testar nätverksuppkoppling
      $pingResult = Test-Connection -ComputerName $computer.name -Quiet -Count 1

      ## Hämtar info från SDP och lägger till i hashtablen
      try {
         $sdpInfo = Get-SDPAsset -Hostname $computer.name
         if ($sdpInfo) {
            $tempVar.value += "`nRum: $($sdpInfo.Rum), Våning: $($sdpInfo.Plan), Byggnad: $($sdpInfo.Byggnad), $($sdpInfo.Ort)"
            $tempvar.value += "`nDatortyp: $($sdpInfo.Licensform) dator, $($sdpInfo.Varutyp.replace('Dator ', ''))"
            $tempVar.value += "`nModell: $($sdpInfo.Fabrikat) $($sdpInfo.product.name)"
         } else {
            $tempVar.value += "`nIngen information från CMDB tillgänglig"
         }

      }
      catch {
         Write-Warning "Kunde inte hämta data från CMDB om datorn $($computer.name)"
      }

      if ($pingResult) {
         $tempVar.connected = $true
         try {
            $tempVar = Get-LocalInformation -CurrentComputer $computer -tempVar $tempVar
         }
         catch {
            Write-Debug "Kunde inte hämta lokal information från datorn $($computer.name)"
         }
      } else {
         $tempVar.connected = $false
      }
      if ($tempVar.reallyLoggedOn -or !$tempVar.connected) {
         $finalText += $tempVar
      }
   }

   Write-Progress -Activity "Går igenom datorer" -Completed
   
   if ($detailedList.LockedOut) {
      Write-Host "$($userInfo.fullname)s konto är låst!`n`n" -ForegroundColor Red
   }

   ## Visa alla objekt följt av uppkopplingsstatus
   if (!$finalText) {
      Write-Host "$($userInfo.fullname) ($User) är inte inloggad på några datorer."
   } else {
      Write-Host "$($userInfo.fullname) ($User) är inloggad på följande datorer ($($finalText.count) st):"
      foreach ($block in $finalText) {
         $block.value
         if ($block.connected) {
            Write-Host "Datorn är ansluten" -ForegroundColor Green
         } else {
            Write-Host "Datorn är ej ansluten" -ForegroundColor Red
         }
         
         if ($block.hasLockedAccount) {
            Write-Host "Denna dator har låst användarens konto!" -ForegroundColor Red
         }
      }
   }

   ## Skapar prompt för att avsluta
   Confirm-Return
}

## Funktion för att hämta versionsnummer för modulen
function Get-ModuleVersion {
   Clear-Host
   $moduleVersion = [string](Get-Module SupportTools).Version
   try {
      $newestVersion = Invoke-RestMethod -Uri "https://serverx.lkl.ltkalmar.se/supporttools/stversion.txt" -Method Get
   }
   catch {
      Write-Warning "Kontroll efter nya uppdateringar misslyckades"
      Start-Sleep -Seconds 3
      return
   }
   Write-Host "Din SupportTools-version är: $moduleversion`n"
   if ($moduleVersion -ne $newestVersion) {
      Write-Host "Senaste versionen är $newestversion. Uppdaterar..." -ForegroundColor Red
      Start-Sleep -Seconds 5
      Find-Updates
   } else {
      Write-Host "Du har den senaste versionen." -ForegroundColor Green
      Confirm-Return
   }
}

## Funktion för att hämta lokal information från dator via SDP
function Get-LocalInformation {
   param (
      $CurrentComputer,
      $tempVar
   )

   try {
      $localInformation = Invoke-RestMethod -Uri "https://sysman.lkl.ltkalmar.se/SysMan/api/v2/client/$($currentComputer.name)/localInformation" -UseDefaultCredentials -ConnectionTimeoutSeconds 30
   }
   catch {
      $tempVar.reallyLoggedOn = $true
      throw $tempVar
   }

   if ($localInformation.loggedOnUsers.userName -contains $User) {
      foreach ($name in $localInformation.loggedOnUsers) {
         if ($name.userName -eq $User) {
            $tempVar.value += "`nNuvarande inloggning påbörjades: $($localInformation.loggedOnUsers.started.ToString("dd/MM/yyyy HH:mm"))"
            $tempVar.reallyLoggedOn = $true
         }
      }
   } else {
      $tempVar.reallyLoggedOn = $false
   }
   return $tempVar
}

## Funktion för att hämta CMDB-info om dator
function Get-SDPAsset {
   param (
      $Hostname
   )

   if ($Hostname -match "PCX") {
      $Hostname = $Hostname.replace("PCX", "NX")
   }

   if ($Hostname -match "PC") {
      $Hostname = $Hostname.replace("PC", "")
   }

   $technician_key = @{ "authtoken" = "XXXX-XXXX-XXXX-XXXX" }
   $input_data = @"
{
   "list_info": {
      "row_count": 100,
      "fields_required":[
         "id",
      ],
      "search_criteria": {
         "field": "name",
         "condition": "is",
         "value": "$Hostname"
         },
      }
   }
}
"@
   $data = @{ 'input_data' = $input_data }
   ## Gör anrop för att hämta Asset-ID
   $assetId = (Invoke-RestMethod -Uri "https://servicedesk.lkl.ltkalmar.se/api/v3/assets" -Method Get -Body $data -Headers $technician_Key -ContentType "application/x-www-form-urlencoded").assets.id

   ## Gör anrop för att hämta info om asset baserat på ID
   $response = Invoke-RestMethod -Uri "https://servicedesk.lkl.ltkalmar.se/api/v3/assets/$assetId" -Method get -Headers $technician_Key

   $response.asset | Add-Member -MemberType NoteProperty -Name "Rum" -Value $response.asset.ci_citype_4501_fields.udf_sline_7809 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Plan" -Value $response.asset.ci_citype_4501_fields.udf_pick_14401 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Byggnad" -Value $response.asset.ci_citype_4501_fields.udf_sline_7807 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Ort" -Value $response.asset.ci_citype_4501_fields.udf_sline_7804 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Licensform" -Value $response.asset.ci_citype_4501_fields.udf_pick_7822 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Varutyp" -Value $response.asset.ci_citype_4501_fields.udf_pick_7814 -ErrorAction SilentlyContinue
   $response.asset | Add-Member -MemberType NoteProperty -Name "Fabrikat" -Value $response.asset.ci_citype_4501_fields.udf_sline_7803 -ErrorAction SilentlyContinue
   return $response.asset
}

## Funktion för att fråga användaren om den vill avsluta
function Confirm-Return {
   Write-Host ""
   do {
      $exitConfirm = Read-Host "Tryck enter för att avsluta"
   } until (
      !$exitConfirm
   )
   Clear-Host
}

## Funktion för att hämta utelåsta konton från Qradar
function Get-QradarLockoutInfo {

   $global:cred = Get-QradarAuthentication
   $aqlQuery = "select%20categoryname(category)%20as%20'Low%20Level%20Category'%2C%22startTime%22%20as%20'Start%20Time'%2C%22deviceTime%22%20as%20'Log%20Source%20Time'%2C%22endTime%22%20as%20'Storage%20Time'%2C%22userName%22%20as%20'Username'%2C%22Machine%20Identifier%22%20as%20'Machine%20Identifier%20(custom)'%20from%20events%20where%20(%20%22Event%20ID%22%3D'4740'%20AND%20(%20%22deviceGroupList%22%3D'100077'%20AND%20ALL%20%22deviceGroupList%22%20!%3D%20'100076'%20)%20)%20order%20by%20%22startTime%22%20desc%20LIMIT%201000%20last%20120%20minutes"
   $id = (Invoke-RestMethod -Uri "https://siem.lkl.ltkalmar.se/api/ariel/searches?query_expression=$aqlQuery" -Method Post -Headers @{
      'Version'       = '20.0'
      'Accept'        = 'application/json'
   } -Authentication Basic -Credential $cred).search_id

   do {
      $queryStatus = (Invoke-RestMethod -Uri "https://siem.lkl.ltkalmar.se/api/ariel/searches/$id" -Method GET -Headers @{
         'Version'       = '20.0'
         'Accept'        = 'application/json'
      } -Authentication Basic -Credential $cred).status
   } until (
      $queryStatus -eq "COMPLETED"
   )

   $lockEvents = (Invoke-RestMethod -Uri "https://siem.lkl.ltkalmar.se/api/ariel/searches/$id/results" -Method GET -Headers @{
      'Range'         = 'items=0-49'
      'Version'       = '20.0'
      'Accept'        = 'application/json'
   } -Authentication Basic -Credential $cred).events
   return $lockEvents
}

## Funktion för att fråga om användaruppgifter till Qradar
function Get-QradarAuthentication {

   if (Test-Path -Path "$env:LOCALAPPDATA\.stcred.xml") {
      [pscredential]$global:cred = Import-Clixml -Path "$env:LOCALAPPDATA\.stcred.xml"
   } else {
      Clear-Host
      $global:cred = Get-Credential -Title "Autentisering" -Message "Ange användarnamn och lösenord till ditt adminkonto"
      $cred | Export-Clixml -Path "$env:LOCALAPPDATA\.stcred.xml"
   }

   do {
      try {
         Invoke-RestMethod -Uri "https://siem.lkl.ltkalmar.se/api/ariel/saved_searches/3339" -Method GET -Headers @{
            'Version'       = '20.0'
            'Accept'        = 'application/json'
         } -Authentication Basic -Credential $cred -ErrorAction Stop | Out-Null
         $authIsCorrect = $true
      }
      catch {
         if (!(Test-Json $_ -ErrorAction SilentlyContinue)) {
            $_
            return
         }
         if (($_ | ConvertFrom-Json).http_response.code -eq 401) {
            Write-Host "Användarnamn eller lösenord är felaktigt, försök igen" -ForegroundColor Red
            Write-Host ""
            $authIsCorrect = $false
            $global:cred = Get-Credential -Title "Autentisering" -Message "Ange användarnamn och lösenord till ditt adminkonto"
            $cred | Export-Clixml -Path "$env:LOCALAPPDATA\.stcred.xml"
         } else {
            $_
            return
         }    
      }
   } until ($authIsCorrect)
   return $cred
}





## Stödfunktioner
## Funktion för att skicka logg till Log4CjS
function Send-Log {
   param (
      [Parameter(Mandatory=$true)]
      [string]$FunctionID,

      [Parameter(Mandatory=$false)]
      [string]$CurrentObject
   )
   
   [string]$username = ([adsi]"WinNT://$env:userdomain/$env:username,user").fullname

   if (!$username) {
      $username = "Okänd användare"
   }

   if ($currentObject) {
      $data = @{
         token = 'yrN4QW4aqgf2m57dQoVtprEoFyR4qY' 
         user = $username
         button = $FunctionID
         object = $CurrentObject
      };
   } else {
      $data = @{
         token = 'yrN4QW4aqgf2m57dQoVtprEoFyR4qY' 
         user = $username
         button = $FunctionID
      };
   }
   
   try {
      Invoke-RestMethod -Uri "https://serverx.lkl.ltkalmar.se/api/supporttools/log" -Method Post -ContentType "application/json" -Body ($data | ConvertTo-Json)   
   }
   catch {
      return
   }
}

## Funktion för att kolla om det finns nya uppdateringar
function Find-Updates { 
   $moduleVersion = [string](Get-Module SupportTools).Version
   try {
      $newestVersion = Invoke-RestMethod -Uri "https://serverx.lkl.ltkalmar.se/supporttools/stversion.txt" -Method Get
   }
   catch {
      Write-Warning "Kontroll efter nya uppdateringar misslyckades"
      Start-Sleep -Seconds 3
      return
   }

   if ($moduleVersion -ne $newestVersion) {
      do {
         $updateAnswer = Read-Host "En ny uppdatering av SupportTools är tillgänglig. Vill du installera den nu? (y/n)"
      } until (
         @("y", "yes", "j", "ja", "n", "nej", "no") -contains $updateAnswer
      )
      
      if (@("y", "yes", "j", "ja") -contains $updateAnswer) {
         Update-SupportTools
      }
   }
}

## Funktion för att uppdatera modulen
function Update-SupportTools {
   Remove-Item -Path "$env:LocalAppData\SupportTools\*"
   try {
      Invoke-WebRequest -Uri "https://serverx.lkl.ltkalmar.se/supporttools/SupportTools.zip" -OutFile "$env:LocalAppData\SupportTools\SupportTools.zip"
   }
   catch {
      throw "Hämtning av ny version misslyckades: $_"
   }
   Expand-Archive -Path "$env:LocalAppData\SupportTools\SupportTools.zip" -DestinationPath "$env:LocalAppData\SupportTools"
   Remove-Item -Path "$env:LocalAppData\SupportTools\SupportTools.zip"
   Start-Process -FilePath "$env:LocalAppData\SupportTools\SupportTools.lnk"
   exit
}