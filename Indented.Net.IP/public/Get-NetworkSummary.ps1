function Get-NetworkSummary {
    # .SYNOPSIS
    #   Generates a summary describing several properties of a network range
    # .DESCRIPTION
    #   Get-NetworkSummary uses many of the IP conversion CmdLets to provide a summary of a network range from any IP address in the range and a subnet mask.
    # .PARAMETER IPAddress
    #   Either a literal IP address, a network range expressed as CIDR notation, or an IP address and subnet mask in a string.
    # .PARAMETER SubnetMask
    #   A subnet mask as an IP address.
    # .INPUTS
    #   System.Net.IPAddress
    #   System.String
    # .OUTPUTS
    #   Indented.Net.IP.NetworkSummary (System.Management.Automation.PSObject)
    # .EXAMPLE
    #   Get-NetworkSummary 192.168.0.1 255.255.255.0
    # .EXAMPLE
    #   Get-NetworkSummary 10.0.9.43/22
    # .EXAMPLE
    #   Get-NetworkSummary 0/0
    # .NOTES
    #   Author: Chris Dent
    #
    #   Change log:
    #     07/03/2016 - Chris Dent - Cleaned up code, added tests.
    #     25/11/2010 - Chris Dent - Created.

    [OutputType([System.Management.Automation.PSObject])]
    param(
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [String]$IPAddress,

        [Parameter(Position = 2)]
        [String]$SubnetMask
    )

    process {
        try {
            $Network = ConvertToNetwork @psboundparameters
        } catch {
            throw $_
        }
        
        $DecimalIP = ConvertTo-DecimalIP $Network.IPAddress
        $DecimalMask = ConvertTo-DecimalIP $Network.SubnetMask
        $DecimalNetwork =  $DecimalIP -band $DecimalMask
        $DecimalBroadcast = $DecimalIP -bor ((-bnot $DecimalMask) -band [UInt32]::MaxValue)
    
        $NetworkSummary = [PSCustomObject]@{
            NetworkAddress    = (ConvertTo-DottedDecimalIP $DecimalNetwork);
            NetworkDecimal    = $DecimalNetwork
            BroadcastAddress  = (ConvertTo-DottedDecimalIP $DecimalBroadcast);
            BroadcastDecimal  = $DecimalBroadcast
            Mask              = $Network.SubnetMask;
            MaskLength        = (ConvertTo-MaskLength $Network.SubnetMask);
            MaskHexadecimal   = (ConvertTo-HexIP $Network.SubnetMask);
            CIDRNotation      = ""
            HostRange         = "";
            NumberOfAddresses = ($DecimalBroadcast - $DecimalNetwork + 1)
            NumberOfHosts     = ($DecimalBroadcast - $DecimalNetwork - 1);
            Class             = "";
            IsPrivate         = $false
        } | Add-Member -TypeName 'Indented.Net.IP.NetworkSummary' -PassThru

        $NetworkSummary.CIDRNotation = '{0}/{1}' -f $NetworkSummary.NetworkAddress, $NetworkSummary.MaskLength

        if ($NetworkSummary.NumberOfHosts -lt 0) {
            $NetworkSummary.NumberOfHosts = 0
        }
        if ($NetworkSummary.MaskLength -lt 31) {
            $NetworkSummary.HostRange = '{0} - {1}' -f (ConvertTo-DottedDecimalIP ($DecimalNetwork + 1)), (ConvertTo-DottedDecimalIP ($DecimalBroadcast - 1))
        }
    
        switch -regex (ConvertTo-BinaryIP $Network.IPAddress) {
            "^1111"              { $NetworkSummary.Class = "E"; break }
            "^1110"              { $NetworkSummary.Class = "D"; break }
            "^11000000.10101000" { $NetworkSummary.Class = "C"; if ($NetworkSummary.MaskLength -ge 16) { $NetworkSummary.IsPrivate = $true }; break }
            "^110"               { $NetworkSummary.Class = "C" }
            "^10101100.0001"     { $NetworkSummary.Class = "B"; if ($NetworkSummary.MaskLength -ge 12) { $NetworkSummary.IsPrivate = $true }; break }
            "^10"                { $NetworkSummary.Class = "B"; break }
            "^00001010"          { $NetworkSummary.Class = "A"; if ($NetworkSummary.MaskLength -ge 8) { $NetworkSummary.IsPrivate = $true}; break }
            "^0"                 { $NetworkSummary.Class = "A"; break }
        }   
    
        return $NetworkSummary
    }
}