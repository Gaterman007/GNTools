#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
#require 'fiddle'
#require 'fiddle/import'
#require 'fiddle/types'
require 'sketchup.rb'
#require 'json'


module GNTools

   # Plugin information
   PLUGIN = {
		id:       "GNTools Tool Set²".freeze,
		name:     "Tool Set²".freeze,
		version:  "0.3.0".freeze,
		creator:  "Gaetan Noiseux",
		description: "GNTools CNC / Tooling"
	}.freeze

# --- Hook sur l’extension SketchUp (enable/disable depuis Extension Manager) ---
	if defined?(SketchupExtension)	
	  EXTENSION = SketchupExtension.new(GNTools::PLUGIN[:id], File.join(File.dirname(__FILE__),"GNTools", "GN_ToolsCore.rb"))
	  EXTENSION.description = GNTools::PLUGIN[:description]
	  EXTENSION.version     = GNTools::PLUGIN[:version]
	  EXTENSION.creator     = GNTools::PLUGIN[:creator]
	  Sketchup.register_extension(EXTENSION, true)
	end
end
