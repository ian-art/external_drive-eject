' EjectDrive.vbs  –  launcher with elevation
If WScript.Arguments.Count = 0 Then
    WScript.Echo "No drive specified."
    WScript.Quit 1
End If

drive = Replace(WScript.Arguments(0), """", "")   ' strip quotes if any
Set shell = CreateObject("Shell.Application")

' hand drive letter to batch **as parameter**
shell.ShellExecute "cmd.exe", "/c """ & _
    "%SystemRoot%\System32\EjectDrive.bat"" " & drive, "", "runas", 0