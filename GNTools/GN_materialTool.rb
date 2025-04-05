require 'sketchup.rb'
require 'json'

module GNTools

	@materialList = {}

	def self.materialList
		@materialList
	end

	class MaterialDialog

		def initialize(tool)
			@tool = tool
			@title = "Material Settings"
			
			@savedData = [
			  @tool.material_type.dup,
			  @tool.safeHeight.to_f,
			  @tool.material_width.to_f,
			  @tool.material_thickness.to_f,
			  @tool.material_depth.to_f
			]			

			@newData = [
			  @tool.material_type.dup,
			  @tool.safeHeight.to_f,
			  @tool.material_width.to_f,
			  @tool.material_thickness.to_f,
			  @tool.material_depth.to_f
			]
						
		end
	
		def show_dialog
			if @dialog && @dialog.visible?
				self.update_dialog
				@dialog.bring_to_front
			else
				# Attach content and callbacks when showing the dialog,
				# not when creating it, to be able to use the same dialog again.
				@dialog ||= self.create_dialog
				@dialog.add_action_callback("ready") { |action_context|
					self.update_dialog
					nil
				}
				# set to model only
				@dialog.add_action_callback("accept") { |action_context, value|
						@tool.material_type = @newData[0]
						@tool.safeHeight = @newData[1]
						@tool.setToMaterial
					self.close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("cancel") { |action_context, value|
					self.close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("newValue") { |action_context, valueName, value|
					if valueName == "material_type"
						@newData[0] = value["material_type"]
					elsif valueName == "safeHeight"
						@newData[1] = value["safeHeight"]
					end
					nil
				}
				@dialog.show
			end
			
		end

		def create_dialog
			html_file = File.join(__dir__, 'html', 'CNC_Material.html') # Use external HTML
			@@html_content = File.read(html_file)
			
			plugin_dir = File.dirname(__FILE__) # Chemin du plugin
			css_path = "file:///" + File.join(plugin_dir, 'css', 'Sketchup.css').gsub("\\", "/")
			jquery_ui_path = "file:///" + File.join(plugin_dir, 'js', 'jquery-ui.css').gsub("\\", "/")
			jquery_js_path = "file:///" + File.join(plugin_dir, 'js/external/jquery/','jquery.js').gsub("\\", "/")
			jquery_uijs_path = "file:///" + File.join(plugin_dir, 'js', 'jquery-ui.js').gsub("\\", "/")

			# Modifier le HTML pour utiliser ces chemins
			@@html_content.gsub!("../css/Sketchup.css", css_path)
			@@html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
			@@html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
			@@html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)
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
			jsonStr = JSON.generate({
				'material_type' => @tool.material_type,
				'safeHeight' => @tool.safeHeight,
				'width' => @tool.material_width,
				'height' => @tool.material_thickness,
				'depth' => @tool.material_depth,
			})
			scriptStr = "updateDialog(\'#{jsonStr}\')"
			@dialog.execute_script(scriptStr)
		end
		
		def close_dialog
			if @dialog
				@dialog.set_can_close { true }
				@dialog.close
			end
		end
		
	end
	
	class MaterialTool
	
		attr_accessor :material_type
		attr_accessor :safeHeight
		attr_accessor :material_width
		attr_accessor :material_thickness
		attr_accessor :material_depth
		attr_accessor :material

		def initialize
			@dictionaryName = "Material"
			@material_type = "Acrylic"
			@material = nil
			@safeHeight = 5
			@dialogMaterial = nil
			@material_width = 0.0
			@material_thickness = 0.0
			@material_depth = 0.0
		end
		
		def activate			# Appelée quand l’outil est activé (via Sketchup.active_model.tools.push_tool(...))
			model = Sketchup.active_model
			selection = Sketchup.active_model.selection
			if @material == nil
				if (selection.count > 0) then
					groups = selection.grep(Sketchup::Group)
					puts groups.count
					groups.each do |group| 
						puts group.manifold?
					end
					if groups.count == 1 && groups[0].manifold?
						@material =	groups[0]
						@material.name = "CNC Material"
						@material.set_attribute( @dictionaryName,"safeHeight", @safeHeight )
						@material.set_attribute( @dictionaryName,"material_type",@material_type )
						boundingBox = @material.bounds
						@material_width = boundingBox.width
						@material_thickness = boundingBox.depth
						@material_depth = boundingBox.height
					end
				end
			else
				@safeHeight = @material.get_attribute( @dictionaryName,"safeHeight" )
				@material_type = @material.get_attribute( @dictionaryName,"material_type" )
				boundingBox = @material.bounds
				@material_width = boundingBox.width
				@material_thickness = boundingBox.depth
				@material_depth = boundingBox.height
			end
			@dialogMaterial = MaterialDialog.new(self)
			@dialogMaterial.show_dialog()
		end

		def deactivate(view)	# Appelée quand un autre outil prend le relai
			@dialogMaterial.close_dialog()
		end

		def resume(view)		# Gèrent les pauses d’outils, par ex. si on ouvre une boîte de dialogue
			view.invalidate
		end

		def suspend(view)		# Gèrent les pauses d’outils, par ex. si on ouvre une boîte de dialogue
			view.invalidate
		end

		def onCancel(reason, view)
			if reason == 0		# L’utilisateur a pressé Échap
#				puts "L'utilisateur a appuyé sur Échap"
				Sketchup.active_model.tools.pop_tool
			elsif reason == 1	# L'outil a été réactivé
				nil
			elsif reason == 2	# Un autre outil a été activé
				nil
			end
			view.invalidate
		end
		
		def onLButtonDown(flags, x, y, view)		# Clic souris
		end
		
		def onMouseMove(flags, x, y, view)			# Détection de mouvement
		end
		
		def onLButtonUp(flags, x, y, view)			# Clic souris
		end

		def onSetCursor
			UI.set_cursor(632)						# Permet de définir un curseur personnalisé (632 = flèche par défaut)
		end
		
		def setToMaterial
			@material.set_attribute( @dictionaryName,"safeHeight", @safeHeight )
			@material.set_attribute( @dictionaryName,"material_type",@material_type )
		end
	end

end #module GNTools