#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
#  load "C:/Users/Gaetan/Documents/Sketchup/GN3DPrinterCNC.rb"
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'
require 'sketchup.rb'
require 'json'

module GNTools

   # Plugin information
    @@PLUGIN          = self
    @@PLUGIN_ID       = "GNTool".freeze
    @@PLUGIN_NAME     = "Tool Set²".freeze
    @@PLUGIN_VERSION  = "0.2.0".freeze

    # Resource paths
    file = File.join(Sketchup.find_support_file('Plugins'),'GNTools.rb').dup
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
    FILENAMESPACE = File.basename(file, ".*")
    PATH_ROOT     = File.dirname(file).freeze
    PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze
    PATH_IMAGES  = File.join(PATH, "images").freeze
    PATH_GL_TEXT = File.join(PATH_IMAGES, "text").freeze
    PATH_HTML    = File.join(PATH, "html").freeze


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

    def self.reload()
        original_verbose = $VERBOSE
        $VERBOSE = nil
        # GN_ToolSet file (this)
        load 'GNTools.rb'
        SKETCHUP_CONSOLE.clear
        if defined?(PATH) && File.exist?(PATH)
            x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
                load file
            }
            x.length + 1
        else
            1
        end
		DrillBits.loadFromFile(File.join(PATH, "DrillBits.txt"))
		initCNCGCode
		ObserverModule.reload
    ensure
        $VERBOSE = original_verbose
    end

	self.load_translation()

	require 'GNTools/GN_Menus.rb'

	unless file_loaded?(file)

		GNTools.create_Menus()
        if defined?(PATH) && File.exist?(PATH)
            x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
#                p file
                load file
            }
            x.length + 1
        else
            1
        end
		require File.join(PATH, "GN_Toolbars.rb")
		GN3DToolbars.load
		file_loaded(file)
	end
	
	SKETCHUP_CONSOLE.show
	DrillBits.loadFromFile(File.join(PATH, "DrillBits.txt"))
	self.initCNCGCode    
end
