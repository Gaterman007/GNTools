require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_PathObj.rb'

module GNTools

	module Paths

		class GN_HoleData < GN_PathObjData
			attr_accessor :holesize
			attr_accessor :cutwidth
			attr_accessor :holeposition
			attr_accessor :nbdesegment

			@defaultType = GN_PathObjData.defaultType.merge({
			  "holesize"       => { "Value" => 15.0,      "type" => "spinner",  "multiple" => false },
			  "dictionaryName" => { "Value" => "Hole",    "type" => "text",     "multiple" => false },
			  "methodType"     => { "Value" => "Pocket",  "type" => "dropdown", "multiple" => false },
			  "holeposition"   => { "Value" => [0,0,0],   "type" => "text",     "multiple" => false },
			  "nbdesegment"    => { "Value" => 24,        "type" => "spinner",  "multiple" => false },
			  "cutwidth"       => { "Value" => 3.175,     "type" => "spinner",  "multiple" => false }
			})		
			
			
			def self.defaultType
			  @defaultType 
		    end
		end

		class Hole < PathObj

			@@useG2Code = true
			
		    def self.useG2Code=(val)
			  @@useG2Code = val
		    end

		    def self.useG2Code
			  @@useG2Code
		    end

			def createDynamiqueModel
				positionHole = getGlobal()
				if methodType == "Pocket"
					if !(holesize.mm == 0.0 || depth.mm == 0.0)
						vector_verticle = Geom::Vector3d.new 0,0,1
						edgearray = pathEntitie.entities.add_circle positionHole, vector_verticle, holesize.mm / 2.0
						face = pathEntitie.entities.add_face(edgearray)
						if face
							distance = depth.mm
							if face.normal.z > 0.0
								distance = -distance
							end
							face.pushpull(distance)
						end
					else
						edge = pathEntitie.entities.add_cpoint(positionHole)
					end
				elsif methodType == "Inside"
					if !(holesize.mm == 0.0 || depth.mm == 0.0)
						drillbitSize = DrillBits.getDrillBit(drillBitName).cut_Diameter
						vector_verticle = Geom::Vector3d.new 0,0,1
						edgearray_big = pathEntitie.entities.add_circle positionHole, vector_verticle, holesize.mm / 2.0
						face_big = pathEntitie.entities.add_face(edgearray_big)
						edgearray_small  = pathEntitie.entities.add_circle positionHole, vector_verticle, (holesize.mm  - (drillbitSize.mm * 2.0)) / 2.0
						# Trouver la face intérieure (celle qui a les arêtes du petit cercle)
						face_inner = pathEntitie.entities.grep(Sketchup::Face).find { |f| (f.edges - edgearray_small).empty? }
						# Supprimer la face intérieure si elle existe
						face_inner&.erase!
						# Trouver la face restante (la plus grande)
						face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
						if face_remaining
							distance = depth.mm
							if face_remaining.normal.z > 0.0
								distance = -distance
							end
							face_remaining.pushpull(distance)
						end
					else
						edge = pathEntitie.entities.add_cpoint(positionHole)
					end

				elsif methodType == "Outside"
					if !(holesize.mm == 0.0 || depth.mm == 0.0)
						drillbitSize = DrillBits.getDrillBit(drillBitName).cut_Diameter
						vector_verticle = Geom::Vector3d.new 0,0,1
						edgearray_big = pathEntitie.entities.add_circle positionHole, vector_verticle, (holesize.mm + (drillbitSize.mm * 2.0)) / 2.0
						face_big = pathEntitie.entities.add_face(edgearray_big)
						edgearray_small  = pathEntitie.entities.add_circle positionHole, vector_verticle, holesize.mm / 2.0
						# Trouver la face intérieure (celle qui a les arêtes du petit cercle)
						face_inner = pathEntitie.entities.grep(Sketchup::Face).find { |f| (f.edges - edgearray_small).empty? }
						# Supprimer la face intérieure si elle existe
						face_inner&.erase!
						# Trouver la face restante (la plus grande)
						face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
						if face_remaining
							distance = depth.mm
							if face_remaining.normal.z > 0.0
								distance = -distance
							end
							face_remaining.pushpull(distance)
						end
					else
						edge = pathEntitie.entities.add_cpoint(positionHole)
					end
				end
				Sketchup.active_model.active_view.invalidate
			end

			
			def self.Create(position,hash)
				newinstance = new()
				newinstance.from_Hash(hash)
				GNTools.toolDefaultNo["Hole"] = GNTools.toolDefaultNo["Hole"] + 1
				newinstance.pathName = "Hole_#{GNTools.toolDefaultNo["Hole"]}"
				newinstance.holeposition = position.to_a
				newinstance.createDynamiqueModel
				newinstance
			end

			def changed(create_undo = false)
				# effacer le model
				pathEntitie.entities.each { |entity|
					pathEntitie.entities.erase_entities(entity)
				}
				# recree le model
				self.createDynamiqueModel
			end


			def createGCode(gCodeStr)
				positionHole = self.getGlobal()
                drillbitSize = DrillBits.getDrillBit(drillBitName).cut_Diameter			# diametre de la drill
			    drillBitRayon = (drillbitSize/2.0)											# rayon de la drill	
				safeHeight = DefaultCNCData.getFromModel("safeHeight")						# la hauteur que l on peut faire un travel sans toucher a la piece
				if safeHeight == nil
					safeHeight = DefaultCNCDialog.def_CNCData.safeHeight
				end
				material_thickness = DefaultCNCData.getFromModel("height")						# la hauteur du materiel
				if material_thickness == nil
					material_thickness = DefaultCNCDialog.def_CNCData.material_thickness
				end
				defaultFeedRate = DefaultCNCData.getFromModel("defaultFeedRate")			# la vitesse par default
                parent=@pathEntitie.parent
				groupPos = Geom::Point3d.new(positionHole[0],positionHole[1],positionHole[2])
				if !(holesize.mm == 0.0 || depth.mm == 0.0)
					globalTransform = GNTools::Paths::TransformPoint.getGlobalTransform(@pathEntitie)
					holeBottom = material_thickness - depth
					if holeBottom < 0 
						holeBottom = 0.0
					end
					holeRayon = (holesize/2.0)										# rayon du trou
					case methodType
					when "Inside"
					  movement = holeRayon - drillBitRayon  # ce deplacer a l intereur du rayon
					  defRayon = movement					# ne fait que un rayon
					when "Outside"
					  movement = holeRayon + drillBitRayon	# ce deplacer a l exterieur du rayon
					  defRayon = movement					# ne fait que un rayon
					when "Pocket"
					  movement = holeRayon - drillBitRayon	# ce deplacer a l exterieur du rayon
					  defRayon = drillBitRayon
					end


					gCodeStr = gCodeStr + "; Path Name: %s\n" % [pathName]
					gCodeStr = gCodeStr + "; drill hole %0.2f\n" % [holesize]
					gCodeStr = gCodeStr + "; drill bitName %s\n" % [drillBitName]
					gCodeStr = gCodeStr + "; hole position X%0.2f Y%0.2f\n" % [groupPos.x.to_mm , groupPos.y.to_mm]
					gCodeStr = gCodeStr + "; drill %s hole bit size, %0.2f\n" % [methodType, drillbitSize]
					gCodeStr = gCodeStr + "G0 Z%0.2f F%0.2f ; goto safe  height\n" % [safeHeight, feedrate]
					gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto position to drill\n" % [groupPos.x.to_mm , groupPos.y.to_mm]

					# aller au debut du cercle
