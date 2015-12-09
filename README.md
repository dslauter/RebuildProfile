# RebuildProfile
This repository is for the PowerShell Module RebuildProfile. This module can rebuild the profile of the selected user across multiple computers/servers

#Import The Module
#Open PowerShell (Duh)
#Import-Module (Path to Module)

PS C:\Users\dslauter> Import-Module C:\RebuildProfile.psm1

#Execute Module

PS C:\Users\dslauter> RebuildProfile

The Module will ask the following questions

1. Are you a domain admin?
2. What is the username of the person you want to rebuild?
3. Do you want to rebuild this user on all PHRC RDS servers?
3. What computers do you want to rebuild this user on?
4. Are you sure you want to do this?

Boom Done
