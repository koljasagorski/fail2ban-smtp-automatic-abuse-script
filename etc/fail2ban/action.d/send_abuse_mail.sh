#!/bin/bash

# Variablen für die Ban-Daten und E-Mail-Konfiguration
IP="$1"                 # Gebannte IP-Adresse
JAIL="$2"               # Name des Jails (z.B. sshd)
REASON="$3"             # Grund des Bans
CC_EMAIL="fail2banabuse@sagorski.org"  # E-Mail-Adresse für CC

# Ermittelt die Abuse-Adresse für die gebannte IP
ABUSE_EMAIL=$(whois "$IP" | grep -i "abuse" | grep -Eo "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}" | head -n 1)

# Ban-Verlauf von Fail2Ban für die gebannte IP-Adresse abrufen
BAN_LOG=$(sudo fail2ban-client status "$JAIL" | grep "$IP")

# Nachrichtentext und Betreff für die E-Mail
SUBJECT="ABUSE Notification: IP $IP banned for malicious activity"
BODY="Dear Abuse Team,

This is an automated notification that the IP address $IP has been banned on our server due to suspicious activity detected by Fail2Ban.

**Ban Details:**
- Service: $JAIL
- Reason: $REASON

**Ban History and Logs:**
The following details are recorded regarding the ban:
$BAN_LOG

**Incident Summary:**
The IP address $IP has been identified as engaging in potentially harmful activity that triggered our security mechanisms. As a result, it has been temporarily banned to prevent further unauthorized access attempts.

If this ban was issued in error or if you require more information, please contact us at your earliest convenience.

Sincerely,
System Administrator"

# Überprüfen, ob eine Abuse-E-Mail-Adresse vorhanden ist
if [ -n "$ABUSE_EMAIL" ]; then
    # E-Mail mit `sendmail` senden und CC hinzufügen
    {
        echo "To: $ABUSE_EMAIL"
        echo "Cc: $CC_EMAIL"
        echo "Subject: $SUBJECT"
        echo
        echo "$BODY"
    } | sendmail -t
else
    echo "No Abuse contact found for IP $IP."
fi
