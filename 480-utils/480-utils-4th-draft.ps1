# TO DO
#    Create a function to get the first IP address of a running VM. Output to be in ansible inventory format.

clear

. ./480-vars.ps1

#Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false

#$ErrorActionPreference = "silentlycontinue"

Function connectvcenter { 
    # This is just to connect to the vcenter server. It will always ask first which server to connect to. 
    # There's only one in this case. If there is an issue connecting to or logging in, it asks if you would like to try again.

    $tryvser = 'y'
    
    while ($tryvser -notmatch '^[nN]$') {
        # While it still needs to get the proper vcenter server connection...
        $vseranswer = Read-Host -Prompt "Enter the vcenter server you would like to connect to (default is $vser)"

        if (-not $vseranswer) {
            $vseranswer = $vser
        }
        
        Write-Host "Using vcenter server $vseranswer..." -fore green
        
        if ($global:DefaultVIServers) {
            # If it is already connected to theserver, it skips the connection process.
            $tryvser = 'n'
        }
        else {
            # If it's not connected, it begins the connecton process.
            Connect-VIServer($vser) -ErrorVariable err -ea SilentlyContinue
            
            if ($err) {
                # If there was an error using the server, it asks if they want to try again.
                $tryvser = Read-Host -Prompt "There was an issue using the vcenter server $vseranswer. Would you like to try again? [Y]es try again, or [N]o"

                if ($tryvser -notmatch '^[yY]$') {
                    # If they say no to trying again, it exits.
                    Write-Host "Exiting..." -fore red
                    exit
                }
            }
            else {
                # If there's no error, it's done.
                $tryvser = 'n'
                $global:visername = $vseranswer
            }
        }
        
    }
}

#
# THE FOLLOWING FUNCTIONS ARE JUST FOR VM CLONING
#

Function getbasevm { 
    # This one will list the available vms to clone. It will ask the user to enter the full name of the vm they would like to clone. 
    # If there's no match found, it asks if they want to try again.

    $vmtable = @(Get-Folder -name $basefolder | Get-VM | Sort-object | Select-Object Name | ForEach-Object { $_ -replace "@{Name=", "" -replace "}", "" })
    Write-Host "
Beginning the cloning process. Some information is needed first. Here is a list of the VMs that can be cloned:"

    foreach ($i in $vmtable) {
        # Looping through the table of VMs to output them properly.
        Write-Host $i
    }
    $tryvm = 'y'

    while ($tryvm -notmatch '^[nN]$') {
        # While they need to get a proper vm...
        $global:basevm = Read-Host -Prompt "Please enter the full name of the vm you are cloning"
        
        foreach ($i in $vmtable) {
            # If their answer matches anything in the table. 
            #This can go wrong if they have vms with the same character length and the same first and ending characters.

            if ($basevm -match ('^{0}$' -f $i)) {
                Write-Host "Match found: $i" -fore green
                $tryvm = 'n'
                $global:bvm = Get-VM -name $basevm
                Write-Host "Base VM set." -fore green
            }
        }

        if ($tryvm -notmatch 'n') {
            # If there's no matches at all, it asks if they want to try again.
            Write-Host "No VM of that name was found. Try again?" -fore red
            $tryvm = Read-Host -Prompt "[Y]es try again, or [N]o, don't try again."

            if ($tryvm -notmatch '^[yY]$') {
                # If they say no to trying again, it exits.
                Write-Host "Exiting..." -fore red
                break exitclonevms
            } 
        }
    }
    #Write-Host $bvm # This is a testing write-host.
}

