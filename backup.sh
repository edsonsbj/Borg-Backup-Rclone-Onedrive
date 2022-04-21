#!usr/bin/bash

#Vars

DIRGPG="/root/.gnupg"		# Diretório onde é armazenada chaves e senhas.
PASSFILE="/root/.config/backup/senha.txt"			# Arquivo de Senha para Criptografar e descriptografar arquivos com GPG.
RCLONECONFIG_CRIPT="/home/usr/.config/rclone/rclone.conf.gpg"	# Arquivo criptografado rclone.conf.gpg
RCLONECONFIG="/home/usr/.config/rclone/rclone.conf"		# Arquivo descriptografado 
LOGFILE_PATH="/var/log/Borg/backup-$(date +%Y-%m-%d_%H-%M).txt"		# Arquivo de Log
BACKUPDIR="/home/"

# Configurando isso, para que o repositório não precise ser fornecido na linha de comando:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg"

# Configurando isso, para que a senha não seja fornecido na linha de comando 
export BORG_PASSPHRASE='Senhasegura'

#gpg Descript
/usr/bin/gpg --batch --no-tty --homedir '$DIRGPG' --passphrase-file '$PASSFILE' '$RCLONECONFIG_CRIPT' $LOGFILE_PATH

sudo systemctl start Backup.service

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Backup Iniciado" 2>&1 | tee -a $LOGFILE_PATH

# Faça backup dos diretórios mais importantes em um arquivo com o nome
# a máquina em que este script está sendo executado

#echo "$(date "+%m-%d-%Y %T") : Borg backup has started" 2>&1 | tee -a $LOGFILE_PATH
borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --progress                      \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --exclude-from '/patch/dir/excludes.txt'  \
                                    \
    ::'{hostname}-{now}'            \
    '$BACKUPDIR'             \
    >> $LOGFILE_PATH 2>&1


backup_exit=$?

info "Pruning repository"

# Use o subcomando `prune` para manter 7 diárias, 4 semanais e 6 mensais
# arquivos desta máquina. O prefixo '{hostname}-' é muito importante para
# limita a operação do prune aos arquivos desta máquina e não se aplica a
# arquivos de outras máquinas também:	

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \
    >> $LOGFILE_PATH 2>&1

prune_exit=$?

# usa o código de saída mais alto como código de saída global
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a $LOGFILE_PATH
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a $LOGFILE_PATH
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a $LOGFILE_PATH
fi

exit ${global_exit}

# Backup Concluido 

sudo systemctl stop Backup.service

rm -rf '$RCLONECONFIG' 

echo
echo "DONE!"
echo "Backup Concluido." $LOGFILE_PATH
