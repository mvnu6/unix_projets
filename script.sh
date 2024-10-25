#!/bin/bash

# Fichier où les utilisateurs sont stockés
user_file="utilisateur.txt"

# Vérifiez si le fichier utilisateur existe, sinon créez-le
if [ ! -f "$user_file" ]; then
    touch "$user_file"
    echo "Le fichier $user_file a été créé."
fi

# Fonction pour vérifier si l'utilisateur existe déjà dans le fichier
utilisateur_existe() {
    local nom=$1
    grep -q "^$nom:" "$user_file"
}

# Fonction pour obtenir le mot de passe enregistré d'un utilisateur
get_mot_de_passe() {
    local nom=$1
    grep "^$nom:" "$user_file" | cut -d ":" -f 5
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

# Demander les informations de l'utilisateur
read -p "Entrez le nom de l'utilisateur : " nom

# Vérifiez si l'utilisateur existe déjà dans le fichier
if utilisateur_existe "$nom"; then
    echo "L'utilisateur $nom existe déjà dans le fichier $user_file."

    # Demander le mot de passe de l'utilisateur pour modification
    read -sp "Entrez le mot de passe pour cet utilisateur : " mot_de_passe_entree
    echo ""

    # Obtenir le mot de passe enregistré pour cet utilisateur
    mot_de_passe_enregistre=$(get_mot_de_passe "$nom")

    # Vérifier si le mot de passe est correct
    if [[ "$mot_de_passe_entree" == "$mot_de_passe_enregistre" ]]; then
        echo "Mot de passe correct. Vous pouvez modifier les informations."

        # Demander les nouvelles informations de l'utilisateur
        # read -p Entrez le nouveau groupe de l'utilisateur : " groupe
         read -p "Entrez le nouveau shell de l'utilisateur (ex: /bin/bash) : " shell
         read -p "Entrez le nouveau répertoire personnel de lutilisateur (ex: /home/$nom) : " repertoire

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
        echo "Mot de passe incorrect. Modification annulée."
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
# Définir le seuil d'inactivité (en jours)
INACTIVE_DAYS=1

# Obtenir la liste des utilisateurs inactifs depuis 90 jours ou plus
inactive_users=$(lastlog -b $INACTIVE_DAYS | awk 'NR>1 {if ($4 != "**Never logged in**" && $0 ~ /^[a-zA-Z0-9]/) print $1}')

# Vérifier si des utilisateurs inactifs ont été trouvés
if [ -z "$inactive_users" ]; then
    echo "Aucun utilisateur inactif trouvé."
    exit 0
fi

# Alerte : utilisateurs inactifs trouvés
echo "Attention : Les utilisateurs suivants sont inactifs depuis plus de $INACTIVE_DAYS jours :"
echo "$inactive_users"
echo

# Demander à l'administrateur de choisir quel utilisateur gérer
read -p "Entrez le nom de l'utilisateur que vous souhaitez gérer (ou 'tous' pour tous les gérer) : " selected_user

# Si l'utilisateur choisit 'tous', on gère tous les utilisateurs inactifs
if [ "$selected_user" == "tous" ]; then
    selected_users=$inactive_users
else
    selected_users=$selected_user
fi

# Proposer des actions pour chaque utilisateur sélectionné
for user in $selected_users; do
    # Vérifier si l'utilisateur est bien dans la liste des inactifs
    if echo "$inactive_users" | grep -q "^$user$"; then
        echo "Utilisateur sélectionné : $user"

        # Demander l'action à effectuer (verrouiller ou supprimer)
        read -p "Voulez-vous (L) verrouiller ou (S) supprimer le compte de $user ? (L/S/N pour ignorer) : " action

        case "$action" in
            L|l)
                echo "Verrouillage du compte $user..."
                sudo passwd -l "$user"
                ;;
            S|s)
                # Demander confirmation avant suppression
                read -p "Êtes-vous sûr de vouloir supprimer l'utilisateur $user ? (O/N) : " confirm
                if [[ "$confirm" == "O" || "$confirm" == "o" ]]; then
                # Sauvegarder le répertoire personnel de l'utilisateur avant suppression
                    home_dir=$(getent passwd "$user" | cut -d: -f6)
                    backup_dir="/backup/${user}_home_backup.tar.gz"
                    echo "Sauvegarde du répertoire personnel de $user dans $backup_dir..."
                    sudo tar -czf "$backup_dir" "$home_dir"
                # suppression de l'utilisateur et de son repertoire
                    echo "Suppression du compte $user..."
                    sudo userdel -r "$user"
                else
                    echo "Suppression annulée pour $user."
                fi
                ;;
            N|n)
                echo "Aucune action prise pour $user."
                ;;
            *)
                echo "Option invalide. Aucune action prise pour $user."
                ;;
        esac
        echo
    else
        echo "L'utilisateur $user n'est pas dans la liste des inactifs."
    fi
