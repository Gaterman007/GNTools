require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_DefaultCNCData.rb'
require 'GNTools/Tools/GN_GCodeGenerate.rb'

module GNTools

	module Paths

		class PathObjObserver < Sketchup::EntityObserver

			def self.add_group(path_obj)
				if path_obj
					path_obj.pathEntitie.add_observer(PathObjObserver.new(path_obj))
				end
			end
		
			def initialize(path_obj)
				super()
				@path_obj = path_obj  # Garde une référence vers l'instance complète
				@group = path_obj.pathEntitie
			end

			def onChangeEntity(entity)
				if @group.valid?
#					puts "PathObjObserver.onChangeEntity #{@group} #{@path_obj.pathName}"
#					@path_obj.changed()
#				else # va passer par onEraseEntity
#					puts "PathObjObserver.onChangeEntity deleted #{@group} #{@path_obj.pathName}"
					nil
				end
			end

			def onEraseEntity(entity)
				if !@group.valid?  #ne devrait jamais etre valid car deja effacer
#					puts "PathObjObserver.onEraseEntity #{@group} #{@path_obj.pathName}"
#				else
#					puts "PathObjObserver.onEraseEntity deleted #{@group} #{@path_obj.pathName}"
					GNTools.pathObjList.delete(@path_obj.pathID)
					@path_obj = nil
				end
			end
		end

		class GN_PathObjData
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

# =========================================
# GN_PathObj
# Classe de base pour tous les objets de chemin
# =========================================
  # ==== Public Methods ====
  # initialize(group = nil)

  # Crée les données associées à l’objet
  # Doit retourner une instance de GN_PathObjData ou dérivée
  # createPathData


  # trois method principal
  #		createDynamiqueModel cree un objet sketchup group solide
  #		createGCode cree un string GCode pour l envoie au CNC
  #		createPath   cree des edges pour montré le chemin
  # createDynamiqueModel
  # Crée le modèle dynamique dans SketchUp
  # Utilise pathData et pathEntitie pour générer géométrie

  # createGCode(gCodeStr)
  # Génère le GCode pour l’objet
  # gCodeStr: string à compléter avec le code CNC

  # createPath
  # Crée la géométrie du chemin (edges, faces, etc.)
  
  # changed(create_undo = false)
  # Mise à jour du modèle après modification des données
	
	
		class PathObj
			attr_accessor :pathEntitie
			attr_accessor :pathID
