$vser = "vcenter.tao.local"
$snshname = "Safe"
$vmhost = "192.168.3.20"
$ds = "datastore2-super10"
#Disconnect-VIServer -Server * -Force -ea SilentlyContinue

Function connectvcenter {
    $tryvseragain = "y"
    while ($tryvseragain -notmatch '^[nN]$') {
        $vseranswer = Read-Host -Prompt "Enter the vcenter server you would like to connect to [default is $vser]"
        if ($vseranswer) {
            Write-Host "Connecting to vcenter server $vseranswer..."
            $connpos = Connect-VIServer($vseranswer) -ErrorVariable err -ea SilentlyContinue
            if ($err) {
                $tryvseragain = Read-Host -Prompt "There was an issue using the vcenter server $vseranswer. Would you like to try again?
[Y]es try again, or [N]o"
                if ($tryvseragain -notmatch '^[yY]$') {
                    Write-Host "Exiting..."
                    exit
                }
            }
            $tryvseragain = "n"
            $moveon = 'y'
        } else {
            Write-Host "Using default vcenter server..."
            $connpos = Connect-VIServer($vser) -ErrorVariable err -ea SilentlyContinue
            if ($err) {
                $tryvseragain = Read-Host -Prompt "There was an issue using the vcenter server $vser. Would you like to try again?
[Y]es try again, or [N]o"
                if ($tryvseragain -notmatch '^[yY]$') {
                    Write-Host "Exiting... $connpos"
                    exit
                }
            }
            $tryvseragain = 'n'
            $moveon = 'y'
            Write-Host "$connpos"
        }
    }
}

connectvcenter

if ($moveon) {
    Get-VM
}