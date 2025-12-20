require 'sketchup.rb'
require 'json'
#require 'GNTools/Tools/GN_DefaultCNCData.rb'
#require 'GNTools/Tools/GN_GCodeGenerate.rb'

module GNTools

	module Paths

		class ToolPathObjObserver < Sketchup::EntityObserver

			def self.add_group(path_obj)
				if path_obj
					path_obj.pathEntitie.add_observer(ToolPathObjObserver.new(path_obj))
				end
			end
		
			def initialize(path_obj)
				super()
				@path_obj = path_obj  # Garde une référence vers l'instance complète
				@group = path_obj.pathEntitie
			end

			def onChangeEntity(entity)
				if @group.valid?
#					puts "ToolPathObjObserver.onChangeEntity #{@group} #{@path_obj.pathName}"
#					@path_obj.changed()
#				else # va passer par onEraseEntity
#					puts "ToolPathObjObserver.onChangeEntity deleted #{@group} #{@path_obj.pathName}"
					nil
				end
			end

			def onEraseEntity(entity)
				if !@group.valid?  #ne devrait jamais etre valid car deja effacer
#					puts "ToolPathObjObserver.onEraseEntity #{@group} #{@path_obj.pathName}"
#				else
#					puts "ToolPathObjObserver.onEraseEntity deleted #{@group} #{@path_obj.pathName}"
					GNTools.pathObjList.delete(@path_obj.pathID)
					@path_obj = nil
				end
			end
		end

		class LoopFace

		  attr_accessor :pfaces_vertices
		  attr_accessor :pfaces_normal

		  def initialize(faces = nil)
			@pfaces_vertices = []
			@pfaces_normal = []

			if faces
			  faces.each do |face|
				face_vertices = []
				face.outer_loop.vertices.each do |vertex|
				  face_vertices << vertex.position
				end
				@pfaces_vertices << face_vertices
				@pfaces_normal << face.normal
			  end
			end

			# Sous-modules internes
			@edge_offsetter   = EdgeOffsetter.new(self)
			@edge_intersector = EdgeIntersector.new(self)
			@loop_rebuilder   = LoopRebuilder.new(self)
		  end

		  # ------------------------------
		  # INTERFACE PUBLIQUE → inchangée
		  # ------------------------------
		  def deplacer(offset_distance)
			self.deplacer_arete(offset_distance)
		  end

		  private
		  
		  def deplacer_arete(offset_distance)
			loop_arrays = []

			@pfaces_vertices.each_with_index do |pface, face_index|
			  # 1. Décalage des arêtes
			  moved_lines, edge_vectors = @edge_offsetter.process(pface, face_index, offset_distance)

			  # 2. Intersections & concavité
			  new_edges = @edge_intersector.process(moved_lines, edge_vectors)

			  # 3. Reconstruction des loops
			  loop_array = @loop_rebuilder.process(new_edges, face_index)
			  loop_arrays << loop_array
			end

			loop_arrays
		  end

		  # ========================================================
		  #  SOUS-CLASSE 1 : EdgeOffsetter
		  # ========================================================
		  class EdgeOffsetter
			def initialize(parent)
			  @parent = parent
			end

			def process(pface, face_index, offset_distance)
			  moved_lines = []
			  edge_vectors = []

			  pface.each_with_index do |start_pt, index|
				end_pt = pface[(index + 1) % pface.count]

				# Vecteur directionnel
				edge_vector = Geom::Vector3d.new(end_pt - start_pt)
				edge_vectors << edge_vector

				normal = @parent.pfaces_normal[face_index]

				# Décalage perpendiculaire
				offset_vector = normal.cross(edge_vector.normalize)
				offset_vector.length = -offset_distance

				new_start = start_pt + offset_vector
				new_end   = end_pt   + offset_vector

				moved_lines << [new_start, new_end]
			  end

			  [moved_lines, edge_vectors]
			end
		  end

		  # ========================================================
		  #  SOUS-CLASSE 2 : EdgeIntersector
		  # ========================================================
		  class EdgeIntersector
			def initialize(parent)
			  @parent = parent
			end

			def process(moved_lines, edge_vectors)
			  new_edges = []
			  inverse_edge = []

			  moved_lines.each_with_index do |line, i|
				next_line = moved_lines[(i + 1) % moved_lines.size]
				prev_line = moved_lines[(i - 1) % moved_lines.size]

				# Intersection début
				if line[0] != prev_line[1]
				  intersection_start = Geom.intersect_line_line(line, prev_line)
				else
				  intersection_start = line[0]
				end

				# Intersection fin
				if line[1] != next_line[0]
				  intersection_end = Geom.intersect_line_line(line, next_line)
				else
				  intersection_end = line[1]
				end

				if (intersection_end - intersection_start).normalize != edge_vectors[i].normalize
				  inverse_edge << i
				else
				  new_edges << [intersection_start, intersection_end]
				end
			  end

			  concavetest(new_edges)
			  new_edges
			end

			# --------------------------------------------------------
			# copie exacte de ton concavetest
			# --------------------------------------------------------
			def concavetest(new_edges)
			  index = 0
			  while index < new_edges.size
				edge_check = new_edges[index]
				index2 = index + 1

				while index2 < new_edges.size
				  other_edge = new_edges[index2]
				  intersection = Geom.intersect_line_line(edge_check, other_edge)

				  if intersection
					if pointOnEdge(edge_check, intersection) && pointOnEdge(other_edge, intersection)

					  new_edges.delete_at(index)
					  new_edges.insert(index, [edge_check[0], intersection], [intersection, edge_check[1]])

					  new_edges.delete_at(index2 + 1)
					  new_edges.insert(index2 + 1, [other_edge[0], intersection], [intersection, other_edge[1]])
					end
				  end

				  index2 += 1
				end

				index += 1
			  end
			end

			def pointOnEdge(edge, intersection)
			  intersect_edge_vector = (edge[1] - intersection)
			  intersect_edge_vector_length = intersect_edge_vector.length

			  edge_vector = (edge[1] - edge[0])

			  if (intersect_edge_vector.normalize == edge_vector.normalize)
				if intersect_edge_vector_length > 0 && intersect_edge_vector_length < edge_vector.length
				  return true
				end
			  end
			  false
			end
		  end

		  # ========================================================
		  #  SOUS-CLASSE 3 : LoopRebuilder
		  # ========================================================
		  class LoopRebuilder
			def initialize(parent)
			  @parent = parent
			end

			def process(new_edges, face_index)
			  @loop_array = []
			  loop = []

			  new_edges.each do |edge|
				loop << edge[0]
			  end

			  original_direction = loop_direction(@parent.pfaces_vertices[face_index])

			  @loop_array << get_loop_recursif(loop)

			  index_loop = 0
			  while index_loop < @loop_array.size
				if @loop_array[index_loop].size > 0
				  loop_direction_val = loop_direction(@loop_array[index_loop])

				  if (original_direction > 0) != (loop_direction_val > 0)
					@loop_array.delete_at(index_loop)
				  else
					index_loop += 1
				  end
				else
				  index_loop += 1
				end
			  end

			  @loop_array
			end
		
			private

			def get_loop_recursif(loop_recur)
			  index_loop = 0
			  while index_loop < loop_recur.size
				point = loop_recur[index_loop]

				if loop_recur.count(point) > 1
				  loop_index = loop_recur.each_index.select { |i| loop_recur[i] == point }

				  if loop_index.size == 2
					sliced_array = loop_recur.slice!(loop_index.min, (loop_index.max - loop_index.min))
					@loop_array << get_loop_recursif(sliced_array)
				  else
					puts "grandeur est plus grand que 2 %d" % loop_index.size
				  end

				  index_loop = 0
				else
				  index_loop += 1
				end
			  end
			  loop_recur
			end

			def loop_direction(old_edges)
			  sum_direction = 0
			  (0..old_edges.size).each do |i|
				edge1 = old_edges[(i) % old_edges.size]
				edge2 = old_edges[(i + 1) % old_edges.size]
				edge3 = old_edges[(i + 2) % old_edges.size]

				sum_direction += (edge2[0] - edge1[0]) * (edge3[1] - edge1[1]) -
								 (edge2[1] - edge1[1]) * (edge3[0] - edge1[0])
			  end
			  sum_direction
			end
		  end
		end

		class TransformPoint

		  # Retourne la transformation globale cumulée d'une entité
		  def self.getGlobalTransform(entity)
			transformation = Geom::Transformation.new
			parent = entity

			while parent
			  case parent
			  when Sketchup::Group, Sketchup::ComponentInstance
				transformation *= parent.transformation
				parent = parent.parent
			  when Sketchup::ComponentDefinition
				# Prendre la première instance si elle existe
				parent = parent.instances.first
			  else
				break
			  end
			end

			transformation
		  end

		  # Retourne un point transformé dans le repère global
		  # Ne modifie pas le point original
		  def self.getGlobalPoint(entity, point)
			point.transform(getGlobalTransform(entity))
		  end

		  # Modifie directement le point pour qu'il soit global
		  def self.setGlobal(entity, point)
			point.transform!(getGlobalTransform(entity))
		  end

		  # Ramène un point global dans le repère local d'une entité
		  def self.setLocal(entity, point)
			inverse = getGlobalTransform(entity).inverse
			point.transform!(inverse)
		  end

		end


		@@groupobj = {
			"Hole" => "Hole",
			"StraitCut" => "StraitCut",
			"Pocket" => "Pocket"
		}


		def self.loadPaths
			model = Sketchup.active_model
			model.entities.each {|ent|
				recursiveLoadPaths(ent)
			}
			nil
		end

		def self.recursiveLoadPaths(ent)
			newPath = createFromEnt(ent)
			if newPath == nil
				if ent.is_a?Sketchup::Group
					ent.entities.each { |entRecusive|
						recursiveLoadPaths(entRecusive)
					}
				end
			end
		end

		def self.isGroupObj(ent)
			groupObjName = nil
			if ent.typename == "Group"
				if ent.attribute_dictionaries  != nil
					if (ent.attribute_dictionaries.count == 1)
						ent.attribute_dictionaries.each {|dictionary| 
							groupObjName = dictionary.name
						}
					end
				end
			end
			if (@@groupobj.has_key?(groupObjName))
				return groupObjName
			else
				return nil
			end
		end # isGroupObj
		
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
				@newhash = GN_ToolPathObj.createHashTable("Hole","StraitCut","Pocket")
				@modiHash = {}
				@selectionHash = GN_ToolPathObj.createHashTable("Hole","StraitCut","Pocket")
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
				jquery_uiscript_path = "file:///" + File.join(PATH_UI, 'Scripts', 'GN_ToolPathDialog.js').gsub("\\", "/")
				# Modifier le HTML pour utiliser ces chemins
				@@html_content.gsub!("../css/Sketchup.css", css_path)
				@@html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
				@@html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
				@@html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)
				@@html_content.gsub!("../Scripts/GN_ToolPathDialog.js", jquery_uiscript_path)

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
					pathInstance = GN_ToolPathObj::create_pathobj("Hole",@mouse_ip.position,@@CombineDia.modiHash["Hole"])
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
				pathInstance = GN_ToolPathObj::create_pathobj("Pocket",@loopForPocket,@@CombineDia.modiHash["Pocket"])
				model.selection.clear
				model.selection.add(pathInstance.pathEntitie)
				@pocketCreated = true
			end
			
			def create_straitCut
				model = Sketchup.active_model
				pathInstance = GN_ToolPathObj::create_pathobj("StraitCut",picked_points,@@CombineDia.modiHash["StraitCut"])
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
		
		def self.createFromEnt(ent)
			groupName = isGroupObj(ent)
			if groupName
				pathObj = GN_ToolPathObj::create_newobj(groupName,ent)
			end
			return pathObj
		end
		
	end # module Paths
end  #module GNTools
