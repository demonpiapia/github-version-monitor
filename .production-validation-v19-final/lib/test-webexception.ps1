$ErrorActionPreference = 'Continue'
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"

# Test 1: WebException with 4 args
try {
    $resp = New-Object System.Net.Http.HttpResponseMessage
    $resp.StatusCode = [System.Net.HttpStatusCode]::NotFound
    $ex = New-Object System.Net.WebException('Mock not_found', $null, [System.Net.HttpStatusCode]::NotFound, $resp)
    throw $ex
} catch {
    Write-Host "Caught: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Has Response"
        Write-Host "StatusCode: $($_.Exception.Response.StatusCode)"
    } else {
        Write-Host "No Response"
    }
}

# Test 2: WebException with 3 args
Write-Host "---"
try {
    $resp = New-Object System.Net.Http.HttpResponseMessage
    $resp.StatusCode = [System.Net.HttpStatusCode]::NotFound
    $ex = New-Object System.Net.WebException('Mock not_found', $resp, [System.Net.HttpStatusCode]::NotFound)
    throw $ex
} catch {
    Write-Host "Caught: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Has Response"
        Write-Host "StatusCode: $($_.Exception.Response.StatusCode)"
    } else {
        Write-Host "No Response"
    }
}

# Test 3: 403 with headers
Write-Host "---"
try {
    $headers = New-Object System.Net.WebHeaderCollection
    $headers.Add('X-RateLimit-Remaining', '0')
    $resp = New-Object System.Net.Http.HttpResponseMessage
    $resp.StatusCode = [System.Net.HttpStatusCode]::Forbidden
    foreach ($pair in $headers.GetEnumerator()) {
        $resp.Headers.TryAddWithoutValidation($pair.Key, $pair.Value) | Out-Null
    }
    $ex = New-Object System.Net.WebException('Mock 403', $resp, [System.Net.HttpStatusCode]::Forbidden)
    throw $ex
} catch {
    Write-Host "Caught: $($_.Exception.GetType().FullName)"
    if ($_.Exception.Response) {
        Write-Host "StatusCode: $($_.Exception.Response.StatusCode)"
        Write-Host "Headers type: $($_.Exception.Response.Headers.GetType().FullName)"
        $rl = $_.Exception.Response.Headers['X-RateLimit-Remaining']
        Write-Host "X-RateLimit-Remaining: '$rl' (type=$($rl.GetType().Name))"
    }
}
