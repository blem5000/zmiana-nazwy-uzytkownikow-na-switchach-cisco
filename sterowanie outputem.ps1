# Install the Posh-SSH Module
if (Get-Module -Name Posh-SSH){}
else {
    <# Action when all if and elseif conditions are false #>
    Install-Module -Name Posh-SSH
}


# Zamyka wszystkie sessje ssh, out-null sprawia że nie ma potwierdzenia po wykonaniu komendy
Get-SSHSession | Remove-SSHSession | Out-Null

# Funkcja usuwania roota
function UsunRoot {
    $SSHStream.WriteLine(" ")
    Start-Sleep 4
    $output = $SSHStream.read()
    if($output -notlike "*(config)#*")
    {
        $SSHStream.WriteLine("conf t")
        Start-Sleep 2
        Write-Host "Usuwam uzytkownika root"
        $SSHStream.WriteLine("no username root")
        Start-Sleep 4
        $output = $SSHStream.read()
        #Write-Host($output)
        if ($output -like "*This operation will remove all username*")
            {
                $SSHStream.WriteLine("y")
                Start-Sleep 2
                Write-Host "root został usunięty"
            }
        $SSHStream.WriteLine("end")
        Start-Sleep 2
        $SSHStream.WriteLine("sh run | i username root")
        Start-Sleep 2
        $output = $SSHStream.read()
        #Write-Host($output)
        if ($output -like "*username root privilege 15 secret*")
            {
                Write-Host "Usuniecie roota nie powiodło się!"
                Return
            }
        else
        {
            Write-Host "Root został usunięty!"
            return
        }

    }
    else {
        <# Action when all if and elseif conditions are false #>
    }
}

function New-Maadmin
{
                    Write-Host "Na switchu nie ma jeszcze użytkownika maadmin. Spróbuję go stworzyć z hasłem secret 9"
                    $SSHStream.WriteLine("conf t")
                    Start-Sleep 2
                    

                    $SSHStream.WriteLine('username maadmin privilege 15 secret 9 $9$9G7QTAzuMh7AA1$aUhOBFi.KBiU89ekGE8e2eYVo2KX4qDwAiDk7sCc7pg')
                    Start-Sleep 4
                    $output = $SSHStream.read()

                    if($output -like "*Replacing <username maadmin privilege 15 secret*") {
                            Write-Host "Switch nie obsluguje secret 9, spróbuję ze starszym szyfrowaniem"
                            $SSHStream.WriteLine('username maadmin privilege 15 secret 5 $1$CBjj$ace0Czs0eP5cWKCfc/bMj.')
                            Start-Sleep 2
                            $SSHStream.WriteLine("do sh run | username maadmin")
                            Start-Sleep 3
                            $output = $SSHStream.read() 
                            if($output -like "*username maadmin privilege 15 secret*"){
                                $SSHStream.WriteLine("end")
                                Write-Host "Usuwam uzytkownika root"
                                UsunRoot
                                  
                            }

                            else {
                                Write-Host "Blad maadmin nie zostal stworzony!"
                                
                            } 
                                                       
                    }
                    
                    if($output -like "*username maadmin privilege 15 secret 9*") {
                        $SSHStream.WriteLine("end")
                        Write-Host "Usuwam uzytkownika root"
                        UsunRoot
                          
                    }
}


# lista adresow IP

$ipStart = Read-Host "Podaj poczatek zakresu IP"
$ipEnd = Read-Host "Podaj koniec zakresu IP"
$ipBase = Read-Host "Podaj podsiec"

if ($ipBase[-1] -ne ".") {
    $ipBase = $ipBase + "."
    <# Action to perform if the condition is true #>
}

# Set Credentials
if ( -not $mycreds) {
$mycreds = Get-Credential -UserName root -Message "Podaj hasło roota"
$haslo = $mycreds.GetNetworkCredential().Password
$mycreds2 = New-Object System.Management.Automation.PSCredential -ArgumentList "maadmin", (ConvertTo-SecureString -AsPlainText $haslo -Force)
}

foreach ($i in $ipStart..$ipEnd) {
    $ip = $ipBase + $i
    # Ping the IP address
    $pingStatus = Test-Connection -ComputerName $ip -Count 1 -Quiet
    $poswiadczenia = $mycreds
    if ($pingStatus) {
        # Build SSH session
        $sessionCreated = $false
        while (-not $sessionCreated) {
            try {
                New-SSHSession $ip -Port 22 -Credential $poswiadczenia -ErrorAction Stop -AcceptKey
                $sessionCreated = $true
            } catch { 
                Write-Host "Blad: $_"
                if ($_.Exception.Message.Contains("Permission denied (keyboard-interactive)") -or $_.Exception.Message.Contains("An established connection was aborted by the server.")) {
                    Write-Host "Poswiadczenia root niepoprawne sprawdzam maadmin."
                    $poswiadczenia = $mycreds2
                } else {
                    throw $_
                }
            } 
        }

        # Assign current session to Var.
        $s = Get-SSHSession | Select-Object -ExpandProperty SessionID -First 1

        # Send SSH Commands
        $SSHStream = New-SSHShellStream -Index $s

        # Sprawdzenie czy na switchu zmieniono juz uzytkownika
        $SSHStream.WriteLine("sh run | i root")
        Start-Sleep 5
        $output = $SSHStream.read()
        if($output -like "*username root*")
        {
            Write-Host "Na Switchu wciąż istnieje użytkownik root, zobaczmy maadmin"

            $SSHStream.WriteLine("sh run | i maadmin")
            Start-Sleep 4
            $output = $SSHStream.read()

            if($output -like "*username maadmin*")
                {
                    Write-Host "Na Switchu istnieje juz użytkownik maadmin, mozna usunac uzytkownika root"
                    UsunRoot
                }
                else
                {
                    New-Maadmin
                }
        }
            else
            {
                Write-Host "Na Switchu nie ma juz użytkownika root, pomijam"
            }

        

        # Zamyka wszystkie sessje ssh, out-null sprawia że nie ma potwierdzenia po wykonaniu komendy
        Get-SSHSession | Remove-SSHSession | Out-Null

    } else {
        Write-Output "Ping to $ip failed"
    }
}

                        