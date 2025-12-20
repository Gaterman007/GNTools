require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_DefaultCNCData.rb'
require 'GNTools/Tools/GN_GCodeGenerate.rb'
#require 'GNTools/Tools/GN_PathObjUtils.rb'


module GNTools

	module Paths

		class GN_ToolPathObjData
			attr_accessor :pathName
			attr_accessor :drillBitName
			attr_accessor :methodType
			attr_accessor :depth
			attr_accessor :feedrate
			attr_accessor :multipass
			attr_accessor :depthstep
			attr_accessor :overlapPercent
			attr_accessor :dictionaryName

			@defaultType = {
			  "pathName"       => { "Value" => "",        "type" => "text",     "multiple" => false },
			  "dictionaryName" => { "Value" => "PathObj", "type" => "text",     "multiple" => false },
			  "drillBitName"   => { "Value" => "Default", "type" => "dropdown", "multiple" => false },
			  "methodType"     => { "Value" => "",        "type" => "dropdown", "multiple" => false },
			  "depth"          => { "Value" => 4.0,       "type" => "spinner",  "multiple" => false },
			  "feedrate"       => { "Value" => 5.0,       "type" => "spinner",  "multiple" => false },
			  "multipass"      => { "Value" => true,      "type" => "checkbox", "multiple" => false },
			  "depthstep"      => { "Value" => 0.2,       "type" => "spinner",  "multiple" => false },
			  "overlapPercent" => { "Value" => 50,        "type" => "spinner",  "multiple" => false }
			}
			
			def initialize()
				self.class.defaultType.each do |key, info|
					instance_variable_set("@#{key}", info["Value"])
				end
			end
			
			def self.defaultType
			  @defaultType 
		    end
			
			# Synchroniser les données de l'objet vers le group
		    def set_To_Attribute(group)
			  self.class.defaultType.each do |key, info|
			    value = instance_variable_get("@#{key}")
			    group.set_attribute(@dictionaryName, key.to_s, value)
			  end
		    end

		    # Synchroniser les données depuis le group vers l'objet
		    def get_From_Attributs(group)
			  self.class.defaultType.each do |key, info|
			    value = group.get_attribute(@dictionaryName, key.to_s)
			    instance_variable_set("@#{key}", value)
			  end
		    end
			
			def from_Hash(hash)
			# from_hash : hash venant du dialog (structure Value/type)
				return unless hash.is_a?(Hash)
				hash.each do |k, v|
				  # accept both string and symbol keys
				  key = k.to_s
				  if self.class.defaultType.key?(key)
					instance_variable_set("@#{key}", v.is_a?(Hash) ? v["Value"] : v)
				  end
				end
			end
			
			def to_Hash(hashTable = {})
				self.class.defaultType.each do |key, info|
					hashTable[key] = {
					"Value"    => instance_variable_get("@#{key}"),
					"type"     => info["type"],
					"multiple" => info["multiple"]
					}
				end
				hashTable
			end

			def display()
			  self.class.defaultType.each do |key, info|
			    value = instance_variable_get("@#{key}")
				puts "#{key} = #{value}"
			  end
			end
		end

		class GN_ToolpathGCodeGenerator
			def self.generate(obj)
				self.get_obj_parameters(obj)
			end

			# Obtient les paramètres CNC
			def get_obj_parameters(obj)
			  drillbitSize = DrillBits.getDrillBit(obj.drillBitName).cut_Diameter	# diametre de la drill
			  drillBitRayon = (drillbitSize/2.0)									# rayon de la drill	
			  safeHeight = GNTools.getSafeHeight()
			  if safeHeight == nil
			    safeHeight = DefaultCNCDialog.def_CNCData.safeHeight
			  end
			  material_thickness = GNTools.material_Height()
			  if material_thickness == nil
				material_thickness = DefaultCNCDialog.def_CNCData.material_thickness
			  end
			  down_slow = obj.depthstep
			  if obj.multipass
				height_pass = material_thickness
			  else
			    height_pass = material_thickness - obj.depth
			  end
			  holeBottom = material_thickness - obj.depth
			end
			
			def createGCodeCirlce(gCodeStr,xpos,ypos,radius,segment)
				radius_mm = radius
				if GN_Hole.useG2Code
					gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; point de départ (haut du cercle)\n" % [xpos,ypos]
					gCodeStr = gCodeStr + "G2 X%0.2f Y%0.2f I0 J%0.2f  ; premier demi-cercle (180°)\n" % [xpos,ypos-radius_mm,-radius_mm]
					gCodeStr = gCodeStr + "G2 X%0.2f Y%0.2f I0 J%0.2f   ; deuxième demi-cercle (180°)\n" % [xpos,ypos+radius_mm,radius_mm]
				else
					halfnbOfAngle = segment / 2.0
					stepAngle = 360.0 / segment
					(0..halfnbOfAngle).each{ |angle|
						sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
						cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
						gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, angle * stepAngle]
					}
					(halfnbOfAngle - 1).step(0,-1) { |angle|
						sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
						cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
						gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, (360 - (angle * stepAngle))]
					}
				end
                gCodeStr
			end

		end



