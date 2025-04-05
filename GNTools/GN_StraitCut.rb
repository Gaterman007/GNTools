require 'sketchup.rb'
require 'json'
#require 'GNTools/GN_DefaultCNCData.rb'
#require 'GNTools/GN_DrillBits.rb'
require 'GNTools/GN_PathObj.rb'

module GNTools

	module Paths

		class StraitCut < PathObj

			attr_accessor :cutwidth
			attr_accessor :startPosition
			attr_accessor :endPosition
			attr_accessor :nbdesegment


			def initialize(group = nil)
				@cutwidth = 5.3
				@startPosition = [0,0,0]
				@endPosition = [0,0,0]
				@nbdesegment = 24
				super("StraitCut",group)
				if self.methodType == ""
					self.methodType = "Ramp"				# 'Ramp','Spiral'											
				end
			end

		    @@derivedType = @@defaultType.merge(
			  {
					"methodType":"Ramp",
					"cutwidth":5.3
			  }
		    )

		    def defaultType
			  @@derivedType
		    end			

			def createDynamiqueModel
				startPos,endPos = getGlobal()
#				startPos = Geom::Point3d.new(startPosition[0],startPosition[1],startPosition[2])
#				endPos = Geom::Point3d.new(endPosition[0],endPosition[1],endPosition[2])

				drillbitSize = DrillBits.getDrillBit(@drillBitName).cut_Diameter
				drillbitSize = drillbitSize.mm
				lineWidth = cutwidth.mm
				if lineWidth < drillbitSize
					lineWidth = drillbitSize
				end
				# Calcul du vecteur directionnel normalisé (unitaire)
				vector_line = endPos - startPos  # Crée un vecteur entre les deux points
				inverse_vector_line = startPos - endPos
				vector_line.length = drillbitSize / 2.0  # Redimensionner le vecteur
				inverse_vector_line.length = drillbitSize / 2.0
				if methodType == "Ramp"
					vector_line.length = lineWidth  / 2.0 # Redimensionner le vecteur
					inverse_vector_line.length = lineWidth / 2.0
				end
				# Déplacer les points de halfDrillSize vers l interieur pour les arc
				startMidPos = startPos.offset(vector_line)
				endMidPos = endPos.offset(inverse_vector_line)
				vector_verticle = Geom::Vector3d.new 0,0,1
				vector_perp = vector_verticle.cross(vector_line) # Vecteur perpendiculaire

				if methodType == "Ramp"
					edgearray_big = pathEntitie.entities.add_arc(startMidPos, vector_line, vector_verticle, lineWidth / 2.0, 90.degrees, 270.degrees)
					edgearray_big = pathEntitie.entities.add_arc(endMidPos, inverse_vector_line, vector_verticle, lineWidth / 2.0, 90.degrees, 270.degrees)

					# Calcul des points pour fermer le rectangle
					p1 = startMidPos.offset(vector_perp, lineWidth / 2.0) # Point déplacé vers le haut
					p2 = endMidPos.offset(vector_perp, lineWidth / 2.0)   # Point déplacé vers le haut
					p3 = endMidPos.offset(vector_perp, -lineWidth / 2.0)  # Point déplacé vers le bas
					p4 = startMidPos.offset(vector_perp, -lineWidth / 2.0) # Point déplacé vers le bas

					# Ajout des lignes pour fermer le rectangle
					edge = pathEntitie.entities.add_edges(p1, p2)  # Ligne du haut
					edge = pathEntitie.entities.add_edges(p3, p4)  # Ligne du ba
					edge[0].find_faces
					face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
					if face_remaining
						distance = self["depth"].mm
						if face_remaining.normal.z > 0.0
							distance = -distance
						end
						face_remaining.pushpull(distance)
					end
				elsif methodType == "Spiral"
					startp1 = startMidPos.offset(vector_perp, (lineWidth / 2.0) - (drillbitSize / 2.0)) # Point déplacé vers le haut
					edgearray_big = pathEntitie.entities.add_arc(startp1, vector_line, vector_verticle, drillbitSize / 2.0, 90.degrees, 180.degrees)

					startp1 = startMidPos.offset(vector_perp, (-(lineWidth / 2.0)) + (drillbitSize / 2.0)) # Point déplacé vers le bas
					edgearray_big = pathEntitie.entities.add_arc(startp1, vector_line, vector_verticle, drillbitSize / 2.0, 180.degrees, 270.degrees)
					# Calcul des points pour fermer le rectangle

					endp2 = endMidPos.offset(vector_perp, (-(lineWidth / 2.0)) + (drillbitSize / 2.0))   # Point déplacé vers le bas
					edgearray_big = pathEntitie.entities.add_arc(endp2, inverse_vector_line, vector_verticle, drillbitSize / 2.0, 90.degrees, 180.degrees)

					endp2 = endMidPos.offset(vector_perp, (lineWidth / 2.0) - (drillbitSize / 2.0))   # Point déplacé vers le haut
					edgearray_big = pathEntitie.entities.add_arc(endp2, inverse_vector_line, vector_verticle, drillbitSize / 2.0, 180.degrees, 270.degrees)

					# Calcul des points pour fermer le rectangle
					p1 = startMidPos.offset(vector_perp, lineWidth / 2.0) # Point déplacé vers le haut
					p2 = endMidPos.offset(vector_perp, lineWidth / 2.0)   # Point déplacé vers le haut
					p3 = endMidPos.offset(vector_perp, -lineWidth / 2.0)  # Point déplacé vers le bas
					p4 = startMidPos.offset(vector_perp, -lineWidth / 2.0) # Point déplacé vers le bas

					# Calcul des points pour fermer le rectangle
					p5 = startPos.offset(vector_perp, (lineWidth / 2.0) - (drillbitSize / 2.0)) # Point déplacé vers le haut
					p6 = endPos.offset(vector_perp, (lineWidth / 2.0) - (drillbitSize / 2.0))   # Point déplacé vers le haut
					p7 = endPos.offset(vector_perp, (-lineWidth / 2.0) + (drillbitSize / 2.0))  # Point déplacé vers le bas
					p8 = startPos.offset(vector_perp, (-lineWidth / 2.0) + (drillbitSize / 2.0)) # Point déplacé vers le bas

					# Ajout des lignes pour fermer le rectangle
					edge1 = pathEntitie.entities.add_edges(p1, p2)  # Ligne du haut
					edge = pathEntitie.entities.add_edges(p3, p4)  # Ligne du bas
					edge = pathEntitie.entities.add_edges(p5, p8)  
					edge = pathEntitie.entities.add_edges(p6, p7)  

					edge1[0].find_faces
					face_remaining = pathEntitie.entities.grep(Sketchup::Face).find { |f| f.valid? }
					if face_remaining
						distance = self["depth"].mm
						if face_remaining.normal.z > 0.0
							distance = -distance
						end
						face_remaining.pushpull(distance)
					end

				end

				edge = pathEntitie.entities.add_cpoint(startPos)
				edge = pathEntitie.entities.add_cpoint(endPos)
				Sketchup.active_model.active_view.invalidate
			end
			
			def self.Create(line,hash)
				newinstance = new()
				GNTools.toolDefaultNo["StraitCut"] = GNTools.toolDefaultNo["StraitCut"] + 1
				newinstance.pathName = "StraitCut_#{GNTools.toolDefaultNo["StraitCut"]}"
				newinstance.from_Hash(hash)
				newinstance.set_To_Attribute(newinstance.pathEntitie)
				newinstance.startPosition = line[0]
				newinstance.endPosition = line[1]
				newinstance.createDynamiqueModel
				newinstance
			end
			
			def getGlobal()
				transformation = GNTools::Paths::TransformPoint.getGlobalTransform(pathEntitie.parent)
				startPos = Geom::Point3d.new(startPosition[0],startPosition[1],startPosition[2])
				startPos.transform! transformation
				
				endPos = Geom::Point3d.new(endPosition[0],endPosition[1],endPosition[2])
				endPos.transform! transformation
				[startPos,endPos]
			end

			def changed(create_undo = false)
				super(create_undo)

				# effacer le model
				pathEntitie.entities.each { |entity|
					pathEntitie.entities.erase_entities(entity)
				}
				# recree le model
				self.createDynamiqueModel
				pathEntitie
			end
			
			def createCirlcePath(pathGroup,xpos,ypos,radius,segment,downslow)
				halfnbOfAngle = segment / 2.0
				stepAngle = 360.0 / segment
				@lastPosition = [xpos.mm,ypos.mm,downslow.mm]
				(0..halfnbOfAngle).each{ |angle|
					sinus = (Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius) + xpos
					cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
					edge = pathGroup.entities.add_edges(@lastPosition,[sinus.mm,cosine.mm,@lastPosition[2]])
					@lastPosition = [sinus.mm,cosine.mm,@lastPosition[2]]
				}
				(halfnbOfAngle - 1).step(0,-1) { |angle|
					sinus = (-(Math.sin((angle * stepAngle) * Math::PI / 180.0) * radius)) + xpos
					cosine = (Math.cos((angle * stepAngle) * Math::PI / 180.0) * radius) + ypos
					edge = pathGroup.entities.add_edges(@lastPosition,[sinus.mm,cosine.mm,@lastPosition[2]])
					@lastPosition = [sinus.mm,cosine.mm,@lastPosition[2]]
				}
			end
			
			def createLinePath(pathGroup,startPos,endPos,defRayon,downslow)
				# dessine une ligne avec des ronds
				startX = startPos.x.to_mm
				startY = startPos.y.to_mm
				endX = endPos.x.to_mm
				endY = endPos.y.to_mm

				# Rayon effectif
				pas = DrillBits.getDrillBit(@drillBitName).cut_Diameter # Espacement par défaut = diamètre du foret

				# Calcul du vecteur directionnel normalisé
				direction = Geom::Vector3d.new(endX - startX, endY - startY, 0)
				direction.length = 1 if direction.length > 0 # Normalisation

				# Position actuelle
				currentX, currentY = startX, startY

			    # Boucle pour placer les cercles le long de la ligne
			    while Geom::Point3d.new(currentX, currentY,downslow).distance(Geom::Point3d.new(endX, endY,downslow)) >= pas
					edge = pathGroup.entities.add_cpoint(Geom::Point3d.new(currentX.mm, currentY.mm,downslow))
					self.createCirlcePath(pathGroup,currentX, currentY,defRayon,nbdesegment,downslow.to_mm)
					# Avancer selon la direction
					currentX += direction.x * pas
					currentY += direction.y * pas
			    end

			    # Ajouter le dernier cercle à `endPos`
			    self.createCirlcePath(pathGroup, endX, endY, defRayon, nbdesegment,downslow.to_mm)
			end
			
			def createPath()
				super()
				startPos,endPos = self.getGlobal()