#					sinus = (Math.sin(0) * defRayon) + groupPos.x.to_mm
#					cosine = (Math.cos(0) * defRayon) + groupPos.y.to_mm
#					gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f  ;circle start\n" % [sinus,cosine]
					if multipass
						downslow = material_thickness
					else
						downslow = holeBottom
					end
					while (downslow >= holeBottom) do
					  puts "Creating layer #{methodType} at #{downslow}"
					  gCodeStr = gCodeStr + "G1 Z%0.2f ; drill slow\n" % [downslow]
					  if (movement > 0) then # drill bit < que la grandeur du trou
						if methodType == "Pocket"
							defRayon = drillBitRayon
						else
							if methodType == "Inside"
								defRayon = holeRayon - drillBitRayon
							else
								defRayon = holeRayon + drillBitRayon
							end
						end
						while (defRayon <= movement) do   # si on fait un pocket on agrandi sinon on en fait un seulement
							gCodeStr = createGCodeCirlce(gCodeStr,groupPos.x.to_mm,groupPos.y.to_mm,defRayon,nbdesegment)
							defRayon = defRayon + (drillBitRayon * (overlapPercent / 100.0))
						end
						if (movement >= 0) then 
							gCodeStr = createGCodeCirlce(gCodeStr,groupPos.x.to_mm,groupPos.y.to_mm,movement,nbdesegment)
						end
					  end
					  downslow = downslow - depthstep
					end
				end
				gCodeStr = gCodeStr + "G0 Z%0.2f F%0.2f ; goto safe  height\n" % [safeHeight, feedrate]
				gCodeStr
			end

			def createPath()
				super()
				positionHole = self.getGlobal()
				pathGroup = Sketchup.active_model.entities.add_group()
                drillbitSize = DrillBits.getDrillBit(drillBitName).cut_Diameter			# diametre de la drill
			    drillBitRayon = (drillbitSize/2.0)											# rayon de la drill	
				drillBitRayon = drillBitRayon.mm
				safeHeight = DefaultCNCData.getFromModel("safeHeight")						# la hauteur que l on peut faire un travel sans toucher a la piece
				if safeHeight == nil
					safeHeight = DefaultCNCDialog.def_CNCData.safeHeight
				end
				safeHeight = safeHeight.mm
				material_thickness = DefaultCNCData.getFromModel("height")						# la hauteur du materiel
				material_thickness = positionHole[2].to_mm
				if material_thickness == nil
					material_thickness = DefaultCNCDialog.def_CNCData.material_thickness
				end
				material_thickness = material_thickness.mm
				defaultFeedRate = DefaultCNCData.getFromModel("defaultFeedRate")			# la vitesse par default
                parent=@pathEntitie.parent
                groupPos = @pathEntitie.definition.bounds.center
				
