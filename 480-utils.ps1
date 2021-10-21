clear
$vser = "vcenter.tao.local"
$global:basevm = $null
$global:snshname = "Safe"
$global:vmhost = "192.168.3.20"
$global:ds = "datastore2-super10"

$global:lvm = $null
$global:bvm = $null
$global:snsh = $null
$global:vmh = $null
$global:dstore = $null
$global:nvm = $null

Function connectvcenter { # This is just to connect to the vcenter server. It will always ask first which server to connect to. There's only one in this case. If there is an issue connecting to or logging in, it asks if you would like to try again.
    $tryvser = 'y'
    
    while ($tryvser -notmatch '^[nN]$') {
        $vseranswer = Read-Host -Prompt "Enter the vcenter server you would like to connect to [default is $vser]"
        
        if (($vseranswer) -and ($vseranswer -notmatch $vser)) {
            Write-Host "Connecting to vcenter server $vseranswer..." -fore green
            $connpos = Connect-VIServer($vseranswer) -ErrorVariable err -ea SilentlyContinue
            
            if ($err) {
                $tryvser = Read-Host -Prompt "There was an issue using the vcenter server $vseranswer. Would you like to try again? [Y]es try again, or [N]o"
                
                if ($tryvser -notmatch '^[yY]$') {
                    Write-Host "Exiting..." -fore red
                    exit
                }
            } else {
                $tryvser = 'n'
            }
        } else {
            Write-Host "Using default vcenter server..." -fore green
            if ($global:DefaultVIServers) { 
                $tryvser = 'n'
            } else {
                $connpos = Connect-VIServer($vser) -ErrorVariable err -ea SilentlyContinue
                
                if ($err) {
                    $tryvser = Read-Host -Prompt "There was an issue using the vcenter server $vser. Would you like to try again? [Y]es try again, or [N]o"

                    if ($tryvser -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $tryvser = 'n'
                }
            }
        }
    }
}

Function getbasevm { # this one will list the available vms to clone. It will ask the user to enter the full name of the vm they would like to clone. If there's no match found, it asks if they want to try again. 
    $vmtable = @(Get-VM | Sort-object | Select-Object Name | % {$_ -replace "@{Name=","" -replace "}",""})
    Write-Host "Beginning the cloning process. Some information is needed first. Here is a list of the VMs that can be cloned:"

    foreach ($i in $vmtable) {
        Write-Host $i
    }
    $tryvm = 'y'

    while ($tryvm -notmatch '^[nN]$') {
        $global:basevm = Read-Host -Prompt "Please enter the full name of the vm you are cloning"
        $novm = 'n'
        
        foreach ($i in $vmtable) {

            if ($global:basevm -match ('^{0}$' -f $i)) {
                Write-Host "Match found: $i" -fore green
                $novm = 'y'
                $tryvm = 'n'
                $global:bvm = Get-VM -name $global:basevm
                Write-Host "Base VM set." -fore green
            }
        }

        if ($novm -notmatch 'y') {
            Write-Host "No VM of that name was found. Try again?" -fore red
            $tryvm = Read-Host "[Y]es try again, or [N]o, don't try again."

            if ($tryvm -notmatch '^[yY]$') {
                Write-Host "Exiting..." -fore red
                exit
            } 
        }
    }
    #Write-Host $global:bvm
}

Function getbvmsnsh { # as with the base vms, this lists the snapshots on the vm. It asks the user to specify a snapshot by name. If there was an issue getting that snapshot in some shape or form, it asks if they want to try again. If it can't find any snapshots, it exits the program.
    Write-Host "The following is a list of snapshots available on $global:bvm :"
    $snshlist = Get-Snapshot -vm $global:bvm
    Write-Host $snshlist
    if ($snshlist) {
        $trysnsh = 'y'

        while ($trysnsh -notmatch '^[nN]$') {
            $snshanswer = Read-Host -Prompt "Please enter the name of the snapshot to utilize from $global:bvm (default is $global:snshname)"

            if ($snshanswer) {
                $global:snsh = Get-Snapshot -vm $global:bvm -name $snshanswer -ErrorVariable err -ea SilentlyContinue

                if ($err) {
                    $trysnsh = Read-Host -Prompt "There was an issue retrieving a snapshot by the name of $snshanswer from $global:bvm. Try again? [Y]es or [N]o"
                    
                    if ($trysnsh -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $trysnsh = 'n'
                    Write-Host "Snapshot set." -fore green
                }
            } else {
                $global:snsh = Get-Snapshot -vm $global:bvm -name $global:snshname -ErrorVariable err -ea SilentlyContinue

                if ($err) {
                    $trysnsh = Read-Host -Prompt "There was an issue retrieving a snapshot by the name of $global:snsh from $global:bvm. Try again? [Y]es or [N]o"

                    if ($trysnsh -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $trysnsh = 'n'
                    Write-Host "Snapshot set." -fore green
                }
            }
        }
    } else {
        Write-Host "This vm does not have any snapshots..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
    #Write-Host $global:snsh 
}

Function getesxihost { # The same with the snapshots, just the esxi hosts.
    Write-Host "The following is a list of ESXi Hosts:"
    $vmhlist = Get-VMHost
    Write-Host $vmhlist

    if ($vmhlist) {
    $tryesxi = 'y'

        while ($tryesxi -notmatch '^[nN]$') {
            $esxianswer = Read-Host -Prompt "Please enter the IP address/Name of  the ESXi Host to use (default is $global:vmhost)"

            if ($esxianswer) {
                $global:vmh = Get-VMHost -name $esxianswer -ErrorVariable err -ea Silentlycontinue

                if ($err) {
                    $tryesxi = Read-Host -Prompt "There was an issue with the ESXi host $esxianswer. Try again? [Y]es or [N]o"

                    if ($tryesxi -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $tryesxi = 'n'
                    Write-Host "ESXi Host set." -fore green
                }
            } else {
                $global:vmh = Get-VMHost -name $global:vmhost -ErrorVariable err -ea SilentlyContinue

                if ($err) {
                    $tryesxi = Read-Host -Prompt "There was an issue with the ESXi host $global:vmhost. Try again? [Y]es or [N]o"

                    if ($tryesxi -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $tryesxi = 'n'
                    Write-Host "ESXi Host set." -fore green
                }
            }
            #Write-Host $global:vmh
        }
    } else {
        Write-Host "There are no ESXi Hosts..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getds { # Also the same with the vms, snapshots, and esxi hosts.
    Write-Host "The following is a list of datastores:"
    $dslist = Get-Datastore
    Write-Host $dslist

    if ($dslist) {
        $tryds = 'y'

        while ($tryds -notmatch '^[nN]$') {
            $dsanswer = Read-Host -Prompt "Please enter the name of the datastore to use (default is $global:ds)"

            if ($dsanswer) {
                $global:dstore = Get-Datastore -name $dsanswer -ErrorVariable err -ea SilentlyContinue

                if ($err) {
                    $tryds = Read-Host -Prompt "There was an issue finding datastore $dsanswer. Try again? [Y]es or [N]o"

                    if ($tryds -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $tryds = 'n'
                    Write-Host "Datastore set." -fore green
                }
            } else {
                $global:dstore = Get-Datastore -name $global:ds -ErrorVariable err -ea SilentlyContinue

                if ($err) {
                    $tryds = Read-Host -Prompt "There was an issue finding datastore $global:ds. Try again? [Y]es or [N]o"

                    if ($tryds -notmatch '^[yY]$') {
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else {
                    $tryds = 'n'
                    Write-Host "Datastore set." -fore green
                }
            }
        }
        #Write-Host $global:dstore
    } else {
        Write-Host "There are no datastores..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getlinkedvm { # creates a linked vm clone.
    Write-Host "Creating the linked vm..."
    $lname = Read-Host -Prompt "Please enter the name for this linked vm"
    $global:lvm = new-vm -LinkedClone -name $lname -vm $global:bvm -referencesnapshot $global:snsh -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    if ($err) {
        Write-Host "There was an issue creating the linked vm $lname." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else {
        Write-Host "Linked vm created." -fore green
        #Write-Host $global:lvm
    }
}

Function getnvm { # creates a linked vm clone and then a full clone based on the linked clone.
    Write-Host "Creating the temporary linked vm..."
    $lname = "{0}.linked" -f $global:basevm
    $global:lvm = new-vm -LinkedClone -name $lname -vm $global:bvm -referencesnapshot $global:snsh -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    if ($err) {
        Write-Host "There was an issue creating the temporary linked vm." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else {
        Write-Host "Temporary linked vm created." -fore green
        #Write-Host $global:lvm
    }

    Write-Host "Creating new vm..."
    $vmname = Read-Host -Prompt "Please name the new vm"
    Write-Host "Creating the new vm $vmname..."
    $global:nvm = new-vm -name $vmname -vm $global:lvm -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    if ($err) {
        Write-Host "There was an issue creating the new vm." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else {
        Write-Host "The new vm $vmname has been created!" -fore green
        Write-Host "Please do not forget about the temporary $lname. It is suggested that you delete it manually using [Remove-VM -name $lname]." -fore blue
        #Write-Host $global:nvm
    }
}

connectvcenter

if ($connpos) {
    getbasevm
    getbvmsnsh
    getesxihost
    getds
    $tryclone = 'y'
    
    while ($tryclone -notmatch '^[nN]$') { # Asks whether the user wants to create a linked clone only or a full clone. 
        $clonetype = Read-Host -Prompt "Would you like to create a [L]inked clone or a [F]ull clone?"

        if ($clonetype -match '^[lL]$') {
            getlinkedvm
            $tryclone = 'n'
        } elseif ($clonetype -match '^[fF]$') {
            getnvm
            $tryclone = 'n'
        } else {
            Write-Host "Invalid answer. Would you like to try again?" -fore red
            $tryclone = Read-Host -Prompt "[Y]es or [N]o"

            if ($tryclone -notmatch '^[yY]$') {
                Write-Host "Exiting..." -fore red
                exit
            }
        }
    }
}

Write-Host "Exiting..." -fore green