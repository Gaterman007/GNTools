require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_PathObj.rb'

module GNTools

	module Paths


		class Pocket < PathObj
			
			attr_accessor :cutwidth
			attr_accessor :loopSegment
			attr_accessor :pocket_faces_normal
			attr_accessor :pocket_faces_vertices
			
			
			# Définition privée du EdgeStruct
			# Définition d'une class qui imite Sketchup::Edge
			
			def initialize(group = nil)
				@cutwidth = 3.175
				@pocket_faces_normal = []
				@pocket_faces_vertices = []
				super("Pocket",group)
				if self.methodType == ""
					self.methodType = "Pocket"				# 'Pocket','Inside','Outside'											
				end
			end

		    @@derivedType = @@defaultType.merge(
			  {
					"methodType":"Pocket",
					"cutwidth":3.175
			  }
		    )

		    def defaultType
			  @@derivedType
		    end			

			def createDynamiqueModel
			
			    drillbitSize = DrillBits.getDrillBit(@drillBitName).cut_Diameter			# diametre de la drill 
			    drillBitRayon = (drillbitSize/2.0)								# rayon de la drill

				loopFace = LoopFace.new()
				loopFace.pfaces_vertices = self.getGlobal()
				loopFace.pfaces_normal = @pocket_faces_normal

				if methodType == "Pocket"
					loopsleft = loopFace.deplacer(0.mm)
					loopsleft.each do |loop_array|
						loop_array.each do |loop_arr|
							if loop_arr.size > 0 
								edgearray_big = []
								(0..loop_arr.size).each do |index_horaire|
									edge1 = loop_arr[(index_horaire) % loop_arr.size]
									edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
									edgearray_big.concat(pathEntitie.entities.add_edges(edge1,edge2))
								end
								number_of_faces_found = edgearray_big[0].find_faces
							end
						end
					end
					face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
					if face_remaining
						distance = self["depth"].mm
						if face_remaining.normal.z > 0.0
							distance = -distance
						end
						face_remaining.pushpull(distance)
					end
				elsif methodType == "Inside"
					loopsleft = loopFace.deplacer(0.mm)
					loopsleft.each do |loop_array|
						loop_array.each do |loop_arr|
							if loop_arr.size > 0 
								edgearray_big = []
								(0..loop_arr.size).each do |index_horaire|
									edge1 = loop_arr[(index_horaire) % loop_arr.size]
									edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
									edgearray_big.concat(pathEntitie.entities.add_edges(edge1,edge2))
								end
								number_of_faces_found = edgearray_big[0].find_faces
							end
						end
					end
				  
					loopsright = loopFace.deplacer(-drillbitSize.mm)
					loopsright.each do |loop_array|
						loop_array.each do |loop_arr|
							if loop_arr.size > 0 
								edgearray_small = []
								(0..loop_arr.size).each do |index_horaire|
									edge1 = loop_arr[(index_horaire) % loop_arr.size]
									edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
									edgearray_small.concat(pathEntitie.entities.add_edges(edge1,edge2))
								end
								edgearray_small[0].find_faces
								# Trouver la face intérieure (celle qui a les arêtes de la plus petit face)
								face_inner = pathEntitie.entities.grep(Sketchup::Face).find { |f| (f.edges - edgearray_small).empty? }
								# Supprimer la face intérieure si elle existe
								face_inner&.erase!
							end
						end
					end
					face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
					if face_remaining
						distance = self["depth"].mm
						if face_remaining.normal.z > 0.0
							distance = -distance
						end
						face_remaining.pushpull(distance)
					end
				elsif methodType == "Outside"
					loopsleft = loopFace.deplacer(drillbitSize.mm)
					loopsleft.each do |loop_array|
						loop_array.each do |loop_arr|
							if loop_arr.size > 0 
								edgearray_big = []
								(0..loop_arr.size).each do |index_horaire|
									edge1 = loop_arr[(index_horaire) % loop_arr.size]
									edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
									edgearray_big.concat(pathEntitie.entities.add_edges(edge1,edge2))
								end
								number_of_faces_found = edgearray_big[0].find_faces
							end
						end
					end
				  
					loopsright = loopFace.deplacer(0.mm)
					loopsright.each do |loop_array|
						loop_array.each do |loop_arr|
							if loop_arr.size > 0 
								edgearray_small = []
								(0..loop_arr.size).each do |index_horaire|
									edge1 = loop_arr[(index_horaire) % loop_arr.size]
									edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
									edgearray_small.concat(pathEntitie.entities.add_edges(edge1,edge2))
								end
								edgearray_small[0].find_faces
								# Trouver la face intérieure (celle qui a les arêtes de la plus petit face)
								face_inner = pathEntitie.entities.grep(Sketchup::Face).find { |f| (f.edges - edgearray_small).empty? }
								# Supprimer la face intérieure si elle existe
								face_inner&.erase!
							end
						end
					end
					face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
					if face_remaining
						distance = self["depth"].mm
						if face_remaining.normal.z > 0.0
							distance = -distance
						end
						face_remaining.pushpull(distance)
					end
				end
				Sketchup.active_model.active_view.invalidate
			end
			
			def self.CreateFromLoop(loop,hash)
				newinstance = new()
				GNTools.toolDefaultNo["Pocket"] = GNTools.toolDefaultNo["Pocket"] + 1
				newinstance.pathName = "Pocket_#{GNTools.toolDefaultNo["Pocket"]}"
				newinstance.from_Hash(hash)
				newinstance.set_To_Attribute(newinstance.pathEntitie)
				face_vertices = []
				loop.each do |edge|
					face_vertices << edge.start.position
				end
				newinstance.pocket_faces_vertices << face_vertices
				sum_direction = 0
				(0..loop.size).each do |index_horaire|
					edge1 = loop[(index_horaire) % loop.size].start.position.to_a
					edge2 = loop[(index_horaire + 1) % loop.size].start.position.to_a
					edge3 = loop[(index_horaire + 2) % loop.size].start.position.to_a
					sum_direction += (edge2[0] - edge1[0]) * (edge3[1] - edge1[1]) - (edge2[1] - edge1[1]) * (edge3[0] - edge1[0])
				end
				if sum_direction > 0
					newinstance.pocket_faces_normal << Geom::Vector3d.new(0.0,0.0,1.0)
				else
					newinstance.pocket_faces_normal << Geom::Vector3d.new(0.0,0.0,-1.0)
				end
				newinstance.createDynamiqueModel
				newinstance
			end
			
			def self.Create(faces,hash)
				newinstance = new()
				GNTools.toolDefaultNo["Pocket"] = GNTools.toolDefaultNo["Pocket"] + 1
				newinstance.pathName = "Pocket_#{GNTools.toolDefaultNo["Pocket"]}"
				newinstance.from_Hash(hash)
				newinstance.set_To_Attribute(newinstance.pathEntitie)
				group = newinstance.pathEntitie
				faces.each do |face|
					face_vertices = []
					face.outer_loop.vertices.each do |vertex|
						face_vertices << vertex.position
					end
					newinstance.pocket_faces_vertices << face_vertices
					newinstance.pocket_faces_normal << face.normal
				end

				newinstance.createDynamiqueModel
				newinstance
			end

			def getGlobal()
				pocketFaceVertices = []
				@pocket_faces_vertices.each do |face|
					pFaceVertices = face.map do |vertex|
						transformation = GNTools::Paths::TransformPoint.getGlobalTransform(pathEntitie.parent)
						vertex.clone.transform(transformation) 
					end
					pocketFaceVertices << pFaceVertices
				end
				pocketFaceVertices
			end
			
			def changed(create_undo = false)
				super(create_undo)
				transformation = GNTools::Paths::TransformPoint.getGlobalTransform(pathEntitie.parent)

				# effacer le model
				pathEntitie.entities.each { |entity|
					pathEntitie.entities.erase_entities(entity)
				}
				# recree le model
				self.createDynamiqueModel
			end
			
			def createPathLoop(pathGroup,loopsleft,offset_height)
				loopsleft.each do |loop_array|
					loop_array.each do |loop_arr|
						if loop_arr.size > 0
							edgearray_big = []
							(0..loop_arr.size).each do |index_horaire|
								edge1 = loop_arr[(index_horaire) % loop_arr.size]
								edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
								edge1[2] = offset_height
								edge2[2] = offset_height									
								edgearray_big.concat(pathGroup.entities.add_edges(edge1,edge2))
							end
						end
					end
				end
			end
			
			def createPath()
				super()
				loopFace = LoopFace.new()
				loopFace.pfaces_vertices = self.getGlobal()
				loopFace.pfaces_normal = @pocket_faces_normal

				pathGroup = Sketchup.active_model.entities.add_group()
                drillbitSize = DrillBits.getDrillBit(@drillBitName).cut_Diameter			# diametre de la drill
			    drillBitRayon = (drillbitSize/2.0)											# rayon de la drill	
				drillBitRayon = drillBitRayon.mm
				safeHeight = DefaultCNCData.getFromModel("safeHeight")						# la hauteur que l on peut faire un travel sans toucher a la piece
				if safeHeight == nil
					safeHeight = DefaultCNCDialog.def_CNCData.safeHeight
				end
				safeHeight = safeHeight.mm
				material_thickness = DefaultCNCData.getFromModel("height")						# la hauteur du materiel
				if material_thickness == nil
					material_thickness = DefaultCNCDialog.def_CNCData.material_thickness
				end
				material_thickness = material_thickness.mm
				defaultFeedRate = DefaultCNCData.getFromModel("defaultFeedRate")			# la vitesse par default
				boundingbox = pathEntitie.bounds
				pocketsize = boundingbox.width
				if pocketsize < boundingbox.height
					pocketsize = boundingbox.height
				end
				offset_height = 0.0
				while offset_height > -self["depth"].mm
					if methodType == "Pocket"
						offset_loop = pocketsize.to_mm
						while offset_loop > 0.0
							loopsleft = loopFace.deplacer(-offset_loop)
							self.createPathLoop(pathGroup,loopsleft,offset_height)
							offset_loop -= drillBitRayon
						end
					elsif methodType == "Inside"
						loopsleft = loopFace.deplacer(-drillBitRayon)
						self.createPathLoop(pathGroup,loopsleft,offset_height)
					elsif methodType == "Outside"
						offset_loop = pocketsize.mm
						loopsleft = loopFace.deplacer(drillBitRayon)
						self.createPathLoop(pathGroup,loopsleft,offset_height)
					end
					offset_height -= depthstep.mm
				end
			end
			
			def distance_point_to_edge(point, edge)
			  a = edge.start.position
			  b = edge.end.position
			  ab = b - a
			  ap = point - a

			  # Projection scalaire du point sur la ligne
			  t = ap.dot(ab) / ab.dot(ab)

			  # Vérification si la projection est sur l'arête
			  if t < 0
				return ap.length  # Distance à A
			  elsif t > 1
				return (point - b).length  # Distance à B
			  else
				# Point projeté sur l'arête	
				projection = a.offset(ab, t)
				return (point - projection).length
			  end
			end

			def faceGCode(newEdges,gCodeStr)
			  # dessine la face
			  newEdges.each_with_index do |cline, i|
				gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f\n" % [cline.finish.position.x.to_mm , cline.finish.position.y.to_mm]
			  end
 			  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f\n" % [newEdges[0].start.position.x.to_mm , newEdges[0].start.position.y.to_mm]
			  gCodeStr
			end
            
			def createGCodeLoop(loopsleft,offset_height,gCodeStr)
				loopsleft.each do |loop_array|
					loop_array.each do |loop_arr|
						if loop_arr.size > 0
							edgearray_big = []
							edge1 = loop_arr[0]
							gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f\n" % [edge1[0].to_mm , edge1[1].to_mm]
							gCodeStr = gCodeStr + "G0 Z%0.2f\n" % [offset_height.to_mm]
							(0..loop_arr.size).each do |index_horaire|
								edge2 = loop_arr[(index_horaire + 1) % loop_arr.size]
								edge2[2] = offset_height									
								gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f\n" % [edge2[0].to_mm , edge2[1].to_mm]
							end
							gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f\n" % [edge1[0].to_mm , edge1[1].to_mm]
						end
					end
				end
				gCodeStr
			end
			
			def createGCode(gCodeStr)
				loopFace = LoopFace.new()
				loopFace.pfaces_vertices = self.getGlobal()
				loopFace.pfaces_normal = @pocket_faces_normal
                drillbitSize = DrillBits.getDrillBit(@drillBitName).cut_Diameter			# diametre de la drill
			    drillBitRayon = (drillbitSize/2.0)											# rayon de la drill	
				drillBitRayon = drillBitRayon.mm
				safeHeight = DefaultCNCData.getFromModel("safeHeight")						# la hauteur que l on peut faire un travel sans toucher a la piece
				if safeHeight == nil
					safeHeight = DefaultCNCDialog.def_CNCData.safeHeight
				end
				safeHeight = safeHeight.mm
				material_thickness = DefaultCNCData.getFromModel("height")						# la hauteur du materiel
				if material_thickness == nil
					material_thickness = DefaultCNCDialog.def_CNCData.material_thickness
				end
				material_thickness = material_thickness.mm
				defaultFeedRate = DefaultCNCData.getFromModel("defaultFeedRate")			# la vitesse par default
				boundingbox = pathEntitie.bounds
				pocketsize = boundingbox.width
				if pocketsize < boundingbox.height
					pocketsize = boundingbox.height
				end

				gCodeStr = gCodeStr + "; create a pocket\n"
				gCodeStr = gCodeStr + "; pocket Name : %s\n" % [@pathName]
				gCodeStr = gCodeStr + "G0  Z%0.2f ; goto safe height\n" % [safeHeight.to_mm]
				gCodeStr = gCodeStr + "; drill %s pocket bit size, %0.2f\n" % [@methodType, drillbitSize]
				holeBottom = material_thickness - @depth.mm
				if holeBottom < 0 
					holeBottom = 0.0
				end
				if @multipass
					downslow = material_thickness
				else
					downslow = holeBottom
				end
				while (downslow >= holeBottom) do
					if methodType == "Pocket"
						offset_loop = pocketsize.to_mm
						while offset_loop > 0.0
							loopsleft = loopFace.deplacer(-offset_loop)
							gCodeStr = self.createGCodeLoop(loopsleft,downslow,gCodeStr)
							offset_loop -= drillBitRayon
						end
					elsif methodType == "Inside"
						loopsleft = loopFace.deplacer(-drillBitRayon)
						gCodeStr = self.createGCodeLoop(loopsleft,downslow,gCodeStr)
					elsif methodType == "Outside"
						loopsleft = loopFace.deplacer(drillBitRayon)
						gCodeStr = self.createGCodeLoop(loopsleft,downslow,gCodeStr)
					end
					downslow = downslow - @depthstep.mm
				end
                gCodeStr
            end
            
