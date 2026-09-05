param(
    [string]$Interface,
    [switch]$ListInterfaces,
    [uint32]$Sequence = 1,
    [uint16]$Instrument = 0x1234,
    [uint32]$Price = 12345,
    [uint32]$Quantity = 100,
    [byte]$MessageType = 1
)

$sender = Join-Path $PSScriptRoot "send_market_packet.py"
$senderArguments = @()

if ($ListInterfaces) {
    $senderArguments += "--list-interfaces"
} else {
    if ([string]::IsNullOrWhiteSpace($Interface)) {
        throw "Specify -Interface, or use -ListInterfaces first."
    }
    $senderArguments += @(
        "--interface", $Interface,
        "--sequence", $Sequence,
        "--instrument", $Instrument,
        "--price", $Price,
        "--quantity", $Quantity,
        "--message-type", $MessageType
    )
}

& py -3 $sender @senderArguments
if ($LASTEXITCODE -ne 0) {
    throw "Packet sender exited with code $LASTEXITCODE."
}
