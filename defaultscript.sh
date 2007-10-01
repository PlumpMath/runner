#!/bin/sh

cat <<EOF
You did not specify command-line arguments; otherwise, the output of your command would start appearing here.  Rather than double-clicking on Runner.app, you should run the executable "Runner.app/Contents/MacOS/Runner" from the command-line and pass it your command, like this:

  /Applications/Runner.app/Contents/MacOS/Runner echo hello world

Runner will run your command and then disappear because the command succeeded. Go ahead and change the preferences now to pick the behaviors you like most. This window will otherwise disappear in 2 minutes.
EOF

sleep 120
