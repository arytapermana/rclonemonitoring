# rclone Monitoring
a simple powershell app to check reclone background process using link to catch data

# Step
mount clone
`rclone mount backblaze:/bucket Y: --rc --rc-addr localhost:5575 --vfs-cache-mode full --vfs-cache-max-size 100G --vfs-cache-max-age 720h --links --no-console --log-file c:\rclone\logs\sync_files_backblaze.txt --volname backblaze --b2-hard-delete --cache-dir "d:\Program Files\rcloneCache"`

set remote on .ps1
`$remotes = @(
    @{ Name = "backblaze"; Port = 5575 },
    @{ Name = "otherbackblaze1"; Port = 5576 },
    @{ Name = "otherbackblaze2"; Port = 5577 }
)`

compile the .ps1 using [PS2EXE] (https://github.com/MScholtes/PS2EXEmak)
