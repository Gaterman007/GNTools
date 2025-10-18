require 'sketchup'
module GNTools
  class OctoPrintDialog
	@@dialogWidth = 890
	@@dialogHeight = 820

    def initialize()
		@title = "OctoPrint Dialog"
		@printerPaused = false
	end
	
	def show_dialog
	  GNTools.octoPrint.add_observer do |event, data|
      case event
		when :print_started
			puts "UI: impression démarrée -> #{data}"
		when :joghead
			puts "UI: joghead #{data.code} #{data.body}"
		when :upload
			puts "upload #{data.code} #{data.body}"
		when :download
			if data.code == "200"
				File.open(data["pathname"], "wb") { |f| f.write(data.body) }
			end
			puts "download #{data["filename"]} #{data.code}"
		when :start_print
			puts "start_print #{data.code} #{data.body}"
		when :delete_file
			nil
#			puts "delete_file #{data.code} #{data.body}"
		when :GCodeSend
			nil
#			puts "GCodeSend #{data.code} #{data.body}"
		when :upload_string
			nil
#			puts "upload_string #{data.code} #{data.body}"
		when :download_string
			puts "download_string #{data.code} #{data.body}"
		when :pause_print
			puts "pause_print"
		when :resume_print
			puts "resume_print"
		when :cancel_print
			puts "cancel_print"
		when :print_status
			puts "print_status #{data.code} #{data.body}"
		when :connection_info
			nil
#			puts "connection_info #{data.code} #{data.body}"
		when :connection
			puts "connection"
		when :control_print
			puts "control_print #{data.code} #{data.body}"
		when :printer_status
			puts "printer_status #{data.code} #{data.body}"
		when :list_files
			nil
#			puts "list_files #{data.code}"
		when :ping
			puts "ping #{data.code}: #{data.body}"
		when :reachable_changed
			update_dialog
			update_connectionInfo
			puts "reachable_changed #{data}"
		when :login
			nil
#			puts "login #{data.code} #{data.body}"
		when :closeSocket
			puts "closeSocket"
		when :handle_message
			if data.has_key?("event")
				type    = data["event"]["type"]
				payload = data["event"]["payload"] || {}
				case type
				  when "Connected"
					puts "🔌 Imprimante connectée"
				  when "Disconnected"
					puts "❌ Imprimante déconnectée"
				  when "PrintStarted"
					puts "▶️ Impression démarrée: #{payload['name']}"
				  when "PrintDone"
					puts "✅ Impression terminée: #{payload['name']}"
				  when "PrintFailed"
					puts "⚠️ Impression échouée: #{payload['name']}"
				  when "UpdatedFiles"
#					puts "📂 Fichiers mis à jour"
					update_fileslist
				  when "PrinterStateChanged"
#					puts "📩 Event: #{type} #{payload['error']}"
					update_connectionInfo
				  when "Error"
					puts "💥 Erreur: #{payload['error']}"
				  when "PositionUpdate"
					puts "📍 Position: #{payload["x"]},#{payload["y"]},#{payload["z"]}"
					update_position(payload["x"],payload["y"],payload["z"])
				  when "FirmwareData"
					nil
#				    puts "#{payload["name"]}"
#				    puts "FirmwareData #{JSON.pretty_generate(payload)}"
				  when "plugin_firmware_check_warning"
					nil
				  when "FileAdded"
					nil
				  when "MetadataAnalysisStarted"
				    nil
				  when "Upload"
				    nil
				  when "MetadataAnalysisFinished"
				    nil
				  when "FileRemoved"
				    nil
				else
				  puts "📩 Event: #{type}  (#{JSON.pretty_generate(payload)})"
				end
			elsif data.has_key?("connected")
				puts "✅ Connecté au serveur OctoPrint, version #{data["connected"]["display_version"]}"
			elsif data.has_key?("history")
				nil
