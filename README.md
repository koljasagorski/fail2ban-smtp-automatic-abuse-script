# fail2ban-smtp-script
Install fail2ban and config smtp and setup a automatic email to the abuse team of the banned ip


curl -fsSL https://raw.githubusercontent.com/koljasagorski/fail2ban-smtp-automatic-abuse-script
/refs/heads/main/install_fail2ban_with_smtp.sh -o install_fail2ban_with_smtp.sh && chmod +x install_fail2ban_with_smtp.sh && sudo ./install_fail2ban_with_smtp.sh


Todo:
- Script anpassen (wirft Fehler aus)
- Abuse nur bei schwerwiegenden dingen
