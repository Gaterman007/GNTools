require 'sketchup.rb'
require 'json'
require 'GNTools/GN_PathObj.rb'

module GNTools
  module Paths

    class StraitCut < PathObj
      attr_accessor :cutwidth, :startPosition, :endPosition, :nbdesegment

      # Configuration par défaut spécifique à StraitCut
      @@derivedType = @@defaultType.merge({
        methodType: "Ramp",
        cutwidth: 5.3
      }).freeze

      def initialize(group = nil)
        @cutwidth = 5.3
        @startPosition = [0, 0, 0]
        @endPosition = [0, 0, 0] 
        @nbdesegment = 24
        
        super("StraitCut", group)
        
        # Définir la méthode par défaut si non définie
        self.methodType = "Ramp" if self.methodType.empty?
      end

      def defaultType
        @@derivedType
      end

      # Création d'une nouvelle instance avec ligne et paramètres
      def self.Create(line, hash)
        return nil unless line && line.size >= 2
        
        begin
          newinstance = new()
          GNTools.toolDefaultNo["StraitCut"] = GNTools.toolDefaultNo["StraitCut"] + 1
          newinstance.pathName = "StraitCut_#{GNTools.toolDefaultNo["StraitCut"]}"
          newinstance.from_Hash(hash) if hash
          newinstance.set_To_Attribute(newinstance.pathEntitie)
          newinstance.startPosition = line[0]
          newinstance.endPosition = line[1]
          newinstance.createDynamiqueModel
          
          puts GNTools.traduire("StraitCut créé: %{name}", name: newinstance.pathName)
          newinstance
        rescue => e
          puts GNTools.traduire("Erreur création StraitCut: %{error}", error: e.message)
          nil
        end
      end

      # Obtient les positions dans le système global
      def getGlobal
        return [@startPosition, @endPosition] unless @pathEntitie
        
        begin
          transformation = GNTools::Paths::TransformPoint.getGlobalTransform(@pathEntitie.parent)
          
          startPos = Geom::Point3d.new(@startPosition[0], @startPosition[1], @startPosition[2])
          startPos.transform!(transformation)
          
          endPos = Geom::Point3d.new(@endPosition[0], @endPosition[1], @endPosition[2])
          endPos.transform!(transformation)
          
          [startPos, endPos]
        rescue => e
          puts GNTools.traduire("Erreur transformation globale: %{error}", error: e.message)
          [@startPosition, @endPosition]
        end
      end

      # Crée le modèle 3D dynamique pour visualisation
      def createDynamiqueModel
        return unless @pathEntitie&.valid?
        
        begin
          startPos, endPos = getGlobal()
          return if startPos == endPos
          
          drillbit = DrillBits.getDrillBit(@drillBitName)
          return unless drillbit
          
          drillbitSize = drillbit.cut_Diameter.mm
          lineWidth = [@cutwidth.mm, drillbitSize].max
          
          # Calcul des vecteurs
          vector_line = endPos - startPos
          return if vector_line.length == 0
          
          inverse_vector_line = startPos - endPos
          
          case @methodType
          when "Ramp"
            create_ramp_model(startPos, endPos, vector_line, inverse_vector_line, lineWidth, drillbitSize)
          when "Spiral"
            create_spiral_model(startPos, endPos, vector_line, inverse_vector_line, lineWidth, drillbitSize)
          end
          
          # Ajouter les points de repère
          @pathEntitie.entities.add_cpoint(startPos)
          @pathEntitie.entities.add_cpoint(endPos)
          
          Sketchup.active_model.active_view.invalidate
          
        rescue => e
          puts GNTools.traduire("Erreur création modèle dynamique: %{error}", error: e.message)
        end
      end

      # Notification de changement - recrée le modèle
      def changed(create_undo = false)
        super(create_undo)
        return unless @pathEntitie&.valid?
        
        begin
          # Effacer le modèle existant
          @pathEntitie.entities.clear!
          
          # Recréer le modèle
          createDynamiqueModel
          
        rescue => e
          puts GNTools.traduire("Erreur lors du changement: %{error}", error: e.message)
        end
        
        @pathEntitie
      end

      # Crée le chemin de visualisation 3D
      def createPath
        super()
        return unless valid_drill_bit?
        
        begin
          startPos, endPos = getGlobal()
          pathGroup = Sketchup.active_model.entities.add_group()
          
          drillbit = DrillBits.getDrillBit(@drillBitName)
          drillbitSize = drillbit.cut_Diameter
          drillBitRayon = (drillbitSize / 2.0).mm
          
          # Obtenir les paramètres CNC
          cnc_params = get_cnc_parameters()
          holeBottom = -@depth.mm
          
          case @methodType
          when "Ramp"
            create_ramp_path(pathGroup, startPos, endPos, drillbitSize, cnc_params, holeBottom)
          when "Spiral"
            create_spiral_path(pathGroup, startPos, endPos, drillbitSize, cnc_params, holeBottom)
          end
          
          # Points de repère
          pathGroup.entities.add_cpoint(startPos)
          pathGroup.entities.add_cpoint(endPos)
          
        rescue => e
          puts GNTools.traduire("Erreur création chemin: %{error}", error: e.message)
        end
      end

      # Génère le G-Code pour cette coupe droite
      def createGCode(gCodeStr)
        return gCodeStr unless valid_drill_bit?
        
        begin
          startPos, endPos = getGlobal()
          drillbit = DrillBits.getDrillBit(@drillBitName)
          drillbitSize = drillbit.cut_Diameter
          
          def_CNCData = DefaultCNCDialog.def_CNCData
          safeHeight = def_CNCData.safeHeight
          material_thickness = def_CNCData.material_thickness
          
          # En-tête
          gCodeStr += generate_gcode_header(startPos, endPos, drillbitSize)
          
          # Aller à la hauteur de sécurité
          gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('aller hauteur sécurité')}\n" % [safeHeight]
          
          # Générer le G-Code selon la méthode
          case @methodType
          when "Ramp"
            gCodeStr = generate_ramp_gcode(gCodeStr, startPos, endPos, drillbitSize, def_CNCData)
          when "Spiral"
            gCodeStr = generate_spiral_gcode(gCodeStr, startPos, endPos, drillbitSize, def_CNCData)
          end
          
        rescue => e
          puts GNTools.traduire("Erreur génération G-Code: %{error}", error: e.message)
          gCodeStr += "; #{GNTools.traduire('ERREUR')}: #{e.message}\n"
        end
        
        gCodeStr
      end

      # Sauvegarde des attributs
      def set_To_Attribute(group)
        super(group)
        return unless group&.valid?
        
        group.set_attribute("StraitCut", "cutwidth", @cutwidth)
        group.set_attribute("StraitCut", "startPosition", @startPosition)
        group.set_attribute("StraitCut", "endPosition", @endPosition)
        group.set_attribute("StraitCut", "nbdesegment", @nbdesegment)
      end

      # Chargement des attributs
      def get_From_Attributs(ent)
        super(ent)
        return unless ent&.valid?
        
        @cutwidth = ent.get_attribute("StraitCut", "cutwidth") || @cutwidth
        @startPosition = ent.get_attribute("StraitCut", "startPosition") || @startPosition
        @endPosition = ent.get_attribute("StraitCut", "endPosition") || @endPosition
        @nbdesegment = ent.get_attribute("StraitCut", "nbdesegment") || @nbdesegment
      end

      # Conversion depuis Hash
      def from_Hash(hash)
        super(hash)
        return unless hash.is_a?(Hash)
        
        @cutwidth = hash.dig("cutwidth", "Value") || @cutwidth
      end

      # Conversion vers Hash
      def to_Hash(hashTable = {})
        super(hashTable)
        hashTable["cutwidth"] = {"Value" => @cutwidth, "type" => "spinner", "multiple" => false}
        hashTable
      end

      private

      # Vérifie si le drill bit est valide
      def valid_drill_bit?
        drillbit = DrillBits.getDrillBit(@drillBitName)
        unless drillbit
          puts GNTools.traduire("Drill bit non trouvé: %{name}", name: @drillBitName)
          return false
        end
        true
      end

      # Obtient les paramètres CNC
      def get_cnc_parameters
        {
          safeHeight: get_cnc_param("safeHeight", DefaultCNCDialog.def_CNCData.safeHeight).mm,
          material_thickness: get_cnc_param("height", DefaultCNCDialog.def_CNCData.material_thickness).mm,
          defaultFeedRate: get_cnc_param("defaultFeedRate", DefaultCNCDialog.def_CNCData.defaultFeedRate)
        }
      end

      def get_cnc_param(param_name, default_value)
        value = DefaultCNCData.getFromModel(param_name) if defined?(DefaultCNCData)
        value || default_value
      end

      # Crée le modèle Ramp
      def create_ramp_model(startPos, endPos, vector_line, inverse_vector_line, lineWidth, drillbitSize)
        vector_line.length = lineWidth / 2.0
        inverse_vector_line.length = lineWidth / 2.0
        
        startMidPos = startPos.offset(vector_line)
        endMidPos = endPos.offset(inverse_vector_line)
        vector_verticle = Geom::Vector3d.new(0, 0, 1)
        vector_perp = vector_verticle.cross(vector_line)
        
        # Arcs aux extrémités
        @pathEntitie.entities.add_arc(startMidPos, vector_line, vector_verticle, 
                                     lineWidth / 2.0, 90.degrees, 270.degrees)
        @pathEntitie.entities.add_arc(endMidPos, inverse_vector_line, vector_verticle, 
                                     lineWidth / 2.0, 90.degrees, 270.degrees)
        
        # Rectangle central
        create_rectangle_edges(startMidPos, endMidPos, vector_perp, lineWidth)
      end

      # Crée le modèle Spiral
      def create_spiral_model(startPos, endPos, vector_line, inverse_vector_line, lineWidth, drillbitSize)
        # Implementation complexe pour spiral - version simplifiée
        create_ramp_model(startPos, endPos, vector_line, inverse_vector_line, lineWidth, drillbitSize)
      end

      # Crée les arêtes du rectangle
      def create_rectangle_edges(startMidPos, endMidPos, vector_perp, lineWidth)
        p1 = startMidPos.offset(vector_perp, lineWidth / 2.0)
        p2 = endMidPos.offset(vector_perp, lineWidth / 2.0)
        p3 = endMidPos.offset(vector_perp, -lineWidth / 2.0)
        p4 = startMidPos.offset(vector_perp, -lineWidth / 2.0)
        
        edges = []
        edges << @pathEntitie.entities.add_edges(p1, p2)
        edges << @pathEntitie.entities.add_edges(p3, p4)
        
        # Créer la face et l'extruder
        if edges.any? && edges.first.any?
          edges.first.first.find_faces
          face = @pathEntitie.entities.grep(Sketchup::Face).find(&:valid?)
          
          if face
            distance = self["depth"].mm
            distance = -distance if face.normal.z > 0.0
            face.pushpull(distance)
          end
        end
      end

      # Génère l'en-tête G-Code
      def generate_gcode_header(startPos, endPos, drillbitSize)
        header = "; #{GNTools.traduire('Coupe Droite')}: #{@pathName}\n"
        header += "; #{GNTools.traduire('Drill bit')}: #{@drillBitName}\n"
        header += "; #{GNTools.traduire('Méthode')}: #{@methodType}\n"
        header += "; #{GNTools.traduire('Taille drill bit')}: %.2fmm\n" % [drillbitSize]
        header += "; #{GNTools.traduire('Ligne de')} X%.2f Y%.2f #{GNTools.traduire('à')} X%.2f Y%.2f\n" % [
          startPos.x.to_mm, startPos.y.to_mm, endPos.x.to_mm, endPos.y.to_mm
        ]
        header
      end

      # Génère le G-Code pour la méthode Ramp
      def generate_ramp_gcode(gCodeStr, startPos, endPos, drillbitSize, def_CNCData)
        defRayon = [@cutwidth - drillbitSize, 0.0].max
        material_thickness = def_CNCData.material_thickness
        holeBottom = [material_thickness - @depth, 0.0].max
        
        downslow = @multipass ? material_thickness : holeBottom
        
        gCodeStr += "G0 X%.2f Y%.2f ; #{GNTools.traduire('aller position départ')}\n" % [startPos.x.to_mm, startPos.y.to_mm]
        gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('aller dessus matériel')}\n" % [material_thickness]
        
        while downslow >= holeBottom
          gCodeStr += "G0 X%.2f Y%.2f ; #{GNTools.traduire('position départ')}\n" % [startPos.x.to_mm, startPos.y.to_mm]
          gCodeStr += "G1 Z%.2f F%.0f ; #{GNTools.traduire('descendre lentement')}\n" % [downslow, def_CNCData.defaultPlungeRate]
          gCodeStr = lineGCode(startPos, endPos, defRayon, gCodeStr)
          downslow -= @depthstep
        end
        
        gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('remonter')}\n" % [def_CNCData.safeHeight]
        gCodeStr
      end

      # Génère le G-Code pour la méthode Spiral
      def generate_spiral_gcode(gCodeStr, startPos, endPos, drillbitSize, def_CNCData)
        material_thickness = def_CNCData.material_thickness
        holeBottom = [material_thickness - @depth, 0.0].max
        
        if @multipass
          downslow = material_thickness
          gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('dessus matériel')}\n" % [material_thickness]
          
          while downslow > holeBottom
            gCodeStr += "G0 X%.2f Y%.2f ; #{GNTools.traduire('position départ')}\n" % [startPos.x.to_mm, startPos.y.to_mm]
            gCodeStr += "G1 Z%.2f F%.0f ; #{GNTools.traduire('descendre')}\n" % [downslow, def_CNCData.defaultPlungeRate]
            gCodeStr += "G1 X%.2f Y%.2f F%.0f ; #{GNTools.traduire('aller fin')}\n" % [endPos.x.to_mm, endPos.y.to_mm, @feedrate]
            downslow -= @depthstep
          end
        else
          gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('dessus matériel')}\n" % [material_thickness]
          gCodeStr += "G0 X%.2f Y%.2f ; #{GNTools.traduire('position départ')}\n" % [startPos.x.to_mm, startPos.y.to_mm]
          gCodeStr += "G1 Z%.2f F%.0f ; #{GNTools.traduire('descendre')}\n" % [holeBottom, def_CNCData.defaultPlungeRate]
          gCodeStr += "G1 X%.2f Y%.2f F%.0f ; #{GNTools.traduire('aller fin')}\n" % [endPos.x.to_mm, endPos.y.to_mm, @feedrate]
        end
        
        gCodeStr += "G0 Z%.2f ; #{GNTools.traduire('remonter')}\n" % [def_CNCData.safeHeight]
        gCodeStr
      end

      # Crée le chemin Ramp
      def create_ramp_path(pathGroup, startPos, endPos, drillbitSize, cnc_params, holeBottom)
        defRayon = [@cutwidth - drillbitSize, 0.0].max
        downslow = @multipass ? 0.0 : holeBottom
        
        while downslow >= holeBottom
          createLinePath(pathGroup, startPos, endPos, defRayon, downslow)
          downslow -= @depthstep.mm
        end
      end

      # Crée le chemin Spiral  
      def create_spiral_path(pathGroup, startPos, endPos, drillbitSize, cnc_params, holeBottom)
        # Version simplifiée pour spiral
        createLinePath(pathGroup, startPos, endPos, 0, holeBottom)
      end

      # Méthodes héritées avec gestion d'erreurs améliorée
      def createLinePath(pathGroup, startPos, endPos, defRayon, downslow)
        return unless pathGroup&.valid?
        
        begin
          startX, startY = startPos.x.to_mm, startPos.y.to_mm
          endX, endY = endPos.x.to_mm, endPos.y.to_mm
          
          pas = DrillBits.getDrillBit(@drillBitName).cut_Diameter
          direction = Geom::Vector3d.new(endX - startX, endY - startY, 0)
          
          return if direction.length == 0
          direction.normalize!
          
          currentX, currentY = startX, startY
          
          while Geom::Point3d.new(currentX, currentY, downslow).distance(Geom::Point3d.new(endX, endY, downslow)) >= pas
            pathGroup.entities.add_cpoint(Geom::Point3d.new(currentX.mm, currentY.mm, downslow))
            createCirlcePath(pathGroup, currentX, currentY, defRayon, @nbdesegment, downslow.to_mm)
            
            currentX += direction.x * pas
            currentY += direction.y * pas
          end
          
          createCirlcePath(pathGroup, endX, endY, defRayon, @nbdesegment, downslow.to_mm)
          
        rescue => e
          puts GNTools.traduire("Erreur création chemin ligne: %{error}", error: e.message)
        end
      end

      def createCirlcePath(pathGroup, xpos, ypos, radius, segment, downslow)
        return unless pathGroup&.valid? && segment > 0
        
        begin
          halfnbOfAngle = segment / 2.0
          stepAngle = 360.0 / segment
          @lastPosition = [xpos.mm, ypos.mm, downslow.mm]
          
          (0..halfnbOfAngle).each do |angle|
            sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
            cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
            pathGroup.entities.add_edges(@lastPosition, [sinus.mm, cosine.mm, @lastPosition[2]])
            @lastPosition = [sinus.mm, cosine.mm, @lastPosition[2]]
          end
          
          (halfnbOfAngle - 1).step(0, -1) do |angle|
            sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
            cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
            pathGroup.entities.add_edges(@lastPosition, [sinus.mm, cosine.mm, @lastPosition[2]])
            @lastPosition = [sinus.mm, cosine.mm, @lastPosition[2]]
          end
          
        rescue => e
          puts GNTools.traduire("Erreur création chemin circulaire: %{error}", error: e.message)
        end
      end

      def lineGCode(startPos, endPos, defRayon, gCodeStr)
        begin
          startX, startY = startPos.x.to_mm, startPos.y.to_mm
          endX, endY = endPos.x.to_mm, endPos.y.to_mm
          
          pas = DrillBits.getDrillBit(@drillBitName).cut_Diameter
          direction = Geom::Vector3d.new(endX - startX, endY - startY, 0)
          
          return gCodeStr if direction.length == 0
          direction.normalize!
          
          currentX, currentY = startX, startY
          
          while Geom::Point3d.new(currentX, currentY).distance(Geom::Point3d.new(endX, endY)) >= pas
            gCodeStr = createGCodeCirlce(gCodeStr, currentX, currentY, defRayon, @nbdesegment)
            currentX += direction.x * pas
            currentY += direction.y * pas
          end
          
          gCodeStr = createGCodeCirlce(gCodeStr, endX, endY, defRayon, @nbdesegment)
          
        rescue => e
          puts GNTools.traduire("Erreur G-Code ligne: %{error}", error: e.message)
          gCodeStr += "; #{GNTools.traduire('ERREUR ligne G-Code')}: #{e.message}\n"
        end
        
        gCodeStr
      end

      def createGCodeCirlce(gCodeStr, xpos, ypos, radius, segment)
        return gCodeStr if segment <= 0
        
        begin
          halfnbOfAngle = segment / 2.0
          stepAngle = 360.0 / segment
          
          (0..halfnbOfAngle).each do |angle|
            sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
            cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
            gCodeStr += "G1 X%.2f Y%.2f F%.0f ; #{GNTools.traduire('cercle angle')} %.2f\n" % [sinus, cosine, @feedrate, angle * stepAngle]
          end
          
          (halfnbOfAngle - 1).step(0, -1) do |angle|
            sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
            cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
            gCodeStr += "G1 X%.2f Y%.2f F%.0f ; #{GNTools.traduire('cercle angle')} %.2f\n" % [sinus, cosine, @feedrate, (360 - (angle * stepAngle))]
          end
          
        rescue => e
          puts GNTools.traduire("Erreur G-Code cercle: %{error}", error: e.message)
          gCodeStr += "; #{GNTools.traduire('ERREUR cercle G-Code')}: #{e.message}\n"
        end
        
        gCodeStr
      end

    end # class StraitCut
  end # module Paths
end # module GNTools