#			def draw(view)
#				if @loopSegment.count > 0
#					@loopSegment.draw(view)
#				end
		#			(0...@edgesArray.length).step(2).each {|index|
		#				startpos = @edgesArray[index]
		#				endpos = @edgesArray[index+1]
		#				view.set_color_from_line(startpos,endpos)
		#				view.line_width = 1
		#view.line_stipple = '-'
		#"." (Dotted Line),
		#"-" (Short Dashes Line),
		#"_" (Long Dashes Line),
		#"-.-" (Dash Dot Dash Line),
		#"" (Solid Line).#
		#view.line_stipple = '_'      
		#				view.line_stipple = ''      
		#				view.draw(GL_LINES, startpos,endpos)
		#			}
#			end


			
			def set_To_Attribute(group)
				super(group)
				group.set_attribute( "Pocket","cutwidth", self.cutwidth )
			end
			
			def get_From_Attributs(ent)
				super(ent)
				@cutwidth = ent.get_attribute( "Pocket","cutwidth" )
			end
			
			# set Pocket data from hash
			def from_Hash(hash)
				super(hash)
				self.cutwidth = hash["cutwidth"]["Value"]
			end

			# set hash from Pocket data
			def to_Hash(hashTable)
				super(hashTable)
				hashTable["cutwidth"] = {"Value" => @cutwidth, "type" => "spinner","multiple" => false}
				if @pathEntitie
					faces = @pathEntitie.entities.grep(Sketchup::Face)
					hashTable["numOfEdge"] = {"Value" => faces.count(), "numOfEdge" => "label","multiple" => false}
				else
					hashTable["numOfEdge"] = {"Value" => 0, "numOfEdge" => "label","multiple" => false}
				end
				hashTable
			end
		end # Pocket
		
		
			
	end # module Paths
end  #module GNTools