done





# Fonction pour créer des groupes
create_group() {
    read -p "Nom du nouveau groupe : " group_name
    if getent group "$group_name" > /dev/null; then
        echo "Le groupe '$group_name' existe déjà."
    else
        sudo groupadd "$group_name"
        if [ $? -eq 0 ]; then
            echo "Le groupe '$group_name' a été créé avec succès."
        else
            echo "Échec de la création du groupe '$group_name'."
        fi
    fi
}

# Fonction pour ajouter un utilisateur à un groupe
add_user_to_group() {
    read -p "Nom de l'utilisateur : " user_name
    read -p "Nom du groupe : " group_name
    
    if id "$user_name" &>/dev/null; then
        if getent group "$group_name" > /dev/null; then
            sudo usermod -aG "$group_name" "$user_name"
            if [ $? -eq 0 ]; then
                echo "$user_name a été ajouté au groupe '$group_name'."
            else
                echo "Échec de l'ajout de $user_name au groupe '$group_name'."
            fi
        else
            echo "Le groupe '$group_name' n'existe pas."
        fi
    else
        echo "L'utilisateur '$user_name' n'existe pas."
    fi
}

# Fonction pour retirer un utilisateur d'un groupe
remove_user_from_group() {
    read -p "Nom de l'utilisateur : " user_name
    read -p "Nom du groupe : " group_name
    
    if id "$user_name" &>/dev/null; then
        if getent group "$group_name" > /dev/null; then
            sudo gpasswd -d "$user_name" "$group_name"
            if [ $? -eq 0 ]; then
                echo "$user_name a été retiré du groupe '$group_name'."
            else
                echo "Échec du retrait de $user_name du groupe '$group_name'."
            fi
        else
            echo "Le groupe '$group_name' n'existe pas."
        fi
    else
        echo "L'utilisateur '$user_name' n'existe pas."
    fi
}

# Fonction pour supprimer un groupe si vide
delete_empty_group() {
    read -p "Nom du groupe à supprimer : " group_name
    if getent group "$group_name" > /dev/null; then
        members=$(getent group "$group_name" | cut -d: -f4)
        if [ -z "$members" ]; then
            sudo groupdel "$group_name"
            if [ $? -eq 0 ]; then
                echo "Le groupe '$group_name' a été supprimé avec succès."
            else
                echo "Échec de la suppression du groupe '$group_name'."
            fi
        else
            echo "Le groupe '$group_name' n'est pas vide. Utilisateurs présents : $members"
        fi
    else
        echo "Le groupe '$group_name' n'existe pas."
    fi
}

# Fonction pour configurer les permissions via ACL
configure_acl() {
    read -p "Nom du répertoire à configurer : " directory
    if [ -d "$directory" ]; then
        read -p "Nom du groupe à configurer : " group_name
        if getent group "$group_name" > /dev/null; then
            echo "Choisissez les permissions à attribuer (ex: r pour lecture, rw pour lecture/écriture, etc.) :"
            read -p "Permissions pour le groupe $group_name : " permissions

            # Appliquer les permissions sur le répertoire
            sudo setfacl -m g:"$group_name":"$permissions" "$directory"
            # Appliquer les permissions par défaut pour les fichiers futurs
            sudo setfacl -d -m g:"$group_name":"$permissions" "$directory"
            
            echo "Les permissions '$permissions' ont été appliquées au groupe '$group_name' pour le répertoire '$directory'."
        else
            echo "Le groupe '$group_name' n'existe pas."
        fi
    else
        echo "Le répertoire '$directory' n'existe pas."
    fi
}

# Menu d'options pour gérer les groupes, utilisateurs et ACL
while true; do
    echo ""
    echo "Choisissez une action :"
    echo "1. Créer un groupe"
    echo "2. Ajouter un utilisateur à un groupe"
    echo "3. Retirer un utilisateur d'un groupe"
    echo "4. Supprimer un groupe vide"
    echo "5. Configurer des permissions ACL"
    echo "6. Quitter"

    read -p "Action choisie (1/2/3/4/5/6) : " action

    case $action in
        1) create_group ;;
        2) add_user_to_group ;;
        3) remove_user_from_group ;;
        4) delete_empty_group ;;
        5) configure_acl ;;
        6) echo "Sortie du script."; exit 0 ;;
        *) echo "Option invalide. Veuillez choisir 1, 2, 3, 4, 5 ou 6." ;;
    esac
done