# =========================================
# GN_ToolPathObj
# Classe de base pour tous les objets de chemin
# =========================================
  # ==== Public Methods ====
  # initialize(group = nil)

  # Crée les données associées à l’objet
  # Doit retourner une instance de GN_ToolPathObjData ou dérivée
  # createPathData


  # Quatre method principal
  #		createDynamiqueModel cree un objet sketchup group solide
  #		createGCode cree un string GCode pour l envoie au CNC
  #		createPath   cree des edges pour montré le chemin
  #		draw		dessine temporairement 
  
  # createDynamiqueModel
  # Crée le modèle dynamique dans SketchUp
  # Utilise pathData et pathEntitie pour générer géométrie

  # createGCode(gCodeStr)
  # Génère le GCode pour l’objet
  # gCodeStr: string à compléter avec le code CNC

  # createPath
  # Crée la géométrie du chemin (edges, faces, etc.)

  # draw(view)
  # Dessinne temporaire du chemin d'outil (ToolPath) dans SketchUp

  # changed(create_undo = false)
  # Mise à jour du modèle après modification des données
	
	
		class GN_ToolPathObj
			attr_accessor :pathEntitie
			attr_accessor :pathID

			@registered_classes = {}

			class << self
				attr_reader :registered_classes
				attr_accessor :defaultTypeKeys

				def register_class(subclass, default_hash,create_callback,new_callback)
				  @registered_classes ||= {}
				  # Création du slot pour cette classe
				  @registered_classes[subclass] ||= {} 
			      @registered_classes[subclass][:defaults] = Marshal.load(Marshal.dump(default_hash))
				  @registered_classes[subclass][:create_path] = create_callback
				  @registered_classes[subclass][:new_callback] = new_callback
				end

				def defaults_for(subclass)
				  entry = @registered_classes[subclass]
				  showerrorstack unless entry
				  raise "Class #{subclass} not registered!" unless entry
				  entry[:defaults]
				end

				def create_pathobj(subclass, *args)
				  entry = @registered_classes[subclass]
				  showerrorstack unless entry
			      raise "Class #{subclass} not registered!" unless entry
				  entry[:create_path].call(*args)
				end
				
				
				def create_newobj(subclass, *args)
				  entry = @registered_classes[subclass]
				  showerrorstack unless entry
			      raise "Class #{subclass} not registered!" unless entry
				  entry[:new_callback].call(*args)
				end
				
				# ------------------------------------------
				# Mettre à jour un SEUL paramètre default
				# ------------------------------------------
				def set_default(subclass, key, value)
				  @registered_classes[subclass][:defaults][key][:default] = value
				end
				
				def createHashTable(*types)
				  result = {}

				  types.each do |t|
					table = {}
					entry = @registered_classes[t]
					if entry
					  table = Marshal.load(Marshal.dump(defaults_for(t)))
					else
					  showerrorstack unless entry
					  raise "Unknown GN_ToolPathObj type: #{t}"
					end
					result[t] = table
				  end
				  result
				end

				def showerrorstack
					# ---> ICI : afficher la stack d'appel
					puts "\n[CALL STACK]"
					puts caller.join("\n")
					puts "[END CALL STACK]\n"
				end
			end

			def initialize(group = nil)
				@pathData = createPathData
				if group				# group != nil devrait toujours etre un group
					self.pathEntitie = group
					@pathData.get_From_Attributs(group)
				else					# group == nil	cree avec les infos par defaut
					self.pathEntitie = Sketchup.active_model.active_entities.add_group()
					@pathData.set_To_Attribute(self.pathEntitie)
				end
				
				# Créer dynamiquement getters et setters pour chaque clé de pathData
				self.class.defaultTypeKeys ||= @pathData.class.defaultType.keys
				self.class.defaultTypeKeys.each do |key|
				  # getter
				  define_singleton_method(key) { @pathData.instance_variable_get("@#{key}") } unless respond_to?(key)
				  # setter
				  define_singleton_method("#{key}=") { |val|
					old_val = @pathData.instance_variable_get("@#{key}")
					@pathData.instance_variable_set("@#{key}",val)
					@pathEntitie.set_attribute(@pathData.dictionaryName, key.to_s, val) if defined?(@pathEntitie) && @pathEntitie
					onChange(key, old_val, val) if respond_to?(:onChange)
				  } unless respond_to?("#{key}=")
				end

			end

			# ---------- Méthodes à OVERRIDE ----------

			# chaque classe dérivée produit son visuel
			def createDynamiqueModel
				raise NotImplementedError
			end

			# retourne un objet complet, déjà configuré
			def self.Create(position, hash)
				raise NotImplementedError
			end

			# appelé quand un param change depuis la palette UI
			def changed(create_undo = false)
				raise NotImplementedError
			end

			# génère le GCode de l'objet
			def createGCode(gCodeStr)
				raise NotImplementedError
			end

			# construit géométriquement le toolpath dans SketchUp
			def createPath
				raise NotImplementedError
			end

			# Dessinne temporaire du chemin d'outil (ToolPath) dans SketchUp
			def draw(view)
				raise NotImplementedError
			end


			def pathEntitie
				@pathEntitie
			end
			
			def pathEntitie=(group)
				if group
					@pathEntitie = group
					@pathID = group.persistent_id
					GNTools.pathObjList[group.persistent_id] = self
					GNTools::Paths::ToolPathObjObserver.add_group(self)
				else
					@pathEntitie = nil
					@pathID = nil
				end
			end

			def onChange(key, old_val, val)
				if key == "pathName"
					@pathEntitie.name = val
				end
			end

			def getVar(key)
			  key = key.to_s
			  return nil unless @pathData.class.defaultType.key?(key)
			  @pathData.instance_variable_get("@#{key}")
			end

			def setVar(key, val)
			  key = key.to_s
			  return unless @pathData.class.defaultType.key?(key)

			  old_val = @pathData.instance_variable_get("@#{key}")

			  # Écrire dans pathData
			  @pathData.instance_variable_set("@#{key}", val)

			  # Écrire dans SketchUp Group (attributes)
			  if @pathEntitie && @pathData.dictionaryName
				@pathEntitie.set_attribute(@pathData.dictionaryName, key, val)
			  end

			  # Callback optionnel
			  onChange(key, old_val, val) if respond_to?(:onChange)

			  val
			end

			def from_Hash(hash)
				@pathData.from_Hash(hash)
			end
				
			def to_Hash(hashTable)
				@pathData.to_Hash(hashTable)
			end

			private
			
			def set_To_Attribute(group)
				@pathData.set_To_Attribute(group)
			end
				
			def get_From_Attributs(group)
				@pathEntitie = group
				@pathName = group.name
				@pathData.get_From_Attributs(group)
			end

			def createPathData
			    GN_ToolPathObjData.new
			end

		end

	end # module Paths
end  #module GNTools