#				puts positionHole[2]

				construction_point = @pathEntitie.entities.grep(Sketchup::ConstructionPoint)
				if construction_point
					globalTransform = GNTools::Paths::TransformPoint.getGlobalTransform(@pathEntitie)
					holeBottom = material_thickness - depth.mm
					if holeBottom < 0 
						holeBottom = 0.0
					end
					holeRayon = (holesize/2.0)										# rayon du trou
					holeRayon = holeRayon.mm
					case methodType
					when "Inside"
					  movement = holeRayon - drillBitRayon  # ce deplacer a l intereur du rayon
					  defRayon = movement					# ne fait que un rayon
					when "Outside"
					  movement = holeRayon + drillBitRayon	# ce deplacer a l exterieur du rayon
					  defRayon = movement					# ne fait que un rayon
					when "Pocket"
					  movement = holeRayon - drillBitRayon	# ce deplacer a l exterieur du rayon
					  defRayon = drillBitRayon
					end

					nextPosition = [0,0,0]
					# aller au debut du cercle
					sinus = (Math.sin(0) * defRayon) + groupPos.x
					cosine = (Math.cos(0) * defRayon) + groupPos.y
					self.createEdge(pathGroup,[groupPos.x , groupPos.y, material_thickness],[sinus,cosine, material_thickness])
					if multipass
						downslow = material_thickness
					else
						downslow = holeBottom
					end
					while (downslow >= holeBottom) do
					  puts "Creating layer #{methodType} at #{downslow}"
					  self.nextEdgeZ(pathGroup,downslow)
