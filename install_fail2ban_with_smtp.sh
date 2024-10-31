#!/bin/bash

# Script zur Installation und Konfiguration von Fail2ban und Postfix für SMTP-E-Mail-Benachrichtigungen

# Schritt 1: Update und automatische Vorkonfiguration von Postfix für den Nicht-Interaktiven Modus
echo "Aktualisiere Paketlisten und installiere Fail2ban und Postfix..."

# Vorkonfiguration für Postfix, um Eingabeaufforderungen zu vermeiden
echo "postfix postfix/mailname string ABSENDER-DOMAIN" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections

# Installation von Fail2ban, Postfix und mailutils
sudo apt update
sudo apt install -y fail2ban postfix mailutils

# Schritt 2: Postfix als SMTP-Client einrichten
echo "Konfiguriere Postfix für die Verwendung von SMTP..."
sudo bash -c 'cat > /etc/postfix/sasl_passwd << EOF
[SERVER]:587 USERNAME:PASSWORD
EOF'

# Setze Berechtigungen für die Passwortdatei
sudo chmod 600 /etc/postfix/sasl_passwd

# Konfiguration für die SMTP-Authentifizierung und TLS aktivieren
sudo postconf -e "relayhost = [SERVER]:587"
sudo postconf -e "smtp_sasl_auth_enable = yes"
sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
sudo postconf -e "smtp_sasl_security_options = noanonymous"
sudo postconf -e "smtp_use_tls = yes"
sudo postconf -e "smtp_tls_security_level = encrypt"
sudo postconf -e "smtp_tls_note_starttls_offer = yes"

# Passwort-Hash erstellen und Postfix neu laden
sudo postmap /etc/postfix/sasl_passwd
sudo systemctl restart postfix

# Schritt 3: Fail2ban konfigurieren, um Benachrichtigungen zu senden
echo "Konfiguriere Fail2ban mit E-Mail-Benachrichtigungen..."
sudo bash -c 'cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# E-Mail-Konfiguration
destemail = EMPFÄNGER
sender = ABSENDER
mta = mail

# Ban-Parameter
bantime  = 10m
findtime  = 10m
maxretry = 5
action = %(action_mwl)s

[sshd]
enabled = true
EOF'

# Schritt 4: Fail2ban-Dienst aktivieren und starten
echo "Aktiviere und starte Fail2ban-Dienst..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# Schritt 5: Fail2ban-Status prüfen
echo "Status von Fail2ban anzeigen:"
sudo fail2ban-client status
