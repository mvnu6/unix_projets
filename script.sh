#!/bin/bash
#
   user_file="utilisateurs.txt"

   generer_mot_de_passe() {
    < /dev/urandom tr -dc 'A-Za-z0-9&!*@' | head -c 12
    }
	while IFS=":" read -r nom groupe shell repertoire; do
		j
        	if id "$nom" &>/dev/null; then
        	echo "L'utilisateur $nom existe déjà. Modification de ses informations..."

		usermod -g "$groupe" "$nom"

		usermod -d "$repertoir" -m"$nom"


	else
	    	echo "ajout de l'utilisateur $nom..."

	    	useradd -g "$groupe" -s "$shell" -d "$repertoire" -m "$nom"

	fi

	mot_de_passe=$(generer_mot_de_passe)

	echo"$nom:$mot_de_passe" | chpasswd

done < "$fichier_utilisateur"





