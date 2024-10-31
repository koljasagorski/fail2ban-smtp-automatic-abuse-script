# fail2ban-smtp-script
Install fail2ban and config smtp and setup a automatic email to the abuse team of the banned ip


curl -fsSL https://raw.githubusercontent.com/koljasagorski/fail2ban-smtp-automatic-abuse-script
/refs/heads/main/install_fail2ban_with_smtp.sh -o install_fail2ban_with_smtp.sh && chmod +x install_fail2ban_with_smtp.sh && sudo ./install_fail2ban_with_smtp.sh


sudo chmod +x /etc/fail2ban/action.d/send_abuse_mail.sh

Füge in deiner Fail2Ban-Konfigurationsdatei (/etc/fail2ban/jail.local) die actionban-Zeile hinzu, um das Skript bei einem Ban aufzurufen:

[DEFAULT]
actionban = /etc/fail2ban/action.d/send_abuse_mail.sh <ip> <jail> <reason>

Starte Fail2Ban neu, damit die Konfiguration wirksam wird:
sudo systemctl restart fail2ban
