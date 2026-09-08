# PS5.1-compatible mock of Invoke-RestMethod for Phase 7 compatibility tests.
#
# Rationale:
#   The canonical lib/mock-invoke-restmethod.ps1 uses PS7 class syntax
#   (`class MockHttpException : System.Exception`) which PS5.1 cannot parse
#   (verified: `Unexpected token '}' in expression or statement` at L10).
#   This PS5.1-compatible variant uses Add-Type to compile a C# exception
#   subclass at runtime, preserving the same shape:
#     - Exception subclass (so `$_` in catch has .Exception.Response)
#     - .Response property (so step2.ps1 catch block can access StatusCode/Headers)
#
# Key PS5.1 compatibility requirement (exec-plan §Phase 7):
#   The mock's Headers MUST be a System.Net.WebHeaderCollection instance
#   (NOT a Hashtable) so that step2.ps1's Get-ResponseHeaderValue function
#   exercises its `if ($Headers -is [System.Net.WebHeaderCollection])` branch
#   (SKILL L340-366). This is the primary compatibility target of T04/T05-PS5.1.
#
# Line mapping from canonical mock-invoke-restmethod.ps1:
#   Canonical L7-12 (class MockHttpException)  -> PS5.1: Add-Type with C# class
#   Canonical L14-23 (New-MockResponse)        -> PS5.1: New-MockResponsePS51
#                                                 returns PSCustomObject with
#                                                 .StatusCode + .Headers
#                                                 (Headers = WebHeaderCollection)
#   Canonical L25-91 (Invoke-RestMethod)       -> PS5.1: same switch, same
#                                                 scenario names, same codes,
#                                                 same header values
#
param([string]$Scenario = 'normal')
$ErrorActionPreference = 'Stop'

# Compile a MockHttpException subclass of System.Exception at runtime.
# This preserves the canonical shape: `$_` in catch block is a real Exception
# with a .Response property, so `$_.Exception.Response.StatusCode` and
# `$_.Exception.Response.Headers` in step2.ps1 both resolve.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public class MockHttpException : Exception {
    public object Response { get; set; }
    public MockHttpException(string message, object response) : base(message) {
        this.Response = response;
    }
}
'@

function New-MockResponsePS51 {
    param([System.Net.HttpStatusCode]$Code, [hashtable]$HeaderHashtable)
    # WebHeaderCollection is the PS5.1-native HTTP header container.
    # step2.ps1's Get-ResponseHeaderValue checks `-is [System.Net.WebHeaderCollection]`
    # and calls `.Get($Name)` on it. This is the compatibility target.
    $hc = New-Object System.Net.WebHeaderCollection
    if ($null -ne $HeaderHashtable) {
        foreach ($key in $HeaderHashtable.Keys) {
            $hc[$key] = [string]$HeaderHashtable[$key]
        }
    }
    return [PSCustomObject]@{
        StatusCode = $Code
        Headers    = $hc
    }
}

function Invoke-RestMethod {
    param(
        [Parameter(Mandatory=$false)][string]$Uri,
        [Parameter(Mandatory=$false)][hashtable]$Headers,
        [Parameter(Mandatory=$false)][int]$TimeoutSec = 20
    )
    $scenario = $env:MOCK_SCENARIO
    if ([string]::IsNullOrWhiteSpace($scenario)) { $scenario = 'normal' }

    switch ($scenario) {
        'normal' {
            return [PSCustomObject]@{
                tag_name     = 'v2.0.0'
                published_at = '2026-09-07T12:00:00Z'
            }
        }
        'versionJump' {
            return [PSCustomObject]@{
                tag_name     = 'v2.0.0'
                published_at = '2026-09-07T12:00:00Z'
            }
        }
        'metadata_incomplete' {
            return [PSCustomObject]@{
                tag_name = 'v1.0.0'
            }
        }
        'invalid_response' {
            return [PSCustomObject]@{
                tag_name = ''
            }
        }
        'not_found' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::NotFound) -HeaderHashtable @{}
            throw (New-Object MockHttpException -ArgumentList 'Mock not_found', $resp)
        }
        'auth_error' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::Unauthorized) -HeaderHashtable @{}
            throw (New-Object MockHttpException -ArgumentList 'Mock auth_error', $resp)
        }
        'rate_limited_429' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::TooManyRequests) -HeaderHashtable @{}
            throw (New-Object MockHttpException -ArgumentList 'Mock rate_limited_429', $resp)
        }
        'rate_limited_403' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::Forbidden) -HeaderHashtable @{ 'X-RateLimit-Remaining' = '0' }
            throw (New-Object MockHttpException -ArgumentList 'Mock rate_limited_403', $resp)
        }
        'forbidden_403' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::Forbidden) -HeaderHashtable @{ 'X-RateLimit-Remaining' = '50' }
            throw (New-Object MockHttpException -ArgumentList 'Mock forbidden_403', $resp)
        }
        'server_error' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::InternalServerError) -HeaderHashtable @{}
            throw (New-Object MockHttpException -ArgumentList 'Mock server_error', $resp)
        }
        'http_error' {
            $resp = New-MockResponsePS51 -Code ([System.Net.HttpStatusCode]::Found) -HeaderHashtable @{}
            throw (New-Object MockHttpException -ArgumentList 'Mock http_error', $resp)
        }
        'network_error' {
            throw (New-Object System.Exception('Mock network error'))
        }
        default {
            throw (New-Object System.Exception("Unknown MOCK_SCENARIO: $scenario"))
        }
    }
}