Function getbvmsnsh { 
    # As with the base vms, this lists the snapshots on the vm. It asks the user to specify a snapshot by name. 
    # If there was an issue getting that snapshot in some shape or form, it asks if they want to try again. 
    # If it can't find any snapshots, it exits the program.

    Write-Host "
The following is a list of snapshots available on $bvm :"
    $snshlist = Get-Snapshot -vm $bvm
    Write-Host $snshlist
    if ($snshlist) {
        # If there is a list of snapshots to choose from for the base vm.
        $trysnsh = 'y'

        while ($trysnsh -notmatch '^[nN]$') {
            # While it needs a proper snapshot...
            $snshanswer = Read-Host -Prompt "Please enter the name of the snapshot to utilize from $bvm (default is $snshname)"

            if (-not $snshanswer) {
                $snshanswer = $snshname
            }
                      
            $global:snsh = Get-Snapshot -vm $bvm -name $snshanswer -ErrorVariable err -ea SilentlyContinue

            if ($err) {
                # If there's an error with the snapshot.
                $trysnsh = Read-Host -Prompt "There was an issue retrieving a snapshot by the name of $snsh from $bvm. Try again? [Y]es or [N]o"

                if ($trysnsh -notmatch '^[yY]$') {
                    # If they say no to trying again.
                    Write-Host "Exiting..." -fore red
                    break exitclonevms
                }
            }
            else {
                # No error, continues.
                $trysnsh = 'n'
                Write-Host "Snapshot set." -fore green
            }
            
        }
    }
    else {
        # No snapshots found.
        Write-Host "This vm does not have any snapshots..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
    #Write-Host $snsh 
}

Function getesxihost { 
    # The same with the snapshots and base vms. It lists them, asks the user for the name/ip of it.

    Write-Host "
The following is a list of ESXi Hosts:"
    $vmhlist = Get-VMHost
    Write-Host $vmhlist

    if ($vmhlist) {
        # If there is a list of vmhosts, it continues.
        $tryesxi = 'y'

        while ($tryesxi -notmatch '^[nN]$') {
            # While it needs a proper vmhost...
            $esxianswer = Read-Host -Prompt "Please enter the IP address/Name of  the ESXi Host to use (default is $vmhost)"

            if (-not $esxianswer) {
                $esxianswer = $vmhost
            }

            $global:vmh = Get-VMHost -name $esxianswer -ErrorVariable err -ea SilentlyContinue

            if ($err) {
                # If there's an error.
                $tryesxi = Read-Host -Prompt "There was an issue with the ESXi host $esxianswer. Try again? [Y]es or [N]o"

                if ($tryesxi -notmatch '^[yY]$') {
                    # If they say no to trying again.
                    Write-Host "Exiting..." -fore red
                    break exitclonevms
                }
            }
            else {
                # If there's no error, it continues.
                $tryesxi = 'n'
                Write-Host "ESXi Host set." -fore green
            }
            
            #Write-Host $vmh # Testing only write-host.
        }
    }
    else {
        # It didn't find any vmhosts, so it exits.
        Write-Host "There are no ESXi Hosts..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getds { 
    # Also the same with the vms, snapshots, and esxi hosts.

    Write-Host "
The following is a list of datastores:"
    $dslist = Get-Datastore
    Write-Host $dslist

    if ($dslist) {
        # If there's a list.
        $tryds = 'y'

        while ($tryds -notmatch '^[nN]$') {
            # While it needs a proper datastore...
            $dsanswer = Read-Host -Prompt "Please enter the name of the datastore to use (default is $ds)"

            if (-not $dsanswer) {
                $dsanswer = $ds
            }
            
            $global:dstore = Get-Datastore -name $dsanswer -ErrorVariable err -ea SilentlyContinue

            if ($err) {
                # Error with datastore.
                $tryds = Read-Host -Prompt "There was an issue finding datastore $dsanswer. Try again? [Y]es or [N]o"

                if ($tryds -notmatch '^[yY]$') {
                    # Don't try again.
                    Write-Host "Exiting..." -fore red
                    break exitclonevms
                }
            }
            else {
                # No error.
                $tryds = 'n'
                Write-Host "Datastore set." -fore green
            }
            
        }
        #Write-Host $dstore
    }
    else {
        # No datastores found.
        Write-Host "There are no datastores..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getlinkedvm { 
    # creates a linked vm clone.

    Write-Host "Creating the linked vm..."
    $lname = Read-Host -Prompt "Please enter the name for this linked vm"
    $global:lvm = new-vm -LinkedClone -name $lname -vm $bvm -referencesnapshot $snsh -vmhost $vmh -datastore $dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) {
        # Error creating linked clone.
        Write-Host "There was an issue creating the linked vm $lname." -fore red
        Write-Host "Exiting..." -fore red
        break exitclonevms
    }
    else {
        # No error creating linked clone.
        Write-Host "Linked vm created." -fore green
        #Write-Host $lvm
    }
}

Function getnvm { 
    # creates a linked vm clone and then a full clone based on the linked clone.

    Write-Host "Creating the temporary linked vm..."
    $lname = "{0}.linked" -f $basevm
    $global:lvm = new-vm -LinkedClone -name $lname -vm $bvm -referencesnapshot $snsh -vmhost $vmh -datastore $dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) {
        # Error creating temporary linked clone.
        Write-Host "There was an issue creating the temporary linked vm." -fore red
        Write-Host "Exiting..." -fore red
        break exitclonevms
    }
    else {
        # No error.
        Write-Host "Temporary linked vm created." -fore green
        #Write-Host $lvm
    }

    Write-Host "Creating new vm..."
    $vmname = Read-Host -Prompt "Please name the new vm"
    Write-Host "Creating the new vm $vmname..."
    $global:nvm = new-vm -name $vmname -vm $lvm -vmhost $vmh -datastore $dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) {
        # Error creating new vm from linked vm.
        Write-Host "There was an issue creating the new vm." -fore red
        Write-Host "Exiting..." -fore red
        break exitclonevms
    }
    else {
        # No error.
        Write-Host "The new vm $vmname has been created!" -fore green
        Write-Host "Please do not forget about the temporary linked clone $lname. It is suggested that you delete it manually using [Remove-VM -vm $lname]." -fore blue
        #Write-Host $nvm
    }
}

