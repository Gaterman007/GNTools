require 'sketchup'
module GNTools
  class OctoPrintDialog
	@@dialogWidth = 850
	@@dialogHeight = 630

    def initialize()
		@title = "OctoPrint Dialog"
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
			GNTools.octoPrint.host = value["host"]
			GNTools.octoPrint.api_key = value["api_key"]
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
			GNTools.octoPrint.host = value["host"]
			GNTools.octoPrint.api_key = value["api_key"]		
			GNTools.octoPrint.saveToFile()
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
				puts "$$Bouton Z+ 100 cliqué!$$"
				GNTools.octoPrint.send_gcode("M114")
			when 6
				puts "$$Bouton Z+ 10 cliqué!$$"
			when 7
				puts "$$Bouton Z+ 1 cliqué!$$"
			when 8
				puts "$$Bouton Z+ 0.1 cliqué!$$"
			when 9
				puts "$$Bouton Z- 0.1 cliqué!$$"
			when 10
				puts "$$Bouton Z- 1 cliqué!$$"
			when 11
				puts "$$Bouton Z- 10 cliqué!$$"
			when 12
				puts "$$Bouton Z- 100 cliqué!$$"
			when 13
				puts "$$Bouton X+ 100 cliqué!$$"
			when 14
				puts "$$Bouton X+ 10 cliqué!$$"
			when 15
				puts "$$Bouton X+ 1 cliqué!$$"
			when 16
				puts "$$Bouton X+ 0.1 cliqué!$$"
			when 17
				puts "$$Bouton X- 0.1 cliqué!$$"
			when 18
				puts "$$Bouton X- 1 cliqué!$$"
			when 19
				puts "$$Bouton X- 10 cliqué!$$"
			when 20
				puts "$$Bouton X- 100 cliqué!$$"
			when 21
				puts "$$Bouton Y+ 100 cliqué!$$"
			when 22
				puts "$$Bouton Y+ 10 cliqué!$$"
			when 23
				puts "$$Bouton Y+ 1 cliqué!$$"
			when 24
				puts "$$Bouton Y+ 0.1 cliqué!$$"
			when 25
				puts "$$Bouton Y- 0.1 cliqué!$$"
			when 26
				puts "$$Bouton Y- 1 cliqué!$$"
			when 27
				puts "$$Bouton Y- 10 cliqué!$$"
			when 28
				puts "$$Bouton Y- 100 cliqué!$$"
			when 29
				puts "$$Bouton send cliqué!$$"
				GNTools.octoPrint.send_gcode(object1)
			when 30
				puts "$$Bouton send cliqué!$$"
				GNTools.octoPrint.send_gcode(object1)
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
		html_file = File.join(PATH_UI, 'html', 'GN_OctoPrint.html') # Use external HTML
		@@html_content = File.read(html_file)
				
		plugin_dir = File.dirname(PATH_UI) # Chemin du plugin
		css_path = "file:///" + File.join(PATH_UI, 'css', 'Sketchup.css').gsub("\\", "/")
		jquery_ui_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.css').gsub("\\", "/")
		jquery_js_path = "file:///" + File.join(PATH_UI, 'js/external/jquery/','jquery.js').gsub("\\", "/")
		jquery_uijs_path = "file:///" + File.join(PATH_UI, 'js', 'jquery-ui.js').gsub("\\", "/")
		jquery_uiimage_path = "file:///" + File.join(PATH_UI, 'images', 'senderControl.jpg').gsub("\\", "/")
		# Modifier le HTML pour utiliser ces chemins
		@@html_content.gsub!("../css/Sketchup.css", css_path)
		@@html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
		@@html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
		@@html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)
		@@html_content.gsub!("../images/senderControl.jpg", jquery_uiimage_path)
		
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
		dialog
	end
	
	def update_dialog
		updateHash = {}
		updateHash["host"] = GNTools.octoPrint.host
		updateHash["api_key"] = GNTools.octoPrint.api_key
		scriptStr = "updateDialog(\'#{JSON.generate(updateHash)}\')"
		@dialog.execute_script(scriptStr)
		
		files = GNTools.octoPrint.list_files
		scriptStr = "updateFiles(\'#{JSON.generate(files)}\')"
		@dialog.execute_script(scriptStr)
	end
  end # class OctoPrintDialog
end # module GNTools