#				puts "⚠️ History:"
	#		    puts "⚠️ History: #{JSON.pretty_generate(data)}"
			elsif data.has_key?("plugin")
				puts "🌡 Plugin: #{data["plugin"]}, données: #{data["data"]}"
			elsif data.has_key?("timelapse")
				nil
#				puts "⚠️ Timelapse: #{JSON.pretty_generate(data)}"
			else
				puts "⚠️ Inconnu: #{JSON.pretty_generate(data)}"
			end
		end
	  end
	  if @dialog && @dialog.visible?
		self.update_all
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
			self.update_all
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
					
		@dialog.add_action_callback("newValue") { |action_context, value, object1|
			case value
			when "host"
				GNTools.octoPrint.host = object1["host"] || ""
				GNTools.octoPrint.closeWebSocket
				GNTools.octoPrint.login_passive
				puts "host was changed"
			when "api_key"
				GNTools.octoPrint.api_key = object1["api_key"] || ""
				GNTools.octoPrint.closeWebSocket
				GNTools.octoPrint.login_passive
				puts "api key was changed"
			end
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
			self.update_all
			nil
		}
					
		# when a new value is entered
		@dialog.add_action_callback("octoPrint") { |action_context, value|
			case value
			when "updateFiles"
				self.update_fileslist
			when "Connected"
				self.update_connectionInfo
			when "Disconnected"
				self.update_connectionInfo
			end
			nil
		}
		
		@dialog.add_action_callback("saveText") do |dlg, filename, content, saveas|
			filename = filename.to_s
			if saveas || filename == "undefined"
				filename = UI.savepanel("Save File", "", filename)
			end
			if filename && !filename.empty?
				File.open(filename, "w") { |f| f.write(content) }
				scriptStr = "updateFilenameDisplay(#{filename.to_json})"
				@dialog.execute_script(scriptStr)
			end
		end

		@dialog.add_action_callback("loadText") do |dlg, filename|
			filename = UI.openpanel("Load File", "", filename.to_s)
		    if !filename.empty? && File.exist?(filename)
				content = File.read(filename)
				scriptStr = "loadEditor(#{filename.to_json}, #{content.to_json})"
				@dialog.execute_script(scriptStr)
			else
				nil
			end
		end
		
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
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: 100)
			when 6
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: 10)
			when 7
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: 1)
			when 8
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: 0.1)
			when 9
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: -0.1)
			when 10
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: -1)
			when 11
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: -10)
			when 12
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(z: -100)
			when 13
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: 100)
			when 14
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: 10)
			when 15
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: 1)
			when 16
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: 0.1)
			when 17
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: -0.1)
			when 18
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: -1)
			when 19
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: -10)
			when 20
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(x: -100)
			when 21
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: 100)
			when 22
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: 10)
			when 23
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: 1)
			when 24
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: 0.1)
			when 25
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: -0.1)
			when 26
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: -1)
			when 27
				puts "$$jog $$ speed #{object1}"
				GNTools.octoPrint.jog_head(y: -10)
			when 28
				puts "$$jog $$ speed #{object1}"
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
			when 39 #object cnc print
				pathObj = GNTools.pathObjList[object1["persistent_id"]]
				gCodeStr = ""
				gCodeStr = pathObj.createGCode(gCodeStr).gsub(/\R+/, "#r")
				if object1
					GNTools.octoPrint.send_gcodes(gCodeStr)
				end
			when 40
				path_to_save_to = UI.savepanel("Save Download", "", object1["name"])
				GNTools.octoPrint.download(object1["name"],path_to_save_to, object1["origin"])
			when 42
#				puts "Pause / Reprendre l'impression"
				if @printerPaused
					GNTools.octoPrint.resume_print
					@printerPaused = false
				else
					GNTools.octoPrint.pause_print
					@printerPaused = true
				end
			when 43
#				puts "Annuler l'impression"
				GNTools.octoPrint.cancel_print
			when 44
				puts "Impression"
				@printerPaused = false
				GNTools.octoPrint.start_print(object1["name"], object1["origin"])
			when 45
