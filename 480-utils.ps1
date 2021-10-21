# TO DO
#   Reformat it so that there's not a ton of different variables.
#   Create a function to add a virtual switch and portgroup
#   Make it pull from a configuration file
#   Add a function that creates a blueX-LAN network (?)
#   Create the blueX-fw vm (via full clone or linked)
#   Create a function to start a vm by name
#   Create a function to set the network adapters of a virtual machine to a network of choice
#   Create a function to get the first IP address of a running VM. Output to be in ansible inventory format.

clear
$vser = "vcenter.tao.local" # name variable for vcenter connection
$global:basevm = $null # name variable for the base vm for any cloning process
$global:snshname = "Safe" # name variable for snapshot
$global:vmhost = "192.168.3.20" # name variable for esxi host
$global:ds = "datastore2-super10" # name variable for datastore

# These are all of the official variables used to make the clone vms.
$global:lvm = $null
$global:bvm = $null
$global:snsh = $null
$global:vmh = $null
$global:dstore = $null
$global:nvm = $null

Function connectvcenter { 
# This is just to connect to the vcenter server. It will always ask first which server to connect to. 
# There's only one in this case. If there is an issue connecting to or logging in, it asks if you would like to try again.

    $tryvser = 'y'
    
    while ($tryvser -notmatch '^[nN]$') { # While it still needs to get the proper vcenter server connection...
        $vseranswer = Read-Host -Prompt "Enter the vcenter server you would like to connect to [default is $vser]"
        
        if (($vseranswer) -and ($vseranswer -notmatch $vser)) { # If the user answers a server that does not match the default, it starts the connection process.
            Write-Host "Connecting to vcenter server $vseranswer..." -fore green
            Connect-VIServer($vseranswer) -ErrorVariable err -ea SilentlyContinue
            
            if ($err) { # If there's an error attempting to connect to the user-given server, it asks if they want to try again.
                $tryvser = Read-Host -Prompt "There was an issue using the vcenter server $vseranswer. Would you like to try again? [Y]es try again, or [N]o"
                
                if ($tryvser -notmatch '^[yY]$') { # If they say no to trying again, it exits.
                    Write-Host "Exiting..." -fore red
                    exit
                }
            } else { # If there's not an error, it continues.
                $tryvser = 'n'
            }
        } else { # If the user enters the default server or hits enter
            Write-Host "Using default vcenter server..." -fore green
            
            if ($global:DefaultVIServers) { # If it is already connected to the default server, it skips the connection process.
                $tryvser = 'n'
            } else { # If it's not connected, it begins the connecton process.
                Connect-VIServer($vser) -ErrorVariable err -ea SilentlyContinue
                
                if ($err) { # If there was an error using the default server, it asks if they want to try again.
                    $tryvser = Read-Host -Prompt "There was an issue using the vcenter server $vser. Would you like to try again? [Y]es try again, or [N]o"

                    if ($tryvser -notmatch '^[yY]$') { # If they say no to trying again, it exits.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # If there's no error, it's done.
                    $tryvser = 'n'
                }
            }
        }
    }
}

Function getbasevm { 
# This one will list the available vms to clone. It will ask the user to enter the full name of the vm they would like to clone. 
# If there's no match found, it asks if they want to try again.

    $vmtable = @(Get-VM | Sort-object | Select-Object Name | % {$_ -replace "@{Name=","" -replace "}",""})
    Write-Host "Beginning the cloning process. Some information is needed first. Here is a list of the VMs that can be cloned:"

    foreach ($i in $vmtable) { # Looping through the table of VMs to output them properly.
        Write-Host $i
    }
    $tryvm = 'y'

    while ($tryvm -notmatch '^[nN]$') { # While they need to get a proper vm...
        $global:basevm = Read-Host -Prompt "Please enter the full name of the vm you are cloning"
        $novm = 'n'
        
        foreach ($i in $vmtable) { # If their answer matches anything in the table. 
        #This can go wrong if they have vms with the same character length and the same first and ending characters.

            if ($global:basevm -match ('^{0}$' -f $i)) {
                Write-Host "Match found: $i" -fore green
                $novm = 'y'
                $tryvm = 'n'
                $global:bvm = Get-VM -name $global:basevm
                Write-Host "Base VM set." -fore green
            }
        }

        if ($novm -notmatch 'y') { # If there's no matches at all, it asks if they want to try again.
            Write-Host "No VM of that name was found. Try again?" -fore red
            $tryvm = Read-Host "[Y]es try again, or [N]o, don't try again."

            if ($tryvm -notmatch '^[yY]$') { # If they say no to trying again, it exits.
                Write-Host "Exiting..." -fore red
                exit
            } 
        }
    }
    #Write-Host $global:bvm # This is a testing write-host.
}

Function getbvmsnsh { 
# As with the base vms, this lists the snapshots on the vm. It asks the user to specify a snapshot by name. 
# If there was an issue getting that snapshot in some shape or form, it asks if they want to try again. 
# If it can't find any snapshots, it exits the program.

    Write-Host "The following is a list of snapshots available on $global:bvm :"
    $snshlist = Get-Snapshot -vm $global:bvm
    Write-Host $snshlist
    if ($snshlist) { # If there is a list of snapshots to choose from for the base vm.
        $trysnsh = 'y'

        while ($trysnsh -notmatch '^[nN]$') { # While it needs a proper snapshot...
            $snshanswer = Read-Host -Prompt "Please enter the name of the snapshot to utilize from $global:bvm (default is $global:snshname)"

            if ($snshanswer) { # If the user chooses non-default answer.
                $global:snsh = Get-Snapshot -vm $global:bvm -name $snshanswer -ErrorVariable err -ea SilentlyContinue

                if ($err) { # If there's an error with the non-default answer.
                    $trysnsh = Read-Host -Prompt "There was an issue retrieving a snapshot by the name of $snshanswer from $global:bvm. Try again? [Y]es or [N]o"
                    
                    if ($trysnsh -notmatch '^[yY]$') { # If they say no to trying again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # If there's no error with the non-default answer.
                    $trysnsh = 'n'
                    Write-Host "Snapshot set." -fore green
                }
            } else { # If they choose the default snapshot.
                $global:snsh = Get-Snapshot -vm $global:bvm -name $global:snshname -ErrorVariable err -ea SilentlyContinue

                if ($err) { # If there's an error with the default snapshot.
                    $trysnsh = Read-Host -Prompt "There was an issue retrieving a snapshot by the name of $global:snsh from $global:bvm. Try again? [Y]es or [N]o"

                    if ($trysnsh -notmatch '^[yY]$') { # If they say no to trying again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # No error, continues.
                    $trysnsh = 'n'
                    Write-Host "Snapshot set." -fore green
                }
            }
        }
    } else { # No snapshots found.
        Write-Host "This vm does not have any snapshots..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
    #Write-Host $global:snsh 
}

Function getesxihost { 
# The same with the snapshots and base vms. It lists them, asks the user for the name/ip of it.

    Write-Host "The following is a list of ESXi Hosts:"
    $vmhlist = Get-VMHost
    Write-Host $vmhlist

    if ($vmhlist) { # If there is a list of vmhosts, it continues.
    $tryesxi = 'y'

        while ($tryesxi -notmatch '^[nN]$') { # While it needs a proper vmhost...
            $esxianswer = Read-Host -Prompt "Please enter the IP address/Name of  the ESXi Host to use (default is $global:vmhost)"

            if ($esxianswer) { # If the user gives a non-default answer.
                $global:vmh = Get-VMHost -name $esxianswer -ErrorVariable err -ea Silentlycontinue

                if ($err) { # If there's an error with the user answer.
                    $tryesxi = Read-Host -Prompt "There was an issue with the ESXi host $esxianswer. Try again? [Y]es or [N]o"

                    if ($tryesxi -notmatch '^[yY]$') { # If they say no to trying again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # If there's not an error, it continues.
                    $tryesxi = 'n'
                    Write-Host "ESXi Host set." -fore green
                }
            } else { # If they use the default vmhost.
                $global:vmh = Get-VMHost -name $global:vmhost -ErrorVariable err -ea SilentlyContinue

                if ($err) { # If there's an error with the default vmhost.
                    $tryesxi = Read-Host -Prompt "There was an issue with the ESXi host $global:vmhost. Try again? [Y]es or [N]o"

                    if ($tryesxi -notmatch '^[yY]$') { # If they say no to trying again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # If there's no error, it continues.
                    $tryesxi = 'n'
                    Write-Host "ESXi Host set." -fore green
                }
            }
            #Write-Host $global:vmh # Testing only write-host.
        }
    } else { # It didn't find any vmhosts, so it exits.
        Write-Host "There are no ESXi Hosts..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getds { 
# Also the same with the vms, snapshots, and esxi hosts.

    Write-Host "The following is a list of datastores:"
    $dslist = Get-Datastore
    Write-Host $dslist

    if ($dslist) { # If there's a list.
        $tryds = 'y'

        while ($tryds -notmatch '^[nN]$') { # While it needs a proper datastore...
            $dsanswer = Read-Host -Prompt "Please enter the name of the datastore to use (default is $global:ds)"

            if ($dsanswer) { # User-answer datastore.
                $global:dstore = Get-Datastore -name $dsanswer -ErrorVariable err -ea SilentlyContinue

                if ($err) { # Error with user-answer.
                    $tryds = Read-Host -Prompt "There was an issue finding datastore $dsanswer. Try again? [Y]es or [N]o"

                    if ($tryds -notmatch '^[yY]$') { # Don't try again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # No error.
                    $tryds = 'n'
                    Write-Host "Datastore set." -fore green
                }
            } else { # Default datastore.
                $global:dstore = Get-Datastore -name $global:ds -ErrorVariable err -ea SilentlyContinue

                if ($err) { # Error with default datastore.
                    $tryds = Read-Host -Prompt "There was an issue finding datastore $global:ds. Try again? [Y]es or [N]o"

                    if ($tryds -notmatch '^[yY]$') { # Don't try again.
                        Write-Host "Exiting..." -fore red
                        exit
                    }
                } else { # No error.
                    $tryds = 'n'
                    Write-Host "Datastore set." -fore green
                }
            }
        }
        #Write-Host $global:dstore
    } else { # No datastores found.
        Write-Host "There are no datastores..." -fore red
        Write-Host "Exiting..." -fore red
        exit
    }
}

Function getlinkedvm { 
# creates a linked vm clone.

    Write-Host "Creating the linked vm..."
    $lname = Read-Host -Prompt "Please enter the name for this linked vm"
    $global:lvm = new-vm -LinkedClone -name $lname -vm $global:bvm -referencesnapshot $global:snsh -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) { # Error creating linked clone.
        Write-Host "There was an issue creating the linked vm $lname." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else { # No error creating linked clone.
        Write-Host "Linked vm created." -fore green
        #Write-Host $global:lvm
    }
}

Function getnvm { 
# creates a linked vm clone and then a full clone based on the linked clone.

    Write-Host "Creating the temporary linked vm..."
    $lname = "{0}.linked" -f $global:basevm
    $global:lvm = new-vm -LinkedClone -name $lname -vm $global:bvm -referencesnapshot $global:snsh -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) { # Error creating temporary linked clone.
        Write-Host "There was an issue creating the temporary linked vm." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else { # No error.
        Write-Host "Temporary linked vm created." -fore green
        #Write-Host $global:lvm
    }

    Write-Host "Creating new vm..."
    $vmname = Read-Host -Prompt "Please name the new vm"
    Write-Host "Creating the new vm $vmname..."
    $global:nvm = new-vm -name $vmname -vm $global:lvm -vmhost $global:vmh -datastore $global:dstore -ErrorVariable err -ea SilentlyContinue
    
    if ($err) { # Error creating new vm from linked vm.
        Write-Host "There was an issue creating the new vm." -fore red
        Write-Host "Exiting..." -fore red
        exit
    } else { # No error.
        Write-Host "The new vm $vmname has been created!" -fore green
        Write-Host "Please do not forget about the temporary $lname. It is suggested that you delete it manually using [Remove-VM -name $lname]." -fore blue
        #Write-Host $global:nvm
    }
}

Function clonevms {
# VM cloning function only.

    getbasevm
    getbvmsnsh
    getesxihost
    getds
    $tryclone = 'y'
    
    while ($tryclone -notmatch '^[nN]$') { # Asks whether the user wants to create a linked clone only or a full clone. 
        $clonetype = Read-Host -Prompt "Would you like to create a [L]inked clone or a [F]ull clone?"

        if ($clonetype -match '^[lL]$') { # If they say linked clone.
            getlinkedvm
            $tryclone = 'n'
        } elseif ($clonetype -match '^[fF]$') { # If they say full clone.
            getnvm
            $tryclone = 'n'
        } else { # If it's neither linked or full.
            Write-Host "Invalid answer. Would you like to try again?" -fore red
            $tryclone = Read-Host -Prompt "[Y]es or [N]o"

            if ($tryclone -notmatch '^[yY]$') { # If they don't wanna try again.
                Write-Host "Exiting..." -fore red
                exit
            }
        }
    }
}

connectvcenter

if ($global:DefaultVIServers) { # If there's a connection to a vcenter server.
    clonevms
}

Write-Host "Exiting..." -fore green
