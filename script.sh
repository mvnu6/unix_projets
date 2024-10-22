#!/bin/bash

# Fichier où les utilisateurs sont stockés
user_file="utilisateurs.txt"

# Vérifiez si le fichier utilisateur existe, sinon créez-le
if [ ! -f "$user_file" ]; then
    touch "$user_file"
    echo "Le fichier $user_file a été créé."
fi

# Dossier pour les sauvegardes
BACKUP_DIR="/home/mvnu/backup"  # Modifiez ce chemin selon votre configuration

# Vérifier si le répertoire de sauvegarde existe, sinon le créer
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR" || { echo "Erreur : impossible de créer le répertoire $BACKUP_DIR."; exit 1; }
    echo "Le répertoire de sauvegarde a été créé : $BACKUP_DIR"
fi

# Fonction pour vérifier si l'utilisateur existe déjà dans le fichier
utilisateur_existe() {
    local nom=$1
    grep -q "^$nom:" "$user_file"
}

# Fonction pour obtenir les informations d'un utilisateur
get_utilisateur_info() {
    local nom=$1
    grep "^$nom:" "$user_file"
}

# Fonction pour modifier un utilisateur existant dans le fichier
modifier_utilisateur() {
    local nom=$1
    local groupe=$2
    local shell=$3
    local repertoire=$4
    local mot_de_passe=$5

    # Supprimer la ligne existante pour cet utilisateur
    sed -i "/^$nom:/d" "$user_file"
    
    # Ajouter la nouvelle ligne avec les informations mises à jour
    echo "$nom:$groupe:$shell:$repertoire:$mot_de_passe" >> "$user_file"
}

# Fonction pour générer un mot de passe aléatoire de 12 caractères
generer_mot_de_passe() {
    < /dev/urandom tr -dc 'A-Za-z0-9&!*@' | head -c 12
}

# Fonction pour configurer les permissions ACL
configurer_acl() {
    local repertoire=$1
    local groupe_rh="RH"
    local groupe_dir="direction"

    # Vérifier si le répertoire existe
    if [ ! -d "$repertoire" ]; then
        echo "Le répertoire $repertoire n'existe pas."
        return
    fi

    # Configurer les permissions pour le groupe RH
    setfacl -m g:$groupe_rh:r "$repertoire"  # Lecture pour le groupe RH
    setfacl -d -m g:$groupe_rh:r "$repertoire"  # ACL par défaut pour le groupe RH

    # Configurer les permissions pour le groupe direction
    setfacl -m g:$groupe_dir:rw "$repertoire"  # Lecture et écriture pour le groupe direction
    setfacl -d -m g:$groupe_dir:rw "$repertoire"  # ACL par défaut pour le groupe direction

    echo "Permissions ACL configurées pour le répertoire $repertoire."
}

# Demander les informations de l'utilisateur
read -p "Entrez le nom de l'utilisateur : " nom

# Vérifiez si l'utilisateur existe déjà dans le fichier
if utilisateur_existe "$nom"; then
    echo "L'utilisateur $nom existe déjà dans le fichier $user_file."

    # Obtenir les informations de l'utilisateur
    utilisateur_info=$(get_utilisateur_info "$nom")
    IFS=":" read -r nom groupe shell repertoire mot_de_passe_enregistre <<< "$utilisateur_info"

    # Demander le mot de passe de l'utilisateur pour modification
    read -sp "Entrez le mot de passe pour cet utilisateur : " mot_de_passe_entree
    echo ""

    # Vérifier si le mot de passe est correct
    if [[ "$mot_de_passe_entree" == "$mot_de_passe_enregistre" ]]; then
        echo "Mot de passe correct. Vous pouvez modifier les informations."

        # Demander les nouvelles informations de l'utilisateur
        read -p "Entrez le nouveau groupe de l'utilisateur : " groupe
        read -p "Entrez le nouveau shell de l'utilisateur (ex: /bin/bash) : " shell
        read -p "Entrez le nouveau répertoire personnel de l'utilisateur (ex: /home/$nom) : " repertoire

        # Demander si l'utilisateur souhaite changer son mot de passe
        read -p "Voulez-vous changer le mot de passe ? (oui/non) : " changer_mot_de_passe
        if [[ "$changer_mot_de_passe" == "oui" ]]; then
            read -sp "Entrez le nouveau mot de passe : " nouveau_mot_de_passe
            echo ""
        else
            nouveau_mot_de_passe="$mot_de_passe_enregistre"
        fi

        # Modifier l'utilisateur dans le fichier
        modifier_utilisateur "$nom" "$groupe" "$shell" "$repertoire" "$nouveau_mot_de_passe"
        echo "Les informations de l'utilisateur $nom ont été modifiées."
    else
        echo "Mot de passe incorrect."

        # Demander si l'utilisateur souhaite changer son mot de passe
        read -p "Voulez-vous changer le mot de passe ? (oui/non) : " changer_mot_de_passe
        if [[ "$changer_mot_de_passe" == "oui" ]]; then
            read -sp "Entrez le nouveau mot de passe : " nouveau_mot_de_passe
            echo ""
            # Modifier l'utilisateur dans le fichier avec le nouveau mot de passe
            modifier_utilisateur "$nom" "$groupe" "$shell" "$repertoire" "$nouveau_mot_de_passe"
            echo "Le mot de passe de l'utilisateur $nom a été changé."
        else
            echo "Aucune modification n'a été apportée."
        fi
    fi
else
    # Si l'utilisateur n'existe pas, demander les informations et ajouter l'utilisateur
    read -p "Entrez le groupe de l'utilisateur : " groupe
    read -p "Entrez le shell de l'utilisateur (ex: /bin/bash) : " shell
    read -p "Entrez le répertoire personnel de l'utilisateur (ex: /home/$nom) : " repertoire

    # Générer un mot de passe aléatoire pour le nouvel utilisateur
    mot_de_passe=$(generer_mot_de_passe)

    # Ajouter les informations de l'utilisateur dans le fichier avec le mot de passe
    echo "$nom:$groupe:$shell:$repertoire:$mot_de_passe" >> "$user_file"
    echo "L'utilisateur $nom a été ajouté dans le fichier $user_file avec le mot de passe : $mot_de_passe."

    # Demander si l'utilisateur souhaite changer le mot de passe
    read -p "Voulez-vous changer le mot de passe ? (oui/non) : " changer_mot_de_passe
    if [[ "$changer_mot_de_passe" == "oui" ]]; then
        read -sp "Entrez le nouveau mot de passe : " nouveau_mot_de_passe
        echo ""
        # Mettre à jour le fichier avec le nouveau mot de passe
        sed -i "\$s/$mot_de_passe/$nouveau_mot_de_passe/" "$user_file"
        echo "Le mot de passe de l'utilisateur $nom a été changé."
    fi
fi

# Configurer les permissions ACL sur le répertoire spécifié
configurer_acl "$repertoire"