#			attr_accessor :pathData

			@registered_classes = {}

			class << self
				attr_reader :registered_classes
				attr_accessor :defaultTypeKeys

				def register_class(subclass, default_hash,create_callback)
				  @registered_classes ||= {}
				  # Création du slot pour cette classe
				  @registered_classes[subclass] ||= {} 
			      @registered_classes[subclass][:defaults] = Marshal.load(Marshal.dump(default_hash))
				  @registered_classes[subclass][:create_path] = create_callback
				end

				def defaults_for(subclass)
				  entry = @registered_classes[subclass]
				  raise "Class #{subclass} not registered!" unless entry
				  entry[:defaults]
				end

				def create_pathobj(subclass, *args)
				  entry = @registered_classes[subclass]
			      raise "Class #{subclass} not registered!" unless entry
				  entry[:create_path].call(*args)
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
					  raise "Unknown PathObj type: #{t}"
					end
					result[t] = table
				  end
				  result
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
#				# ---> ICI : afficher la stack d'appel
#				puts "\n[CALL STACK]"
#				puts caller.join("\n")
#				puts "[END CALL STACK]\n"
#				@pathData.display()
			end

			# ---------- Méthodes à OVERRIDE ----------
			def createDynamiqueModel
			# chaque classe dérivée produit son visuel
				raise NotImplementedError
			end

			def self.Create(position, hash)
			# retourne un objet complet, déjà configuré
				raise NotImplementedError
			end

			def changed(create_undo = false)
			# appelé quand un param change depuis la palette UI
				raise NotImplementedError
			end

			def createGCode(gCodeStr)
			# génère le GCode de l'objet
				raise NotImplementedError
			end

			def createPath
			# construit géométriquement le toolpath dans SketchUp
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
					GNTools::Paths::PathObjObserver.add_group(self)
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

			def set_To_Attribute(group)
				@pathData.set_To_Attribute(group)
			end
				
			def get_From_Attributs(group)
				@pathEntitie = group
				@pathName = group.name
				@pathData.get_From_Attributs(group)
			end

			private

			def createPathData
			    GN_PathObjData.new
			end

		end

		class GN_PathObjDialog
		
			@@dialogWidth = 350
			@@dialogHeight = 830
			@@html_content = ""
		
			attr_accessor :tabValue
			attr_accessor :modiHash
			attr_accessor :selectionHash
			attr_accessor :selectedPaths
					
			def initialize()
				@methodTypeCombineChoices = {'Hole' => ['Inside','Outside','Pocket'],'StraitCut' => ['Ramp','Multipass','Plunge'],'Pocket' => ['Inside','Outside','Pocket'] }
				@title = "Tools Paths Settings"
				@tabValue = 0
				@newhash = PathObj.createHashTable("Hole","StraitCut","Pocket")
				@modiHash = {}
				@selectionHash = PathObj.createHashTable("Hole","StraitCut","Pocket")
				@newhash.each {|key,value| 
					@modiHash = @modiHash.merge({key => {}})
					@newhash[key].each {|key2,value| 
						@modiHash[key] = @modiHash[key].merge({key2 => @newhash[key][key2].dup})
					}
				}
				@observer = nil
				@selectedPaths = []
			end
			
			
			def resetModiHashMultiple
				@newhash.each {|key,value|
					@newhash[key].each {|key2,value| 
						@newhash[key][key2]["multiple"] = false
					}
				}
			end
						
			def showTabValue()
				if @tabValue == 0 # hole tab
				  Sketchup.status_text = "Selected tab. Hole"
				else
				  if @tabValue == 1 # Line tab
					Sketchup.status_text = "Selected tab. Line"
					  if @tabValue == 2 # Line tab
						Sketchup.status_text = "Selected tab. Shape"
					  end
				  end
				end
				tabs_changed_callback if respond_to?(:tabs_changed_callback)
			end

			def tabs_changed_callback
				if @observer != nil
					@observer.tabs_changed_callback
				end
			end

			def register_observer(observer)
				@observer = observer
			end

			
			def show_dialog
				if @dialog && @dialog.visible?
					self.update_dialog
					self.update_Tab
					@dialog.set_size(@@dialogWidth,@@dialogHeight)
					@dialog.center # New feature!
					@dialog.bring_to_front
				else
					# Attach content and callbacks when showing the dialog,
					# not when creating it, to be able to use the same dialog again.
					@dialog ||= self.create_dialog
					@dialog.set_html(@@html_content) # Injecter le HTML modifié

					self.update_Tab
					# when the dialog is ready update the data
					@dialog.add_action_callback("ready") { |action_context|
						self.update_dialog
						self.update_Tab
						nil
					}
					# when the button "Accept" is press "OK"
					@dialog.add_action_callback("accept") { |action_context, value|
						if @observer
							@observer.commitOperation = true
						end
						@dialog.close
						Sketchup.active_model.select_tool(nil)
							
					}
					# when the button "Cancel" is press
					@dialog.add_action_callback("cancel") { |action_context, value|
						if @observer
							@observer.commitOperation = false
						end
						@dialog.close
						Sketchup.active_model.select_tool(nil)
						nil
					}

					@dialog.add_action_callback("tabValue") { |action_context, value|
						@tabValue = value
						@@html_content.gsub!(/var tabIndex = \d+;/, "var tabIndex = #{@tabValue};")
						showTabValue()
						nil
					}

					
					# when the button "Set Default" is press
					@dialog.add_action_callback("apply") { |action_context, value|
						if @tabValue == 0
							GNTools::Paths.defaultHoleData.from_Hash(@modiHash[@modiHash.keys[@tabValue]])
						elsif @tabValue == 1
							@@defaultStraitCutData.from_Hash(@modiHash[@modiHash.keys[@tabValue]])
						elsif @tabValue == 2
							modiHash["Pocket"]["numOfEdge"]["Value"] = 0
							@@defaultPocketData.from_Hash(@modiHash[@modiHash.keys[@tabValue]])
						end
						nil
					}
					
					# when a new value is entered
					@dialog.add_action_callback("newValue") { |action_context, value, valueName, valueMethod|
						@modiHash[valueMethod][valueName]["Value"] = value
						@modiHash[valueMethod][valueName]["multiple"] = false
						selection = Sketchup.active_model.selection
						if selection.count() > 0
							selection.each { |ent|
								groupMethod = Paths::isGroupObj(ent)
								if groupMethod == valueMethod
 								  pathObj = GNTools.pathObjList[ent.persistent_id]
								  if value == nil
									oldValue = pathObj.getVar("#{valueName}")
									if oldValue.is_a?(String)
										value = ""
									elsif oldValue.is_a?(Numeric)
										value = 0
									else
										value = false
									end
								  end
								  pathObj.setVar("#{valueName}",value)
								  pathObj.changed()
								end
							}
						end
						nil
					}
					@dialog.set_size(@@dialogWidth,@@dialogHeight)
					@dialog.center # New feature!
					@dialog.show
				end
			end
			
			def close_dialog
				if @dialog
					@dialog.set_can_close { true }
					@dialog.close
				end
			end
			
			def create_dialog
				html_file = File.join(PATH_UI, 'html', 'CombinePath.html') # Use external HTML
				@@html_content = File.read(html_file)
				
				plugin_dir = File.dirname(PATH_UI) # Chemin du plugin
				css_path = "file:///" + File.join(PATH_UI, 'css', 'Sketchup.css').gsub("\\", "/")
				jquery_ui_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.css').gsub("\\", "/")
				jquery_js_path = "file:///" + File.join(PATH_UI, 'js/external/jquery/','jquery.js').gsub("\\", "/")
				jquery_uijs_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.js').gsub("\\", "/")

				# Modifier le HTML pour utiliser ces chemins
				@@html_content.gsub!("../css/Sketchup.css", css_path)
				@@html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
				@@html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
				@@html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)

				@@html_content.gsub!(/var tabIndex = \d+;/, "var tabIndex = #{@tabValue};")

				@@html_content.gsub!('<li><a href="#tabs-1" id = "Hole">Trou</a></li>', '<li><a href="#tabs-1" id = "Hole">'+GNTools.traduire("Hole") +'</a></li>')
				@@html_content.gsub!('<li><a href="#tabs-2" id = "StraitCut">Ligne</a></li>', '<li><a href="#tabs-2" id = "StraitCut">'+GNTools.traduire("Line")+'</a></li>')
				@@html_content.gsub!('<li><a href="#tabs-3" id = "Pocket">Forme</a></li>', '<li><a href="#tabs-3" id = "Pocket">'+GNTools.traduire("Shape")+'</a></li>')



				
				options = {
				  :dialog_title => @title,
				  :resizable => true,
				  :width => 250,
				  :height => 250,
				  :preferences_key => "example.htmldialog.materialinspector",
				  :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
				}
				dialog = UI::HtmlDialog.new(options)
				dialog.set_html(@@html_content) # Injecter le HTML modifié
