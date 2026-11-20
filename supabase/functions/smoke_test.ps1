$key = "sb_publishable_kMbiVj_on1b8XUdkTKvHmw_urG_F5sz"
$base = "https://zrkkbknndavvprejskjy.supabase.co/functions/v1"
$headers = @{ "apikey" = $key; "Authorization" = "Bearer $key"; "Content-Type" = "application/json" }
$failed = 0

foreach ($check in @(
  @{ Name="verify-otp-sms"; Body='{"phone_number":"+639000000000","code":"000000"}'; Expect=@(400) },
  @{ Name="send-sms-notice"; Body='{}'; Expect=@(401,403) },
  @{ Name="sms-gate-status"; Body='{}'; Expect=@(401,403) },
  @{ Name="purge-expired-biometrics"; Body='{}'; Expect=@(200) }
)) {
  $code = 0
  try {
    $r = Invoke-WebRequest -Uri "$base/$($check.Name)" -Method Post -Headers $headers -Body $check.Body -TimeoutSec 8
    $code = [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
  }
  $ok = $check.Expect -contains $code
  if (-not $ok) { $failed++ }
  Write-Host ("{0,-28} HTTP {1} ({2})" -f $check.Name, $code, $(if ($ok) { "PASS" } else { "FAIL" }))
}
exit $failed
