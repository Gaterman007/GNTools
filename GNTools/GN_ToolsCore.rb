#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
#require 'fiddle'
#require 'fiddle/import'
#require 'fiddle/types'
#require 'sketchup.rb'
#require 'json'


module GNTools

	SKETCHUP_CONSOLE.show

    # Resource paths
    file = __FILE__.dup
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
	PATH_ROOT     = File.dirname(__FILE__).freeze
	PATH_UI		  = File.join(PATH_ROOT, "UI").freeze
	PATH_TOOLS	  = File.join(PATH_ROOT, "Tools").freeze
    PATH_IMAGES  = File.join(PATH_UI, "images").freeze
    PATH_HTML    = File.join(PATH_UI, "html").freeze

	# --- Public init routine (idempotent) ---
	def self.init(file)
		require File.join(PATH_TOOLS, "GN_Translation.rb")
		self.load_translation()
		unless file_loaded?(file)
			create_menus_and_toolbars
			file_loaded(file)
		end
		post_init_actions
	end
	
	def self.create_menus_and_toolbars
		require File.join(PATH_ROOT, "GN_Menus.rb")
		GNTools.initMenu()
		GNTools.create_Menus()
		require File.join(PATH_ROOT, "GN_Toolbars.rb")
		GN3DToolbars.load
		# loading all the other files
		if File.exist?(PATH_ROOT)
			x = Dir.glob(File.join(PATH_ROOT, "**/*.{rb,rbs}")).each { |subfile|
			  expand_subfile = File.expand_path(subfile)
			  next if $LOADED_FEATURES.any? { |f| File.expand_path(f) == expand_subfile }
			  require expand_subfile
			}
			x.length + 1
		else
			1
		end
	end
	
	  # --- Post init actions (drillbits, cnc init, ...) ---
	def self.post_init_actions
		drill_file = File.join(PATH_ROOT, "DrillBits.txt")
		if File.exist?(drill_file) && defined?(DrillBits)
			DrillBits.loadFromFile(drill_file)
		end
		self.initCNCGCode    
	end
	
	# run init when file is loaded (SketchUp environment)
	init(file) unless file_loaded?(file)
end
