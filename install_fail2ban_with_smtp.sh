#!/bin/bash

# SMTP-Serverkonfiguration
SERVER=""
USERNAME=""
PASSWORD=""
ABSENDER=""
EMPFAENGER=""

# Entfernen alter Installationen
echo "Entferne alte Versionen von Fail2ban, Postfix und Mailutils..."
sudo systemctl stop fail2ban
sudo apt remove --purge -y fail2ban postfix mailutils whois

# Installation von benötigten Paketen
echo "Aktualisiere Paketlisten und installiere Fail2ban, Postfix, Mailutils und Whois..."
sudo apt update
echo "postfix postfix/mailname string $ABSENDER" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections
sudo apt install -y fail2ban postfix mailutils whois

# Postfix für SMTP konfigurieren
echo "Konfiguriere Postfix für SMTP..."
sudo bash -c "cat > /etc/postfix/sasl_passwd << EOF
[$SERVER]:587 $USERNAME:$PASSWORD
EOF"

# Berechtigungen setzen und Postfix-Konfiguration anwenden
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postconf -e "relayhost = [$SERVER]:587"
sudo postconf -e "smtp_sasl_auth_enable = yes"
sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
sudo postconf -e "smtp_sasl_security_options = noanonymous"
sudo postconf -e "smtp_use_tls = yes"
sudo postconf -e "smtp_tls_security_level = encrypt"
sudo postconf -e "smtp_tls_note_starttls_offer = yes"
sudo postmap /etc/postfix/sasl_passwd
sudo systemctl restart postfix

# Abuse-Benachrichtigungs-Skript erstellen
echo "Erstelle Abuse-Benachrichtigungs-Skript..."
sudo bash -c "cat > /etc/fail2ban/action.d/send_abuse_mail.sh << 'EOF'
#!/bin/bash

IP="\$1"
JAIL="\$2"
REASON="\$3"
CC_EMAIL="$EMPFAENGER"

# Ermittelt die Abuse-Adresse der gebannten IP
ABUSE_EMAIL=\$(whois "\$IP" | grep -i abuse | grep -Eo '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}' | head -n 1)
if [ -z "\$ABUSE_EMAIL" ]; then
    ABUSE_EMAIL=\$(whois "\$IP" | grep -i 'e-mail' | grep -Eo '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}' | head -n 1)
fi

# Ban-Verlauf von Fail2Ban abrufen
BAN_LOG=\$(sudo fail2ban-client status "\$JAIL" | grep "\$IP")

# Nachrichtentext und Betreff der E-Mail
SUBJECT="ABUSE Notification: IP \$IP banned for malicious activity"
BODY="Dear Abuse Team,

This is an automated notification that the IP address \$IP has been banned on our server due to suspicious activity detected by Fail2Ban.

**Ban Details:**
- Service: \$JAIL
- Reason: \$REASON

**Ban History and Logs:**
The following details are recorded regarding the ban:
\$BAN_LOG

**Incident Summary:**
The IP address \$IP has been identified as engaging in potentially harmful activity that triggered our security mechanisms. As a result, it has been temporarily banned to prevent further unauthorized access attempts.

If this ban was issued in error or if you require more information, please contact us at your earliest convenience.

Sincerely,
System Administrator"

# E-Mail senden
if [ -n "\$ABUSE_EMAIL" ]; then
    {
        echo "To: \$ABUSE_EMAIL"
        echo "Cc: \$CC_EMAIL"
        echo "Subject: \$SUBJECT"
        echo
        echo "\$BODY"
    } | sendmail -t
else
    echo "Keine Abuse-E-Mail-Adresse für \$IP gefunden."
fi
EOF"

# Skript ausführbar machen
sudo chmod +x /etc/fail2ban/action.d/send_abuse_mail.sh

# Fail2ban-Konfiguration mit allen verfügbaren Jails
echo "Konfiguriere Fail2ban mit allen verfügbaren Jails..."
sudo bash -c "cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
destemail = $EMPFAENGER
sender = $ABSENDER
mta = mail
bantime  = 10m
findtime  = 10m
maxretry = 5
action = %(action_mwl)s
actionban = /etc/fail2ban/action.d/send_abuse_mail.sh <ip> <jail> <reason>

[sshd]
enabled = true

[sshd-ddos]
enabled = true

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache*/*error.log

[apache-badbots]
enabled = true
port = http,https
logpath = /var/log/apache*/*error.log

[apache-noscript]
enabled = true
port = http,https
logpath = /var/log/apache*/*error.log

[apache-overflows]
enabled = true
port = http,https
logpath = /var/log/apache*/*error.log

[postfix-sasl]
enabled = true
port = smtp,ssmtp
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps
logpath = /var/log/mail.log

[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
logpath = /var/log/vsftpd.log

[proftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
logpath = /var/log/proftpd/proftpd.log

[pure-ftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
logpath = /var/log/syslog

[exim]
enabled = true
port = smtp,ssmtp
logpath = /var/log/exim4/mainlog

[squirrelmail]
enabled = true
port = http,https
logpath = /var/log/squirrelmail/errors

EOF"

# Sicherstellen, dass das Verzeichnis und Berechtigungen korrekt sind
echo "Stelle sicher, dass das Verzeichnis und Berechtigungen für Fail2ban korrekt sind..."
sudo mkdir -p /var/run/fail2ban
sudo chown -R root:root /etc/fail2ban
sudo chmod -R 644 /etc/fail2ban

# Fail2ban-Dienst aktivieren und starten
echo "Aktiviere und starte Fail2ban-Dienst..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# Fail2ban-Status überprüfen
echo "Status von Fail2ban anzeigen:"
sudo fail2ban-client status

echo "Installation und Konfiguration abgeschlossen."
