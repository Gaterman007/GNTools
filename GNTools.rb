#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
#  load "C:/Users/Gaetan/Documents/Sketchup/GN3DPrinterCNC.rb"
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

require File.join(PATH_TOOLS, "GN_Translation.rb")
	self.load_translation()
require File.join(PATH, "GN_Menus.rb")
require File.join(PATH, "GN_Toolbars.rb")






	unless file_loaded?(file)

		GNTools.create_Menus()
        if File.exist?(PATH)
            x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
#                p file
                load file
            }
            x.length + 1
        else
            1
        end
		
		GN3DToolbars.load
		file_loaded(file)
	end
	
	DrillBits.loadFromFile(File.join(PATH, "DrillBits.txt"))
	self.initCNCGCode    



end