#				dialog.set_file(html_file) # Can be set here.
				dialog.center # New feature!
				dialog.set_can_close { false }
				dialog
			end

			def update_dialog
				showTabValue()

				DrillBits.drillbitTbl.each { |oneDrill|
					scriptStr = "addRowToTable(\'#{oneDrill.to_Json()}\')"
					@dialog.execute_script(scriptStr)
				}
				@dialog.execute_script("updateTable()")	
				
#				puts @modiHash.inspect

				scriptStr = "updateMethod3(\'#{JSON.generate(@modiHash)}\')"
				@dialog.execute_script(scriptStr)
			end

			#		update numOfEdge  Pocket.numOfEdge  et nbdesegment_Hole Hole.nbdesegment
			def update_info
				scriptStr = "updateMethod4(\'#{JSON.generate(@modiHash)}\')"
				@dialog.execute_script(scriptStr)
			end
			
			def update_Tab
				scriptStr = "updateTab(\'{\"tabIndex\": #{@tabValue}}\')"
				@dialog.execute_script(scriptStr)
			end

		end
		

		class GN_PathObjTool
			@@CombineDia = nil

			def initialize
				# Initialise le dialog une seule fois
				@@CombineDia ||= GN_PathObjDialog.new
			end		
			
			def self.combineDia
				@@CombineDia
			end
			
			def commitOperation=(value)
				@commitOperation = value
			end
			
			def activate
				@mouse_pos_down = ORIGIN
				@mouse_ip = Sketchup::InputPoint.new
				@picked_first_ip = Sketchup::InputPoint.new
				@dragged = false
				@mouseButton = false
				@state = 0
				@tabsValue = 0
				@pocketCreated = false
				@loopForPocket = []
				@@CombineDia.selectedPaths = []
				@commitOperation = true
				model = Sketchup.active_model
				sel = Sketchup.active_model.selection
				if (sel.count > 0) then
					# some selected
					allpathsSelected = sel.select { |selectedEntity| Paths::isGroupObj(selectedEntity) }
					@@CombineDia.selectedPaths = allpathsSelected.map { |selectedEntity|  GNTools::pathObjList[selectedEntity.persistent_id].dup}
					if sel.count == 1
						groupName = Paths::isGroupObj(sel[0])
						@tabsValue = 0
						if groupName == "Hole"
							@tabsValue = 0
							@@CombineDia.tabValue = 0
						elsif groupName == "StraitCut"
							@tabsValue = 1
							@@CombineDia.tabValue = 1
						elsif groupName == "Pocket"
							@tabsValue = 2
							@@CombineDia.tabValue = 2
						end
					end
					# show the values that are the same for all selection (seperate for hole,straitcut,pocket)
					Sketchup.active_model.start_operation(GNTools::traduire("Modi Path"), true)
				else
					Sketchup.active_model.start_operation(GNTools::traduire("Add Path"), true)
					# none selected
					#showDefaultValue
				end
				@@CombineDia.register_observer(self)
				@@CombineDia.show_dialog
			end
			
			def deactivate(view)
				if @loopForPocket.size > 0
					@loopForPocket.each do |removeEdge|
						Sketchup.active_model.entities.erase_entities(removeEdge)
					end
				end
				@loopForPocket = []
				@@CombineDia.selectedPaths.clear
				@@CombineDia.selectedPaths = []
				view.invalidate
				@@CombineDia.close_dialog
				if @commitOperation
					Sketchup.active_model.commit_operation
				else
					Sketchup.active_model.abort_operation
				end
			end
			
			def resume(view)
				view.invalidate
			end

			def suspend(view)
				view.invalidate
			end

			def onCancel(reason, view)
				reset_tool
				view.invalidate
			end
			
			def onLButtonDown(flags, x, y, view)
				if @tabsValue == 0
					@mouseButton = true
					@mouse_ip.pick(view, x, y)
				elsif @tabsValue == 1
					@mouseButton = true
					# Track where in screen space mouse is pressed down.
					@mouse_down = Geom::Point3d.new(x, y)
					if @state == 0			
						@picked_first_ip.pick(view, x, y)
						@state = 1			
					else 
						if @state == 1
							@mouse_ip.pick(view, x, y, @picked_first_ip)
							@state = 2
						end
					end
					view.invalidate		
				elsif @tabsValue == 2
					@mouseButton = true
					# Track where in screen space mouse is pressed down.
					@mouse_down = Geom::Point3d.new(x, y)
					if @state == 0
						@picked_first_ip.pick(view, x, y)
						@state = 1
					else 
						if @state == 1
							@mouse_ip.pick(view, x, y, @picked_first_ip)
							@state = 2
						end
					end
