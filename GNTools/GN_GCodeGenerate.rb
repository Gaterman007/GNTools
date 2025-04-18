require 'sketchup.rb'
require 'json'
require 'GNTools/GN_DrillBits.rb'


module GNTools

	@pathObjList = {}


	def self.pathObjList
		@pathObjList
	end

	def self.pathObjList=(v)
		@pathObjList = v
	end


	@@toolDefaultNo = {"Hole" => 0,"StraitCut" => 0,"Pocket" => 0}

	def self.toolDefaultNo
		@@toolDefaultNo
	end

	def self.toolDefaultNo=(v)
		@@toolDefaultNo = v
	end


	@@toolPathNo = 0
	def self.toolPathNo
		@@toolPathNo
	end

	def self.toolPathNo=(v)
		@@toolPathNo = v
	end


	@@straitCutNo= 0

	def self.straitCutNo
		@@straitCutNo
	end

	def self.straitCutNo=(v)
		@@straitCutNo = v
	end

	@@pocketNo= 0

	def self.pocketNo
		@@pocketNo
	end

	def self.pocketNo=(v)
		@@pocketNo = v
	end
	
	def self.initCNCGCode
		DefaultCNCDialog.set_defaults
		self.setCNCDefaultNo
		Paths.loadPaths()
	end

	def self.setCNCDefaultNo
		model = Sketchup.active_model
		ents = model.active_entities


		ents.each { |entity| 
			groupName = Paths::isGroupObj(entity)
			if groupName != nil
				entnumber = entity.name.chars.last(entity.name.reverse.index("_")).join.to_i
			end
			if @@toolDefaultNo.key?(groupName)
				if @@toolDefaultNo[groupName] < entnumber
					@@toolDefaultNo[groupName] = entnumber
				end
			end
		}
	end

	class GCodeGenerate
        def self.generateGCode
			model = Sketchup.active_model
			drillNames = GNTools.pathObjList.values.map { |pathObj| pathObj.drillBitName}
			drillNames = drillNames.uniq
			gCodeStr = ""
			drillNames.each { |drillName| 
				if GNTools::DrillBits.isDrillBit(drillName)[0] != nil
					gCodeStr = gCodeStr + generateGCodeLayer(drillName)
				end
			}
			gCodeStr
        end
		
        def self.generateGCode2
			model = Sketchup.active_model
			drillNames = GNTools.pathObjList.values.map { |pathObj| pathObj.drillBitName}
			drillNames = drillNames.uniq

			drillNames.each { |drillName| 
				if GNTools::DrillBits.isDrillBit(drillName)[0] != nil
					generateGCodeLayer2(drillName)
				end
			}
        end

		def self.generateGCodeLayer2(drillName)
            def_CNCData = DefaultCNCDialog.def_CNCData
			GNTools.pathObjList.each {|pathobj| 
				if drillName == pathobj[1].drillBitName
					pathobj[1].createPath()
#						puts pathobj[1].pathEntitie.name
				end
			}
		end

        
		def self.generateGCodeLayer(drillName)
            def_CNCData = DefaultCNCDialog.def_CNCData
			gCodeStr = ";Nom du drill bit %s\n" % [ drillName ]
			gCodeStr = gCodeStr + def_CNCData.startGCode.gsub(/\r?\\n/, "\n")
			gCodeStr = gCodeStr + ";\nG0 X0 Y0 Z%0.2f\n" % [def_CNCData.safeHeight]
			GNTools.pathObjList.each {|pathobj| 
				if drillName == pathobj[1].drillBitName
					gCodeStr = pathobj[1].createGCode(gCodeStr)
#						puts pathobj[1].pathEntitie.name
				end
			}
			gCodeStr = gCodeStr + def_CNCData.endGCode.gsub(/\r?\\n/, "\n")
			gCodeStr = gCodeStr + "\n"
			gCodeStr = gCodeStr + "\n"
			gCodeStr
		end
		
		def self.SaveAs
			model = Sketchup.active_model
			sel = model.selection
              begin
                defaultFileName = "filecnc.cnc"
				selected_folder = UI.select_directory(
					title: "Choisir un dossier",
					directory: File.join(File.expand_path("~"), "Documents") # Optionnel, définit le dossier de départ
				)
				if selected_folder
					last_subdir = File.basename(selected_folder)
					last_subdir = last_subdir + ".cnc"
#					puts last_subdir
#					filepath = UI.savepanel("Save as…", File.join(File.expand_path("~"), "Documents",defaultFileName),"CNC|*.cnc|GCO|*.gco||")
#					unless filepath.nil? # User cancelled file dialog.
					self.saveTo(File.join(selected_folder, last_subdir),model)
                end
              rescue StandardError => e
                UI.messagebox("Failed to save", MB_MULTILINE, e.message)
              end
            
		end  #end def SaveAs

        def self.saveTo(filepath,model)
			model = Sketchup.active_model
			gCodeStr = ""
			drillNames = GNTools.pathObjList.values.map { |pathObj| pathObj.drillBitName}
			drillNames = drillNames.uniq
			drillNames.each { |drillName| 
				if GNTools::DrillBits.isDrillBit(drillName)[0] != nil
					filename = ""
					if filepath[-4,4].downcase == ".cnc"
						filename = filepath[0, filepath.length - 4] + "_" + drillName + ".cnc"
					else
						filename = filepath + "_" + drillName + ".cnc"
					end
				    filecnc = File.open(filename,"w+")
				    filecnc.printf(";Nom du Fichier %s\n" , filename)
					filecnc.printf(generateGCodeLayer(drillName))
					filecnc.close
 				end
			}
        end
	end  #end class
end  #module GNTools
