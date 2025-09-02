require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'GNTools/GN_DrillBits.rb'

module GNTools

  # Variables de classe avec accesseurs propres
  @pathObjList = {}
  @generation_stats = {
    total_objects: 0,
    generated_files: 0,
    total_lines: 0,
    generation_time: 0.0
  }

  class << self
    attr_accessor :pathObjList, :generation_stats
  end

  # Compteurs pour les différents types d'outils
  @@toolDefaultNo = {"Hole" => 0, "StraitCut" => 0, "Pocket" => 0}
  @@toolPathNo = 0
  @@straitCutNo = 0
  @@pocketNo = 0

  class << self
    attr_accessor :toolDefaultNo, :toolPathNo, :straitCutNo, :pocketNo
  end

  # Initialisation améliorée
  def self.initCNCGCode
    begin
      puts GNTools.traduire("🔧 Initialisation du générateur G-Code...")
      
      # Initialiser les données par défaut
      if defined?(DefaultCNCDialog)
        DefaultCNCDialog.set_defaults
      else
        puts GNTools.traduire("⚠ DefaultCNCDialog non trouvé")
      end
      
      # Définir les numéros par défaut
      self.setCNCDefaultNo
      
      # Charger les chemins
      if defined?(Paths)
        Paths.loadPaths()
        puts GNTools.traduire("✓ Chemins chargés")
      else
        puts GNTools.traduire("⚠ Module Paths non trouvé")
      end
      
      # Réinitialiser les statistiques
      @generation_stats = {
        total_objects: 0,
        generated_files: 0,
        total_lines: 0,
        generation_time: 0.0
      }
      
      puts GNTools.traduire("✓ Générateur G-Code initialisé")
    rescue => e
      puts GNTools.traduire("✗ Erreur lors de l'initialisation G-Code: %{error}", error: e.message)
      UI.messagebox(GNTools.traduire("Erreur d'initialisation G-Code: %{error}", error: e.message))
    end
  end

  # Méthode améliorée pour définir les numéros par défaut
  def self.setCNCDefaultNo
    model = Sketchup.active_model
    return unless model

    ents = model.active_entities
    return unless ents

    begin
      ents.each do |entity|
        next unless entity.respond_to?(:name) && entity.name
        
        groupName = nil
        if defined?(Paths) && Paths.respond_to?(:isGroupObj)
          groupName = Paths::isGroupObj(entity)
        end
        
        if groupName && @@toolDefaultNo.key?(groupName) && entity.name.include?("_")
          # Extraire le numéro de manière plus robuste
          name_parts = entity.name.split("_")
          if name_parts.length > 1
            number_str = name_parts.last
            if number_str.match(/^\d+$/)
              entnumber = number_str.to_i
              @@toolDefaultNo[groupName] = [@@toolDefaultNo[groupName], entnumber].max
            end
          end
        end
      end
    rescue => e
              puts GNTools.traduire("Erreur lors de setCNCDefaultNo: %{error}", error: e.message)
    end
  end

  class GCodeGenerate
    
    # Génération G-Code principale avec statistiques
    def self.generateGCode
      start_time = Time.now
      
      begin
        model = Sketchup.active_model
        unless model
          UI.messagebox(GNTools.traduire("Aucun modèle actif"))
          return ""
        end

        # Collecter tous les drill bits uniques
        drillNames = collect_unique_drill_bits
        return "" if drillNames.empty?

        puts GNTools.traduire("🔄 Génération G-Code pour %{count} outil(s)...", count: drillNames.length)
        
        gCodeStr = generate_header_comment
        total_lines = 0

        drillNames.each do |drillName|
          if GNTools::DrillBits.isDrillBit(drillName)[0]
            layer_code = generateGCodeLayer(drillName)
            gCodeStr += layer_code
            total_lines += layer_code.lines.count
            puts "  ✓ #{drillName}: #{layer_code.lines.count} lignes"
          else
            puts GNTools.traduire("  ⚠ Drill bit non trouvé: %{name}", name: drillName)
          end
        end

        # Mettre à jour les statistiques
        generation_time = Time.now - start_time
        GNTools.generation_stats[:generation_time] = generation_time
        GNTools.generation_stats[:total_lines] = total_lines
        GNTools.generation_stats[:total_objects] = GNTools.pathObjList.length

        puts GNTools.traduire("✓ G-Code généré: %{lines} lignes en %{time}s", 
                                lines: total_lines, 
                                time: generation_time.round(2))
        gCodeStr
        
      rescue => e
        UI.messagebox(GNTools.traduire("Erreur lors de la génération G-Code: %{error}", error: e.message))
        puts GNTools.traduire("✗ Erreur génération: %{error}", error: e.message)
        ""
      end
    end

    # Génération pour visualisation (sans G-Code, juste les chemins)
    def self.generatePreview
      drillNames = collect_unique_drill_bits
      
      drillNames.each do |drillName|
        if GNTools::DrillBits.isDrillBit(drillName)[0]
          generateGCodeLayer2(drillName)
        end
      end
    end

    # Version améliorée de generateGCodeLayer2 pour prévisualisation
    def self.generateGCodeLayer2(drillName)
      return unless defined?(DefaultCNCDialog)
      
      def_CNCData = DefaultCNCDialog.def_CNCData
      preview_count = 0
      
      GNTools.pathObjList.each do |key, pathobj|
        if drillName == pathobj.drillBitName
          begin
            pathobj.createPath()
            preview_count += 1
          rescue => e
            puts GNTools.traduire("Erreur création chemin pour %{key}: %{error}", key: key, error: e.message)
          end
        end
      end
      
      puts GNTools.traduire("✓ Prévisualisation: %{count} chemins créés pour %{drill}", 
                           count: preview_count, drill: drillName)
    end

    # Substitution des codes avec validation
    def self.replaceCodes(code)
      return code unless defined?(DefaultCNCDialog)
      
      begin
        def_CNCData = DefaultCNCDialog.def_CNCData
        
        replacements = {
          "{Safe Height}" => "%0.3f" % [def_CNCData.safeHeight || 5.0],
          "{Project Name}" => "%s" % [def_CNCData.project_Name || "Projet_CNC"],
          "{Material Type}" => "%s" % [def_CNCData.material_type || "Bois"],
          "{FeedRate}" => "%0.1f" % [def_CNCData.defaultFeedRate || 1000.0],
          "{PlungeRate}" => "%0.1f" % [def_CNCData.defaultPlungeRate || 300.0],
          "{DepthLenght}" => "%0.3f" % [def_CNCData.defaultDepthLenght || 3.0],
          "{Material Width}" => "%0.2f" % [def_CNCData.material_width || 100.0],
          "{Material Thickness}" => "%0.2f" % [def_CNCData.material_thickness || 20.0],
          "{Material Depth}" => "%0.2f" % [def_CNCData.material_depth || 20.0],
          "{Lenght Precision}" => "%0.0f" % [def_CNCData.LengthPrecision || 3],
          "{Date}" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
          "{Tool Count}" => GNTools.pathObjList.length.to_s
        }
        
        replacements.each do |placeholder, value|
          code = code.gsub(placeholder, value.to_s)
        end
        
        code
      rescue => e
        puts GNTools.traduire("Erreur lors du remplacement des codes: %{error}", error: e.message)
        code
      end
    end

    # Génération d'une couche G-Code améliorée
    def self.generateGCodeLayer(drillName)
      return "" unless defined?(DefaultCNCDialog)
      
      def_CNCData = DefaultCNCDialog.def_CNCData
      gCodeStr = ""
      
      # En-tête de l'outil
      gCodeStr += generate_tool_header(drillName)
      
      # Code de début
      startCode = (def_CNCData.startGCode || "").gsub(/\r?\\n/, "\n")
      gCodeStr += replaceCodes(startCode)
      
      # Traiter tous les objets pour cet outil
      path_count = 0
      GNTools.pathObjList.each do |key, pathobj|
        if drillName == pathobj.drillBitName
          begin
            tool_gcode = pathobj.createGCode(gCodeStr)
            if tool_gcode && tool_gcode != gCodeStr
              gCodeStr = tool_gcode
              path_count += 1
            end
          rescue => e
            puts GNTools.traduire("Erreur génération G-Code pour %{key}: %{error}", key: key, error: e.message)
            gCodeStr += "; #{GNTools.traduire('ERREUR')}: #{e.message}\n"
          end
        end
      end
      
      # Code de fin
      endCode = (def_CNCData.endGCode || "").gsub(/\r?\\n/, "\n")
      gCodeStr += replaceCodes(endCode)
      gCodeStr += "\n\n"
      
      puts GNTools.traduire("  Objets traités pour %{drill}: %{count}", drill: drillName, count: path_count)
      gCodeStr
    end

    # Sauvegarde améliorée avec validation
    def self.SaveAs
      model = Sketchup.active_model
      unless model
        UI.messagebox(GNTools.traduire("Aucun modèle actif"))
        return
      end

      if GNTools.pathObjList.empty?
        UI.messagebox(GNTools.traduire("Aucun objet à générer"))
        return
      end

      begin
        selected_folder = UI.select_directory(
          title: GNTools.traduire("Choisir un dossier de sauvegarde"),
          directory: get_default_save_directory
        )
        
        if selected_folder && File.directory?(selected_folder)
          base_filename = generate_base_filename(selected_folder)
          self.saveTo(File.join(selected_folder, base_filename), model)
        end
      rescue StandardError => e
        UI.messagebox(GNTools.traduire("Erreur lors de la sauvegarde: %{error}", error: e.message))
        puts GNTools.traduire("Erreur sauvegarde: %{error}", error: e.message)
      end
    end

    # Sauvegarde améliorée avec gestion d'erreurs
    def self.saveTo(filepath, model)
      start_time = Time.now
      files_created = 0
      
      begin
        drillNames = collect_unique_drill_bits
        return if drillNames.empty?
        
        # Créer le dossier si nécessaire
        FileUtils.mkdir_p(File.dirname(filepath))
        
        # Générer un fichier par drill bit
        drillNames.each do |drillName|
          if GNTools::DrillBits.isDrillBit(drillName)[0]
            filename = generate_drill_filename(filepath, drillName)
            
            File.open(filename, "w+", encoding: 'UTF-8') do |file|
              file.puts generate_file_header(filename)
              file.puts generateGCodeLayer(drillName)
              files_created += 1
            end
            
            puts GNTools.traduire("✓ Fichier créé: %{filename}", filename: File.basename(filename))
          end
        end
        
        # Mettre à jour les statistiques
        GNTools.generation_stats[:generated_files] = files_created
        generation_time = Time.now - start_time
        
        # Message de confirmation
        message = GNTools.traduire("✓ %{count} fichier(s) G-Code généré(s)", count: files_created) + "\n"
        message += GNTools.traduire("📂 Dossier: %{folder}", folder: File.dirname(filepath)) + "\n"
        message += GNTools.traduire("⏱ Temps: %{time}s", time: generation_time.round(2))
        
        UI.messagebox(message)
        puts message.gsub("\n", " | ")
        
      rescue => e
        UI.messagebox(GNTools.traduire("Erreur lors de la sauvegarde: %{error}", error: e.message))
        puts GNTools.traduire("✗ Erreur sauvegarde: %{error}", error: e.message)
      end
    end

    # === MÉTHODES UTILITAIRES ===

    private

    def self.collect_unique_drill_bits
      return [] if GNTools.pathObjList.empty?
      
      drillNames = GNTools.pathObjList.values
        .map { |pathObj| pathObj.drillBitName }
        .compact
        .uniq
        .reject { |name| name.nil? || name.empty? }
      
      drillNames
    end

    def self.generate_header_comment
      ";\n; === #{GNTools.traduire('G-Code généré par GNTools v%{version}', version: @@PLUGIN_VERSION)} ===\n;\n"
    end

    def self.generate_tool_header(drillName)
      drill_info = GNTools::DrillBits.isDrillBit(drillName)
      header = ";\n; === #{GNTools.traduire('OUTIL')}: #{drillName} ===\n"
      if drill_info[0]
        header += "; #{GNTools.traduire('Diamètre')}: #{drill_info[0].diameter}mm\n"
        header += "; #{GNTools.traduire('Type')}: #{drill_info[0].type || 'Standard'}\n"
      end
      header += ";\n"
      header
    end

    def self.generate_file_header(filename)
      header = "; #{GNTools.traduire('Fichier')}: #{File.basename(filename)}\n"
      header += "; #{GNTools.traduire('Généré le')}: #{Time.now.strftime('%Y-%m-%d à %H:%M:%S')}\n"
      header += "; #{GNTools.traduire('Par')}: GNTools v#{@@PLUGIN_VERSION}\n"
      header += ";"
      header
    end

    def self.get_default_save_directory
      # Essayer plusieurs dossiers par défaut
      candidates = [
        File.join(File.expand_path("~"), "Documents", "CNC"),
        File.join(File.expand_path("~"), "Documents"),
        File.expand_path("~")
      ]
      
      candidates.find { |dir| File.directory?(dir) } || File.expand_path("~")
    end

    def self.generate_base_filename(folder_path)
      folder_name = File.basename(folder_path)
      timestamp = Time.now.strftime("%Y%m%d_%H%M")
      "#{folder_name}_#{timestamp}.cnc"
    end

    def self.generate_drill_filename(base_filepath, drillName)
      # Nettoyer le nom du drill bit pour le nom de fichier
      clean_drill_name = drillName.gsub(/[^\w\-_.]/, '_')
      
      if base_filepath.downcase.end_with?(".cnc")
        base_filepath.sub(/\.cnc$/i, "_#{clean_drill_name}.cnc")
      else
        "#{base_filepath}_#{clean_drill_name}.cnc"
      end
    end

  end # class GCodeGenerate

  # Méthode utilitaire pour obtenir les statistiques
  def self.get_generation_stats
    @generation_stats
  end

  # Méthode pour nettoyer les ressources
  def self.cleanup_gcode_resources
    @pathObjList.clear
    @generation_stats = {
      total_objects: 0,
      generated_files: 0,
      total_lines: 0,
      generation_time: 0.0
    }
    puts GNTools.traduire("🧹 Ressources G-Code nettoyées")
  end

end # module GNTools