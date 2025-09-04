require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_DefaultCNCData.rb'
require 'GNTools/Tools/GN_Hole.rb'
require 'GNTools/Tools/GN_StraitCut.rb'
require 'GNTools/Tools/GN_Pocket.rb'

module GNTools

	module Paths


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
			
		#GNTools::Paths.createFromEnt(ent)
		def self.createFromEnt(ent)
			groupName = isGroupObj(ent)
			case groupName
			when "Hole"
				pathObj = Paths::Hole.new(ent)
				return pathObj
			when "StraitCut"
				pathObj = Paths::StraitCut.new(ent)
				return pathObj
			when "Pocket"
				pathObj = Paths::Pocket.new(ent)
				return pathObj
			end
			return nil
		end

		class CombineDialog
		
			@@dialogWidth = 350
			@@dialogHeight = 830
		
			@@defaultHoleData = Paths::Hole.new(0)
			@@defaultStraitCutData = Paths::StraitCut.new(0)
			@@defaultPocketData = Paths::Pocket.new(0)

			@@html_content = ""
		
			attr_accessor :tabValue
			attr_accessor :modiHash
			attr_accessor :selectionHash
			attr_accessor :selectedPaths

		    # Getter (lecture)
		    def self.defaultHoleData
			  @@defaultHoleData
		    end

		    # Getter (lecture)
		    def self.defaultStraitCutData
			  @@defaultStraitCutData
		    end

		    # Getter (lecture)
		    def self.defaultPocketData
			  @@defaultPocketData
		    end

					
			def initialize()
				@methodTypeCombineChoices = {'Hole' => ['Inside','Outside','Pocket'],'StraitCut' => ['Ramp','Multipass','Plunge'],'Pocket' => ['Inside','Outside','Pocket'] }
				@title = "Tools Settings"
				@tabValue = 0
				@newhash = createHashTable()
				@modiHash = {}
				@selectionHash = createHashTable()
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
							@@defaultHoleData.from_Hash(@modiHash[@modiHash.keys[@tabValue]])
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
								  pathObj[valueName] = value
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

			def createHashTable()
				holeHashTable = {}
				straitCutHashTable = {}
				pocketHashTable = {}
				@@defaultHoleData.to_Hash(holeHashTable)
				@@defaultStraitCutData.to_Hash(straitCutHashTable)
				@@defaultPocketData.to_Hash(pocketHashTable)
				@newhash = {"Hole" => holeHashTable,"StraitCut" => straitCutHashTable,"Pocket" => pocketHashTable}
				@newhash
			end
			
			def update_dialog
				showTabValue()

				DrillBits.drillbitTbl.each { |oneDrill|
					scriptStr = "addRowToTable(\'#{oneDrill.to_Json()}\')"
					@dialog.execute_script(scriptStr)
				}
				@dialog.execute_script("updateTable()")	

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
		

		class CombineTool


			@@CombineDia = CombineDialog.new()

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
					pathInstance = Paths::Hole.Create(@mouse_ip.position,@@CombineDia.modiHash["Hole"])
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
							puts "@loopForPocket.size %d" % @loopForPocket.size
							puts @mouse_ip.position , @loopForPocket[0].start.position
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
								puts "@loopForPocket.size %d" % @loopForPocket.size
								puts @mouse_ip.position , @loopForPocket[0].start.position
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
				pathInstance = Paths::Pocket.CreateFromLoop(@loopForPocket,@@CombineDia.modiHash["Pocket"])
				model.selection.clear
				model.selection.add(pathInstance.pathEntitie)
				@pocketCreated = true
			end
			
			def create_straitCut
				model = Sketchup.active_model
				pathInstance = Paths::StraitCut.Create(picked_points,@@CombineDia.modiHash["StraitCut"])
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
