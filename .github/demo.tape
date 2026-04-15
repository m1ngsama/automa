# VHS demo tape for automa
# Run: vhs .github/demo.tape

Output .github/demo.gif

Set Shell bash
Set FontSize 15
Set Width 900
Set Height 500
Set Padding 20
Set Theme { "name": "automa", "black": "#0f172a", "red": "#ef4444", "green": "#22c55e", "yellow": "#eab308", "blue": "#3b82f6", "magenta": "#a855f7", "cyan": "#06b6d4", "white": "#f8fafc", "brightBlack": "#64748b", "brightRed": "#f87171", "brightGreen": "#4ade80", "brightYellow": "#facc15", "brightBlue": "#60a5fa", "brightMagenta": "#c084fc", "brightCyan": "#22d3ee", "brightWhite": "#ffffff", "background": "#0f172a", "foreground": "#f8fafc", "selection": "#334155", "cursor": "#38bdf8" }

Sleep 500ms

Type "./automa help"
Enter
Sleep 3s

Type "./automa list"
Enter
Sleep 3s

Type "./automa -y deploy uptime-kuma"
Enter
Sleep 6s

Type "./automa status"
Enter
Sleep 3s

Sleep 1s