Function cloning {
    $tryclone = 'y'
        
    while ($tryclone -notmatch '^[nN]$') {
        # Asks whether the user wants to create a linked clone only or a full clone. 
        $clonetype = Read-Host -Prompt "
Would you like to create a [L]inked clone or a [F]ull clone?"

        if ($clonetype -match '^[lL]$') {
            # If they say linked clone.
            getlinkedvm
            $tryclone = 'n'
        }
        elseif ($clonetype -match '^[fF]$') {
            # If they say full clone.
            getnvm
            $tryclone = 'n'
        }
        else {
            # If it's neither linked or full.
            Write-Host "Invalid answer. Would you like to try again?" -fore red
            $tryclone = Read-Host -Prompt "[Y]es or [N]o"

            if ($tryclone -notmatch '^[yY]$') {
                # If they don't wanna try again.
                Write-Host "Exiting..." -fore red
                break exitclonevms
            }
        }
    }
}

Function clonevms {
    # VM cloning function only.

    :exitclonevms while ($true) {
        getbasevm
        getbvmsnsh
        getesxihost
        getds
        cloning
        break
    }
}

#
# THE ABOVE FUNCTIONS ARE JUST FOR VM CLONING
#

Function startvms {
    $vmtable = @(Get-VM | Sort-object | Select-Object Name | ForEach-Object { $_ -replace "@{Name=", "" -replace "}", "" })
    Write-Host "The following is a list of vms that you can start:"

    foreach ($i in $vmtable) {
        # Looping through the table of VMs to output them properly.
        Write-Host $i
    }
    $trystartvms = 'y'
    while ($trystartvms -notmatch '^[nN]$') {
        # While they need to get a proper vm...
        $startvm = Read-Host -Prompt "Please enter a vm name"
        
        foreach ($i in $vmtable) {
            # If their answer matches anything in the table. 
            #This can go wrong if they have vms with the same character length and the same first and ending characters.

            if ($startvm -match ('^{0}$' -f $i)) {
                Write-Host "Match found: $i" -fore green
                $trystartvms = 'n'
                $vmstate = Get-VM -name $startvm -ErrorVariable err -ea SilentlyContinue | Select-Object PowerState

                If ($vmstate -notmatch 'PoweredOn') {
                    Start-VM -VM $startvm
                    Write-Host "VM Started." -fore green
                }
                else {
                    Write-Host "VM is already on." -fore yellow
                }
            }
        }

        if ($trystartvms -notmatch 'n') {
            # If there's no matches at all, it asks if they want to try again.
            Write-Host "No VM of that name was found. Try again?" -fore red
            $trystartvms = Read-Host -Prompt "[Y]es try again, or [N]o, don't try again."

            if ($trystartvms -notmatch '^[yY]$') {
                # If they say no to trying again, it exits.
                Write-Host "Exiting..." -fore red
            } 
        }

        if ($err) {
            Write-Host "There was an error attempting to start that VM. Would you like to try again?" -fore red
            $trystartvms = Read-Host -Prompt "[Y]es try again, or [N]o"

            if ($trystartvms -notmatch '^[yY]$') {
                # If they say no to trying again, it exits.
                Write-Host "Exiting..." -fore red
            } 
        }
    }
}

