require 'sketchup'
module GNTools
  class OctoPrintDialog
	@@dialogWidth = 890
	@@dialogHeight = 820

    def initialize()
		@title = "OctoPrint Dialog"
	end
	
	def addToAxis(axis,montant)
		reponse = GNTools.octoPrint.send_gcode("M114")
		json = JSON.parse(reponse.body)
		pos = json.dig("position")
		if pos
		  positionZ = pos[axis.downcase] + montant
		  reponse = GNTools.octoPrint.send_gcode("G0 #{axis.upcase}#{positionZ}")
		end
		reponse
	end

	def subToAxis(axis,montant)
		reponse = GNTools.octoPrint.send_gcode("M114")
		json = JSON.parse(reponse.body)
		pos = json.dig("position")
		if pos
		  positionZ = pos[axis.downcase] - montant
		  reponse = GNTools.octoPrint.send_gcode("G0 #{axis.upcase}#{positionZ}")
		end
		reponse
	end
	
	def show_dialog
	  if @dialog && @dialog.visible?
		self.update_dialog
		self.update_Tab
		@dialog.set_size(@@dialogWidth,@@dialogHeight)
		dialog.center # New feature!
		@dialog.bring_to_front
	  else
		# Attach content and callbacks when showing the dialog,
		# not when creating it, to be able to use the same dialog again.
		@dialog ||= self.create_dialog
		@dialog.set_html(@@html_content) # Injecter le HTML modifié

		# when the dialog is ready update the data
		@dialog.add_action_callback("ready") { |action_context|
			self.update_dialog
#			self.update_Tab
			nil
		}
		# when the button "Accept" is press "OK"
		@dialog.add_action_callback("accept") { |action_context, value|
			GNTools.octoPrint.host = value["host"]  || ""
			GNTools.octoPrint.api_key = value["api_key"] || ""
			GNTools.octoPrint.macro1 = value["macro1"] || ""	
			GNTools.octoPrint.macro2 = value["macro2"] || ""	
			GNTools.octoPrint.macro3 = value["macro3"] || ""
			self.close_dialog
			nil
		}
		# when the button "Cancel" is press
		@dialog.add_action_callback("cancel") { |action_context, value|
			self.close_dialog
			nil
		}
					
		# when the button "Set Default" is press
		@dialog.add_action_callback("setDefault") { |action_context, value|
			GNTools.octoPrint.host = value["host"] || ""
			GNTools.octoPrint.api_key = value["api_key"] || ""		
			GNTools.octoPrint.macro1 = value["macro1"] || ""
			GNTools.octoPrint.macro2 = value["macro2"] || ""
			GNTools.octoPrint.macro3 = value["macro3"] || ""	
			GNTools.octoPrint.saveToFile()
			self.update_dialog
			nil
		}
					
		# when a new value is entered
		@dialog.add_action_callback("buttonPress") { |action_context, value, object1|
			case value
			when 1
				puts "$$Home X$$"
				GNTools.octoPrint.send_gcode("G28 X")
			when 2
				puts "$$Home Y$$"
				GNTools.octoPrint.send_gcode("G28 Y")
			when 3
				puts "$$Home Z$$"
				GNTools.octoPrint.send_gcode("G28 Z")
			when 4
				puts "$$Home All$$"
				GNTools.octoPrint.send_gcode("G28")
			when 5
				GNTools.octoPrint.jog_head(z: 100)
			when 6
				GNTools.octoPrint.jog_head(z: 10)
			when 7
				GNTools.octoPrint.jog_head(z: 1)
			when 8
				GNTools.octoPrint.jog_head(z: 0.1)
			when 9
				GNTools.octoPrint.jog_head(z: -0.1)
			when 10
				GNTools.octoPrint.jog_head(z: -1)
			when 11
				GNTools.octoPrint.jog_head(z: -10)
			when 12
				GNTools.octoPrint.jog_head(z: -100)
			when 13
				GNTools.octoPrint.jog_head(x: 100)
			when 14
				GNTools.octoPrint.jog_head(x: 10)
			when 15
				GNTools.octoPrint.jog_head(x: 1)
			when 16
				GNTools.octoPrint.jog_head(x: 0.1)
			when 17
				GNTools.octoPrint.jog_head(x: -0.1)
			when 18
				GNTools.octoPrint.jog_head(x: -1)
			when 19
				GNTools.octoPrint.jog_head(x: -10)
			when 20
				GNTools.octoPrint.jog_head(x: -100)
			when 21
				GNTools.octoPrint.jog_head(y: 100)
			when 22
				GNTools.octoPrint.jog_head(y: 10)
			when 23
				GNTools.octoPrint.jog_head(y: 1)
			when 24
				GNTools.octoPrint.jog_head(y: 0.1)
			when 25
				GNTools.octoPrint.jog_head(y: -0.1)
			when 26
				GNTools.octoPrint.jog_head(y: -1)
			when 27
				GNTools.octoPrint.jog_head(y: -10)
			when 28
				GNTools.octoPrint.jog_head(y: -100)
			when 30
				puts "$$Bouton send cliqué!$$ #{object1} 30"
				GNTools.octoPrint.send_gcodes(object1)
			when 31
				puts "$$Bouton auto connect$$"
				GNTools.octoPrint.connexion
			when 32
				puts "$$Bouton disconnect$$"
				GNTools.octoPrint.connexion(false)
			when 33 #setToCoord
				puts "$$Bouton G92 X#{object1["X"]} Y#{object1["Y"]} Z#{object1["Z"]}$$"
				GNTools.octoPrint.send_gcode("G92 X#{object1["X"]} Y#{object1["Y"]} Z#{object1["Z"]}")
			when 34 #spindleStart1
				vitesse = object1["speed"]
				puts "$$Bouton M3 S#{vitesse}$$"
				GNTools.octoPrint.send_gcode("M3 S#{vitesse}")
			when 35 #spindleStart2
				vitesse = 255 - object1["speed"]
				puts "$$Bouton M4 S#{vitesse}$$"
				GNTools.octoPrint.send_gcode("M4 S#{vitesse}")
			when 36 #spindleStop
				puts "$$Bouton M5$$"
				GNTools.octoPrint.send_gcode("M5")
			when 37 #MesureMode
				if object1
					GNTools.octoPrint.send_gcode("G21")
				else
					GNTools.octoPrint.send_gcode("G20")
				end
			when 38 #MovementStyle
				if object1
					GNTools.octoPrint.send_gcode("G91")
				else
					GNTools.octoPrint.send_gcode("G90")
				end
			else
				puts "$$Bouton inconnu : #{value}$$"
				
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
		@fileslisted = true
		html_file = File.join(PATH_UI, 'html', 'GN_OctoPrint.html') # Use external HTML
		@@html_content = File.read(html_file)
				
		plugin_dir = File.dirname(PATH_UI) # Chemin du plugin
		css_path = "file:///" + File.join(PATH_UI, 'css', 'Sketchup.css').gsub("\\", "/")
		cssStyle_path = "file:///" + File.join(PATH_UI, 'css', 'styles.css').gsub("\\", "/")
		jquery_ui_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.css').gsub("\\", "/")
		octoprint_ui_path = "file:///" + File.join(PATH_UI, 'Scripts', 'GN_OctoPrint.js').gsub("\\", "/")
		jquery_js_path = "file:///" + File.join(PATH_UI, 'js/external/jquery/','jquery.js').gsub("\\", "/")
		jquery_uijs_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.js').gsub("\\", "/")
		jquery_uiimage_path = "file:///" + File.join(PATH_UI, 'images', 'senderControl.jpg').gsub("\\", "/")
		jquery_uiimage2_path = "file:///" + File.join(PATH_UI, 'images', 'moreControls.jpg').gsub("\\", "/")
		# Modifier le HTML pour utiliser ces chemins
		@@html_content.gsub!("../css/Sketchup.css", css_path)
		@@html_content.gsub!("../css/styles.css", cssStyle_path)
		@@html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
		@@html_content.gsub!("../Scripts/GN_OctoPrint.js",octoprint_ui_path)
		@@html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
		@@html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)
		@@html_content.gsub!("../images/senderControl.jpg", jquery_uiimage_path)
		@@html_content.gsub!("../images/moreControls.jpg", jquery_uiimage2_path)
		
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
#		dialog.set_file(html_file) # Can be set here.
		dialog.center # New feature!
