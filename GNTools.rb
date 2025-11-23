#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'
require 'sketchup.rb'
require 'json'


module GNTools

   # Plugin information
   PLUGIN = {
		id:       "GNTool".freeze,
		name:     "Tool Set²".freeze,
		version:  "0.2.1".freeze
	}.freeze

	SKETCHUP_CONSOLE.show

    # Resource paths
    file = File.join(Sketchup.find_support_file('Plugins'),'GNTools.rb').dup
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
    FILENAMESPACE = File.basename(file, ".*")
    PATH_ROOT     = File.dirname(file).freeze
    PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze
	PATH_UI		  = File.join(PATH, "UI").freeze
	PATH_TOOLS	  = File.join(PATH, "Tools").freeze
    PATH_IMAGES  = File.join(PATH_UI, "images").freeze
    PATH_HTML    = File.join(PATH_UI, "html").freeze

	# --- Public init routine (idempotent) ---
	def self.init(file)
		load_translation
		unless file_loaded?(file)
			create_menus_and_toolbars
			file_loaded(file)
		end
		post_init_actions
	end
	
	def self.load_translation
		require File.join(PATH_TOOLS, "GN_Translation.rb")
		self.load_translation()
	end
	
	def self.create_menus_and_toolbars
		if File.exist?(PATH)
			x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |subfile|
			  expand_subfile = File.expand_path(subfile)
			  next if $LOADED_FEATURES.any? { |f| File.expand_path(f) == expand_subfile }
			  load expand_subfile
			}
			x.length + 1
		else
			1
		end
		GNTools.initMenu()
		GNTools.create_Menus()
		require File.join(PATH, "GN_Toolbars.rb")
		GN3DToolbars.load
	end
	
	  # --- Post init actions (drillbits, cnc init, ...) ---
	def self.post_init_actions
		drill_file = File.join(PATH, "DrillBits.txt")
		if File.exist?(drill_file) && defined?(DrillBits)
			DrillBits.loadFromFile(drill_file)
		end
		self.initCNCGCode    
	end
	
	
	
	def self.parse_ruby_file(file_path)
	  stack = []
	  structure = { modules: [], classes: [], methods: [] }
	  current_scope = structure

	  File.readlines(file_path).each do |line|
		line.strip!
		next if line.empty? || line.start_with?('#')

		# Détection module
		if line =~ /^module\s+([\w:]+)/
		  mod_name = $1
		  new_scope = { name: mod_name, type: :module, modules: [], classes: [], methods: [] }
		  current_scope[:modules] << new_scope
		  stack.push(current_scope)
		  current_scope = new_scope

		# Détection class
		elsif line =~ /^class\s+([\w:]+)/
		  class_name = $1
		  new_scope = { name: class_name, type: :class, modules: [], classes: [], methods: [] }
		  current_scope[:classes] << new_scope
		  stack.push(current_scope)
		  current_scope = new_scope

		# Méthodes
		elsif line =~ /^def\s+self\.([a-zA-Z0-9_!?]+)/
		  current_scope[:methods] << "self.#{$1}"
		elsif line =~ /^def\s+([a-zA-Z0-9_!?]+)/
		  current_scope[:methods] << $1

		# Fin module/class/méthode
		elsif line =~ /^end\b/
		  current_scope = stack.pop unless stack.empty?
		end
	  end

	  structure
	end

	# Fonction pour afficher la structure de façon hiérarchique
	def self.print_structure(scope, indent = 0)
	  prefix = ' ' * indent
	  scope[:modules].each do |m|
		puts "#{prefix}Module: #{m[:name]}"
		print_structure(m, indent + 2)
	  end
	  scope[:classes].each do |c|
		puts "#{prefix}Class: #{c[:name]}"
		print_structure(c, indent + 2)
	  end
#	  scope[:methods].each do |m|
#		puts "#{prefix}Method: #{m}"
#	  end
	end
	
	
	# Exemple pour tous les fichiers
#	Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each do |file|
#	  next if $LOADED_FEATURES.any? { |f| File.expand_path(f) == File.expand_path(file) }
#	  struct = parse_ruby_file(file)
#
#	  puts "File: #{file}"
#	  print_structure(struct, 2)
#	end	
	
	
	
	
	# run init when file is loaded (SketchUp environment)
	init(file) if file_loaded?(file) == false
end