Function setvmnetadapt {
    $vmtable = @(Get-VM | Sort-object | Select-Object Name | ForEach-Object { $_ -replace "@{Name=", "" -replace "}", "" })
    Write-Host "The following is a list of vms that you can change the network adapters of:"

    foreach ($i in $vmtable) {
        # Looping through the table of VMs to output them properly.
        Write-Host $i
    }
    $trysetvmna = 'y'
    while ($trysetvmna -notmatch '^[nN]$') {
        # While they need to get a proper vm...
        $setvmna = Read-Host -Prompt "Please enter a vm name"
        
        foreach ($i in $vmtable) {
            # If their answer matches anything in the table. 
            #This can go wrong if they have vms with the same character length and the same first and ending characters.

            if ($setvmna -match ('^{0}$' -f $i)) {
                Write-Host "Match found: $i" -fore green

                Get-VM $setvmna | Get-NetworkAdapter

                $vmneta = @(Get-VM $setvmna | Get-NetworkAdapter)

                $vmna = Read-Host -Prompt "Please choose a network adapter"
                $choosenetadapt = 0

                foreach ($i in $vmneta) {

                    if ($vmna -match ('^{0}$' -f $i)) {
                        $choosenetadapt += 1
                    }

                }

                if ($choosenetadapt -match 0) {
                    Write-Host "No network adapter named $vmna was found on $setvmna." -fore red

                    $trysetvmna = Read-Host -Prompt "Would you like to try again? [Y]es or [N]o"

                    if ($trysetvmna -match '^[nN]$') {
                        Write-Host "Exiting..." -fore red
                    }
                }
                else {
                    $networkname = Read-Host -Prompt "Please choose a network adapter network (default is $vmnetwork)"

                    if (-not $networkname) {
                        $networkname = $vmnetwork
                    }
                    
                    Write-Host "Setting network adapter $vmna to $networkname..."
                    Get-VM $setvmna | Get-NetworkAdapter -Name $vmna | Set-NetworkAdapter -NetworkName $networkname -ErrorVariable err -ea SilentlyContinue

                    if ($err) {
                        Write-Host "There was an issue setting the vm network adapter." -fore red
                        $trysetvmna = Read-Host -Prompt "Would you like to try again? [Y]es or [N]o"

                        if ($trysetvmna -match '^[nN]$') {
                            Write-Host "Exiting..." -fore red
                        }
                    }
                    else {
                        Write-Host "VM Network Adapter $vmna was set to $networkname on $setvmna" -fore green
                        $trysetvmna = 'n'
                    }
                    
                }
            }
        }

        if ($trysetvmna -notmatch 'n') {
            # If there's no matches at all, it asks if they want to try again.
            Write-Host "No VM of that name was found. Try again?" -fore red
            $trysetvmna = Read-Host -Prompt "[Y]es try again, or [N]o, don't try again."

            if ($trysetvmna -notmatch '^[yY]$') {
                # If they say no to trying again, it exits.
                Write-Host "Exiting..." -fore red
            } 
        }
    }
}