#				startPos = Geom::Point3d.new(startPosition[0],startPosition[1],startPosition[2])
#				endPos = Geom::Point3d.new(endPosition[0],endPosition[1],endPosition[2])
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
				holeBottom = -@depth.mm
#				holeBottom = material_thickness - @depth.mm
#				if holeBottom < 0 
#					holeBottom = 0.0
#				end
				if methodType == "Ramp"
					defRayon = @cutwidth - drillbitSize  # pour moitier gauche et droite
					if defRayon < 0.0
						defRayon = 0.0
					end
					if @multipass
						downslow = 0.0
					else
						downslow = holeBottom
					end
				    while (downslow >= holeBottom)
						self.createLinePath(pathGroup,startPos,endPos,defRayon,downslow)
						downslow = downslow - @depthstep.mm
					end
				elsif methodType == "Spiral"
				
				end
				edge = pathGroup.entities.add_cpoint(startPos)
				edge = pathGroup.entities.add_cpoint(endPos)
			end

			def lineGCode(startPos,endPos,defRayon,gCodeStr)
				# dessine une ligne avec des ronds
				startX = startPos.x.to_mm
				startY = startPos.y.to_mm
				endX = endPos.x.to_mm
				endY = endPos.y.to_mm

				# Rayon effectif
				pas = DrillBits.getDrillBit(@drillBitName).cut_Diameter # Espacement par défaut = diamètre du foret

				# Calcul du vecteur directionnel normalisé
				direction = Geom::Vector3d.new(endX - startX, endY - startY, 0)
				direction.length = 1 if direction.length > 0 # Normalisation

				# Position actuelle
				currentX, currentY = startX, startY

			    # Boucle pour placer les cercles le long de la ligne
			    while Geom::Point3d.new(currentX, currentY).distance(Geom::Point3d.new(endX, endY)) >= pas
				  gCodeStr = createGCodeCirlce(gCodeStr, currentX, currentY, defRayon, nbdesegment)
				  # Avancer selon la direction
				  currentX += direction.x * pas
				  currentY += direction.y * pas
			    end

			    # Ajouter le dernier cercle à `endPos`
			    gCodeStr = createGCodeCirlce(gCodeStr, endX, endY, defRayon, nbdesegment)
				gCodeStr
			end

			def createGCode(gCodeStr)
				startPos,endPos = self.getGlobal()