#				puts "effacer fichier"
				GNTools.octoPrint.delete_file(object1["name"], object1["origin"])
			when 46
#				puts "upload file " + object1["filename"]
				GNTools.octoPrint.upload_string(object1["content"], object1["filename"])
			when 47
#				puts "G0 X#{object1["X"]} Y#{object1["Y"]} Z#{object1["Z"]}"
				if object1.has_key?("F")
					GNTools.octoPrint.send_gcode("G0 X#{object1["X"]} Y#{object1["Y"]} Z#{object1["Z"]} F#{object1["F"]}")
				else
					GNTools.octoPrint.send_gcode("G0 X#{object1["X"]} Y#{object1["Y"]} Z#{object1["Z"]}")
				end
			when 48
				pathObj = GNTools.pathObjList[object1["persistent_id"]]
				gCodeStr = ""
				gCodeStr = pathObj.createGCode(gCodeStr)
				filename = ""
				scriptStr = "loadEditor(#{filename.to_json}, #{gCodeStr.to_json})"
				@dialog.execute_script(scriptStr)
			when 49
				puts object1
				GNTools::Paths::Hole.useG2Code = object1
			else
				puts "$$Bouton inconnu : #{value}$$"
				
			end
			nil
		}
		@dialog.set_size(@@dialogWidth,@@dialogHeight)
		@dialog.center # New feature!
		@dialog.show
	  end
	  if not GNTools.octoPrint.login_passive
		  @repeating_timer_id = UI.start_timer(10, true) do
		      next false unless @dialog
			  if GNTools.octoPrint.login_passive
				  UI.stop_timer(@repeating_timer_id)
			  end
		  end
	  end
	end
			
	def close_dialog
		if @dialog
			@dialog.set_can_close { true }
			@dialog.close
			GNTools.octoPrint.closeWebSocket
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
		  GNTools.octoPrint.closeWebSocket
		}
		dialog
	end
	
	def update_connectionInfo
		status_hash = {}
		status_hash["ping"] = GNTools.octoPrint.reachable
		connect_info = GNTools.octoPrint.connection_Info
		status_hash.merge!(connect_info) if connect_info
		script_str = "statusDialog(\'#{JSON.generate(status_hash)}\')"
		@dialog.execute_script(script_str)
	end
	
	def update_position(x,y,z)
		status_hash = {}
		status_hash["x"] = x
		status_hash["y"] = y
		status_hash["z"] = z
		script_str = "update_position(\'#{JSON.generate(status_hash)}\')"
		@dialog.execute_script(script_str)
	end
	
	def update_fileslist
		files = GNTools.octoPrint.list_files("")
		scriptStr = "updateFiles(\'#{JSON.generate(files)}\')"
		@dialog.execute_script(scriptStr)
	end
	
	def update_Objects
		newlist = self.get_ObjectList
		scriptStr = "updateObjects(\'#{JSON.generate(newlist)}\')"
		@dialog.execute_script(scriptStr)
	end
	
	def update_all
		self.update_dialog
		self.update_connectionInfo
		self.update_fileslist
		self.update_Objects
	end
	
	def update_dialog
		updateHash = {}
		updateHash["host"] = GNTools.octoPrint.host || ""
		updateHash["api_key"] = GNTools.octoPrint.api_key || ""
		updateHash["ping"] = GNTools.octoPrint.reachable
		updateHash["macro1"] = GNTools.octoPrint.macro1	|| ""
		updateHash["macro2"] = GNTools.octoPrint.macro2	|| ""	
		updateHash["macro3"] = GNTools.octoPrint.macro3 || ""
		scriptStr = "updateDialog(\'#{JSON.generate(updateHash)}\')"
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
				names << { "name" => entity.name, "persistent_id" => entity.persistent_id }
			end
		end

		return {"objet" => names}
	end
  end # class OctoPrintDialog
end # module GNTools