Function newportandvs {
    $tryswndport = 'y'
    While ($tryswndport -match '^[yY]$') {
        Write-Host "Would you like to create a new switch or a new port group?
[1] Switch
[2] Port Group
[3] Go Back"
        $sworport = Read-Host -Prompt "Choose"

        switch ($sworport) {
            '1' {
                $tryswitch = 'y'
                While ($tryswitch -match '^[yY]$') {
                    Write-Host "Listing existing switches..."
                    Get-VirtualSwitch
                    $newswitch = Read-Host -Prompt "Please enter the name of the new virtual switch"

                    Write-Host "Listing existing VM Hosts..."
                    Get-VMHost | Select-Object Name 
                    $getvmh = Read-Host -Prompt "Please enter the VM Host (default is $vmhost)"

                    if (-not $getvmh) {
                        $getvmh = $vmhost
                    }
                
                    New-VirtualSwitch -name $newswitch -VMHost $getvmh -ErrorVariable err -ea SilentlyContinue

                    if ($err) {
                        Write-Host "There was an issue attempting to create a new virtual switch named $newswitch on $getvmh." -fore red
                        $tryswitch = Read-Host -Prompt "Try again? [Y]es or [N]o"

                        if ($tryswitch -match '^[nN]$') {
                            Write-Host "Exiting..." -fore red
                            
                        }
                    }
                    else {
                        $portbool = Read-Host -Prompt "Create a matching port group as well? [Y]es or [N]o"
                        if ($portbool -match '^[yY]$') {
                            Get-VirtualSwitch -Name $newswitch | New-VirtualPortGroup -Name $newswitch -ErrorVariable err -ea SilentlyContinue #| Select-Object Name,VirtualSwitch

                            if ($err) {
                                Write-Host "There was an issue attempting to create a new port group named $newswitch for virtual switch $newswitch on $getvmh." -fore red
                                $tryswitch = Read-Host -Prompt "Try again? [Y]es or [N]o"

                                if ($tryswitch -match '^[nN]$') {
                                    Write-Host "Exiting..." -fore Red
                                }
                            }
                        }
                        else {
                            $tryswitch = 'n'
                        }
                        $tryswitch = 'n'
                    }
                }
            }
            '2' {
                $tryport = 'y'
                While ($tryport -match '^[yY]$') {
                    Write-Host "Listing virtual port groups..."
                    $listvpgs = @(Get-VirtualPortGroup | Select-Object Name | ForEach-Object { $_ -replace "@{Name=", "" -replace "}", "" })
                    foreach ($i in $listvpgs) {
                        Write-Host $i
                    }
                    $newportgroup = Read-Host -Prompt "Please enter the name of the new port group"

                    Write-Host "Listing virtual switches..."
                    Get-VirtualSwitch
                    $selswitch = Read-Host -Prompt "Please enter the name of a switch"

                    $listswitch = @(Get-VirtualSwitch | Select-Object Name | ForEach-Object { $_ -replace "@{Name=", "" -replace "}", "" })
                    foreach ($i in $listswitch) {
                        Write-Host $i
                        if ($i -match $selswitch) {
                            $yesswitch = 1
                        }
                    }
                    if ($yesswitch) {
                        Get-VirtualSwitch -Name $selswitch | New-VirtualPortGroup -Name $newportgroup -ErrorVariable err -ea SilentlyContinue

                        if ($err) {
                            Write-Host "There was an issue creating new port group $newportgroup for switch $selswitch." -fore red
                            $tryport = Read-Host -Prompt "Try again? [Y]es or [N]o"

                            if ($tryport -match '^[nN]$') {
                                Write-Host "Exiting..." -fore red
                            }
                        }
                        else {
                            Write-Host "$newportgroup was added for $selswitch." -fore green
                            Write-Host $err
                            $tryport = 'n'
                        }
                    }
                    else {
                        Write-Host "There was an issue creating new port group $newportgroup for non-existing switch $selswitch." -fore red
                        $tryport = Read-Host -Prompt "Try again? [Y]es or [N]o"

                        if ($tryport -match '^[nN]$') {
                            Write-Host "Exiting..." -fore red
                        }
                    }
                }
            }
            '3' {
                $tryswndport = 'n'
            }
        }
        
    }   
}

Function retrieveip {
    $tryip = 'y'
    While ($tryip -match '^[yY]$') {
        Get-VM | Sort-Object -Property Name
        $setvm = Read-Host -Prompt "Select a VM to retrieve the IP of"
        $thevm = Get-VM -Name $setvm -ErrorVariable err -ea silentlycontinue

        if ($err) {
            Write-Host "There was an issue with VM $setvm." -fore red
            $tryip = Read-Host -Prompt "Try again? [Y]es or [N]o"

            if ($tryip -match '^[nN]$') {
                Write-Host "Exiting..." -fore Red
            }
        } else {
            $output = $thevm.guest.IPAddress[0] + " hostname=" + $setvm
            Write-Host $output
            $tryip = 'n'
        }
    }
}

connectvcenter

if ($global:DefaultVIServers) {
    # If there's a connection to a vcenter server.
    Write-Host "Now connected to $global:visername."
    while ($true) {
        Write-Host "
Please choose an option:
[1] Create a linked or full VM clone
[2] Start a VM
[3] Set a VM's network adapter(s)
[4] Add a virtual switch and portgroup
[5] Retrieve the first IP address of a VM
[6] Exit Program"
        $what = Read-Host -Prompt "Choose"

        switch ($what) {
            '1' {
                clonevms
            }
            '2' {
                startvms
            }
            '3' {
                setvmnetadapt
            }
            '4' {
                newportandvs
            }
            '5' {
                retrieveip
            }
            '6' {
                Write-Host "Exiting..." -fore green
                Exit
            }
        }
    }
}