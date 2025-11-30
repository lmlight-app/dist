-- LM Light Launcher (Stay Open)

use AppleScript version "2.4"
use scripting additions

on run
    doToggle()
end run

on reopen
    doToggle()
end reopen

on idle
    return 300 -- check every 5 minutes
end idle

on doToggle()
    set installDir to (system attribute "HOME") & "/.local/lmlight"
    set pidFile to installDir & "/logs/api.pid"

    set isRunning to false
    try
        do shell script "test -f " & quoted form of pidFile & " && kill -0 $(cat " & quoted form of pidFile & ") 2>/dev/null"
        set isRunning to true
    end try

    if isRunning then
        display notification "Stopping..." with title "LM Light"
        try
            do shell script quoted form of (installDir & "/stop.sh")
        end try
        display notification "Stopped" with title "LM Light"
    else
        display notification "Starting..." with title "LM Light"
        try
            do shell script quoted form of (installDir & "/start.sh")
        end try
        delay 2
        display notification "Started: http://localhost:3000" with title "LM Light"
        do shell script "open http://localhost:3000"
    end if
end doToggle

on quit
    set installDir to (system attribute "HOME") & "/.local/lmlight"
    try
        do shell script quoted form of (installDir & "/stop.sh")
    end try
    continue quit
end quit
