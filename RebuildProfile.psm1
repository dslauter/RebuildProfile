Function RebuildProfile {

<#This script was written by Dan Slauter to rebuild profiles multiple computers, if you run into any problems please let me know.

Email: dslauter@trivalentgroup.com
Phone: 616-301-6395

Written December 1st, 2015

#>
#Allow Scripts
#Set-ExecutionPolicy unrestricted


###########Variables###########
$Domain = "Null"
$admin = "Null"
$User = "Null"
$RDSServers = "Null"
###############################

#############Functions########

Function Get-WMIComputerSessions {
<#
.SYNOPSIS
    Retrieves all user sessions from local or remote server/s
.DESCRIPTION
    Retrieves all user sessions from local or remote server/s
.PARAMETER computer
    Name of computer/s to run session query against.
.NOTES
    Name: Get-WmiComputerSessions
    Author: Boe Prox
    DateCreated: 01Nov2010
 
.LINK
    https://boeprox.wordpress.org
.EXAMPLE
Get-WmiComputerSessions -computer "server1"
 
Description
-----------
This command will query all current user sessions on 'server1'.
 
#>
[cmdletbinding(
    DefaultParameterSetName = 'session',
    ConfirmImpact = 'low'
)]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True)]
            [string[]]$computer
    )
Begin {
    #Create empty report
    $report = @()
    }
Process {
    #Iterate through collection of computers
    ForEach ($c in $computer) {
        #Get explorer.exe processes
        $proc = gwmi win32_process -computer $c -Filter "Name = 'explorer.exe'" -ErrorAction Inquire
        #Go through collection of processes
        ForEach ($p in $proc) {
            $temp = "" | Select Computer, Domain, User
            $temp.computer = $c
            $temp.user = ($p.GetOwner()).User
            $temp.domain = ($p.GetOwner()).Domain
            $report += $temp
          }
        }
    }
End {
    $report
    }
}
Function Reg-RemoveProfile($Domain, $User) {
<#Function Reg-RemoveProfile
1. Grabs the SID of the User
2. Searches the registry to see if they have an entry in profile list, if not the profile won't be rebuilt
3. Grabs the ProfileImagePath Value
4. Renames the ProfileImagePath folder to C:\Users\Username.OLD
5. Deletes the Registry Key

ex. Reg-RemoveProfile tg dslauter 
Written by Dan Slauter#>
    $objUser = New-Object System.Security.Principal.NTAccount("$Domain","$User")
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier]) 
    $sid = $strSID.Value
    If ($sid -eq $NULL) {
        $sid = "no profile"
        }
    #Search for and remove the profile in registry
    $regpath = "HkLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $regexists = (Test-Path -Path $regpath)
    write-Host  Has $User logged onto this computer? $regexists
        If ($regexists -eq $True) {
            $profileimagepath = (Get-ItemProperty $regpath).ProfileImagePath
                    If (Test-Path $profileimagepath) {
                        #Rename the folder
                        Write-Host "$profileimagepath folder will now be renamed to $profileimagepath.OLD"
                        Rename-Item $profileimagepath "$profileimagepath.OLD"
                        Write-Host "The folder has been successfully renamed to $profileimagepath.OLD"
                    }
                    Else {
                        Write-Output "$User does not have a home folder on this server"
                    }
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -Recurse
        Write-Host "Registry key for $User has been removed from this computer"
        }
        Else {
            Write-Host " $User has not logged into this computer, profile will not be rebuilt"
        }
}

Function IsUserLoggedIn($User,$Computer) {
<#Funciton: IsUserLoggedIn
This function is used to call another function to check if the user is logged in or not. 
If the user is logged in a 1 is returned, if they aren't logged in a 0 is returned #>
$UserLoggedin = Get-WMIComputerSessions -computer "$Computer" | Select-String -Pattern $User

If ($UserLoggedin -eq $NULL) {
    Write-Output 0
    }
    Else
    {
    Write-Output 1
    }

}

########################################


#First enter the username of the profile you would like to rebuild
Write-Host "You need to be running this as a Domain Administrator. Are you a Domain Administrator? (Y/N)" 
$response = Read-Host
If ($response -ne "Y" ) {Exit}

$User = Read-Host -Prompt 'What is the username of the profile you want to rebuild'
$Domain = Read-Host -Prompt "And the domain for $User"
Write-Host "Would you like to rebuild this profile on all of the PHRC RDS Servers? (Y/N)"
$response = Read-Host
    If ($response -ne "y") {
        [array]$RDSServers = (Read-Host “Enter the computer(s) you want to rebuild the profile on(separate with comma ex. PHRC-GVL-RDS01,PHRC-GVL-RDS02)”).split(“,”) | %{$_.trim()}
        }
    Else {
        $RDSServers = "PHRC-GVL-RDS01","PHRC-GVL-RDS02","PHRC-GVL-RDS04","PHRC-GVL-RDS05","PHRC-GVL-RDS06","PHRC-GVL-RDS07","PHRC-GVL-RDS08","PHRC-GVL-RDS09","PHRC-GVL-RDS10","PHRC-GVL-RDS11"
    }
#Now display information to verify that it is correct
Write-Host "The username of the profile you want to rebuild is $User and the domain is $Domain and the computer(s) are $RDSServers is this correct? (Y/N)"
$response = Read-Host
    If ( $response -ne "Y" ) { Exit}


Foreach ($RDS in $RDSServers) {
    Write-Host "Starting Profile Rebuild for $User on $RDS"
    Write-Host "Checking if $User is logged in on  $RDS"
    #Query RDS Server for Users Logged In, if user isn't logged in the profile will be rebuilt. 
    If ((IsUserLoggedIn $User $RDS) -eq 0) {
        Write-Host "Safe to Continue, $User is not logged in on $RDS"

        #Remove Profile from Registry and Rename Folder
        Invoke-Command -ComputerName $RDS -ScriptBlock ${function:Reg-RemoveProfile} -ArgumentList  $Domain,$User 
        Write-Host "$User profile has been rebuilt on $RDS"
        }
    Else {
        Write-Host "***** $User was logged in on $RDS please rebuild this profile at another time ********" -ForegroundColor "Red"
    }
}
Write-Host Here are the errors $Error -ForegroundColor "Red"
Write-Host "The script has run successfully to rebuild $User's profile on the computers you selected. If there were any errors, they will be above and in red. Would you like to exit? (Y/N)"
$response = Read-Host
    If ($response -ne "N" ) {Exit}
}