#			  startPos = Geom::Point3d.new(startPosition[0],startPosition[1],startPosition[2])
#			  endPos = Geom::Point3d.new(endPosition[0],endPosition[1],endPosition[2])

			  drillbitSize = DrillBits.getDrillBit(@drillBitName).cut_Diameter
			  drillBitRayon = (DrillBits.getDrillBit(@drillBitName).cut_Diameter/2.0)								# rayon de la drill
              def_CNCData = DefaultCNCDialog.def_CNCData
              safeHeight = def_CNCData.safeHeight
              material_thickness = def_CNCData.material_thickness
			  
              gCodeStr = gCodeStr + "; Strait Cut Name : %s\n" % [@pathName]
              gCodeStr = gCodeStr + "; drill bitName %s\n" % [@drillBitName]
			  gCodeStr = gCodeStr + "G0 Z%0.2f ; goto safe height\n" % [safeHeight]
		      gCodeStr = gCodeStr + "; drill %s line bit size, %0.2f\n" % [methodType, drillbitSize]
			  gCodeStr = gCodeStr + "; line from X%0.2f Y%0.2f to X%0.2f Y%0.2f\n" % [startPos.x.to_mm , startPos.y.to_mm , endPos.x.to_mm , endPos.y.to_mm]

			  holeBottom = material_thickness - @depth
			  if holeBottom < 0 
				holeBottom = 0.0
			  end
			  
              if methodType == "Ramp"
				  defRayon = @cutwidth - drillbitSize  # pour moitier gauche et droite
				  if defRayon < 0.0
					defRayon = 0.0
				  end
				  if @multipass
					downslow = material_thickness
				  else
					downslow = holeBottom
				  end
				  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto start position\n" % [startPos.x.to_mm , startPos.y.to_mm]
				  gCodeStr = gCodeStr + "G0 Z%0.2f ; go top of material\n" % [material_thickness]
				  while (downslow >= holeBottom) do
					gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto start position\n" % [startPos.x.to_mm , startPos.y.to_mm]
					gCodeStr = gCodeStr + "G0 Z%0.2f ; drill slow\n" % [downslow]
					gCodeStr = self.lineGCode(startPos,endPos,defRayon,gCodeStr)
					downslow = downslow - @depthstep
				  end
				  gCodeStr = gCodeStr + "G0  Z%0.2f ; go back up\n" % [safeHeight]
			  else
				  widthTotal = @cutwidth - drillbitSize
				  if widthTotal < 0.0
					widthTotal = 0.0
				  end

				  if @multipass
					  downslow = material_thickness
					  gCodeStr = gCodeStr + "G0 Z%0.2f ; go top of material\n" % [material_thickness]
					  while (downslow > material_thickness - @depth) do
						  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto start position\n" % [startPos.x.to_mm , startPos.y.to_mm]
						  gCodeStr = gCodeStr + "G0 Z%0.2f ; drill slow\n" % [downslow]
						  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto end position\n" % [endPos.x.to_mm , endPos.y.to_mm]
						  downslow = downslow - @depthstep
					  end
					  gCodeStr = gCodeStr + "G0  Z%0.2f ; go back up\n" % [safeHeight]
				  else
					  gCodeStr = gCodeStr + "G0 Z%0.2f ; go top of material\n" % [material_thickness]
					  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto start position\n" % [startPos.x.to_mm , startPos.y.to_mm]
					  gCodeStr = gCodeStr + "G0 Z%0.2f ; drill slow\n" % [holeBottom]
					  gCodeStr = gCodeStr + "G0 X%0.2f Y%0.2f ; goto end position\n" % [endPos.x.to_mm , endPos.y.to_mm]
					  gCodeStr = gCodeStr + "G0  Z%0.2f ; go back up\n" % [safeHeight]
				  end
			  end
              gCodeStr
            end

			def createGCodeCirlce(gCodeStr,xpos,ypos,radius,segment)
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
                gCodeStr
			end
            
			def set_To_Attribute(group)
				super(group)
				group.set_attribute( "StraitCut","cutwidth", self.cutwidth )
			end
			
			def get_From_Attributs(ent)
				super(ent)
				@cutwidth = ent.get_attribute( "StraitCut","cutwidth" )
			end

			# set StraitCut data from hash
			def from_Hash(hash)
				super(hash)
				self.cutwidth = hash["cutwidth"]["Value"]
			end

			# set hash from StraitCut data
			def to_Hash(hashTable)
				super(hashTable)
				hashTable["cutwidth"] = {"Value" => @cutwidth, "type" => "spinner","multiple" => false}
				hashTable
			end
		end
		
			
	end # module Paths
end  #module GNTools
