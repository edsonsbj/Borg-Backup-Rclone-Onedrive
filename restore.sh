#!usr/bin/bash

#Vars

DIRGPG="/root/.gnupg"		# Diretório onde é armazenada chaves e senhas.
PASSFILE="/root/.config/backup/senha.txt"			# Arquivo de Senha para Criptografar e descriptografar arquivos com GPG.
RCLONECONFIG_CRIPT="/home/usr/.config/rclone/rclone.conf.gpg"	# Arquivo criptografado rclone.conf.gpg
RCLONECONFIG="/home/usr/.config/rclone/rclone.conf"		# Arquivo descriptografado 
LOGFILE_PATH="/var/log/Borg/backup-$(date +%Y-%m-%d_%H-%M).txt"		# Arquivo de Log
RESTOREDIR=/home/

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg"

# See the section "Passphrase notes" for more infos.
export BORG_PASSPHRASE='Senhasegura'

#gpg Descript

/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file '$PASSFILE' '$RCLONECONFIG_CRIPT' 

# Função para mensagens de erro
errorecho() { cat <<< "$@" 1>&2; } $LOGFILE_PATH

#
# Verifica se o Script é executado pelo root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERROR: This script has to be run as root!"
        exit 1
fi

# Montar Remoto Rclone

sudo systemctl start Backup.service

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# Restaura os Arquivos 
# 
echo "Restoring Borg Archive"
cd /
borg extract -v --list "$BORG_REPO::$(hostname)-2022-05-16T21:40:05" '$RESTOREDIR' $LOGFILE_PATH

# Backup Terminado 

sudo systemctl stop Backup.service

rm -rf '$RCLONECONFIG'

echo
echo "DONE!"
echo "Successfully restored."

