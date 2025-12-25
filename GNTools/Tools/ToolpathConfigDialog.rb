require 'sketchup'
module GNTools
  class ToolpathConfigDialog
    @@dialogWidth = 890
    @@dialogHeight = 820
	
	def self.instance
      @instance ||= new
    end
	
    def initialize()
    end

    def show_dialog
	  if @dialog && @dialog.visible?
		update_dialog
		@dialog.set_size(@@dialogWidth,@@dialogHeight)
		dialog.center # New feature!
		@dialog.bring_to_front
	  else
		# Attach content and callbacks when showing the dialog,
		# not when creating it, to be able to use the same dialog again.
		@dialog ||= create_dialog
		@dialog.set_html(@@html_content) # Injecter le HTML modifié
		action_callback
		@dialog.set_size(@@dialogWidth,@@dialogHeight)
		@dialog.center # New feature!
		@dialog.show
	  end
	end
	
	def action_callback
	  # when the dialog is ready update the data
	  puts "add dialog ready"
	  @dialog.add_action_callback("ready") { |action_context|
		puts "dialog ready"
		update_dialog
		nil
	  }
	  # when the button "Accept" is press "OK"
	  @dialog.add_action_callback("accept") { |action_context, value|
	    close_dialog
		nil
	  }
	  # when the button "Cancel" is press
	  @dialog.add_action_callback("cancel") { |action_context, value|
		close_dialog
		nil
	  }
				
	  @dialog.add_action_callback("newValue") { |action_context, value, object1|
		nil
	  }
					
	  # when the button "Set Default" is press
	  @dialog.add_action_callback("setDefault") { |action_context, value|
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
	  
	  @dialog.add_action_callback("saveSchema") do |ctx, type, values|
	    ToolpathSchemas.update_custom(type, values)
	    ToolpathSchemas.save_custom_schemas
	  end	  

	  @dialog.add_action_callback("resetSchema") do |ctx, type|
	    ToolpathSchemas.reset_custom(type)
	    ToolpathSchemas.save_custom_schemas
	    update_dialog
	  end
	  
    end # action_callback
	
	def ui_dir_path(subfolder)
	  "file:///" + File.join(PATH_UI, subfolder).gsub("\\", "/") + "/"
	end
	
	def create_dialog
	  html_file = File.join(PATH_UI, 'html', 'GN_ConfigDialog.html') # Use external HTML
	  @@html_content = File.read(html_file)
	
      @@html_content.gsub!("../css/", ui_dir_path("css"))
      @@html_content.gsub!("../js/", ui_dir_path("js"))
      @@html_content.gsub!("../Scripts/", ui_dir_path("Scripts"))
	  
	  options = {
	    :dialog_title => @title,
	    :resizable => true,
	    :width => @@dialogWidth,
	    :height => @@dialogHeight,
	    :preferences_key => "example.htmldialog.materialinspector",
	    :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
	  }
	  dialog = UI::HtmlDialog.new(options)
	  dialog.set_html(@@html_content) # Injecter le HTML modifié
#		dialog.set_file(html_file) # Can be set here.
	  dialog.center # New feature!
	  dialog.set_can_close { false }
	  dialog
	end
	
	def close_dialog
	  if @dialog
		@dialog.set_can_close { true }
		@dialog.close
	  end
	end
	
	def update_dialog
	  @dialog.execute_script(
		"loadPreviews(#{GNTools::NewPaths::ToolpathPreview.toJson})"
	  )
	  @dialog.execute_script(
		"loadStrategies(#{GNTools::NewPaths::StrategyEngine.toJson})"
	  )
	  @dialog.execute_script(
		"loadSchemas(#{GNTools::NewPaths::ToolpathSchemas.toJson})"
	  )
	  
	end	
  end # ToolpathConfigDialog
  
  def self.dialog
	$config = GNTools::ToolpathConfigDialog.instance
	$config.show_dialog
  end

end #GNTools