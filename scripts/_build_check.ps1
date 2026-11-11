$env:DEVECO_SDK_HOME = "C:/sandbox/DevEco Studio/sdk"
$NODE = "C:/sandbox/nodejs/node.exe"
$HVIGOR = "C:/sandbox/DevEco Studio/tools/hvigor/bin/hvigorw.js"
$LOG = "scripts/_build_check.log"
& $NODE $HVIGOR --mode module -p product=default assembleHap *> $LOG
$rc = $LASTEXITCODE
# hvigor regenerates two BuildProfile.ets build artifacts on every run;
# restore them byte-exactly from HEAD so the working tree stays clean.
python -c "import subprocess; [open(p,'wb').write(subprocess.check_output(['git','show','HEAD:'+p])) for p in ['entry/oh_modules/@devzeng/quickjs/BuildProfile.ets','quickjs/BuildProfile.ets']]"
Write-Host "=== BUILD rc=$rc ==="
Select-String -Path $LOG -Pattern "BUILD (SUCCESSFUL|FAILED)|ArkTS:ERROR|error:|Finished :entry:default@CompileArkTS|ERROR:" | Select-Object -First 30 | ForEach-Object { $_.Line }
Write-Host "=== full log: $LOG ==="
exit $rc
