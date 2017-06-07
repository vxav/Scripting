Function New-RandomPassword {

param(
    [ValidateRange(6,30)]
    [int]$length = 12,
    [switch]$uppercase,
    [switch]$lowercase,
    [switch]$numbers,
    [switch]$special,
    [string[]]$excludedchars
)

IF (!$uppercase -and !$lowercase -and !$numbers -and !$special) {write-warning "Please specify characters to use";break}

$upperID   = 65..90
$lowerID   = 97..122
$numberID  = 48..57
$specialID = 33..47+58..64+91..96+123..126

IF ($uppercase) {$range += $upperID}
IF ($lowercase) {$range += $lowerID}
IF ($numbers) {$range += $numberID}
IF ($special) {$range += $specialID}

$allowedchar = @()

foreach ($i in $range) {
    
    IF ([char]$i -notin $excludedchars) {$allowedchar += [char]$i}

}

$BadPass = "I don't want to be bad"

while ($BadPass) {
    
    if ($BadPass) {Clear-Variable badpass}
    if ($RandomPassword) {Clear-Variable RandomPassword}

    for ($i = 1; $i –le $length; $i++) {

        $randomIndex = Get-Random -Maximum $allowedchar.count

        $RandomPassword += $allowedchar[$randomIndex]

    }

    IF ($lowercase) {IF ($RandomPassword -cnotmatch "[a-z]") {$BadPass++}}
    IF ($uppercase) {IF ($RandomPassword -cnotmatch "[A-Z]") {$BadPass++}}
    IF ($numbers)   {IF ($RandomPassword -notmatch "[0-9]") {$BadPass++}}
    IF ($special)   {IF ($RandomPassword -cnotmatch '[^a-zA-Z0-9]') {$BadPass++}}

}

Return $RandomPassword

}