#		dialog.set_can_close { false }
		dialog.set_on_closed {
		  # Code to execute when the dialog is closed
		  puts "Dialog has been closed."
		  # For example, you might save the dialog's position and size:
		  @position = dialog.get_position
		  @size = dialog.get_size
		  @dialog = nil # Clear the reference to the dialog
		}
		dialog
	end
	
	def update_status
		interval = 3

		# Stocker le dernier état pour ne pas envoyer si pas de changement
		@last_status ||= {}

		timerid = UI.start_timer(interval, true) do
#		  next unless @dialog # vérifier que le dialog existe toujours
		  next false unless @dialog
		  # Construire le nouvel état
		  status_hash = {}
		  status_hash["ping"] = GNTools.octoPrint.quick_ping
		  if GNTools.octoPrint.reachable
		    @fileslisted = true
			connect_info = GNTools.octoPrint.connection_Info
			status_hash.merge!(connect_info) if connect_info

			reloadFile = false
			if status_hash["current"] && @last_status["current"] &&
			  status_hash["current"]["state"] != @last_status["current"]["state"]
			  reloadFile = true
			end
			# Comparer avec le dernier état
			if status_hash != @last_status
			  @last_status = status_hash.dup

			  # Envoyer le JSON au dialog
			  script_str = "statusDialog(\'#{JSON.generate(status_hash)}\')"
			  @dialog.execute_script(script_str)
			end
			if reloadFile
			  UI.set_cursor(632)
			  sleep 1
			  files = GNTools.octoPrint.list_files("")
			  scriptStr = "updateFiles(\'#{JSON.generate(files)}\')"
			  @dialog.execute_script(scriptStr)
			  UI.set_cursor(630)
			end
		  else
			if @fileslisted
			  scriptStr = "updateFiles(\'#{JSON.generate(nil)}\')"
			  @dialog.execute_script(scriptStr)
			end
			@fileslisted = false
		  end
		end
	end
	
	def update_dialog
		updateHash = {}
		updateHash["host"] = GNTools.octoPrint.host || ""
		updateHash["api_key"] = GNTools.octoPrint.api_key || ""
		updateHash["macro1"] = GNTools.octoPrint.macro1	|| ""
		updateHash["macro2"] = GNTools.octoPrint.macro2	|| ""	
		updateHash["macro3"] = GNTools.octoPrint.macro3 || ""
		scriptStr = "updateDialog(\'#{JSON.generate(updateHash)}\')"
		@dialog.execute_script(scriptStr)

		status_hash = {}
		status_hash["ping"] = GNTools.octoPrint.quick_ping
		connect_info = GNTools.octoPrint.connection_Info
		status_hash.merge!(connect_info) if connect_info
		# Envoyer le JSON au dialog
		script_str = "statusDialog(\'#{JSON.generate(status_hash)}\')"
		@dialog.execute_script(script_str)
		
		self.update_status
		
		files = GNTools.octoPrint.list_files("")
		scriptStr = "updateFiles(\'#{JSON.generate(files)}\')"
		@dialog.execute_script(scriptStr)
		
		newlist = self.get_ObjectList
		puts newlist
		scriptStr = "updateObjects(\'#{JSON.generate(newlist)}\')"
		@dialog.execute_script(scriptStr)

		
	end
	
	def get_ObjectList
		names = []
	    model = Sketchup.active_model
		return {} unless model

		ents = model.active_entities
		return {} unless ents
		
		ents.each do |entity|
			next unless entity.respond_to?(:name) && entity.name && !entity.name.empty?

			groupName = nil
			if defined?(Paths) && Paths.respond_to?(:isGroupObj)
				groupName = Paths::isGroupObj(entity)
			end

			if groupName
				# stocke l'entité par son nom
				names << entity.name
			end
		end

		return {"objet" => names}
	end
  end # class OctoPrintDialog
end # module GNTools