#					  gCodeStr = gCodeStr + "G1 Z%0.2f ; drill slow\n" % [downslow]
					  if (movement > 0) then # drill bit < que la grandeur du trou
						if methodType == "Pocket"
							defRayon = drillBitRayon
						else
							if methodType == "Inside"
								defRayon = holeRayon - drillBitRayon
							else
								defRayon = holeRayon + drillBitRayon
							end
						end

						while (defRayon <= movement) do   # si on fait un pocket on agrandi sinon on en fait un seulement						
							createEdgeCirlce(pathGroup,groupPos.x,groupPos.y,defRayon,nbdesegment)
							defRayon = defRayon + (drillBitRayon * (overlapPercent / 100.0))
						end
						if (movement >= 0) then 
							createEdgeCirlce(pathGroup,groupPos.x,groupPos.y,movement,nbdesegment)
						end
					  end
					  downslow = downslow - depthstep.mm
					end
				end
            end

			private

			def createPathData
			  GN_HoleData.new
			end

			def createEdgeCirlce(pathGroup,xpos,ypos,radius,segment)
				halfnbOfAngle = segment / 2.0
				stepAngle = 360.0 / segment
				(0..halfnbOfAngle).each{ |angle|
					sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
					cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
					self.nextEdgeXY(pathGroup,sinus,cosine)

#					gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, angle * stepAngle]
				}
				(halfnbOfAngle - 1).step(0,-1) { |angle|
					sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
					cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
					self.nextEdgeXY(pathGroup,sinus,cosine)
#					gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, (360 - (angle * stepAngle))]
				}
			end

			def createGCodeCirlce(gCodeStr,xpos,ypos,radius,segment)
				radius_mm = radius
				if Hole.useG2Code
					gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; point de départ (haut du cercle)\n" % [xpos,ypos]
					gCodeStr = gCodeStr + "G2 X%0.2f Y%0.2f I0 J%0.2f  ; premier demi-cercle (180°)\n" % [xpos,ypos-radius_mm,-radius_mm]
					gCodeStr = gCodeStr + "G2 X%0.2f Y%0.2f I0 J%0.2f   ; deuxième demi-cercle (180°)\n" % [xpos,ypos+radius_mm,radius_mm]
				else
					halfnbOfAngle = segment / 2.0
					stepAngle = 360.0 / segment
					(0..halfnbOfAngle).each{ |angle|
						sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
						cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
						gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, angle * stepAngle]
					}
					(halfnbOfAngle - 1).step(0,-1) { |angle|
						sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
						cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
						gCodeStr = gCodeStr + "G1 X%0.2f Y%0.2f  ;circle angle %0.2f\n" % [sinus,cosine, (360 - (angle * stepAngle))]
					}
				end
                gCodeStr
			end

			def createEdge(group,start,finish)
#				puts "edge %f,%f,%f : %f,%f,%f" % [start[0] , start[1], start[2], finish[0] , finish[1], finish[2]]
				edge = group.entities.add_edges(start,finish)
				@lastPosition = finish
			end
			
			def nextEdge(group,newPosition)
#				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], newPosition[0] , newPosition[1], newPosition[2]]
				edge = group.entities.add_edges(@lastPosition,newPosition)
				@lastPosition = newPosition
			end
			
			def nextEdgeXY(group,newXPosition,newYPosition)
#				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], newXPosition,newYPosition,@lastPosition[2]]
				edge = group.entities.add_edges(@lastPosition,[newXPosition,newYPosition,@lastPosition[2]])
				@lastPosition = [newXPosition,newYPosition,@lastPosition[2]]
			end

			def nextEdgeZ(group,newPosition)
#				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], @lastPosition[0],@lastPosition[1],newPosition]
				edge = group.entities.add_edges(@lastPosition,[@lastPosition[0],@lastPosition[1],newPosition])
				@lastPosition = [@lastPosition[0],@lastPosition[1],newPosition]
			end

			def getGlobal()
				transformation = GNTools::Paths::TransformPoint.getGlobalTransform(pathEntitie.parent)
				posi = Geom::Point3d.new(holeposition[0],holeposition[1],holeposition[2])
				posi.transform! transformation
				posi.to_a
			end
			
		end # Hole
		
		PathObj.register_class("Hole", GN_HoleData.defaultType, ->(*args){ Hole.Create(*args) })
			
	end # module Paths
end  #module GNTools
