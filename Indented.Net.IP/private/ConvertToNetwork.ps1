function ConvertToNetwork {
    # .SYNOPSIS
    #   Converts IP address formats to a set a known styles.
    # .DESCRIPTION
    #   Internal use only.
    #
    #   ConvertToNetwork ensures consistent values are recorded from parameters which must handle differing addressing formats. This Cmdlet allows all other the other functions in this module to offload parameter handling.
    # .PARAMETER IPAddress
    #   Either a literal IP address, a network range expressed as CIDR notation, or an IP address and subnet mask in a string.
    # .PARAMETER SubnetMask
    #   A subnet mask as an IP address.
    # .INPUTS
    #   System.String
    # .OUTPUTS
    #   Indented.Net.IP.Network
    # .NOTES
    #   Author: Chris Dent
    #
    #   Change log:
    #     05/03/2016 - Chris Dent - Refactored and simplified.
    #     14/01/2014 - Chris Dent - Created.
  
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [String]$IPAddress,

        [Parameter(Position = 2)]
        [AllowNull()]
        [String]$SubnetMask
    )

    if (-not $Script:ValidSubnetMaskValues) {
        $Script:ValidSubnetMaskValues = 
            "0.0.0.0", "128.0.0.0", "192.0.0.0", 
            "224.0.0.0", "240.0.0.0", "248.0.0.0", "252.0.0.0",
            "254.0.0.0", "255.0.0.0", "255.128.0.0", "255.192.0.0",
            "255.224.0.0", "255.240.0.0", "255.248.0.0", "255.252.0.0",
            "255.254.0.0", "255.255.0.0", "255.255.128.0", "255.255.192.0",
            "255.255.224.0", "255.255.240.0", "255.255.248.0", "255.255.252.0",
            "255.255.254.0", "255.255.255.0", "255.255.255.128", "255.255.255.192",
            "255.255.255.224", "255.255.255.240", "255.255.255.248", "255.255.255.252",
            "255.255.255.254", "255.255.255.255"
    }
 
    $Network = [PSCustomObject]@{
        IPAddress  = $null
        SubnetMask = $null
        MaskLength = 0
    } | Add-Member -TypeName 'Indented.Net.IP.Network' -PassThru
    
    # Override ToString
    $Network | Add-Member ToString -MemberType ScriptMethod -Force -Value {
        '{0}/{1}' -f $this.IPAddress, $this.MaskLength
    }

    if (-not $psboundparameters.ContainsKey('SubnetMask') -or $SubnetMask -eq '') {
        $IPAddress, $SubnetMask = $IPAddress.Split('\/ ', [StringSplitOptions]::RemoveEmptyEntries)
    }
    
    # IPAddress
    
    while ($IPAddress.Split('.').Count -lt 4) {
        $IPAddress += '.0'
    }
    
    if ([IPAddress]::TryParse($IPAddress, [Ref]$null)) {
        $Network.IPAddress = [IPAddress]$IPAddress
    } else {
        $ErrorRecord = New-Object System.Management.Automation.ErrorRecord(
            (New-Object ArgumentException 'Invalid IP address.'),
            'InvalidIPAddress',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $IPAddress
        )
        throw $ErrorRecord
    }
    
    # SubnetMask
    
    if ($null -eq $SubnetMask -or $SubnetMask -eq '') {
        $Network.SubnetMask = [IPAddress]$Script:ValidSubnetMaskValues[32]
        $Network.MaskLength = 32 
    } else {
        $MaskLength = 0
        if ([Int32]::TryParse($SubnetMask, [Ref]$MaskLength)) {
            if ($MaskLength -ge 0 -and $MaskLength -le 32) {
                $Network.SubnetMask = [IPAddress]$Script:ValidSubnetMaskValues[$MaskLength]
                $Network.MaskLength = $MaskLength
            } else {
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object ArgumentException 'Mask length out of range (expecting 0 to 32).'),
                    'InvalidMaskLength',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $SubnetMask
                )
                throw $ErrorRecord                    
            }
        } else {
            while ($SubnetMask.Split('.').Count -lt 4) {
                $SubnetMask += '.0'
            }
            $MaskLength = $Script:ValidSubnetMaskValues.IndexOf($SubnetMask) 
            
            if ($MaskLength -ge 0) {
                $Network.SubnetMask = [IPAddress]$SubnetMask
                $Network.MaskLength = $MaskLength
            } else {
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object ArgumentException 'Invalid subnet mask.'),
                    'InvalidSubnetMask',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $SubnetMask
                )
                throw $ErrorRecord
            }
        }
    }
    
    return $Network
}