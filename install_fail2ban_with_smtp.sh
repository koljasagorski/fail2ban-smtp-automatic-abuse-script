#!/bin/bash

# Script zur Deinstallation, Installation und Konfiguration von Fail2ban und Postfix für SMTP-E-Mail-Benachrichtigungen
# Sendet bei jedem Ban eine E-Mail an die eigene Adresse und die "Abuse"-Adresse der gebannten IP

# Variablen für Konfiguration
SERVER=""
USERNAME=""
PASSWORD=""
ABSENDER=""
EMPFAENGER=""

# Schritt 1: Alte Fail2Ban-Version deinstallieren
echo "Entferne alte Fail2ban-Version, falls vorhanden..."
sudo systemctl stop fail2ban
sudo apt remove --purge -y fail2ban

# Schritt 2: Installation von Fail2ban, Postfix und Mailutils
echo "Aktualisiere Paketlisten und installiere Fail2ban, Postfix und mailutils..."
sudo apt update
echo "postfix postfix/mailname string $ABSENDER" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections
sudo apt install -y fail2ban postfix mailutils whois

# Schritt 3: Postfix als SMTP-Client konfigurieren
echo "Konfiguriere Postfix für die Verwendung von SMTP..."
sudo bash -c "cat > /etc/postfix/sasl_passwd << EOF
[$SERVER]:587 $USERNAME:$PASSWORD
EOF"

# Setze Berechtigungen für die Passwortdatei und konfiguriere Postfix
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

# Schritt 4: Skript zur automatischen Abuse-Benachrichtigung erstellen
echo "Erstelle Skript zur automatischen Benachrichtigung der Abuse-Abteilung..."
sudo bash -c "cat > /etc/fail2ban/action.d/send_abuse_mail.sh << 'EOF'
#!/bin/bash

IP="\$1"
JAIL="\$2"
REASON="\$3"
EMAIL="$EMPFÄNGER"

# Ermittelt die Abuse-Adresse
ABUSE_EMAIL=\$(whois "\$IP" | grep -i "abuse" | grep -Eo "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}" | head -n 1)

# Nachrichtentext und Betreff
SUBJECT="Fail2Ban Alert: IP \$IP gebannt für \$JAIL"
BODY="IP: \$IP wurde für den Dienst \$JAIL gesperrt. Grund: \$REASON. Bitte kontaktieren Sie uns, falls dies ein Fehler ist."

# Sende E-Mail an dich und, falls vorhanden, an die Abuse-Adresse
echo -e "\$BODY" | mail -s "\$SUBJECT" "\$EMAIL"

if [ -n "\$ABUSE_EMAIL" ]; then
    echo -e "\$BODY" | mail -s "\$SUBJECT" "\$ABUSE_EMAIL"
else
    echo "Keine Abuse-E-Mail für \$IP gefunden."
fi
EOF"

# Skript ausführbar machen
sudo chmod +x /etc/fail2ban/action.d/send_abuse_mail.sh

# Schritt 5: Fail2ban konfigurieren, um Benachrichtigungen zu senden
echo "Konfiguriere Fail2ban mit E-Mail-Benachrichtigungen..."
sudo bash -c "cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# E-Mail-Konfiguration
destemail = $EMPFÄNGER
sender = $ABSENDER
mta = mail

# Ban-Parameter
bantime  = 10m
findtime  = 10m
maxretry = 5
action = %(action_mwl)s
# Spezielles Action-Skript für Abuse-Benachrichtigungen
actionban = /etc/fail2ban/action.d/send_abuse_mail.sh <ip> <jail> <reason>

[sshd]
enabled = true
EOF"

# Schritt 6: Fail2ban-Dienst aktivieren und starten
echo "Aktiviere und starte Fail2ban-Dienst..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# Schritt 7: Fail2ban-Status prüfen
echo "Status von Fail2ban anzeigen:"
sudo fail2ban-client status

echo "Installation und Konfiguration abgeschlossen."