#					update_ui
					view.invalidate		
				end
			end
			
			def onMouseMove(flags, x, y, view)
				if @tabsValue == 0
					if @mouseButton
						# Lock inferences to the cursor position
						@mouse_ip.pick(view, x, y)
						@mouse_ip.draw(view)
					else
						@mouse_ip.pick(view, x, y)
						view.invalidate
					end
				elsif @tabsValue == 1
					if @mouseButton
						if (!@dragged) && (@mouse_down.distance([x, y]) > 10)
							@dragged = true
						end
					end
					if @picked_first_ip.valid?
						@mouse_ip.pick(view, x, y, @picked_first_ip)
					else
						@mouse_ip.pick(view, x, y)
					end

					view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
					view.invalidate
				elsif @tabsValue == 2
					if @mouseButton
						if (!@dragged) && (@mouse_down.distance([x, y]) > 10)
							@dragged = true
						end
					end
					if @picked_first_ip.valid?
						@mouse_ip.pick(view, x, y, @picked_first_ip)
					else
						@mouse_ip.pick(view, x, y)
					end
					view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
					view.invalidate
#					update_ui
				end
			end
			
			def onLButtonUp(flags, x, y, view)
				if @tabsValue == 0
					@mouseButton = false
					@mouse_ip.pick(view, x, y)
					model = Sketchup.active_model
					pathInstance = PathObj::create_pathobj("Hole",@mouse_ip.position,@@CombineDia.modiHash["Hole"])
					model.selection.clear
					model.selection.add(pathInstance.pathEntitie)
				elsif @tabsValue == 1
					if @state == 2
						create_straitCut
						@state == 1
						@picked_first_ip.copy! @mouse_ip
					end
					if @state == 1
						if @dragged
							create_straitCut
							@state == 1
							@picked_first_ip.copy! @mouse_ip
						end
					end
					@mouseButton = false
					@dragged = false
					view.invalidate
				elsif @tabsValue == 2
					if @state == 2	# mouse up line crated by 
						@mouse_ip.pick(view, x, y)
						@loopForPocket.concat(Sketchup.active_model.entities.add_edges(@picked_first_ip.position,@mouse_ip.position))
						@state == 1
						@picked_first_ip.copy! @mouse_ip
						if @loopForPocket.size > 2
							if @mouse_ip.position == @loopForPocket[0].start.position
								create_Pocket
								@state == 0
								@picked_first_ip.clear
							end
						end
						@@CombineDia.update_info
					end
					if @state == 1
						if @dragged  #mouse up line created by dragging
							@mouse_ip.pick(view, x, y)
							@loopForPocket.concat(Sketchup.active_model.entities.add_edges(@picked_first_ip.position,@mouse_ip.position))
							@state == 1
							@picked_first_ip.copy! @mouse_ip
							if @loopForPocket.size > 2
								if @mouse_ip.position == @loopForPocket[0].start.position
									create_Pocket
									@state == 0
									@picked_first_ip.clear
								end
							end
							@@CombineDia.update_info
						end
					end
					@mouseButton = false
					@dragged = false
