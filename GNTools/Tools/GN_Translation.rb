require 'sketchup.rb'

module GNTools
	# Variable pour stocker les traductions une fois chargées
	@translations = {}

  # Fonction pour charger les traductions une seule fois
    def self.load_translation
	    locale = Sketchup.get_locale  # Récupère la locale de SketchUp (par ex: "en-US", "fr", etc.)
		translation_file = "GNTools.strings"  # Le fichier JSON de traduction
        # Chemin complet du fichier JSON de traduction pour la locale
        json_path = File.join(PATH_ROOT, "GNTools", "Resources", locale, translation_file)
		# Vérifie si le fichier de traduction existe
		if File.exist?(json_path)
			begin
			# Charge le contenu du fichier JSON
			file_content = File.read(json_path)
        
			# Parse le contenu JSON en un Hash
			@translations = JSON.parse(file_content)
			return nil
			rescue => e
				UI.messagebox("Erreur lors du chargement des traductions : #{e.message}")
			end
		end
		return nil
	end
	
	# Charger les traductions
	def self.traduire(chaine)
		return @translations[chaine] || chaine
	end

	def self.translations()
		@translations
	end

end