#					update_ui
					view.invalidate
				end
			end
			
			def create_Pocket
				model = Sketchup.active_model
				pathInstance = PathObj::create_pathobj("Pocket",@loopForPocket,@@CombineDia.modiHash["Pocket"])
				model.selection.clear
				model.selection.add(pathInstance.pathEntitie)
				@pocketCreated = true
			end
			
			def create_straitCut
				model = Sketchup.active_model
				pathInstance = PathObj::create_pathobj("StraitCut",picked_points,@@CombineDia.modiHash["StraitCut"])
				model.selection.clear
				model.selection.add(pathInstance.pathEntitie)
			end
			
			def onSetCursor
				UI.set_cursor(632)
			end

			def draw(view)
				if @tabsValue == 1
					draw_preview(view)
				elsif @tabsValue == 2
					draw_preview(view)
				end
				@mouse_ip.draw(view) if @mouse_ip.display?
			end

			def draw_preview(view)
				points = picked_points
				return unless points.size == 2
				view.set_color_from_line(*points)
				view.line_width = 1
	#      view.line_stipple = '-'
				view.line_stipple = '_'      
				view.draw(GL_LINES, points)
			end
			
			def picked_points
			  points = []
			  points << @picked_first_ip.position if @picked_first_ip.valid?
			  points << @mouse_ip.position if @mouse_ip.valid?
			  points
			end


			def reset_tool
			end

			def tabs_changed_callback
				if @tabsValue != @@CombineDia.tabValue
					@tabsValue = @@CombineDia.tabValue
					@state = 0
					if @loopForPocket.size > 0
						@loopForPocket.each do |removeEdge|
							Sketchup.active_model.entities.erase_entities(removeEdge)
						end
					end
					@loopForPocket = []
				end
			end
		end
	end # module Paths
end  #module GNTools
